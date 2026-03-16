package gateway

import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

// route maps a URL path prefix to a backend service URL.
type route struct {
	prefix string
	target string
}

// Proxy routes incoming requests to the appropriate backend microservice
// based on URL path prefix matching.
type Proxy struct {
	routes  []route
	proxies sync.Map // cached *httputil.ReverseProxy per target URL
}

// NewProxy creates a proxy with the routing table.
// Route order matters — more specific prefixes must come first.
func NewProxy(authURL, agentURL, guildURL, workspaceURL string) *Proxy {
	return &Proxy{
		routes: []route{
			// Auth Service
			{"/api/v1/auth", authURL},

			// Workspace Service (must be before generic /user)
			{"/api/v1/user/missions", workspaceURL},
			{"/api/v1/user/legend", workspaceURL},

			// Guild Service
			{"/api/v1/guilds", guildURL},
			{"/api/v1/guild-master", guildURL},

			// Agent Service (handles all remaining /user, /agents, and public routes)
			{"/api/v1/user", agentURL},
			{"/api/v1/agents", agentURL},
			{"/api/v1/trial", agentURL},
			{"/api/v1/users", agentURL},
			{"/api/v1/leaderboard", agentURL},
			{"/api/v1/images", agentURL},
		},
	}
}

// Handler returns a Gin handler that proxies requests to backend services.
func (p *Proxy) Handler() gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path

		var target string
		for _, r := range p.routes {
			if strings.HasPrefix(path, r.prefix) {
				target = r.target
				break
			}
		}
		if target == "" {
			c.JSON(http.StatusNotFound, gin.H{"error": "route not found"})
			return
		}

		// Inject wallet address as header for downstream services.
		if wallet, exists := c.Get("wallet"); exists {
			c.Request.Header.Set("X-Wallet-Address", wallet.(string))
		}

		rp := p.getOrCreateProxy(target)
		rp.ServeHTTP(c.Writer, c.Request)
	}
}

func (p *Proxy) getOrCreateProxy(target string) *httputil.ReverseProxy {
	if v, ok := p.proxies.Load(target); ok {
		return v.(*httputil.ReverseProxy)
	}

	u, _ := url.Parse(target)

	rp := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(u)
			pr.Out.Host = u.Host
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			log.Printf("[gateway] proxy error for %s %s -> %s: %v", r.Method, r.URL.Path, target, err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadGateway)
			w.Write([]byte(`{"error":"service unavailable"}`))
		},
	}

	p.proxies.Store(target, rp)
	return rp
}
