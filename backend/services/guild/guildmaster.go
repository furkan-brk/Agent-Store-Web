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

// GuildSuggestion holds the recommendation response.
type GuildSuggestion struct {
	RecommendedTypes []string          `json:"recommended_types"`
	MatchingAgents   []models.Agent    `json:"matching_agents"`
	Reasoning        string            `json:"reasoning"`
	SuggestedName    string            `json:"suggested_name"`
	ReasoningPerType map[string]string `json:"reasoning_per_type,omitempty"`
	PriorityTags     []string          `json:"priority_tags,omitempty"`
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
}

// SuggestGuild recommends character types and matching agents for a problem.
func (s *GuildMasterService) SuggestGuild(problem string) (*GuildSuggestion, error) {
	rec := s.suggestTypesViaAI(problem)

	problemKeywords := extractKeywords(problem)

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
			Limit(6).
			Find(&candidates).Error
		if err != nil {
			continue
		}

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
	systemPrompt := `You are a Guild Master AI that recommends the best team composition for problems.
Given a problem description, recommend 2-3 character types from this list:
wizard (backend/code), strategist (planning/PM), oracle (data/analytics),
guardian (security/infra), artisan (frontend/design), bard (creative/writing),
scholar (research/education), merchant (business/marketing).

For each recommended type, explain WHY it is needed for this specific problem.
Also suggest 3-5 priority tags (lowercase, single words or hyphenated) that would help find the most relevant agents.

Respond with valid JSON only, no markdown:
{"recommended_types":["type1","type2"],"reasoning":"overall short explanation","suggested_name":"Creative Team Name","reasoning_per_type":{"type1":"why type1 is needed","type2":"why type2 is needed"},"priority_tags":["tag1","tag2","tag3"]}`

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	reply, err := s.aiClient.Chat(ctx, systemPrompt, fmt.Sprintf("Problem: %s", problem))
	if err == nil {
		var parsed struct {
			RecommendedTypes []string          `json:"recommended_types"`
			Reasoning        string            `json:"reasoning"`
			SuggestedName    string            `json:"suggested_name"`
			ReasoningPerType map[string]string `json:"reasoning_per_type"`
			PriorityTags     []string          `json:"priority_tags"`
		}
		start := strings.Index(reply, "{")
		end := strings.LastIndex(reply, "}")
		if start >= 0 && end > start {
			if jsonErr := json.Unmarshal([]byte(reply[start:end+1]), &parsed); jsonErr == nil {
				valid := filterValidTypes(parsed.RecommendedTypes)
				if len(valid) > 0 {
					filteredReasoning := make(map[string]string, len(valid))
					for _, t := range valid {
						if r, ok := parsed.ReasoningPerType[t]; ok {
							filteredReasoning[t] = r
						}
					}
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

	types := keywordFallback(problem)
	return typeRecommendation{
		Types:         types,
		Reasoning:     "Based on keyword analysis of your problem.",
		SuggestedName: "Custom Squad",
	}
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
