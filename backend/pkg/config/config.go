package config

import (
	"log"
	"os"
)

// Config holds all shared configuration for microservices.
type Config struct {
	Port            string
	PostgresDSN     string
	JWTSecret       string
	GeminiAPIKey    string
	ReplicateAPIKey string
	AllowedOrigins  string
	MonadRPCURL     string
	CreditsContract string
	TreasuryWallet  string
	RembgURL        string

	// Inter-service URLs
	AuthServiceURL      string
	AgentServiceURL     string
	AIPipelineServiceURL string
	GuildServiceURL     string
	WorkspaceServiceURL string
}

// Load reads environment variables and returns a populated Config.
func Load() *Config {
	jwtSecret := getEnv("JWT_SECRET", "dev_secret_change_me")

	env := getEnv("RAILWAY_ENVIRONMENT", getEnv("GO_ENV", "development"))
	if env == "production" && jwtSecret == "dev_secret_change_me" {
		log.Fatal("FATAL: JWT_SECRET must be set in production; refusing to start with default value")
	}

	return &Config{
		Port:            getEnv("PORT", "8080"),
		PostgresDSN:     buildDSN(),
		JWTSecret:       jwtSecret,
		GeminiAPIKey:    getEnv("GEMINI_API_KEY", ""),
		ReplicateAPIKey: getEnv("REPLICATE_API_KEY", ""),
		AllowedOrigins:  getEnv("ALLOWED_ORIGINS", "http://localhost:80,http://localhost:3000,https://agent-store-web-final.vercel.app,https://agent-store-web-seven.vercel.app"),
		MonadRPCURL:     getEnv("MONAD_RPC_URL", "https://testnet-rpc.monad.xyz"),
		CreditsContract: getEnv("CREDITS_CONTRACT_ADDRESS", ""),
		TreasuryWallet:  getEnv("TREASURY_WALLET", ""),
		RembgURL:        getEnv("REMBG_URL", "http://rembg:5000"),

		// Service URLs default to Docker service names
		AuthServiceURL:       getEnv("AUTH_SERVICE_URL", "http://authsvc:8081"),
		AgentServiceURL:      getEnv("AGENT_SERVICE_URL", "http://agentsvc:8082"),
		AIPipelineServiceURL: getEnv("AIPIPELINE_SERVICE_URL", "http://aipipelinesvc:8083"),
		GuildServiceURL:      getEnv("GUILD_SERVICE_URL", "http://guildsvc:8084"),
		WorkspaceServiceURL:  getEnv("WORKSPACE_SERVICE_URL", "http://workspacesvc:8085"),
	}
}

func buildDSN() string {
	if url := firstEnv("DATABASE_URL", "DATABASE_PRIVATE_URL", "DATABASE_PUBLIC_URL", "POSTGRES_URL"); url != "" {
		return url
	}

	host := firstEnv("POSTGRES_HOST", "PGHOST")
	if host == "" {
		host = "localhost"
	}
	port := firstEnv("POSTGRES_PORT", "PGPORT")
	if port == "" {
		port = "5432"
	}
	user := firstEnv("POSTGRES_USER", "PGUSER")
	if user == "" {
		user = "agent_user"
	}
	password := firstEnv("POSTGRES_PASSWORD", "PGPASSWORD")
	if password == "" {
		password = "agent_pass"
	}
	dbName := firstEnv("POSTGRES_DB", "PGDATABASE")
	if dbName == "" {
		dbName = "agent_store"
	}
	sslMode := getEnv("POSTGRES_SSLMODE", "disable")

	return "host=" + host +
		" port=" + port +
		" user=" + user +
		" password=" + password +
		" dbname=" + dbName +
		" sslmode=" + sslMode + " TimeZone=UTC"
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func firstEnv(keys ...string) string {
	for _, key := range keys {
		if v := os.Getenv(key); v != "" {
			return v
		}
	}
	return ""
}
