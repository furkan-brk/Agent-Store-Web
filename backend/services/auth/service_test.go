package auth

import (
	"strings"
	"testing"
	"time"

	"github.com/agentstore/backend/internal/testutil"
	"github.com/agentstore/backend/pkg/models"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetOrCreateUser_NewWallet(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, _ := testutil.NewWallet(t)
	u, err := svc.GetOrCreateUser(wallet)

	require.NoError(t, err)
	assert.Equal(t, strings.ToLower(wallet), u.WalletAddress)
	assert.EqualValues(t, 100, u.Credits, "new users start with 100 credits")
	assert.NotEmpty(t, u.Nonce)

	var count int64
	db.Model(&models.User{}).Count(&count)
	assert.EqualValues(t, 1, count)
}

func TestGetOrCreateUser_ExistingWallet(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	existing := testutil.NewUser(t, db, "")
	got, err := svc.GetOrCreateUser(existing.WalletAddress)
	require.NoError(t, err)
	assert.Equal(t, existing.WalletAddress, got.WalletAddress)

	var count int64
	db.Model(&models.User{}).Count(&count)
	assert.EqualValues(t, 1, count, "should not duplicate existing user")
}

func TestGetOrCreateUser_LowercasesWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	upper := "0xABCDEF0123456789ABCDEF0123456789ABCDEF01"
	u, err := svc.GetOrCreateUser(upper)
	require.NoError(t, err)
	assert.Equal(t, strings.ToLower(upper), u.WalletAddress)
}

func TestGetNonce_RotatesOnEachCall(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, _ := testutil.NewWallet(t)
	n1, err := svc.GetNonce(wallet)
	require.NoError(t, err)
	n2, err := svc.GetNonce(wallet)
	require.NoError(t, err)

	assert.NotEqual(t, n1, n2, "consecutive nonces must differ")
	assert.Len(t, n1, 32, "16 bytes of hex = 32 chars")
}

func TestVerifySignature_HappyPath(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, priv := testutil.NewWallet(t)
	nonce, err := svc.GetNonce(wallet)
	require.NoError(t, err)

	sig := testutil.SignNonce(t, priv, nonce)
	ok, err := svc.VerifySignature(wallet, nonce, sig)

	require.NoError(t, err)
	assert.True(t, ok)
}

func TestVerifySignature_RotatesNonceOnSuccess(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, priv := testutil.NewWallet(t)
	nonce, _ := svc.GetNonce(wallet)
	sig := testutil.SignNonce(t, priv, nonce)
	_, err := svc.VerifySignature(wallet, nonce, sig)
	require.NoError(t, err)

	var u models.User
	db.Where("wallet_address = ?", strings.ToLower(wallet)).First(&u)
	assert.NotEqual(t, nonce, u.Nonce, "nonce must rotate after successful verify")
}

func TestVerifySignature_NonceMismatch(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, priv := testutil.NewWallet(t)
	_, _ = svc.GetNonce(wallet)
	sig := testutil.SignNonce(t, priv, "bogus-nonce")
	ok, err := svc.VerifySignature(wallet, "bogus-nonce", sig)

	require.Error(t, err)
	assert.False(t, ok)
	assert.Contains(t, err.Error(), "nonce")
}

func TestVerifySignature_WrongSigner(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, _ := testutil.NewWallet(t)
	nonce, _ := svc.GetNonce(wallet)

	// Sign with a DIFFERENT key than the wallet claims.
	_, attacker := testutil.NewWallet(t)
	sig := testutil.SignNonce(t, attacker, nonce)

	ok, err := svc.VerifySignature(wallet, nonce, sig)
	require.NoError(t, err)
	assert.False(t, ok, "signature from wrong key must not verify")
}

func TestVerifySignature_UnknownWallet(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, priv := testutil.NewWallet(t)
	// No GetNonce call — wallet was never persisted.
	sig := testutil.SignNonce(t, priv, "any")

	ok, err := svc.VerifySignature(wallet, "any", sig)
	require.Error(t, err)
	assert.False(t, ok)
	assert.Contains(t, err.Error(), "user not found")
}

