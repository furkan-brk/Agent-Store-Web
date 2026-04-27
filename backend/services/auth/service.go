package auth

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/models"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/golang-jwt/jwt/v5"
)

// AuthService handles wallet-based authentication: nonce generation,
// Ethereum personal_sign verification, and JWT issuance.
type AuthService struct {
	jwtSecret string
}

// NewAuthService creates an AuthService with the given JWT signing secret.
func NewAuthService(secret string) *AuthService {
	return &AuthService{jwtSecret: secret}
}

// GetOrCreateUser returns the user for the given wallet, creating one if needed.
func (s *AuthService) GetOrCreateUser(wallet string) (*models.User, error) {
	wallet = strings.ToLower(wallet)
	var user models.User
	if err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
		nonce, _ := generateNonce()
		user = models.User{WalletAddress: wallet, Nonce: nonce, Credits: 100}
		if err := database.DB.Create(&user).Error; err != nil {
			return nil, err
		}
	}
	return &user, nil
}

// GetNonce generates a fresh nonce for the given wallet and persists it.
func (s *AuthService) GetNonce(wallet string) (string, error) {
	user, err := s.GetOrCreateUser(wallet)
	if err != nil {
		return "", err
	}
	nonce, _ := generateNonce()
	if err := database.DB.Model(user).Update("nonce", nonce).Error; err != nil {
		return "", fmt.Errorf("failed to save nonce: %w", err)
	}
	return nonce, nil
}

// VerifySignature validates an Ethereum personal_sign signature against the
// stored nonce and rotates the nonce on every outcome to prevent replay
// attacks and stale-nonce reuse across browser tabs (v3.7-8.2).
//
// On any failure path (mismatched nonce, malformed signature, recovery
// error, or recovered address mismatch), the stored nonce is invalidated
// — replaced with a fresh one — so a leaked or partial signature can't be
// retried. The caller (frontend) must request a new nonce before retrying.
func (s *AuthService) VerifySignature(wallet, nonce, signature string) (bool, error) {
	wallet = strings.ToLower(wallet)
	var user models.User
	if err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
		return false, errors.New("user not found")
	}
	log.Printf("[AUTH] verify wallet=%s nonce_db=%s nonce_req=%s", wallet, user.Nonce, nonce)
	if user.Nonce != nonce {
		log.Printf("[AUTH] FAIL nonce mismatch: db=%q req=%q", user.Nonce, nonce)
		// Invalidate the stored nonce too — a mismatch likely means the
		// caller sees a stale value, and we don't want either side to
		// keep believing the old one is valid.
		s.invalidateNonce(&user)
		return false, errors.New("nonce mismatch")
	}
	// Construct the same human-readable message the frontend signs.
	signable := fmt.Sprintf("Sign in to Agent Store\n\nNonce: %s", nonce)
	msg := fmt.Sprintf("\x19Ethereum Signed Message:\n%d%s", len(signable), signable)
	hash := crypto.Keccak256Hash([]byte(msg))
	sigBytes, err := hex.DecodeString(strings.TrimPrefix(signature, "0x"))
	if err != nil || len(sigBytes) != 65 {
		log.Printf("[AUTH] FAIL invalid signature: len=%d err=%v", len(sigBytes), err)
		s.invalidateNonce(&user)
		return false, errors.New("invalid signature")
	}
	if sigBytes[64] >= 27 {
		sigBytes[64] -= 27
	}
	pubKey, err := crypto.SigToPub(hash.Bytes(), sigBytes)
	if err != nil {
		log.Printf("[AUTH] FAIL SigToPub err=%v", err)
		s.invalidateNonce(&user)
		return false, err
	}
	recovered := crypto.PubkeyToAddress(*pubKey)
	expected := common.HexToAddress(wallet)
	match := strings.EqualFold(recovered.Hex(), expected.Hex())
	log.Printf("[AUTH] recovered=%s expected=%s match=%v msg_len=%d", recovered.Hex(), expected.Hex(), match, len(signable))

	// Rotate nonce on both success AND failure so the prior nonce can never
	// be re-used. Frontend must call /auth/nonce again to retry.
	s.invalidateNonce(&user)

	return match, nil
}

// Abandon invalidates the stored nonce for [wallet] without verifying any
// signature. Frontend calls this when the user dismisses the MetaMask
// signature popup, so a subsequent retry can't accidentally replay a
// leaked or sniffed in-flight nonce. No-op if the wallet doesn't exist
// (we don't want to leak existence via this endpoint).
func (s *AuthService) Abandon(wallet string) error {
	wallet = strings.ToLower(wallet)
	var user models.User
	if err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
		// Silently succeed for unknown wallets — see comment above.
		return nil
	}
	s.invalidateNonce(&user)
	return nil
}

// invalidateNonce rotates the stored nonce on the user row. Returns the
// new nonce (not used by callers today, but useful for future debug
// logging or test assertions).
func (s *AuthService) invalidateNonce(user *models.User) string {
	newNonce, _ := generateNonce()
	database.DB.Model(user).Update("nonce", newNonce)
	user.Nonce = newNonce
	return newNonce
}

// GenerateJWT issues a signed JWT containing the wallet address claim.
func (s *AuthService) GenerateJWT(wallet string) (string, error) {
	wallet = strings.ToLower(wallet)
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"wallet": wallet,
		"exp":    time.Now().Add(24 * time.Hour).Unix(),
		"iat":    time.Now().Unix(),
	})
	return token.SignedString([]byte(s.jwtSecret))
}

func generateNonce() (string, error) {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b), nil
}
