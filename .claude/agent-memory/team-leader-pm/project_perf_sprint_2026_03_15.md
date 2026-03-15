---
name: Performance & DB Fix Sprint (2026-03-15)
description: Major backend optimization sprint — fixed DB race condition, hardcoded API keys, parallelized AI pipeline, added image fallback chain, optimized avatar prompts
type: project
---

Sprint executed on 2026-03-15 with 7 tasks, all completed.

**Critical bugs fixed:**
1. DB race condition — `database.DB` was nil when requests arrived before goroutine connected. Added `DBReadiness()` middleware returning 503 if DB not ready.
2. Hardcoded Gemini API key in 3 places in `gemini_service.go` — replaced with `g.apiKey`. Added API key guards to all methods.

**Performance optimizations:**
- Parallelized 3 independent AI calls in `CreateAgent()` using `sync.WaitGroup` (AnalyzePrompt + GenerateAgentProfile + ScoreAndDescribe run concurrently). Saves ~4-10s per agent creation.
- Switched from legacy `GenerateImage()` to profile-driven `GenerateAvatarImage()` in both CreateAgent and ForkAgent.
- Added `generateImageWithFallback()` method: Imagen → Pollinations → Replicate fallback chain.
- Extracted shared `BuildAvatarPrompt()` function and `avatarPrompt` constant — reduced prompt size by ~40% (~350 chars vs ~1200 chars). Shared across gemini_service.go and pollinations_service.go.
- Optimized AnalyzePrompt system prompt — compressed from ~1200 chars to ~500 chars.

**Why:** User reported "no DB connection works" and slow image generation. Root causes were nil pointer dereference on startup race, wrong API key usage, sequential pipeline, and unused fallback providers.

**How to apply:** These patterns (DB readiness middleware, parallel AI calls, fallback chains) should be followed for any new service integrations. The `BuildAvatarPrompt` shared template should be updated in one place if visual style changes.
