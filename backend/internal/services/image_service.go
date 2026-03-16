package services

import (
	"fmt"
	"os"
	"path/filepath"
)

// ImageService handles saving processed avatar images to disk and generating
// URL paths that can be served by the static file endpoint.
type ImageService struct {
	uploadDir string // e.g. "./uploads"
	baseURL   string // e.g. "" for relative URLs, or "https://api.example.com"
}

// NewImageService creates an ImageService and ensures the upload directories exist.
func NewImageService(uploadDir, baseURL string) *ImageService {
	agentsDir := filepath.Join(uploadDir, "agents")
	os.MkdirAll(agentsDir, 0755)
	return &ImageService{uploadDir: uploadDir, baseURL: baseURL}
}

// SaveAgentImage saves raw image bytes to disk and returns the relative path.
// The extension should be "webp" or "png" depending on the source.
func (s *ImageService) SaveAgentImage(agentID uint, imageBytes []byte, ext string) (string, error) {
	if ext == "" {
		ext = "webp"
	}
	filename := fmt.Sprintf("agents/%d.%s", agentID, ext)
	fullPath := filepath.Join(s.uploadDir, filename)

	// Ensure parent directory exists (idempotent)
	os.MkdirAll(filepath.Dir(fullPath), 0755)

	if err := os.WriteFile(fullPath, imageBytes, 0644); err != nil {
		return "", fmt.Errorf("write image: %w", err)
	}
	return filename, nil
}

// GetImageURL returns the full URL for a stored image given its relative path.
// If baseURL is empty, returns a relative path suitable for same-origin requests.
func (s *ImageService) GetImageURL(relativePath string) string {
	if relativePath == "" {
		return ""
	}
	if s.baseURL != "" {
		return s.baseURL + "/api/v1/images/" + relativePath
	}
	return "/api/v1/images/" + relativePath
}
