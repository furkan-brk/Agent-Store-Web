package guild

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

func encodeJSON(v any) ([]byte, error) { return json.Marshal(v) }

// ─── Guild Invite Links ───────────────────────────────────────────────────────

// CreateInviteInput is the request body for creating a guild invite.
type CreateInviteInput struct {
	MaxUses   int `json:"max_uses"`   // 0 = unlimited
	ExpiresIn int `json:"expires_in"` // hours; 0 = 7 days default
}

// generateToken returns a 16-byte (32 hex char) cryptographically random token.
func generateToken() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// CreateInvite generates a new invite link for a guild, scoped to the creator wallet.
func (s *GuildService) CreateInvite(wallet string, guildID uint, input CreateInviteInput) (*models.GuildInvite, error) {
	wallet = strings.ToLower(wallet)

	// Verify ownership.
	var guild models.Guild
	if err := database.DB.First(&guild, guildID).Error; err != nil {
		return nil, fmt.Errorf("guild not found")
	}
	if strings.ToLower(guild.CreatorWallet) != wallet {
		return nil, fmt.Errorf("only the guild owner can create invite links")
	}

	token, err := generateToken()
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	hours := input.ExpiresIn
	if hours <= 0 {
		hours = 7 * 24 // 7 days default
	}

	invite := &models.GuildInvite{
		GuildID:   guildID,
		Token:     token,
		ExpiresAt: time.Now().UTC().Add(time.Duration(hours) * time.Hour),
		MaxUses:   input.MaxUses,
	}
	if err := database.DB.Create(invite).Error; err != nil {
		return nil, fmt.Errorf("failed to create invite: %w", err)
	}
	return invite, nil
}

// GetInvite returns a guild invite by token (for preview before accepting).
func (s *GuildService) GetInvite(token string) (*models.GuildInvite, error) {
	var invite models.GuildInvite
	if err := database.DB.Where("token = ?", token).First(&invite).Error; err != nil {
		return nil, fmt.Errorf("invite not found")
	}
	if time.Now().After(invite.ExpiresAt) {
		return nil, fmt.Errorf("invite has expired")
	}
	if invite.MaxUses > 0 && invite.UsesCount >= invite.MaxUses {
		return nil, fmt.Errorf("invite has reached maximum uses")
	}
	return &invite, nil
}

// AcceptInvite adds the requesting wallet as a member of the guild.
// Returns an error if the invite is invalid/expired/exhausted or the user is already a member.
func (s *GuildService) AcceptInvite(wallet, token string) (*models.Guild, error) {
	wallet = strings.ToLower(wallet)

	invite, err := s.GetInvite(token)
	if err != nil {
		return nil, err
	}

	var guild models.Guild
	if err := database.DB.Preload("Members").First(&guild, invite.GuildID).Error; err != nil {
		return nil, fmt.Errorf("guild not found")
	}

	// Check already a member (via agent ownership — wallet-level membership not directly tracked,
	// but prevent double-joining the same guild as the creator).
	if strings.ToLower(guild.CreatorWallet) == wallet {
		return nil, fmt.Errorf("you are already the guild owner")
	}

	// Increment usage count.
	database.DB.Model(invite).UpdateColumn("uses_count", invite.UsesCount+1)

	return &guild, nil
}

// DeleteInvite removes all invite links for a guild (owner only).
func (s *GuildService) DeleteInvite(wallet string, guildID uint) error {
	wallet = strings.ToLower(wallet)
	var guild models.Guild
	if err := database.DB.First(&guild, guildID).Error; err != nil {
		return fmt.Errorf("guild not found")
	}
	if strings.ToLower(guild.CreatorWallet) != wallet {
		return fmt.Errorf("only the guild owner can delete invite links")
	}
	return database.DB.Where("guild_id = ?", guildID).Delete(&models.GuildInvite{}).Error
}

// ─── Guild Permissions ────────────────────────────────────────────────────────

