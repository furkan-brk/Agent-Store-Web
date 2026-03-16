package services

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/draw"
	_ "image/jpeg" // decode support
	"image/png"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
	"github.com/google/uuid"
	"github.com/lib/pq"
	"gorm.io/gorm"
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

type AgentService struct {
	aiSvc           *AIService
	geminiSvc       *GeminiService
	replicateSvc    *ReplicateService
	scoreSvc        *ScoreService
	pollinationsSvc *PollinationsService
	cache           *CacheStore
	rembgURL        string
}

func NewAgentService(aiSvc *AIService, geminiSvc *GeminiService, replicateSvc *ReplicateService, scoreSvc *ScoreService, pollinationsSvc *PollinationsService, cache *CacheStore, rembgURL string) *AgentService {
	return &AgentService{aiSvc: aiSvc, geminiSvc: geminiSvc, replicateSvc: replicateSvc, scoreSvc: scoreSvc, pollinationsSvc: pollinationsSvc, cache: cache, rembgURL: rembgURL}
}

type CreateAgentInput struct {
	Title         string `json:"title" binding:"required"`
	Description   string `json:"description"`
	Prompt        string `json:"prompt" binding:"required"`
	CreatorWallet string
}

func (s *AgentService) ListAgents(category, search, sort string, page, limit int) ([]models.Agent, int64, error) {
	type cachedResult struct {
		Agents []models.Agent `json:"agents"`
		Total  int64          `json:"total"`
	}
	cacheKey := fmt.Sprintf("agents|%s|%s|%s|%d|%d", category, search, sort, page, limit)
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
	if search != "" {
		query = query.Where("title ILIKE ? OR description ILIKE ?", "%"+search+"%", "%"+search+"%")
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
	err := query.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at").
		Offset(offset).Limit(limit).Order(orderClause).Find(&agents).Error
	if err == nil {
		if b, jerr := json.Marshal(cachedResult{Agents: agents, Total: total}); jerr == nil {
			s.cache.Set(cacheKey, b, 60*time.Second)
		}
	}
	return agents, total, err
}

func (s *AgentService) GetAgent(id uint) (*models.Agent, error) {
	var agent models.Agent
	err := database.DB.First(&agent, id).Error
	return &agent, err
}

// deductCredits atomically deducts amount credits from wallet and records a CreditTransaction.
// Uses row-level locking (SELECT ... FOR UPDATE) to prevent TOCTOU race conditions.
// Returns an error if the user does not have enough credits.
func (s *AgentService) deductCredits(wallet string, amount int64, txType string, agentID *uint) error {
	return database.DB.Transaction(func(dbTx *gorm.DB) error {
		var user models.User
		// Lock the row for update to prevent concurrent balance races
		if err := dbTx.Set("gorm:query_option", "FOR UPDATE").
			Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
			return fmt.Errorf("user not found: %w", err)
		}
		if user.Credits < amount {
			return fmt.Errorf("insufficient credits: have %d, need %d", user.Credits, amount)
		}
		if err := dbTx.Model(&models.User{}).Where("wallet_address = ?", wallet).
			UpdateColumn("credits", gorm.Expr("credits - ?", amount)).Error; err != nil {
			return fmt.Errorf("failed to deduct credits: %w", err)
		}
		// Record transaction
		creditTx := models.CreditTransaction{
			Wallet:  wallet,
			Type:    txType,
			Amount:  -amount,
			AgentID: agentID,
		}
		return dbTx.Create(&creditTx).Error
	})
}

