package agent

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/agent/client"
	"github.com/google/uuid"
	"github.com/lib/pq"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// UserProfile holds a user's public profile data.
type UserProfile struct {
	Wallet        string         `json:"wallet"`
	Username      string         `json:"username"`
	Bio           string         `json:"bio"`
	CreatedAgents []models.Agent `json:"created_agents"`
	TotalSaves    int64          `json:"total_saves"`
	TotalAgents   int64          `json:"total_agents"`
}

// UpdateProfileInput holds the fields a user can update on their profile.
type UpdateProfileInput struct {
	Username string `json:"username"`
	Bio      string `json:"bio"`
}

// CreateAgentInput holds the request body for agent creation.
type CreateAgentInput struct {
	Title         string `json:"title" binding:"required"`
	Description   string `json:"description"`
	Prompt        string `json:"prompt" binding:"required"`
	CreatorWallet string
}

// LeaderboardEntry holds a single creator's ranking data.
type LeaderboardEntry struct {
	Wallet      string `json:"wallet"`
	TotalAgents int64  `json:"total_agents"`
	TotalSaves  int64  `json:"total_saves"`
	TotalUses   int64  `json:"total_uses"`
	Rank        int    `json:"rank"`
}

// TrialError represents a trial token generation error with an appropriate HTTP status hint.
type TrialError struct {
	Message string
	Status  int
}

func (e *TrialError) Error() string { return e.Message }

// AgentService handles all agent-related business logic.
type AgentService struct {
	aiClient        *client.AIClient
	imageSvc        *ImageService
	cache           *cache.Store
	creditsContract string
	treasuryWallet  string
}

// NewAgentService creates a new AgentService.
func NewAgentService(aiClient *client.AIClient, imageSvc *ImageService, c *cache.Store, creditsContract, treasuryWallet string) *AgentService {
	return &AgentService{
		aiClient:        aiClient,
		imageSvc:        imageSvc,
		cache:           c,
		creditsContract: strings.ToLower(creditsContract),
		treasuryWallet:  strings.ToLower(treasuryWallet),
	}
}

// ListAgents returns a page of agents with optional filtering and sorting.
//
// Search behaviour (v3.11.1): when `search` is non-empty, the SQL filter
// widens to `title ILIKE OR description ILIKE OR tags ILIKE` and pulls
// up to 200 candidates, then re-ranks them in-process with weighted
// fuzzy matching (title 3×, tags 2×, description 1× — see scoreAgent).
// The cache key is unchanged because re-ranking is deterministic.
func (s *AgentService) ListAgents(category, search, sort, creatorWallet string, page, limit int) ([]models.Agent, int64, error) {
	type cachedResult struct {
		Agents []models.Agent `json:"agents"`
		Total  int64          `json:"total"`
	}
	cacheKey := fmt.Sprintf("agents|%s|%s|%s|%s|%d|%d", category, search, sort, creatorWallet, page, limit)
	if data, ok := s.cache.Get(cacheKey); ok {
		var r cachedResult
		if err := json.Unmarshal(data, &r); err == nil {
			return r.Agents, r.Total, nil
		}
	}

	var agents []models.Agent
	var total int64
	query := database.DB.Model(&models.Agent{})
	if category != "" {
		query = query.Where("category = ?", category)
	}
	searched := strings.TrimSpace(search) != ""
	if searched {
		// Widen the candidate set so the in-process ranker has something to work with.
		// `tags` is a Postgres text[] in prod / TEXT in sqlite tests — we cast it to
		// text via `array_to_string` on Postgres (still LIKE-able) but the simple
		// pattern below works on both dialects because GORM's Where bind param is
		// applied as a text comparison.
		like := "%" + search + "%"
		query = query.Where(
			"title ILIKE ? OR description ILIKE ? OR CAST(tags AS TEXT) ILIKE ?",
			like, like, like,
		)
	}
	if creatorWallet != "" {
		query = query.Where("creator_wallet = ?", creatorWallet)
	}
	query.Count(&total)
	offset := (page - 1) * limit
	orderClause := "created_at DESC"
	switch sort {
	case "popular":
		orderClause = "(save_count * 3 + use_count * 2) DESC"
	case "saves":
		orderClause = "save_count DESC"
	case "price_asc":
		orderClause = "price ASC"
	case "price_desc":
		orderClause = "price DESC"
	case "oldest":
		orderClause = "created_at ASC"
	}

	selectCols := "id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, image_url, generated_image, price, prompt_score, card_version, created_at"

	if searched {
		// Pull a wider candidate slice (up to 200) so the Go-side weighted ranker
		// has room to surface fuzzy hits that the SQL LIKE filter accepts. Then
		// re-rank, page in-process, and return total = len(unfiltered candidates)
		// so the caller's pagination matches what they actually see.
		const candidateCap = 200
		var candidates []models.Agent
		if err := query.
			Select(selectCols).
			Order(orderClause).
			Limit(candidateCap).
			Find(&candidates).Error; err != nil {
			return nil, 0, err
		}
		ranked := rankAgentsByQuery(candidates, search)
		// Re-set total to the post-rank count — for fuzzy queries this equals
		// candidate count (we don't drop zero-score rows when total < candidateCap),
		// so the UI's "X results" stays honest.
		total = int64(len(ranked))
		// Apply page/limit in memory.
		start := min(offset, len(ranked))
		end := min(start+limit, len(ranked))
		agents = ranked[start:end]
		if b, jerr := json.Marshal(cachedResult{Agents: agents, Total: total}); jerr == nil {
			s.cache.Set(cacheKey, b, 60*time.Second)
		}
		return agents, total, nil
	}

	err := query.
		Select(selectCols).
		Offset(offset).Limit(limit).Order(orderClause).Find(&agents).Error
	if err == nil {
		if b, jerr := json.Marshal(cachedResult{Agents: agents, Total: total}); jerr == nil {
			s.cache.Set(cacheKey, b, 60*time.Second)
		}
	}
	return agents, total, err
}

// rankAgentsByQuery applies scoreAgent to every candidate and returns the
// list ordered by descending score. Zero-score rows are kept (they passed
// the SQL LIKE filter) but sorted last so the user still sees something
// when only fuzzy hits exist. Stable sort — original DB order tie-breaks.
func rankAgentsByQuery(candidates []models.Agent, query string) []models.Agent {
	if len(candidates) == 0 {
		return candidates
	}
	type scored struct {
		a models.Agent
		s float64
	}
	out := make([]scored, len(candidates))
	for i, c := range candidates {
		out[i] = scored{a: c, s: scoreAgent(c, query)}
	}
	// Insertion sort — candidate caps at 200, simple and stable.
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j].s > out[j-1].s; j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	res := make([]models.Agent, len(out))
	for i, sc := range out {
		res[i] = sc.a
	}
	return res
}

// CategoryCount holds the name and agent count for a single category.
type CategoryCount struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	Count int64  `json:"count"`
}

// categoryLabels maps stored category keys to human-readable labels.
var categoryLabels = map[string]string{
	"backend":    "Backend",
	"frontend":   "Frontend",
	"data":       "Data",
	"devops":     "DevOps",
	"security":   "Security",
	"marketing":  "Marketing",
	"writing":    "Writing",
	"education":  "Education",
	"general":    "General",
	"research":   "Research",
	"design":     "Design",
	"business":   "Business",
	"finance":    "Finance",
	"healthcare": "Healthcare",
	"legal":      "Legal",
}

