package agent

import (
	"testing"

	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
)

func TestScoreAgent_TitleOutweighsDescription(t *testing.T) {
	titleHit := models.Agent{
		Title:       "Wizard Code Reviewer",
		Description: "Reviews JavaScript code carefully",
		Tags:        []string{"react"},
	}
	descHit := models.Agent{
		Title:       "Code Reviewer",
		Description: "A wizard at refactoring legacy modules",
		Tags:        []string{"react"},
	}
	q := "wizard"

	titleScore := scoreAgent(titleHit, q)
	descScore := scoreAgent(descHit, q)
	assert.Greater(t, titleScore, descScore, "title hit must outscore description hit (3× vs 1×)")
}

func TestScoreAgent_TagOutweighsDescription(t *testing.T) {
	tagHit := models.Agent{
		Title:       "Frontend Helper",
		Description: "Builds components",
		Tags:        []string{"react", "typescript"},
	}
	descHit := models.Agent{
		Title:       "Frontend Helper",
		Description: "Helps build react components in plain text",
		Tags:        []string{"javascript"},
	}
	q := "react"

	tagScore := scoreAgent(tagHit, q)
	descScore := scoreAgent(descHit, q)
	assert.Greater(t, tagScore, descScore, "tag hit must outscore description hit (2× vs 1×)")
}

func TestScoreAgent_FuzzyTypoMatches(t *testing.T) {
	// "wziard" is a transposition of "wizard" — Levenshtein dist 2 / max 6 = 0.667 sim.
	// Pre-filter (P1-9) requires at least one query token to be a literal title hit
	// before fuzzy scoring kicks in — "backend" satisfies that, so "wziard" still
	// scores via the Levenshtein fallback against the title's "wizard" word.
	a := models.Agent{Title: "Wizard of Backend"}
	score := scoreAgent(a, "wziard backend")
	assert.Greater(t, score, 0.0, "fuzzy match should produce non-zero score")
	// Confirm Levenshtein similarity sits above the configured threshold.
	assert.GreaterOrEqual(t, levenshteinSimilarity("wziard", "wizard"), fuzzyThreshold)
}

func TestScoreAgent_FuzzySkippedWithoutTitleLiteralHit(t *testing.T) {
	// Pre-filter (P1-9): a candidate whose title contains zero literal token hits
	// must NOT be scored via Levenshtein. Substring scoring in tags/desc still applies.
	a := models.Agent{Title: "Database Helper", Description: "no relevance"}
	// "wziard" is not literally in title, no other field has any token —
	// fuzzy disabled, expect zero score.
	assert.Equal(t, 0.0, scoreAgent(a, "wziard"))
}

func TestTokenize_CapsAtMaxQueryTokens(t *testing.T) {
	// P1-9: queries beyond maxQueryTokens are truncated to keep DP work bounded.
	got := tokenize("alpha beta gamma delta epsilon zeta eta theta")
	assert.Len(t, got, maxQueryTokens, "tokenize must cap at maxQueryTokens")
	assert.Equal(t, []string{"alpha", "beta", "gamma", "delta", "epsilon"}, got)
}

func TestRankAgentsByQuery_LongQueryStillCorrect(t *testing.T) {
	// 10-token query against a 5-row fixture: tokenize caps at 5, but the strongest
	// title hit must still rank first.
	agents := []models.Agent{
		{Title: "Random Helper"},
		{Title: "Wizard Architect"},
		{Title: "Backend Helper"},
		{Title: "Database Helper"},
		{Title: "Frontend Helper"},
	}
	ranked := rankAgentsByQuery(agents, "wizard alpha beta gamma delta epsilon zeta eta theta iota")
	assert.Equal(t, "Wizard Architect", ranked[0].Title)
	assert.Len(t, ranked, 5, "ranker must keep all candidates regardless of query length")
}

func TestScoreAgent_EmptyQueryZero(t *testing.T) {
	a := models.Agent{Title: "Wizard", Description: "Magic things", Tags: []string{"x"}}
	assert.Equal(t, 0.0, scoreAgent(a, ""))
	assert.Equal(t, 0.0, scoreAgent(a, "   "))
}

func TestScoreAgent_MultiTokenAdditive(t *testing.T) {
	a := models.Agent{
		Title:       "Wizard Code Reviewer",
		Description: "review",
		Tags:        []string{"backend"},
	}
	single := scoreAgent(a, "wizard")
	double := scoreAgent(a, "wizard backend")
	assert.Greater(t, double, single, "two matched tokens must outscore one")
}

func TestScoreAgent_CaseInsensitive(t *testing.T) {
	a := models.Agent{Title: "Wizard"}
	low := scoreAgent(a, "wizard")
	up := scoreAgent(a, "WIZARD")
	mix := scoreAgent(a, "WiZaRd")
	assert.Equal(t, low, up)
	assert.Equal(t, low, mix)
}

func TestTokenize_DedupesAndLowercases(t *testing.T) {
	got := tokenize("  Foo  BAR foo  bar  ")
	assert.Equal(t, []string{"foo", "bar"}, got, "dedup preserving first-seen order, lowercase")
}

func TestTokenize_EmptyAndWhitespace(t *testing.T) {
	assert.Nil(t, tokenize(""))
	assert.Nil(t, tokenize("   "))
}

func TestRankAgentsByQuery_TopNStable(t *testing.T) {
	agents := []models.Agent{
		{Title: "Random Helper", Description: "no relevance"},
		{Title: "Wizard Architect", Description: "wizard things"},      // big title hit
		{Title: "Backend Helper", Description: "wizard appears here"},  // desc hit only
		{Title: "Database Helper", Description: "no wizard mention"},
	}
	ranked := rankAgentsByQuery(agents, "wizard")
	assert.Equal(t, "Wizard Architect", ranked[0].Title, "highest-scoring agent first")
	assert.Equal(t, "Backend Helper", ranked[1].Title, "weaker hit second")
	assert.Len(t, ranked, 4, "ranker must not drop zero-score rows")
}