func (s *AgentService) CreateAgent(input CreateAgentInput) (*models.Agent, error) {
	// ── Overlapped Phase: Run AI analysis + image generation concurrently ─
	agentConcept := input.Title
	if input.Description != "" {
		agentConcept += ": " + input.Description
	}

	var (
		analysis    *PromptAnalysis
		analysisErr error
		profile     *AgentProfile
		profileErr  error
		scoreResult *PromptScoreResult
	)

	// profileCh delivers the real profile as soon as it's ready, allowing
	// image generation to start with a fallback and upgrade if the real
	// profile arrives first.
	profileCh := make(chan *AgentProfile, 1)

	// Determine a preliminary charType from keywords so image gen can start
	// immediately with a fallback profile, without waiting for LLM analysis.
	prelimCharType := DetermineCharacterType(input.Prompt)
	fallbackProfile := buildFallbackProfile(agentConcept, prelimCharType)

	var wg sync.WaitGroup
	wg.Add(4)

	// goroutine 1: Analyze prompt (category, tags, character type, rarity)
	go func() {
		defer wg.Done()
		analysis, analysisErr = s.geminiSvc.AnalyzePrompt(input.Prompt)
	}()

	// goroutine 2: Generate rich visual profile via world-builder LLM call
	go func() {
		defer wg.Done()
		profile, profileErr = s.geminiSvc.GenerateAgentProfile(agentConcept)
		if profileErr == nil && profile != nil {
			profileCh <- profile
		}
		close(profileCh)
	}()

	// goroutine 3: Score prompt and generate service description
	go func() {
		defer wg.Done()
		scoreResult = s.scoreSvc.ScoreAndDescribe(input.Prompt)
	}()

	// goroutine 4: Start image generation immediately (overlaps with LLM calls).
	// Uses fallback profile right away but upgrades to the real profile if it
	// arrives within 2 seconds.
	var generatedImage string
	go func() {
		defer wg.Done()

		// Wait briefly for the real profile; if it arrives quickly, use it.
		imageProfile := fallbackProfile
		select {
		case realProfile := <-profileCh:
			if realProfile != nil {
				imageProfile = realProfile
				log.Printf("[Avatar] using real LLM profile for image generation")
			}
		case <-time.After(2 * time.Second):
			log.Printf("[Avatar] real profile not ready in 2s, starting with fallback")
		}

		sanitized := sanitizeProfile(*imageProfile)
		imagePrompt := "A " + prelimCharType + " character with unique abilities and tools"
		generatedImage = s.generateImageWithFallback(&sanitized, imagePrompt, prelimCharType)

		// Remove background via ML service (chroma key fallback)
		if generatedImage != "" {
			generatedImage = s.removeBackground(generatedImage)
		}
	}()

	wg.Wait()

	// ── Handle analysis result (with keyword fallback) ──────────────────
	if analysisErr != nil {
		log.Printf("[Gemini] analysis failed, falling back to keywords: %v", analysisErr)
		charType := DetermineCharacterType(input.Prompt)
		subclass := DetermineSubclass(charType, input.Prompt)
		rarity := DetermineRarity(input.Prompt)
		analysis = &PromptAnalysis{
			CharacterType: charType,
			Subclass:      subclass,
			Category:      charTypeToCategory(charType),
			Tags:          extractKeywordTags(input.Prompt),
			Rarity:        string(rarity),
			ImagePrompt:   "A " + charType + " character with unique abilities and tools",
		}
	}

	rarity := models.CharacterRarity(analysis.Rarity)

	// ── Handle profile result (with fallback) ───────────────────────────
	if profileErr != nil {
		log.Printf("[Gemini] profile generation failed, using fallback: %v", profileErr)
		profile = buildFallbackProfile(agentConcept, analysis.CharacterType)
	} else {
		log.Printf("[Gemini] agent profile generated: name=%q type=%s", profile.Name, analysis.CharacterType)
	}

	// ── Build stats / traits / colors, then merge visual profile ────────
	charData, err := BuildCharacterData(analysis.CharacterType, analysis.Subclass, rarity, input.Prompt)
	if err != nil {
		charData = "{}"
	}
	charData = MergeProfileIntoCharacterData(charData, profile)

	// ── Deduct 10 credits for agent creation ────────────────────────────
	if input.CreatorWallet != "" {
		if err := s.deductCredits(input.CreatorWallet, 10, "create", nil); err != nil {
			return nil, fmt.Errorf("credit check failed: %w", err)
		}
	}

	// ── Persist ─────────────────────────────────────────────────────────
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
		PromptScore:        scoreResult.TotalScore,
		ServiceDescription: scoreResult.ServiceDescription,
		CardVersion:        "2.0",
	}
	err = database.DB.Create(agent).Error
	if err == nil && input.CreatorWallet != "" {
		entry := models.LibraryEntry{UserWallet: input.CreatorWallet, AgentID: agent.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).Where("id = ?", agent.ID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	}
	// Invalidate agent list + trending caches so new agent appears immediately.
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	return agent, err
}

func (s *AgentService) GetLibrary(wallet string) ([]models.LibraryEntry, error) {
	var entries []models.LibraryEntry
	err := database.DB.Preload("Agent", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at, updated_at")
	}).Where("user_wallet = ?", wallet).Find(&entries).Error
	return entries, err
}

func (s *AgentService) AddToLibrary(wallet string, agentID uint) error {
	var existing models.LibraryEntry
	if database.DB.Where("user_wallet = ? AND agent_id = ?", wallet, agentID).First(&existing).Error == nil {
		return nil
	}
	entry := models.LibraryEntry{UserWallet: wallet, AgentID: agentID}
	if err := database.DB.Create(&entry).Error; err != nil {
		return err
	}
	database.DB.Model(&models.Agent{}).Where("id = ?", agentID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	return nil
}

func (s *AgentService) RemoveFromLibrary(wallet string, agentID uint) error {
	return database.DB.Where("user_wallet = ? AND agent_id = ?", wallet, agentID).Delete(&models.LibraryEntry{}).Error
}

func (s *AgentService) GetUserCredits(wallet string) (int64, error) {
	var user models.User
	err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return 0, nil
	}
	return user.Credits, err
}

// charTypeToCategory maps character type to the best matching category.
func charTypeToCategory(charType string) string {
	m := map[string]string{
		"wizard":     "backend",
		"strategist": "business",
		"oracle":     "data",
		"guardian":   "security",
		"artisan":    "frontend",
		"bard":       "creative",
		"scholar":    "research",
		"merchant":   "business",
	}
	if c, ok := m[charType]; ok {
		return c
	}
	return "general"
}

