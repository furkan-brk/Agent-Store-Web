package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const (
	pollinationsImageAPI = "https://api.pollinations.ai/v1/images"
	pollinationsTimeout  = 120 * time.Second
)

// PollinationsService handles image generation via the Pollinations API.
type PollinationsService struct {
	httpClient *http.Client
}

func NewPollinationsService() *PollinationsService {
	return &PollinationsService{
		httpClient: &http.Client{
			Timeout: pollinationsTimeout,
		},
	}
}

// GenerateImage generates a pixel-art image using the Pollinations API and returns base64-encoded PNG.
// The profile parameter provides visual characteristics (colors, features) that are merged into the prompt.
func (p *PollinationsService) GenerateImage(profile *AgentProfile) (string, error) {
	// Extract per-characteristic details safely.
	face, chest, rightHand, distinction := extractCharacteristics(profile.Characteristics)

	fullPrompt := fmt.Sprintf(
		`A professional, high-fidelity 2D pixel art avatar in a strict 16-bit retro video game aesthetic. `+
			`Crisp, blocky pixels, absolutely no anti-aliasing. High contrast, clean arcade sprite style. 1:1 aspect ratio.`+
			"\n\n"+
			`The character is standing in the identical full-body standing pose, with the identical size, proportions, `+
			`and central positioning as a reference robot character template. It is clad in sleek, futuristic power armor `+
			`with a simple, integrated sci-fi jacket design. Pouches and heavy detailed elements are completely removed, `+
			`replaced by a smooth, clean armored surface.`+
			"\n\n"+
			`Main armor plating color: %s. Accent color for gears, vents, and symbols: %s. `+
			`The helmet visor shows %s. The chest panel displays %s. `+
			`Unique surface detail: %s.`+
			"\n\n"+
			`Props and Pose (Strictly Preserved):`+"\n"+
			`1. Left Hand: Holding a flat, integrated data tablet with a vibrant %s neon glow. `+
			`The tablet displays glowing lines of graphical metrics, abstract symbols, and grid patterns — `+
			`but NO text, letters, or words.`+"\n"+
			`2. Right Hand: Holding %s.`+
			"\n\n"+
			`Background: Completely flat, solid dark grey (#1a1a1a), no gradients, no scenery. `+
			`No text, letters, or symbols anywhere in the image.`,
		profile.PrimaryColor,
		profile.SecondaryColor,
		face,
		chest,
		distinction,
		profile.TabletGlowColor,
		rightHand,
	)

	imageURL, err := p.callPollinationsAPI(fullPrompt)
	if err != nil {
		return "", err
	}

	// Download the image from the URL and convert to base64
	base64Image, err := p.downloadAndEncodeImage(imageURL)
	if err != nil {
		return "", fmt.Errorf("failed to download image: %w", err)
	}

	return base64Image, nil
}

// callPollinationsAPI sends a request to Pollinations API and returns the image URL.
func (p *PollinationsService) callPollinationsAPI(prompt string) (string, error) {
	reqBody := map[string]interface{}{
		"prompt":    prompt,
		"model":     "flux",
		"width":     512,
		"height":    512,
		"steps":     20,
		"guidance":  7.5,
		"seed":      -1,
		"negative":  "text, letters, words, watermark, signature",
		"sampler":   "euler",
		"scheduler": "normal",
		"upscale":   false,
		"async":     false,
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", pollinationsImageAPI, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("pollinations request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return "", fmt.Errorf("pollinations error %d: %s", resp.StatusCode, string(respBody))
	}

	var apiResp struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return "", fmt.Errorf("parse pollinations response: %w — raw: %s", err, string(respBody))
	}

	if apiResp.URL == "" {
		return "", fmt.Errorf("no image URL in pollinations response: %s", string(respBody))
	}

	return apiResp.URL, nil
}

// downloadAndEncodeImage downloads an image from a URL and returns it as base64-encoded PNG.
func (p *PollinationsService) downloadAndEncodeImage(imageURL string) (string, error) {
	req, err := http.NewRequest("GET", imageURL, nil)
	if err != nil {
		return "", err
	}

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to download image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("image download error %d", resp.StatusCode)
	}

	imageData, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read image data: %w", err)
	}

	// Encode to base64
	base64Image := base64.StdEncoding.EncodeToString(imageData)
	return base64Image, nil
}

// GenerateImageSync is a simpler synchronous method that uses Pollinations' direct image endpoint.
// It returns a direct image URL without needing to handle base64 encoding.
func (p *PollinationsService) GenerateImageSync(profile *AgentProfile) (string, error) {
	// Extract per-characteristic details safely.
	face, chest, rightHand, distinction := extractCharacteristics(profile.Characteristics)

	fullPrompt := fmt.Sprintf(
		`A professional, high-fidelity 2D pixel art avatar in a strict 16-bit retro video game aesthetic. `+
			`Crisp, blocky pixels, absolutely no anti-aliasing. High contrast, clean arcade sprite style. 1:1 aspect ratio.`+
			"\n\n"+
			`The character is standing in the identical full-body standing pose, with the identical size, proportions, `+
			`and central positioning as a reference robot character template. It is clad in sleek, futuristic power armor `+
			`with a simple, integrated sci-fi jacket design. Pouches and heavy detailed elements are completely removed, `+
			`replaced by a smooth, clean armored surface.`+
			"\n\n"+
			`Main armor plating color: %s. Accent color for gears, vents, and symbols: %s. `+
			`The helmet visor shows %s. The chest panel displays %s. `+
			`Unique surface detail: %s.`+
			"\n\n"+
			`Props and Pose (Strictly Preserved):`+"\n"+
			`1. Left Hand: Holding a flat, integrated data tablet with a vibrant %s neon glow. `+
			`The tablet displays glowing lines of graphical metrics, abstract symbols, and grid patterns — `+
			`but NO text, letters, or words.`+"\n"+
			`2. Right Hand: Holding %s.`+
			"\n\n"+
			`Background: Completely flat, solid dark grey (#1a1a1a), no gradients, no scenery. `+
			`No text, letters, or symbols anywhere in the image.`,
		profile.PrimaryColor,
		profile.SecondaryColor,
		face,
		chest,
		distinction,
		profile.TabletGlowColor,
		rightHand,
	)

	// Use the direct image endpoint: https://image.pollinations.ai
	params := url.Values{}
	params.Set("prompt", fullPrompt)
	params.Set("width", "512")
	params.Set("height", "512")
	params.Set("model", "flux")
	params.Set("negative", "text, letters, words, watermark, signature")

	directURL := "https://image.pollinations.ai/?" + params.Encode()
	return directURL, nil
}
