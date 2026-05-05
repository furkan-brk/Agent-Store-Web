package agent

// versioning.go — point-in-time snapshots of an agent's editable fields, with
// list / get / rollback endpoints.
//
// Snapshots are taken (best-effort) inside UpdateAgent right after a successful
// write. Rollback re-snapshots the *current* state before applying the
// historical fields so users never lose their last-saved variant when they
// undo. Storage is bounded at maxAgentVersions per agent (LRU evict).

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/lib/pq"
	"gorm.io/gorm"
)

// maxAgentVersions caps history depth per agent. v3.11.3 picks 20 — enough
// for a busy editor session, small enough that 10k agents × 20 versions still
// fits comfortably in pg without a separate retention job.
const maxAgentVersions = 20

// ErrAgentVersionNotFound surfaces when (agent_id, version) has no row.
var ErrAgentVersionNotFound = errors.New("agent version not found")

// AgentVersionFields is the schema-flexible snapshot payload. Pointer-typed
// fields preserve "absent" vs "explicitly empty" so the rollback applier
// doesn't accidentally clobber unaffected columns. character_data is stored
// as a raw JSON blob so we don't have to mirror its inner schema here.
type AgentVersionFields struct {
	Title              *string         `json:"title,omitempty"`
	Prompt             *string         `json:"prompt,omitempty"`
	Description        *string         `json:"description,omitempty"`
	Tags               []string        `json:"tags,omitempty"`
	CharacterData      json.RawMessage `json:"character_data,omitempty"`
	Traits             []string        `json:"traits,omitempty"`
	ProfileMood        *string         `json:"profile_mood,omitempty"`
	ProfileRolePurpose *string         `json:"profile_role_purpose,omitempty"`
	Stats              json.RawMessage `json:"stats,omitempty"`
}

// AgentVersionDTO is the public response shape. FieldsJSON is exposed as a
// parsed object so the UI doesn't need to double-decode.
type AgentVersionDTO struct {
	ID        uint               `json:"id"`
	AgentID   uint               `json:"agent_id"`
	Version   int                `json:"version"`
	Fields    AgentVersionFields `json:"fields"`
	CreatedAt string             `json:"created_at"`
}

// maxSnapshotRetries caps the MAX(version)+1 retry loop. v3.12 P1-7:
// under burst edits two callers can both read the same MAX, both try to
// INSERT version=N+1, and the loser hits the (agent_id, version) unique
// index. Re-read MAX and retry — any single agent should converge in
// well under this bound; the cap exists to fail loud on a stuck case.
const maxSnapshotRetries = 3

// isAgentVersionUniqueConflict matches the duplicate-key signature for the
// (agent_id, version) composite unique. Pure-string match is dialect-
// portable: gorm.ErrDuplicatedKey only fires on Postgres in some versions,
// and SQLite returns "UNIQUE constraint failed" with the column names.
func isAgentVersionUniqueConflict(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, gorm.ErrDuplicatedKey) {
		return true
	}
	msg := err.Error()
	return strings.Contains(msg, "UNIQUE constraint failed") ||
		strings.Contains(msg, "duplicate key value") ||
		strings.Contains(msg, "idx_agent_version_pair")
}

