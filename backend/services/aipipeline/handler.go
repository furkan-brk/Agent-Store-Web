package aipipeline

import (
	"net/http"

	"github.com/agentstore/backend/pkg/models"
	"github.com/gin-gonic/gin"
)

// Handler exposes internal HTTP endpoints for the AI Pipeline Service.
type Handler struct {
	pipeline *PipelineService
}

// NewHandler creates an internal API handler.
func NewHandler(pipeline *PipelineService) *Handler {
	return &Handler{pipeline: pipeline}
}

// --- Request / Response types ---

type analyzeReq struct {
	Prompt string `json:"prompt" binding:"required"`
}

type profileReq struct {
	Concept string `json:"concept" binding:"required"`
}

type scoreReq struct {
	Prompt string `json:"prompt" binding:"required"`
}

type avatarReq struct {
	Profile     *AgentProfile `json:"profile" binding:"required"`
	ImagePrompt string        `json:"image_prompt"`
	CharType    string        `json:"char_type"`
}

type chatReq struct {
	SystemPrompt string `json:"system_prompt" binding:"required"`
	UserMessage  string `json:"user_message" binding:"required"`
}

type compatibilityReq struct {
	GuildID uint                 `json:"guild_id"`
	Members []GuildMemberSummary `json:"members"`
}

type characterReq struct {
	CharType string `json:"char_type" binding:"required"`
	Subclass string `json:"subclass"`
	Prompt   string `json:"prompt" binding:"required"`
	Rarity   string `json:"rarity"`
}

// --- Endpoints ---

// Analyze classifies a prompt into character type, subclass, category, tags, rarity.
func (h *Handler) Analyze(c *gin.Context) {
	var req analyzeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Try Gemini first
	analysis, err := h.pipeline.Gemini.AnalyzePrompt(req.Prompt)
	if err == nil {
		c.JSON(http.StatusOK, analysis)
		return
	}

	// Keyword fallback
	charType := DetermineCharacterType(req.Prompt)
	subclass := DetermineSubclass(charType, req.Prompt)
	rarity := DetermineRarity(req.Prompt)

	c.JSON(http.StatusOK, &PromptAnalysis{
		CharacterType: charType,
		Subclass:      subclass,
		Category:      "general",
		Tags:          []string{charType},
		Rarity:        string(rarity),
		ImagePrompt:   "A " + charType + " character with unique abilities and tools",
	})
}

// Profile generates a rich visual character profile from an agent concept.
func (h *Handler) Profile(c *gin.Context) {
	var req profileReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	profile, err := h.pipeline.Gemini.GenerateAgentProfile(req.Concept)
	if err != nil {
		// Return fallback profile
		charType := DetermineCharacterType(req.Concept)
		profile = BuildFallbackProfile(req.Concept, charType)
	}

	c.JSON(http.StatusOK, profile)
}

// Score evaluates a prompt's quality (0-100) and generates a service description.
func (h *Handler) Score(c *gin.Context) {
	var req scoreReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result := h.pipeline.Score.ScoreAndDescribe(req.Prompt)
	c.JSON(http.StatusOK, result)
}

// Avatar generates an avatar image with fallback chain.
// Returns base64-encoded image bytes and format.
func (h *Handler) Avatar(c *gin.Context) {
	var req avatarReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Generate image via Imagen (Gemini) + background removal
	base64Image, format := h.pipeline.GenerateImageWithFallback(req.Profile, req.ImagePrompt, req.CharType)
	if base64Image == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "all image providers failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"image_base64": base64Image,
		"format":       format,
	})
}

// Chat sends a message to the AI (Gemini preferred, Claude fallback).
func (h *Handler) Chat(c *gin.Context) {
	var req chatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	response, err := h.pipeline.Chat(req.SystemPrompt, req.UserMessage)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"response": response})
}

// Compatibility analyzes guild member compatibility.
func (h *Handler) Compatibility(c *gin.Context) {
	var req compatibilityReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result := h.pipeline.Score.AnalyzeGuildCompatibility(req.GuildID, req.Members)
	c.JSON(http.StatusOK, result)
}

// Character builds character data JSON (stats, colors, traits).
func (h *Handler) Character(c *gin.Context) {
	var req characterReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	rarity := req.Rarity
	if rarity == "" {
		rarity = string(DetermineRarity(req.Prompt))
	}
	subclass := req.Subclass
	if subclass == "" {
		subclass = DetermineSubclass(req.CharType, req.Prompt)
	}

	charData, err := BuildCharacterData(req.CharType, subclass, models.CharacterRarity(rarity), req.Prompt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"character_data": charData})
}

