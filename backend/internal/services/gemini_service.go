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

const (
	geminiBase  = "https://generativelanguage.googleapis.com/v1beta"
	flashModel  = "gemini-2.0-flash"
	imagenModel = "imagen-3.0-generate-001"
)

// PromptAnalysis holds the structured result of Gemini's prompt analysis.
type PromptAnalysis struct {
	CharacterType string   `json:"character_type"`
	Subclass      string   `json:"subclass"`
	Category      string   `json:"category"`
	Tags          []string `json:"tags"`
	Rarity        string   `json:"rarity"`
	ImagePrompt   string   `json:"image_prompt"`
}

// charTypeStyles provides the visual base for each character type's image prompt.
var charTypeStyles = map[string]string{
	"wizard":     "pixel art RPG wizard, glowing purple robes, magical staff with arcane blue orb, runes floating around",
	"strategist": "pixel art RPG commander, dark red tactical armor with golden medals, commanding presence",
	"oracle":     "pixel art RPG oracle, flowing golden mystical robes, glowing crystal ball, all-seeing eyes",
	"guardian":   "pixel art RPG paladin guardian, heavy cobalt blue armor, large shielded defender stance",
	"artisan":    "pixel art RPG artisan craftsman, colorful paint-splattered apron, holds glowing creative tools",
	"bard":       "pixel art RPG bard performer, bright green travelling cloak, ornate lute instrument, cheerful",
	"scholar":    "pixel art RPG scholar mage, warm brown academic robes, round spectacles, floating open books",
	"merchant":   "pixel art RPG merchant, rich golden embroidered outfit, bulging coin bag, sly confident grin",
}

// GeminiService handles all Gemini API calls (analysis + image generation).
type GeminiService struct {
	apiKey     string
	httpClient *http.Client
}

func NewGeminiService(apiKey string) *GeminiService {
	return &GeminiService{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 90 * time.Second,
		},
	}
}

// AnalyzePrompt sends the agent prompt to Gemini Flash and returns structured metadata.
func (g *GeminiService) AnalyzePrompt(prompt string) (*PromptAnalysis, error) {
	if g.apiKey == "" {
		return nil, fmt.Errorf("gemini api key not configured")
	}

	desc := prompt
	if len(desc) > 600 {
		desc = desc[:600]
	}

	instruction := fmt.Sprintf(`You are a classifier for an AI agent gamification platform.

Analyze the following AI agent prompt and return ONLY a valid JSON object with these exact fields:

{
  "character_type": <one of: wizard, strategist, oracle, guardian, artisan, bard, scholar, merchant>,
  "subclass": <appropriate subclass listed below>,
  "category": <one of: backend, frontend, data, security, creative, business, research, general>,
  "tags": [<3 to 5 lowercase tags, single words or hyphenated>],
  "rarity": <one of: common, uncommon, rare, epic, legendary>,
  "image_prompt": <1-2 sentences describing a pixel art portrait of this agent's personality, tools, and visual identity>
}

Character type → subclasses:
  wizard (backend/code/programming): archmage, sorcerer, hex_master
  strategist (planning/PM/roadmap): war_commander, tactician, diplomat
  oracle (data/analytics/ML/AI): prophet, analyst, seer
  guardian (security/infra/devops): sentinel, warden, paladin
  artisan (frontend/design/UI/UX): sculptor, weaver, painter
  bard (writing/content/creative): storyteller, lyricist, chronicler
  scholar (research/education/learning): sage, professor, librarian
  merchant (business/marketing/sales): entrepreneur, trader, ambassador

Rarity guide (based on prompt detail and uniqueness):
  common: generic, <80 chars
  uncommon: somewhat specific
  rare: detailed with clear personality
  epic: very detailed, specific tools/techniques
  legendary: extremely long, complex, multi-role, >400 chars

Image prompt tips: mention the character's defining tool or item, their color scheme, one unique visual trait that matches the agent's purpose. Keep it concise but vivid.

Agent prompt: %s

Return ONLY the JSON object. No markdown, no explanation.`, desc)

	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", geminiBase, flashModel, g.apiKey)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{"parts": []map[string]string{{"text": instruction}}},
		},
		"generationConfig": map[string]interface{}{
			"responseMimeType": "application/json",
			"temperature":      0.4,
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("content-type", "application/json")

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("gemini analyze error %d: %s", resp.StatusCode, string(b))
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
		return nil, fmt.Errorf("decode analyze response: %w", err)
	}
	if len(apiResp.Candidates) == 0 || len(apiResp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("empty analyze response from gemini")
	}

	text := strings.TrimSpace(apiResp.Candidates[0].Content.Parts[0].Text)
	// Strip markdown fences if present
	text = strings.TrimPrefix(text, "```json")
	text = strings.TrimPrefix(text, "```")
	text = strings.TrimSuffix(text, "```")
	text = strings.TrimSpace(text)

	var analysis PromptAnalysis
	if err := json.Unmarshal([]byte(text), &analysis); err != nil {
		return nil, fmt.Errorf("parse analysis JSON: %w — raw: %s", err, text)
	}

	// Validate and sanitize
	analysis = sanitizeAnalysis(analysis)
	return &analysis, nil
}

