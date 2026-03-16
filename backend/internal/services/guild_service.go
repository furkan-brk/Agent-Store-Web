package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/models"
	"gorm.io/gorm"
)

type GuildService struct {
	scoreSvc *ScoreService
	cache    *CacheStore
}

func NewGuildService(scoreSvc *ScoreService, cache *CacheStore) *GuildService {
	return &GuildService{scoreSvc: scoreSvc, cache: cache}
}

type CreateGuildInput struct {
	Name          string `json:"name" binding:"required"`
	CreatorWallet string
}

// determineMemberRole picks a role based on the highest stat in character_data.
func determineMemberRole(agent models.Agent) string {
	var charData struct {
		Stats map[string]int `json:"stats"`
	}
	if err := json.Unmarshal([]byte(agent.CharacterData), &charData); err != nil || len(charData.Stats) == 0 {
		return "Member"
	}
	best, bestVal := "power", 0
	for k, v := range charData.Stats {
		if v > bestVal {
			bestVal = v
			best = k
		}
	}
	roleMap := map[string]string{
		"intelligence": "Brain",
		"defense":      "Shield",
		"speed":        "Scout",
		"creativity":   "Innovator",
		"power":        "Striker",
	}
	if role, ok := roleMap[best]; ok {
		return role
	}
	return "Member"
}

func (s *GuildService) ListGuilds(page, limit int) ([]models.Guild, int64, error) {
	cacheKey := fmt.Sprintf("guilds|%d|%d", page, limit)
	type cachedResult struct {
		Guilds []models.Guild `json:"guilds"`
		Total  int64          `json:"total"`
	}
	if data, ok := s.cache.Get(cacheKey); ok {
		var r cachedResult
		if err := json.Unmarshal(data, &r); err == nil {
			return r.Guilds, r.Total, nil
		}
	}
	var guilds []models.Guild
	var total int64
	database.DB.Model(&models.Guild{}).Count(&total)
	offset := (page - 1) * limit
	err := database.DB.Preload("Members.Agent", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at, updated_at")
	}).Preload("Members").
		Offset(offset).Limit(limit).Order("created_at DESC").Find(&guilds).Error
	if err == nil {
		if b, jerr := json.Marshal(cachedResult{Guilds: guilds, Total: total}); jerr == nil {
			s.cache.Set(cacheKey, b, 60*time.Second)
		}
	}
	return guilds, total, err
}

func (s *GuildService) CreateGuild(input CreateGuildInput) (*models.Guild, error) {
	guild := &models.Guild{
		Name:          input.Name,
		CreatorWallet: input.CreatorWallet,
		Rarity:        "common",
	}
	err := database.DB.Create(guild).Error
	if err == nil {
		s.cache.DeletePrefix("guilds|")
	}
	return guild, err
}

func (s *GuildService) GetGuild(id uint) (*models.Guild, []SynergyBonus, map[string]int, error) {
	var guild models.Guild
	err := database.DB.Preload("Members.Agent", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at, updated_at")
	}).Preload("Members").First(&guild, id).Error
	if err != nil {
		return nil, nil, nil, err
	}
	types := []string{}
	for _, m := range guild.Members {
		if m.Agent.CharacterType != "" {
			types = append(types, m.Agent.CharacterType)
		}
	}
	synergies, bonuses := CalculateGuildSynergy(types)
	guild.Rarity = calculateGuildRarity(guild.Members)
	return &guild, synergies, bonuses, nil
}

func (s *GuildService) AddMember(guildID uint, agentID uint, wallet string) error {
	var guild models.Guild
	if err := database.DB.First(&guild, guildID).Error; err != nil {
		return errors.New("guild not found")
	}
	if guild.CreatorWallet != wallet {
		return errors.New("unauthorized")
	}
	var count int64
	database.DB.Model(&models.GuildMember{}).Where("guild_id = ?", guildID).Count(&count)
	if count >= 4 {
		return errors.New("guild is full (max 4 members)")
	}
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return errors.New("agent not found")
	}
	var existing models.GuildMember
	if database.DB.Where("guild_id = ? AND agent_id = ?", guildID, agentID).First(&existing).Error == nil {
		return errors.New("agent already in guild")
	}
	role := determineMemberRole(agent)
	member := &models.GuildMember{
		GuildID: guildID,
		AgentID: agentID,
		Role:    role,
	}
	err := database.DB.Create(member).Error
	if err == nil {
		s.cache.DeletePrefix("guilds|")
	}
	return err
}

