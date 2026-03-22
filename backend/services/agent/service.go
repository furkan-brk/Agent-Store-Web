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
	if search != "" {
		query = query.Where("title ILIKE ? OR description ILIKE ?", "%"+search+"%", "%"+search+"%")
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
	err := query.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, image_url, generated_image, price, prompt_score, card_version, created_at").
		Offset(offset).Limit(limit).Order(orderClause).Find(&agents).Error
	if err == nil {
		if b, jerr := json.Marshal(cachedResult{Agents: agents, Total: total}); jerr == nil {
			s.cache.Set(cacheKey, b, 60*time.Second)
		}
	}
	return agents, total, err
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

// deductCredits atomically deducts amount credits from wallet and records a CreditTransaction.
func (s *AgentService) deductCredits(wallet string, amount int64, txType string, agentID *uint) error {
	return database.DB.Transaction(func(dbTx *gorm.DB) error {
		var user models.User
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
		creditTx := models.CreditTransaction{
			Wallet:  wallet,
			Type:    txType,
			Amount:  -amount,
			AgentID: agentID,
		}
		return dbTx.Create(&creditTx).Error
	})
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
		entry := models.LibraryEntry{UserWallet: input.CreatorWallet, AgentID: agent.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).Where("id = ?", agent.ID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	}
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	s.cache.Delete("categories")
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
func (s *AgentService) GetLibrary(wallet string) ([]models.LibraryEntry, error) {
	var entries []models.LibraryEntry
	err := database.DB.Preload("Agent", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, image_url, price, prompt_score, card_version, created_at, updated_at")
	}).Where("user_wallet = ?", wallet).Find(&entries).Error
	return entries, err
}

// AddToLibrary adds an agent to a user's library.
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

// RemoveFromLibrary removes an agent from a user's library.
func (s *AgentService) RemoveFromLibrary(wallet string, agentID uint) error {
	return database.DB.Where("user_wallet = ? AND agent_id = ?", wallet, agentID).Delete(&models.LibraryEntry{}).Error
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

// ForkAgent creates a copy of an existing agent for the authenticated user.
func (s *AgentService) ForkAgent(originalID uint, creatorWallet string) (*models.Agent, error) {
	var original models.Agent
	if err := database.DB.First(&original, originalID).Error; err != nil {
		return nil, fmt.Errorf("original agent not found: %w", err)
	}

	// Generate a fresh avatar via AI Pipeline
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	forkProfile := &client.AgentProfile{Name: original.Title}
	avatarRes, _ := s.aiClient.Avatar(ctx, forkProfile, "A variant of "+original.CharacterType+" agent", original.CharacterType)

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
		entry := models.LibraryEntry{UserWallet: creatorWallet, AgentID: fork.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).Where("id = ?", fork.ID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
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

// GetCreditHistory returns the last 50 credit transactions for a wallet.
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
func (s *AgentService) RecordPurchase(buyerWallet string, agentID uint, txHash string, amountMon float64) error {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return fmt.Errorf("agent not found: %w", err)
	}

	if err := verifyMonadTransaction(txHash, buyerWallet, s.expectedToAddresses(), amountMon); err != nil {
		return fmt.Errorf("transaction verification failed: %w", err)
	}

	return database.DB.Transaction(func(dbTx *gorm.DB) error {
		var existing models.PurchasedAgent
		if dbTx.Where("buyer_wallet = ? AND agent_id = ?", buyerWallet, agentID).First(&existing).Error == nil {
			return nil // already purchased
		}
		purchase := models.PurchasedAgent{
			BuyerWallet: buyerWallet,
			AgentID:     agentID,
			TxHash:      txHash,
			AmountMon:   amountMon,
		}
		return dbTx.Create(&purchase).Error
	})
}

// IsPurchased checks if a wallet has purchased the agent.
func (s *AgentService) IsPurchased(buyerWallet string, agentID uint) bool {
	var p models.PurchasedAgent
	return database.DB.Where("buyer_wallet = ? AND agent_id = ?", buyerWallet, agentID).First(&p).Error == nil
}

// UpdateAgent allows a creator to update title, description, and tags.
func (s *AgentService) UpdateAgent(agentID uint, wallet string, title, description *string, tags []string) (*models.Agent, error) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return nil, fmt.Errorf("agent not found")
	}
	if agent.CreatorWallet != wallet {
		return nil, fmt.Errorf("unauthorized: you can only edit your own agents")
	}

	updates := map[string]any{}
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
	database.DB.First(&agent, agentID)

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

// GetRatings returns ratings, average, and count for an agent.
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

// TopUpCredits grants credits after verifying MON payment on-chain.
func (s *AgentService) TopUpCredits(wallet, txHash string, amountMon float64) error {
	credits := int64(amountMon * 100)
	if credits < 10 {
		return fmt.Errorf("minimum top-up is 0.1 MON (10 credits)")
	}

	if err := verifyMonadTransaction(txHash, wallet, s.expectedToAddresses(), amountMon); err != nil {
		return fmt.Errorf("transaction verification failed: %w", err)
	}

	var user models.User
	if database.DB.Where("wallet_address = ?", wallet).First(&user).Error != nil {
		database.DB.Create(&models.User{WalletAddress: wallet, Credits: credits})
	} else {
		database.DB.Model(&models.User{}).
			Where("wallet_address = ?", wallet).
			UpdateColumn("credits", gorm.Expr("credits + ?", credits))
	}
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

// UpdateProfile updates username and bio.
func (s *AgentService) UpdateProfile(wallet string, input UpdateProfileInput) error {
	if len(input.Username) > 32 {
		return errors.New("username too long (max 32)")
	}
	if len(input.Bio) > 160 {
		return errors.New("bio too long (max 160)")
	}
	return database.DB.Model(&models.User{}).
		Where("wallet_address = ?", wallet).
		Updates(map[string]any{
			"username": input.Username,
			"bio":      input.Bio,
		}).Error
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
func (s *AgentService) IncrementUseCount(agentID uint) {
	database.DB.Model(&models.Agent{}).
		Where("id = ?", agentID).
		UpdateColumn("use_count", gorm.Expr("use_count + 1"))
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
