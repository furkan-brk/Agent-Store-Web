---
name: Avatar Prompt System v3 — Medieval Fantasy Redesign
description: Complete redesign from sci-fi robot to medieval fantasy illustration system; all 4 service files updated, shared BuildAvatarPrompt() architecture preserved
type: project
---

Avatar prompt system was completely redesigned on 2026-03-15. Switched from sci-fi pixel-art robots to medieval fantasy character illustrations (user's creative direction: "like Reddit Snoo avatars but medieval").

Key changes in v3:

1. **avatarPrompt const** — Replaced 16-bit pixel art robot prompt with "Detailed 2D medieval fantasy character illustration, rich painterly style, warm parchment tones, consistent storybook RPG art". Three-quarter view, contextual blurred medieval background, 1:1 square.

2. **7 placeholder reinterpretation** (order preserved):
   - %s[1] PrimaryColor → outfit main color (heraldic/jewel/earth tones)
   - %s[2] SecondaryColor → trim, cape, accents
   - %s[3] Characteristics[0] → headwear/facial features (hood, helm, spectacles, hat)
   - %s[4] Characteristics[1] → outfit/armor description
   - %s[5] Characteristics[2] → unique distinguishing feature (familiar, floating objects, aura)
   - %s[6] TabletGlowColor → magical glow/aura color
   - %s[7] Characteristics[3] → held item (staff, sword, book, lute, scales)

3. **GenerateAgentProfile instruction** — Full medieval world-builder prompt with explicit JSON schema, examples per field, rules prohibiting neon/cyber colors, requiring 8-20 word descriptive phrases per characteristic.

4. **buildFallbackProfile** — 8 rich medieval defaults (wizard=purple robes+pointed hat+amethyst staff, guardian=plate armor+tower shield+gargoyle companion, scholar=brown monk robes+spectacles+enchanted candle, merchant=gold doublet+trained raven+brass scales, etc.)

5. **sanitizeProfile defaults** — Medieval fallbacks: "Royal Purple", "Burnished Gold", "Amber", hood/robes/runes/oak staff.

6. **charTypeStyles** — All 8 entries rewritten to medieval fantasy style prefixes.

7. **replicateStylePrefixes** — Updated to match medieval theme.

8. **Pollinations negative prompt** — Extended to exclude "modern, sci-fi, futuristic, robot, neon".

**Why:** User wants Reddit-Snoo-like consistency — all characters from the same medieval world, but visually distinct per agent purpose. Knights, wizards, monks, bards, etc.

**How to apply:** The `BuildAvatarPrompt()` single-source-of-truth architecture is preserved. Edit only `avatarPrompt` const in gemini_service.go. All three image providers (Imagen, Pollinations, Replicate) pick it up automatically. When modifying fallback profiles, update both `buildFallbackProfile` in agent_service.go AND `sanitizeProfile`/`extractCharacteristics` defaults in gemini_service.go to stay consistent.
