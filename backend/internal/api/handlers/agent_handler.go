package handlers

import (
	"net/http"
	"regexp"
	"strconv"

	"github.com/agentstore/backend/internal/services"
	"github.com/gin-gonic/gin"
)

// txHashRegex validates Ethereum transaction hash format (0x followed by 64 hex chars).
var txHashRegex = regexp.MustCompile(`^0x[0-9a-fA-F]{64}$`)

type AgentHandler struct{ agentSvc *services.AgentService }

func NewAgentHandler(agentSvc *services.AgentService) *AgentHandler { return &AgentHandler{agentSvc} }

func (h *AgentHandler) ListAgents(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	// Cap search length to prevent excessively long ILIKE queries
	search := c.Query("search")
	if len(search) > 200 {
		search = search[:200]
	}
	sort := c.DefaultQuery("sort", "newest")
	agents, total, err := h.agentSvc.ListAgents(c.Query("category"), search, sort, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"agents": agents, "total": total, "page": page, "limit": limit})
}

func (h *AgentHandler) GetAgent(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	agent, err := h.agentSvc.GetAgent(uint(id))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.JSON(http.StatusOK, agent)
}

func (h *AgentHandler) CreateAgent(c *gin.Context) {
	var input services.CreateAgentInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(input.Title) > 100 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title too long (max 100 characters)"})
		return
	}
	if len(input.Description) > 500 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "description too long (max 500 characters)"})
		return
	}
	if len(input.Prompt) > 10000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "prompt too long (max 10000 characters)"})
		return
	}
	input.CreatorWallet = c.GetString("wallet")
	agent, err := h.agentSvc.CreateAgent(input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, agent)
}

func (h *AgentHandler) GetLibrary(c *gin.Context) {
	entries, err := h.agentSvc.GetLibrary(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"entries": entries})
}

func (h *AgentHandler) AddToLibrary(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	if err := h.agentSvc.AddToLibrary(c.GetString("wallet"), uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "added to library"})
}

func (h *AgentHandler) RemoveFromLibrary(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	if err := h.agentSvc.RemoveFromLibrary(c.GetString("wallet"), uint(id)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "removed"})
}

func (h *AgentHandler) GetCredits(c *gin.Context) {
	credits, err := h.agentSvc.GetUserCredits(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"credits": credits, "wallet": c.GetString("wallet")})
}

// TrendingAgents returns the top 6 agents by weighted score (save_count*3 + use_count*2).
func (h *AgentHandler) TrendingAgents(c *gin.Context) {
	agents, err := h.agentSvc.GetTrending()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"agents": agents, "count": len(agents)})
}

// ForkAgent creates a copy of an existing agent for the authenticated user.
func (h *AgentHandler) ForkAgent(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	agent, err := h.agentSvc.ForkAgent(uint(id), c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, agent)
}

// ChatWithAgent handles a chat message directed at a specific agent.
func (h *AgentHandler) ChatWithAgent(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var body struct {
		Message string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(body.Message) > 4000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "message too long (max 4000 characters)"})
		return
	}
	reply, err := h.agentSvc.ChatWithAgent(uint(id), body.Message)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"reply": reply, "agent_id": id})
}

// UpdateProfile updates the authenticated user's username and bio.
func (h *AgentHandler) UpdateProfile(c *gin.Context) {
	var input services.UpdateProfileInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.agentSvc.UpdateProfile(c.GetString("wallet"), input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "profile updated"})
}

// GetUserProfile returns the authenticated user's profile with their created agents and stats.
func (h *AgentHandler) GetUserProfile(c *gin.Context) {
	profile, err := h.agentSvc.GetUserProfile(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profile)
}

// GetPublicProfile returns a public profile for any wallet address.
func (h *AgentHandler) GetPublicProfile(c *gin.Context) {
	wallet := c.Param("wallet")
	if wallet == "" || len(wallet) != 42 || wallet[:2] != "0x" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid wallet address"})
		return
	}
	profile, err := h.agentSvc.GetUserProfile(wallet)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profile)
}