// extractKeywordTags returns up to 5 matching keyword tags from the prompt.
func extractKeywordTags(prompt string) []string {
	lower := strings.ToLower(prompt)
	tags := []string{}
	seen := map[string]bool{}
	for kw := range keywordMap {
		if len(tags) >= 5 {
			break
		}
		if !seen[kw] && strings.Contains(lower, kw) {
			seen[kw] = true
			tags = append(tags, kw)
		}
	}
	if len(tags) == 0 {
		return []string{"agent"}
	}
	return tags
}

// GetTrending returns the top 6 agents ranked by save_count*3 + use_count*2.
func (s *AgentService) GetTrending() ([]models.Agent, error) {
	const cacheKey = "trending"
	if data, ok := s.cache.Get(cacheKey); ok {
		var agents []models.Agent
		if err := json.Unmarshal(data, &agents); err == nil {
			return agents, nil
		}
	}
	var agents []models.Agent
	// Select only list-view fields, skip heavy prompt and character_data
	err := database.DB.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at").
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

// ForkAgent creates a new agent based on an existing one with a fresh GenerateAvatarImage avatar.
func (s *AgentService) ForkAgent(originalID uint, creatorWallet string) (*models.Agent, error) {
	var original models.Agent
	if err := database.DB.First(&original, originalID).Error; err != nil {
		return nil, fmt.Errorf("original agent not found: %w", err)
	}

	// Generate a fresh avatar for the fork via fallback chain
	forkProfile := buildFallbackProfile(original.Title, original.CharacterType)
	forkedImage := s.generateImageWithFallback(forkProfile, "A variant of "+original.CharacterType+" agent", original.CharacterType)

	// Remove background via ML service (chroma key fallback)
	if forkedImage != "" {
		forkedImage = s.removeBackground(forkedImage)
	}

	// Deduct 5 credits for forking
	if creatorWallet != "" {
		if err := s.deductCredits(creatorWallet, 5, "fork", &original.ID); err != nil {
			return nil, fmt.Errorf("credit check failed: %w", err)
		}
	}

	fork := &models.Agent{
		Title:          original.Title + " (Fork)",
		Description:    "Forked from: " + original.Title,
		Prompt:         "", // Security: prompt stripped from forks to prevent IP extraction
		Category:       original.Category,
		CreatorWallet:  creatorWallet,
		CharacterType:  original.CharacterType,
		Subclass:       original.Subclass,
		CharacterData:  original.CharacterData,
		Rarity:         original.Rarity,
		Tags:           original.Tags,
		GeneratedImage: forkedImage,
		CardVersion:    "2.0",
	}

	if err := database.DB.Create(fork).Error; err != nil {
		return nil, err
	}
	// Invalidate caches
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")

	// Auto-add fork to creator's library
	if creatorWallet != "" {
		entry := models.LibraryEntry{UserWallet: creatorWallet, AgentID: fork.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).
			Where("id = ?", fork.ID).
			UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	}

	return fork, nil
}

// ChatWithAgent sends a user message to Gemini Flash using the agent's prompt as system context.
// It increments the agent's use_count on each call.
func (s *AgentService) ChatWithAgent(agentID uint, userMessage string) (string, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return "", fmt.Errorf("agent not found: %w", err)
	}

	reply, err := s.geminiSvc.Chat(agent.Prompt, userMessage)
	if err != nil {
		return "", err
	}

	// Increment use_count
	database.DB.Model(&models.Agent{}).
		Where("id = ?", agentID).
		UpdateColumn("use_count", gorm.Expr("use_count + 1"))

	return reply, nil
}

// TrialError represents a trial token generation error with an appropriate HTTP status hint.
type TrialError struct {
	Message string
	Status  int // HTTP status code hint: 403 = forbidden, 400 = bad request, 500 = internal
}

func (e *TrialError) Error() string { return e.Message }

// GenerateTrialToken creates a one-time trial token for the encrypted CLI trial system.
// The token allows the user to download a Node.js script that decrypts and runs the
// agent prompt locally using their own API key.
func (s *AgentService) GenerateTrialToken(agentID uint, wallet, provider, message string) (string, error) {
	// Verify agent exists
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return "", &TrialError{Message: "agent not found", Status: 404}
	}

	// Check if trial already used for this agent by this wallet
	var existing models.TrialUse
	if database.DB.Where("wallet = ? AND agent_id = ?", wallet, agentID).First(&existing).Error == nil {
		return "", &TrialError{Message: "trial already used for this agent — purchase to continue", Status: 403}
	}

	// Validate provider
	validProviders := map[string]bool{"claude": true, "openai": true, "gemini": true}
	if !validProviders[provider] {
		return "", &TrialError{Message: "invalid provider: must be claude, openai, or gemini", Status: 400}
	}

	// Generate token
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