// JoinGuild lets any authenticated user add their first agent to a guild.
func (s *GuildService) JoinGuild(guildID uint, wallet string) error {
	var guild models.Guild
	if err := database.DB.First(&guild, guildID).Error; err != nil {
		return errors.New("guild not found")
	}
	var count int64
	database.DB.Model(&models.GuildMember{}).Where("guild_id = ?", guildID).Count(&count)
	if count >= 4 {
		return errors.New("guild is full (max 4 members)")
	}
	// Find the user's first agent
	var agent models.Agent
	if err := database.DB.Where("creator_wallet = ?", wallet).Order("created_at ASC").First(&agent).Error; err != nil {
		return errors.New("you have no agents to join with")
	}
	var existing models.GuildMember
	if database.DB.Where("guild_id = ? AND agent_id = ?", guildID, agent.ID).First(&existing).Error == nil {
		return errors.New("agent already in guild")
	}
	role := determineMemberRole(agent)
	member := &models.GuildMember{GuildID: guildID, AgentID: agent.ID, Role: role}
	err := database.DB.Create(member).Error
	if err == nil {
		s.cache.DeletePrefix("guilds|")
	}
	return err
}

// LeaveGuild removes the authenticated user's agent from a guild.
func (s *GuildService) LeaveGuild(guildID uint, wallet string) error {
	var agent models.Agent
	if err := database.DB.Where("creator_wallet = ?", wallet).Order("created_at ASC").First(&agent).Error; err != nil {
		return errors.New("no agent found")
	}
	err := database.DB.Where("guild_id = ? AND agent_id = ?", guildID, agent.ID).
		Delete(&models.GuildMember{}).Error
	if err == nil {
		s.cache.DeletePrefix("guilds|")
	}
	return err
}

func (s *GuildService) RemoveMember(guildID, agentID uint, wallet string) error {
	var guild models.Guild
	if err := database.DB.First(&guild, guildID).Error; err != nil {
		return errors.New("guild not found")
	}
	if guild.CreatorWallet != wallet {
		return errors.New("unauthorized")
	}
	err := database.DB.Where("guild_id = ? AND agent_id = ?", guildID, agentID).
		Delete(&models.GuildMember{}).Error
	if err == nil {
		s.cache.DeletePrefix("guilds|")
	}
	return err
}

// CheckCompatibility analyzes how well the agents in a guild complement each other.
func (s *GuildService) CheckCompatibility(guildID uint) (*GuildCompatibilityResult, error) {
	var guild models.Guild
	if err := database.DB.Preload("Members.Agent", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, title, description, service_description, category, creator_wallet, character_type, character_data, subclass, rarity, tags, save_count, use_count, generated_image, price, prompt_score, card_version, created_at, updated_at")
	}).Preload("Members").First(&guild, guildID).Error; err != nil {
		return nil, errors.New("guild not found")
	}

	summaries := make([]guildMemberSummary, 0, len(guild.Members))
	for _, m := range guild.Members {
		summaries = append(summaries, guildMemberSummary{
			AgentID:     m.AgentID,
			Title:       m.Agent.Title,
			CharType:    m.Agent.CharacterType,
			Category:    m.Agent.Category,
			ServiceDesc: m.Agent.ServiceDescription,
		})
	}

	return s.scoreSvc.AnalyzeGuildCompatibility(guildID, summaries), nil
}

func calculateGuildRarity(members []models.GuildMember) string {
	if len(members) == 0 {
		return "common"
	}
	rarityScore := map[string]int{
		"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4,
	}
	scoreToRarity := []string{"common", "uncommon", "rare", "epic", "legendary"}
	total := 0
	for _, m := range members {
		total += rarityScore[string(m.Agent.Rarity)]
	}
	avg := total / len(members)
	if avg < 0 {
		avg = 0
	}
	if avg >= len(scoreToRarity) {
		avg = len(scoreToRarity) - 1
	}
	return scoreToRarity[avg]
}
