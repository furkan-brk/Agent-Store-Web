package agent

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
)

// useCooldownWindow is the duration during which repeat use_count increments
// from the same wallet or IP for the same agent are suppressed. Tuned to be
// long enough to defeat scripted spamming but short enough not to penalise
// genuine user retries.
const useCooldownWindow = 60 * time.Second

// HashIP returns a deterministic SHA-256 hex digest of the given IP string.
// Empty input → empty output. We never store raw IPs to keep the log
// privacy-friendly while still allowing cross-request correlation.
func HashIP(ip string) string {
	ip = strings.TrimSpace(ip)
	if ip == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(ip))
	return hex.EncodeToString(sum[:])
}

// recordUseAttempt records a use_count attempt for the given agent and
// returns whether the increment should actually be applied. If a previous log
// row from the same wallet OR ip_hash exists within useCooldownWindow, the
// attempt is suppressed (counted = false) and no log row is written.
//
// Both wallet and ipHash may be empty (anonymous internal calls); in that case
// no cooldown is applied and the increment is always counted.
func recordUseAttempt(agentID uint, wallet, ipHash string) bool {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" && ipHash == "" {
		// No identity to dedupe on — let the caller decide via plain Increment.
		return true
	}

	cutoff := time.Now().Add(-useCooldownWindow)

	// Build a single OR query: same agent + (matching wallet OR matching ip_hash) within window.
	q := database.DB.Model(&models.AgentUseLog{}).Where("agent_id = ? AND created_at > ?", agentID, cutoff)
	switch {
	case wallet != "" && ipHash != "":
		q = q.Where("wallet = ? OR ip_hash = ?", wallet, ipHash)
	case wallet != "":
		q = q.Where("wallet = ?", wallet)
	default:
		q = q.Where("ip_hash = ?", ipHash)
	}

	var count int64
	if err := q.Count(&count).Error; err != nil {
		// If the lookup fails, fail-open so legitimate counts are not lost.
		return true
	}
	if count > 0 {
		return false
	}

	// Persist the log row so future calls within the window are suppressed.
	_ = database.DB.Create(&models.AgentUseLog{
		AgentID: agentID,
		Wallet:  wallet,
		IPHash:  ipHash,
	}).Error
	return true
}
