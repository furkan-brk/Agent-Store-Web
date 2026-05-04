package guild

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Pure-helper tests for the v3.8 structured-suggest pipeline. These
// don't need DB so they live alongside the service file rather than
// behind testutil.NewTestDB.

func TestFilterConfidencePerType_DropsUnknownTypes(t *testing.T) {
	in := map[string]float64{
		"wizard":     0.9,
		"strategist": 0.5,
		"unknown":    0.8, // not in validTypes
	}
	got := filterConfidencePerType(in, []string{"wizard", "strategist"})
	require.Len(t, got, 2)
	assert.InDelta(t, 0.9, got["wizard"], 0.01)
	assert.NotContains(t, got, "unknown")
}

func TestFilterConfidencePerType_NormalisesPercentages(t *testing.T) {
	// AI providers occasionally return 0..100 instead of 0..1 — coerce.
	in := map[string]float64{"wizard": 75, "strategist": 30}
	got := filterConfidencePerType(in, []string{"wizard", "strategist"})
	assert.InDelta(t, 0.75, got["wizard"], 0.01)
	assert.InDelta(t, 0.30, got["strategist"], 0.01)
}

func TestFilterConfidencePerType_ClampsOutOfRange(t *testing.T) {
	in := map[string]float64{
		"wizard":     -0.5, // negative → 0
		"strategist": 9999, // way past 100 → clamped to 1
	}
	got := filterConfidencePerType(in, []string{"wizard", "strategist"})
	assert.Equal(t, 0.0, got["wizard"])
	assert.Equal(t, 1.0, got["strategist"])
}

func TestFilterConfidencePerType_EmptyReturnsNil(t *testing.T) {
	assert.Nil(t, filterConfidencePerType(nil, []string{"wizard"}))
	assert.Nil(t, filterConfidencePerType(map[string]float64{}, []string{"wizard"}))
}

func TestNormalisePlan_RenumbersSteps(t *testing.T) {
	in := []PlanStep{
		{Step: 5, Title: "Spec"}, // out-of-order numbering from AI
		{Step: 0, Title: "Build"},
		{Step: 17, Title: "Ship"},
	}
	got := normalisePlan(in)
	require.Len(t, got, 3)
	assert.Equal(t, 1, got[0].Step)
	assert.Equal(t, 2, got[1].Step)
	assert.Equal(t, 3, got[2].Step)
	assert.Equal(t, "Spec", got[0].Title)
}

func TestNormalisePlan_DropsEmptyTitles(t *testing.T) {
	in := []PlanStep{
		{Step: 1, Title: "Real step"},
		{Step: 2, Title: "   "}, // whitespace only → drop
		{Step: 3, Title: "Another step"},
	}
	got := normalisePlan(in)
	require.Len(t, got, 2)
	assert.Equal(t, "Real step", got[0].Title)
	assert.Equal(t, "Another step", got[1].Title)
}

func TestNormalisePlan_NilOnEmpty(t *testing.T) {
	assert.Nil(t, normalisePlan(nil))
	assert.Nil(t, normalisePlan([]PlanStep{}))
	assert.Nil(t, normalisePlan([]PlanStep{{Title: ""}}))
}

func TestFilterOwners_KeepsOnlyValidTypes(t *testing.T) {
	in := []OwnerAssignment{
		{Type: "wizard", Role: "Code Architect", Responsibility: "Backend"},
		{Type: "ghost", Role: "Spook", Responsibility: "Boo"}, // not in valid set
		{Type: "strategist", Role: "PM", Responsibility: "Plan"},
	}
	got := filterOwners(in, []string{"wizard", "strategist"})
	require.Len(t, got, 2)
	assert.Equal(t, "wizard", got[0].Type)
	assert.Equal(t, "strategist", got[1].Type)
}

