package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// PromptScoreResult holds the scoring breakdown for an agent prompt.
type PromptScoreResult struct {
	TotalScore         int    `json:"total_score"`         // 0-100
	ClarityScore       int    `json:"clarity_score"`       // 0-25: role definition clarity
	SpecificityScore   int    `json:"specificity_score"`   // 0-25: explicit constraints/behaviors
	UsefulnessScore    int    `json:"usefulness_score"`    // 0-25: solves a clear problem
	DepthScore         int    `json:"depth_score"`         // 0-25: context richness/nuance
	ServiceDescription string `json:"service_description"` // functional 1-2 sentence description
}

// GuildCompatibilityResult holds the compatibility analysis for a guild.
type GuildCompatibilityResult struct {
	GuildID            uint                   `json:"guild_id"`
	CompatibilityScore int                    `json:"compatibility_score"` // 0-100
	Breakdown          CompatibilityBreakdown `json:"breakdown"`
	Description        string                 `json:"description"` // narrative summary
	Gaps               []string               `json:"gaps"`        // suggested missing character types
}

// CompatibilityBreakdown holds sub-scores for guild compatibility.
type CompatibilityBreakdown struct {
	Diversity int `json:"diversity"` // 0-40: variety of character types/categories
	Synergy   int `json:"synergy"`   // 0-40: complementary roles
	Coverage  int `json:"coverage"`  // 0-20: breadth of problem space covered
}

// ScoreService scores agent prompts and analyzes guild compatibility using Gemini.
type ScoreService struct {
	apiKey     string
	httpClient *http.Client
}

func NewScoreService(geminiAPIKey string) *ScoreService {
	return &ScoreService{
		apiKey:     geminiAPIKey,
		httpClient: &http.Client{Timeout: 60 * time.Second},
	}
}

// ScoreAndDescribe scores a prompt (0-100) and generates a service description.
// Falls back to heuristic scoring if Gemini is unavailable.
func (s *ScoreService) ScoreAndDescribe(prompt string) *PromptScoreResult {
	if s.apiKey != "" {
		if result, err := s.scoreWithGemini(prompt); err == nil {
			return result
		}
	}
	return s.heuristicScore(prompt)
}

func (s *ScoreService) scoreWithGemini(prompt string) (*PromptScoreResult, error) {
	excerpt := prompt
	if len(excerpt) > 800 {
		excerpt = excerpt[:800]
	}

	instruction := fmt.Sprintf(`You are a prompt quality evaluator for an AI agent marketplace.

Evaluate the following AI agent prompt and return ONLY a valid JSON object:

{
  "clarity_score": <0-25, how clear and structured the role definition is>,
  "specificity_score": <0-25, how specific the constraints and behaviors are>,
  "usefulness_score": <0-25, how clearly it solves a real-world problem>,
  "depth_score": <0-25, complexity, nuance, and richness of context>,
  "service_description": <1-2 sentences describing what this agent does functionally, third person, e.g. "This agent helps developers by...">
}

Scoring guide:
- clarity_score: 0-5 vague, 6-15 somewhat clear, 16-25 crystal-clear role + instructions
- specificity_score: 0-5 generic, 6-15 some specifics, 16-25 detailed constraints + behaviors
- usefulness_score: 0-5 unclear purpose, 6-15 useful, 16-25 clear high-value use case
- depth_score: 0-5 single line, 6-15 moderate detail, 16-25 rich context with nuance and examples

Agent prompt:
%s

Return ONLY the JSON object. No markdown, no explanation.`, excerpt)

	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", geminiBase, flashModel, s.apiKey)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{"parts": []map[string]string{{"text": instruction}}},
		},
		"generationConfig": map[string]interface{}{
			"responseMimeType": "application/json",
			"temperature":      0.2,
		},
	}

	body, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("content-type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("gemini score error %d: %s", resp.StatusCode, string(b))
	}

	var apiResp struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return nil, err
	}
	if len(apiResp.Candidates) == 0 || len(apiResp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("empty score response from gemini")
	}

	text := strings.TrimSpace(apiResp.Candidates[0].Content.Parts[0].Text)
	text = strings.TrimPrefix(text, "```json")
	text = strings.TrimPrefix(text, "```")
	text = strings.TrimSuffix(text, "```")
	text = strings.TrimSpace(text)

	var raw struct {
		ClarityScore       int    `json:"clarity_score"`
		SpecificityScore   int    `json:"specificity_score"`
		UsefulnessScore    int    `json:"usefulness_score"`
		DepthScore         int    `json:"depth_score"`
		ServiceDescription string `json:"service_description"`
	}
	if err := json.Unmarshal([]byte(text), &raw); err != nil {
		return nil, fmt.Errorf("parse score JSON: %w", err)
	}

	clamp := func(v, min, max int) int {
		if v < min {
			return min
		}
		if v > max {
			return max
		}
		return v
	}

	result := &PromptScoreResult{
		ClarityScore:       clamp(raw.ClarityScore, 0, 25),
		SpecificityScore:   clamp(raw.SpecificityScore, 0, 25),
		UsefulnessScore:    clamp(raw.UsefulnessScore, 0, 25),
		DepthScore:         clamp(raw.DepthScore, 0, 25),
		ServiceDescription: raw.ServiceDescription,
	}
	result.TotalScore = result.ClarityScore + result.SpecificityScore + result.UsefulnessScore + result.DepthScore

	if result.ServiceDescription == "" {
		result.ServiceDescription = "This agent assists users with specialized tasks."
	}
	return result, nil
}