// GenerateImage calls Gemini Imagen 3 and returns a base64-encoded PNG string.
func (g *GeminiService) GenerateImage(imagePrompt, charType string) (string, error) {
	if g.apiKey == "" {
		return "", fmt.Errorf("gemini api key not configured")
	}

	style := charTypeStyles[charType]
	if style == "" {
		style = "pixel art RPG fantasy character"
	}

	fullPrompt := style + ". " + imagePrompt +
		" Style: 8-bit retro pixel art, front-facing game sprite, solid dark background, " +
		"vibrant saturated colors, clean blocky shapes, professional pixel art portrait, " +
		"no text, no watermark, square composition."

	url := fmt.Sprintf("%s/models/%s:predict?key=%s", geminiBase, imagenModel, g.apiKey)

	reqBody := map[string]interface{}{
		"instances": []map[string]interface{}{
			{"prompt": fullPrompt},
		},
		"parameters": map[string]interface{}{
			"sampleCount":       1,
			"aspectRatio":       "1:1",
			"safetyFilterLevel": "block_few",
			"personGeneration":  "dont_allow",
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("content-type", "application/json")

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("imagen request: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("imagen error %d: %s", resp.StatusCode, string(respBody))
	}

	var imgResp struct {
		Predictions []struct {
			BytesBase64Encoded string `json:"bytesBase64Encoded"`
			MimeType           string `json:"mimeType"`
		} `json:"predictions"`
	}
	if err := json.Unmarshal(respBody, &imgResp); err != nil {
		return "", fmt.Errorf("parse imagen response: %w", err)
	}
	if len(imgResp.Predictions) == 0 || imgResp.Predictions[0].BytesBase64Encoded == "" {
		return "", fmt.Errorf("no image in imagen response: %s", string(respBody))
	}

	return imgResp.Predictions[0].BytesBase64Encoded, nil
}

// Chat sends a user message to Gemini Flash using systemPrompt as context and returns the text reply.
func (g *GeminiService) Chat(systemPrompt, userMessage string) (string, error) {
	if g.apiKey == "" {
		return "", fmt.Errorf("gemini api key not configured")
	}

	// Combine system prompt and user message into a single turn
	combinedText := "System instructions:\n" + systemPrompt + "\n\nUser message:\n" + userMessage

	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", geminiBase, flashModel, g.apiKey)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{"parts": []map[string]string{{"text": combinedText}}},
		},
		"generationConfig": map[string]interface{}{
			"maxOutputTokens": 1024,
			"temperature":     0.8,
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("content-type", "application/json")

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("gemini chat request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("gemini chat error %d: %s", resp.StatusCode, string(b))
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
		return "", fmt.Errorf("decode chat response: %w", err)
	}
	if len(apiResp.Candidates) == 0 || len(apiResp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("empty chat response from gemini")
	}

	return strings.TrimSpace(apiResp.Candidates[0].Content.Parts[0].Text), nil
}

// sanitizeAnalysis ensures all returned fields are valid known values.
func sanitizeAnalysis(a PromptAnalysis) PromptAnalysis {
	validTypes := map[string]bool{
		"wizard": true, "strategist": true, "oracle": true, "guardian": true,
		"artisan": true, "bard": true, "scholar": true, "merchant": true,
	}
	validCategories := map[string]bool{
		"backend": true, "frontend": true, "data": true, "security": true,
		"creative": true, "business": true, "research": true, "general": true,
	}
	validRarities := map[string]bool{
		"common": true, "uncommon": true, "rare": true, "epic": true, "legendary": true,
	}

	a.CharacterType = strings.ToLower(strings.TrimSpace(a.CharacterType))
	if !validTypes[a.CharacterType] {
		a.CharacterType = "wizard"
	}

	a.Category = strings.ToLower(strings.TrimSpace(a.Category))
	if !validCategories[a.Category] {
		a.Category = "general"
	}

	a.Rarity = strings.ToLower(strings.TrimSpace(a.Rarity))
	if !validRarities[a.Rarity] {
		a.Rarity = "common"
	}

	if len(a.Tags) == 0 {
		a.Tags = []string{a.Category}
	}
	if len(a.Tags) > 5 {
		a.Tags = a.Tags[:5]
	}

	if a.Subclass == "" {
		a.Subclass = defaultSubclass[a.CharacterType]
	}

	return a
}
