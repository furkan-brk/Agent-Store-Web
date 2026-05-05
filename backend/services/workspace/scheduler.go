package workspace

// scheduler.go — cron-driven mission re-runs.
//
// SetSchedule parses + validates a 5-field cron expression and computes
// NextRunAt. RunDueSchedules is called on a 60-second tick from the
// monolith's background goroutine; it picks up rows where NextRunAt <= now
// and inserts a UserActivity marker (the v3.11.4 stand-in for actual
// mission execution).
//
// The standalone workspacesvc binary doesn't run the goroutine — only the
// monolith owns the tick loop. The model + endpoints are still functional
// in svc mode; rows just won't fire automatically.

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/robfig/cron/v3"
	"gorm.io/gorm"
)

// cronParser is the standard 5-field parser shared across SetSchedule and
// RunDueSchedules so they always agree on what's valid.
var cronParser = cron.NewParser(
	cron.Minute | cron.Hour | cron.Dom | cron.Month | cron.Dow,
)

// ScheduleInput is the payload accepted by SetSchedule.
type ScheduleInput struct {
	CronExpr string `json:"cron"`
	Enabled  *bool  `json:"enabled,omitempty"`
}

// ErrScheduleInvalidCron is returned by SetSchedule when the cron string fails parsing.
var ErrScheduleInvalidCron = errors.New("invalid cron expression")

// ErrScheduleMissionNotFound is returned when the mission doesn't exist or
// belongs to a different wallet.
var ErrScheduleMissionNotFound = errors.New("mission not found")

// SetSchedule upserts a MissionSchedule row for the (mission, wallet) pair.
// Validates the mission ownership and the cron expression before any DB
// write. NextRunAt is computed from the parsed schedule.
func (s *LegendService) SetSchedule(wallet string, missionID uint, input ScheduleInput) (*models.MissionSchedule, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || missionID == 0 {
		return nil, errors.New("wallet and missionID required")
	}
	cronExpr := strings.TrimSpace(input.CronExpr)
	if cronExpr == "" {
		return nil, ErrScheduleInvalidCron
	}
	sched, err := cronParser.Parse(cronExpr)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrScheduleInvalidCron, err)
	}

	// Verify mission exists and is owned by the wallet.
	var mission models.UserMission
	if err := database.DB.Where("id = ? AND user_wallet = ?", missionID, wallet).First(&mission).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrScheduleMissionNotFound
		}
		return nil, err
	}

	enabled := true
	if input.Enabled != nil {
		enabled = *input.Enabled
	}

	now := time.Now()
	row := models.MissionSchedule{
		MissionID: missionID,
		Wallet:    wallet,
		CronExpr:  cronExpr,
		NextRunAt: sched.Next(now),
		Enabled:   enabled,
	}

	// Upsert via update-or-create (composite unique covers the dedup).
	var existing models.MissionSchedule
	err = database.DB.
		Where("mission_id = ? AND wallet = ?", missionID, wallet).
		First(&existing).Error
	if err == nil {
		// Patch in place so foreign keys / created_at survive.
		existing.CronExpr = cronExpr
		existing.NextRunAt = row.NextRunAt
		existing.Enabled = enabled
		if err := database.DB.Save(&existing).Error; err != nil {
			return nil, err
		}
		return &existing, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if err := database.DB.Create(&row).Error; err != nil {
		return nil, err
	}
	return &row, nil
}

// RemoveSchedule hard-deletes the row. (Soft-disable path is via SetSchedule
// with Enabled=false.)
func (s *LegendService) RemoveSchedule(wallet string, missionID uint) error {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" || missionID == 0 {
		return errors.New("wallet and missionID required")
	}
	res := database.DB.Where("mission_id = ? AND wallet = ?", missionID, wallet).
		Delete(&models.MissionSchedule{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrScheduleMissionNotFound
	}
	return nil
}

// ListSchedules returns all schedules belonging to the wallet, newest first.
func (s *LegendService) ListSchedules(wallet string) ([]models.MissionSchedule, error) {
	wallet = strings.ToLower(strings.TrimSpace(wallet))
	if wallet == "" {
		return nil, errors.New("wallet required")
	}
	var rows []models.MissionSchedule
	err := database.DB.Where("wallet = ?", wallet).
		Order("id DESC").Find(&rows).Error
	return rows, err
}

