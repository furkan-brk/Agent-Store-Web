package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type entry struct {
	count     int
	windowEnd time.Time
}

// RateLimiter provides a simple per-key sliding window rate limiter.
type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*entry
	limit    int
	window   time.Duration
}

// NewRateLimiter creates a rate limiter that allows `limit` requests per `window`.
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*entry),
		limit:    limit,
		window:   window,
	}
	go func() {
		for {
			time.Sleep(window * 2)
			rl.cleanup()
		}
	}()
	return rl
}

func (rl *RateLimiter) cleanup() {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	now := time.Now()
	for ip, e := range rl.visitors {
		if now.After(e.windowEnd) {
			delete(rl.visitors, ip)
		}
	}
}

// Middleware returns a Gin middleware that enforces the rate limit using client IP.
func (rl *RateLimiter) Middleware() gin.HandlerFunc {
	return rl.middleware(func(c *gin.Context) string { return c.ClientIP() })
}

// WalletMiddleware returns a Gin middleware that enforces rate limits per wallet address.
func (rl *RateLimiter) WalletMiddleware() gin.HandlerFunc {
	return rl.middleware(func(c *gin.Context) string {
		key := c.GetString("wallet")
		if key == "" {
			key = c.ClientIP()
		}
		return key
	})
}

func (rl *RateLimiter) middleware(keyFn func(*gin.Context) string) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := keyFn(c)
		rl.mu.Lock()
		e, exists := rl.visitors[key]
		now := time.Now()

		if !exists || now.After(e.windowEnd) {
			rl.visitors[key] = &entry{count: 1, windowEnd: now.Add(rl.window)}
			rl.mu.Unlock()
			c.Next()
			return
		}

		e.count++
		if e.count > rl.limit {
			rl.mu.Unlock()
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded, try again later",
			})
			return
		}
		rl.mu.Unlock()
		c.Next()
	}
}
