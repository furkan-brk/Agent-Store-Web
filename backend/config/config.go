package config

import "os"

type Config struct {
	Port            string
	PostgresDSN     string
	JWTSecret       string
	ClaudeAPIKey    string
	GeminiAPIKey    string
	ReplicateAPIKey string
	AllowedOrigins  string
	MonadRPCURL     string
	CreditsContract string
	TreasuryWallet  string // wallet address to receive MON for credit top-ups
}

func Load() *Config {
	return &Config{
		Port:            getEnv("PORT", "8080"),
		PostgresDSN:     buildDSN(),
		JWTSecret:       getEnv("JWT_SECRET", "dev_secret_change_me"),
		ClaudeAPIKey:    getEnv("CLAUDE_API_KEY", ""),
		GeminiAPIKey:    getEnv("GEMINI_API_KEY", ""),
		ReplicateAPIKey: getEnv("REPLICATE_API_KEY", ""),
		AllowedOrigins:  getEnv("ALLOWED_ORIGINS", "http://localhost:80,http://localhost:3000,https://agent-store-web-final.vercel.app"),
		MonadRPCURL:     getEnv("MONAD_RPC_URL", "https://testnet-rpc.monad.xyz"),
		CreditsContract: getEnv("CREDITS_CONTRACT_ADDRESS", ""),
		TreasuryWallet:  getEnv("TREASURY_WALLET", ""),
	}
}

func buildDSN() string {
	// Prefer full URLs injected by Railway (or other platforms), if present.
	if url := firstEnv("DATABASE_URL", "DATABASE_PRIVATE_URL", "DATABASE_PUBLIC_URL", "POSTGRES_URL"); url != "" {
		return url
	}

	// Fallback to host/port/user/password vars. Support both app-local and Railway PG* names.
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
