---
name: Sprint v2.7 Status
description: Performance optimization, agent export for Claude Code, guild refinement, medieval avatars, 10 agent seeding
type: project
---

Sprint v2.7 completed on 2026-03-15. Key deliverables:

1. **Agent creation speed: 13.5min worst case → 90s max**
   - Image generation now races Imagen/Pollinations/Replicate in parallel (first wins)
   - Image gen overlaps with LLM analysis (4 goroutines instead of sequential)
   - Timeouts: Gemini 90s→45s, Pollinations 120s→30s (1 retry), Replicate 120s→45s
   - Hard 60s cap on total image generation time

2. **Agent export for Claude Code / Cursor**
   - ExportAgentWidget on agent detail page
   - Downloads CLAUDE.md, .cursorrules, or copies raw prompt
   - Client-side file generation via dart:html Blob

3. **Create agent state reset fix**
   - `_ctrl.reset()` in initState() — form always fresh on re-navigation

4. **Guild Master smart agent selection**
   - Multi-factor scoring: prompt_score*0.4 + log(use_count)*0.3 + log(save_count)*0.2 + tag_overlap*0.1
   - Returns up to 4 agents (2 per type), tag relevance matching
   - AI now returns reasoning_per_type and priority_tags

5. **10 seed agents** created via seed script (backend/cmd/seed/main.go)
   - Go Backend Architect, Flutter Frontend Dev, UI/UX Design Sage, DevOps Commander, Data Oracle, Security Guardian, API Design Architect, Code Review Knight, QA Test Strategist, Technical Scribe

**Why:** User needed faster creation, usable agents in Claude Code/Cursor (not web chat), smarter guild teams, and a populated store.

**How to apply:** These changes affect agent_service.go (parallel pipeline), agent_detail_screen.dart (export widget), guild_master_service.go (scoring), and create_agent_screen.dart (state reset).
