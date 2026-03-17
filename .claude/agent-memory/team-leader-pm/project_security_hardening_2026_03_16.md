---
name: Security Hardening Sprint 2026-03-16
description: Comprehensive security audit and fixes applied — 22 findings, all fixable ones resolved
type: project
---

Full security audit performed on 2026-03-16 with 22 findings (2 CRITICAL, 8 HIGH, 9 MEDIUM, 2 LOW, 1 INFO). All code-fixable issues resolved in the same session.

## Critical Fixes Applied
- On-chain tx verification via Monad RPC for purchase/topup (prevents fake tx_hash credits)
- ForkAgent prompt stripped (prevents IP extraction via forking)
- TopUpCredits now stores TxHash (prevents double-spend)

## High Fixes Applied
- GetUserProfile excludes prompt via .Select()
- GetLibrary uses scoped Preload excluding prompt
- Guild service: all 3 Preload("Members.Agent") now scoped to exclude prompt
- Guild-master endpoints require AuthMiddleware (prevents anon API credit drain)
- deductCredits uses DB transaction with FOR UPDATE (prevents race condition)
- legend_service deductCredits also fixed
- Nonce rotated after successful auth verification (prevents replay)

## Medium Fixes Applied
- All 500 error responses sanitized (generic messages, server-side logging)
- 2MB request body size limit added
- CORS restricted to agent-store*.vercel.app only, localhost only in non-prod
- Per-user rate limiting on AI endpoints (create: 10/hr, chat: 30/min, fork: 10/hr, gm: 20/min)
- Gemini API key moved from URL params to x-goog-api-key header (all services + genbg tool)
- GORM logger set to Warn in production
- Backend Dockerfile runs as non-root user (appuser)
- Nginx security headers added (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, etc.)
- Docker-compose default credentials warning added

## Known Accepted Risks
- Trial script contains AES-encrypted prompt with key fragments in same file (architectural limitation)
- JWT in localStorage (acceptable for Flutter Web SPA model)
- go-ethereum v1.13.14 should be checked with govulncheck periodically

**Why:** Production readiness and IP protection — prompts are the platform's core asset.
**How to apply:** When adding new endpoints or Preloads involving Agent model, always exclude the prompt field. When adding new AI-calling endpoints, always add auth + per-user rate limiting.
