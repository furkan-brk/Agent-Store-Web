package workspace

// mission_slug_test.go — v3.12 P1-3 regression: the (wallet, slug) unique
// index plus the CreateMissionWithUniqueSlug helper must reject duplicate
// inserts at DB level, instead of relying on the racy ensureUniqueSlug
// SELECT-then-Create flow.

import (
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// CreateMissionWithUniqueSlug must succeed on first try when slug is free.
func TestCreateMissionWithUniqueSlug_FreshSlug(t *testing.T) {
	testutil.NewTestDB(t)

	m := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "c1",
		Title:      "First",
		Slug:       "first-mission",
		Prompt:     "do a thing",
		CreatedAt:  time.Now(),
	}
	require.NoError(t, CreateMissionWithUniqueSlug(database.DB, m))
	assert.Equal(t, "first-mission", m.Slug, "fresh slug must not be mutated")
	assert.NotZero(t, m.ID)
}

// On a (wallet, slug) collision the helper must bump the suffix and retry,
// landing as slug_2.
func TestCreateMissionWithUniqueSlug_BumpsOnCollision(t *testing.T) {
	testutil.NewTestDB(t)

	// Plant a mission that owns the desired slug.
	planted := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "c1",
		Title:      "Original",
		Slug:       "shared-slug",
		Prompt:     "x",
		CreatedAt:  time.Now(),
	}
	require.NoError(t, database.DB.Create(planted).Error)

	// Insert another row for the same wallet with the same desired slug.
	collider := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "c2",
		Title:      "Imported",
		Slug:       "shared-slug",
		Prompt:     "y",
		CreatedAt:  time.Now(),
	}
	require.NoError(t, CreateMissionWithUniqueSlug(database.DB, collider))
	assert.Equal(t, "shared-slug_2", collider.Slug, "first retry must use _2 suffix")
	assert.NotZero(t, collider.ID)
	assert.NotEqual(t, planted.ID, collider.ID)
}

// Different wallets must be allowed to share the same slug — the unique index
// is composite on (wallet, slug), not slug alone.
func TestCreateMissionWithUniqueSlug_DifferentWalletsCanShareSlug(t *testing.T) {
	testutil.NewTestDB(t)

	a := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "ca",
		Title:      "A",
		Slug:       "shared",
		Prompt:     "p",
		CreatedAt:  time.Now(),
	}
	b := &models.UserMission{
		UserWallet: "0xdef",
		ClientID:   "cb",
		Title:      "B",
		Slug:       "shared",
		Prompt:     "p",
		CreatedAt:  time.Now(),
	}
	require.NoError(t, CreateMissionWithUniqueSlug(database.DB, a))
	require.NoError(t, CreateMissionWithUniqueSlug(database.DB, b))
	assert.Equal(t, "shared", a.Slug)
	assert.Equal(t, "shared", b.Slug, "different wallet must keep original slug")
}

// Cascading collisions (slug, slug_2) must skip ahead to slug_3.
func TestCreateMissionWithUniqueSlug_CascadingCollisions(t *testing.T) {
	testutil.NewTestDB(t)

	for _, s := range []string{"x", "x_2"} {
		require.NoError(t, database.DB.Create(&models.UserMission{
			UserWallet: "0xabc",
			ClientID:   "client-" + s,
			Title:      "T",
			Slug:       s,
			Prompt:     "p",
			CreatedAt:  time.Now(),
		}).Error)
	}

	m := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "fresh",
		Title:      "T",
		Slug:       "x",
		Prompt:     "p",
		CreatedAt:  time.Now(),
	}
	require.NoError(t, CreateMissionWithUniqueSlug(database.DB, m))
	assert.Equal(t, "x_3", m.Slug, "two collisions must skip to suffix _3")
}

// The (wallet, slug) unique index must be installed by AutoMigrate and reject
// a manual duplicate insert at DB level — this is what backstops the helper.
func TestUserMission_WalletSlugUniqueIndex(t *testing.T) {
	testutil.NewTestDB(t)

	first := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "c1",
		Title:      "First",
		Slug:       "dup",
		Prompt:     "p",
		CreatedAt:  time.Now(),
	}
	require.NoError(t, database.DB.Create(first).Error)

	dup := &models.UserMission{
		UserWallet: "0xabc",
		ClientID:   "c2",
		Title:      "Dup",
		Slug:       "dup",
		Prompt:     "p",
		CreatedAt:  time.Now(),
	}
	err := database.DB.Create(dup).Error
	require.Error(t, err, "DB must reject duplicate (wallet, slug)")
	assert.True(t, isUniqueSlugViolation(err), "error must look like a unique-slug violation")
}
