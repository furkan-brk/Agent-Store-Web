package middleware

import (
	"net/http"

	"github.com/agentstore/backend/pkg/database"
	"github.com/gin-gonic/gin"
)

// DBReadiness returns 503 if the database connection has not been established yet.
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