// snapshotAgentVersion captures the current row's editable fields as a new
// version. Best-effort — failures are logged and never bubble up to the
// UpdateAgent caller (a missed snapshot is recoverable; a failed save isn't).
//
// v3.12 P1-7: read-then-insert is wrapped in a retry loop. Two parallel
// saves can race on MAX(version) and produce identical version numbers;
// the composite unique index rejects the second insert, we re-read MAX
// and try again. Bounded at maxSnapshotRetries to fail loud on a stuck
// case (e.g. a corrupted index or a bug in the version sequencer).
func (s *AgentService) snapshotAgentVersion(agentID uint) {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		log.Printf("[versioning] snapshot load failed for agent %d: %v", agentID, err)
		return
	}

	fields := buildVersionFields(&agent)
	blob, err := json.Marshal(fields)
	if err != nil {
		log.Printf("[versioning] marshal failed for agent %d: %v", agentID, err)
		return
	}

	for attempt := 1; attempt <= maxSnapshotRetries; attempt++ {
		// Re-read MAX(version) on each attempt so a competing writer's
		// successful insert is reflected in our next computed version.
		var maxVersion int
		database.DB.Model(&models.AgentVersion{}).
			Where("agent_id = ?", agentID).
			Select("COALESCE(MAX(version), 0)").
			Scan(&maxVersion)

		next := maxVersion + 1
		err := database.DB.Create(&models.AgentVersion{
			AgentID:    agentID,
			Version:    next,
			FieldsJSON: string(blob),
		}).Error
		if err == nil {
			if attempt > 1 {
				log.Printf("[versioning] snapshot succeeded for agent %d v%d after %d attempts",
					agentID, next, attempt)
			}
			// LRU evict: if we now have > maxAgentVersions rows, drop the oldest.
			pruneOldVersions(agentID)
			return
		}
		if !isAgentVersionUniqueConflict(err) {
			log.Printf("[versioning] snapshot insert failed for agent %d v%d: %v", agentID, next, err)
			return
		}
		// Conflict: another writer claimed this version. Loop.
		log.Printf("[versioning] snapshot retry %d/%d for agent %d v%d (concurrent writer)",
			attempt, maxSnapshotRetries, agentID, next)
	}
	log.Printf("[versioning] snapshot gave up after %d retries for agent %d", maxSnapshotRetries, agentID)
}

// pruneOldVersions trims the oldest snapshot rows so total per-agent count
// stays at maxAgentVersions. Best-effort, called from snapshotAgentVersion.
func pruneOldVersions(agentID uint) {
	var count int64
	database.DB.Model(&models.AgentVersion{}).
		Where("agent_id = ?", agentID).
		Count(&count)
	if count <= maxAgentVersions {
		return
	}
	excess := int(count) - maxAgentVersions

	// Find the oldest `excess` rows and delete them. Subquery via Pluck so it
	// works on both sqlite + postgres (no LIMIT on DELETE).
	var oldIDs []uint
	if err := database.DB.Model(&models.AgentVersion{}).
		Where("agent_id = ?", agentID).
		Order("version ASC").
		Limit(excess).
		Pluck("id", &oldIDs).Error; err != nil {
		log.Printf("[versioning] prune lookup failed: %v", err)
		return
	}
	if len(oldIDs) == 0 {
		return
	}
	if err := database.DB.
		Where("id IN ?", oldIDs).
		Delete(&models.AgentVersion{}).Error; err != nil {
		log.Printf("[versioning] prune delete failed: %v", err)
	}
}

// buildVersionFields snapshots the editable subset of an agent into the
// versioning payload. Pulls character_data as raw JSON so traits / profile /
// stats survive intact.
func buildVersionFields(a *models.Agent) AgentVersionFields {
	f := AgentVersionFields{
		Title:       strPtr(a.Title),
		Prompt:      strPtr(a.Prompt),
		Description: strPtr(a.Description),
		Tags:        []string(a.Tags),
	}
	if a.CharacterData != "" {
		f.CharacterData = json.RawMessage(a.CharacterData)
		// Pull traits / profile fields out of character_data so consumers that
		// only render the fields struct (without re-decoding character_data)
		// still see them.
		var charData map[string]any
		if err := json.Unmarshal([]byte(a.CharacterData), &charData); err == nil {
			if traitsRaw, ok := charData["traits"].([]any); ok {
				f.Traits = make([]string, 0, len(traitsRaw))
				for _, t := range traitsRaw {
					if s, ok := t.(string); ok {
						f.Traits = append(f.Traits, s)
					}
				}
			}
			if profile, ok := charData["profile"].(map[string]any); ok {
				if mood, ok := profile["mood"].(string); ok {
					f.ProfileMood = strPtr(mood)
				}
				if rp, ok := profile["role_purpose"].(string); ok {
					f.ProfileRolePurpose = strPtr(rp)
				}
			}
			if stats, ok := charData["stats"]; ok {
				if b, err := json.Marshal(stats); err == nil {
					f.Stats = b
				}
			}
		}
	}
	return f
}

// strPtr returns a pointer to s — convenience for the optional fields above.
func strPtr(s string) *string { return &s }