// GetCreditHistory returns the last 50 credit transactions for a given wallet.
func (s *AgentService) GetCreditHistory(wallet string) ([]models.CreditTransaction, error) {
	var txs []models.CreditTransaction
	if err := database.DB.
		Where("wallet = ?", wallet).
		Order("created_at DESC").
		Limit(50).
		Find(&txs).Error; err != nil {
		return nil, err
	}
	// Populate AgentTitle from join
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

// LeaderboardEntry holds a single creator's ranking data.
type LeaderboardEntry struct {
	Wallet      string `json:"wallet"`
	TotalAgents int64  `json:"total_agents"`
	TotalSaves  int64  `json:"total_saves"`
	TotalUses   int64  `json:"total_uses"`
	Rank        int    `json:"rank"`
}

// GetLeaderboard returns top 10 creators ranked by total_saves desc.
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
func (s *AgentService) RecordPurchase(buyerWallet string, agentID uint, txHash string, amountMon float64) error {
	// Verify agent exists
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return fmt.Errorf("agent not found: %w", err)
	}
	// Avoid duplicate purchases
	var existing models.PurchasedAgent
	if database.DB.Where("buyer_wallet = ? AND agent_id = ?", buyerWallet, agentID).First(&existing).Error == nil {
		return nil // already purchased
	}

	// Security: verify transaction on-chain before recording purchase
	if err := verifyMonadTransaction(txHash, buyerWallet); err != nil {
		return fmt.Errorf("transaction verification failed: %w", err)
	}

	purchase := models.PurchasedAgent{
		BuyerWallet: buyerWallet,
		AgentID:     agentID,
		TxHash:      txHash,
		AmountMon:   amountMon,
	}
	return database.DB.Create(&purchase).Error
}

// IsPurchased returns true if the wallet has purchased the agent.
func (s *AgentService) IsPurchased(buyerWallet string, agentID uint) bool {
	var p models.PurchasedAgent
	return database.DB.Where("buyer_wallet = ? AND agent_id = ?", buyerWallet, agentID).First(&p).Error == nil
}

// generateImageWithFallback fires Imagen, Pollinations, and Replicate in parallel.
// The first provider to return a successful result wins; the rest are abandoned.
// A hard 60-second deadline caps total image generation time.
func (s *AgentService) generateImageWithFallback(profile *AgentProfile, imagePrompt, charType string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	type imageResult struct {
		image    string
		provider string
	}
	ch := make(chan imageResult, 3)

	// Fire all 3 providers in parallel
	go func() {
		if img, err := s.geminiSvc.GenerateAvatarImage(profile); err == nil && img != "" {
			ch <- imageResult{image: img, provider: "Imagen"}
		} else if err != nil {
			log.Printf("[Avatar] Imagen failed: %v", err)
		}
	}()

	go func() {
		if img, err := s.pollinationsSvc.GenerateImage(profile); err == nil && img != "" {
			ch <- imageResult{image: img, provider: "Pollinations"}
		} else if err != nil {
			log.Printf("[Avatar] Pollinations failed: %v", err)
		}
	}()

	go func() {
		if img, err := s.replicateSvc.GeneratePixelArt(imagePrompt, charType); err == nil && img != "" {
			ch <- imageResult{image: img, provider: "Replicate"}
		} else if err != nil {
			log.Printf("[Avatar] Replicate failed: %v", err)
		}
	}()

	// Take the first successful result or timeout
	select {
	case r := <-ch:
		log.Printf("[Avatar] %s won the race (type=%s)", r.provider, charType)
		return r.image
	case <-ctx.Done():
		log.Printf("[Avatar] all providers timed out or failed within 60s (type=%s)", charType)
		return "" // frontend shows skeleton placeholder
	}
}

// removeBackground sends the image to the rembg ML microservice for background removal.
// On any failure it falls back to chromaKey, and if that also fails it returns the original image unchanged.
func (s *AgentService) removeBackground(base64Image string) string {
	raw := base64Image
	if idx := strings.Index(raw, ","); idx != -1 {
		raw = raw[idx+1:]
	}

	imgBytes, err := base64.StdEncoding.DecodeString(raw)
	if err != nil {
		log.Printf("[BG-Remove] base64 decode failed, returning original: %v", err)
		return base64Image
	}

	// POST raw image bytes to rembg service
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Post(s.rembgURL+"/api/remove", "application/octet-stream", bytes.NewReader(imgBytes))
	if err != nil {
		log.Printf("[BG-Remove] ML failed, falling back to chroma key: %v", err)
		if transparent, ckErr := chromaKey(raw); ckErr != nil {
			log.Printf("[BG-Remove] chroma key also failed, returning original: %v", ckErr)
			return base64Image
		} else {
			return transparent
		}
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		log.Printf("[BG-Remove] ML returned status %d, falling back to chroma key", resp.StatusCode)
		if transparent, ckErr := chromaKey(raw); ckErr != nil {
			log.Printf("[BG-Remove] chroma key also failed, returning original: %v", ckErr)
			return base64Image
		} else {
			return transparent
		}
	}

	pngBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("[BG-Remove] failed to read ML response, falling back to chroma key: %v", err)
		if transparent, ckErr := chromaKey(raw); ckErr != nil {
			log.Printf("[BG-Remove] chroma key also failed, returning original: %v", ckErr)
			return base64Image
		} else {
			return transparent
		}
	}

	log.Printf("[BG-Remove] ML removal succeeded (%d bytes)", len(pngBytes))
	return base64.StdEncoding.EncodeToString(pngBytes)
}

