package agent

import (
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/agentstore/backend/pkg/models"
)

// ── SkillSlug tests ───────────────────────────────────────────────────────────

func TestSkillSlug_Basic(t *testing.T) {
	cases := []struct {
		input string
		want  string
	}{
		{"My Cool Agent", "my-cool-agent"},
		{"Hello World", "hello-world"},
		{"already-dashed", "already-dashed"},
		{"UPPERCASE TITLE", "uppercase-title"},
		{"title with  extra   spaces", "title-with-extra-spaces"},
		{"title-with-trailing-dash-", "title-with-trailing-dash"},
	}
	for _, tc := range cases {
		got := SkillSlug(tc.input)
		if got != tc.want {
			t.Errorf("SkillSlug(%q) = %q; want %q", tc.input, got, tc.want)
		}
	}
}

func TestSkillSlug_SpecialChars(t *testing.T) {
	cases := []struct {
		input string
		want  string
	}{
		{"Agent #1!", "agent-1"},
		{"foo@bar.baz", "foobarbaz"},
		{"  leading and trailing  ", "leading-and-trailing"},
		{"em—dash title", "emdash-title"},
		{"100% accurate", "100-accurate"},
	}
	for _, tc := range cases {
		got := SkillSlug(tc.input)
		if got != tc.want {
			t.Errorf("SkillSlug(%q) = %q; want %q", tc.input, got, tc.want)
		}
	}
}

func TestSkillSlug_MaxLength(t *testing.T) {
	long := strings.Repeat("a", 60)
	got := SkillSlug(long)
	if utf8.RuneCountInString(got) > 50 {
		t.Errorf("SkillSlug truncation failed: len=%d for input len=%d", utf8.RuneCountInString(got), len(long))
	}
}

func TestSkillSlug_OnlySymbols(t *testing.T) {
	got := SkillSlug("!@#$%^&*()")
	// After stripping, nothing left — should return empty string without panic
	if strings.Contains(got, " ") {
		t.Errorf("SkillSlug with only symbols returned spaces: %q", got)
	}
}

// ── BuildSkillMd tests ────────────────────────────────────────────────────────

func makeTestAgent() *models.Agent {
	return &models.Agent{
		Title:              "My Test Agent",
		Description:        "A test agent for unit testing",
		Prompt:             "You are a helpful test agent.\nRespond clearly.",
		Category:           "Development",
		CharacterType:      "Wizard",
		Subclass:           "Arcane",
		Rarity:             "Epic",
		Tags:               []string{"test", "wizard", "dev"},
		ServiceDescription: "Use when you need to test things.",
	}
	// Note: ID defaults to 0 in tests (no DB)
}

func TestBuildSkillMd_HasFrontmatter(t *testing.T) {
	a := makeTestAgent()
	md := BuildSkillMd(a)

	if !strings.HasPrefix(md, "---\n") {
		t.Error("SKILL.md must start with ---")
	}
	// Must have a closing --- after the opening one
	rest := md[4:]
	if !strings.Contains(rest, "---\n") {
		t.Error("SKILL.md frontmatter must be closed by ---")
	}
}

func TestBuildSkillMd_ContainsRequiredFields(t *testing.T) {
	a := makeTestAgent()
	md := BuildSkillMd(a)

	requiredFields := []string{
		"name: my-test-agent",
		"description:",
		"version: 1.0.0",
		"when_to_use:",
		"model: opus",
		"metadata:",
		"  openclaw:",
		"agent_store:",
		"  character_type: Wizard",
		"  subclass: Arcane",
		"  rarity: Epic",
		"  category: Development",
		`  tags: ["test", "wizard", "dev"]`,
	}

	for _, field := range requiredFields {
		if !strings.Contains(md, field) {
			t.Errorf("SKILL.md missing expected field %q", field)
		}
	}
}

func TestBuildSkillMd_PromptPreserved(t *testing.T) {
	a := makeTestAgent()
	md := BuildSkillMd(a)

	// Prompt must appear verbatim after the closing ---
	parts := strings.SplitN(md, "---\n", 3)
	if len(parts) < 3 {
		t.Fatal("could not split frontmatter from body")
	}
	body := parts[2]
	if !strings.Contains(body, a.Prompt) {
		t.Errorf("prompt not preserved in body.\nBody:\n%s", body)
	}
}

func TestBuildSkillMd_TitleInBody(t *testing.T) {
	a := makeTestAgent()
	md := BuildSkillMd(a)
	if !strings.Contains(md, "# My Test Agent\n") {
		t.Error("body must contain '# <Title>' heading")
	}
}

