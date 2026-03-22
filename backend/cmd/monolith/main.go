package main

import (
	"encoding/base64"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/cache"
	"github.com/agentstore/backend/pkg/claude"
	"github.com/agentstore/backend/pkg/config"
	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/agentstore/backend/pkg/models"
	"github.com/agentstore/backend/services/agent"
	agentclient "github.com/agentstore/backend/services/agent/client"
	"github.com/agentstore/backend/services/aipipeline"
	"github.com/agentstore/backend/services/auth"
	"github.com/agentstore/backend/services/gateway"
	"github.com/agentstore/backend/services/guild"
	guildclient "github.com/agentstore/backend/services/guild/client"
	"github.com/agentstore/backend/services/workspace"
	wsclient "github.com/agentstore/backend/services/workspace/client"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	if os.Getenv("GIN_MODE") == "" && os.Getenv("RAILWAY_ENVIRONMENT") == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Async DB connect — HTTP server starts immediately so healthcheck passes.
	go func() {
		database.ConnectWithRetry(cfg.PostgresDSN)
		auth.Migrate()
		agent.Migrate()
		guild.Migrate()
		workspace.Migrate()
		log.Println("All migrations completed")
	}()

	port := cfg.Port

	// --- Build internal service URLs pointing to ourselves ---
	selfURL := "http://127.0.0.1:" + port

	// --- Initialize all services ---

	// Auth
	authSvc := auth.NewAuthService(cfg.JWTSecret)
	authHandler := auth.NewHandler(authSvc)

	// AI Pipeline (no DB needed)
	geminiSvc := aipipeline.NewGeminiService(cfg.GeminiAPIKey)
	claudeSvc := aipipeline.NewAIService(cfg.ClaudeAPIKey)
	scoreSvc := aipipeline.NewScoreService(cfg.GeminiAPIKey)
	bgRemover := aipipeline.NewBgRemover(cfg.ClipDropAPIKey)
	pipeline := aipipeline.NewPipelineService(geminiSvc, claudeSvc, scoreSvc, bgRemover)
	pipelineHandler := aipipeline.NewHandler(pipeline)

	// Agent
	agentAIClient := agentclient.NewAIClient(selfURL)
	imageSvc := agent.NewImageService("./uploads", "")
	cacheStore := cache.NewStore()
	agentSvc := agent.NewAgentService(agentAIClient, imageSvc, cacheStore, cfg.CreditsContract, cfg.TreasuryWallet)
	agentHandler := agent.NewHandler(agentSvc)

	// Guild
	guildAIClient := guildclient.NewAIClient(selfURL)
	guildCacheStore := cache.NewStore()
	guildSvc := guild.NewGuildService(guildAIClient, guildCacheStore)
	gmSvc := guild.NewGuildMasterService(guildAIClient)
	guildHandler := guild.NewHandler(guildSvc, gmSvc)

	// Workspace
	wsAIClient := wsclient.NewAIClient(selfURL)
	wsAgentClient := wsclient.NewAgentClient(selfURL)
	claudeClient := claude.NewClient(cfg.ClaudeAPIKey)
	missionSvc := workspace.NewMissionService()
	legendSvc := workspace.NewLegendService(wsAIClient, wsAgentClient, missionSvc, claudeClient)
	workspaceHandler := workspace.NewHandler(missionSvc, legendSvc)

	// --- Single Gin Engine ---
	r := gin.Default()
	r.RedirectTrailingSlash = false
	r.RedirectFixedPath = false

	// Global middleware
	r.Use(func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 2<<20)
		c.Next()
	})
	r.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))

	// JWT extraction — sets "wallet" in context AND X-Wallet-Address header
	// so InternalAuth middleware works without changes.
	r.Use(gateway.JWTExtractor(cfg.JWTSecret))
	r.Use(func(c *gin.Context) {
		if wallet, exists := c.Get("wallet"); exists {
			c.Request.Header.Set("X-Wallet-Address", wallet.(string))
		}
		c.Next()
	})

	// DB readiness middleware (shared)
	dbReady := func(c *gin.Context) {
		if !database.IsReady() {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "database not ready"})
			return
		}
		c.Next()
	}

	// Auth middleware
	authMW := middleware.InternalAuth()
	optionalAuth := middleware.OptionalInternalAuth()

	// Rate limiters
	authRL := middleware.NewRateLimiter(20, 1*time.Minute)
	createRL := middleware.NewRateLimiter(10, 1*time.Hour)
	chatRL := middleware.NewRateLimiter(30, 1*time.Minute)
	forkRL := middleware.NewRateLimiter(10, 1*time.Hour)
	gmRL := middleware.NewRateLimiter(20, 1*time.Minute)
	executeRL := middleware.NewRateLimiter(20, 1*time.Minute)

	// ============================================================
	// ROUTES
	// ============================================================

	v1 := r.Group("/api/v1")

	// --- Auth routes ---
	{
		authGroup := v1.Group("/auth", dbReady, authRL.Middleware())
		authGroup.GET("/nonce/:wallet", authHandler.GetNonce)
		authGroup.POST("/verify", authHandler.VerifySignature)
	}

	// --- Agent routes ---
	{
		agents := v1.Group("/agents", dbReady)
		agents.GET("", agentHandler.ListAgents)
		agents.GET("/trending", agentHandler.TrendingAgents)
		agents.GET("/categories", agentHandler.GetCategories)
		agents.POST("/batch", optionalAuth, agentHandler.BatchGetAgents)
		agents.GET("/:id", optionalAuth, agentHandler.GetAgent)
		agents.POST("", authMW, createRL.WalletMiddleware(), agentHandler.CreateAgent)
		agents.PUT("/:id", authMW, agentHandler.UpdateAgent)
		agents.POST("/:id/regenerate-image", authMW, createRL.WalletMiddleware(), agentHandler.RegenerateImage)
		agents.POST("/:id/fork", authMW, forkRL.WalletMiddleware(), agentHandler.ForkAgent)
		agents.POST("/:id/chat", authMW, chatRL.WalletMiddleware(), agentHandler.ChatWithAgent)
		agents.POST("/:id/trial", authMW, agentHandler.GenerateTrialToken)
		agents.POST("/:id/purchase", authMW, agentHandler.RecordPurchase)
		agents.GET("/:id/purchase-status", authMW, agentHandler.GetPurchaseStatus)
		agents.PUT("/:id/price", authMW, agentHandler.SetAgentPrice)
		agents.POST("/:id/rate", authMW, agentHandler.RateAgent)
		agents.GET("/:id/ratings", agentHandler.GetRatings)

		user := v1.Group("/user", dbReady, authMW)
		user.GET("/library", agentHandler.GetLibrary)
		user.POST("/library/:id", agentHandler.AddToLibrary)
		user.DELETE("/library/:id", agentHandler.RemoveFromLibrary)
		user.GET("/credits", agentHandler.GetCredits)
		user.GET("/credits/history", agentHandler.GetCreditHistory)
		user.POST("/credits/topup", agentHandler.TopUpCredits)
		user.GET("/profile", agentHandler.GetUserProfile)
		user.PATCH("/profile", agentHandler.UpdateProfile)

		v1.GET("/trial/:token/script", dbReady, agentHandler.GetTrialScript)
		v1.GET("/users/:wallet", dbReady, agentHandler.GetPublicProfile)
		v1.GET("/leaderboard", dbReady, agentHandler.GetLeaderboard)
	}

	// --- Guild routes ---
	{
		guilds := v1.Group("/guilds", dbReady)
		guilds.GET("", guildHandler.ListGuilds)
		guilds.GET("/:id", guildHandler.GetGuild)
		guilds.POST("", authMW, guildHandler.CreateGuild)
		guilds.POST("/:id/members", authMW, guildHandler.AddMember)
		guilds.DELETE("/:id/members/:agentId", authMW, guildHandler.RemoveMember)
		guilds.POST("/:id/join", authMW, guildHandler.JoinGuild)
		guilds.DELETE("/:id/join", authMW, guildHandler.LeaveGuild)
		guilds.GET("/:id/compatibility", guildHandler.GetCompatibility)

		gm := v1.Group("/guild-master", dbReady, authMW, gmRL.WalletMiddleware())
		gm.POST("/suggest", guildHandler.Suggest)
		gm.POST("/chat", guildHandler.TeamChat)
	}

	// --- Workspace routes ---
	{
		wsUser := v1.Group("/user", dbReady, authMW)

		missions := wsUser.Group("/missions")
		missions.GET("", workspaceHandler.GetMissions)
		missions.POST("", workspaceHandler.SaveMission)
		missions.DELETE("/:id", workspaceHandler.DeleteMission)
		missions.POST("/sync", workspaceHandler.BatchSyncMissions)
		missions.POST("/expand", workspaceHandler.ExpandMissions)

		legend := wsUser.Group("/legend")
		legend.GET("/workflows", workspaceHandler.GetLegendWorkflows)
		legend.POST("/workflows", workspaceHandler.SaveLegendWorkflow)
		legend.DELETE("/workflows/:id", workspaceHandler.DeleteLegendWorkflow)
		legend.POST("/workflows/sync", workspaceHandler.BatchSyncLegendWorkflows)
		legend.POST("/workflows/:id/execute", executeRL.WalletMiddleware(), workspaceHandler.ExecuteWorkflow)
		legend.GET("/executions", workspaceHandler.ListExecutions)
		legend.GET("/executions/:execId", workspaceHandler.GetExecution)
	}

	// --- Internal endpoints (AI pipeline + agent cross-service) ---
	{
		internal := r.Group("/internal")
		internal.POST("/analyze", pipelineHandler.Analyze)
		internal.POST("/profile", pipelineHandler.Profile)
		internal.POST("/score", pipelineHandler.Score)
		internal.POST("/avatar", pipelineHandler.Avatar)
		internal.POST("/chat", pipelineHandler.Chat)
		internal.POST("/compatibility", pipelineHandler.Compatibility)
		internal.POST("/character", pipelineHandler.Character)

		internal.GET("/agents/:id", agentHandler.InternalGetAgent)
		internal.POST("/agents/:id/increment-use", agentHandler.InternalIncrementUse)
		internal.POST("/credits/deduct", agentHandler.InternalDeductCredits)
		internal.GET("/credits/:wallet", agentHandler.InternalGetCredits)
	}

	// --- Image serving ---
	r.GET("/api/v1/images/*filepath", func(c *gin.Context) {
		fp := c.Param("filepath")
		if strings.Contains(fp, "..") {
			c.AbortWithStatus(http.StatusBadRequest)
			return
		}
		fullPath := filepath.Join("./uploads", fp)

		contentType := "application/octet-stream"
		if strings.HasSuffix(fp, ".webp") {
			contentType = "image/webp"
		} else if strings.HasSuffix(fp, ".png") {
			contentType = "image/png"
		}

		if _, err := os.Stat(fullPath); err == nil {
			c.Header("Cache-Control", "public, max-age=31536000, immutable")
			c.Header("Content-Type", contentType)
			c.File(fullPath)
			return
		}

		if !database.IsReady() {
			c.AbortWithStatus(http.StatusServiceUnavailable)
			return
		}

		base := filepath.Base(fp)
		ext := filepath.Ext(base)
		idStr := strings.TrimSuffix(base, ext)
		agentID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			c.AbortWithStatus(http.StatusNotFound)
			return
		}

		var ag models.Agent
		if err := database.DB.Select("id, generated_image").First(&ag, agentID).Error; err != nil || ag.GeneratedImage == "" {
			c.AbortWithStatus(http.StatusNotFound)
			return
		}

		imgBytes, err := base64.StdEncoding.DecodeString(ag.GeneratedImage)
		if err != nil || len(imgBytes) == 0 {
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}

		c.Header("Cache-Control", "public, max-age=3600")
		c.Header("Content-Type", contentType)
		c.Data(http.StatusOK, contentType, imgBytes)

		go func(path string, data []byte) {
			_ = os.MkdirAll(filepath.Dir(path), 0755)
			_ = os.WriteFile(path, data, 0644)
		}(fullPath, imgBytes)
	})

	// --- Health ---
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "monolith", "db_ready": database.IsReady()})
	})

	log.Printf("Monolith starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Monolith error: %v", err)
	}
}
