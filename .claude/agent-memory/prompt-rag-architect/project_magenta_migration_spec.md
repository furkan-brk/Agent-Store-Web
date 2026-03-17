---
name: Magenta Chroma Key Migration — Final Spec
description: Complete change specification for green->magenta background switch across all 4 backend service files; 11 change blocks finalized 2026-03-16
type: project
---

On 2026-03-16, finalized the exact change specification for migrating avatar chroma key from green (#00FF00) to magenta (#FF00FF).

**Key design decisions in the new avatarPrompt:**
1. Background instruction is the FIRST sentence (~15 tokens) — front-loaded for maximum model attention
2. "clean digital painting style with defined edges" replaces "rich painterly style, warm parchment tones, storybook RPG art" — eliminates frame triggers
3. "Arms close to the body, held items overlap the torso, compact silhouette" — reduces interior background pockets
4. 7 %s placeholder order is UNCHANGED — BuildAvatarPrompt() needs zero sprintf changes
5. Magenta exclusion clause mirrors old green exclusion: "MUST NOT contain any magenta, hot pink, fuchsia, or #FF00FF"

**isMagentaish detection thresholds:**
- Primary: R > 120 AND B > 120 AND R > G+50 AND B > G+50
- Secondary HSV: hue 280-320 (tight window around magenta 300, protects wizard purple ~270 and artisan pink ~330+), saturation > 0.35

**Bard glow fix:** "Lime Green" -> "Golden Yellow" (was in isGreenish detection range)

**Pollinations tuning:** guidance 7.5->8.5, steps 20->25, negative prompt expanded with frame/border/vignette + magenta exclusion terms

**Replicate prompt:** Switched to magenta #FF00FF, "clean digital painting style", added "no frames, no borders"

**Why:** Green background conflicts with Bard (emerald/lime), Oracle (teal), and common medieval fantasy colors. Magenta has zero palette overlap with any of the 8 character types.

**How to apply:** This spec is a complete implementation guide. All 11 changes across 4 files are needed atomically — partial application will break chroma key (e.g., magenta prompt + green detection = no removal).
