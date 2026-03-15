package services

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg" // decode support
	"image/png"
	"log"
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
}

func NewAgentService(aiSvc *AIService, geminiSvc *GeminiService, replicateSvc *ReplicateService, scoreSvc *ScoreService, pollinationsSvc *PollinationsService, cache *CacheStore) *AgentService {
	return &AgentService{aiSvc: aiSvc, geminiSvc: geminiSvc, replicateSvc: replicateSvc, scoreSvc: scoreSvc, pollinationsSvc: pollinationsSvc, cache: cache}
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
// Returns an error if the user does not have enough credits.
func (s *AgentService) deductCredits(wallet string, amount int64, txType string, agentID *uint) error {
	var user models.User
	if err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
		return fmt.Errorf("user not found: %w", err)
	}
	if user.Credits < amount {
		return fmt.Errorf("insufficient credits: have %d, need %d", user.Credits, amount)
	}
	database.DB.Model(&models.User{}).
		Where("wallet_address = ?", wallet).
		UpdateColumn("credits", gorm.Expr("credits - ?", amount))
	tx := models.CreditTransaction{
		Wallet:  wallet,
		Type:    txType,
		Amount:  -amount,
		AgentID: agentID,
	}
	database.DB.Create(&tx)
	return nil
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

		// Apply chroma key to remove green screen background
		if generatedImage != "" {
			raw := generatedImage
			if idx := strings.Index(raw, ","); idx != -1 {
				raw = raw[idx+1:]
			}
			if transparent, err := chromaKey(raw); err != nil {
				log.Printf("[ChromaKey] failed, keeping original: %v", err)
			} else {
				generatedImage = transparent
				log.Printf("[ChromaKey] background removed successfully")
			}
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
	err := database.DB.Preload("Agent").Where("user_wallet = ?", wallet).Find(&entries).Error
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

	// Apply chroma key to remove green screen background
	if forkedImage != "" {
		raw := forkedImage
		if idx := strings.Index(raw, ","); idx != -1 {
			raw = raw[idx+1:]
		}
		if transparent, err := chromaKey(raw); err != nil {
			log.Printf("[ChromaKey] fork failed, keeping original: %v", err)
		} else {
			forkedImage = transparent
			log.Printf("[ChromaKey] fork background removed successfully")
		}
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
		Prompt:         original.Prompt,
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

// chromaKey removes the green-screen background using flood-fill from edges.
// Unlike per-pixel color matching, this approach only removes green pixels that
// are spatially connected to the image border. Interior green pixels (e.g., a
// green gemstone on a wizard's staff) are preserved because the flood fill
// cannot reach them through non-green character pixels.
//
// Frame handling: AI generators sometimes add decorative frames/borders around
// the image. To handle this, we scan inward from each edge (up to maxScanDepth
// pixels). Non-green "frame" pixels are marked transparent, and the first green
// pixel found seeds the flood fill. This effectively punches through any frame
// to reach the green background behind it.
func chromaKey(base64Image string) (string, error) {
	imgBytes, err := base64.StdEncoding.DecodeString(base64Image)
	if err != nil {
		return "", fmt.Errorf("decode base64: %w", err)
	}

	img, _, err := image.Decode(bytes.NewReader(imgBytes))
	if err != nil {
		return "", fmt.Errorf("decode image: %w", err)
	}

	bounds := img.Bounds()
	w := bounds.Max.X - bounds.Min.X
	h := bounds.Max.Y - bounds.Min.Y
	result := image.NewNRGBA(bounds)

	// Copy all pixels initially as opaque
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			result.SetNRGBA(x, y, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), uint8(a >> 8)})
		}
	}

	visited := make([]bool, w*h)
	idx := func(x, y int) int { return (y-bounds.Min.Y)*w + (x - bounds.Min.X) }

	// framePixels tracks non-green pixels found while scanning through frames.
	// These get marked transparent after the flood fill completes.
	type point struct{ x, y int }
	var framePixels []point
	queue := make([]point, 0, 2*(w+h))

	// Maximum depth to scan inward looking for green through a frame.
	// ~6% of image dimension handles thick ornamental borders.
	maxScanDepth := w / 16
	if dh := h / 16; dh > maxScanDepth {
		maxScanDepth = dh
	}
	if maxScanDepth < 40 {
		maxScanDepth = 40
	}
	if maxScanDepth > 80 {
		maxScanDepth = 80
	}

	// scanAndSeed scans inward from an edge pixel along (dx, dy) direction.
	// If the edge pixel is green → seed directly. If not (frame), scan inward
	// marking frame pixels, and seed from the first green pixel found.
	scanAndSeed := func(startX, startY, stepX, stepY int) {
		if isGreenish(img.At(startX, startY)) {
			// No frame — seed directly
			i := idx(startX, startY)
			if !visited[i] {
				visited[i] = true
				queue = append(queue, point{startX, startY})
			}
			return
		}
		// Frame detected — scan inward to find green
		for depth := 1; depth <= maxScanDepth; depth++ {
			sx := startX + stepX*depth
			sy := startY + stepY*depth
			if sx < bounds.Min.X || sx >= bounds.Max.X || sy < bounds.Min.Y || sy >= bounds.Max.Y {
				break
			}
			if isGreenish(img.At(sx, sy)) {
				// Found green behind the frame — seed flood fill here
				i := idx(sx, sy)
				if !visited[i] {
					visited[i] = true
					queue = append(queue, point{sx, sy})
				}
				// Mark all pixels from edge to here as frame (to be removed)
				for d := 0; d < depth; d++ {
					fx := startX + stepX*d
					fy := startY + stepY*d
					framePixels = append(framePixels, point{fx, fy})
				}
				return
			}
		}
		// No green found within scan depth — likely character extends to edge.
		// Don't remove anything on this scan line.
	}

	// Scan from all 4 borders
	for x := bounds.Min.X; x < bounds.Max.X; x++ {
		scanAndSeed(x, bounds.Min.Y, 0, 1)    // Top edge, scan downward
		scanAndSeed(x, bounds.Max.Y-1, 0, -1)  // Bottom edge, scan upward
	}
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		scanAndSeed(bounds.Min.X, y, 1, 0)    // Left edge, scan rightward
		scanAndSeed(bounds.Max.X-1, y, -1, 0)  // Right edge, scan leftward
	}

	// BFS flood fill — expand to neighboring green pixels
	ddx := []int{-1, 1, 0, 0}
	ddy := []int{0, 0, -1, 1}

	for len(queue) > 0 {
		p := queue[0]
		queue = queue[1:]

		// Mark this pixel as transparent
		result.SetNRGBA(p.x, p.y, color.NRGBA{0, 0, 0, 0})

		for d := 0; d < 4; d++ {
			nx, ny := p.x+ddx[d], p.y+ddy[d]
			if nx < bounds.Min.X || nx >= bounds.Max.X || ny < bounds.Min.Y || ny >= bounds.Max.Y {
				continue
			}
			ni := idx(nx, ny)
			if visited[ni] {
				continue
			}
			if isGreenish(img.At(nx, ny)) {
				visited[ni] = true
				queue = append(queue, point{nx, ny})
			}
		}
	}

	// Mark frame pixels as transparent (these were between the border and the green)
	for _, fp := range framePixels {
		result.SetNRGBA(fp.x, fp.y, color.NRGBA{0, 0, 0, 0})
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, result); err != nil {
		return "", fmt.Errorf("encode png: %w", err)
	}

	return base64.StdEncoding.EncodeToString(buf.Bytes()), nil
}

