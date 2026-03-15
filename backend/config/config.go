package config

import (
	"log"
	"os"
)

type Config struct {
	Port            string
	PostgresDSN     string
	JWTSecret       string
	GeminiAPIKey    string
	ReplicateAPIKey string
	AllowedOrigins  string
	MonadRPCURL     string
	CreditsContract string
	TreasuryWallet  string // wallet address to receive MON for credit top-ups
}

func Load() *Config {
	jwtSecret := getEnv("JWT_SECRET", "dev_secret_change_me")

	// Fail loudly in production if JWT_SECRET is the default insecure value.
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
	}
}

func buildDSN() string {
	// Railway injects DATABASE_URL when a PostgreSQL service is linked
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	return "host=" + getEnv("POSTGRES_HOST", "localhost") +
		" port=" + getEnv("POSTGRES_PORT", "5432") +
		" user=" + getEnv("POSTGRES_USER", "agent_user") +
		" password=" + getEnv("POSTGRES_PASSWORD", "agent_pass") +
		" dbname=" + getEnv("POSTGRES_DB", "agent_store") +
		" sslmode=disable TimeZone=UTC"
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
