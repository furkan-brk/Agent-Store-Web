---
name: Background Removal Pipeline Architecture
description: Pure Go chroma-key background removal — 4-pass magenta keying, PNG output, no external dependencies
type: project
---

The avatar pipeline uses a pure-Go chroma-key background removal system in `backend/services/aipipeline/rembg.go`. The Python rembg service was removed (2026-03-18).

**Architecture:**
- `BgRemover` struct with `NewBgRemover()` (no arguments)
- `RemoveBackground(base64Image string) ([]byte, string)` — returns image bytes + format ("png")
- `chromaKeyRemove(imgBytes []byte) ([]byte, string, error)` — unexported core algorithm

**4-pass algorithm:**
1. Hard magenta classification (RGB heuristic + HSV fallback) — mark transparent
2. Edge soft alpha + despill on border pixels (8-connected neighbours)
3. 1-pixel fringe erosion (remove isolated pixels with >= 6 transparent neighbours)
4. PNG encode with `BestCompression`

**Why:** Characters need transparent backgrounds for compositing. The Imagen avatar prompt always generates a solid magenta (#FF00FF) backdrop, so ML-based segmentation is unnecessary. Pure Go avoids the Docker complexity and memory overhead of the Python rembg sidecar.

**How to apply:** The `BgRemover` is a standalone utility — currently not wired into `PipelineService`. To integrate, add it as a field on `PipelineService`, call `RemoveBackground()` in the avatar handler after `GenerateImageWithFallback()`, and update the response format. The Dockerfile uses `CGO_ENABLED=0` so any future WebP encoding would require either enabling CGo + libwebp or finding a pure-Go WebP encoder.

## Key Decisions
- PNG output only (not WebP) because Docker build uses CGO_ENABLED=0 — no CGo-based WebP encoders available
- PNG BestCompression used to minimize file size within stdlib constraints
- Quality metrics logged: pixel removal %, processing time, output size
- No external dependencies added to go.mod

## Key Files
- `backend/services/aipipeline/rembg.go` — BgRemover struct, chromaKeyRemove(), helpers
- `backend/services/aipipeline/gemini.go` — avatarPrompt const (magenta background instructions)
- `backend/services/aipipeline/service.go` — PipelineService orchestrator (BgRemover NOT yet wired)
- `backend/services/aipipeline/handler.go` — Avatar endpoint (BgRemover NOT yet called)