// GetCategories returns all categories with their agent counts.
func (s *AgentService) GetCategories() ([]CategoryCount, error) {
	const cacheKey = "categories"
	if data, ok := s.cache.Get(cacheKey); ok {
		var cached []CategoryCount
		if err := json.Unmarshal(data, &cached); err == nil {
			return cached, nil
		}
	}

	var rows []struct {
		Category string
		Count    int64
	}
	err := database.DB.Model(&models.Agent{}).
		Select("category, count(*) as count").
		Where("category != ''").
		Group("category").
		Order("count DESC").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("query categories: %w", err)
	}

	result := make([]CategoryCount, 0, len(rows))
	for _, r := range rows {
		label := categoryLabels[r.Category]
		if label == "" {
			// Capitalize first letter as fallback
			label = strings.ToUpper(r.Category[:1]) + r.Category[1:]
		}
		result = append(result, CategoryCount{
			Key:   r.Category,
			Label: label,
			Count: r.Count,
		})
	}

	if b, jerr := json.Marshal(result); jerr == nil {
		s.cache.Set(cacheKey, b, 120*time.Second)
	}

	return result, nil
}

// GetAgent returns a single agent by ID.
func (s *AgentService) GetAgent(id uint) (*models.Agent, error) {
	var agent models.Agent
	err := database.DB.First(&agent, id).Error
	return &agent, err
}

// deductCredits atomically deducts amount credits from wallet and records both
// a legacy CreditTransaction (compat) and a CreditLedgerEntry (v3.7+).
//
// txType maps to ledger action_type (e.g. "create_agent", "fork", "topup").
// nodeRef is set for legend node executions ("workflow:node" format) and nil otherwise.
// breakdown is an optional structured cost detail (e.g. {"model":"sonnet","tokens":1234}).
func (s *AgentService) deductCredits(wallet string, amount int64, txType string, agentID *uint) error {
	return s.appendLedger(wallet, -amount, txType, agentID, nil, nil)
}

// normaliseLedgerAction maps the legacy free-form txType to the canonical
// Action label the v3.11.2 UI expects. Unknown values pass through unchanged
// so future call sites can introduce new actions without a code change here.
//
// Canonical labels: agent_purchase | legend_node | image_regen | topup |
// agent_create | agent_fork | dev_grant | "" (backward-compat for rows
// written before this normalisation existed).
func normaliseLedgerAction(txType string) string {
	switch txType {
	case "create":
		return "agent_create"
	case "fork":
		return "agent_fork"
	case "workflow_execute", "legend_run_node":
		return "legend_node"
	case "purchase":
		return "agent_purchase"
	case "regenerate_image":
		return "image_regen"
	}
	return txType
}

// appendLedger is the unified credit mutation primitive. delta is signed
// (negative=spend, positive=topup/grant). Writes both the legacy
// CreditTransaction row and the structured CreditLedgerEntry inside one
// transaction so the two histories never drift.
//
// breakdown is serialised into both CreditLedgerEntry.CostBreakdown (existing
// v3.7+ field) and CreditTransaction.Metadata (v3.11.2 new field) so legacy
// list endpoints expose per-action metadata without a join.
func (s *AgentService) appendLedger(wallet string, delta int64, actionType string, agentID *uint, nodeRef *string, breakdown map[string]any) error {
	return database.DB.Transaction(func(dbTx *gorm.DB) error {
		var user models.User
		if err := dbTx.Set("gorm:query_option", "FOR UPDATE").
			Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
			return fmt.Errorf("user not found: %w", err)
		}
		newBalance := user.Credits + delta
		if newBalance < 0 {
			return fmt.Errorf("insufficient credits: have %d, need %d", user.Credits, -delta)
		}
		if err := dbTx.Model(&models.User{}).Where("wallet_address = ?", wallet).
			UpdateColumn("credits", gorm.Expr("credits + ?", delta)).Error; err != nil {
			return fmt.Errorf("failed to apply credit delta: %w", err)
		}
		breakdownStr := ""
		if breakdown != nil {
			b, err := json.Marshal(breakdown)
			if err != nil {
				return fmt.Errorf("failed to marshal cost breakdown: %w", err)
			}
			breakdownStr = string(b)
		}
		legacyAmount := delta
		canonicalAction := normaliseLedgerAction(actionType)
		creditTx := models.CreditTransaction{
			Wallet:   wallet,
			Type:     actionType,
			Amount:   legacyAmount,
			AgentID:  agentID,
			Action:   canonicalAction,
			Metadata: breakdownStr,
		}
		if err := dbTx.Create(&creditTx).Error; err != nil {
			return fmt.Errorf("failed to write credit transaction: %w", err)
		}
		entry := models.CreditLedgerEntry{
			UserWallet:    wallet,
			Delta:         delta,
			BalanceAfter:  newBalance,
			ActionType:    actionType,
			NodeRef:       nodeRef,
			CostBreakdown: breakdownStr,
		}
		return dbTx.Create(&entry).Error
	})
}

// AppendLedger is the public ledger primitive used by other services (Workspace,
// AI Pipeline) via the in-process service handle. delta is signed.
func (s *AgentService) AppendLedger(userWallet string, delta int64, actionType string, nodeRef *string, breakdown map[string]any) error {
	return s.appendLedger(userWallet, delta, actionType, nil, nodeRef, breakdown)
}

