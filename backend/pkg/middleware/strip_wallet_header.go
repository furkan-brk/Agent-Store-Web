// Package middleware exposes Gin handlers shared across services.
//
// strip_wallet_header.go closes a critical auth-bypass vector: the
// X-Wallet-Address header is an *internal* convention used by the gateway/
// monolith JWT extractor to forward a verified caller wallet to downstream
// handlers. If an external client could set this header on a request, every
// handler that trusts c.GetHeader("X-Wallet-Address") would happily
// impersonate the requested wallet.
//
// The fix is simple: always delete inbound X-Wallet-Address as the very
// first thing we do, before any auth-extracting middleware runs. Only code
// inside the trust boundary (after a JWT validates) is allowed to write the
// header. Internal-only routes (/internal/*) are still protected because
// the gateway never proxies inbound /internal traffic.
package middleware

import "github.com/gin-gonic/gin"

// walletForwardHeader is the canonical name of the inter-service wallet
// header. Defined here so future renames touch one place.
const walletForwardHeader = "X-Wallet-Address"

// StripInboundWalletHeader is a Gin middleware that deletes any inbound
// X-Wallet-Address header before downstream middleware runs. Mount this
// at the top of the gin chain on any binary that accepts external traffic
// (gateway, monolith). After this runs, the only way the header can appear
// is if our own code sets it — which in practice means after a verified JWT.
//
// The header is also stripped on case-insensitive matches because Go's
// net/http canonicalises header keys but defensive code is cheap.
func StripInboundWalletHeader() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Header.Del is case-insensitive (canonical-key match) so a single
		// call covers x-wallet-address, X-WALLET-ADDRESS, etc.
		c.Request.Header.Del(walletForwardHeader)
		c.Next()
	}
}
