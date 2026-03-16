package agent

import (
	"fmt"
	"os"
	"path/filepath"
)

// ImageService handles saving processed avatar images to disk and generating
// URL paths that can be served by the static file endpoint.
type ImageService struct {
	uploadDir string
	baseURL   string
}

// NewImageService creates an ImageService and ensures the upload directories exist.
func NewImageService(uploadDir, baseURL string) *ImageService {
	agentsDir := filepath.Join(uploadDir, "agents")
	os.MkdirAll(agentsDir, 0755)
	return &ImageService{uploadDir: uploadDir, baseURL: baseURL}
}

// SaveAgentImage saves raw image bytes to disk and returns the relative path.
func (s *ImageService) SaveAgentImage(agentID uint, imageBytes []byte, ext string) (string, error) {
	if ext == "" {
		ext = "webp"
	}
	filename := fmt.Sprintf("agents/%d.%s", agentID, ext)
	fullPath := filepath.Join(s.uploadDir, filename)

	os.MkdirAll(filepath.Dir(fullPath), 0755)

	if err := os.WriteFile(fullPath, imageBytes, 0644); err != nil {
		return "", fmt.Errorf("write image: %w", err)
	}
	return filename, nil
}

// GetImageURL returns the full URL for a stored image given its relative path.
func (s *ImageService) GetImageURL(relativePath string) string {
	if relativePath == "" {
		return ""
	}
	if s.baseURL != "" {
		return s.baseURL + "/api/v1/images/" + relativePath
	}
	return "/api/v1/images/" + relativePath
}
