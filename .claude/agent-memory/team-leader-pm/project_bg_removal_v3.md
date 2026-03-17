---
name: Background Removal v3.0 — Magenta Chroma Key Overhaul
description: Strategic decision to switch from green (#00FF00) to magenta (#FF00FF) chroma key and replace BFS flood-fill with global per-pixel detection + soft alpha edge refinement
type: project
---

On 2026-03-16, after coordinated analysis by bg-removal-architect, prompt-rag-architect, and go-backend-architect:

**Decision: Switch chroma key from green (#00FF00) to magenta (#FF00FF) and rewrite chromaKey algorithm.**

**Why:**
1. Green chroma key conflicted with Bard character type ("Lime Green" glow at agent_service.go line 933)
2. BFS edge-seeded flood-fill fundamentally cannot reach enclosed green pockets (between arm/torso, held items, etc.)
3. Frame scanning heuristic (40-80px depth) was fragile and often failed
4. Binary alpha (0 or 255) produced green fringe halos at character edges
5. Magenta has zero palette conflicts with any of our 8 character types

**New Algorithm: Global Replace + Edge Refinement (2-Pass)**
- Pass 1: `isMagenta()` global per-pixel threshold → all magenta pixels → transparent
- Pass 2: Edge pixels get soft alpha gradient (0-255) + magenta despill
- No flood-fill, no frame scanning, ~100 lines replacing ~200 lines
- Estimated ~80ms for 512x512 (well within 500ms budget)

**How to apply:** All avatar generation prompts must request #FF00FF background. The chromaKey function in agent_service.go needs full replacement. Replicate and Pollinations prompts also need magenta background instruction.
