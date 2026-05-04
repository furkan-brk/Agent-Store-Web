package guild

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/guild/client"
)

// GuildMasterService handles AI-powered guild suggestions and team chat.
type GuildMasterService struct {
	aiClient *client.AIClient
}

// NewGuildMasterService creates a new GuildMasterService.
func NewGuildMasterService(aiClient *client.AIClient) *GuildMasterService {
	return &GuildMasterService{aiClient: aiClient}
}

// PlanStep is one step in the suggested action plan returned by the
// Guild Master. Step numbers are 1-indexed for UI display.
type PlanStep struct {
	Step        int    `json:"step"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
}

// OwnerAssignment ties a character type to a concrete responsibility on the
// recommended team. The Type field always matches one of the canonical
// character types (wizard, strategist, …) so the UI can render the matching
// pixel-art icon next to the responsibility text.
type OwnerAssignment struct {
	Type           string `json:"type"`
	Role           string `json:"role"`
	Responsibility string `json:"responsibility"`
}

// MatchingAgent embeds models.Agent so the JSON contract for existing
// fields (id, title, character_type, …) is unchanged, then layers v3.8
// explainability on top:
//
//   - Reason: one-line "why was this agent picked" string
//   - Confidence: 0.0–1.0 score from rankCandidates' composite formula
//   - Contribution: human-readable role (e.g. "Code Architect") so the UI
//     can show what the agent is meant to do without re-deriving from type
type MatchingAgent struct {
	models.Agent
	Reason       string  `json:"reason,omitempty"`
	Confidence   float64 `json:"confidence,omitempty"`
	Contribution string  `json:"contribution,omitempty"`
}

// GuildSuggestion holds the recommendation response.
//
// v3.8 adds the structured explainability block (Goal/Plan/Owners/Risks/
// SuccessCriteria/ConfidencePerType) on top of the legacy free-form
// Reasoning + PriorityTags. New fields are all `omitempty` so older AI
// providers that still return only the legacy shape stay compatible.
type GuildSuggestion struct {
	// ── Legacy fields (preserved for backward compat) ──
	RecommendedTypes []string          `json:"recommended_types"`
	MatchingAgents   []MatchingAgent   `json:"matching_agents"`
	Reasoning        string            `json:"reasoning"`
	SuggestedName    string            `json:"suggested_name"`
	ReasoningPerType map[string]string `json:"reasoning_per_type,omitempty"`
	PriorityTags     []string          `json:"priority_tags,omitempty"`

	// ── v3.8 structured explainability block ──
	Goal              string             `json:"goal,omitempty"`
	Plan              []PlanStep         `json:"plan,omitempty"`
	Owners            []OwnerAssignment  `json:"owners,omitempty"`
	Risks             []string           `json:"risks,omitempty"`
	SuccessCriteria   []string           `json:"success_criteria,omitempty"`
	ConfidencePerType map[string]float64 `json:"confidence_per_type,omitempty"`
}

// MemberResponse holds one agent's reply in a team chat.
type MemberResponse struct {
	AgentID       uint   `json:"agent_id"`
	AgentTitle    string `json:"agent_title"`
	CharacterType string `json:"character_type"`
	Role          string `json:"role"`
	Reply         string `json:"reply"`
}

var validCharacterTypes = []string{
	"wizard", "strategist", "oracle", "guardian", "artisan", "bard", "scholar", "merchant",
}

type typeRecommendation struct {
	Types            []string          `json:"recommended_types"`
	Reasoning        string            `json:"reasoning"`
	SuggestedName    string            `json:"suggested_name"`
	ReasoningPerType map[string]string `json:"reasoning_per_type"`
	PriorityTags     []string          `json:"priority_tags"`

	// v3.8 structured fields. May be empty when the AI provider falls
	// back to the legacy shape — SuggestGuild copes with both.
	Goal              string             `json:"goal"`
	Plan              []PlanStep         `json:"plan"`
	Owners            []OwnerAssignment  `json:"owners"`
	Risks             []string           `json:"risks"`
	SuccessCriteria   []string           `json:"success_criteria"`
	ConfidencePerType map[string]float64 `json:"confidence_per_type"`
}

// SuggestGuild recommends character types and matching agents for a problem.
//
// v3.8: Each MatchingAgent now carries its composite Confidence (0..1) and
// a one-line Reason ("type X fits because …" or fallback to type rationale)
// plus the human-readable Contribution (e.g. "Code Architect"). The whole
// structured block (Goal/Plan/Owners/Risks/SuccessCriteria/ConfidencePerType)
// flows from the AI through into the response so the UI can render the
// suggest panel without any client-side scoring logic.
func (s *GuildMasterService) SuggestGuild(problem string) (*GuildSuggestion, error) {
	rec := s.suggestTypesViaAI(problem)

	problemKeywords := extractKeywords(problem)

	const maxAgents = 4
	matches := make([]MatchingAgent, 0, maxAgents)
	seen := map[uint]bool{}

	for _, t := range rec.Types {
		if len(matches) >= maxAgents {
			break
		}

		var candidates []models.Agent
		err := database.DB.
			Where("character_type = ?", t).
			Order("(prompt_score * 4 + use_count * 3 + save_count * 2) DESC").
			Limit(6).
			Find(&candidates).Error
		if err != nil {
			continue
		}

		scored := rankCandidates(candidates, problemKeywords, rec.PriorityTags)

		added := 0
		for _, sc := range scored {
			if len(matches) >= maxAgents || added >= 2 {
				break
			}
			if seen[sc.agent.ID] {
				continue
			}
			seen[sc.agent.ID] = true
			added++

			// Reason: prefer per-type rationale from the AI, fall back to
			// the agent title so the panel never shows "" in production.
			reason := strings.TrimSpace(rec.ReasoningPerType[t])
			if reason == "" {
				reason = fmt.Sprintf("Strong %s match for %s.", t, sc.agent.Title)
			}
			matches = append(matches, MatchingAgent{
				Agent:        sc.agent,
				Reason:       reason,
				Confidence:   roundConfidence(sc.score),
				Contribution: deriveRole(sc.agent),
			})
		}
	}

	return &GuildSuggestion{
		RecommendedTypes:  rec.Types,
		MatchingAgents:    matches,
		Reasoning:         rec.Reasoning,
		SuggestedName:     rec.SuggestedName,
		ReasoningPerType:  rec.ReasoningPerType,
		PriorityTags:      rec.PriorityTags,
		Goal:              rec.Goal,
		Plan:              rec.Plan,
		Owners:            rec.Owners,
		Risks:             rec.Risks,
		SuccessCriteria:   rec.SuccessCriteria,
		ConfidencePerType: rec.ConfidencePerType,
	}, nil
}

// roundConfidence rounds the composite score to 2 decimal places to keep
// JSON payloads tidy and avoid showing things like "0.7321428571" in the UI.
func roundConfidence(score float64) float64 {
	if score < 0 {
		return 0
	}
	if score > 1 {
		return 1
	}
	return math.Round(score*100) / 100
}

// TeamChat sends the user's message to each agent via the AI Pipeline.
func (s *GuildMasterService) TeamChat(message string, agentIDs []uint) ([]MemberResponse, error) {
	if len(agentIDs) > 4 {
		agentIDs = agentIDs[:4]
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	responses := make([]MemberResponse, 0, len(agentIDs))
	for _, id := range agentIDs {
		var agent models.Agent
		if err := database.DB.First(&agent, id).Error; err != nil {
			continue
		}

		role := deriveRole(agent)
		systemPrompt := fmt.Sprintf(
			"%s\n\nYou are %s, a %s specialist on this team. Your role: %s. Respond concisely from your specialized perspective.",
			agent.Prompt, agent.Title, agent.CharacterType, role,
		)

		reply, err := s.aiClient.Chat(ctx, systemPrompt, message)
		if err != nil {
			reply = fmt.Sprintf("[%s is unavailable right now]", agent.Title)
		}

		responses = append(responses, MemberResponse{
			AgentID:       agent.ID,
			AgentTitle:    agent.Title,
			CharacterType: agent.CharacterType,
			Role:          role,
			Reply:         reply,
		})
	}
	return responses, nil
}

func deriveRole(agent models.Agent) string {
	roleMap := map[string]string{
		"wizard":     "Code Architect",
		"strategist": "Project Lead",
		"oracle":     "Data Analyst",
		"guardian":   "Security Expert",
		"artisan":    "UI/UX Designer",
		"bard":       "Creative Writer",
		"scholar":    "Researcher",
		"merchant":   "Business Strategist",
	}
	if role, ok := roleMap[agent.CharacterType]; ok {
		return role
	}
	return "Specialist"
}

func (s *GuildMasterService) suggestTypesViaAI(problem string) typeRecommendation {
	// v3.8 structured prompt: tells the model to emit Goal/Plan/Owners/
	// Risks/SuccessCriteria/ConfidencePerType in addition to the legacy
	// fields. The defensive parser below tolerates models that still only
	// emit the legacy subset (older Gemini Flash builds, fallback paths).
	systemPrompt := `You are a Guild Master AI that recommends the best team composition for problems.
Given a problem description, recommend 2-3 character types from this list:
wizard (backend/code), strategist (planning/PM), oracle (data/analytics),
guardian (security/infra), artisan (frontend/design), bard (creative/writing),
scholar (research/education), merchant (business/marketing).

Produce a structured plan that explains the recommendation:
- goal: one sentence rephrasing what success looks like.
- plan: 3-5 ordered steps (each: step number, short title, one-line description).
- owners: for each recommended type, the role and concrete responsibility.
- risks: 2-3 things that could derail the work.
- success_criteria: 2-4 measurable bullets ("X is shipped", "Y under N ms", …).
- confidence_per_type: 0.0–1.0 for how strongly each recommended type fits.
- priority_tags: 3-5 lowercase tags that help the matcher rank candidate agents.

Respond with VALID JSON only, no markdown fences. Shape:
{
  "recommended_types":["type1","type2"],
  "reasoning":"overall one-paragraph explanation",
  "suggested_name":"Creative Team Name",
  "reasoning_per_type":{"type1":"why type1 is needed","type2":"why type2 is needed"},
  "priority_tags":["tag1","tag2","tag3"],
  "goal":"…",
  "plan":[{"step":1,"title":"…","description":"…"},{"step":2,"title":"…","description":"…"}],
  "owners":[{"type":"type1","role":"Code Architect","responsibility":"…"},{"type":"type2","role":"Project Lead","responsibility":"…"}],
  "risks":["…","…"],
  "success_criteria":["…","…"],
  "confidence_per_type":{"type1":0.9,"type2":0.7}
}`

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	reply, err := s.aiClient.Chat(ctx, systemPrompt, fmt.Sprintf("Problem: %s", problem))
	if err == nil {
		var parsed typeRecommendation
		start := strings.Index(reply, "{")
		end := strings.LastIndex(reply, "}")
		if start >= 0 && end > start {
			if jsonErr := json.Unmarshal([]byte(reply[start:end+1]), &parsed); jsonErr == nil {
				valid := filterValidTypes(parsed.Types)
				if len(valid) > 0 {
					filteredReasoning := make(map[string]string, len(valid))
					for _, t := range valid {
						if r, ok := parsed.ReasoningPerType[t]; ok {
							filteredReasoning[t] = r
						}
					}
					filteredConfidence := filterConfidencePerType(parsed.ConfidencePerType, valid)
					tags := sanitizeTags(parsed.PriorityTags)
					return typeRecommendation{
						Types:             valid,
						Reasoning:         parsed.Reasoning,
						SuggestedName:     parsed.SuggestedName,
						ReasoningPerType:  filteredReasoning,
						PriorityTags:      tags,
						Goal:              strings.TrimSpace(parsed.Goal),
						Plan:              normalisePlan(parsed.Plan),
						Owners:            filterOwners(parsed.Owners, valid),
						Risks:             trimStrings(parsed.Risks),
						SuccessCriteria:   trimStrings(parsed.SuccessCriteria),
						ConfidencePerType: filteredConfidence,
					}
				}
			}
		}
	}

	types := keywordFallback(problem)
	return typeRecommendation{
		Types:         types,
		Reasoning:     "Based on keyword analysis of your problem.",
		SuggestedName: "Custom Squad",
	}
}

// filterConfidencePerType clamps confidence values to [0,1] and drops
// entries that don't match a recommended type. AI providers occasionally
// return out-of-range numbers (e.g. 0..100 percentages) — we coerce
// anything > 1 by assuming it was a percentage.
func filterConfidencePerType(raw map[string]float64, validTypes []string) map[string]float64 {
	if len(raw) == 0 {
		return nil
	}
	allowed := make(map[string]bool, len(validTypes))
	for _, t := range validTypes {
		allowed[t] = true
	}
	out := make(map[string]float64, len(validTypes))
	for k, v := range raw {
		k = strings.ToLower(strings.TrimSpace(k))
		if !allowed[k] {
			continue
		}
		if v > 1 && v <= 100 {
			v = v / 100.0
		}
		if v < 0 {
			v = 0
		}
		if v > 1 {
			v = 1
		}
		out[k] = v
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// normalisePlan re-numbers plan steps to 1..N and drops empty entries so
// the UI can render a stable ordered list. AI providers sometimes start
// from 0 or skip numbers; the field is too small to gate the whole
// suggestion on, so we just normalise instead of rejecting.
func normalisePlan(plan []PlanStep) []PlanStep {
	if len(plan) == 0 {
		return nil
	}
	out := make([]PlanStep, 0, len(plan))
	for i, p := range plan {
		title := strings.TrimSpace(p.Title)
		if title == "" {
			continue
		}
		out = append(out, PlanStep{
			Step:        i + 1,
			Title:       title,
			Description: strings.TrimSpace(p.Description),
		})
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// filterOwners keeps only owner entries whose Type matches one of the
// recommended types. Drops empty Role/Responsibility slots so the UI
// doesn't render half-blank cards.
func filterOwners(owners []OwnerAssignment, validTypes []string) []OwnerAssignment {
	if len(owners) == 0 {
		return nil
	}
	allowed := make(map[string]bool, len(validTypes))
	for _, t := range validTypes {
		allowed[t] = true
	}
	out := make([]OwnerAssignment, 0, len(owners))
	for _, o := range owners {
		t := strings.ToLower(strings.TrimSpace(o.Type))
		if !allowed[t] {
			continue
		}
		role := strings.TrimSpace(o.Role)
		resp := strings.TrimSpace(o.Responsibility)
		if role == "" && resp == "" {
			continue
		}
		out = append(out, OwnerAssignment{Type: t, Role: role, Responsibility: resp})
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// trimStrings strips whitespace and drops empty entries from a list.
// Used to clean up risks / success_criteria payloads from the AI.
func trimStrings(in []string) []string {
	if len(in) == 0 {
		return nil
	}
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(s)
		if s != "" {
			out = append(out, s)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// --- Scoring & keyword utilities ---

type scoredAgent struct {
	agent models.Agent
	score float64
}

func rankCandidates(candidates []models.Agent, problemKeywords, priorityTags []string) []scoredAgent {
	if len(candidates) == 0 {
		return nil
	}
	scored := make([]scoredAgent, 0, len(candidates))
	for _, agent := range candidates {
		qualityScore := float64(agent.PromptScore) / 100.0
		useScore := math.Log1p(float64(agent.UseCount))
		saveScore := math.Log1p(float64(agent.SaveCount))
		const logCeiling = 6.9
		useNorm := math.Min(useScore/logCeiling, 1.0)
		saveNorm := math.Min(saveScore/logCeiling, 1.0)
		tagOverlap := computeTagOverlap(agent.Tags, problemKeywords, priorityTags)
		composite := qualityScore*0.4 + useNorm*0.3 + saveNorm*0.2 + tagOverlap*0.1
		scored = append(scored, scoredAgent{agent: agent, score: composite})
	}
	for i := 1; i < len(scored); i++ {
		for j := i; j > 0 && scored[j].score > scored[j-1].score; j-- {
			scored[j], scored[j-1] = scored[j-1], scored[j]
		}
	}
	return scored
}

func computeTagOverlap(agentTags []string, problemKeywords, priorityTags []string) float64 {
	if len(agentTags) == 0 {
		return 0
	}
	tagSet := make(map[string]bool, len(agentTags))
	for _, t := range agentTags {
		tagSet[strings.ToLower(strings.TrimSpace(t))] = true
	}
	allTerms := make([]string, 0, len(problemKeywords)+len(priorityTags))
	allTerms = append(allTerms, problemKeywords...)
	allTerms = append(allTerms, priorityTags...)
	if len(allTerms) == 0 {
		return 0
	}
	matches := 0
	for _, kw := range allTerms {
		if tagSet[kw] {
			matches++
			continue
		}
		for tag := range tagSet {
			if strings.Contains(tag, kw) || strings.Contains(kw, tag) {
				matches++
				break
			}
		}
	}
	return math.Min(float64(matches)/float64(len(allTerms)), 1.0)
}

func extractKeywords(problem string) []string {
	stopWords := map[string]bool{
		"a": true, "an": true, "the": true, "is": true, "are": true,
		"was": true, "were": true, "be": true, "been": true, "being": true,
		"have": true, "has": true, "had": true, "do": true, "does": true,
		"did": true, "will": true, "would": true, "shall": true, "should": true,
		"may": true, "might": true, "must": true, "can": true, "could": true,
		"i": true, "me": true, "my": true, "we": true, "our": true,
		"you": true, "your": true, "he": true, "she": true, "it": true,
		"they": true, "them": true, "its": true, "his": true, "her": true,
		"to": true, "of": true, "in": true, "for": true, "on": true,
		"with": true, "at": true, "by": true, "from": true, "as": true,
		"into": true, "about": true, "that": true, "this": true, "and": true,
		"or": true, "but": true, "if": true, "not": true, "no": true,
		"so": true, "up": true, "out": true, "then": true, "than": true,
		"too": true, "very": true, "just": true, "how": true, "what": true,
		"when": true, "where": true, "which": true, "who": true, "why": true,
		"need": true, "want": true, "help": true, "like": true, "get": true,
		"make": true, "use": true, "also": true, "each": true, "all": true,
		"some": true, "any": true, "more": true, "most": true, "other": true,
	}
	cleaned := strings.NewReplacer(
		",", " ", ".", " ", "!", " ", "?", " ",
		"(", " ", ")", " ", "[", " ", "]", " ",
		":", " ", ";", " ", "\"", " ", "'", " ",
	).Replace(strings.ToLower(problem))
	words := strings.Fields(cleaned)
	seen := map[string]bool{}
	keywords := make([]string, 0, len(words)/2)
	for _, w := range words {
		if len(w) < 3 || stopWords[w] || seen[w] {
			continue
		}
		seen[w] = true
		keywords = append(keywords, w)
	}
	return keywords
}

func sanitizeTags(tags []string) []string {
	if len(tags) == 0 {
		return nil
	}
	seen := map[string]bool{}
	result := make([]string, 0, len(tags))
	for _, t := range tags {
		t = strings.ToLower(strings.TrimSpace(t))
		if t != "" && !seen[t] {
			seen[t] = true
			result = append(result, t)
		}
	}
	return result
}

func filterValidTypes(types []string) []string {
	valid := make([]string, 0, len(types))
	typeSet := map[string]bool{}
	for _, t := range validCharacterTypes {
		typeSet[t] = true
	}
	for _, t := range types {
		t = strings.ToLower(strings.TrimSpace(t))
		if typeSet[t] {
			valid = append(valid, t)
		}
	}
	return valid
}

func keywordFallback(problem string) []string {
	lower := strings.ToLower(problem)
	keywords := map[string][]string{
		"wizard":     {"code", "programming", "backend", "api", "database", "software"},
		"strategist": {"plan", "project", "manage", "strategy", "roadmap", "business"},
		"oracle":     {"data", "analytics", "ml", "machine learning", "ai", "analysis"},
		"guardian":   {"security", "infra", "devops", "deploy", "server", "cloud"},
		"artisan":    {"frontend", "design", "ui", "ux", "interface", "visual"},
		"bard":       {"write", "content", "creative", "blog", "copy", "story"},
		"scholar":    {"research", "learn", "study", "education", "document"},
		"merchant":   {"market", "sales", "growth", "business", "revenue", "customer"},
	}
	results := []string{}
	for charType, kws := range keywords {
		for _, kw := range kws {
			if strings.Contains(lower, kw) {
				results = append(results, charType)
				break
			}
		}
		if len(results) >= 3 {
			break
		}
	}
	if len(results) == 0 {
		return []string{"wizard", "strategist", "oracle"}
	}
	return results
}
