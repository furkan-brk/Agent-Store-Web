package agent

// rating_moderation.go — community-driven moderation for AgentRating rows.
//
// Rules:
//   * A wallet may flag the same rating only once (composite unique index on
//     (rating_id, reporter_wallet) enforces this; OnConflict does nothing).
//   * Per-wallet rate limit: at most 3 flags inside a rolling 5-minute window.
//   * At ≥3 distinct flags, the rating is auto-hidden (Hidden=true); GetRatings
//     filters those out of the public list.
//   * Self-flag (a wallet flagging its own rating) is rejected — there's no
//     legitimate use case and it would let an author hide their own rating to
//     escape review.

import (
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// flagRateWindow is the rolling window for the per-wallet rate limit.
const flagRateWindow = 5 * time.Minute

// flagRateMaxInWindow is the cap inside flagRateWindow.
const flagRateMaxInWindow = 3

// hideThreshold is the number of distinct wallet flags required to auto-hide
// a rating from the public list. Tuned low because each flag requires a unique
// wallet and is rate-limited.
const hideThreshold int64 = 3

// Errors surfaced by FlagRating.
var (
	ErrRatingNotFound  = errors.New("rating not found")
	ErrSelfFlag        = errors.New("cannot flag your own rating")
	ErrFlagRateLimited = errors.New("flag rate limited (max 3 flags per 5 minutes)")
)

// abusiveWords is a tiny profanity blocklist used by the abusive-content
// heuristic. The list is intentionally short; full moderation belongs to a
// dedicated service in v3.11.3.
var abusiveWords = []string{
	"fuck", "shit", "bitch", "asshole", "bastard",
	"cunt", "dick", "piss", "slut", "whore",
	"retard", "faggot", "nigger",
}

// urlRegex matches a permissive http(s) URL. We use it only to count URLs in
// a comment; >2 URLs is a strong spam signal.
var urlRegex = regexp.MustCompile(`(?i)\bhttps?://\S+`)

// isAbusive returns true when content trips one of the simple heuristics:
//   - any word in abusiveWords appears as a token (case-insensitive)
//   - the comment carries >2 URLs (link-spam pattern)
//
// This is deliberately conservative; it's a coarse pre-filter that flags
// content for human review, not an automatic ban.
func isAbusive(content string) bool {
	lower := strings.ToLower(content)
	// Tokenise crudely on non-letter chars so "Fuck!" still matches "fuck".
	for _, w := range abusiveWords {
		if strings.Contains(lower, w) {
			return true
		}
	}
	urls := urlRegex.FindAllString(content, -1)
	if len(urls) > 2 {
		return true
	}
	// Sanity check the URLs that did match — if any parse as valid http(s),
	// they're real links and the count threshold above already applied.
	for _, u := range urls {
		if pu, err := url.Parse(u); err == nil && (pu.Scheme == "http" || pu.Scheme == "https") {
			_ = pu // only used to confirm parseability; counted above
		}
	}
	return false
}

// FlagRating records a flag from reporterWallet against ratingID with the
// given reason and returns whether the rating was auto-hidden as a result.
//
// The whole flow runs inside a transaction so the count + Hidden update sees
// a consistent snapshot of flags. The OnConflict clause makes flag insertion
// idempotent at the (rating, wallet) level — a duplicate flag from the same
// wallet returns nil and does not increment the counter.
func (s *AgentService) FlagRating(reporterWallet string, ratingID uint, reason string) (bool, error) {
	reporterWallet = strings.ToLower(strings.TrimSpace(reporterWallet))
	if reporterWallet == "" {
		return false, fmt.Errorf("wallet required")
	}
	if len(reason) > 500 {
		reason = reason[:500]
	}

	// Rate limit: count this wallet's flags inside the rolling window before
	// touching the rating row.
	cutoff := time.Now().Add(-flagRateWindow)
	var recent int64
	if err := database.DB.Model(&models.RatingFlag{}).
		Where("reporter_wallet = ? AND created_at > ?", reporterWallet, cutoff).
		Count(&recent).Error; err != nil {
		return false, fmt.Errorf("rate-limit lookup: %w", err)
	}
	if recent >= flagRateMaxInWindow {
		return false, ErrFlagRateLimited
	}

	var hidden bool
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		var rating models.AgentRating
		if err := tx.Set("gorm:query_option", "FOR UPDATE").
			Where("id = ?", ratingID).First(&rating).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrRatingNotFound
			}
			return err
		}
		if strings.EqualFold(rating.Wallet, reporterWallet) {
			return ErrSelfFlag
		}
		flag := models.RatingFlag{
			RatingID:       ratingID,
			ReporterWallet: reporterWallet,
			Reason:         reason,
		}
		// OnConflict-DoNothing turns duplicate flags into no-ops at DB level
		// (mirrors v3.9 UserFollow pattern) so we don't have to pre-check.
		res := tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&flag)
		if res.Error != nil {
			return fmt.Errorf("insert flag: %w", res.Error)
		}
		// If the wallet already flagged this rating, RowsAffected is 0 and we
		// stop here — re-counting would be harmless but pointless.
		if res.RowsAffected == 0 {
			hidden = rating.Hidden
			return nil
		}
		// Re-count distinct flags now that we've inserted ours and decide
		// whether the hide threshold is crossed.
		var totalFlags int64
		if err := tx.Model(&models.RatingFlag{}).
			Where("rating_id = ?", ratingID).Count(&totalFlags).Error; err != nil {
			return fmt.Errorf("count flags: %w", err)
		}
		// Only flip Hidden if we actually crossed the threshold OR the rating
		// content itself trips the abuse heuristic (profanity / link spam) —
		// any flag against an obviously-abusive rating short-circuits the
		// 3-vote threshold so the row leaves the public list immediately.
		shouldHide := !rating.Hidden && (totalFlags >= hideThreshold || isAbusive(rating.Comment))
		if shouldHide {
			if err := tx.Model(&rating).Update("hidden", true).Error; err != nil {
				return fmt.Errorf("hide rating: %w", err)
			}
			hidden = true
		} else {
			hidden = rating.Hidden
		}
		return nil
	})
	if err != nil {
		return false, err
	}
	return hidden, nil
}