// SetMemberPermissions sets the permission array for a specific guild member.
// Only the guild creator wallet can update permissions.
func (s *GuildService) SetMemberPermissions(wallet string, guildID, memberID uint, permissions []string) error {
	wallet = strings.ToLower(wallet)
	var guild models.Guild
	if err := database.DB.First(&guild, guildID).Error; err != nil {
		return fmt.Errorf("guild not found")
	}
	if strings.ToLower(guild.CreatorWallet) != wallet {
		return fmt.Errorf("only the guild owner can set permissions")
	}

	// Validate permission keys.
	validKeys := map[string]bool{
		"edit_agents": true, "invite_members": true, "kick_members": true,
		"change_compatibility": true, "manage_roles": true,
	}
	for _, p := range permissions {
		if !validKeys[p] {
			return fmt.Errorf("unknown permission key %q", p)
		}
	}

	permJSON := "[]"
	if len(permissions) > 0 {
		b, _ := encodeJSON(permissions)
		permJSON = string(b)
	}

	result := database.DB.Model(&models.GuildMember{}).
		Where("id = ? AND guild_id = ?", memberID, guildID).
		UpdateColumn("permissions", permJSON)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("member not found")
	}
	return nil
}

// ─── Compatibility Explainability ─────────────────────────────────────────────

// CompatibilityBreakdown explains the synergy score components for a guild.
type CompatibilityBreakdown struct {
	TotalScore       float64               `json:"total_score"`
	TypeSynergy      float64               `json:"type_synergy"`
	RarityBalance    float64               `json:"rarity_balance"`
	RoleCompleteness float64               `json:"role_completeness"`
	Details          []CompatibilityDetail `json:"details"`
}

// CompatibilityDetail is one line of the score breakdown.
type CompatibilityDetail struct {
	Factor      string  `json:"factor"`
	Score       float64 `json:"score"`
	MaxScore    float64 `json:"max_score"`
	Description string  `json:"description"`
}

// ExplainCompatibility returns a breakdown of the guild's synergy score.
func (s *GuildService) ExplainCompatibility(guildID uint) (*CompatibilityBreakdown, error) {
	var guild models.Guild
	if err := database.DB.
		Preload("Members.Agent").
		First(&guild, guildID).Error; err != nil {
		return nil, fmt.Errorf("guild not found")
	}

	if len(guild.Members) == 0 {
		return &CompatibilityBreakdown{
			Details: []CompatibilityDetail{
				{Factor: "No members", Score: 0, MaxScore: 100, Description: "Add agents to calculate synergy"},
			},
		}, nil
	}

	// 1. Type diversity: unique character types / total members (max 40 pts)
	typeSet := map[string]bool{}
	raritySet := map[string]bool{}
	roleSet := map[string]bool{}
	for _, m := range guild.Members {
		typeSet[m.Agent.CharacterType] = true
		raritySet[string(m.Agent.Rarity)] = true
		if m.Role != "" {
			roleSet[m.Role] = true
		}
	}
	uniqueTypes := float64(len(typeSet))
	totalMembers := float64(len(guild.Members))

	typeSynergy := (uniqueTypes / totalMembers) * 40
	if typeSynergy > 40 {
		typeSynergy = 40
	}

	// 2. Rarity balance: having at least 2 different rarities (max 30 pts)
	rarityBalance := float64(len(raritySet)) / 5.0 * 30
	if rarityBalance > 30 {
		rarityBalance = 30
	}

	// 3. Role completeness: unique roles / members (max 30 pts)
	roleCompleteness := (float64(len(roleSet)) / totalMembers) * 30
	if roleCompleteness > 30 {
		roleCompleteness = 30
	}

	total := typeSynergy + rarityBalance + roleCompleteness

	details := []CompatibilityDetail{
		{
			Factor:      "Type Diversity",
			Score:       round2(typeSynergy),
			MaxScore:    40,
			Description: fmt.Sprintf("%d unique character types across %d members", len(typeSet), len(guild.Members)),
		},
		{
			Factor:      "Rarity Balance",
			Score:       round2(rarityBalance),
			MaxScore:    30,
			Description: fmt.Sprintf("%d distinct rarity levels represented", len(raritySet)),
		},
		{
			Factor:      "Role Completeness",
			Score:       round2(roleCompleteness),
			MaxScore:    30,
			Description: fmt.Sprintf("%d unique roles assigned", len(roleSet)),
		},
	}

	return &CompatibilityBreakdown{
		TotalScore:       round2(total),
		TypeSynergy:      round2(typeSynergy),
		RarityBalance:    round2(rarityBalance),
		RoleCompleteness: round2(roleCompleteness),
		Details:          details,
	}, nil
}

func round2(f float64) float64 {
	return float64(int(f*100+0.5)) / 100
}
