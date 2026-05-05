package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// InternalAuth reads the X-Wallet-Address header injected by the API Gateway
// (or, in the monolith, by JWTExtractor + the wallet-injection middleware)
// after JWT validation.
//
// SECURITY (v3.12-P0-1): the X-Wallet-Address header is INTERNAL ONLY.
// Trusting it is safe ONLY if every public-facing entry point strips inbound
// values via middleware.StripInboundWalletHeader before any handler runs.
// monolith/main.go and gateway/main.go both mount that strip middleware at
// the top of the chain. Microservices binaries (cmd/agentsvc etc.) MUST NOT
// be exposed to the public network — they trust the header from the
// gateway, and they have no JWT verification of their own.
//
// If you add a new entry-point binary, mount StripInboundWalletHeader before
// any auth middleware or you will reintroduce the auth-bypass.
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
//
// Same SECURITY contract as InternalAuth — see that function's docstring.
// The header must be stripped on inbound requests via StripInboundWalletHeader.
func OptionalInternalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		if wallet := c.GetHeader("X-Wallet-Address"); wallet != "" {
			c.Set("wallet", wallet)
		}
		c.Next()
	}
}
