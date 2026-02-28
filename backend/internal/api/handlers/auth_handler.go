package handlers

import (
	"net/http"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct{ authSvc *services.AuthService }

func NewAuthHandler(authSvc *services.AuthService) *AuthHandler { return &AuthHandler{authSvc} }

func (h *AuthHandler) GetNonce(c *gin.Context) {
	wallet := c.Param("wallet")
	if wallet == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "wallet required"})
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
