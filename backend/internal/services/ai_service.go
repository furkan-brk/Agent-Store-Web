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

const claudeAPIURL = "https://api.anthropic.com/v1/messages"

type AIService struct {
	apiKey     string
	httpClient *http.Client
	slowClient *http.Client // longer timeout for pixel-art generation
}

func NewAIService(apiKey string) *AIService {
	return &AIService{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		slowClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

// AnalyzePrompt sends the agent prompt to Claude and returns the character type.
// Returns an error if the API key is missing or the call fails.
func (s *AIService) AnalyzePrompt(prompt string) (string, error) {
	if s.apiKey == "" {
		return "", fmt.Errorf("claude api key not configured")
	}

	instruction := fmt.Sprintf(
		`Analyze this AI agent prompt and categorize it as exactly one of these types:
wizard (backend/code/programming)
strategist (planning/project management/business strategy)
oracle (data/analytics/machine learning)
guardian (security/infrastructure/devops)
artisan (frontend/design/UI/UX)
bard (creative writing/content creation)
scholar (research/education/learning)
merchant (sales/marketing/growth/business)

Prompt: %s

Respond with ONLY the category name in lowercase, nothing else. Example: wizard`, prompt)

	reqBody := map[string]interface{}{
		"model":      "claude-haiku-4-5-20251001",
		"max_tokens": 20,
		"messages": []map[string]string{
			{"role": "user", "content": instruction},
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", claudeAPIURL, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("x-api-key", s.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("claude api error %d: %s", resp.StatusCode, string(b))
	}

	var result struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	if len(result.Content) == 0 {
		return "", fmt.Errorf("empty response from claude")
	}

	charType := strings.TrimSpace(strings.ToLower(result.Content[0].Text))
	// Validate that the returned type is one we know
	if _, ok := characterMap[charType]; !ok {
		return "", fmt.Errorf("unknown character type returned: %q", charType)
	}
	return charType, nil
}

// Chat sends a single-turn message to Claude and returns the text response.
// Uses slowClient (60s) because multi-agent sequential calls can be slow.
func (s *AIService) Chat(systemPrompt, userMessage string) (string, error) {
	if s.apiKey == "" {
		return "", fmt.Errorf("claude api key not configured")
	}

	reqBody := map[string]interface{}{
		"model":      "claude-haiku-4-5-20251001",
		"max_tokens": 1024,
		"system":     systemPrompt,
		"messages": []map[string]string{
			{"role": "user", "content": userMessage},
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", claudeAPIURL, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("x-api-key", s.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := s.slowClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("claude api error %d: %s", resp.StatusCode, string(b))
	}

	var result struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	if len(result.Content) == 0 {
		return "", fmt.Errorf("empty response from claude")
	}
	return strings.TrimSpace(result.Content[0].Text), nil
}

// GeneratePixelArt asks Claude to produce a unique 16×16 pixel matrix for the given prompt.
// Returns nil if generation fails — the caller should fall back to static data.
func (s *AIService) GeneratePixelArt(prompt, charType string) ([][]int, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("claude api key not configured")
	}

	// Truncate prompt so the instruction stays concise
	desc := prompt
	if len(desc) > 250 {
		desc = desc[:250]
	}

	instruction := fmt.Sprintf(
		`Generate pixel art data for a game character sprite.
Character class: %s
Character role/prompt: %s

Return a 16×16 grid where every cell is one integer 0-9:
0=transparent  1=primary color (body/clothes)  2=shadow/secondary
3=skin tone    4=accent/highlight               5=dark outline
6=white        7=gold/brown detail              8=dark eyes/pupils
9=special glow

Layout (front-facing, blocky/minimalist):
- Rows 0-1  : head accessory (hat, crown, hood)
- Rows 2-6  : head (3=skin face, 8=two eye pixels at row 4 cols ~5 and ~8)
- Rows 7-12 : torso (1=clothes, 4=small detail)
- Rows 13-15: legs and feet
- Center: mostly cols 3-12, leave 0-2 and 13-15 as 0
- Use 1 for the main body mass, add personality with other colors
- Make the silhouette UNIQUE for this specific agent role

Output ONLY valid JSON, no explanation, no markdown:
{"pixels":[[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints],[16 ints]]}`,
		charType, desc)

	reqBody := map[string]interface{}{
		"model":      "claude-haiku-4-5-20251001",
		"max_tokens": 500,
		"messages": []map[string]string{
			{"role": "user", "content": instruction},
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", claudeAPIURL, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("x-api-key", s.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := s.slowClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("claude pixel-art error %d: %s", resp.StatusCode, string(b))
	}

	var apiResp struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return nil, err
	}
	if len(apiResp.Content) == 0 {
		return nil, fmt.Errorf("empty pixel-art response")
	}

	// Extract JSON block from the text (Claude might add extra text)
	text := strings.TrimSpace(apiResp.Content[0].Text)
	start := strings.Index(text, "{")
	end := strings.LastIndex(text, "}")
	if start < 0 || end <= start {
		return nil, fmt.Errorf("no JSON found in pixel-art response")
	}
	text = text[start : end+1]

	var pixResult struct {
		Pixels [][]int `json:"pixels"`
	}
	if err := json.Unmarshal([]byte(text), &pixResult); err != nil {
		return nil, fmt.Errorf("pixel-art JSON parse error: %w", err)
	}
	if len(pixResult.Pixels) != 16 {
		return nil, fmt.Errorf("expected 16 rows, got %d", len(pixResult.Pixels))
	}
	// Clamp every value to 0-9 and ensure each row has exactly 16 cols
	for i, row := range pixResult.Pixels {
		if len(row) != 16 {
			return nil, fmt.Errorf("row %d has %d cols, expected 16", i, len(row))
		}
		for j, v := range row {
			if v < 0 {
				pixResult.Pixels[i][j] = 0
			} else if v > 9 {
				pixResult.Pixels[i][j] = 9
			}
		}
	}
	return pixResult.Pixels, nil
}
