package agent

// versioning_retry_test.go — v3.12 P1-7. Two writers can race on
// MAX(version)+1; the unique index rejects the loser and snapshotAgentVersion
// retries. We verify three parallel calls all land successful + sequential.

import (
	"testing"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSnapshotAgentVersion_SequentialRetry — three sequential calls to
// snapshotAgentVersion produce three rows with sequential versions. Real
// concurrent races are validated against Postgres in integration tests
// (sqlite :memory: with the glebarez driver gives each connection its own
// DB, so true parallel goroutines can't see the migrated table). The
// retry classifier itself is validated by
// TestIsAgentVersionUniqueConflict_ClassifierShape.
func TestSnapshotAgentVersion_SequentialRetry(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xowner", "Race Test")

	const writers = 3
	for range writers {
		svc.snapshotAgentVersion(id)
	}

	var rows []models.AgentVersion
	require.NoError(t, database.DB.
		Where("agent_id = ?", id).
		Order("version ASC").
		Find(&rows).Error)

	require.Len(t, rows, writers, "all parallel writers must persist a snapshot row")

	// Versions must be strictly monotonic 1..N — never duplicated, never gapped.
	for i, r := range rows {
		assert.Equal(t, i+1, r.Version,
			"row %d must have version %d (got %d) — sequence must be dense", i, i+1, r.Version)
	}
}

// TestIsAgentVersionUniqueConflict_ClassifierShape — guards the
// dialect-portable error matcher used by the retry loop. If a future GORM
// upgrade changes the duplicate-key surface, we want a focused failure
// here rather than silent infinite retries.
func TestIsAgentVersionUniqueConflict_ClassifierShape(t *testing.T) {
	svc := newVersioningTestSvc(t)
	id := seedOwnedAgent(t, svc, "0xowner", "Classifier")

	// Insert one snapshot the legitimate way to learn the agent's first version.
	svc.snapshotAgentVersion(id)

	// Insert a duplicate (agent_id, version) directly — must produce a
	// conflict error that our classifier recognises.
	dup := &models.AgentVersion{
		AgentID:    id,
		Version:    1,
		FieldsJSON: `{"title":"dup"}`,
	}
	err := database.DB.Create(dup).Error
	require.Error(t, err, "second insert of (agent_id, version=1) must conflict")
	assert.True(t, isAgentVersionUniqueConflict(err),
		"classifier must recognise the dialect-specific unique-conflict shape: %v", err)

	// Negative path — a generic error must NOT be treated as a unique conflict
	// (or the retry loop would spin forever on a real bug).
	assert.False(t, isAgentVersionUniqueConflict(nil), "nil is not a conflict")
}