// chromaKey removes the magenta-screen background (#FF00FF) using global color
// replacement with soft alpha edge refinement. Four-pass pipeline:
//  1. Hard classification: mark all magenta pixels transparent
//  2. Edge soft alpha: blend character edges smoothly with magenta despill
//  3. 1-pixel erosion: remove orphan fringe pixels
//  4. Encode as transparent PNG
//
// Unlike the previous flood-fill approach, this detects magenta globally — no
// spatial connectivity required. Interior magenta pockets (between arm and torso,
// inside held items) are correctly removed. No frame scanning needed.
func chromaKey(base64Image string) (string, error) {
	imgBytes, err := base64.StdEncoding.DecodeString(base64Image)
	if err != nil {
		return "", fmt.Errorf("base64 decode: %w", err)
	}

	img, _, err := image.Decode(bytes.NewReader(imgBytes))
	if err != nil {
		return "", fmt.Errorf("image decode: %w", err)
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()

	// Convert to NRGBA for direct pixel access via .Pix slice (much faster than img.At())
	result := image.NewNRGBA(bounds)
	draw.Draw(result, bounds, img, bounds.Min, draw.Src)

	mask := make([]bool, w*h)

	// ── Pass 1: Hard classification — mark all magenta pixels transparent ──
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			idx := y*result.Stride + x*4
			r8 := int(result.Pix[idx])
			g8 := int(result.Pix[idx+1])
			b8 := int(result.Pix[idx+2])

			if isMagenta(r8, g8, b8) {
				result.Pix[idx] = 0   // R
				result.Pix[idx+1] = 0 // G
				result.Pix[idx+2] = 0 // B
				result.Pix[idx+3] = 0 // A
				mask[y*w+x] = true
			}
		}
	}

	// ── Pass 2: Edge soft alpha + despill ──
	// Edge pixels are non-masked pixels with at least one masked neighbor (8-connectivity)
	dx := []int{-1, 0, 1, -1, 1, -1, 0, 1}
	dy := []int{-1, -1, -1, 0, 0, 1, 1, 1}

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if mask[y*w+x] {
				continue // already transparent
			}

			// Check if this pixel borders a transparent pixel
			isEdge := false
			for d := 0; d < 8; d++ {
				nx, ny := x+dx[d], y+dy[d]
				if nx >= 0 && nx < w && ny >= 0 && ny < h && mask[ny*w+nx] {
					isEdge = true
					break
				}
			}
			if !isEdge {
				continue
			}

			idx := y*result.Stride + x*4
			r8 := int(result.Pix[idx])
			g8 := int(result.Pix[idx+1])
			b8 := int(result.Pix[idx+2])

			contrib := magentaContribution(r8, g8, b8)
			alpha := 1.0 - contrib
			if alpha < 0.12 {
				// Almost fully magenta — force transparent
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
				mask[y*w+x] = true
				continue
			}

			// Despill magenta contamination from RGB
			dr, dg, db := despillMagenta(r8, g8, b8)
			result.Pix[idx] = uint8(dr)
			result.Pix[idx+1] = uint8(dg)
			result.Pix[idx+2] = uint8(db)
			result.Pix[idx+3] = uint8(alpha * 255)
		}
	}

	// ── Pass 3: 1-pixel erosion — remove orphan fringe pixels ──
	// Clone alpha channel to avoid read-write conflicts during erosion
	alphaSnap := make([]uint8, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			alphaSnap[y*w+x] = result.Pix[y*result.Stride+x*4+3]
		}
	}
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if alphaSnap[y*w+x] == 0 {
				continue
			}
			transparentCount := 0
			for d := 0; d < 8; d++ {
				nx, ny := x+dx[d], y+dy[d]
				if nx < 0 || nx >= w || ny < 0 || ny >= h {
					transparentCount++ // out-of-bounds counts as transparent
					continue
				}
				if alphaSnap[ny*w+nx] == 0 {
					transparentCount++
				}
			}
			if transparentCount >= 6 {
				idx := y*result.Stride + x*4
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
			}
		}
	}

	// ── Pass 4: Encode as transparent PNG ──
	var buf bytes.Buffer
	if err := png.Encode(&buf, result); err != nil {
		return "", fmt.Errorf("png encode: %w", err)
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes()), nil
}

