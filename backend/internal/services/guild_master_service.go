package services

import (
	"encoding/json"
	"fmt"
	"math"
	"strings"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
)

type GuildMasterService struct {
	aiSvc *AIService
}

func NewGuildMasterService(aiSvc *AIService) *GuildMasterService {
	return &GuildMasterService{aiSvc: aiSvc}
}

type GuildSuggestion struct {
	RecommendedTypes []string            `json:"recommended_types"`
	MatchingAgents   []models.Agent      `json:"matching_agents"`
	Reasoning        string              `json:"reasoning"`
	SuggestedName    string              `json:"suggested_name"`
	ReasoningPerType map[string]string   `json:"reasoning_per_type,omitempty"`
	PriorityTags     []string            `json:"priority_tags,omitempty"`
}

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

// typeRecommendation holds the AI response for a single recommended type.
type typeRecommendation struct {
	Types            []string          `json:"recommended_types"`
	Reasoning        string            `json:"reasoning"`
	SuggestedName    string            `json:"suggested_name"`
	ReasoningPerType map[string]string `json:"reasoning_per_type"`
	PriorityTags     []string          `json:"priority_tags"`
}

// SuggestGuild asks Claude to recommend character types for the given problem,
// then fetches the best matching agents using multi-factor scoring.
func (s *GuildMasterService) SuggestGuild(problem string) (*GuildSuggestion, error) {
	rec := s.suggestTypesViaClaude(problem)

	// Extract keywords from the problem for tag-overlap scoring
	problemKeywords := extractKeywords(problem)

	// For each recommended type, find top 2 candidates ranked by multi-factor score
	const maxAgents = 4
	agents := make([]models.Agent, 0, maxAgents)
	seen := map[uint]bool{}

	for _, t := range rec.Types {
		if len(agents) >= maxAgents {
			break
		}

		var candidates []models.Agent
		err := database.DB.
			Where("character_type = ?", t).
			Order("(prompt_score * 4 + use_count * 3 + save_count * 2) DESC").
			Limit(6). // fetch extras so we can re-rank with tag overlap
			Find(&candidates).Error
		if err != nil {
			continue
		}

		// Re-rank candidates by composite score including tag overlap
		scored := rankCandidates(candidates, problemKeywords, rec.PriorityTags)

		added := 0
		for _, sc := range scored {
			if len(agents) >= maxAgents || added >= 2 {
				break
			}
			if !seen[sc.agent.ID] {
				agents = append(agents, sc.agent)
				seen[sc.agent.ID] = true
				added++
			}
		}
	}

	return &GuildSuggestion{
		RecommendedTypes: rec.Types,
		MatchingAgents:   agents,
		Reasoning:        rec.Reasoning,
		SuggestedName:    rec.SuggestedName,
		ReasoningPerType: rec.ReasoningPerType,
		PriorityTags:     rec.PriorityTags,
	}, nil
}

// scoredAgent pairs an agent with its computed relevance score.
type scoredAgent struct {
	agent models.Agent
	score float64
}

// rankCandidates scores and sorts agents by a weighted composite of quality,
// usage, community trust, and tag relevance to the problem.
func rankCandidates(candidates []models.Agent, problemKeywords, priorityTags []string) []scoredAgent {
	if len(candidates) == 0 {
		return nil
	}

	scored := make([]scoredAgent, 0, len(candidates))
	for _, agent := range candidates {
		// Normalize prompt_score (0-100 range) to 0-1
		qualityScore := float64(agent.PromptScore) / 100.0

		// Log-scale use_count and save_count to prevent high-count agents from
		// dominating. log1p(x) keeps zero values at 0.
		useScore := math.Log1p(float64(agent.UseCount))
		saveScore := math.Log1p(float64(agent.SaveCount))

		// Normalize log scores relative to a reasonable ceiling
		// (log1p(1000) ~ 6.9 is a very popular agent)
		const logCeiling = 6.9
		useNorm := math.Min(useScore/logCeiling, 1.0)
		saveNorm := math.Min(saveScore/logCeiling, 1.0)

		// Tag overlap: count how many problem keywords or priority tags appear
		// in the agent's tags
		tagOverlap := computeTagOverlap(agent.Tags, problemKeywords, priorityTags)

		// Weighted composite
		composite := qualityScore*0.4 + useNorm*0.3 + saveNorm*0.2 + tagOverlap*0.1

		scored = append(scored, scoredAgent{agent: agent, score: composite})
	}

	// Sort descending by score (insertion sort is fine for <= 6 elements)
	for i := 1; i < len(scored); i++ {
		for j := i; j > 0 && scored[j].score > scored[j-1].score; j-- {
			scored[j], scored[j-1] = scored[j-1], scored[j]
		}
	}

	return scored
}

