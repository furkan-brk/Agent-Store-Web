package workspace

import (
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
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

// MissionRevisionMismatchError signals an If-Match precondition failure on a mission.
// The handler converts this to 409 Conflict with the current row in the body.
type MissionRevisionMismatchError struct {
	Current *models.UserMission
}

func (e *MissionRevisionMismatchError) Error() string {
	return "revision mismatch"
}

// SaveUserMission creates or updates a mission after validation.
//
// If ifMatchRev is non-nil and the row already exists, it must equal the row's
// current RevisionID — otherwise a *MissionRevisionMismatchError is returned.
// On create (no existing row), If-Match is ignored.
func (s *MissionService) SaveUserMission(wallet string, input SaveMissionInput, ifMatchRev *uint64) (*models.UserMission, error) {
	if err := validateMissionInput(input); err != nil {
		return nil, err
	}

	wallet = strings.ToLower(wallet)
	mission := &models.UserMission{}
	err := database.DB.Where("user_wallet = ? AND client_id = ?", wallet, input.ID).First(mission).Error
	existed := err == nil
	if err != nil {
		mission = &models.UserMission{
			UserWallet: wallet,
			ClientID:   input.ID,
			CreatedAt:  input.CreatedAt,
		}
	}

	if existed && ifMatchRev != nil && *ifMatchRev != mission.RevisionID {
		current := *mission
		return nil, &MissionRevisionMismatchError{Current: &current}
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

// BatchSyncMissions upserts multiple missions in one request and returns the
// full list of all user missions from the DB. The entire batch runs inside a
// transaction so partial failures don't leave inconsistent data.
func (s *MissionService) BatchSyncMissions(wallet string, inputs []SaveMissionInput) ([]models.UserMission, error) {
	wallet = strings.ToLower(wallet)

	tx := database.DB.Begin()
	if tx.Error != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", tx.Error)
	}
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	for _, input := range inputs {
		if err := validateMissionInput(input); err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("invalid mission %q: %w", input.ID, err)
		}

		mission := &models.UserMission{}
		err := tx.Where("user_wallet = ? AND client_id = ?", wallet, input.ID).First(mission).Error
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
		if input.UseCount > mission.UseCount {
			mission.UseCount = input.UseCount
		}

		if err := tx.Save(mission).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("failed to save mission %q: %w", input.ID, err)
		}
	}

	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return s.ListUserMissions(wallet)
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

// ─── Mission Marketplace ─────────────────────────────────────────────────────

// MissionPublicDTO is the marketplace listing shape (omits user_wallet).
type MissionPublicDTO struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Slug      string    `json:"slug"`
	Prompt    string    `json:"prompt"`
	UseCount  int64     `json:"use_count"`
	CreatedAt time.Time `json:"created_at"`
}

// ListPublicMissions returns all public missions, optionally filtered by category slug prefix.
func (s *MissionService) ListPublicMissions(catPrefix string) ([]MissionPublicDTO, error) {
	query := database.DB.Model(&models.UserMission{}).Where("public = ?", true)
	if catPrefix != "" {
		query = query.Where("slug LIKE ?", catPrefix+"%")
	}
	var missions []models.UserMission
	if err := query.Order("use_count DESC, created_at DESC").Limit(100).Find(&missions).Error; err != nil {
		return nil, err
	}
	result := make([]MissionPublicDTO, 0, len(missions))
	for _, m := range missions {
		result = append(result, MissionPublicDTO{
			ID:        m.ClientID,
			Title:     m.Title,
			Slug:      m.Slug,
			Prompt:    m.Prompt,
			UseCount:  m.UseCount,
			CreatedAt: m.CreatedAt,
		})
	}
	return result, nil
}

// ImportPublicMission copies a public mission (by client_id) into the requesting user's library.
func (s *MissionService) ImportPublicMission(wallet, clientID string) (*models.UserMission, error) {
	wallet = strings.ToLower(wallet)

	var src models.UserMission
	if err := database.DB.Where("client_id = ? AND public = ?", clientID, true).First(&src).Error; err != nil {
		return nil, fmt.Errorf("public mission not found")
	}

	// Generate a new client_id and ensure slug uniqueness for the importer.
	newID := fmt.Sprintf("imported_%s_%d", clientID, time.Now().UnixNano())
	slug := ensureUniqueSlug(wallet, src.Slug)

	imported := &models.UserMission{
		UserWallet: wallet,
		ClientID:   newID,
		Title:      src.Title,
		Slug:       slug,
		Prompt:     src.Prompt,
		CreatedAt:  time.Now(),
	}
	if err := database.DB.Create(imported).Error; err != nil {
		return nil, fmt.Errorf("failed to import mission: %w", err)
	}
	return imported, nil
}

// ensureUniqueSlug returns slug if it doesn't conflict for wallet, otherwise appends _2, _3...
func ensureUniqueSlug(wallet, slug string) string {
	candidate := slug
	for i := 2; i <= 20; i++ {
		var count int64
		database.DB.Model(&models.UserMission{}).
			Where("user_wallet = ? AND slug = ?", wallet, candidate).
			Count(&count)
		if count == 0 {
			return candidate
		}
		candidate = fmt.Sprintf("%s_%d", slug, i)
	}
	return fmt.Sprintf("%s_%d", slug, time.Now().UnixNano())
}

// SetMissionPublic toggles the public flag on a mission owned by wallet.
func (s *MissionService) SetMissionPublic(wallet, clientID string, public bool) error {
	wallet = strings.ToLower(wallet)
	result := database.DB.Model(&models.UserMission{}).
		Where("user_wallet = ? AND client_id = ?", wallet, clientID).
		UpdateColumn("public", public)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("mission not found")
	}
	return nil
}

// ExpandMissionTags finds #slug references in text, replaces them with the
// corresponding mission prompt, and increments use_count. Only 1 level deep.
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
			continue
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
			UpdateColumn("use_count", gorm.Expr("use_count + 1"))
	}

	return &ExpandMissionOutput{ExpandedText: expanded, UsedSlugs: usedSlugs}, nil
}
