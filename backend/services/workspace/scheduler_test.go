package workspace

// scheduler_test.go — covers v3.11.4 mission cron scheduling.

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newSchedulerSvc(t *testing.T) *LegendService {
	t.Helper()
	testutil.NewTestDB(t)
	return NewLegendService(nil, nil, nil, nil)
}

func seedMissionForSchedule(t *testing.T, wallet string) uint {
	t.Helper()
	row := models.UserMission{
		UserWallet: wallet, ClientID: "m1", Title: "Test Mission",
		Slug: "test-mission", Prompt: "do x",
	}
	require.NoError(t, database.DB.Create(&row).Error)
	return row.ID
}

func TestSetSchedule_RejectsInvalidCron(t *testing.T) {
	svc := newSchedulerSvc(t)
	mid := seedMissionForSchedule(t, "0xowner")

	_, err := svc.SetSchedule("0xowner", mid, ScheduleInput{CronExpr: "not-a-cron"})
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrScheduleInvalidCron)
}

func TestSetSchedule_RejectsForeignWallet(t *testing.T) {
	svc := newSchedulerSvc(t)
	mid := seedMissionForSchedule(t, "0xowner")

	_, err := svc.SetSchedule("0xstranger", mid, ScheduleInput{CronExpr: "0 9 * * *"})
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrScheduleMissionNotFound)
}

func TestSetSchedule_UpsertsAndComputesNextRun(t *testing.T) {
	svc := newSchedulerSvc(t)
	mid := seedMissionForSchedule(t, "0xowner")

	// First call: creates row.
	row, err := svc.SetSchedule("0xowner", mid, ScheduleInput{CronExpr: "0 9 * * *"})
	require.NoError(t, err)
	require.NotNil(t, row)
	assert.True(t, row.NextRunAt.After(time.Now()), "NextRunAt should be in the future")
	assert.True(t, row.Enabled)

	// Second call: updates the same row (composite unique).
	disabled := false
	updated, err := svc.SetSchedule("0xowner", mid, ScheduleInput{
		CronExpr: "0 18 * * *", Enabled: &disabled,
	})
	require.NoError(t, err)
	assert.Equal(t, row.ID, updated.ID, "same DB row, just patched")
	assert.False(t, updated.Enabled)
	assert.Equal(t, "0 18 * * *", updated.CronExpr)
}

func TestRunDueSchedules_FiresOverdueRowsAndAdvancesNextRun(t *testing.T) {
	svc := newSchedulerSvc(t)
	mid := seedMissionForSchedule(t, "0xowner")

	// Manually craft an overdue schedule (NextRunAt in the past).
	past := time.Now().Add(-1 * time.Hour)
	require.NoError(t, database.DB.Create(&models.MissionSchedule{
		MissionID: mid, Wallet: "0xowner", CronExpr: "0 9 * * *",
		NextRunAt: past, Enabled: true,
	}).Error)

	fired := svc.RunDueSchedules()
	assert.GreaterOrEqual(t, fired, 1, "at least one row should fire")

	// LastRunAt stamped, NextRunAt advanced.
	var sched models.MissionSchedule
	require.NoError(t, database.DB.Where("mission_id = ?", mid).First(&sched).Error)
	require.NotNil(t, sched.LastRunAt)
	assert.True(t, sched.NextRunAt.After(time.Now()), "NextRunAt should be re-computed forward")

	// Activity marker inserted.
	var n int64
	database.DB.Model(&models.UserActivity{}).
		Where("type = ? AND ref_id = ?", "mission_schedule_fired", mid).Count(&n)
	assert.EqualValues(t, 1, n)
}