// heuristicScore provides a keyword-based fallback score.
func (s *ScoreService) heuristicScore(prompt string) *PromptScoreResult {
	lower := strings.ToLower(prompt)
	length := len(prompt)

	// Clarity: role definition keywords
	clarity := 5
	for _, kw := range []string{"you are", "your role", "your task", "your goal", "you must", "you should", "act as", "your job"} {
		if strings.Contains(lower, kw) {
			clarity += 4
		}
	}
	if clarity > 25 {
		clarity = 25
	}

	// Specificity: length-based
	specificity := 5
	switch {
	case length > 600:
		specificity = 25
	case length > 300:
		specificity = 18
	case length > 100:
		specificity = 10
	}

	// Usefulness: action verbs
	usefulness := 5
	for _, kw := range []string{"help", "assist", "generate", "create", "analyze", "review", "explain", "build", "optimize", "debug"} {
		if strings.Contains(lower, kw) {
			usefulness += 2
		}
	}
	if usefulness > 25 {
		usefulness = 25
	}

	// Depth: length + structure indicators
	depth := 5
	switch {
	case length > 800:
		depth = 25
	case length > 500:
		depth = 20
	case length > 200:
		depth = 12
	}

	charType := DetermineCharacterType(prompt)
	serviceDesc := fmt.Sprintf(
		"This agent specializes in %s-related tasks, helping users achieve their goals efficiently.",
		charType,
	)

	total := clarity + specificity + usefulness + depth
	return &PromptScoreResult{
		TotalScore:         total,
		ClarityScore:       clarity,
		SpecificityScore:   specificity,
		UsefulnessScore:    usefulness,
		DepthScore:         depth,
		ServiceDescription: serviceDesc,
	}
}

// AnalyzeGuildCompatibility computes a compatibility score for the given guild members.
// agentSummaries is a slice of {title, charType, category, serviceDesc}.
func (s *ScoreService) AnalyzeGuildCompatibility(guildID uint, members []guildMemberSummary) *GuildCompatibilityResult {
	result := &GuildCompatibilityResult{GuildID: guildID}

	if len(members) == 0 {
		result.Description = "This guild has no members yet."
		return result
	}

	// ── Rule-based base scores ──
	result.Breakdown.Diversity = s.diversityScore(members)
	result.Breakdown.Synergy = s.synergyScore(members)
	result.Breakdown.Coverage = s.coverageScore(members)
	result.CompatibilityScore = result.Breakdown.Diversity + result.Breakdown.Synergy + result.Breakdown.Coverage
	result.Gaps = s.detectGaps(members)

	// ── AI narrative (best-effort) ──
	if s.apiKey != "" {
		if desc, err := s.narrativeWithGemini(members); err == nil {
			result.Description = desc
			return result
		}
	}
	result.Description = s.heuristicNarrative(members)
	return result
}

// guildMemberSummary is a lightweight view of an agent used for compatibility analysis.
type guildMemberSummary struct {
	AgentID     uint
	Title       string
	CharType    string
	Category    string
	ServiceDesc string
}

