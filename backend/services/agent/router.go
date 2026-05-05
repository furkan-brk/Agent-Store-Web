package agent

import (
	"encoding/base64"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/agentstore/backend/pkg/database"
	"github.com/agentstore/backend/pkg/middleware"
	"github.com/agentstore/backend/pkg/models"
	"github.com/gin-gonic/gin"
)

// SetupRouter creates the Gin engine for the Agent Service.
func SetupRouter(handler *Handler) *gin.Engine {
	r := gin.Default()

	// Request body size limit — 2MB
	r.Use(func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 2<<20)
		c.Next()
	})

	// DB readiness check
	dbReady := func(c *gin.Context) {
		if !database.IsReady() {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "database not ready"})
			return
		}
		c.Next()
	}

	// Auth middleware reads X-Wallet-Address header from gateway
	auth := middleware.InternalAuth()
	optionalAuth := middleware.OptionalInternalAuth()

	// v3.11.3 pilot: dual-auth (JWT OR API key). JWT wins when both are present.
	listAgentsAuth := middleware.AuthOrAPIKey("read:agents")
	writeAgentsAuth := middleware.AuthOrAPIKey("write:agents")

	// Per-wallet rate limiters for expensive endpoints
	createRL := middleware.NewRateLimiter(10, 1*time.Hour)
	chatRL := middleware.NewRateLimiter(30, 1*time.Minute)
	forkRL := middleware.NewRateLimiter(10, 1*time.Hour)

	v1 := r.Group("/api/v1")
	v1.Use(dbReady)
	{
		agents := v1.Group("/agents")
		agents.GET("", handler.ListAgents)
		agents.GET("/trending", handler.TrendingAgents)
		agents.GET("/categories", handler.GetCategories)
		agents.POST("/batch", optionalAuth, handler.BatchGetAgents)
		// v3.11.3: wallet-scoped bulk operations (library remove, tag add/remove, image regen).
		agents.POST("/bulk", auth, handler.BulkAction)
		agents.GET("/:id", optionalAuth, handler.GetAgent)
		agents.GET("/:id/similar", optionalAuth, handler.GetSimilar)
		// Public endpoint: unauth callers get redacted SKILL.md so the
		// `openclaw://install-skill?url=...` deeplink can be opened from
		// anywhere. Full prompt is served only to owner/purchaser.
		agents.GET("/:id/skill.md", optionalAuth, handler.GetAgentSkillMd)
		// v3.11.3: dual-auth (JWT OR API key with `write:agents`) on create.
		// JWT-authed callers behave exactly as before (header takes precedence).
		agents.POST("", writeAgentsAuth, createRL.WalletMiddleware(), handler.CreateAgent)
		// v3.11.3: programmatic /agents listing for API-key callers. The public
		// `GET /agents` route stays open; this dedicated path enforces a key so
		// scope-gated bots can prove provenance. JWT-authed users can hit
		// either path.
		v1.GET("/keyed/agents", listAgentsAuth, handler.ListAgents)
		agents.PUT("/:id", auth, handler.UpdateAgent)
		agents.POST("/:id/regenerate-image", auth, createRL.WalletMiddleware(), handler.RegenerateImage)
		agents.POST("/:id/fork", auth, forkRL.WalletMiddleware(), handler.ForkAgent)
		agents.POST("/:id/chat", auth, chatRL.WalletMiddleware(), handler.ChatWithAgent)
		agents.POST("/:id/trial", auth, handler.GenerateTrialToken)
		agents.POST("/:id/purchase", auth, handler.RecordPurchase)
		agents.GET("/:id/purchase-status", auth, handler.GetPurchaseStatus)
		agents.PUT("/:id/price", auth, handler.SetAgentPrice)
		agents.POST("/:id/rate", auth, handler.RateAgent)
		agents.GET("/:id/ratings", handler.GetRatings)
		agents.POST("/:id/ratings/:ratingID/helpful", auth, handler.MarkRatingHelpful)
		agents.POST("/:id/ratings/:ratingID/flag", auth, handler.FlagRating)
		// v3.11.4: discovery funnel signal — record when authenticated user
		// copies an agent's prompt. Empty body, attribution via wallet header.
		agents.POST("/:id/copy-analytics", auth, handler.CopyAnalytics)

		// v3.11.3: agent version history + rollback (owner-only).
		agents.GET("/:id/versions", auth, handler.ListAgentVersions)
		agents.GET("/:id/versions/:v", auth, handler.GetAgentVersion)
		agents.POST("/:id/versions/:v/rollback", auth, handler.RollbackAgentVersion)

		user := v1.Group("/user", auth)
		user.GET("/library", handler.GetLibrary)
		user.POST("/library/:id", handler.AddToLibrary)
		user.DELETE("/library/:id", handler.RemoveFromLibrary)
		user.GET("/credits", handler.GetCredits)
		user.GET("/credits/history", handler.GetCreditHistory)
		user.POST("/credits/topup", handler.TopUpCredits)
		user.POST("/credits/dev-grant", handler.DevGrantCredits)
		user.GET("/profile", handler.GetUserProfile)
		user.PATCH("/profile", handler.UpdateProfile)

		// Public trial script endpoint (no auth, token-based)
		v1.GET("/trial/:token/script", handler.GetTrialScript)

		agents.GET("/for-you", auth, handler.GetForYou)

		v1.GET("/users/:wallet", handler.GetPublicProfile)
		// v3.11.4: public achievement badges earned by a wallet
		v1.GET("/users/:wallet/achievements", handler.GetAchievements)
		v1.POST("/users/:wallet/follow", auth, handler.FollowUser)
		v1.DELETE("/users/:wallet/follow", auth, handler.UnfollowUser)
		v1.GET("/users/:wallet/followers", handler.GetFollowers)
		v1.GET("/users/:wallet/following", handler.GetFollowing)
		v1.GET("/users/:wallet/feed", handler.GetActivityFeed)
		v1.GET("/users/:wallet/follow-status", auth, handler.GetFollowStatus)
		v1.GET("/leaderboard", handler.GetLeaderboard)
		v1.GET("/og/agent/:id", handler.GetOGMeta)

		// v3.10: creator analytics
		user.GET("/creator/insights", handler.GetCreatorInsights)

		// v3.11.3: cross-cutting KPI funnel (creator-scoped).
		v1.GET("/admin/kpi/funnel", auth, handler.GetFunnelMetrics)
		// v3.11.4: Store discovery KPI funnel (creator-scoped).
		v1.GET("/admin/kpi/discovery", auth, handler.GetDiscoveryFunnel)
		// v3.11.4: bulk impression batch — store grid sends IDs as cards scroll into view.
		agents.POST("/impressions", auth, handler.RecordImpressions)

		// v3.11.2: notification center
		notif := user.Group("/notifications")
		notif.GET("/prefs", handler.GetNotificationPrefs)
		notif.PATCH("/prefs", handler.UpdateNotificationPref)
		notif.GET("/inbox", handler.GetNotificationInbox)
		notif.POST("/inbox/:id/read", handler.MarkNotificationRead)
		notif.POST("/inbox/mark-all-read", handler.MarkAllNotificationsRead)

		// v3.11.2: developer/API key management
		keys := user.Group("/api-keys")
		keys.POST("", handler.CreateAPIKey)
		keys.GET("", handler.ListAPIKeys)
		keys.DELETE("/:id", handler.RevokeAPIKey)
	}

	// Internal endpoints for cross-service communication
	internal := r.Group("/internal")
	internal.Use(dbReady)
	{
		internal.GET("/agents/:id", handler.InternalGetAgent)
		internal.POST("/agents/:id/increment-use", handler.InternalIncrementUse)
		internal.POST("/credits/deduct", handler.InternalDeductCredits)
		internal.GET("/credits/:wallet", handler.InternalGetCredits)
	}

	// Serve uploaded images with long-lived cache headers.
	// Fast path: serve from disk. Fallback: decode base64 from DB and lazy-hydrate to disk.
	r.GET("/api/v1/images/*filepath", func(c *gin.Context) {
		fp := c.Param("filepath")
		// Security: prevent directory traversal
		if strings.Contains(fp, "..") {
			c.AbortWithStatus(http.StatusBadRequest)
			return
		}
		fullPath := filepath.Join("./uploads", fp)

		// Determine content type from extension
		contentType := "application/octet-stream"
		if strings.HasSuffix(fp, ".webp") {
			contentType = "image/webp"
		} else if strings.HasSuffix(fp, ".png") {
			contentType = "image/png"
		}

		// Fast path: file exists on disk
		if _, err := os.Stat(fullPath); err == nil {
			c.Header("Cache-Control", "public, max-age=31536000, immutable")
			c.Header("Content-Type", contentType)
			c.File(fullPath)
			return
		}

		// Slow path: file missing on disk — try DB fallback
		if !database.IsReady() {
			c.AbortWithStatus(http.StatusServiceUnavailable)
			return
		}

		// Parse agent ID from filepath: e.g. "/agents/123.webp" → 123
		base := filepath.Base(fp)
		ext := filepath.Ext(base)
		idStr := strings.TrimSuffix(base, ext)
		agentID, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			c.AbortWithStatus(http.StatusNotFound)
			return
		}

		// Load only the generated_image column (base64 text) to avoid fetching full row
		var agent models.Agent
		if err := database.DB.Select("id, generated_image").First(&agent, agentID).Error; err != nil || agent.GeneratedImage == "" {
			c.AbortWithStatus(http.StatusNotFound)
			return
		}

		imgBytes, err := base64.StdEncoding.DecodeString(agent.GeneratedImage)
		if err != nil || len(imgBytes) == 0 {
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}

		// Serve the decoded image with a shorter cache (1 hour) since it was a fallback
		c.Header("Cache-Control", "public, max-age=3600")
		c.Header("Content-Type", contentType)
		c.Data(http.StatusOK, contentType, imgBytes)

		// Lazy-hydrate: re-save the file to disk so next request hits the fast path
		go func(path string, data []byte) {
			if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
				log.Printf("[ImageHydrate] mkdir failed for %s: %v", path, err)
				return
			}
			if err := os.WriteFile(path, data, 0644); err != nil {
				log.Printf("[ImageHydrate] write failed for %s: %v", path, err)
				return
			}
			log.Printf("[ImageHydrate] lazy-restored %s (%d bytes)", path, len(data))
		}(fullPath, imgBytes)
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "agentsvc", "db_ready": database.IsReady()})
	})

	return r
}
