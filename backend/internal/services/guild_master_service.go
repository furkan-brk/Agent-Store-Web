package services

import (
	"encoding/json"
	"fmt"
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
	RecommendedTypes []string       `json:"recommended_types"`
	MatchingAgents   []models.Agent `json:"matching_agents"`
	Reasoning        string         `json:"reasoning"`
	SuggestedName    string         `json:"suggested_name"`
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

// SuggestGuild asks Claude to recommend character types for the given problem,
// then fetches matching agents from the DB.
func (s *GuildMasterService) SuggestGuild(problem string) (*GuildSuggestion, error) {
	types, reasoning, name := s.suggestTypesViaClaude(problem)

	// Fetch top agent per type (by prompt_score DESC), max 3 agents
	agents := make([]models.Agent, 0, 3)
	seen := map[uint]bool{}
	for _, t := range types {
		if len(agents) >= 3 {
			break
		}
		var agent models.Agent
		err := database.DB.
			Where("character_type = ?", t).
			Order("prompt_score DESC").
			First(&agent).Error
		if err == nil && !seen[agent.ID] {
			agents = append(agents, agent)
			seen[agent.ID] = true
		}
	}

	return &GuildSuggestion{
		RecommendedTypes: types,
		MatchingAgents:   agents,
		Reasoning:        reasoning,
		SuggestedName:    name,
	}, nil
}

// suggestTypesViaClaude calls Claude to get recommended types; falls back to keyword matching.
func (s *GuildMasterService) suggestTypesViaClaude(problem string) ([]string, string, string) {
	systemPrompt := `You are a Guild Master AI that recommends the best team composition for problems.
Given a problem description, recommend 2-3 character types from this list:
wizard (backend/code), strategist (planning/PM), oracle (data/analytics),
guardian (security/infra), artisan (frontend/design), bard (creative/writing),
scholar (research/education), merchant (business/marketing).

Respond with valid JSON only, no markdown:
{"recommended_types":["type1","type2"],"reasoning":"short explanation","suggested_name":"Creative Team Name"}`

	reply, err := s.aiSvc.Chat(systemPrompt, fmt.Sprintf("Problem: %s", problem))
	if err == nil {
		var parsed struct {
			RecommendedTypes []string `json:"recommended_types"`
			Reasoning        string   `json:"reasoning"`
			SuggestedName    string   `json:"suggested_name"`
		}
		// Extract JSON block in case Claude adds extra text
		start := strings.Index(reply, "{")
		end := strings.LastIndex(reply, "}")
		if start >= 0 && end > start {
			if jsonErr := json.Unmarshal([]byte(reply[start:end+1]), &parsed); jsonErr == nil {
				// Validate that returned types are known
				valid := filterValidTypes(parsed.RecommendedTypes)
				if len(valid) > 0 {
					return valid, parsed.Reasoning, parsed.SuggestedName
				}
			}
		}
	}

	// Keyword fallback
	return keywordFallback(problem), "Based on keyword analysis of your problem.", "Custom Squad"
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
