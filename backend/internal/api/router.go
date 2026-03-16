package api

import (
	"strings"
	"time"

	"github.com/agentstore/backend/internal/api/handlers"
	"github.com/agentstore/backend/internal/api/middleware"
	"github.com/agentstore/backend/internal/database"
	"github.com/agentstore/backend/internal/services"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func SetupRouter(jwtSecret, allowedOrigins, geminiAPIKey, replicateAPIKey string) *gin.Engine {
	r := gin.Default()

	// Parse comma-separated origins from config.
	allowed := map[string]struct{}{}
	for _, origin := range strings.Split(allowedOrigins, ",") {
		o := strings.TrimSpace(origin)
		if o != "" {
			allowed[o] = struct{}{}
		}
	}

	isAllowedOrigin := func(origin string) bool {
		if origin == "" {
			// Non-browser clients may not send Origin.
			return true
		}
		if _, ok := allowed[origin]; ok {
			return true
		}
		// Allow preview/staging domains used by this project.
		if strings.HasSuffix(origin, ".vercel.app") || strings.HasSuffix(origin, ".up.railway.app") {
			return true
		}
		if strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:") {
			return true
		}
		return false
	}

	corsConfig := cors.Config{
		AllowOriginFunc:  isAllowedOrigin,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "Accept"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: false,
		MaxAge:           12 * time.Hour,
	}
	r.Use(cors.New(corsConfig))

	// Single shared in-process cache for all services.
	cache := services.NewCacheStore()

	authSvc := services.NewAuthService(jwtSecret)
	aiSvc := services.NewAIService("")
	geminiSvc := services.NewGeminiService(geminiAPIKey)
	replicateSvc := services.NewReplicateService(replicateAPIKey)
	scoreSvc := services.NewScoreService(geminiAPIKey)
	pollinationsSvc := services.NewPollinationsService()
	agentSvc := services.NewAgentService(aiSvc, geminiSvc, replicateSvc, scoreSvc, pollinationsSvc, cache)
	guildSvc := services.NewGuildService(scoreSvc, cache)
	gmSvc := services.NewGuildMasterService(aiSvc)
	missionSvc := services.NewMissionService()
	legendSvc := services.NewLegendService(geminiSvc, missionSvc)

	// Rate limiter: 20 requests per minute on auth endpoints to mitigate brute-force
	authRL := middleware.NewRateLimiter(20, 1*time.Minute)

	authH := handlers.NewAuthHandler(authSvc)
	agentH := handlers.NewAgentHandler(agentSvc)
	guildH := handlers.NewGuildHandler(guildSvc)
	gmH := handlers.NewGuildMasterHandler(gmSvc)
	wsH := handlers.NewWorkspaceHandler(missionSvc, legendSvc)

	v1 := r.Group("/api/v1")
	v1.Use(middleware.DBReadiness())
	{
		auth := v1.Group("/auth")
		auth.Use(authRL.Middleware())
		auth.GET("/nonce/:wallet", authH.GetNonce)
		auth.POST("/verify", authH.VerifySignature)

		agents := v1.Group("/agents")
		agents.GET("", agentH.ListAgents)
		agents.GET("/trending", agentH.TrendingAgents)
		agents.GET("/:id", middleware.OptionalAuthMiddleware(authSvc), agentH.GetAgent)
		agents.POST("", middleware.AuthMiddleware(authSvc), agentH.CreateAgent)
		agents.PUT("/:id", middleware.AuthMiddleware(authSvc), agentH.UpdateAgent)
		agents.POST("/:id/regenerate-image", middleware.AuthMiddleware(authSvc), agentH.RegenerateImage)
		agents.POST("/:id/fork", middleware.AuthMiddleware(authSvc), agentH.ForkAgent)
		agents.POST("/:id/chat", middleware.AuthMiddleware(authSvc), agentH.ChatWithAgent)
		agents.POST("/:id/trial", middleware.AuthMiddleware(authSvc), agentH.GenerateTrialToken)
		agents.POST("/:id/purchase", middleware.AuthMiddleware(authSvc), agentH.RecordPurchase)
		agents.GET("/:id/purchase-status", middleware.AuthMiddleware(authSvc), agentH.GetPurchaseStatus)
		agents.PUT("/:id/price", middleware.AuthMiddleware(authSvc), agentH.SetAgentPrice)
		agents.POST("/:id/rate", middleware.AuthMiddleware(authSvc), agentH.RateAgent)
		agents.GET("/:id/ratings", agentH.GetRatings)

		user := v1.Group("/user", middleware.AuthMiddleware(authSvc))
		user.GET("/library", agentH.GetLibrary)
		user.POST("/library/:id", agentH.AddToLibrary)
		user.DELETE("/library/:id", agentH.RemoveFromLibrary)
		user.GET("/credits", agentH.GetCredits)
		user.GET("/credits/history", agentH.GetCreditHistory)
		user.POST("/credits/topup", agentH.TopUpCredits)
		user.GET("/profile", agentH.GetUserProfile)
		user.PATCH("/profile", agentH.UpdateProfile)
		user.GET("/missions", wsH.GetMissions)
		user.POST("/missions", wsH.SaveMission)
		user.DELETE("/missions/:id", wsH.DeleteMission)
		user.POST("/missions/expand", wsH.ExpandMissions)
		user.GET("/legend/workflows", wsH.GetLegendWorkflows)
		user.POST("/legend/workflows", wsH.SaveLegendWorkflow)
		user.DELETE("/legend/workflows/:id", wsH.DeleteLegendWorkflow)
		user.POST("/legend/workflows/:id/execute", wsH.ExecuteWorkflow)
		user.GET("/legend/executions/:execId", wsH.GetExecution)
		user.GET("/legend/executions", wsH.ListExecutions)

		// Public trial script endpoint (no auth, token-based)
		v1.GET("/trial/:token/script", agentH.GetTrialScript)

		v1.GET("/users/:wallet", agentH.GetPublicProfile)
		v1.GET("/leaderboard", agentH.GetLeaderboard)

		guilds := v1.Group("/guilds")
		guilds.GET("", guildH.ListGuilds)
		guilds.GET("/:id", guildH.GetGuild)
		guilds.POST("", middleware.AuthMiddleware(authSvc), guildH.CreateGuild)
		guilds.POST("/:id/members", middleware.AuthMiddleware(authSvc), guildH.AddMember)
		guilds.DELETE("/:id/members/:agentId", middleware.AuthMiddleware(authSvc), guildH.RemoveMember)
		guilds.POST("/:id/join", middleware.AuthMiddleware(authSvc), guildH.JoinGuild)
		guilds.DELETE("/:id/join", middleware.AuthMiddleware(authSvc), guildH.LeaveGuild)
		guilds.GET("/:id/compatibility", guildH.GetCompatibility)

		gm := v1.Group("/guild-master")
		gm.POST("/suggest", gmH.Suggest)
		gm.POST("/chat", gmH.TeamChat)
	}

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "agent-store-backend", "db_ready": database.IsReady()})
	})

	return r
}
