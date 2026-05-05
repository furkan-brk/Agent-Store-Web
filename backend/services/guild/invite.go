package guild

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
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
//
// SECURITY (v3.12-P0-3): the previous implementation had two bugs that
// together made the endpoint a no-op-with-side-effects:
//
//  1. TOCTOU on UsesCount: GetInvite read uses_count, then the increment
//     wrote a literal value (uses_count = read+1). N concurrent calls all
//     read 0 and wrote 1 — a MaxUses=1 invite minted N memberships.
//  2. Missing GuildMember insert: the function bumped uses_count and
//     returned the guild but never created the membership row, so
//     "accepting" an invite did nothing observable.
//
// The fix wraps everything in a single DB transaction:
//   - SELECT the invite FOR UPDATE so concurrent acceptors serialize.
//   - Re-validate ExpiresAt and MaxUses inside the lock.
//   - Increment uses_count via gorm.Expr("uses_count + 1") — atomic and
//     race-free (no read-then-write).
//   - Pick the user's first agent and INSERT the GuildMember row with
//     ON CONFLICT DO NOTHING so re-acceptance (user clicks twice) is
//     idempotent rather than an error.
//   - Best-effort audit log AFTER the transaction commits.
//
// Returns an error if the invite is invalid/expired/exhausted, the user
// has no agents, or the user is the guild owner.
func (s *GuildService) AcceptInvite(wallet, token string) (*models.Guild, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}
	if database.DB == nil {
		return nil, fmt.Errorf("database not ready")
	}

	var (
		guild        models.Guild
		joinedAgent  models.Agent
		alreadyMember bool
	)

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		// FOR UPDATE serialises concurrent acceptors of the same invite —
		// the cap check + increment now happens under exclusive lock.
		// SQLite (used in tests) ignores the locking clause but the
		// transaction itself is still serialised. Postgres honours it.
		var invite models.GuildInvite
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("token = ?", token).
			First(&invite).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return fmt.Errorf("invite not found")
			}
			return fmt.Errorf("invite lookup: %w", err)
		}
		if time.Now().After(invite.ExpiresAt) {
			return fmt.Errorf("invite has expired")
		}
		if invite.MaxUses > 0 && invite.UsesCount >= invite.MaxUses {
			return fmt.Errorf("invite has reached maximum uses")
		}

		// Load the guild for the response and to enforce the owner check.
		if err := tx.First(&guild, invite.GuildID).Error; err != nil {
			return fmt.Errorf("guild not found")
		}
		if strings.ToLower(guild.CreatorWallet) == wallet {
			return fmt.Errorf("you are already the guild owner")
		}

		// Capacity check (max 4 members).
		var memberCount int64
		if err := tx.Model(&models.GuildMember{}).
			Where("guild_id = ?", invite.GuildID).
			Count(&memberCount).Error; err != nil {
			return fmt.Errorf("member count: %w", err)
		}
		if memberCount >= 4 {
			return fmt.Errorf("guild is full (max 4 members)")
		}

		// Pick the user's first agent — same convention as JoinGuild.
		if err := tx.Where("LOWER(creator_wallet) = ?", wallet).
			Order("created_at ASC").First(&joinedAgent).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return fmt.Errorf("you have no agents to join with")
			}
			return fmt.Errorf("agent lookup: %w", err)
		}

		// Idempotent insert: if this agent is already a member of this
		// guild, treat as a successful re-accept rather than creating a
		// duplicate row. We use a SELECT-then-INSERT inside the tx
		// because the GuildMember model doesn't carry a unique index on
		// (guild_id, agent_id) — adding one would require a separate
		// migration and is outside the scope of this P0.
		//
		// Note: we still bump uses_count below because the invite itself
		// was redeemed. Preserving "free re-accept doesn't count against
		// cap" semantics would require a per-(invite, wallet) dedup
		// table — out of scope for this P0.
		var existing models.GuildMember
		existsErr := tx.Where("guild_id = ? AND agent_id = ?", invite.GuildID, joinedAgent.ID).
			First(&existing).Error
		if existsErr == nil {
			alreadyMember = true
		} else if !errors.Is(existsErr, gorm.ErrRecordNotFound) {
			return fmt.Errorf("member dedup check: %w", existsErr)
		} else {
			role := determineMemberRole(joinedAgent)
			member := models.GuildMember{
				GuildID: invite.GuildID,
				AgentID: joinedAgent.ID,
				Role:    role,
			}
			if err := tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&member).Error; err != nil {
				return fmt.Errorf("member insert: %w", err)
			}
		}

		// Atomic uses_count increment — avoids the read-then-write race
		// the previous implementation had.
		if err := tx.Model(&models.GuildInvite{}).
			Where("id = ?", invite.ID).
			UpdateColumn("uses_count", gorm.Expr("uses_count + 1")).Error; err != nil {
			return fmt.Errorf("uses_count bump: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	// Cache + audit log AFTER commit so we don't pollute either when the
	// transaction rolls back. Best-effort — failures here don't surface.
	s.cache.DeletePrefix("guilds|")
	if !alreadyMember {
		s.LogMemberEvent(guild.ID, wallet, models.GuildEventJoined, map[string]any{
			"agent_id": joinedAgent.ID,
			"role":     joinedAgent.CharacterType,
			"via":      "invite_accept",
			"token":    token,
		})
	}

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
	// v3.11.4: audit-log permission change.
	s.LogMemberEvent(guildID, wallet, models.GuildEventPermissionChanged, map[string]any{
		"member_id": memberID, "permissions": permissions,
	})
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
