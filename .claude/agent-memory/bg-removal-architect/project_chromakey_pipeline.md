---
name: ChromaKey Pipeline Architecture
description: Chroma key background removal pipeline details - transitioning from green (#00FF00) to magenta (#FF00FF) with Approach B (global replace + edge refinement)
type: project
---

The avatar pipeline generates images with chroma key backgrounds via Imagen 3, Pollinations Flux, or Replicate pixel-art-xl. The `chromaKey()` function in `agent_service.go` (line 670) removes the background and outputs transparent PNGs.

**Why:** Characters need transparent backgrounds for compositing onto themed scene backgrounds generated separately (see `backend/cmd/genbg/`).

**How to apply:** Any background removal changes must remain pure Go (no Python/ML), handle 3 different image providers with varying styles, and run under 500ms for 512x512 images. The function is called from 3 sites: CreateAgent (line 212), ForkAgent (line 403), and RegenerateImage (line 1057).

## v3.0 Migration (approved 2026-03-16)

- Switching from green (#00FF00) to magenta (#FF00FF) as key color
- Approach B (Global Replace + Edge Refinement) approved; flood fill + scanAndSeed eliminated
- 4-pass pipeline: hard classification -> soft alpha boundary -> despill -> 1px erosion
- Critical edge case: Artisan primary #EC4899 (236, 72, 153) nearly passes magenta detection. Mitigated by R/B symmetry check (ratio 0.35) and tightened HSV hue range [285, 320].
- Spec document: `backend/MAGENTA_CHROMAKEY_V3_SPEC.md`
- Prompt changes also required in gemini_service.go (line 62-63) and replicate_service.go (line 61) to switch from green to magenta background instructions.