// CreateAgent creates a new agent with concurrent AI analysis, profile generation,
// scoring, and avatar generation via the AI Pipeline Service.
func (s *AgentService) CreateAgent(input CreateAgentInput) (*models.Agent, error) {
	agentConcept := input.Title
	if input.Description != "" {
		agentConcept += ": " + input.Description
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	var (
		analysis    *client.AnalysisResult
		analysisErr error
		profile     *client.AgentProfile
		profileErr  error
		scoreResult *client.ScoreResult
		scoreErr    error
		avatarRes   *client.AvatarResult
	)

	profileCh := make(chan *client.AgentProfile, 1)

	var wg sync.WaitGroup
	wg.Add(4)

	// goroutine 1: Analyze prompt
	go func() {
		defer wg.Done()
		analysis, analysisErr = s.aiClient.Analyze(ctx, input.Prompt)
	}()

	// goroutine 2: Generate profile
	go func() {
		defer wg.Done()
		profile, profileErr = s.aiClient.Profile(ctx, agentConcept)
		if profileErr == nil && profile != nil {
			profileCh <- profile
		}
		close(profileCh)
	}()

	// goroutine 3: Score prompt
	go func() {
		defer wg.Done()
		scoreResult, scoreErr = s.aiClient.Score(ctx, input.Prompt)
	}()

	// goroutine 4: Generate avatar (waits briefly for real profile)
	go func() {
		defer wg.Done()
		var imageProfile *client.AgentProfile
		select {
		case realProfile := <-profileCh:
			if realProfile != nil {
				imageProfile = realProfile
				log.Printf("[Avatar] using real LLM profile for image generation")
			}
		case <-time.After(2 * time.Second):
			log.Printf("[Avatar] real profile not ready in 2s, starting with fallback")
		}
		// Fallback: let AI Pipeline decide if profile is nil
		if imageProfile == nil {
			imageProfile = &client.AgentProfile{Name: agentConcept}
		}
		prelimTypes := []string{"wizard", "strategist", "oracle", "guardian", "artisan", "bard", "scholar", "merchant"}
		charType := prelimTypes[rand.Intn(len(prelimTypes))]
		imagePrompt := "A " + charType + " character with unique abilities and tools"
		avatarRes, _ = s.aiClient.Avatar(ctx, imageProfile, imagePrompt, charType)
	}()

	wg.Wait()

	// Handle analysis result
	if analysisErr != nil {
		log.Printf("[Agent] analysis failed, using fallback: %v", analysisErr)
		allTypes := []string{"wizard", "strategist", "oracle", "guardian", "artisan", "bard", "scholar", "merchant"}
		fallbackType := allTypes[rand.Intn(len(allTypes))]
		analysis = &client.AnalysisResult{
			CharacterType: fallbackType,
			Category:      "general",
			Tags:          []string{"agent"},
			Rarity:        "common",
			ImagePrompt:   "A " + fallbackType + " character with unique abilities and tools",
		}
	}

	rarity := models.CharacterRarity(analysis.Rarity)

	// Handle profile result
	if profileErr != nil {
		log.Printf("[Agent] profile generation failed: %v", profileErr)
	} else if profile != nil {
		log.Printf("[Agent] agent profile generated: name=%q type=%s", profile.Name, analysis.CharacterType)
	}

	// Build character data via AI Pipeline
	charData := "{}"
	charResult, charErr := s.aiClient.Character(ctx, analysis.CharacterType, analysis.Subclass, string(rarity), input.Prompt)
	if charErr == nil && charResult != nil {
		charData = charResult.CharacterData
	}

	// Handle score
	promptScore := 0
	serviceDesc := ""
	if scoreErr == nil && scoreResult != nil {
		promptScore = scoreResult.TotalScore
		serviceDesc = scoreResult.ServiceDescription
	}

	// Deduct 10 credits for agent creation
	if input.CreatorWallet != "" {
		if err := s.deductCredits(input.CreatorWallet, 10, "create", nil); err != nil {
			return nil, fmt.Errorf("credit check failed: %w", err)
		}
	}

	// Determine generated image base64
	generatedImage := ""
	if avatarRes != nil && avatarRes.ImageBase64 != "" {
		generatedImage = avatarRes.ImageBase64
	}

	// Persist
	agent := &models.Agent{
		Title:              input.Title,
		Description:        input.Description,
		Prompt:             input.Prompt,
		Category:           analysis.Category,
		CreatorWallet:      input.CreatorWallet,
		CharacterType:      analysis.CharacterType,
		Subclass:           analysis.Subclass,
		CharacterData:      charData,
		Rarity:             rarity,
		Tags:               analysis.Tags,
		GeneratedImage:     generatedImage,
		PromptScore:        promptScore,
		ServiceDescription: serviceDesc,
		CardVersion:        "2.0",
	}
	if err := database.DB.Create(agent).Error; err != nil {
		return nil, err
	}

	// Process image: save to disk, update ImageURL
	s.processAndSaveImage(agent, generatedImage, avatarRes)

	if input.CreatorWallet != "" {
		wallet := strings.ToLower(input.CreatorWallet)
		entry := models.LibraryEntry{UserWallet: wallet, AgentID: agent.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).Where("id = ?", agent.ID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	}
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	s.cache.Delete("categories")
	// Record activity (best-effort).
	s.RecordActivity(input.CreatorWallet, models.ActivityAgentCreated, agent.ID, map[string]any{
		"title": agent.Title,
	})
	return agent, nil
}

// processAndSaveImage saves avatar bytes to disk and updates DB.
func (s *AgentService) processAndSaveImage(agent *models.Agent, generatedImage string, avatarRes *client.AvatarResult) {
	if generatedImage == "" {
		return
	}

	// Decode the base64 image
	imgBytes, err := base64.StdEncoding.DecodeString(generatedImage)
	if err != nil || len(imgBytes) == 0 {
		return
	}

	format := "png"
	if avatarRes != nil && avatarRes.Format != "" {
		format = avatarRes.Format
	}

	// Save to disk
	if s.imageSvc != nil {
		relPath, saveErr := s.imageSvc.SaveAgentImage(agent.ID, imgBytes, format)
		if saveErr == nil {
			imageURL := s.imageSvc.GetImageURL(relPath)
			agent.ImageURL = imageURL
			database.DB.Model(agent).Update("image_url", imageURL)
			log.Printf("[Image] saved %s (%d bytes) for agent %d", relPath, len(imgBytes), agent.ID)
		} else {
			log.Printf("[Image] failed to save file for agent %d: %v", agent.ID, saveErr)
		}
	}

	// Keep base64 in GeneratedImage for backwards compatibility
	agent.GeneratedImage = generatedImage
	database.DB.Model(agent).Update("generated_image", generatedImage)
}

// GetLibrary returns all library entries for a wallet.
//
// Wallet matching is case-insensitive (LOWER(user_wallet) = LOWER(?)) so
// entries written before the v3.7 wallet-lowercasing pass are still surfaced
// correctly when the JWT carries a lowercased wallet. Returns an allocated
// empty slice (never nil) so the JSON response is `{"entries":[]}` and the
// frontend never has to parse `null`.
func (s *AgentService) GetLibrary(wallet string) ([]models.LibraryEntry, error) {
	entries := make([]models.LibraryEntry, 0)
	err := database.DB.Preload("Agent", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, image_url, generated_image, price, prompt_score, card_version, created_at, updated_at")
	}).Where("LOWER(user_wallet) = LOWER(?)", wallet).
		Order("saved_at DESC").
		Find(&entries).Error
	return entries, err
}

// AddToLibrary adds an agent to a user's library.
//
// Idempotent: re-adding an already-saved agent is a no-op (no save_count bump).
// On a fresh insert, bumps the agent's save_count and busts the agents/trending
// cache so list and trending endpoints reflect the new count immediately.
//
// Wallet is normalised to lowercase before insertion and matched case-
// insensitively on lookup so a single user is never split across casings.
func (s *AgentService) AddToLibrary(wallet string, agentID uint) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return errors.New("wallet required")
	}
	var existing models.LibraryEntry
	if database.DB.Where("LOWER(user_wallet) = ? AND agent_id = ?", wallet, agentID).
		First(&existing).Error == nil {
		return nil
	}
	entry := models.LibraryEntry{UserWallet: wallet, AgentID: agentID}
	if err := database.DB.Create(&entry).Error; err != nil {
		return err
	}
	database.DB.Model(&models.Agent{}).Where("id = ?", agentID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	s.cache.DeletePrefix("agents|")
	s.cache.DeletePrefix("similar|")
	s.cache.Delete("trending")
	s.cache.Delete("for-you|" + wallet)
	s.RecordActivity(wallet, models.ActivityAgentSaved, agentID, nil)

	// v3.11.3: notify the creator that someone saved their agent. Synchronous
	// (matches RecordActivity pattern) — no goroutine, so t.Cleanup can't race
	// the inbox write. Self-saves don't notify.
	var saved models.Agent
	if err := database.DB.Select("id, title, creator_wallet").First(&saved, agentID).Error; err == nil {
		creator := strings.ToLower(saved.CreatorWallet)
		if creator != "" && creator != wallet {
			s.notifyOnce(
				creator,
				"social",
				"New library save",
				saved.Title+" was added to a library",
				fmt.Sprintf("/agent/%d", agentID),
			)
		}
	}
	return nil
}

