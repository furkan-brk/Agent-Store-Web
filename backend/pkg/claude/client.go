package claude

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client communicates with the Anthropic Claude API.
type Client struct {
	apiKey     string
	httpClient *http.Client
}

// Message represents a single conversation turn.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// NewClient creates a new Claude API client.
func NewClient(apiKey string) *Client {
	return &Client{
		apiKey:     apiKey,
		httpClient: &http.Client{Timeout: 120 * time.Second},
	}
}

// modelMapping maps short names to full Claude model identifiers.
var modelMapping = map[string]string{
	"haiku":  "claude-3-5-haiku-20241022",
	"sonnet": "claude-sonnet-4-20250514",
	"opus":   "claude-opus-4-20250514",
}

// CreditCost returns credits per node for each model.
var CreditCost = map[string]int64{
	"haiku":  1,
	"sonnet": 3,
	"opus":   10,
}

// SendMessage sends a message to Claude and returns the text response.
func (c *Client) SendMessage(ctx context.Context, model, systemPrompt string, messages []Message) (string, error) {
	fullModel, ok := modelMapping[model]
	if !ok {
		fullModel = modelMapping["sonnet"] // default
	}

	reqBody := map[string]any{
		"model":      fullModel,
		"max_tokens": 4096,
		"system":     systemPrompt,
		"messages":   messages,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(jsonData))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("claude API error %d: %s", resp.StatusCode, string(body))
	}

	var result struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("parse response: %w", err)
	}
	if len(result.Content) == 0 {
		return "", fmt.Errorf("empty response from Claude")
	}
	return result.Content[0].Text, nil
}

// IsConfigured returns true if the client has an API key set.
func (c *Client) IsConfigured() bool {
	return c.apiKey != ""
}