// isMagenta checks if a color is in the magenta chroma-key family (#FF00FF).
// Uses a dual-gate approach: RGB dominance + R/B symmetry check, then HSV fallback.
// Critical: protects Artisan pink (#EC4899 = 236,72,153) via the symmetry gate.
func isMagenta(r8, g8, b8 int) bool {
	// Primary: R and B both high, both dominate G by 50+
	if r8 > 120 && b8 > 120 && r8 > g8+50 && b8 > g8+50 {
		// Symmetry check: true magenta has R ≈ B.
		// Artisan pink (236,72,153): |236-153|=83, max=236, 83/236=0.35 → FAILS
		// Pure magenta (255,0,255): |255-255|=0 → PASSES
		maxRB := r8
		if b8 > maxRB {
			maxRB = b8
		}
		diff := r8 - b8
		if diff < 0 {
			diff = -diff
		}
		if float64(diff) < float64(maxRB)*0.35 {
			return true
		}
	}

	// Secondary: HSV hue in [285, 320], saturation > 0.35
	// Pure magenta hue = 300. Artisan pink hue ≈ 330 → outside. Wizard purple ≈ 270 → outside.
	hue, sat, _ := rgbToHSV(uint8(r8), uint8(g8), uint8(b8))
	if hue >= 285 && hue <= 320 && sat > 0.35 {
		return true
	}

	return false
}

// magentaContribution estimates how much a pixel's color comes from the magenta
// background vs the foreground character, returning 0.0 (no magenta) to 1.0 (pure magenta).
// Used only for edge pixels to compute soft alpha blending.
func magentaContribution(r8, g8, b8 int) float64 {
	// Magenta = high R + high B, low G. Contribution based on (R+B)/2 excess over G.
	avgRB := float64(r8+b8) / 2.0
	gf := float64(g8)
	if avgRB <= gf {
		return 0.0
	}
	excess := (avgRB - gf) / 255.0
	contrib := excess * excess // quadratic for sharper transition
	if contrib < 0.02 {
		return 0.0
	}
	if contrib > 0.90 {
		return 1.0
	}
	return contrib
}

// despillMagenta removes magenta contamination from edge pixel RGB channels.
// Clamps R and B so neither exceeds the luminance-preserving limit based on G.
func despillMagenta(r8, g8, b8 int) (int, int, int) {
	avg := (r8 + g8 + b8) / 3
	limit := g8
	if avg > limit {
		limit = avg
	}
	if r8 > limit {
		r8 = limit
	}
	if b8 > limit {
		b8 = limit
	}
	return r8, g8, b8
}

// rgbToHSV converts 8-bit RGB values to HSV. Hue is returned in degrees (0-360),
// saturation and value are in the range 0.0-1.0. Pure Go stdlib, no external deps.
func rgbToHSV(r, g, b uint8) (h float64, s float64, v float64) {
	rf := float64(r) / 255.0
	gf := float64(g) / 255.0
	bf := float64(b) / 255.0

	max := rf
	if gf > max {
		max = gf
	}
	if bf > max {
		max = bf
	}
	min := rf
	if gf < min {
		min = gf
	}
	if bf < min {
		min = bf
	}

	v = max
	delta := max - min

	if max == 0 {
		// Black
		return 0, 0, 0
	}
	s = delta / max

	if delta == 0 {
		// Grey — hue is undefined, return 0
		return 0, 0, v
	}

	switch max {
	case rf:
		h = 60.0 * (gf - bf) / delta
	case gf:
		h = 60.0*(bf-rf)/delta + 120.0
	case bf:
		h = 60.0*(rf-gf)/delta + 240.0
	}
	if h < 0 {
		h += 360.0
	}
	return h, s, v
}

