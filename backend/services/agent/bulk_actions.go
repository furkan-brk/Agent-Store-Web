package agent

// bulk_actions.go — wallet-scoped bulk operations on agents.
//
// Each per-id action runs independently and per-id failures are tolerated:
// the response carries success/failure lists so the UI can surface partial
// results. This avoids a single bad id (e.g. a deleted agent) from blowing
// up the entire request.
//
// Quota guard runs once up front for actions with a credit cost
// (regenerate_image = 3 credits each). Other actions are free; the bulk
// caller pays nothing for tag changes / library removals.

import (
	"context"
	"errors"
	"fmt"
	"log"
	"slices"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/agent/client"
	"github.com/lib/pq"
	"gorm.io/gorm"
)

// maxBulkIDs caps the per-request batch size. Keeps regenerate_image bulk
// from accidentally draining a wallet's credits and bounds DB write fanout.
const maxBulkIDs = 100

// bulkActionCost returns the *total* credit cost for running action over n ids.
// Free actions return 0. Unknown actions return 0 too — the dispatcher will
// reject them before this is consulted.
func bulkActionCost(action string, n int) int64 {
	switch action {
	case "regenerate_image":
		return 3 * int64(n)
	default:
		return 0
	}
}

// supportedBulkActions is the closed set of actions BulkAction will dispatch.
// Adding a new action here also requires a handler in the switch below and
// (if it costs credits) an entry in bulkActionCost.
var supportedBulkActions = []string{
	"remove_from_library",
	"tag_add",
	"tag_remove",
	"regenerate_image",
}

// BulkResult is the per-request response envelope.
type BulkResult struct {
	Action       string             `json:"action"`
	Success      []uint             `json:"success"`
	Failures     []BulkFailureEntry `json:"failures"`
	CreditCost   int64              `json:"credit_cost"`
}

// BulkFailureEntry pairs a failed id with its error message so the UI can
// render which agents to retry vs which to drop.
type BulkFailureEntry struct {
	ID    uint   `json:"id"`
	Error string `json:"error"`
}

// ErrBulkTooManyIDs is returned when the request exceeds maxBulkIDs.
var ErrBulkTooManyIDs = fmt.Errorf("too many ids (max %d)", maxBulkIDs)

// ErrBulkUnknownAction is returned when the action label isn't in supportedBulkActions.
var ErrBulkUnknownAction = errors.New("unknown bulk action")

// ErrBulkInsufficientCredits is returned by the quota guard.
var ErrBulkInsufficientCredits = errors.New("insufficient credits for bulk action")

// BulkAction dispatches a single bulk operation across ids. Validation order:
//
//  1. action must be in supportedBulkActions
//  2. ids capped at maxBulkIDs (returns ErrBulkTooManyIDs)
//  3. quota guard (regenerate_image only) — fails the whole request if the
//     wallet can't cover the total cost. Better to fail loud upfront than to
//     half-succeed and surprise the user with a credit deduction.
//
// Per-id errors are aggregated into result.Failures rather than aborting.
//
// payload is action-specific:
//   - tag_add / tag_remove: {"tag": "<single tag>"}
//   - remove_from_library / regenerate_image: ignored
func (s *AgentService) BulkAction(wallet, action string, ids []uint, payload map[string]any) (*BulkResult, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, fmt.Errorf("wallet required")
	}
	if !slices.Contains(supportedBulkActions, action) {
		return nil, ErrBulkUnknownAction
	}
	if len(ids) == 0 {
		// Empty batch is a successful no-op so the UI doesn't have to filter
		// before calling.
		return &BulkResult{Action: action, Success: []uint{}, Failures: []BulkFailureEntry{}}, nil
	}
	if len(ids) > maxBulkIDs {
		return nil, ErrBulkTooManyIDs
	}

	// Quota guard up front — only matters for actions with non-zero cost.
	cost := bulkActionCost(action, len(ids))
	if cost > 0 {
		credits, err := s.GetUserCredits(wallet)
		if err != nil {
			return nil, fmt.Errorf("credit check: %w", err)
		}
		if credits < cost {
			return nil, fmt.Errorf("%w: need %d, have %d",
				ErrBulkInsufficientCredits, cost, credits)
		}
	}

	result := &BulkResult{
		Action:     action,
		Success:    make([]uint, 0, len(ids)),
		Failures:   make([]BulkFailureEntry, 0),
		CreditCost: cost,
	}

	// Dispatch per id. Each handler decides what "success" means for its
	// action; we only collect ids that actually moved state forward.
	for _, id := range ids {
		var err error
		switch action {
		case "remove_from_library":
			err = s.bulkRemoveFromLibrary(wallet, id)
		case "tag_add":
			tag := bulkPayloadTag(payload)
			err = s.bulkTagAdd(wallet, id, tag)
		case "tag_remove":
			tag := bulkPayloadTag(payload)
			err = s.bulkTagRemove(wallet, id, tag)
		case "regenerate_image":
			err = s.bulkRegenerateImage(wallet, id)
		}
		if err != nil {
			result.Failures = append(result.Failures, BulkFailureEntry{
				ID:    id,
				Error: err.Error(),
			})
			continue
		}
		result.Success = append(result.Success, id)
	}
	return result, nil
}

// bulkPayloadTag pulls the "tag" string out of an action payload, trimmed.
// Empty string is a valid signal for "no tag provided" — handlers reject it.
func bulkPayloadTag(payload map[string]any) string {
	if payload == nil {
		return ""
	}
	if v, ok := payload["tag"].(string); ok {
		return strings.TrimSpace(v)
	}
	return ""
}

