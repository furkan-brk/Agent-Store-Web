package client

import (
	"context"
	"fmt"
	"time"

	"github.com/agentstore/backend/pkg/httputil"
)

// AIClient communicates with the AI Pipeline Service for guild-related AI tasks.
type AIClient struct {
	client *httputil.ServiceClient
}

// NewAIClient creates a client for the AI Pipeline Service.
func NewAIClient(baseURL string) *AIClient {
	return &AIClient{
		client: httputil.NewServiceClientWithTimeout(baseURL, 60*time.Second),
	}
}

// CompatibilityMember mirrors aipipeline.GuildMemberSummary for the compatibility request.
type CompatibilityMember struct {
	AgentID     uint   `json:"agent_id"`
	Title       string `json:"title"`
	CharType    string `json:"char_type"`
	Category    string `json:"category"`
	ServiceDesc string `json:"service_desc"`
}

// CompatibilityBreakdown holds sub-scores for guild compatibility.
type CompatibilityBreakdown struct {
	Diversity int `json:"diversity"`
	Synergy   int `json:"synergy"`
	Coverage  int `json:"coverage"`
}

// CompatibilityResult mirrors aipipeline.GuildCompatibilityResult.
type CompatibilityResult struct {
	GuildID            uint                   `json:"guild_id"`
	CompatibilityScore int                    `json:"compatibility_score"`
	Breakdown          CompatibilityBreakdown `json:"breakdown"`
	Description        string                 `json:"description"`
	Gaps               []string               `json:"gaps"`
}

// ChatResult holds the chat response.
type ChatResult struct {
	Response string `json:"response"`
}

// Compatibility analyzes guild member compatibility via AI Pipeline.
func (a *AIClient) Compatibility(ctx context.Context, guildID uint, members []CompatibilityMember) (*CompatibilityResult, error) {
	body := map[string]any{
		"guild_id": guildID,
		"members":  members,
	}
	var result CompatibilityResult
	if err := a.client.Post(ctx, "/internal/compatibility", body, &result); err != nil {
		return nil, fmt.Errorf("ai pipeline compatibility: %w", err)
	}
	return &result, nil
}

// Chat sends a message to the AI via the pipeline's chat endpoint.
func (a *AIClient) Chat(ctx context.Context, systemPrompt, userMessage string) (string, error) {
	body := map[string]string{
		"system_prompt": systemPrompt,
		"user_message":  userMessage,
	}
	var result ChatResult
	if err := a.client.Post(ctx, "/internal/chat", body, &result); err != nil {
		return "", fmt.Errorf("ai pipeline chat: %w", err)
	}
	return result.Response, nil
}
