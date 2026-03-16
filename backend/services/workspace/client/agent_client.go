package client

import (
	"context"
	"fmt"
	"time"

	"github.com/agentstore/backend/pkg/httputil"
	"github.com/agentstore/backend/pkg/models"
)

// AgentClient communicates with the Agent Service's internal API.
type AgentClient struct {
	client *httputil.ServiceClient
}

// NewAgentClient creates a client for the Agent Service.
func NewAgentClient(baseURL string) *AgentClient {
	return &AgentClient{
		client: httputil.NewServiceClientWithTimeout(baseURL, 30*time.Second),
	}
}

// GetAgent fetches an agent by ID from the Agent Service.
func (a *AgentClient) GetAgent(ctx context.Context, agentID uint) (*models.Agent, error) {
	var agent models.Agent
	if err := a.client.Get(ctx, fmt.Sprintf("/internal/agents/%d", agentID), &agent); err != nil {
		return nil, fmt.Errorf("agent service get agent %d: %w", agentID, err)
	}
	return &agent, nil
}

// IncrementUseCount increments the use count for an agent.
func (a *AgentClient) IncrementUseCount(ctx context.Context, agentID uint) error {
	var resp struct {
		OK bool `json:"ok"`
	}
	if err := a.client.Post(ctx, fmt.Sprintf("/internal/agents/%d/increment-use", agentID), nil, &resp); err != nil {
		return fmt.Errorf("agent service increment use %d: %w", agentID, err)
	}
	return nil
}

// CreditsResponse holds the credit balance response.
type CreditsResponse struct {
	Credits int64  `json:"credits"`
	Wallet  string `json:"wallet"`
}

// GetCredits returns the credit balance for a wallet.
func (a *AgentClient) GetCredits(ctx context.Context, wallet string) (int64, error) {
	var resp CreditsResponse
	if err := a.client.Get(ctx, fmt.Sprintf("/internal/credits/%s", wallet), &resp); err != nil {
		return 0, fmt.Errorf("agent service get credits: %w", err)
	}
	return resp.Credits, nil
}

// DeductCredits deducts credits from a wallet via the Agent Service.
func (a *AgentClient) DeductCredits(ctx context.Context, wallet string, amount int64, txType string) error {
	body := map[string]any{
		"wallet":  wallet,
		"amount":  amount,
		"tx_type": txType,
	}
	var resp struct {
		OK bool `json:"ok"`
	}
	if err := a.client.Post(ctx, "/internal/credits/deduct", body, &resp); err != nil {
		return fmt.Errorf("agent service deduct credits: %w", err)
	}
	return nil
}
