package middleware

import (
	"net/http"

	"github.com/agentstore/backend/internal/database"
	"github.com/gin-gonic/gin"
)

// DBReadiness returns 503 Service Unavailable if the database connection
// has not been established yet. This prevents nil-pointer panics when
// handlers access database.DB before ConnectWithRetry completes.
func DBReadiness() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !database.IsReady() {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{
				"error": "database not ready, please retry in a few seconds",
			})
			return
		}
		c.Next()
	}
}