// RemoveFromLibrary removes an agent from a user's library.
//
// Symmetric with AddToLibrary: decrements the agent's save_count (clamped at 0)
// and busts the agents/trending cache. Also no-op if the entry didn't exist.
// Wallet matching is case-insensitive to mirror AddToLibrary/GetLibrary.
func (s *AgentService) RemoveFromLibrary(wallet string, agentID uint) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return errors.New("wallet required")
	}
	res := database.DB.Where("LOWER(user_wallet) = ? AND agent_id = ?", wallet, agentID).
		Delete(&models.LibraryEntry{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		// CASE WHEN clamps at 0 in case of any race or pre-existing skew.
		// Dialect-agnostic; works on both Postgres (prod) and sqlite (tests).
		database.DB.Model(&models.Agent{}).
			Where("id = ?", agentID).
			UpdateColumn("save_count", gorm.Expr("CASE WHEN save_count > 0 THEN save_count - 1 ELSE 0 END"))
		s.cache.DeletePrefix("agents|")
		s.cache.DeletePrefix("similar|")
		s.cache.Delete("trending")
		s.cache.Delete("for-you|" + wallet)
	}
	return nil
}

// GetUserCredits returns the credit balance for a wallet.
func (s *AgentService) GetUserCredits(wallet string) (int64, error) {
	var user models.User
	err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return 0, nil
	}
	return user.Credits, err
}

// GetTrending returns the top 6 agents ranked by weighted score.
func (s *AgentService) GetTrending() ([]models.Agent, error) {
	const cacheKey = "trending"
	if data, ok := s.cache.Get(cacheKey); ok {
		var agents []models.Agent
		if err := json.Unmarshal(data, &agents); err == nil {
			return agents, nil
		}
	}
	var agents []models.Agent
	err := database.DB.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, image_url, generated_image, price, prompt_score, card_version, created_at").
		Order("(save_count * 3 + use_count * 2) DESC").
		Limit(6).
		Find(&agents).Error
	if err == nil {
		if b, jerr := json.Marshal(agents); jerr == nil {
			s.cache.Set(cacheKey, b, 120*time.Second)
		}
	}
	return agents, err
}

// GetSimilar returns up to `limit` agents that share the source agent's
// character_type, ordered by a simple in-process similarity score
// (character type + subclass + rarity proximity + save_count tiebreaker).
//
// The source agent itself is excluded. Cached for 5 minutes per (id, limit)
// pair; AddToLibrary / RemoveFromLibrary bust the `similar|` prefix so
// save_count changes propagate without waiting for the TTL.
//
// Returns an empty slice (never nil) when no agents of that type exist.
func (s *AgentService) GetSimilar(agentID uint, limit int) ([]models.Agent, error) {
	if limit <= 0 || limit > 10 {
		limit = 5
	}
	cacheKey := fmt.Sprintf("similar|%d|%d", agentID, limit)
	if data, ok := s.cache.Get(cacheKey); ok {
		var cached []models.Agent
		if err := json.Unmarshal(data, &cached); err == nil {
			return cached, nil
		}
	}

	var src models.Agent
	if err := database.DB.First(&src, agentID).Error; err != nil {
		return nil, err
	}

	// Pull a wider candidate slice (limit*4) so the in-process ranker has
	// breathing room for subclass/rarity boosts.
	candidates := make([]models.Agent, 0)
	if err := database.DB.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, image_url, generated_image, price, prompt_score, card_version, created_at").
		Where("character_type = ? AND id <> ?", src.CharacterType, agentID).
		Order("save_count DESC, use_count DESC").
		Limit(limit * 4).
		Find(&candidates).Error; err != nil {
		return nil, err
	}

	out := rankBySimilarity(candidates, src, limit)
	if out == nil {
		out = []models.Agent{}
	}
	if b, jerr := json.Marshal(out); jerr == nil {
		s.cache.Set(cacheKey, b, 5*time.Minute)
	}
	return out, nil
}