// buildFallbackProfile creates a sensible AgentProfile when the LLM call fails,
// using the character type to determine default medieval fantasy visual details.
func buildFallbackProfile(concept, charType string) *AgentProfile {
	type defaults struct {
		primary, secondary, glow string
		headwear, outfit         string
		uniqueFeature, heldItem  string
		mood                     string
	}
	d := map[string]defaults{
		"wizard": {
			"Deep Purple", "Midnight Blue", "Violet",
			"a tall pointed hat with silver star embroidery",
			"layered indigo robes with silver thread runes along the hem",
			"faint arcane symbols orbiting slowly around the shoulders",
			"a gnarled oak staff crowned with a pulsing amethyst crystal",
			"Mysterious and contemplative",
		},
		"strategist": {
			"Deep Crimson", "Burnished Gold", "Red",
			"a steel crowned helm with a crimson plume",
			"battle-worn plate armor beneath a crimson commander's surcoat with a golden lion crest",
			"a tattered war banner fluttering behind in an unseen wind",
			"a broadsword with a lion-head pommel, point resting on the ground",
			"Fierce and resolute",
		},
		"oracle": {
			"Amber", "Deep Teal", "Golden",
			"a silk headwrap with a third-eye gemstone set in the center of the forehead",
			"flowing saffron and teal robes with celestial patterns woven into the fabric",
			"floating constellation charts and star maps orbiting overhead",
			"a brass astrolabe in one hand and a rolled star chart in the other",
			"Serene and all-knowing",
		},
		"guardian": {
			"Steel Blue", "Iron Grey", "Ice Blue",
			"a full steel helm with a raised visor revealing vigilant eyes",
			"heavy plate armor with chainmail underneath and a blue heraldic tabard",
			"a loyal stone gargoyle perched on one massive shoulder pauldron",
			"a tall tower shield bearing a fortress emblem and a flanged mace",
			"Steadfast and unyielding",
		},
		"artisan": {
			"Warm Sienna", "Teal", "Warm Copper",
			"a soft beret tilted to one side, flecked with dried paint",
			"a fine linen tunic beneath a well-worn leather apron stained with pigments",
			"tiny enchanted paint droplets floating and swirling around the hands",
			"a set of ornate woodcarving chisels and a half-finished miniature sculpture",
			"Inspired and passionate",
		},
		"bard": {
			"Emerald Green", "Cream", "Golden Yellow",
			"a wide-brimmed feathered hat with a jaunty emerald plume",
			"a velvet doublet over a billowing white shirt with an embroidered green travelling cloak",
			"shimmering musical notes drifting visibly through the air",
			"an ornate lute with mother-of-pearl inlay across the neck",
			"Cheerful and silver-tongued",
		},
		"scholar": {
			"Warm Brown", "Parchment Beige", "Amber",
			"round brass spectacles perched on a lined and thoughtful face",
			"a brown monastic robe with ink-stained sleeves and a rope belt hung with scroll cases",
			"a small enchanted candle flame hovering above one shoulder casting warm light",
			"an ancient leather-bound tome open to illuminated pages with glowing marginalia",
			"Calm and deeply curious",
		},
		"merchant": {
			"Rich Gold", "Navy Blue", "Orange",
			"a fine velvet cap with a jeweled brooch and a peacock feather",
			"a gold-trimmed brocade doublet with a heavy coin purse on the belt",
			"a trained raven perched on the shoulder clutching a tiny sealed letter",
			"a set of brass weighing scales balanced in one hand, the other gesturing persuasively",
			"Shrewd and charismatic",
		},
	}
	def, ok := d[charType]
	if !ok {
		def = d["wizard"]
	}
	return &AgentProfile{
		Name:            concept,
		Mood:            def.mood,
		RolePurpose:     "A medieval keeper of knowledge and craft, serving those who seek expert guidance in their domain.",
		PrimaryColor:    def.primary,
		SecondaryColor:  def.secondary,
		TabletGlowColor: def.glow,
		Characteristics: []string{
			def.headwear,
			def.outfit,
			def.uniqueFeature,
			def.heldItem,
		},
	}
}

// UpdateAgent allows a creator to update title, description, and tags of their own agent.
// Only non-nil fields are updated (partial update). The prompt cannot be changed.
func (s *AgentService) UpdateAgent(agentID uint, wallet string, title, description *string, tags []string) (*models.Agent, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return nil, fmt.Errorf("agent not found")
	}
	if agent.CreatorWallet != wallet {
		return nil, fmt.Errorf("unauthorized: you can only edit your own agents")
	}

	updates := map[string]interface{}{}
	if title != nil && *title != "" {
		updates["title"] = *title
	}
	if description != nil && *description != "" {
		updates["description"] = *description
	}
	if tags != nil {
		updates["tags"] = pq.StringArray(tags)
	}

	if len(updates) == 0 {
		return &agent, nil
	}

	if err := database.DB.Model(&agent).Updates(updates).Error; err != nil {
		return nil, fmt.Errorf("update failed: %w", err)
	}
	database.DB.First(&agent, agentID) // reload with updated fields

	// Invalidate caches so list views reflect the changes
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")

	return &agent, nil
}

// RegenerateImage regenerates the avatar image for a creator's own agent.
// Enforces a 24-hour cooldown between regenerations.
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

	// Generate new profile from agent concept
	concept := agent.Title
	if agent.Description != "" {
		concept += ": " + agent.Description
	}
	profile, err := s.geminiSvc.GenerateAgentProfile(concept)
	if err != nil {
		log.Printf("[RegenerateImage] profile generation failed, using fallback: %v", err)
		profile = buildFallbackProfile(concept, agent.CharacterType)
	}

	// Generate new image using the same fallback chain as CreateAgent
	sanitized := sanitizeProfile(*profile)
	imagePrompt := "A " + agent.CharacterType + " character with unique abilities and tools"
	generatedImage := s.generateImageWithFallback(&sanitized, imagePrompt, agent.CharacterType)

	// Remove background via ML service (chroma key fallback)
	if generatedImage != "" {
		generatedImage = s.removeBackground(generatedImage)
	}

	// Merge new profile into existing character_data
	charData := MergeProfileIntoCharacterData(agent.CharacterData, profile)

	// Update agent record
	now := time.Now()
	updateErr := database.DB.Model(&agent).Updates(map[string]interface{}{
		"generated_image":  generatedImage,
		"character_data":   charData,
		"last_image_regen": now,
	}).Error
	if updateErr != nil {
		return nil, fmt.Errorf("failed to save regenerated image: %w", updateErr)
	}

	// Reload to return the full updated agent
	database.DB.First(&agent, agentID)

	// Invalidate caches
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")

	return &agent, nil
}

// SetAgentPrice allows a creator to set the price of their agent (in MON).
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
		// Update existing
		return database.DB.Model(&existing).Updates(map[string]interface{}{
			"rating":  rating,
			"comment": comment,
		}).Error
	}
	r := models.AgentRating{AgentID: agentID, Wallet: wallet, Rating: rating, Comment: comment}
	return database.DB.Create(&r).Error
}

