package aipipeline

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

// AIService handles Claude API calls for prompt analysis and chat.
type AIService struct {
	apiKey     string
	httpClient *http.Client
	slowClient *http.Client
}

// NewAIService creates a new Claude-backed AI service.
func NewAIService(apiKey string) *AIService {
	return &AIService{
		apiKey:     apiKey,
		httpClient: &http.Client{Timeout: 15 * time.Second},
		slowClient: &http.Client{Timeout: 60 * time.Second},
	}
}

// AnalyzePrompt sends the agent prompt to Claude and returns the character type.
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

	reqBody := map[string]any{
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
	if _, ok := characterMap[charType]; !ok {
		return "", fmt.Errorf("unknown character type returned: %q", charType)
	}
	return charType, nil
}

// Chat sends a single-turn message to Claude and returns the text response.
func (s *AIService) Chat(systemPrompt, userMessage string) (string, error) {
	if s.apiKey == "" {
		return "", fmt.Errorf("claude api key not configured")
	}

	reqBody := map[string]any{
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