// isGreenish checks if a color is clearly in the green-screen family.
// Used by the flood fill to decide whether to expand into a neighboring pixel.
// Thresholds are strict so the flood fill stops at the character boundary even
// when the AI doesn't render a dark ink outline — transition pixels between
// green background and character colors won't pass these checks, acting as a
// natural barrier. The solid green background still gets fully removed because
// all its pixels are well above these thresholds.
func isGreenish(c color.Color) bool {
	r, g, b, _ := c.RGBA()
	r8, g8, b8 := int(r>>8), int(g>>8), int(b>>8)

	// Primary check: green channel must clearly dominate both red and blue.
	// Strict margins (+50) prevent leaking through semi-green transition pixels.
	if g8 > 120 && g8 > r8+50 && g8 > b8+50 {
		return true
	}

	// Secondary: HSV hue in narrow green range with strong saturation
	h, s, _ := rgbToHSV(uint8(r8), uint8(g8), uint8(b8))
	if h >= 90 && h <= 150 && s > 0.35 {
		return true
	}

	return false
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
			"Emerald Green", "Cream", "Lime Green",
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

	// Apply chroma key to remove green screen background
	if generatedImage != "" {
		raw := generatedImage
		if idx := strings.Index(raw, ","); idx != -1 {
			raw = raw[idx+1:]
		}
		if transparent, chromaErr := chromaKey(raw); chromaErr != nil {
			log.Printf("[ChromaKey] regen failed, keeping original: %v", chromaErr)
		} else {
			generatedImage = transparent
			log.Printf("[ChromaKey] regen background removed successfully")
		}
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

// TopUpCredits grants credits to a wallet after verifying MON payment.
// rate: 100 credits per 1 MON
func (s *AgentService) TopUpCredits(wallet, txHash string, amountMon float64) error {
	credits := int64(amountMon * 100)
	if credits < 10 {
		return fmt.Errorf("minimum top-up is 0.1 MON (10 credits)")
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
	// Record transaction
	tx := models.CreditTransaction{
		Wallet: wallet,
		Type:   "topup",
		Amount: credits,
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
