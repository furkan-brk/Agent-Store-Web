package middleware

import (
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// CORSMiddleware returns a configured CORS middleware for the API Gateway.
func CORSMiddleware(allowedOrigins string) gin.HandlerFunc {
	allowed := map[string]struct{}{}
	for _, origin := range strings.Split(allowedOrigins, ",") {
		o := strings.TrimSpace(origin)
		if o != "" {
			allowed[o] = struct{}{}
		}
	}

	isAllowedOrigin := func(origin string) bool {
		if origin == "" {
			return true
		}
		if _, ok := allowed[origin]; ok {
			return true
		}
		if strings.Contains(origin, "agent-store") && strings.HasSuffix(origin, ".vercel.app") {
			return true
		}
		if strings.Contains(origin, "agent-store") && strings.HasSuffix(origin, ".up.railway.app") {
			return true
		}
		if os.Getenv("RAILWAY_ENVIRONMENT") != "production" {
			if strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:") {
				return true
			}
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
	return cors.New(corsConfig)
}
