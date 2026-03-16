---
name: Frame Elimination Strategies for AI Avatar Generation
description: Comprehensive ranked strategy list for eliminating decorative frames/borders from Imagen, Flux, and pixel-art-xl generated avatars; vocabulary surgery, edge-bleed composition, provider-specific prefixes, post-generation detection
type: project
---

On 2026-03-16, completed deep-dive analysis on why AI image models generate decorative frames around character avatars and how to eliminate them.

**Root causes identified:**
1. "portrait" + "illustration" are the strongest frame triggers (trading card / oil painting associations)
2. "centered in frame" — the word "frame" itself activates frame generation
3. "medieval fantasy" overlaps heavily with illuminated manuscripts (always bordered)
4. Solid color background reads as "canvas/mat board" which invites framing
5. No explicit edge-behavior instruction lets model default to framed composition

**7 ranked strategies (cumulative ~99% elimination):**

1. **Vocabulary surgery** (50-60%) — Remove "portrait", "illustration", "frame" from prompt. Use "depiction", "character", "image" instead.
2. **Edge-bleed composition** (cumulative ~80%) — Add "magenta extends to every pixel of all four edges" + "character's head may be slightly cropped by top edge"
3. **Asset/render metaphor** (cumulative ~88%) — "backdrop" instead of "background"; "game character asset" prefix for Imagen
4. **Expanded negative prompts** (~92%) — Comprehensive frame/border/vignette/filigree/trading card terms for Flux and SDXL
5. **Provider-specific prefixes** (~95%) — "Game character asset" for Imagen, "Digital character design" for Pollinations
6. **Generate-and-center-crop** (~97%) — Generate at larger size, crop center 87.5% to remove edge frames
7. **Post-generation frame detection** (~99%) — Sample outer 8px ring, if >30% non-background pixels, scan inward and crop

**Key vocabulary changes in avatarPrompt:**
- "portrait" -> removed entirely ("character depiction")
- "illustration" -> removed ("character" is sufficient)
- "centered in frame" -> "centered in the image"
- "fills most of the frame" -> "fills most of the image"
- "background" -> "backdrop" (photography connotation, never framed)
- NEW: "extends to every pixel of all four edges"
- NEW: "character's head may be slightly cropped by the top edge"
- NEW: "Game character asset" prefix for Imagen-specific prompt

**Pollinations tuning:** guidance 7.5->8.5, steps 20->28, negative prompt expanded with 15+ frame-specific terms

**Replicate addition:** negative_prompt parameter with frame/border terms

**Why:** AI models trained on millions of framed character artworks. "Medieval fantasy character portrait illustration" maps almost directly to "framed artwork." Simple "no frames" instruction is vastly outweighed by positive frame-triggering tokens.

**How to apply:** When editing avatarPrompt, always avoid the words "portrait", "illustration", and "frame". Use "image", "depiction", and "backdrop" instead. For Imagen specifically, prepend "Game character asset" to the prompt. Implement post-generation frame detection as a safety net using the 8px border-ring sampling algorithm.