// MissionExpander is the cross-package contract LegendService uses to
// resolve #slug references in a mission's prompt. v3.11.5 wires
// MissionService.ExpandMissionTags as the implementation.
//
// Splitting via interface keeps RunDueSchedules unit-testable without a
// concrete MissionService instance and lets the standalone workspacesvc
// binary skip wiring entirely (returns marker-only results).
type MissionExpander interface {
	ExpandMissionTags(wallet, text string) (*ExpandMissionOutput, error)
}

// SetMissionExpander installs the v3.11.5 expander — call once at boot
// from the monolith with the same MissionService instance used by handlers.
// Test code can pass a stub that returns a deterministic expanded body.
func (s *LegendService) SetMissionExpander(e MissionExpander) {
	s.missionExpander = e
}

// RunDueSchedules picks rows where NextRunAt has passed and Enabled is true,
// then for each:
//   * recompute NextRunAt via the cron parser
//   * stamp LastRunAt = now
//   * v3.11.5: load the mission, expand its prompt via MissionExpander,
//     and persist a MissionRun row with the expanded prompt + any error
//   * insert a UserActivity "mission_schedule_fired" marker (kept for the
//     funnel queries that rely on it)
//
// Returns the count of rows that fired so the caller can log it. Errors
// inside the per-row loop are logged but don't abort the batch — one bad
// schedule shouldn't take the whole tick down.
func (s *LegendService) RunDueSchedules() int {
	if database.DB == nil {
		return 0
	}
	now := time.Now()
	var due []models.MissionSchedule
	if err := database.DB.Where("enabled = ? AND next_run_at <= ?", true, now).
		Find(&due).Error; err != nil {
		return 0
	}
	fired := 0
	for _, sched := range due {
		parsed, err := cronParser.Parse(sched.CronExpr)
		if err != nil {
			// Bad row — disable so it doesn't keep tripping every tick.
			database.DB.Model(&sched).Update("enabled", false)
			continue
		}
		next := parsed.Next(now)
		ts := now
		// v3.12 P1-4: atomic CAS on next_run_at so multi-replica deploys can't
		// fire the same schedule twice. The WHERE clause includes the OLD
		// next_run_at value we read; if another replica already advanced the
		// row, RowsAffected == 0 and we silently skip the rest of the per-row
		// work (mission run + activity marker). The single winner proceeds.
		res := database.DB.Model(&models.MissionSchedule{}).
			Where("id = ? AND next_run_at = ?", sched.ID, sched.NextRunAt).
			Updates(map[string]any{
				"next_run_at": next,
				"last_run_at": ts,
			})
		if res.Error != nil {
			continue
		}
		if res.RowsAffected != 1 {
			// Another replica won the CAS — skip silently.
			continue
		}

		// v3.11.5: real execution — load + expand the mission, persist
		// a MissionRun row capturing what the schedule produced.
		runRow := models.MissionRun{
			MissionID: sched.MissionID,
			Wallet:    sched.Wallet,
			Source:    "schedule",
		}
		var mission models.UserMission
		if mErr := database.DB.Where("id = ? AND user_wallet = ?", sched.MissionID, sched.Wallet).First(&mission).Error; mErr != nil {
			runRow.Error = "mission not found"
		} else if s.missionExpander != nil {
			out, eErr := s.missionExpander.ExpandMissionTags(sched.Wallet, mission.Prompt)
			if eErr != nil {
				runRow.Error = eErr.Error()
				runRow.ExpandedPrompt = mission.Prompt // fall back to raw
			} else {
				runRow.ExpandedPrompt = out.ExpandedText
			}
		} else {
			// No expander wired (standalone svc binary) → store the raw prompt.
			runRow.ExpandedPrompt = mission.Prompt
		}
		_ = database.DB.Create(&runRow).Error

		// Marker activity row — kept so the funnel + activity-feed queries
		// that already filter on `mission_schedule_fired` keep working.
		_ = database.DB.Create(&models.UserActivity{
			Wallet: sched.Wallet,
			Type:   "mission_schedule_fired",
			RefID:  sched.MissionID,
		}).Error
		fired++
	}
	return fired
}

// ListMissionRuns returns the most recent runs for a mission, newest first.
// Used by the FE schedule history dialog. limit caps at 50.
func (s *LegendService) ListMissionRuns(wallet string, missionID uint, limit int) ([]models.MissionRun, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	var rows []models.MissionRun
	err := database.DB.Where("mission_id = ? AND wallet = ?", missionID, strings.ToLower(strings.TrimSpace(wallet))).
		Order("id DESC").Limit(limit).Find(&rows).Error
	return rows, err
}