// ForkAgent creates a copy of an existing agent for the authenticated user.
func (s *AgentService) ForkAgent(originalID uint, creatorWallet string) (*models.Agent, error) {
	var original models.Agent
	if err := database.DB.First(&original, originalID).Error; err != nil {
		return nil, fmt.Errorf("original agent not found: %w", err)
	}

	// Generate a fresh avatar via AI Pipeline. aiClient is nil in unit tests
	// — skip the network call and let downstream code carry an empty image.
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	var avatarRes *client.AvatarResult
	if s.aiClient != nil {
		forkProfile := &client.AgentProfile{Name: original.Title}
		avatarRes, _ = s.aiClient.Avatar(ctx, forkProfile, "A variant of "+original.CharacterType+" agent", original.CharacterType)
	}

	// Deduct 5 credits
	if creatorWallet != "" {
		if err := s.deductCredits(creatorWallet, 5, "fork", &original.ID); err != nil {
			return nil, fmt.Errorf("credit check failed: %w", err)
		}
	}

	generatedImage := ""
	if avatarRes != nil {
		generatedImage = avatarRes.ImageBase64
	}

	fork := &models.Agent{
		Title:         original.Title + " (Fork)",
		Description:   "Forked from: " + original.Title,
		Prompt:        "",
		Category:      original.Category,
		CreatorWallet: creatorWallet,
		CharacterType: original.CharacterType,
		Subclass:      original.Subclass,
		CharacterData: original.CharacterData,
		Rarity:        original.Rarity,
		Tags:          original.Tags,
		CardVersion:   "2.0",
	}

	if err := database.DB.Create(fork).Error; err != nil {
		return nil, err
	}

	s.processAndSaveImage(fork, generatedImage, avatarRes)

	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	s.cache.Delete("categories")

	if creatorWallet != "" {
		entry := models.LibraryEntry{UserWallet: strings.ToLower(creatorWallet), AgentID: fork.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).Where("id = ?", fork.ID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	}
	s.RecordActivity(creatorWallet, models.ActivityAgentForked, fork.ID, map[string]any{
		"original_id":    originalID,
		"original_title": fork.Title,
	})

	// v3.11.3: notify the *original* creator of the fork so they know their
	// agent is being remixed. Skip self-forks.
	originalCreator := strings.ToLower(original.CreatorWallet)
	if originalCreator != "" && originalCreator != strings.ToLower(creatorWallet) {
		s.notifyOnce(
			originalCreator,
			"social",
			"Your agent was forked",
			original.Title+" was forked into a new variant",
			fmt.Sprintf("/agent/%d", fork.ID),
		)
	}

	return fork, nil
}

// ChatWithAgent sends a user message to the agent via the AI Pipeline chat endpoint.
func (s *AgentService) ChatWithAgent(agentID uint, userMessage string) (string, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return "", fmt.Errorf("agent not found: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	reply, err := s.aiClient.Chat(ctx, agent.Prompt, userMessage)
	if err != nil {
		return "", err
	}

	database.DB.Model(&models.Agent{}).
		Where("id = ?", agentID).
		UpdateColumn("use_count", gorm.Expr("use_count + 1"))

	return reply, nil
}

// GenerateTrialToken creates a one-time trial token for the encrypted CLI trial system.
func (s *AgentService) GenerateTrialToken(agentID uint, wallet, provider, message string) (string, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return "", &TrialError{Message: "agent not found", Status: 404}
	}

	var existing models.TrialUse
	if database.DB.Where("wallet = ? AND agent_id = ?", wallet, agentID).First(&existing).Error == nil {
		return "", &TrialError{Message: "trial already used for this agent — purchase to continue", Status: 403}
	}

	validProviders := map[string]bool{"claude": true, "openai": true, "gemini": true}
	if !validProviders[provider] {
		return "", &TrialError{Message: "invalid provider: must be claude, openai, or gemini", Status: 400}
	}

	token := uuid.New().String()
	trialToken := models.TrialToken{
		Token:       token,
		AgentID:     agentID,
		Wallet:      wallet,
		Provider:    provider,
		UserMessage: message,
		ExpiresAt:   time.Now().Add(10 * time.Minute),
	}
	if err := database.DB.Create(&trialToken).Error; err != nil {
		return "", &TrialError{Message: "failed to create trial token", Status: 500}
	}

	return token, nil
}

// GetCreditHistory returns the last 50 credit transactions for a wallet (legacy
// endpoint — preserved so existing frontend keeps working).
func (s *AgentService) GetCreditHistory(wallet string) ([]models.CreditTransaction, error) {
	var txs []models.CreditTransaction
	if err := database.DB.
		Where("wallet = ?", wallet).
		Order("created_at DESC").
		Limit(50).
		Find(&txs).Error; err != nil {
		return nil, err
	}
	for i, tx := range txs {
		if tx.AgentID != nil {
			var agent models.Agent
			if database.DB.Select("title").First(&agent, *tx.AgentID).Error == nil {
				txs[i].AgentTitle = agent.Title
			}
		}
	}
	return txs, nil
}

// GetCreditLedger returns paginated CreditLedgerEntry rows for a wallet, newest first.
func (s *AgentService) GetCreditLedger(wallet string, page, limit int) ([]models.CreditLedgerEntry, int64, error) {
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	var entries []models.CreditLedgerEntry
	var total int64
	q := database.DB.Model(&models.CreditLedgerEntry{}).Where("user_wallet = ?", wallet)
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	offset := (page - 1) * limit
	if err := q.Order("created_at DESC, id DESC").
		Offset(offset).Limit(limit).
		Find(&entries).Error; err != nil {
		return nil, 0, err
	}
	return entries, total, nil
}

// GetLeaderboard returns top 10 creators ranked by total saves.
func (s *AgentService) GetLeaderboard() ([]LeaderboardEntry, error) {
	type row struct {
		Wallet      string
		TotalAgents int64
		TotalSaves  int64
		TotalUses   int64
	}
	var rows []row
	err := database.DB.Model(&models.Agent{}).
		Select("creator_wallet as wallet, COUNT(*) as total_agents, SUM(save_count) as total_saves, SUM(use_count) as total_uses").
		Where("creator_wallet != ''").
		Group("creator_wallet").
		Order("total_saves DESC").
		Limit(10).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	result := make([]LeaderboardEntry, len(rows))
	for i, r := range rows {
		result[i] = LeaderboardEntry{
			Wallet:      r.Wallet,
			TotalAgents: r.TotalAgents,
			TotalSaves:  r.TotalSaves,
			TotalUses:   r.TotalUses,
			Rank:        i + 1,
		}
	}
	return result, nil
}

// RecordPurchase records a successful on-chain purchase of an agent.
//
// In addition to inserting the PurchasedAgent row, v3.11.2 writes a
// CreditTransaction with Action="agent_purchase" + metadata so the credit
// history UI can render a per-action breakdown (which agent, what price)
// without re-querying the agent table.
//
// Note: this MON purchase is on-chain — no credits are deducted from the
// internal ledger. We persist the transaction row purely for history display
// (Amount=0, Action=agent_purchase) so users see a complete activity timeline.
func (s *AgentService) RecordPurchase(buyerWallet string, agentID uint, txHash string, amountMon float64) error {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return fmt.Errorf("agent not found: %w", err)
	}

	if err := verifyMonadTransaction(txHash, buyerWallet, s.expectedToAddresses(), amountMon); err != nil {
		return fmt.Errorf("transaction verification failed: %w", err)
	}

	if err := database.DB.Transaction(func(dbTx *gorm.DB) error {
		var existing models.PurchasedAgent
		if dbTx.Where("buyer_wallet = ? AND agent_id = ?", buyerWallet, agentID).First(&existing).Error == nil {
			return nil // already purchased — idempotent
		}
		purchase := models.PurchasedAgent{
			BuyerWallet: buyerWallet,
			AgentID:     agentID,
			TxHash:      txHash,
			AmountMon:   amountMon,
		}
		if err := dbTx.Create(&purchase).Error; err != nil {
			return err
		}
		// v3.11.2: write a CreditTransaction row purely for the credit history
		// UI. Best-effort: a failure here does NOT roll back the purchase.
		txHashPtr := &txHash
		metadata, _ := json.Marshal(map[string]any{
			"agent_id":   agentID,
			"agent_title": agent.Title,
			"price_mon":  amountMon,
			"price":      agent.Price,
			"tx_hash":    txHash,
		})
		_ = dbTx.Create(&models.CreditTransaction{
			Wallet:   strings.ToLower(buyerWallet),
			Type:     "purchase",
			Amount:   0, // on-chain spend, not internal credit deduction
			AgentID:  &agentID,
			TxHash:   txHashPtr,
			Action:   "agent_purchase",
			Metadata: string(metadata),
		}).Error
		return nil
	}); err != nil {
		return err
	}

	// v3.11.3: notify both sides of a successful purchase. Outside the
	// transaction so a notification failure can't roll the purchase back.
	creator := strings.ToLower(agent.CreatorWallet)
	buyer := strings.ToLower(buyerWallet)
	if creator != "" && creator != buyer {
		s.notifyOnce(
			creator,
			"credit",
			"Your agent was purchased",
			agent.Title+" was purchased for "+strconv.FormatFloat(amountMon, 'f', -1, 64)+" MON",
			fmt.Sprintf("/agent/%d", agentID),
		)
	}
	if buyer != "" {
		s.notifyOnce(
			buyer,
			"system",
			"Purchase confirmed",
			agent.Title+" is now in your library",
			fmt.Sprintf("/agent/%d", agentID),
		)
	}
	return nil
}

// IsPurchased checks if a wallet has purchased the agent.
func (s *AgentService) IsPurchased(buyerWallet string, agentID uint) bool {
	var p models.PurchasedAgent
	return database.DB.Where("buyer_wallet = ? AND agent_id = ?", buyerWallet, agentID).First(&p).Error == nil
}

