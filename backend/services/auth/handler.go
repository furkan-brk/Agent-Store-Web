package auth

import (
	"log"
	"net/http"
	"regexp"

	"github.com/gin-gonic/gin"
)

// walletRegex validates Ethereum-style wallet addresses (0x followed by 40 hex chars).
var walletRegex = regexp.MustCompile(`^0x[0-9a-fA-F]{40}$`)

// Handler exposes HTTP endpoints for wallet authentication.
type Handler struct {
	authSvc *AuthService
}

// NewHandler creates a Handler backed by the given AuthService.
func NewHandler(authSvc *AuthService) *Handler {
	return &Handler{authSvc: authSvc}
}

// GetNonce generates a nonce for the wallet and returns it.
func (h *Handler) GetNonce(c *gin.Context) {
	wallet := c.Param("wallet")
	if !walletRegex.MatchString(wallet) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet address format"})
		return
	}
	nonce, err := h.authSvc.GetNonce(wallet)
	if err != nil {
		log.Printf("[AuthHandler.GetNonce] error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"nonce": nonce, "message": "Sign this nonce: " + nonce})
}

type verifyReq struct {
	Wallet    string `json:"wallet" binding:"required"`
	Nonce     string `json:"nonce" binding:"required"`
	Signature string `json:"signature" binding:"required"`
}

// VerifySignature validates the Ethereum signature and returns a JWT on success.
func (h *Handler) VerifySignature(c *gin.Context) {
	var req verifyReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if !walletRegex.MatchString(req.Wallet) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet address format"})
		return
	}
	valid, err := h.authSvc.VerifySignature(req.Wallet, req.Nonce, req.Signature)
	if err != nil || !valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "signature verification failed"})
		return
	}
	token, err := h.authSvc.GenerateJWT(req.Wallet)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "token generation failed"})
		return
	}
	user, _ := h.authSvc.GetOrCreateUser(req.Wallet)
	c.JSON(http.StatusOK, gin.H{"token": token, "user": user})
}
