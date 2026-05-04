package testutil

import (
	"crypto/ecdsa"
	"fmt"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/agentstore/backend/pkg/models"
	"github.com/ethereum/go-ethereum/crypto"
	"gorm.io/gorm"
)

var agentCounter int64

// NewWallet generates a fresh ECDSA keypair and returns the lowercase
// 0x-prefixed Ethereum address along with the private key. Tests use the
// private key to sign nonces in auth flow tests.
func NewWallet(t *testing.T) (string, *ecdsa.PrivateKey) {
	t.Helper()
	priv, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("testutil: generate key: %v", err)
	}
	addr := strings.ToLower(crypto.PubkeyToAddress(priv.PublicKey).Hex())
	return addr, priv
}

// NewUser inserts a User row with the given wallet (or a fresh one if empty)
// and 100 starting credits. Returns the persisted user.
func NewUser(t *testing.T, db *gorm.DB, wallet string) *models.User {
	t.Helper()
	if wallet == "" {
		wallet, _ = NewWallet(t)
	}
	u := &models.User{
		WalletAddress: strings.ToLower(wallet),
		Nonce:         "test-nonce",
		Credits:       100,
	}
	if err := db.Create(u).Error; err != nil {
		t.Fatalf("testutil: create user: %v", err)
	}
	return u
}

// NewAgent inserts an Agent row with sensible defaults. Optional overrides
// can be applied via mutator funcs before persisting (e.g. set Category,
// CreatorWallet).
func NewAgent(t *testing.T, db *gorm.DB, mut ...func(*models.Agent)) *models.Agent {
	t.Helper()
	n := atomic.AddInt64(&agentCounter, 1)
	a := &models.Agent{
		Title:         fmt.Sprintf("Test Agent %d", n),
		Description:   "test description",
		Prompt:        "You are a test agent.",
		Category:      "general",
		CreatorWallet: "0xtest",
		CharacterType: "wizard",
		Subclass:      "",
		CharacterData: `{"stats":{},"traits":[]}`,
		Rarity:        models.RarityCommon,
		UseCount:      0,
		SaveCount:     0,
		Price:         0,
	}
	for _, f := range mut {
		f(a)
	}
	if err := db.Create(a).Error; err != nil {
		t.Fatalf("testutil: create agent: %v", err)
	}
	return a
}

// AddToLibrary creates a LibraryEntry linking wallet → agent.
func AddToLibrary(t *testing.T, db *gorm.DB, wallet string, agentID uint) *models.LibraryEntry {
	t.Helper()
	e := &models.LibraryEntry{
		UserWallet: strings.ToLower(wallet),
		AgentID:    agentID,
	}
	if err := db.Create(e).Error; err != nil {
		t.Fatalf("testutil: create library entry: %v", err)
	}
	return e
}
