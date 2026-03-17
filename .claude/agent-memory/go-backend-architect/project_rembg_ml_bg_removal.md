---
name: rembg ML background removal service
description: Background removal migrated from chroma key to local rembg ML microservice via Docker sidecar, with chroma key as fallback
type: project
---

Background removal replaced from chroma-key-only to ML-based rembg service with chroma key fallback.

**Why:** Chroma key was fragile — required magenta (#FF00FF) background in image prompts, restricted character color palettes (no pink/fuchsia allowed), and produced edge artifacts. ML-based removal works on any background color and produces cleaner transparency.

**How to apply:**
- `rembg/Dockerfile` — Python 3.11-slim with rembg[cpu], isnet-general-use model pre-downloaded at build time
- `docker-compose.yml` — rembg service on port 5000, backend depends_on with health check
- `config.go` — `RembgURL` field (env: `REMBG_URL`, default: `http://rembg:5000`)
- `agent_service.go` — `removeBackground()` method: POST raw bytes to `/api/remove`, fallback to `chromaKey()` on any error, return original on double failure
- `AgentService` struct now has `rembgURL string` field, threaded through `NewAgentService()` -> `SetupRouter()` -> `main.go`
- `chromaKey()` and all helpers (isMagenta, magentaContribution, despillMagenta, rgbToHSV) preserved as fallback path
- Avatar prompt relaxed: characters may now include pink/rose/fuchsia/purple accents (no longer banned to protect chroma key)
- Pollinations negative prompt cleaned: removed `magenta clothing, pink clothing, fuchsia`