// UpdateAgentRequest is the whitelist of fields a creator may patch on their agent.
// Pointer fields are nil when not present in the request body.
//
// Note: `stats` is intentionally excluded — those values come out of the
// analysis pipeline at creation/regeneration time and must not be hand-tuned.
// Same rationale as `character_type` and `rarity`.
type UpdateAgentRequest struct {
	Title              *string  `json:"title"`
	Description        *string  `json:"description"`
	Prompt             *string  `json:"prompt"`
	Category           *string  `json:"category"`
	Subclass           *string  `json:"subclass"`
	Tags               []string `json:"tags"`
	Price              *float64 `json:"price"`
	CardVersion        *string  `json:"card_version"`
	ServiceDescription *string  `json:"service_description"`
	ProfileMood        *string  `json:"profile_mood"`
	ProfileRolePurpose *string  `json:"profile_role_purpose"`
	Traits             []string `json:"traits"`
}

// RevisionMismatchError signals that an If-Match precondition failed. The
// handler converts this to a 409 Conflict with the current row in the body.
type RevisionMismatchError struct {
	Current *models.Agent
}

func (e *RevisionMismatchError) Error() string {
	return "revision mismatch"
}

// UpdateAgent allows a creator to update a wide whitelist of fields on their own agent.
// Column-level fields are written via GORM Updates(); fields living inside character_data
// (stats, traits, profile.mood, profile.role_purpose) are merged into the JSON blob.
//
// If ifMatchRev is non-nil and differs from the row's current RevisionID, this returns
// a *RevisionMismatchError carrying the current row so the handler can answer 409.
func (s *AgentService) UpdateAgent(agentID uint, wallet string, req *UpdateAgentRequest, ifMatchRev *uint64) (*models.Agent, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return nil, fmt.Errorf("agent not found")
	}
	if agent.CreatorWallet != wallet {
		return nil, fmt.Errorf("unauthorized: you can only edit your own agents")
	}
	if ifMatchRev != nil && *ifMatchRev != agent.RevisionID {
		current := agent
		return nil, &RevisionMismatchError{Current: &current}
	}

	updates := map[string]any{}
	if req.Title != nil && *req.Title != "" {
		updates["title"] = *req.Title
	}
	if req.Description != nil && *req.Description != "" {
		updates["description"] = *req.Description
	}
	if req.Prompt != nil && *req.Prompt != "" {
		updates["prompt"] = *req.Prompt
	}
	if req.Category != nil {
		updates["category"] = *req.Category
	}
	if req.Subclass != nil {
		updates["subclass"] = *req.Subclass
	}
	if req.Tags != nil {
		updates["tags"] = pq.StringArray(req.Tags)
	}
	if req.Price != nil {
		updates["price"] = *req.Price
	}
	if req.CardVersion != nil {
		updates["card_version"] = *req.CardVersion
	}
	if req.ServiceDescription != nil {
		updates["service_description"] = *req.ServiceDescription
	}

	// Merge traits / profile into character_data JSON blob. (Stats are
	// owned by the analysis pipeline and never accepted from the editor.)
	needsJSONMerge := req.Traits != nil || req.ProfileMood != nil || req.ProfileRolePurpose != nil
	if needsJSONMerge {
		charData := map[string]any{}
		if agent.CharacterData != "" {
			if err := json.Unmarshal([]byte(agent.CharacterData), &charData); err != nil {
				log.Printf("[UpdateAgent] character_data unmarshal failed (will reset): %v", err)
				charData = map[string]any{}
			}
		}
		if req.Traits != nil {
			charData["traits"] = req.Traits
		}
		if req.ProfileMood != nil || req.ProfileRolePurpose != nil {
			profile, _ := charData["profile"].(map[string]any)
			if profile == nil {
				profile = map[string]any{}
			}
			if req.ProfileMood != nil {
				profile["mood"] = *req.ProfileMood
			}
			if req.ProfileRolePurpose != nil {
				profile["role_purpose"] = *req.ProfileRolePurpose
			}
			charData["profile"] = profile
		}
		blob, err := json.Marshal(charData)
		if err != nil {
			return nil, fmt.Errorf("character_data marshal failed: %w", err)
		}
		updates["character_data"] = string(blob)
	}

	if len(updates) == 0 {
		return &agent, nil
	}

	if err := database.DB.Model(&agent).Updates(updates).Error; err != nil {
		return nil, fmt.Errorf("update failed: %w", err)
	}
	database.DB.First(&agent, agentID)

	// v3.11.3: snapshot post-update state into AgentVersion for history/rollback.
	// Best-effort — failure is logged inside snapshotAgentVersion and never
	// surfaces to the caller.
	s.snapshotAgentVersion(agentID)

	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	s.cache.Delete("categories")

	return &agent, nil
}

// RegenerateImage regenerates the avatar image for a creator's own agent.
func (s *AgentService) RegenerateImage(agentID uint, wallet string) (*models.Agent, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return nil, fmt.Errorf("agent not found")
	}
	if agent.CreatorWallet != wallet {
		return nil, fmt.Errorf("unauthorized: you can only regenerate your own agents")
	}

	// Check 24-hour cooldown
	if agent.LastImageRegen != nil {
		cooldown := agent.LastImageRegen.Add(24 * time.Hour)
		if time.Now().Before(cooldown) {
			remaining := time.Until(cooldown).Round(time.Minute)
			return nil, fmt.Errorf("image regeneration available in %s", remaining)
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	concept := agent.Title
	if agent.Description != "" {
		concept += ": " + agent.Description
	}

	// Generate profile and avatar via AI Pipeline
	profile, profileErr := s.aiClient.Profile(ctx, concept)
	if profileErr != nil {
		log.Printf("[RegenerateImage] profile generation failed: %v", profileErr)
		profile = &client.AgentProfile{Name: concept}
	}

	imagePrompt := "A " + agent.CharacterType + " character with unique abilities and tools"
	avatarRes, _ := s.aiClient.Avatar(ctx, profile, imagePrompt, agent.CharacterType)

	generatedImage := ""
	if avatarRes != nil {
		generatedImage = avatarRes.ImageBase64
	}

	// Update regen timestamp
	now := time.Now()
	database.DB.Model(&agent).Updates(map[string]any{
		"last_image_regen": now,
	})

	s.processAndSaveImage(&agent, generatedImage, avatarRes)

	database.DB.First(&agent, agentID)

	// v3.11.2: log image_regen in the credit history UI as a zero-cost action
	// (free for owners; future v3.11.3 may attach a credit cost).
	metadata, _ := json.Marshal(map[string]any{
		"agent_id":    agentID,
		"agent_title": agent.Title,
	})
	_ = database.DB.Create(&models.CreditTransaction{
		Wallet:   strings.ToLower(wallet),
		Type:     "regenerate_image",
		Amount:   0,
		AgentID:  &agentID,
		Action:   "image_regen",
		Metadata: string(metadata),
	}).Error

	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	s.cache.Delete("categories")

	return &agent, nil
}

// SetAgentPrice allows a creator to set the price of their agent.
func (s *AgentService) SetAgentPrice(agentID uint, creatorWallet string, price float64) error {
	result := database.DB.Model(&models.Agent{}).
		Where("id = ? AND creator_wallet = ?", agentID, creatorWallet).
		Update("price", price)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("agent not found or not owned by wallet")
	}
	return nil
}

