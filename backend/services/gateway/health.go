package gateway

import (
	"context"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// ServiceHealth describes one downstream service for health aggregation.
type ServiceHealth struct {
	Name string `json:"name"`
	URL  string `json:"-"`
	OK   bool   `json:"ok"`
}

// HealthHandler returns a Gin handler that pings every downstream service's
// /health endpoint in parallel and returns an aggregated status.
func HealthHandler(services []ServiceHealth) gin.HandlerFunc {
	client := &http.Client{Timeout: 3 * time.Second}

	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
		defer cancel()

		results := make([]ServiceHealth, len(services))
		copy(results, services)

		var wg sync.WaitGroup
		for i := range results {
			wg.Add(1)
			go func(idx int) {
				defer wg.Done()
				req, err := http.NewRequestWithContext(ctx, "GET", results[idx].URL+"/health", nil)
				if err != nil {
					return
				}
				resp, err := client.Do(req)
				results[idx].OK = err == nil && resp != nil && resp.StatusCode == http.StatusOK
				if resp != nil {
					resp.Body.Close()
				}
			}(i)
		}
		wg.Wait()

		allOK := true
		for _, s := range results {
			if !s.OK {
				allOK = false
				break
			}
		}

		status := http.StatusOK
		statusStr := "ok"
		if !allOK {
			status = http.StatusServiceUnavailable
			statusStr = "degraded"
		}

		c.JSON(status, gin.H{
			"status":   statusStr,
			"service":  "gateway",
			"services": results,
		})
	}
}