// v3.7-8.2 — failure paths must invalidate the stored nonce so a leaked
// or sniffed value can't be replayed by retrying with the same nonce.
func TestVerifySignature_FailureInvalidatesNonce(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, priv := testutil.NewWallet(t)
	nonce, _ := svc.GetNonce(wallet)

	// Wrong signer → false, no error, but nonce should rotate.
	_, attacker := testutil.NewWallet(t)
	badSig := testutil.SignNonce(t, attacker, nonce)
	ok, err := svc.VerifySignature(wallet, nonce, badSig)
	require.NoError(t, err)
	assert.False(t, ok)

	var u models.User
	require.NoError(t, db.Where("wallet_address = ?", strings.ToLower(wallet)).First(&u).Error)
	assert.NotEqual(t, nonce, u.Nonce, "nonce must rotate after failed verify")

	// Replay attempt with the original nonce + valid signer must now fail
	// because the stored nonce has changed.
	goodSig := testutil.SignNonce(t, priv, nonce)
	ok, err = svc.VerifySignature(wallet, nonce, goodSig)
	require.Error(t, err)
	assert.False(t, ok, "stale nonce can't be re-used after a failed verify")
}

func TestVerifySignature_NonceMismatchInvalidatesNonce(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, priv := testutil.NewWallet(t)
	_, _ = svc.GetNonce(wallet)

	var before models.User
	db.Where("wallet_address = ?", strings.ToLower(wallet)).First(&before)

	// Caller sends a stale/garbage nonce.
	sig := testutil.SignNonce(t, priv, "stale-value")
	ok, err := svc.VerifySignature(wallet, "stale-value", sig)
	require.Error(t, err)
	assert.False(t, ok)

	var after models.User
	db.Where("wallet_address = ?", strings.ToLower(wallet)).First(&after)
	assert.NotEqual(t, before.Nonce, after.Nonce, "mismatch must rotate stored nonce")
}

func TestAbandon_InvalidatesNonce(t *testing.T) {
	db := testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, _ := testutil.NewWallet(t)
	nonce, _ := svc.GetNonce(wallet)

	require.NoError(t, svc.Abandon(wallet))

	var u models.User
	db.Where("wallet_address = ?", strings.ToLower(wallet)).First(&u)
	assert.NotEqual(t, nonce, u.Nonce, "Abandon must rotate stored nonce")
}

func TestAbandon_UnknownWalletNoError(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, _ := testutil.NewWallet(t)
	// Never called GetNonce → wallet not persisted.
	require.NoError(t, svc.Abandon(wallet), "Abandon on unknown wallet is a silent no-op")
}

func TestVerifySignature_MalformedSignature(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret")

	wallet, _ := testutil.NewWallet(t)
	nonce, _ := svc.GetNonce(wallet)

	cases := []string{
		"",                           // empty
		"0x123",                      // too short
		"not-hex",                    // not hex
		"0x" + strings.Repeat("a", 130), // hex but wrong length
	}
	for _, sig := range cases {
		t.Run(sig, func(t *testing.T) {
			ok, err := svc.VerifySignature(wallet, nonce, sig)
			require.Error(t, err)
			assert.False(t, ok)
		})
	}
}

func TestGenerateJWT_ContainsWalletAndExpiry(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("test-secret-key")

	wallet, _ := testutil.NewWallet(t)
	tokenStr, err := svc.GenerateJWT(wallet)
	require.NoError(t, err)
	assert.NotEmpty(t, tokenStr)

	parsed, err := jwt.Parse(tokenStr, func(*jwt.Token) (interface{}, error) {
		return []byte("test-secret-key"), nil
	})
	require.NoError(t, err)
	require.True(t, parsed.Valid)

	claims, ok := parsed.Claims.(jwt.MapClaims)
	require.True(t, ok)
	assert.Equal(t, strings.ToLower(wallet), claims["wallet"])

	exp, ok := claims["exp"].(float64)
	require.True(t, ok)
	assert.InDelta(t, time.Now().Add(24*time.Hour).Unix(), int64(exp), 5)
}

func TestGenerateJWT_RejectsWrongSecret(t *testing.T) {
	testutil.NewTestDB(t)
	svc := NewAuthService("real-secret")

	wallet, _ := testutil.NewWallet(t)
	tokenStr, _ := svc.GenerateJWT(wallet)

	_, err := jwt.Parse(tokenStr, func(*jwt.Token) (interface{}, error) {
		return []byte("wrong-secret"), nil
	})
	require.Error(t, err)
}
