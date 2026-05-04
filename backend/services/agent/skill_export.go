package agent

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/agentstore/backend/pkg/models"
)

// SkillSlug converts an agent title to OpenClaw's kebab-case skill name.
// Mirrors Flutter's ClaudeExportService._slugify exactly:
//   - lowercase, strip non-alphanumeric/space/dash, collapse spaces→dash, max 50, trim trailing dash.
func SkillSlug(title string) string {
	lower := strings.ToLower(title)
	stripped := regexp.MustCompile(`[^a-z0-9\s-]`).ReplaceAllString(lower, "")
	trimmed := strings.TrimSpace(stripped)
	dashed := regexp.MustCompile(`\s+`).ReplaceAllString(trimmed, "-")
	if len([]rune(dashed)) > 50 {
		dashed = string([]rune(dashed)[:50])
	}
	return strings.TrimRight(dashed, "-")
}

// BuildSkillMd serialises an agent as an OpenClaw-compatible SKILL.md string.
// The format is:
//
//	---
//	<YAML frontmatter>
//	---
//
//	# Title
//
//	<prompt verbatim>
func BuildSkillMd(agent *models.Agent) string {
	slug := SkillSlug(agent.Title)

	// Single-line description, truncated at 200 chars, escaping YAML special chars
	desc := singleLine(agent.Description)
	if len([]rune(desc)) > 200 {
		desc = string([]rune(desc)[:197]) + "..."
	}
	desc = strings.ReplaceAll(desc, `"`, `\"`)

	// when_to_use: prefer ServiceDescription, fall back to a one-liner
	whenToUse := strings.TrimSpace(agent.ServiceDescription)
	if whenToUse == "" {
		whenToUse = fmt.Sprintf("Use for %s tasks (%s, %s).",
			strings.ToLower(agent.Category),
			agent.CharacterType,
			string(agent.Rarity))
	}
	// Indent continuation lines for YAML block scalar
	whenToUse = indentBlockScalar(whenToUse)

	// Tags: emit as YAML inline list
	tagList := yamlStringList(agent.Tags)

	// Build frontmatter manually (no external YAML dep, same approach as existing parsers)
	var sb strings.Builder
	sb.WriteString("---\n")
	sb.WriteString(fmt.Sprintf("name: %s\n", slug))
	sb.WriteString(fmt.Sprintf("description: \"%s\"\n", desc))
	sb.WriteString("version: 1.0.0\n")
	sb.WriteString("when_to_use: |\n")
	sb.WriteString(whenToUse)
	sb.WriteString("model: opus\n")
	sb.WriteString("metadata:\n")
	sb.WriteString("  openclaw:\n")
	sb.WriteString("    requires:\n")
	sb.WriteString("      env: []\n")
	sb.WriteString("      bins: []\n")
	sb.WriteString("agent_store:\n")
	sb.WriteString(fmt.Sprintf("  id: %d\n", agent.ID))
	sb.WriteString(fmt.Sprintf("  url: https://agentstore.xyz/agent/%d\n", agent.ID))
	sb.WriteString(fmt.Sprintf("  character_type: %s\n", agent.CharacterType))
	sb.WriteString(fmt.Sprintf("  subclass: %s\n", agent.Subclass))
	sb.WriteString(fmt.Sprintf("  rarity: %s\n", string(agent.Rarity)))
	sb.WriteString(fmt.Sprintf("  category: %s\n", agent.Category))
	sb.WriteString(fmt.Sprintf("  tags: %s\n", tagList))
	sb.WriteString("---\n")
	sb.WriteString("\n")
	sb.WriteString(fmt.Sprintf("# %s\n", agent.Title))
	sb.WriteString("\n")
	sb.WriteString(agent.Prompt)
	if !strings.HasSuffix(agent.Prompt, "\n") {
		sb.WriteString("\n")
	}

	return sb.String()
}

// ── helpers ──────────────────────────────────────────────────────────────────

// singleLine replaces newlines with a single space.
func singleLine(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

// indentBlockScalar prefixes every line with two spaces (YAML block scalar body).
// Returns empty string as empty block (just a trailing newline).
func indentBlockScalar(s string) string {
	lines := strings.Split(s, "\n")
	var sb strings.Builder
	for _, l := range lines {
		sb.WriteString("  ")
		sb.WriteString(l)
		sb.WriteString("\n")
	}
	return sb.String()
}

// yamlStringList builds an inline YAML list from a string slice: [a, b, c]
func yamlStringList(tags []string) string {
	if len(tags) == 0 {
		return "[]"
	}
	quoted := make([]string, len(tags))
	for i, t := range tags {
		quoted[i] = fmt.Sprintf("%q", t)
	}
	return "[" + strings.Join(quoted, ", ") + "]"
}