func (s *ScoreService) diversityScore(members []guildMemberSummary) int {
	typeSet := map[string]bool{}
	catSet := map[string]bool{}
	for _, m := range members {
		typeSet[m.CharType] = true
		catSet[m.Category] = true
	}
	// Max 40: 20 from unique types, 20 from unique categories
	typePts := len(typeSet) * (20 / max(len(members), 1))
	catPts := len(catSet) * (20 / max(len(members), 1))
	if typePts > 20 {
		typePts = 20
	}
	if catPts > 20 {
		catPts = 20
	}
	return typePts + catPts
}

func (s *ScoreService) synergyScore(members []guildMemberSummary) int {
	types := make([]string, len(members))
	for i, m := range members {
		types[i] = m.CharType
	}
	_, bonuses := CalculateGuildSynergy(types)
	total := 0
	for _, v := range bonuses {
		total += v
	}
	// Normalize to 0-40
	if total > 40 {
		total = 40
	}
	return total
}

func (s *ScoreService) coverageScore(members []guildMemberSummary) int {
	// Broad categories signal wide problem-space coverage
	broadCats := map[string]bool{
		"backend": false, "frontend": false, "data": false,
		"security": false, "creative": false, "business": false,
		"research": false, "general": false,
	}
	for _, m := range members {
		if _, ok := broadCats[m.Category]; ok {
			broadCats[m.Category] = true
		}
	}
	covered := 0
	for _, v := range broadCats {
		if v {
			covered++
		}
	}
	// 20 pts max: 5 pts per unique broad category (cap 4)
	pts := covered * 5
	if pts > 20 {
		pts = 20
	}
	return pts
}

func (s *ScoreService) detectGaps(members []guildMemberSummary) []string {
	present := map[string]bool{}
	for _, m := range members {
		present[m.CharType] = true
	}
	// Suggest types not represented that would complement the guild
	allTypes := []string{"wizard", "strategist", "oracle", "guardian", "artisan", "bard", "scholar", "merchant"}
	gaps := []string{}
	for _, t := range allTypes {
		if !present[t] {
			gaps = append(gaps, t)
			if len(gaps) >= 2 {
				break
			}
		}
	}
	return gaps
}

func (s *ScoreService) narrativeWithGemini(members []guildMemberSummary) (string, error) {
	lines := []string{}
	for _, m := range members {
		desc := m.ServiceDesc
		if desc == "" {
			desc = fmt.Sprintf("a %s agent", m.CharType)
		}
		lines = append(lines, fmt.Sprintf("- %s (%s): %s", m.Title, m.CharType, desc))
	}
	agentList := strings.Join(lines, "\n")

	instruction := fmt.Sprintf(`You are a guild advisor for an AI agent team-building platform.

Given these guild members:
%s

Write 2-3 sentences describing how these agents complement each other as a team.
Focus on what problems they can solve together, their combined strengths, and any notable synergies.
Be specific about their roles — do not be generic.

Return ONLY the narrative text. No JSON, no markdown, no bullet points.`, agentList)

	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", geminiBase, flashModel, s.apiKey)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{"parts": []map[string]string{{"text": instruction}}},
		},
		"generationConfig": map[string]interface{}{
			"maxOutputTokens": 256,
			"temperature":     0.6,
		},
	}

	body, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("content-type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("gemini narrative error %d: %s", resp.StatusCode, string(b))
	}

	var apiResp struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return "", err
	}
	if len(apiResp.Candidates) == 0 || len(apiResp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("empty narrative response")
	}
	return strings.TrimSpace(apiResp.Candidates[0].Content.Parts[0].Text), nil
}

func (s *ScoreService) heuristicNarrative(members []guildMemberSummary) string {
	if len(members) == 1 {
		return fmt.Sprintf(
			"This guild is led by a solo %s agent. Adding complementary members will unlock synergy bonuses.",
			members[0].CharType,
		)
	}
	types := []string{}
	for _, m := range members {
		types = append(types, m.CharType)
	}
	return fmt.Sprintf(
		"This guild brings together %s agents. Their combined skills cover a broad range of problem domains, making them effective for complex multi-faceted tasks.",
		strings.Join(types, ", "),
	)
}

