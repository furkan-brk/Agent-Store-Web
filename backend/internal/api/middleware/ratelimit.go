package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// entry tracks request count and window start for a single IP.
type entry struct {
	count     int
	windowEnd time.Time
}

// RateLimiter provides a simple per-IP sliding window rate limiter.
type RateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*entry
	limit    int
	window   time.Duration
}

// NewRateLimiter creates a rate limiter that allows `limit` requests per `window` per IP.
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*entry),
		limit:    limit,
		window:   window,
	}
	// Periodically clean up expired entries to prevent memory growth.
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

// Middleware returns a Gin middleware that enforces the rate limit.
func (rl *RateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()

		rl.mu.Lock()
		e, exists := rl.visitors[ip]
		now := time.Now()

		if !exists || now.After(e.windowEnd) {
			// Start a new window
			rl.visitors[ip] = &entry{count: 1, windowEnd: now.Add(rl.window)}
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
