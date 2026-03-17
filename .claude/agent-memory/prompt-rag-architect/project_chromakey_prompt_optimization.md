---
name: Chroma Key Prompt Optimization Analysis
description: Comprehensive analysis of avatar prompt weaknesses for background removal; recommends #00FF00 -> #FF00FF switch, front-loaded composition instructions, frame-vocabulary elimination, silhouette compactness guidance
type: project
---

On 2026-03-16, completed deep analysis of avatar generation prompt for chroma key background removal.

Key findings and decisions:

1. **Switch green (#00FF00) to magenta (#FF00FF)** — Green conflicts with Bard (Emerald/Lime Green), Oracle (Teal), and common medieval fantasy colors. Magenta has zero palette overlap with any character type. isGreenish -> isMagentaish detection has near-zero false positives.

2. **Front-load composition/background instructions** — Image models allocate more attention to early tokens. Previous prompt buried background instructions after 180+ tokens of style/character description. Move composition + background to the first 80 tokens.

3. **Remove "storybook RPG art" and "parchment tones"** — These are the primary triggers for Imagen adding ornamental frames/borders. Replace with "clean digital painting style with defined edges."

4. **Add silhouette compactness guidance** — "Arms close to body," "held items overlap torso," "no thin strands revealing background." Reduces interior green/magenta pockets that flood-fill can't reach.

5. **Bard fallback glow bug** — buildFallbackProfile uses "Lime Green" TabletGlowColor which falls within isGreenish detection range (hue 90-150). Must change to non-conflicting color.

6. **Replicate prompt inconsistency** — GeneratePixelArt builds its own prompt instead of using BuildAvatarPrompt. Still says green #00FF00 and "storybook RPG art." Should be refactored to use the shared template.

7. **Provider-specific notes:**
   - Imagen 4.0-fast: Add "studio green screen backdrop" metaphor. Worst frame offender. Check for native transparent background support via backgroundOptions API parameter.
   - Pollinations Flux: Expand negative prompt with frame/border terms. Increase guidance from 7.5 to 8.5. Increase steps from 20 to 25.
   - Replicate pixel-art-xl: Cleanest edges naturally. Needs prompt sync with BuildAvatarPrompt.

8. **Alternative approaches evaluated:**
   - White background: Rejected (white halos on dark UI theme)
   - Checkerboard: Rejected (models can't produce it reliably)
   - AI background removal (RMBG-2.0): Strong medium-term option, ~$0.001/image, 2s latency
   - Imagen native transparency: Worth investigating for Imagen-only path

**Why:** Current prompt produces frames, interior pockets, green fringe, and inconsistent backgrounds that break the flood-fill chromaKey algorithm.

**How to apply:** When editing avatar prompts, always front-load background/composition, avoid frame-triggering vocabulary, use magenta not green, and test against all 3 providers. The improved avatarPrompt template is in the conversation from 2026-03-16.
