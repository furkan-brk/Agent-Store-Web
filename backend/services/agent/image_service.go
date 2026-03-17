package agent

import (
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
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

// HydrateFromDB restores missing image files from the database's generated_image
// column (base64). This is needed after container restarts where the ephemeral
// disk storage is wiped but the DB retains the image data.
func (s *ImageService) HydrateFromDB() {
	// Wait for DB readiness
	for !database.IsReady() {
		log.Println("[ImageHydrate] waiting for database...")
		time.Sleep(2 * time.Second)
	}

	var agents []models.Agent
	if err := database.DB.
		Select("id, image_url, generated_image").
		Where("image_url IS NOT NULL AND image_url != ''").
		Find(&agents).Error; err != nil {
		log.Printf("[ImageHydrate] failed to query agents: %v", err)
		return
	}

	restored := 0
	skipped := 0
	failed := 0

	for _, agent := range agents {
		relPath := agent.ImageURL
		if idx := strings.Index(relPath, "/api/v1/images/"); idx >= 0 {
			relPath = relPath[idx+len("/api/v1/images/"):]
		}
		if relPath == "" {
			continue
		}

		fullPath := filepath.Join(s.uploadDir, relPath)

		if _, err := os.Stat(fullPath); err == nil {
			skipped++
			continue
		}

		if agent.GeneratedImage == "" {
			failed++
			continue
		}

		imgBytes, err := base64.StdEncoding.DecodeString(agent.GeneratedImage)
		if err != nil || len(imgBytes) == 0 {
			log.Printf("[ImageHydrate] decode failed for agent %d: %v", agent.ID, err)
			failed++
			continue
		}

		os.MkdirAll(filepath.Dir(fullPath), 0755)
		if err := os.WriteFile(fullPath, imgBytes, 0644); err != nil {
			log.Printf("[ImageHydrate] write failed for %s: %v", fullPath, err)
			failed++
			continue
		}
		restored++
	}

	log.Printf("[ImageHydrate] complete: %d restored, %d already on disk, %d failed (total %d agents with images)",
		restored, skipped, failed, len(agents))
}
