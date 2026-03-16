package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"time"
)

const (
	pollinationsImageAPI = "https://api.pollinations.ai/v1/images"
	pollinationsTimeout  = 30 * time.Second
	maxRetries           = 1
	initialBackoff       = 2 * time.Second
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
	fullPrompt := "Digital character design, " + BuildAvatarPrompt(profile)

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

// callPollinationsAPI sends a request to Pollinations API with retry logic and returns the image URL.
func (p *PollinationsService) callPollinationsAPI(prompt string) (string, error) {
	var lastErr error

	for attempt := 0; attempt < maxRetries; attempt++ {
		imageURL, err := p.attemptPollinationsRequest(prompt)
		if err == nil {
			return imageURL, nil
		}

		lastErr = err

		// Check if the error is retryable (server error, timeout, etc.)
		if !isRetryable(err) {
			return "", err
		}

		// Don't sleep after the last attempt
		if attempt < maxRetries-1 {
			backoffDuration := calculateBackoff(attempt)
			fmt.Printf("[Pollinations] Retry attempt %d/%d after %v (error: %v)\n", attempt+1, maxRetries-1, backoffDuration, err)
			time.Sleep(backoffDuration)
		}
	}

	return "", fmt.Errorf("pollinations failed after %d retries: %w", maxRetries, lastErr)
}

// attemptPollinationsRequest makes a single request to the Pollinations API.
func (p *PollinationsService) attemptPollinationsRequest(prompt string) (string, error) {
	reqBody := map[string]interface{}{
		"prompt":    prompt,
		"model":     "flux",
		"width":     512,
		"height":    512,
		"steps":     28,
		"guidance":  8.5,
		"seed":      -1,
		"negative":  "text, letters, words, numbers, symbols, watermark, signature, modern, sci-fi, futuristic, robot, neon, frame, border, vignette, ornament, decorative edge, card border, trading card, rounded corners, picture frame, filigree, mat board, gilded frame, ornamental border, Celtic knot, scroll border, magenta clothing, pink clothing, fuchsia",
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
		return "", fmt.Errorf("pollinations error code: %d", resp.StatusCode)
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

// isRetryable determines if an error is transient and should be retried.
func isRetryable(err error) bool {
	if err == nil {
		return false
	}

	errStr := err.Error()

	// Retry on specific HTTP status codes (5xx errors, 429 rate limit)
	retryableErrors := []string{
		"error code: 5",   // 5xx errors (500, 502, 503, 504, 522, etc.)
		"error code: 429", // Rate limit
		"timeout",
		"connection refused",
		"connection reset",
		"no such host",
	}

	for _, retryErr := range retryableErrors {
		if stringContains(errStr, retryErr) {
			return true
		}
	}

	return false
}

// calculateBackoff computes exponential backoff with jitter.
func calculateBackoff(attempt int) time.Duration {
	// Exponential backoff: 2s * 2^attempt with random jitter
	exponential := time.Duration(math.Pow(2, float64(attempt))) * initialBackoff
	jitter := time.Duration(rand.Intn(1000)) * time.Millisecond
	return exponential + jitter
}

// stringContains is a helper to check if a string contains a substring.
func stringContains(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// downloadAndEncodeImage downloads an image from a URL with retry logic and returns it as base64-encoded PNG.
func (p *PollinationsService) downloadAndEncodeImage(imageURL string) (string, error) {
	var lastErr error

	for attempt := 0; attempt < maxRetries; attempt++ {
		base64Image, err := p.attemptDownloadImage(imageURL)
		if err == nil {
			return base64Image, nil
		}

		lastErr = err

		// Check if the error is retryable
		if !isRetryable(err) {
			return "", err
		}

		// Don't sleep after the last attempt
		if attempt < maxRetries-1 {
			backoffDuration := calculateBackoff(attempt)
			fmt.Printf("[Pollinations] Image download retry %d/%d after %v (error: %v)\n", attempt+1, maxRetries-1, backoffDuration, err)
			time.Sleep(backoffDuration)
		}
	}

	return "", fmt.Errorf("image download failed after %d retries: %w", maxRetries, lastErr)
}

// attemptDownloadImage makes a single attempt to download an image from a URL.
func (p *PollinationsService) attemptDownloadImage(imageURL string) (string, error) {
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
		return "", fmt.Errorf("image download error code: %d", resp.StatusCode)
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
	fullPrompt := "Digital character design, " + BuildAvatarPrompt(profile)

	// Use the direct image endpoint: https://image.pollinations.ai
	params := url.Values{}
	params.Set("prompt", fullPrompt)
	params.Set("width", "512")
	params.Set("height", "512")
	params.Set("model", "flux")
	params.Set("negative", "text, letters, words, numbers, symbols, watermark, signature, modern, sci-fi, futuristic, robot, neon, frame, border, vignette, ornament, decorative edge, card border, trading card, rounded corners, picture frame, filigree, mat board, gilded frame, ornamental border, Celtic knot, scroll border, magenta clothing, pink clothing, fuchsia")

	directURL := "https://image.pollinations.ai/?" + params.Encode()
	return directURL, nil
}