// computeTagOverlap returns a 0-1 score reflecting how well the agent's tags
// match the problem keywords and AI-suggested priority tags.
func computeTagOverlap(agentTags []string, problemKeywords, priorityTags []string) float64 {
	if len(agentTags) == 0 {
		return 0
	}

	// Build a set of lowercased agent tags for O(1) lookup
	tagSet := make(map[string]bool, len(agentTags))
	for _, t := range agentTags {
		tagSet[strings.ToLower(strings.TrimSpace(t))] = true
	}

	// Merge problem keywords and priority tags, count matches
	allTerms := make([]string, 0, len(problemKeywords)+len(priorityTags))
	allTerms = append(allTerms, problemKeywords...)
	allTerms = append(allTerms, priorityTags...)

	if len(allTerms) == 0 {
		return 0
	}

	matches := 0
	for _, kw := range allTerms {
		// Check exact match
		if tagSet[kw] {
			matches++
			continue
		}
		// Check substring match (e.g., keyword "api" matches tag "api-design")
		for tag := range tagSet {
			if strings.Contains(tag, kw) || strings.Contains(kw, tag) {
				matches++
				break
			}
		}
	}

	return math.Min(float64(matches)/float64(len(allTerms)), 1.0)
}

// extractKeywords splits the problem text into lowercase tokens, filtering out
// short/common words to produce meaningful matching terms.
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

	// Replace common punctuation with spaces
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

// suggestTypesViaClaude calls Claude to get recommended types with reasoning
// and priority tags; falls back to keyword matching.
func (s *GuildMasterService) suggestTypesViaClaude(problem string) typeRecommendation {
	systemPrompt := `You are a Guild Master AI that recommends the best team composition for problems.
Given a problem description, recommend 2-3 character types from this list:
wizard (backend/code), strategist (planning/PM), oracle (data/analytics),
guardian (security/infra), artisan (frontend/design), bard (creative/writing),
scholar (research/education), merchant (business/marketing).

For each recommended type, explain WHY it is needed for this specific problem.
Also suggest 3-5 priority tags (lowercase, single words or hyphenated) that would help find the most relevant agents.

Respond with valid JSON only, no markdown:
{"recommended_types":["type1","type2"],"reasoning":"overall short explanation","suggested_name":"Creative Team Name","reasoning_per_type":{"type1":"why type1 is needed","type2":"why type2 is needed"},"priority_tags":["tag1","tag2","tag3"]}`

	reply, err := s.aiSvc.Chat(systemPrompt, fmt.Sprintf("Problem: %s", problem))
	if err == nil {
		var parsed struct {
			RecommendedTypes []string          `json:"recommended_types"`
			Reasoning        string            `json:"reasoning"`
			SuggestedName    string            `json:"suggested_name"`
			ReasoningPerType map[string]string `json:"reasoning_per_type"`
			PriorityTags     []string          `json:"priority_tags"`
		}
		// Extract JSON block in case Claude adds extra text
		start := strings.Index(reply, "{")
		end := strings.LastIndex(reply, "}")
		if start >= 0 && end > start {
			if jsonErr := json.Unmarshal([]byte(reply[start:end+1]), &parsed); jsonErr == nil {
				valid := filterValidTypes(parsed.RecommendedTypes)
				if len(valid) > 0 {
					// Only keep reasoning for valid types
					filteredReasoning := make(map[string]string, len(valid))
					for _, t := range valid {
						if r, ok := parsed.ReasoningPerType[t]; ok {
							filteredReasoning[t] = r
						}
					}

					// Sanitize priority tags
					tags := sanitizeTags(parsed.PriorityTags)

					return typeRecommendation{
						Types:            valid,
						Reasoning:        parsed.Reasoning,
						SuggestedName:    parsed.SuggestedName,
						ReasoningPerType: filteredReasoning,
						PriorityTags:     tags,
					}
				}
			}
		}
	}

	// Keyword fallback
	types := keywordFallback(problem)
	return typeRecommendation{
		Types:         types,
		Reasoning:     "Based on keyword analysis of your problem.",
		SuggestedName: "Custom Squad",
	}
}

// sanitizeTags lowercases and deduplicates tags, keeping only non-empty values.
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

// TeamChat sends the user's message to each agent via Claude and collects their replies.
func (s *GuildMasterService) TeamChat(message string, agentIDs []uint) ([]MemberResponse, error) {
	if len(agentIDs) > 4 {
		agentIDs = agentIDs[:4]
	}

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

		reply, err := s.aiSvc.Chat(systemPrompt, message)
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

// deriveRole picks a descriptive role label based on character type.
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
