package client

import (
	"context"
	"fmt"
	"time"

	"github.com/agentstore/backend/pkg/httputil"
)

// AIClient communicates with the AI Pipeline Service for workspace AI tasks.
type AIClient struct {
	client *httputil.ServiceClient
}

// NewAIClient creates a client for the AI Pipeline Service.
func NewAIClient(baseURL string) *AIClient {
	return &AIClient{
		client: httputil.NewServiceClientWithTimeout(baseURL, 90*time.Second),
	}
}

// ChatResult holds the chat response.
type ChatResult struct {
	Response string `json:"response"`
}

// Chat sends a message to the AI via the pipeline's chat endpoint.
// Used by Legend workflow execution for agent nodes.
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