// ListAgentVersions returns the wallet's agent's version history, newest first.
// Owner check is mandatory (versions reveal historical prompt/title — not for
// non-owners to see). Capped at maxAgentVersions because that's the storage
// ceiling anyway.
func (s *AgentService) ListAgentVersions(wallet string, agentID uint) ([]AgentVersionDTO, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if err := s.ensureAgentOwner(wallet, agentID); err != nil {
		return nil, err
	}
	var rows []models.AgentVersion
	if err := database.DB.
		Where("agent_id = ?", agentID).
		Order("version DESC").
		Limit(maxAgentVersions).
		Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make([]AgentVersionDTO, 0, len(rows))
	for _, r := range rows {
		out = append(out, versionRowToDTO(&r))
	}
	return out, nil
}

// GetAgentVersion returns a single version snapshot for the wallet's agent.
// Returns ErrAgentVersionNotFound when (agent_id, version) doesn't match.
func (s *AgentService) GetAgentVersion(wallet string, agentID uint, version int) (*AgentVersionDTO, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if err := s.ensureAgentOwner(wallet, agentID); err != nil {
		return nil, err
	}
	var row models.AgentVersion
	if err := database.DB.
		Where("agent_id = ? AND version = ?", agentID, version).
		First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAgentVersionNotFound
		}
		return nil, err
	}
	dto := versionRowToDTO(&row)
	return &dto, nil
}

// RollbackAgentVersion restores the editable fields from a historical snapshot.
//
// Order of operations:
//  1. snapshot the *current* state as a new version (so the user can undo the
//     undo without losing their latest variant);
//  2. apply the historical fields via Updates();
//  3. record a fresh snapshot of the post-rollback state so the next list
//     shows the rollback as the newest version.
//
// Step (3) ensures version numbers stay strictly monotonic — never re-write
// an older row. Returns the post-rollback agent.
func (s *AgentService) RollbackAgentVersion(wallet string, agentID uint, version int) (*models.Agent, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if err := s.ensureAgentOwner(wallet, agentID); err != nil {
		return nil, err
	}
	var snap models.AgentVersion
	if err := database.DB.
		Where("agent_id = ? AND version = ?", agentID, version).
		First(&snap).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAgentVersionNotFound
		}
		return nil, err
	}

	// Snapshot current first so the rollback is reversible.
	s.snapshotAgentVersion(agentID)

	var fields AgentVersionFields
	if err := json.Unmarshal([]byte(snap.FieldsJSON), &fields); err != nil {
		return nil, fmt.Errorf("decode snapshot: %w", err)
	}

	updates := map[string]any{}
	if fields.Title != nil {
		updates["title"] = *fields.Title
	}
	if fields.Prompt != nil {
		updates["prompt"] = *fields.Prompt
	}
	if fields.Description != nil {
		updates["description"] = *fields.Description
	}
	if fields.Tags != nil {
		updates["tags"] = pq.StringArray(fields.Tags)
	}
	if fields.CharacterData != nil {
		updates["character_data"] = string(fields.CharacterData)
	}

	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return nil, fmt.Errorf("agent not found")
	}
	if len(updates) > 0 {
		if err := database.DB.Model(&agent).Updates(updates).Error; err != nil {
			return nil, fmt.Errorf("rollback apply: %w", err)
		}
	}
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return nil, err
	}

	// Snapshot the post-rollback state so it shows up as the newest version.
	s.snapshotAgentVersion(agentID)

	// Cache busts mirror UpdateAgent.
	s.cache.DeletePrefix("agents|")
	s.cache.Delete("trending")
	s.cache.Delete("categories")

	return &agent, nil
}

// ensureAgentOwner returns nil if the wallet is the agent's creator. This is
// the gate that keeps version data private to the owner.
func (s *AgentService) ensureAgentOwner(wallet string, agentID uint) error {
	var a models.Agent
	if err := database.DB.Select("id, creator_wallet").First(&a, agentID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("agent not found")
		}
		return err
	}
	if strings.ToLower(a.CreatorWallet) != wallet {
		return fmt.Errorf("unauthorized")
	}
	return nil
}

// versionRowToDTO normalises a stored row into the public DTO. Decodes
// FieldsJSON eagerly so the caller gets a typed payload.
func versionRowToDTO(r *models.AgentVersion) AgentVersionDTO {
	var fields AgentVersionFields
	_ = json.Unmarshal([]byte(r.FieldsJSON), &fields)
	return AgentVersionDTO{
		ID:        r.ID,
		AgentID:   r.AgentID,
		Version:   r.Version,
		Fields:    fields,
		CreatedAt: r.CreatedAt.UTC().Format("2006-01-02T15:04:05Z"),
	}
}
