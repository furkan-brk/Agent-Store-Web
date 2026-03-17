package client

import (
	"context"
	"fmt"
	"time"

	"github.com/agentstore/backend/pkg/httputil"
)

// AIClient communicates with the AI Pipeline Service's internal API.
type AIClient struct {
	client *httputil.ServiceClient
}

// NewAIClient creates a client pointing at the AI Pipeline Service base URL.
func NewAIClient(baseURL string) *AIClient {
	return &AIClient{
		client: httputil.NewServiceClientWithTimeout(baseURL, 90*time.Second),
	}
}

// --- Request / Response DTOs ---

// AnalysisResult mirrors aipipeline.PromptAnalysis.
type AnalysisResult struct {
	CharacterType string   `json:"character_type"`
	Subclass      string   `json:"subclass"`
	Category      string   `json:"category"`
	Tags          []string `json:"tags"`
	Rarity        string   `json:"rarity"`
	ImagePrompt   string   `json:"image_prompt"`
}

// AgentProfile mirrors aipipeline.AgentProfile.
type AgentProfile struct {
	Name            string   `json:"name"`
	Mood            string   `json:"mood"`
	RolePurpose     string   `json:"role_purpose"`
	PrimaryColor    string   `json:"primary_color"`
	SecondaryColor  string   `json:"secondary_color"`
	TabletGlowColor string   `json:"tablet_glow_color"`
	Characteristics []string `json:"characteristics"`
}

// ScoreResult mirrors aipipeline.PromptScoreResult.
type ScoreResult struct {
	TotalScore         int    `json:"total_score"`
	ClarityScore       int    `json:"clarity_score"`
	SpecificityScore   int    `json:"specificity_score"`
	UsefulnessScore    int    `json:"usefulness_score"`
	DepthScore         int    `json:"depth_score"`
	ServiceDescription string `json:"service_description"`
}

// AvatarResult holds the image bytes and format returned from the avatar endpoint.
type AvatarResult struct {
	ImageBase64 string `json:"image_base64"`
	Format      string `json:"format"`
}

// CharacterResult holds the character data JSON returned from the character endpoint.
type CharacterResult struct {
	CharacterData string `json:"character_data"`
}

// ChatResult holds the chat response.
type ChatResult struct {
	Response string `json:"response"`
}

// --- API Methods ---

// Analyze sends a prompt to /internal/analyze and returns classification results.
func (a *AIClient) Analyze(ctx context.Context, prompt string) (*AnalysisResult, error) {
	var result AnalysisResult
	err := a.client.Post(ctx, "/internal/analyze", map[string]string{"prompt": prompt}, &result)
	if err != nil {
		return nil, fmt.Errorf("ai pipeline analyze: %w", err)
	}
	return &result, nil
}

// Profile generates a rich visual character profile from an agent concept.
func (a *AIClient) Profile(ctx context.Context, concept string) (*AgentProfile, error) {
	var result AgentProfile
	err := a.client.Post(ctx, "/internal/profile", map[string]string{"concept": concept}, &result)
	if err != nil {
		return nil, fmt.Errorf("ai pipeline profile: %w", err)
	}
	return &result, nil
}

// Score evaluates a prompt's quality and generates a service description.
func (a *AIClient) Score(ctx context.Context, prompt string) (*ScoreResult, error) {
	var result ScoreResult
	err := a.client.Post(ctx, "/internal/score", map[string]string{"prompt": prompt}, &result)
	if err != nil {
		return nil, fmt.Errorf("ai pipeline score: %w", err)
	}
	return &result, nil
}

// Avatar generates an avatar image with background removal.
func (a *AIClient) Avatar(ctx context.Context, profile *AgentProfile, imagePrompt, charType string) (*AvatarResult, error) {
	body := map[string]any{
		"profile":      profile,
		"image_prompt": imagePrompt,
		"char_type":    charType,
	}
	var result AvatarResult
	err := a.client.Post(ctx, "/internal/avatar", body, &result)
	if err != nil {
		return nil, fmt.Errorf("ai pipeline avatar: %w", err)
	}
	return &result, nil
}

// Character builds character data JSON (stats, colors, traits).
func (a *AIClient) Character(ctx context.Context, charType, subclass, rarity, prompt string) (*CharacterResult, error) {
	body := map[string]string{
		"char_type": charType,
		"subclass":  subclass,
		"rarity":    rarity,
		"prompt":    prompt,
	}
	var result CharacterResult
	err := a.client.Post(ctx, "/internal/character", body, &result)
	if err != nil {
		return nil, fmt.Errorf("ai pipeline character: %w", err)
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
	err := a.client.Post(ctx, "/internal/chat", body, &result)
	if err != nil {
		return "", fmt.Errorf("ai pipeline chat: %w", err)
	}
	return result.Response, nil
}