func TestFilterOwners_DropsBlankRoleAndResponsibility(t *testing.T) {
	in := []OwnerAssignment{
		{Type: "wizard", Role: "", Responsibility: ""}, // both blank → drop
		{Type: "strategist", Role: "PM", Responsibility: ""},
	}
	got := filterOwners(in, []string{"wizard", "strategist"})
	require.Len(t, got, 1)
	assert.Equal(t, "strategist", got[0].Type)
}

func TestRoundConfidence_ClampsAndRounds(t *testing.T) {
	assert.Equal(t, 0.0, roundConfidence(-1))
	assert.Equal(t, 1.0, roundConfidence(2))
	assert.Equal(t, 0.73, roundConfidence(0.7321428571))
	assert.Equal(t, 0.5, roundConfidence(0.5))
}

func TestSlugify_ProducesValidMissionSlug(t *testing.T) {
	cases := map[string]string{
		"My Test Mission!":         "my-test-mission",
		"  spaces  inside  ":       "spaces-inside",
		"Mixed-Case_Symbols #@!":   "mixed-case_symbols",
		"---leading-trailing---":   "leading-trailing",
		"AAAAAA":                   "aaaaaa",
		"":                         "", // checked separately for the timestamp fallback
	}
	for in, want := range cases {
		if want == "" {
			got := slugify(in)
			// fallback prefix
			assert.True(t, strings.HasPrefix(got, "gm-"),
				"empty input must fall back to a timestamped slug, got %q", got)
			continue
		}
		got := slugify(in)
		assert.Equal(t, want, got, "slugify(%q)", in)
	}
}

func TestSlugify_TruncatesLongInput(t *testing.T) {
	in := strings.Repeat("a", 200)
	got := slugify(in)
	assert.LessOrEqual(t, len(got), 80)
}

func TestBuildMissionPrompt_ContainsAllSections(t *testing.T) {
	s := &GuildSuggestion{
		Goal: "Ship the bot.",
		Plan: []PlanStep{
			{Step: 1, Title: "Spec", Description: "Write a one-pager"},
			{Step: 2, Title: "Build"},
		},
		Owners: []OwnerAssignment{
			{Type: "wizard", Role: "Code Architect", Responsibility: "Backend"},
		},
		Risks:           []string{"AI provider rate limit"},
		SuccessCriteria: []string{"Shipped within two weeks"},
	}
	prompt := buildMissionPrompt(s, "Original problem")
	assert.Contains(t, prompt, "## Goal")
	assert.Contains(t, prompt, "Ship the bot.")
	assert.Contains(t, prompt, "## Plan")
	assert.Contains(t, prompt, "1. **Spec**")
	assert.Contains(t, prompt, "## Owners")
	assert.Contains(t, prompt, "Code Architect")
	assert.Contains(t, prompt, "## Risks")
	assert.Contains(t, prompt, "## Success criteria")
}

func TestBuildMissionPrompt_FallsBackToProblemWhenNoGoal(t *testing.T) {
	// When the AI didn't fill in a goal but a problem statement is
	// available, use the problem so the mission isn't headless.
	s := &GuildSuggestion{
		Plan: []PlanStep{{Step: 1, Title: "Step"}},
	}
	prompt := buildMissionPrompt(s, "Build the thing")
	assert.Contains(t, prompt, "## Goal")
	assert.Contains(t, prompt, "Build the thing")
}

func TestBuildMissionPrompt_EmptyWhenAllFieldsBlank(t *testing.T) {
	prompt := buildMissionPrompt(&GuildSuggestion{}, "")
	assert.Empty(t, prompt, "no inputs → no prompt; caller should refuse to bridge")
}

func TestTrimStrings_FiltersWhitespace(t *testing.T) {
	got := trimStrings([]string{"  hello", " ", "world  "})
	assert.Equal(t, []string{"hello", "world"}, got)
}

func TestTrimStrings_EmptyReturnsNil(t *testing.T) {
	assert.Nil(t, trimStrings(nil))
	assert.Nil(t, trimStrings([]string{}))
	assert.Nil(t, trimStrings([]string{"   "}))
}
