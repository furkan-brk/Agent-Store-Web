---
name: Image CDN Service & BG Removal Rewrite
description: v2.8 rewrite — images saved to disk as WebP, served via URL (not base64), rembg FastAPI rewrite, ImageService abstraction
type: project
---

Images are now saved to disk (`./uploads/agents/{id}.webp`) and served via `/api/v1/images/agents/{id}.webp` with immutable cache headers. The `image_url` field on Agent model holds the relative URL path.

**Why:** Base64 images in PostgreSQL TEXT columns caused 5MB+ list API responses (267KB x 20 agents). Moving to file-based storage with URL references reduces JSON payload to kilobytes.

**How to apply:**
- List endpoints (ListAgents, GetTrending, GetLibrary, GetUserProfile) SELECT `image_url` instead of `generated_image` — no base64 in list responses
- Detail endpoint (GetAgent) still includes both `generated_image` (for backward compat) and `image_url`
- `GeneratedImage` json tag has `omitempty` — empty string won't serialize
- `ImageURL` json tag has `omitempty` — old agents without URL won't have null in JSON
- `processAndSaveImage()` is the unified method: removeBackgroundToBytes -> ImageService.SaveAgentImage -> DB update
- rembg service is now a custom FastAPI app (server.py) returning WebP directly, not the raw rembg CLI server
- Docker: backend volume `uploads_data:/app/uploads` persists images across deploys
- Image serving: `GET /api/v1/images/*filepath` with directory traversal protection and 1-year cache headers