// RateAgent creates or updates a rating for an agent.
func (s *AgentService) RateAgent(agentID uint, wallet string, rating int, comment string) error {
	if rating < 1 || rating > 5 {
		return fmt.Errorf("rating must be between 1 and 5")
	}
	var existing models.AgentRating
	err := database.DB.Where("agent_id = ? AND wallet = ?", agentID, wallet).First(&existing).Error
	if err == nil {
		return database.DB.Model(&existing).Updates(map[string]any{
			"rating":  rating,
			"comment": comment,
		}).Error
	}
	r := models.AgentRating{AgentID: agentID, Wallet: wallet, Rating: rating, Comment: comment}
	return database.DB.Create(&r).Error
}

// GetRatings returns ratings, average, and count for an agent. Hidden=true
// rows (auto-hidden by FlagRating) are filtered out of both the list and the
// average so a flagged spam comment can't drag the visible score down.
func (s *AgentService) GetRatings(agentID uint) ([]models.AgentRating, float64, int64, error) {
	var ratings []models.AgentRating
	err := database.DB.
		Where("agent_id = ? AND hidden = ?", agentID, false).
		Order("created_at DESC").Limit(20).Find(&ratings).Error
	if err != nil {
		return nil, 0, 0, err
	}
	var avg float64
	var count int64
	database.DB.Model(&models.AgentRating{}).
		Where("agent_id = ? AND hidden = ?", agentID, false).Count(&count)
	if count > 0 {
		database.DB.Model(&models.AgentRating{}).
			Where("agent_id = ? AND hidden = ?", agentID, false).
			Select("AVG(rating)").Row().Scan(&avg)
	}
	return ratings, avg, count, nil
}

// GetUserRating returns the authenticated user's rating for an agent.
func (s *AgentService) GetUserRating(agentID uint, wallet string) int {
	var r models.AgentRating
	err := database.DB.Session(&gorm.Session{Logger: logger.Discard}).
		Where("agent_id = ? AND wallet = ?", agentID, wallet).First(&r).Error
	if err != nil {
		return 0
	}
	return r.Rating
}

// MarkRatingHelpful records a wallet's "helpful" upvote on a specific rating
// and returns the new helpful count (or the existing count if the wallet
// already voted). Idempotent: a second call from the same wallet is a no-op.
//
// The transaction holds a row-level lock on the AgentRating row so concurrent
// upvotes from different wallets cannot race past the unique-index check on
// RatingHelpfulVote and over-count the counter.
func (s *AgentService) MarkRatingHelpful(ratingID uint, wallet string) (int64, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return 0, fmt.Errorf("wallet required")
	}
	var newHelpful int64
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		var rating models.AgentRating
		if err := tx.Set("gorm:query_option", "FOR UPDATE").
			Where("id = ?", ratingID).First(&rating).Error; err != nil {
			return fmt.Errorf("rating %d not found: %w", ratingID, err)
		}
		// Self-helpful is disallowed — the author can't boost their own rating.
		if strings.EqualFold(rating.Wallet, wallet) {
			return fmt.Errorf("cannot mark your own rating as helpful")
		}
		// Already voted? Return current count, no change.
		var existing models.RatingHelpfulVote
		err := tx.Where("rating_id = ? AND wallet = ?", ratingID, wallet).First(&existing).Error
		if err == nil {
			newHelpful = rating.Helpful
			return nil
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		// Insert vote + bump counter atomically.
		if err := tx.Create(&models.RatingHelpfulVote{RatingID: ratingID, Wallet: wallet}).Error; err != nil {
			return err
		}
		if err := tx.Model(&rating).
			UpdateColumn("helpful", gorm.Expr("helpful + 1")).Error; err != nil {
			return err
		}
		newHelpful = rating.Helpful + 1
		return nil
	})
	return newHelpful, err
}

// TopUpCredits grants credits after verifying MON payment on-chain. Writes
// both the legacy CreditTransaction (with tx_hash for replay protection) and
// a CreditLedgerEntry (action_type=topup, breakdown carries amount_mon + tx_hash).
func (s *AgentService) TopUpCredits(wallet, txHash string, amountMon float64) error {
	credits := int64(amountMon * 100)
	if credits < 10 {
		return fmt.Errorf("minimum top-up is 0.1 MON (10 credits)")
	}

	if err := verifyMonadTransaction(txHash, wallet, s.expectedToAddresses(), amountMon); err != nil {
		return fmt.Errorf("transaction verification failed: %w", err)
	}

	// Ensure the user row exists so the ledger primitive can find it.
	var user models.User
	if database.DB.Where("wallet_address = ?", wallet).First(&user).Error != nil {
		if err := database.DB.Create(&models.User{WalletAddress: wallet, Credits: 0}).Error; err != nil {
			return fmt.Errorf("create user: %w", err)
		}
	}

	return database.DB.Transaction(func(dbTx *gorm.DB) error {
		var u models.User
		if err := dbTx.Set("gorm:query_option", "FOR UPDATE").
			Where("wallet_address = ?", wallet).First(&u).Error; err != nil {
			return fmt.Errorf("user not found: %w", err)
		}
		if err := dbTx.Model(&models.User{}).Where("wallet_address = ?", wallet).
			UpdateColumn("credits", gorm.Expr("credits + ?", credits)).Error; err != nil {
			return fmt.Errorf("failed to add credits: %w", err)
		}
		txHashPtr := &txHash
		breakdown, _ := json.Marshal(map[string]any{
			"amount_mon": amountMon,
			"tx_hash":    txHash,
		})
		creditTx := models.CreditTransaction{
			Wallet:   wallet,
			Type:     "topup",
			Amount:   credits,
			TxHash:   txHashPtr,
			Action:   "topup",
			Metadata: string(breakdown),
		}
		if err := dbTx.Create(&creditTx).Error; err != nil {
			return fmt.Errorf("write credit transaction: %w", err)
		}
		entry := models.CreditLedgerEntry{
			UserWallet:    wallet,
			Delta:         credits,
			BalanceAfter:  u.Credits + credits,
			ActionType:    "topup",
			CostBreakdown: string(breakdown),
		}
		return dbTx.Create(&entry).Error
	})
}

