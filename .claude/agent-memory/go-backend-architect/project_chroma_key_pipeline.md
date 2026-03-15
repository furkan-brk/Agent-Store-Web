---
name: Chroma Key Pipeline — Green Screen
description: Avatar pipeline uses green screen (#00FF00) background with isGreenScreen() chroma key removal, portrait framing (belly-up), card_version field
type: project
---

Avatar generation pipeline uses a **green screen (#00FF00)** background with a pure-Go `chromaKey()` function that strips the background to transparency post-generation.

**Why:** Enables the Flutter frontend to composite character portraits onto custom card backgrounds. Switched from magenta to green screen (2026-03-15) to avoid color conflicts with character art that contained pink/magenta tones. The `card_version` field ("1.0" for legacy, "2.0" for new) lets the frontend decide which rendering path to use.

**How to apply:**
- `avatarPrompt` in `gemini_service.go` specifies portrait framing (belly upward), solid green (#00FF00) background, and anti-frame/border instruction
- `isGreenScreen()` in `agent_service.go` uses **dual detection**:
  - RGB check: G > 100, R < 180, B < 180, G exceeds both R and B by 30+
  - HSV check: hue 80-160 degrees, saturation > 0.2
  - Any match → fully transparent (no soft edges)
- Helper function `rgbToHSV()` does pure-Go RGB→HSV conversion (no external deps)
- Both `CreateAgent()` and `ForkAgent()` apply chroma key after `generateImageWithFallback()`
- Replicate prompt suffix also uses green #00FF00 background
- Pollinations uses `BuildAvatarPrompt()` which inherits the green screen from `avatarPrompt` const
- `card_version` added to Agent model with GORM default '1.0', set to "2.0" in CreateAgent/ForkAgent
- `card_version` included in ListAgents and GetTrending Select clauses