func TestBuildSkillMd_PromptEndsWithNewline(t *testing.T) {
	a := makeTestAgent()
	a.Prompt = "No trailing newline"
	md := BuildSkillMd(a)
	if !strings.HasSuffix(md, "\n") {
		t.Error("SKILL.md must end with newline even when prompt has none")
	}
}

func TestBuildSkillMd_PromptWithTripleDash(t *testing.T) {
	// Prompts that contain --- shouldn't break the frontmatter parser.
	// The format relies on exactly two --- delimiters; body content is free-form.
	a := makeTestAgent()
	a.Prompt = "Step 1\n---\nStep 2\n---\nDone"
	md := BuildSkillMd(a)

	// First two --- occurrences are frontmatter; remaining are prompt content.
	parts := strings.SplitN(md, "---\n", 3)
	if len(parts) < 3 {
		t.Fatal("frontmatter split failed")
	}
	body := parts[2]
	if !strings.Contains(body, "---\nStep 2") {
		t.Errorf("triple-dash in prompt not preserved: %s", body)
	}
}

func TestBuildSkillMd_DescriptionTruncated(t *testing.T) {
	a := makeTestAgent()
	a.Description = strings.Repeat("x", 250)
	md := BuildSkillMd(a)

	// Extract description line from frontmatter
	for _, line := range strings.Split(md, "\n") {
		if strings.HasPrefix(line, "description:") {
			if len([]rune(line)) > 220 { // 200 chars + `description: "` overhead + `..."`
				t.Errorf("description line too long: %d chars", len([]rune(line)))
			}
			break
		}
	}
}

func TestBuildSkillMd_EmptyTagsYield_EmptyList(t *testing.T) {
	a := makeTestAgent()
	a.Tags = nil
	md := BuildSkillMd(a)
	if !strings.Contains(md, "  tags: []") {
		t.Error("empty tags should render as []")
	}
}

func TestBuildSkillMd_ServiceDescriptionFallback(t *testing.T) {
	a := makeTestAgent()
	a.ServiceDescription = ""
	md := BuildSkillMd(a)
	// Should have a non-empty when_to_use block
	if !strings.Contains(md, "when_to_use: |") {
		t.Error("when_to_use block missing")
	}
	if strings.Contains(md, "when_to_use: |\n  \n") {
		t.Error("when_to_use block should not be blank when ServiceDescription is empty")
	}
}

// ── BuildPublicSkillMd tests ─────────────────────────────────────────────────

func TestBuildPublicSkillMd_PromptRedacted(t *testing.T) {
	a := makeTestAgent()
	pub := BuildPublicSkillMd(a)

	// The original (secret) prompt must NOT appear anywhere in the public output.
	if strings.Contains(pub, a.Prompt) {
		t.Errorf("public SKILL.md leaked the real prompt:\n%s", pub)
	}
	// And a purchase-required notice MUST be present in the body.
	if !strings.Contains(pub, "Purchase this agent on Agent Store") {
		t.Errorf("public SKILL.md missing purchase placeholder:\n%s", pub)
	}
	// Caller's input agent should not be mutated by the redacted build.
	if a.Prompt == publicPromptPlaceholder {
		t.Error("BuildPublicSkillMd mutated caller's agent.Prompt — must operate on a copy")
	}
}

func TestBuildPublicSkillMd_FrontmatterPreserved(t *testing.T) {
	a := makeTestAgent()
	full := BuildSkillMd(a)
	pub := BuildPublicSkillMd(a)

	// Both versions must share the same YAML frontmatter (delimited by --- ... ---).
	splitFrontmatter := func(md string) string {
		parts := strings.SplitN(md, "---\n", 3)
		if len(parts) < 3 {
			t.Fatalf("could not split frontmatter from:\n%s", md)
		}
		return parts[1]
	}
	if splitFrontmatter(full) != splitFrontmatter(pub) {
		t.Errorf("frontmatter differs between full and public SKILL.md\nFULL:\n%s\nPUBLIC:\n%s",
			splitFrontmatter(full), splitFrontmatter(pub))
	}

	// Spot-check that critical OpenClaw discovery fields are present in the public version.
	for _, want := range []string{
		"name: my-test-agent",
		"description:",
		"when_to_use:",
		"agent_store:",
		"  character_type: Wizard",
	} {
		if !strings.Contains(pub, want) {
			t.Errorf("public SKILL.md missing %q", want)
		}
	}
}

func TestBuildPublicSkillMd_EndsWithNewline(t *testing.T) {
	a := makeTestAgent()
	a.Prompt = "ignored — will be replaced anyway"
	pub := BuildPublicSkillMd(a)
	if !strings.HasSuffix(pub, "\n") {
		t.Errorf("public SKILL.md must end with a newline, got tail %q", pub[len(pub)-5:])
	}
}