// UpdateProfile updates username and bio.
//
// Validates length and uniqueness, applies a username reservation policy, and
// busts the agents/trending cache so any creator name renderings refresh on
// the next list/trending fetch (60-120s TTL otherwise leaves stale names).
func (s *AgentService) UpdateProfile(wallet string, input UpdateProfileInput) error {
	username := strings.TrimSpace(input.Username)
	if len(username) > 32 {
		return errors.New("username too long (max 32)")
	}
	if len(input.Bio) > 160 {
		return errors.New("bio too long (max 160)")
	}
	if username != "" {
		if err := validateUsername(username); err != nil {
			return err
		}
		// Uniqueness check — case-insensitive, exclude self.
		var existing models.User
		err := database.DB.
			Where("LOWER(username) = LOWER(?) AND wallet_address <> ?", username, wallet).
			First(&existing).Error
		if err == nil {
			return ErrUsernameTaken
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
	}

	if err := database.DB.Model(&models.User{}).
		Where("wallet_address = ?", wallet).
		Updates(map[string]any{
			"username": username,
			"bio":      input.Bio,
		}).Error; err != nil {
		return err
	}
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	return nil
}

// GetUserProfile returns public profile data for a wallet.
func (s *AgentService) GetUserProfile(wallet string) (*UserProfile, error) {
	var user models.User
	database.DB.Where("wallet_address = ?", wallet).First(&user)

	var agents []models.Agent
	if err := database.DB.Where("creator_wallet = ?", wallet).
		Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, image_url, price, prompt_score, card_version, created_at, updated_at").
		Order("created_at DESC").
		Find(&agents).Error; err != nil {
		return nil, err
	}

	var totalSaves int64
	for _, a := range agents {
		totalSaves += a.SaveCount
	}

	return &UserProfile{
		Wallet:        wallet,
		Username:      user.Username,
		Bio:           user.Bio,
		CreatedAgents: agents,
		TotalSaves:    totalSaves,
		TotalAgents:   int64(len(agents)),
	}, nil
}

// BatchGetAgents returns agents by IDs. Prompts are only visible to the agent creator.
func (s *AgentService) BatchGetAgents(ids []uint, requestingWallet string) ([]models.Agent, error) {
	if len(ids) == 0 {
		return []models.Agent{}, nil
	}
	if len(ids) > 50 {
		return nil, fmt.Errorf("maximum 50 IDs per batch request")
	}
	var agents []models.Agent
	if err := database.DB.Where("id IN ?", ids).Find(&agents).Error; err != nil {
		return nil, err
	}
	// Hide prompt for non-owned agents
	requestingWallet = strings.ToLower(requestingWallet)
	for i := range agents {
		if strings.ToLower(agents[i].CreatorWallet) != requestingWallet {
			agents[i].Prompt = ""
		}
	}
	return agents, nil
}

// DeductCreditsExternal is exposed for other services (Workspace) via internal API.
func (s *AgentService) DeductCreditsExternal(wallet string, amount int64, txType string, agentID *uint) error {
	return s.deductCredits(wallet, amount, txType, agentID)
}

// IncrementUseCount bumps the use_count for an agent. Exposed for internal API.
// Anti-abuse: callers may pass a wallet and/or ip_hash to invoke a 60-second
// cooldown window via recordUseAttempt; pass empty strings for unconditional
// internal increments (workflow execution, trusted server-to-server calls).
// Returns true if the count was actually applied, false if it was suppressed.
func (s *AgentService) IncrementUseCount(agentID uint, wallet, ipHash string) bool {
	if (wallet != "" || ipHash != "") && !recordUseAttempt(agentID, wallet, ipHash) {
		return false
	}
	database.DB.Model(&models.Agent{}).
		Where("id = ?", agentID).
		UpdateColumn("use_count", gorm.Expr("use_count + 1"))
	return true
}

// expectedToAddresses returns the set of valid destination addresses for on-chain payments.
func (s *AgentService) expectedToAddresses() []string {
	var addrs []string
	if s.creditsContract != "" {
		addrs = append(addrs, s.creditsContract)
	}
	if s.treasuryWallet != "" {
		addrs = append(addrs, s.treasuryWallet)
	}
	return addrs
}

// verifyMonadTransaction verifies a transaction on Monad testnet.
// It checks that the tx succeeded, was sent by expectedFrom, was sent to one of
// the allowedTo addresses (if any are configured), and that the value covers expectedAmountMon.
func verifyMonadTransaction(txHash, expectedFrom string, allowedTo []string, expectedAmountMon float64) error {
	rpcURL := "https://testnet-rpc.monad.xyz"
	payload := map[string]any{
		"jsonrpc": "2.0",
		"method":  "eth_getTransactionByHash",
		"params":  []string{txHash},
		"id":      1,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal rpc request: %w", err)
	}

	httpClient := &http.Client{Timeout: 15 * time.Second}

	// Fetch full transaction to get To and Value fields.
	resp, err := httpClient.Post(rpcURL, "application/json", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("monad rpc request failed: %w", err)
	}
	defer resp.Body.Close()

	var txResp struct {
		Result *struct {
			From  string `json:"from"`
			To    string `json:"to"`
			Value string `json:"value"`
		} `json:"result"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&txResp); err != nil {
		return fmt.Errorf("decode rpc response: %w", err)
	}
	if txResp.Error != nil {
		return fmt.Errorf("rpc error: %s", txResp.Error.Message)
	}
	if txResp.Result == nil {
		return fmt.Errorf("transaction not found on chain: %s", txHash)
	}

	// Verify sender
	if !strings.EqualFold(txResp.Result.From, expectedFrom) {
		return fmt.Errorf("transaction sender mismatch: expected %s, got %s", expectedFrom, txResp.Result.From)
	}

	// Verify recipient — must be one of the configured contract/treasury addresses
	if len(allowedTo) > 0 {
		toMatch := false
		for _, addr := range allowedTo {
			if strings.EqualFold(txResp.Result.To, addr) {
				toMatch = true
				break
			}
		}
		if !toMatch {
			return fmt.Errorf("transaction recipient %s is not a recognized platform address", txResp.Result.To)
		}
	}

	// Verify value — parse hex wei and compare against expected MON (1 MON = 1e18 wei)
	if expectedAmountMon > 0 && txResp.Result.Value != "" {
		valueHex := strings.TrimPrefix(txResp.Result.Value, "0x")
		// Parse hex value as uint64 — sufficient for reasonable MON amounts
		valueWei, parseErr := strconv.ParseUint(valueHex, 16, 64)
		if parseErr == nil {
			// Convert expected MON to wei (1 MON = 1e18 wei)
			expectedWei := uint64(expectedAmountMon * 1e18)
			// Allow 1% tolerance for gas/rounding
			minWei := expectedWei - expectedWei/100
			if valueWei < minWei {
				return fmt.Errorf("transaction value too low: expected ~%.4f MON, got %d wei", expectedAmountMon, valueWei)
			}
		}
	}

	// Now verify the receipt to confirm the transaction succeeded
	receiptPayload := map[string]any{
		"jsonrpc": "2.0",
		"method":  "eth_getTransactionReceipt",
		"params":  []string{txHash},
		"id":      2,
	}
	receiptBody, err := json.Marshal(receiptPayload)
	if err != nil {
		return fmt.Errorf("marshal receipt request: %w", err)
	}
	receiptResp, err := httpClient.Post(rpcURL, "application/json", bytes.NewReader(receiptBody))
	if err != nil {
		return fmt.Errorf("monad receipt rpc request failed: %w", err)
	}
	defer receiptResp.Body.Close()

	var rpcResp struct {
		Result *struct {
			Status string `json:"status"`
		} `json:"result"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(receiptResp.Body).Decode(&rpcResp); err != nil {
		return fmt.Errorf("decode receipt response: %w", err)
	}
	if rpcResp.Error != nil {
		return fmt.Errorf("receipt rpc error: %s", rpcResp.Error.Message)
	}
	if rpcResp.Result == nil {
		return fmt.Errorf("transaction receipt not found: %s (may be pending)", txHash)
	}
	if rpcResp.Result.Status != "0x1" {
		return fmt.Errorf("transaction failed on chain (status: %s)", rpcResp.Result.Status)
	}

	return nil
}
