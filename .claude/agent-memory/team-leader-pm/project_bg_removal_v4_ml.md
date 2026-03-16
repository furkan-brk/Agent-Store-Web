---
name: Background Removal v4.0 — Local ML via rembg Docker Service
description: Replaced fragile chroma key with color-agnostic ML background removal using local rembg Python microservice in Docker
type: project
---

On 2026-03-16, replaced chroma key (magenta #FF00FF) with ML-based background removal.

**Decision: Add local rembg microservice to Docker Compose for color-agnostic background removal.**

**Why:**
1. Chroma key is fundamentally fragile — characters contain every color in the spectrum (purple wizards, pink artisans, green bards)
2. No single chroma key color is safe; switching green→magenta just moved the problem
3. ML segmentation (ISNet) removes backgrounds by semantic understanding, not color thresholds
4. Local = zero per-image cost, fast (~2-4s on CPU), no external API dependency

**Architecture:**
- New Docker service: `rembg` (Python 3.11 + rembg + ISNet model) on port 5000
- Go backend POSTs image bytes to `http://rembg:5000/api/remove`
- chromaKey() preserved as fallback if rembg service is unavailable
- Magenta background still requested in prompts (helps ML contrast + fallback)
- Prompt constraint relaxed: characters can now include pink/fuchsia/purple freely

**Files changed:**
- Created: `rembg/Dockerfile`
- Modified: `docker-compose.yml`, `config.go` (RembgURL), `agent_service.go` (removeBackground method + 3 call sites DRY'd), `gemini_service.go` (relaxed prompt), `pollinations_service.go` (cleaned negative prompt)
- Also touched: `router.go`, `main.go` (pass rembgURL through)

**How to apply:** For Railway/production, deploy rembg as separate service or set REMBG_URL to Replicate API. Env var `REMBG_URL` makes deployment transparent.