// GetCreditHistory returns the credit transaction history for the authenticated user.
func (h *AgentHandler) GetCreditHistory(c *gin.Context) {
	txs, err := h.agentSvc.GetCreditHistory(c.GetString("wallet"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	// Include current balance
	credits, _ := h.agentSvc.GetUserCredits(c.GetString("wallet"))
	c.JSON(http.StatusOK, gin.H{"transactions": txs, "balance": credits})
}

// GetLeaderboard returns the top creators ranked by total saves.
func (h *AgentHandler) GetLeaderboard(c *gin.Context) {
	rankings, err := h.agentSvc.GetLeaderboard()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"rankings": rankings, "count": len(rankings)})
}

// RecordPurchase records a Monad on-chain purchase for an agent.
func (h *AgentHandler) RecordPurchase(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var body struct {
		TxHash    string  `json:"tx_hash" binding:"required"`
		AmountMon float64 `json:"amount_mon"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if !txHashRegex.MatchString(body.TxHash) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid transaction hash format"})
		return
	}
	if err := h.agentSvc.RecordPurchase(c.GetString("wallet"), uint(id), body.TxHash, body.AmountMon); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"purchased": true, "agent_id": id})
}

// GetPurchaseStatus checks if the authenticated user has purchased an agent.
func (h *AgentHandler) GetPurchaseStatus(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	purchased := h.agentSvc.IsPurchased(c.GetString("wallet"), uint(id))
	c.JSON(http.StatusOK, gin.H{"purchased": purchased, "agent_id": id})
}

// RateAgent creates or updates the authenticated user's rating for an agent.
func (h *AgentHandler) RateAgent(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var body struct {
		Rating  int    `json:"rating" binding:"required,min=1,max=5"`
		Comment string `json:"comment"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(body.Comment) > 500 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "comment too long (max 500 characters)"})
		return
	}
	if err := h.agentSvc.RateAgent(uint(id), c.GetString("wallet"), body.Rating, body.Comment); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "rated"})
}

// GetRatings returns ratings, average score, total count, and the current user's rating for an agent.
func (h *AgentHandler) GetRatings(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	ratings, avg, count, err := h.agentSvc.GetRatings(uint(id))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	wallet := c.GetString("wallet")
	userRating := 0
	if wallet != "" {
		userRating = h.agentSvc.GetUserRating(uint(id), wallet)
	}
	c.JSON(http.StatusOK, gin.H{"ratings": ratings, "average": avg, "count": count, "user_rating": userRating})
}

// TopUpCredits handles POST /user/credits/topup — grants credits after MON payment.
func (h *AgentHandler) TopUpCredits(c *gin.Context) {
	var body struct {
		TxHash    string  `json:"tx_hash" binding:"required"`
		AmountMon float64 `json:"amount_mon" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if !txHashRegex.MatchString(body.TxHash) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid transaction hash format"})
		return
	}
	if body.AmountMon <= 0 || body.AmountMon > 10000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be between 0 and 10000 MON"})
		return
	}
	wallet := c.GetString("wallet")
	if err := h.agentSvc.TopUpCredits(wallet, body.TxHash, body.AmountMon); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	// Return updated balance
	credits, _ := h.agentSvc.GetUserCredits(wallet)
	c.JSON(http.StatusOK, gin.H{"message": "credits added", "new_balance": credits})
}

// SetAgentPrice lets a creator set the MON price for their agent.
func (h *AgentHandler) SetAgentPrice(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var body struct {
		Price float64 `json:"price" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if body.Price < 0 || body.Price > 1000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "price must be between 0 and 1000 MON"})
		return
	}
	if err := h.agentSvc.SetAgentPrice(uint(id), c.GetString("wallet"), body.Price); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"price": body.Price, "agent_id": id})
}