// bulkRemoveFromLibrary calls the existing library remover so cache-bust /
// save_count clamping logic stays in one place.
func (s *AgentService) bulkRemoveFromLibrary(wallet string, agentID uint) error {
	return s.RemoveFromLibrary(wallet, agentID)
}

// bulkTagAdd appends tag to the agent's tags slice if missing. Owner check
// is mandatory — non-owners get "unauthorized".
func (s *AgentService) bulkTagAdd(wallet string, agentID uint, tag string) error {
	if tag == "" {
		return fmt.Errorf("tag required")
	}
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return fmt.Errorf("agent not found")
	}
	if strings.ToLower(agent.CreatorWallet) != wallet {
		return fmt.Errorf("unauthorized")
	}
	for _, existing := range agent.Tags {
		if strings.EqualFold(existing, tag) {
			return nil // already present — idempotent
		}
	}
	newTags := append(append([]string{}, agent.Tags...), tag)
	if err := database.DB.Model(&agent).
		Update("tags", pq.StringArray(newTags)).Error; err != nil {
		return fmt.Errorf("tag add: %w", err)
	}
	return nil
}

// bulkTagRemove drops tag from the agent's tags slice. Idempotent — a
// missing tag is a successful no-op.
func (s *AgentService) bulkTagRemove(wallet string, agentID uint, tag string) error {
	if tag == "" {
		return fmt.Errorf("tag required")
	}
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return fmt.Errorf("agent not found")
	}
	if strings.ToLower(agent.CreatorWallet) != wallet {
		return fmt.Errorf("unauthorized")
	}
	filtered := make([]string, 0, len(agent.Tags))
	dropped := false
	for _, existing := range agent.Tags {
		if strings.EqualFold(existing, tag) {
			dropped = true
			continue
		}
		filtered = append(filtered, existing)
	}
	if !dropped {
		return nil
	}
	if err := database.DB.Model(&agent).
		Update("tags", pq.StringArray(filtered)).Error; err != nil {
		return fmt.Errorf("tag remove: %w", err)
	}
	return nil
}

// bulkRegenerateImage runs the per-agent regenerate flow. Cooldown errors
// from RegenerateImage propagate through as per-id failures so a partially-
// stale batch still completes for the eligible agents.
//
// When the AI client isn't wired (unit tests with svc.aiClient == nil) we
// skip the heavy network call and exercise the dispatch + ledger path only.
//
// SECURITY (v3.12-P0-2): credits are deducted via deductCredits BEFORE the
// regen runs. The previous implementation wrote a CreditTransaction row with
// Amount=3 but never decremented the wallet balance — users got free
// regenerations and the ledger drifted from `users.credits`.
//
// Policy: cost-bearing prework runs in this order:
//  1. ownership + cooldown check (cheap, fail fast on bad input)
//  2. deductCredits (atomic — also writes the ledger row)
//  3. AI call (heavy, may fail)
//  4. timestamp + image persist
//
// If step 3 fails (AI down, network blip, decode error), we refund the
// 3 credits via appendLedger(+3, "regenerate_image_refund"). Step 4 failures
// also refund. The ledger then carries a balanced spend/refund pair so
// audit trails stay accurate.
func (s *AgentService) bulkRegenerateImage(wallet string, agentID uint) error {
	var agent models.Agent
	if err := database.DB.First(&agent, agentID).Error; err != nil {
		return fmt.Errorf("agent not found")
	}
	if strings.ToLower(agent.CreatorWallet) != wallet {
		return fmt.Errorf("unauthorized")
	}
	if agent.LastImageRegen != nil {
		cooldown := agent.LastImageRegen.Add(24 * time.Hour)
		if time.Now().Before(cooldown) {
			return fmt.Errorf("cooldown active")
		}
	}

	// Deduct 3 credits atomically. This writes both the legacy
	// CreditTransaction row and the structured CreditLedgerEntry, and
	// fails fast if the wallet is short on funds (the per-agent guard
	// that complements the up-front quota check in BulkAction).
	if err := s.deductCredits(wallet, 3, "regenerate_image", &agentID); err != nil {
		return fmt.Errorf("credit deduct: %w", err)
	}
	// Mark whether the heavy work succeeded so we know whether to refund.
	regenSucceeded := false
	defer func() {
		if regenSucceeded {
			return
		}
		// Best-effort refund. Logged on failure but never surfaced —
		// callers already see the original error from the caller path.
		if rerr := s.appendLedger(wallet, 3, "regenerate_image_refund", &agentID, nil, map[string]any{
			"agent_id": agentID,
			"reason":   "regen_failed",
			"bulk":     true,
		}); rerr != nil {
			log.Printf("[bulk] refund failed for wallet %s agent %d: %v", wallet, agentID, rerr)
		}
	}()

	if s.aiClient != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		concept := agent.Title
		if agent.Description != "" {
			concept += ": " + agent.Description
		}
		profile, perr := s.aiClient.Profile(ctx, concept)
		if perr != nil {
			profile = &client.AgentProfile{Name: concept}
		}
		imagePrompt := "A " + agent.CharacterType + " character with unique abilities and tools"
		avatarRes, aerr := s.aiClient.Avatar(ctx, profile, imagePrompt, agent.CharacterType)
		if aerr != nil {
			return fmt.Errorf("avatar generate: %w", aerr)
		}
		generated := ""
		if avatarRes != nil {
			generated = avatarRes.ImageBase64
		}
		s.processAndSaveImage(&agent, generated, avatarRes)
	}

	now := time.Now()
	if err := database.DB.Model(&agent).
		Update("last_image_regen", now).Error; err != nil {
		return fmt.Errorf("timestamp update: %w", err)
	}

	regenSucceeded = true
	return nil
}

// keep gorm import used even if all GORM-using lines later get refactored away
var _ = gorm.ErrRecordNotFound
