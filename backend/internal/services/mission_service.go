package services

import (
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
)

// MissionService handles mission CRUD and tag expansion.
type MissionService struct{}

// NewMissionService creates a new MissionService.
func NewMissionService() *MissionService {
	return &MissionService{}
}

// SaveMissionInput is the request payload for creating or updating a mission.
type SaveMissionInput struct {
	ID        string    `json:"id" binding:"required"`
	Title     string    `json:"title" binding:"required"`
	Slug      string    `json:"slug" binding:"required"`
	Prompt    string    `json:"prompt" binding:"required"`
	UseCount  int64     `json:"use_count"`
	CreatedAt time.Time `json:"created_at"`
}

// ExpandMissionInput is the request payload for expanding #slug references.
type ExpandMissionInput struct {
	Text string `json:"text" binding:"required"`
}

// ExpandMissionOutput is the response for tag expansion.
type ExpandMissionOutput struct {
	ExpandedText string   `json:"expanded_text"`
	UsedSlugs    []string `json:"used_slugs"`
}

var (
	slugRegex    = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]*$`)
	missionTagRe = regexp.MustCompile(`#([a-zA-Z0-9_-]+)`)
)

// validateMissionInput checks that all fields meet constraints.
func validateMissionInput(input SaveMissionInput) error {
	if strings.TrimSpace(input.ID) == "" {
		return fmt.Errorf("id is required")
	}
	title := strings.TrimSpace(input.Title)
	if len(title) == 0 || len(title) > 120 {
		return fmt.Errorf("title must be 1-120 characters")
	}
	slug := strings.TrimSpace(input.Slug)
	if len(slug) == 0 || len(slug) > 160 {
		return fmt.Errorf("slug must be 1-160 characters")
	}
	if !slugRegex.MatchString(slug) {
		return fmt.Errorf("slug must match ^[a-z0-9][a-z0-9_-]*$")
	}
	prompt := strings.TrimSpace(input.Prompt)
	if len(prompt) == 0 || len(prompt) > 20000 {
		return fmt.Errorf("prompt must be 1-20000 characters")
	}
	return nil
}

// ListUserMissions returns all missions for a wallet, ordered by use_count then created_at.
func (s *MissionService) ListUserMissions(wallet string) ([]models.UserMission, error) {
	var missions []models.UserMission
	err := database.DB.
		Where("user_wallet = ?", strings.ToLower(wallet)).
		Order("use_count DESC, created_at DESC").
		Find(&missions).Error
	return missions, err
}

// SaveUserMission creates or updates a mission after validation.
func (s *MissionService) SaveUserMission(wallet string, input SaveMissionInput) (*models.UserMission, error) {
	if err := validateMissionInput(input); err != nil {
		return nil, err
	}

	wallet = strings.ToLower(wallet)
	mission := &models.UserMission{}
	err := database.DB.Where("user_wallet = ? AND client_id = ?", wallet, input.ID).First(mission).Error
	if err != nil {
		mission = &models.UserMission{
			UserWallet: wallet,
			ClientID:   input.ID,
			CreatedAt:  input.CreatedAt,
		}
	}
	if mission.CreatedAt.IsZero() {
		mission.CreatedAt = time.Now()
	}
	if !input.CreatedAt.IsZero() {
		mission.CreatedAt = input.CreatedAt
	}
	mission.Title = input.Title
	mission.Slug = input.Slug
	mission.Prompt = input.Prompt
	mission.UseCount = input.UseCount

	if err := database.DB.Save(mission).Error; err != nil {
		return nil, err
	}
	return mission, nil
}

// DeleteUserMission removes a mission by wallet and client ID.
func (s *MissionService) DeleteUserMission(wallet, clientID string) error {
	return database.DB.Where("user_wallet = ? AND client_id = ?", strings.ToLower(wallet), clientID).Delete(&models.UserMission{}).Error
}

// GetMissionBySlug returns a single mission matching the given wallet and slug.
func (s *MissionService) GetMissionBySlug(wallet, slug string) (*models.UserMission, error) {
	var mission models.UserMission
	err := database.DB.Where("user_wallet = ? AND slug = ?", strings.ToLower(wallet), slug).First(&mission).Error
	if err != nil {
		return nil, err
	}
	return &mission, nil
}

// ExpandMissionTags finds #slug references in text, replaces them with the
// corresponding mission prompt, and increments use_count. Only 1 level deep
// (no recursive expansion).
func (s *MissionService) ExpandMissionTags(wallet, text string) (*ExpandMissionOutput, error) {
	wallet = strings.ToLower(wallet)
	matches := missionTagRe.FindAllStringSubmatchIndex(text, -1)
	if len(matches) == 0 {
		return &ExpandMissionOutput{ExpandedText: text, UsedSlugs: []string{}}, nil
	}

	// Deduplicate slugs while preserving replacement positions.
	type slugMatch struct {
		fullStart, fullEnd int
		slug               string
	}
	var slugMatches []slugMatch
	seen := map[string]bool{}
	for _, m := range matches {
		slug := text[m[2]:m[3]]
		slugMatches = append(slugMatches, slugMatch{fullStart: m[0], fullEnd: m[1], slug: slug})
		seen[slug] = true
	}

	// Load all referenced missions in one query.
	slugList := make([]string, 0, len(seen))
	for sl := range seen {
		slugList = append(slugList, sl)
	}
	var missions []models.UserMission
	if err := database.DB.Where("user_wallet = ? AND slug IN ?", wallet, slugList).Find(&missions).Error; err != nil {
		return nil, fmt.Errorf("failed to load missions: %w", err)
	}
	missionMap := make(map[string]*models.UserMission, len(missions))
	for i := range missions {
		missionMap[missions[i].Slug] = &missions[i]
	}

	// Replace from right to left so indices stay valid.
	expanded := text
	usedSlugs := []string{}
	usedSet := map[string]bool{}
	for i := len(slugMatches) - 1; i >= 0; i-- {
		sm := slugMatches[i]
		m, ok := missionMap[sm.slug]
		if !ok {
			continue // slug not found, leave as-is
		}
		expanded = expanded[:sm.fullStart] + m.Prompt + expanded[sm.fullEnd:]
		if !usedSet[sm.slug] {
			usedSet[sm.slug] = true
			usedSlugs = append(usedSlugs, sm.slug)
		}
	}

	// Increment use_count for all used missions.
	for _, slug := range usedSlugs {
		database.DB.Model(&models.UserMission{}).
			Where("user_wallet = ? AND slug = ?", wallet, slug).
			UpdateColumn("use_count", database.DB.Raw("use_count + 1"))
	}

	return &ExpandMissionOutput{ExpandedText: expanded, UsedSlugs: usedSlugs}, nil
}