// GetRatings returns ratings for an agent with average and count.
func (s *AgentService) GetRatings(agentID uint) ([]models.AgentRating, float64, int64, error) {
	var ratings []models.AgentRating
	err := database.DB.Where("agent_id = ?", agentID).Order("created_at DESC").Limit(20).Find(&ratings).Error
	if err != nil {
		return nil, 0, 0, err
	}
	var avg float64
	var count int64
	database.DB.Model(&models.AgentRating{}).Where("agent_id = ?", agentID).Count(&count)
	if count > 0 {
		database.DB.Model(&models.AgentRating{}).
			Where("agent_id = ?", agentID).
			Select("AVG(rating)").Row().Scan(&avg)
	}
	return ratings, avg, count, nil
}

// GetUserRating returns the authenticated user's rating for an agent (0 if none).
func (s *AgentService) GetUserRating(agentID uint, wallet string) int {
	var r models.AgentRating
	if database.DB.Where("agent_id = ? AND wallet = ?", agentID, wallet).First(&r).Error != nil {
		return 0
	}
	return r.Rating
}

// verifyMonadTransaction verifies that a transaction exists on-chain via the Monad
// testnet RPC and that it was sent by the expected wallet address.
func verifyMonadTransaction(txHash, expectedFrom string) error {
	rpcURL := "https://testnet-rpc.monad.xyz"
	payload := map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  "eth_getTransactionReceipt",
		"params":  []string{txHash},
		"id":      1,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal rpc request: %w", err)
	}

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Post(rpcURL, "application/json", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("monad rpc request failed: %w", err)
	}
	defer resp.Body.Close()

	var rpcResp struct {
		Result *struct {
			Status string `json:"status"`
			From   string `json:"from"`
		} `json:"result"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&rpcResp); err != nil {
		return fmt.Errorf("decode rpc response: %w", err)
	}
	if rpcResp.Error != nil {
		return fmt.Errorf("rpc error: %s", rpcResp.Error.Message)
	}
	if rpcResp.Result == nil {
		return fmt.Errorf("transaction not found on chain: %s", txHash)
	}
	if rpcResp.Result.Status != "0x1" {
		return fmt.Errorf("transaction failed on chain (status: %s)", rpcResp.Result.Status)
	}
	if !strings.EqualFold(rpcResp.Result.From, expectedFrom) {
		return fmt.Errorf("transaction sender mismatch: expected %s, got %s", expectedFrom, rpcResp.Result.From)
	}
	return nil
}

// TopUpCredits grants credits to a wallet after verifying MON payment on-chain.
// rate: 100 credits per 1 MON
func (s *AgentService) TopUpCredits(wallet, txHash string, amountMon float64) error {
	credits := int64(amountMon * 100)
	if credits < 10 {
		return fmt.Errorf("minimum top-up is 0.1 MON (10 credits)")
	}

	// Security: verify transaction on-chain before granting credits
	if err := verifyMonadTransaction(txHash, wallet); err != nil {
		return fmt.Errorf("transaction verification failed: %w", err)
	}

	// Ensure user exists; if not, create with the new credits
	var user models.User
	if database.DB.Where("wallet_address = ?", wallet).First(&user).Error != nil {
		database.DB.Create(&models.User{WalletAddress: wallet, Credits: credits})
	} else {
		// Add credits to existing user
		database.DB.Model(&models.User{}).
			Where("wallet_address = ?", wallet).
			UpdateColumn("credits", gorm.Expr("credits + ?", credits))
	}
	// Record transaction with TxHash to prevent double-spend (unique index on tx_hash)
	txHashPtr := &txHash
	tx := models.CreditTransaction{
		Wallet: wallet,
		Type:   "topup",
		Amount: credits,
		TxHash: txHashPtr,
	}
	database.DB.Create(&tx)
	return nil
}

// UpdateProfileInput holds the fields a user can update on their profile.
type UpdateProfileInput struct {
	Username string `json:"username"`
	Bio      string `json:"bio"`
}

// UpdateProfile updates the username and bio for the given wallet address.
func (s *AgentService) UpdateProfile(wallet string, input UpdateProfileInput) error {
	if len(input.Username) > 32 {
		return errors.New("username too long (max 32)")
	}
	if len(input.Bio) > 160 {
		return errors.New("bio too long (max 160)")
	}
	return database.DB.Model(&models.User{}).
		Where("wallet_address = ?", wallet).
		Updates(map[string]interface{}{
			"username": input.Username,
			"bio":      input.Bio,
		}).Error
}

// GetUserProfile returns public profile data for a given wallet address.
func (s *AgentService) GetUserProfile(wallet string) (*UserProfile, error) {
	var user models.User
	database.DB.Where("wallet_address = ?", wallet).First(&user)

	var agents []models.Agent
	if err := database.DB.Where("creator_wallet = ?", wallet).
		Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at, updated_at").
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
