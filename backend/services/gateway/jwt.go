package gateway

import (
	"errors"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// JWTExtractor is a Gin middleware that optionally extracts the wallet address
// from the Authorization header's JWT. If present and valid, it sets "wallet"
// in the Gin context so the proxy can inject the X-Wallet-Address header.
// Invalid or missing tokens are silently ignored — auth enforcement is the
// responsibility of each downstream service via InternalAuth middleware.
func JWTExtractor(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" || !strings.HasPrefix(header, "Bearer ") {
			c.Next()
			return
		}
		wallet, err := validateJWT(strings.TrimPrefix(header, "Bearer "), jwtSecret)
		if err != nil {
			c.Next()
			return
		}
		c.Set("wallet", wallet)
		c.Next()
	}
}

func validateJWT(tokenStr, secret string) (string, error) {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil || !token.Valid {
		return "", errors.New("invalid token")
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("invalid claims")
	}
	wallet, ok := claims["wallet"].(string)
	if !ok {
		return "", errors.New("missing wallet claim")
	}
	return wallet, nil
}
