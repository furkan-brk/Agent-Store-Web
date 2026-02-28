package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// replicateStylePrefixes provides per-character-type style descriptors for pixel art generation.
var replicateStylePrefixes = map[string]string{
	"wizard":     "pixel art RPG wizard, glowing purple robes, magic staff, fantasy",
	"strategist": "pixel art RPG commander, red armor, tactical, strategy",
	"oracle":     "pixel art RPG oracle, golden robes, crystal ball, mystical",
	"guardian":   "pixel art RPG paladin, blue heavy armor, shield, defender",
	"artisan":    "pixel art RPG artisan, colorful clothes, creative tools",
	"bard":       "pixel art RPG bard, green cloak, lute, performer",
	"scholar":    "pixel art RPG scholar, brown robes, glasses, books",
	"merchant":   "pixel art RPG merchant, golden outfit, coin bag, trader",
}

// ReplicateService handles pixel-art image generation via Replicate API.
type ReplicateService struct {
	apiKey     string
	httpClient *http.Client
}

// NewReplicateService creates a new ReplicateService with the provided API key.
func NewReplicateService(apiKey string) *ReplicateService {
	return &ReplicateService{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

// replicatePredictionResponse represents the response from Replicate predictions endpoint.
type replicatePredictionResponse struct {
	ID     string      `json:"id"`
	Status string      `json:"status"`
	Output interface{} `json:"output"`
	Error  string      `json:"error"`
}

// GeneratePixelArt calls the nerijs/pixel-art-xl model on Replicate and returns a base64-encoded PNG.
func (r *ReplicateService) GeneratePixelArt(imagePrompt, charType string) (string, error) {
	if r.apiKey == "" {
		return "", fmt.Errorf("replicate api key not configured")
	}

	prefix, ok := replicateStylePrefixes[charType]
	if !ok {
		prefix = "pixel art RPG fantasy character"
	}

	fullPrompt := prefix + ", " + imagePrompt +
		", 8-bit pixel art game sprite, front facing, dark background, vibrant colors, retro RPG"

	reqBody := map[string]interface{}{
		"input": map[string]interface{}{
			"prompt": fullPrompt,
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal replicate request: %w", err)
	}

	req, err := http.NewRequest("POST",
		"https://api.replicate.com/v1/models/nerijs/pixel-art-xl/predictions",
		bytes.NewBuffer(body))
	if err != nil {
		return "", fmt.Errorf("create replicate request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "wait")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("replicate request: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("replicate error %d: %s", resp.StatusCode, string(respBody))
	}

	var prediction replicatePredictionResponse
	if err := json.Unmarshal(respBody, &prediction); err != nil {
		return "", fmt.Errorf("parse replicate response: %w", err)
	}

	if prediction.Error != "" {
		return "", fmt.Errorf("replicate prediction error: %s", prediction.Error)
	}

	if prediction.Status != "succeeded" {
		return "", fmt.Errorf("replicate prediction status: %s", prediction.Status)
	}

	// Output is a JSON array of URL strings: ["https://..."]
	imageURL, err := extractFirstOutputURL(prediction.Output)
	if err != nil {
		return "", fmt.Errorf("extract replicate output url: %w", err)
	}

	// Download the image and convert to base64
	imgResp, err := r.httpClient.Get(imageURL)
	if err != nil {
		return "", fmt.Errorf("download replicate image: %w", err)
	}
	defer imgResp.Body.Close()

	imgBytes, err := io.ReadAll(imgResp.Body)
	if err != nil {
		return "", fmt.Errorf("read replicate image bytes: %w", err)
	}

	return base64.StdEncoding.EncodeToString(imgBytes), nil
}

// extractFirstOutputURL extracts the first URL string from Replicate's output field.
// The output field can be []interface{} or []string depending on model version.
func extractFirstOutputURL(output interface{}) (string, error) {
	if output == nil {
		return "", fmt.Errorf("replicate output is nil")
	}

	// Try as []interface{} (standard JSON unmarshal result)
	if arr, ok := output.([]interface{}); ok {
		if len(arr) == 0 {
			return "", fmt.Errorf("replicate output array is empty")
		}
		if url, ok := arr[0].(string); ok && url != "" {
			return url, nil
		}
		return "", fmt.Errorf("replicate output[0] is not a string")
	}

	return "", fmt.Errorf("unexpected replicate output format: %T", output)
}
