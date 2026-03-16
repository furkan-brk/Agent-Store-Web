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

**v4.0 Phase 1 (rembg service):**
- Created: `rembg/Dockerfile`, `rembg/server.py` (FastAPI)
- Modified: `docker-compose.yml`, `config.go`, `agent_service.go`, `gemini_service.go`, `pollinations_service.go`, `router.go`, `main.go`

**v4.0 Phase 2 (Image CDN + WebP):**
- Custom FastAPI server in rembg: bg removal + WebP output in one call
- New `ImageService` in Go: saves WebP to `uploads/agents/{id}.webp`
- New endpoint: `GET /api/v1/images/*filepath` (1-year cache headers, traversal protection)
- New `image_url` field on Agent model (omitempty), list queries exclude `generated_image`
- `processAndSaveImage()` orchestrates: bg removal → disk save → DB update
- Docker: `uploads_data` named volume for persistent image storage
- Frontend: 12 files updated, `Image.network(url)` with shimmer loading + base64 fallback
- Backwards compatible: old agents without image_url still work via base64

**How to apply:** For Railway/production, deploy rembg as separate service or set REMBG_URL to Replicate API. Env var `REMBG_URL` makes deployment transparent.
