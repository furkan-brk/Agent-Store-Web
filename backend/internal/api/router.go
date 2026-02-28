package api

import (
	"time"

	"github.com/agentstore/backend/internal/api/handlers"
	"github.com/agentstore/backend/internal/api/middleware"
	"github.com/agentstore/backend/internal/services"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func SetupRouter(jwtSecret, allowedOrigins, claudeAPIKey, geminiAPIKey, replicateAPIKey string) *gin.Engine {
	r := gin.Default()

	corsConfig := cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "Accept"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: false, // Must be false when AllowAllOrigins is true
		MaxAge:           12 * time.Hour,
	}
	r.Use(cors.New(corsConfig))

	authSvc := services.NewAuthService(jwtSecret)
	aiSvc := services.NewAIService(claudeAPIKey)
	geminiSvc := services.NewGeminiService(geminiAPIKey)
	replicateSvc := services.NewReplicateService(replicateAPIKey)
	scoreSvc := services.NewScoreService(geminiAPIKey)
	agentSvc := services.NewAgentService(aiSvc, geminiSvc, replicateSvc, scoreSvc)
	guildSvc := services.NewGuildService(scoreSvc)
	gmSvc := services.NewGuildMasterService(aiSvc)

	authH := handlers.NewAuthHandler(authSvc)
	agentH := handlers.NewAgentHandler(agentSvc)
	guildH := handlers.NewGuildHandler(guildSvc)
	gmH := handlers.NewGuildMasterHandler(gmSvc)

	v1 := r.Group("/api/v1")
	{
		auth := v1.Group("/auth")
		auth.GET("/nonce/:wallet", authH.GetNonce)
		auth.POST("/verify", authH.VerifySignature)

		agents := v1.Group("/agents")
		agents.GET("", agentH.ListAgents)
		agents.GET("/trending", agentH.TrendingAgents)
		agents.GET("/:id", agentH.GetAgent)
		agents.POST("", middleware.AuthMiddleware(authSvc), agentH.CreateAgent)
		agents.POST("/:id/fork", middleware.AuthMiddleware(authSvc), agentH.ForkAgent)
		agents.POST("/:id/chat", middleware.AuthMiddleware(authSvc), agentH.ChatWithAgent)
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
		c.JSON(200, gin.H{"status": "ok", "service": "agent-store-backend"})
	})

	return r
}
