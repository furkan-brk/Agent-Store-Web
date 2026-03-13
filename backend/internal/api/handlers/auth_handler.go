package handlers

import (
	"net/http"
	"regexp"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

// walletRegex validates Ethereum-style wallet addresses (0x followed by 40 hex chars).
var walletRegex = regexp.MustCompile(`^0x[0-9a-fA-F]{40}$`)

type AuthHandler struct{ authSvc *services.AuthService }

func NewAuthHandler(authSvc *services.AuthService) *AuthHandler { return &AuthHandler{authSvc} }

func (h *AuthHandler) GetNonce(c *gin.Context) {
	wallet := c.Param("wallet")
	if !walletRegex.MatchString(wallet) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet address format"})
		return
	}
	nonce, err := h.authSvc.GetNonce(wallet)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"nonce": nonce, "message": "Sign this nonce: " + nonce})
}

type verifyReq struct {
	Wallet    string `json:"wallet" binding:"required"`
	Nonce     string `json:"nonce" binding:"required"`
	Signature string `json:"signature" binding:"required"`
}

func (h *AuthHandler) VerifySignature(c *gin.Context) {
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
