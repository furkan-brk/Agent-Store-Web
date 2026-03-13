---
name: Security and Performance Audit v2.6
description: Comprehensive backend audit — security fixes, dead code removal, rate limiting, input validation, TopUp replay fix
type: project
---

Completed a full audit of the Go backend in March 2026. Key changes:

**Security Fixes:**
- JWT_SECRET now fails loudly in production if set to default "dev_secret_change_me" (checks RAILWAY_ENVIRONMENT / GO_ENV)
- TopUpCredits txHash replay check was broken: AgentTitle field had `gorm:"-"` so the hash was never persisted. Added a real `tx_hash` column to CreditTransaction model and query by that column instead.
- ILIKE search patterns now escape `%`, `_`, `\` via `escapeLike()` to prevent wildcard injection
- Wallet address validation added at auth handler level using `^0x[0-9a-fA-F]{40}$` regex
- Transaction hash validation added at handler level using `^0x[0-9a-fA-F]{64}$` regex
- Rate limiting added on auth endpoints: 20 requests/minute per IP via `middleware/ratelimit.go`
- Input length validation: title (100), description (500), prompt (10000), comment (500), price bounds (0-1000), topup amount (0-10000)

**Dead Code Removal:**
- Deleted `ai_service.go` (legacy Claude integration, replaced by Gemini in v2.0)
- Removed `ClaudeAPIKey` from Config struct
- Removed `AIService` / `aiSvc` from AgentService constructor and router
- Router signature changed from 5 params to 4 (removed claudeAPIKey)

**Performance:**
- ListGuilds now uses selective Preload for Agent fields instead of full `Preload("Members.Agent")` — only fetches id, title, character_type, subclass, rarity, creator_wallet, generated_image

**Why:** These were identified as part of the v2.6 audit task. The TopUp replay bug was the most critical — any txHash could be reused since the field was never persisted.

**How to apply:** When adding new endpoints that accept blockchain txHashes, always validate format at handler level AND check uniqueness in a persisted DB column.
