package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// InternalAuth reads the X-Wallet-Address header injected by the API Gateway
// after JWT validation. Internal services trust this header since they are not
// exposed to the public network.
func InternalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		wallet := c.GetHeader("X-Wallet-Address")
		if wallet == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing wallet header"})
			return
		}
		c.Set("wallet", wallet)
		c.Next()
	}
}

// OptionalInternalAuth reads the X-Wallet-Address header if present but does
// not block unauthenticated requests. Use on public endpoints that behave
// differently for authenticated users.
func OptionalInternalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		if wallet := c.GetHeader("X-Wallet-Address"); wallet != "" {
			c.Set("wallet", wallet)
		}
		c.Next()
	}
}
