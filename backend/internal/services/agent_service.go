package services

import (
	"errors"
	"fmt"
	"log"
	"strings"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
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
	aiSvc        *AIService
	geminiSvc    *GeminiService
	replicateSvc *ReplicateService
	scoreSvc     *ScoreService
}

func NewAgentService(aiSvc *AIService, geminiSvc *GeminiService, replicateSvc *ReplicateService, scoreSvc *ScoreService) *AgentService {
	return &AgentService{aiSvc: aiSvc, geminiSvc: geminiSvc, replicateSvc: replicateSvc, scoreSvc: scoreSvc}
}

type CreateAgentInput struct {
	Title         string `json:"title" binding:"required"`
	Description   string `json:"description"`
	Prompt        string `json:"prompt" binding:"required"`
	CreatorWallet string
}

func (s *AgentService) ListAgents(category, search, sort string, page, limit int) ([]models.Agent, int64, error) {
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
	orderClause := "created_at DESC" // default: newest
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
	// Select only list-view fields, skip heavy prompt and character_data
	err := query.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, created_at").
		Offset(offset).Limit(limit).Order(orderClause).Find(&agents).Error
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
	// ── Step 1: Analyze prompt with Gemini (category, tags, character type, rarity)
	analysis, err := s.geminiSvc.AnalyzePrompt(input.Prompt)
	if err != nil {
		log.Printf("[Gemini] analysis failed, falling back to keywords: %v", err)
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

	// ── Step 2: Generate rich visual profile via world-builder LLM call
	agentConcept := input.Title
	if input.Description != "" {
		agentConcept += ": " + input.Description
	}
	profile, profileErr := s.geminiSvc.GenerateAgentProfile(agentConcept)
	if profileErr != nil {
		log.Printf("[Gemini] profile generation failed, using fallback: %v", profileErr)
		profile = buildFallbackProfile(agentConcept, analysis.CharacterType)
	} else {
		log.Printf("[Gemini] agent profile generated: name=%q type=%s", profile.Name, analysis.CharacterType)
	}

	// ── Step 3: Generate 16-bit pixel-art avatar via GenerateAvatarImage (sole image source)
	generatedImage, imgErr := s.geminiSvc.GenerateAvatarImage(profile)
	if imgErr != nil {
		log.Printf("[Gemini] avatar image generation failed, agent will have no image: %v", imgErr)
		generatedImage = "" // frontend shows shimmer skeleton placeholder
	} else {
		log.Printf("[Gemini] 16-bit avatar generated (type=%s)", analysis.CharacterType)
	}

	// ── Step 4: Build stats / traits / colors, then merge visual profile into character_data
	charData, err := BuildCharacterData(analysis.CharacterType, analysis.Subclass, rarity, input.Prompt)
	if err != nil {
		charData = "{}"
	}
	charData = MergeProfileIntoCharacterData(charData, profile)

	// ── Step 3.5: Score prompt and generate service description
	scoreResult := s.scoreSvc.ScoreAndDescribe(input.Prompt)

	// ── Step 3.6: Deduct 10 credits for agent creation
	if input.CreatorWallet != "" {
		if err := s.deductCredits(input.CreatorWallet, 10, "create", nil); err != nil {
			return nil, fmt.Errorf("credit check failed: %w", err)
		}
	}

	// ── Step 6: Persist
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
	}
	err = database.DB.Create(agent).Error
	if err == nil && input.CreatorWallet != "" {
		entry := models.LibraryEntry{UserWallet: input.CreatorWallet, AgentID: agent.ID}
		database.DB.Create(&entry)
		database.DB.Model(&models.Agent{}).Where("id = ?", agent.ID).UpdateColumn("save_count", gorm.Expr("save_count + 1"))
	}
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
	var agents []models.Agent
	// Select only list-view fields, skip heavy prompt and character_data
	err := database.DB.
		Select("id, title, description, service_description, category, creator_wallet, character_type, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, created_at").
		Order("(save_count * 3 + use_count * 2) DESC").
		Limit(6).
		Find(&agents).Error
	return agents, err
}

// ForkAgent creates a new agent based on an existing one with a fresh GenerateAvatarImage avatar.
func (s *AgentService) ForkAgent(originalID uint, creatorWallet string) (*models.Agent, error) {
	var original models.Agent
	if err := database.DB.First(&original, originalID).Error; err != nil {
		return nil, fmt.Errorf("original agent not found: %w", err)
	}

	// Generate a fresh visual profile + 16-bit avatar for the fork (sole image source)
	forkConcept := original.Title + " (forked variant)"
	forkProfile, profileErr := s.geminiSvc.GenerateAgentProfile(forkConcept)
	if profileErr != nil {
		log.Printf("[Gemini] fork profile failed, using fallback: %v", profileErr)
		forkProfile = buildFallbackProfile(forkConcept, original.CharacterType)
	}

	forkedImage, imgErr := s.geminiSvc.GenerateAvatarImage(forkProfile)
	if imgErr != nil {
		log.Printf("[Gemini] fork avatar image failed, fork will have no image: %v", imgErr)
		forkedImage = "" // frontend shows shimmer skeleton placeholder
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
	}

	if err := database.DB.Create(fork).Error; err != nil {
		return nil, err
	}

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

// buildFallbackProfile creates a sensible AgentProfile when the LLM call fails,
// using the character type to determine default colors and visual details.
func buildFallbackProfile(concept, charType string) *AgentProfile {
	type defaults struct {
		primary, secondary, glow string
		face, chest, tool, dist  string
	}
	d := map[string]defaults{
		"wizard":     {"Violet", "Midnight Blue", "Purple", "a glowing purple visor", "an arcane rune emblem", "a magical energy wand", "subtle glowing rune etchings on the shoulder plates"},
		"strategist": {"Crimson", "Gold", "Red", "a sharp tactical visor", "a command-star emblem", "a holographic baton", "integrated command chevrons along the chest"},
		"oracle":     {"Amber", "Deep Orange", "Yellow", "glowing all-seeing eyes behind a glass visor", "a third-eye emblem", "a crystal data probe", "flowing light-ribbon accents along the arms"},
		"guardian":   {"Cobalt Blue", "Steel Grey", "Cyan", "a fortress-slit visor", "a shield emblem", "a scanning lance probe", "reinforced angular shoulder armor vents"},
		"artisan":    {"Rose Pink", "Teal", "Magenta", "a creative lens visor", "a palette emblem", "a precision stylus pen", "color-gradient panel accents on the torso"},
		"bard":       {"Emerald Green", "Lime", "Green", "an expressive mirrored visor", "a musical note emblem", "a resonance rod stylus", "harmonic wave patterns etched into the chest plate"},
		"scholar":    {"Warm Beige", "Brown", "Amber", "round academic glass spectacles over a calm face", "an open-book emblem", "a calibration pointer rod", "subtle gear-and-cog filigree on the pauldrons"},
		"merchant":   {"Gold", "Navy Blue", "Orange", "a confident half-mirrored visor", "a coin-stack emblem", "a deal-sealing signet stylus", "thin gold trim lines running along the suit edges"},
	}
	def, ok := d[charType]
	if !ok {
		def = d["wizard"]
	}
	return &AgentProfile{
		Name:            concept,
		Mood:            "Focused and ready to assist.",
		RolePurpose:     "An AI agent designed to excel in its specialized domain. Provides expert assistance with precision and efficiency.",
		PrimaryColor:    def.primary,
		SecondaryColor:  def.secondary,
		TabletGlowColor: def.glow,
		Characteristics: []string{
			def.face,
			def.chest,
			def.tool,
			def.dist,
		},
	}
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
