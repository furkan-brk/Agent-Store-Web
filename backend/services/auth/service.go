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
// stored nonce and rotates the nonce on success to prevent replay attacks.
func (s *AuthService) VerifySignature(wallet, nonce, signature string) (bool, error) {
	wallet = strings.ToLower(wallet)
	var user models.User
	if err := database.DB.Where("wallet_address = ?", wallet).First(&user).Error; err != nil {
		return false, errors.New("user not found")
	}
	log.Printf("[AUTH] verify wallet=%s nonce_db=%s nonce_req=%s", wallet, user.Nonce, nonce)
	if user.Nonce != nonce {
		log.Printf("[AUTH] FAIL nonce mismatch: db=%q req=%q", user.Nonce, nonce)
		return false, errors.New("nonce mismatch")
	}
	// Construct the same human-readable message the frontend signs.
	signable := fmt.Sprintf("Sign in to Agent Store\n\nNonce: %s", nonce)
	msg := fmt.Sprintf("\x19Ethereum Signed Message:\n%d%s", len(signable), signable)
	hash := crypto.Keccak256Hash([]byte(msg))
	sigBytes, err := hex.DecodeString(strings.TrimPrefix(signature, "0x"))
	if err != nil || len(sigBytes) != 65 {
		log.Printf("[AUTH] FAIL invalid signature: len=%d err=%v", len(sigBytes), err)
		return false, errors.New("invalid signature")
	}
	if sigBytes[64] >= 27 {
		sigBytes[64] -= 27
	}
	pubKey, err := crypto.SigToPub(hash.Bytes(), sigBytes)
	if err != nil {
		log.Printf("[AUTH] FAIL SigToPub err=%v", err)
		return false, err
	}
	recovered := crypto.PubkeyToAddress(*pubKey)
	expected := common.HexToAddress(wallet)
	match := strings.EqualFold(recovered.Hex(), expected.Hex())
	log.Printf("[AUTH] recovered=%s expected=%s match=%v msg_len=%d", recovered.Hex(), expected.Hex(), match, len(signable))

	// Rotate nonce after successful verification to prevent replay attacks.
	if match {
		newNonce, _ := generateNonce()
		database.DB.Model(&user).Update("nonce", newNonce)
	}

	return match, nil
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
