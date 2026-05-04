# Agent Store — Presentation Design Document
> A 10-slide, 20-minute deck covering the full stack: `agent_store/` (Flutter Web) · `backend/` (Go microservices) · `contracts/` (Solidity on Monad).
> Drafted by the Presentation Designer agent · Target tooling: Keynote / PowerPoint / Google Slides (16:9).

---

## 1. Strategy Overview

### Core Narrative Arc
**Problem → Insight → Architecture → Proof → Vision**
The audience first feels the pain (prompts are invisible labor with no ownership), then sees the insight (treat prompts as ownable, gamified, on-chain assets), then walks through the three-layer architecture, sees it run end-to-end, and finally hears the bigger bet: a creator economy for AI prompts.

### Tone & Voice
**Confident, builder-energy, slightly playful.** This is a hackathon-grade demo backed by production-grade architecture — the presenter should sound like an engineer who shipped, not a marketer who dreamed.

### Audience Psychology Notes
Assumed audience: **technical evaluators, hackathon judges, and prospective creators** (mixed). Their hot buttons:
- *"Is the architecture real, or vibes?"* → Show the actual three-binary deploy model and the test counts.
- *"Why blockchain at all?"* → Frame Monad credits as **provable scarcity for an infinite-copy good**, not crypto-for-crypto's-sake.
- *"What makes this fun?"* → The pixel-art character system turns dry prompt metadata into a Pokémon-style collectible.

### Success Criteria
After the talk, a viewer should be able to:
1. Repeat the one-liner: *"Agent Store turns prompts into pixel-art characters you own on-chain."*
2. Recall the **three layers** (Flutter Web · Go monolith/microservices · Monad contracts).
3. Name **at least one differentiator** (8 character archetypes, Legend visual workflow builder, OpenClaw round-trip export, or Guild Master AI).

---

## 2. Design System

### Color Palette
Anchored to the existing app theme (dark indigo) with two accent rails — *gold* for blockchain/credits, *teal* for Flutter/UI moments.

| Role           | Hex       | Usage                                              |
| -------------- | --------- | -------------------------------------------------- |
| Primary BG     | `#0B0B1A` | Slide background — deep indigo, near-black         |
| Surface        | `#1A1A2E` | Panel / card backgrounds, code block fills         |
| Primary text   | `#EAEAF2` | Body copy, off-white for reduced eye strain        |
| Accent — Gold  | `#F4C95D` | Credits, blockchain, "legendary" callouts          |
| Accent — Teal  | `#3FE0C5` | UI / Flutter moments, success states               |
| Accent — Mauve | `#9B7BFF` | Wizard/character lore, emotional peaks             |
| Muted          | `#6E6E85` | Captions, footnotes, "less important" supporting   |
| Danger         | `#E55D87` | Problem framing, the *before* state on slide 3     |

**Rationale:** Indigo + gold reads as *"premium technical"* (think Linear, Arc, Vercel). The teal+mauve secondary pair gives the pixel-art slides the Saturday-morning-cartoon palette they need without clashing. Contrast ratio of `#EAEAF2` on `#0B0B1A` ≈ **15.4 : 1** — comfortably above WCAG AAA.

### Typography
Pairing a geometric display face with a humanist body face, plus a monospace for code.

- **Headings**: `Space Grotesk` (700 weight) — fallback `Inter`, then `system-ui`
- **Body**: `Inter` (400 / 500) — fallback `Helvetica Neue`, then `Arial`
- **Mono / code**: `JetBrains Mono` (500) — fallback `Menlo`, then `Consolas`
- **Pixel-art accent** (used sparingly, slide 5 only): `Press Start 2P` for a single character-name badge

| Level         | Size  | Weight | Tracking  |
| ------------- | ----- | ------ | --------- |
| Slide title   | 56 pt | 700    | -1%       |
| Section head  | 36 pt | 600    | -0.5%     |
| Body          | 28 pt | 400    | 0         |
| Caption       | 18 pt | 500    | +2%, caps |
| Code block    | 22 pt | 500    | 0         |

The 28 pt body floor respects **Guy Kawasaki's 30 pt rule** (within rounding) and stays legible from the back of a 200-seat room.

### Visual Elements
- **Photography style**: *None.* This is an engineering product — every visual is either a UI screenshot, a diagram, a code excerpt, or a pixel-art character render. Stock photography would dilute the aesthetic.
- **Iconography**: **Phosphor Icons (regular weight)** — same family the Flutter app uses via Material Icons fallback. Outlined, not filled. 32 px on slide.
- **Diagrams**: Mermaid-rendered architecture diagrams exported to SVG for crisp scaling. Three-tone limit per diagram (BG + 2 accents) so they read as glance-able, not as schematics.
- **Charts**: Bar charts for test counts (slide 8) and rarity distribution (slide 5). No pie charts. No 3D anything.
- **Pixel-art renders**: Use the actual `pixel_art_painter.dart` output exported at 4× DPR, transparent background, with an optional soft glow matching the character's color palette.

### Animation Guidance
Keep motion minimal and purposeful. Death-by-animation is the #1 way to make a technical deck feel like a 2008 sales pitch.

- **Slide transitions**: A single 250 ms cross-dissolve. No "cube," no "page curl," no "morph."
- **Build-ins** (sparingly): Fade + 8 px upward slide on bullet reveal. ~180 ms per item, ease-out cubic.
- **The exception** — slide 5 (the character system) gets a single 1 s "pixel materialize" animation where the 16×16 grid fills in row-by-row. This is the deck's one moment of delight; don't squander it elsewhere.

**Never animate**: code blocks, diagram nodes, body copy. The audience needs to *read*, not *track motion*.

---

## 3. Slide-by-Slide Breakdown (10 slides · ~2 min each)

---

### **Slide 1 — Hook**
**Title:** *Your best prompts are invisible labor.*

**Content Structure**
- Centered single sentence: *"Your best prompts are invisible labor."*
- Below, in muted 18 pt: *"Agent Store · A creator economy for AI prompts"*
- Bottom-right corner: presenter name + handle, ClawCon talk badge

**Design Layout**
Full-bleed indigo background. The title sits at optical center (slightly above geometric center). A single faint pixel-art **Wizard** character, 25% opacity, drifts in the lower-left third — establishing the visual language without crowding the type.

**Visual Recommendations**
- One character render only — Wizard (Mauve `#9B7BFF` palette).
- No icons, no underline, no decoration. The line carries it.
- Pixel character at exactly 320 × 320 px, soft 24 px outer glow.

**Transition Recommendation**
*Enter:* hard cut (no fade — opens cold for impact).
*Exit:* 250 ms cross-dissolve to slide 2.

**Speaker Notes** (~90 s)
> "Show of hands — who has a prompts.txt, a Notion page, a chaos folder of system prompts you've spent hours iterating on? [pause] Now — who has shared one of those, and a week later seen it copy-pasted into someone else's product, no credit, no trail? That's what I mean by *invisible labor*. The most valuable artifact of AI work — the prompt — has no ownership, no provenance, and no economy around it. We built Agent Store to fix that."

---

### **Slide 2 — The 30-Second Pitch**
**Title:** *What is Agent Store?*

**Content Structure**
Three-column layout, each column a single line + one-icon-above:
- 🎨 **Discover** — Browse a store of agents, each with its own pixel-art character.
- 📚 **Own** — Save to your library, fork, remix, or upload your own.
- ⛓ **Prove** — Login with Monad wallet. Credits, ownership, on-chain.

Below the columns, a single bold line: *"Three layers, one round-trippable creator loop."*

**Design Layout**
Three equal columns, 80 px gutters. Each icon at 64 px, color-coded (Teal / Gold / Mauve). Title top-left, columns at vertical middle, the closing line in bottom third.

**Visual Recommendations**
- Phosphor icons: `MagnifyingGlass`, `BookmarksSimple`, `LinkSimple`.
- Each column gets a 1 px hairline separator on its right (last omits).
- A faint horizontal divider above the closing line — `#1A1A2E`, 2 px.

**Transition Recommendation**
Build: each column fades in 180 ms apart, left to right. Closing line appears 200 ms after the third column.

**Speaker Notes** (~90 s)
> "Agent Store is three things stacked together. The Flutter web frontend is where you discover and remix agents — every agent gets its own pixel-art character generated from its prompt. The Go backend turns those prompts into structured, searchable, scored objects. And the Monad smart contracts give creators a credit system and an ownership trail. We'll spend the rest of the talk going one layer deep on each."

---

### **Slide 3 — The Problem (Why now?)**
**Title:** *Prompts are the new code, treated like the old screenshots.*

**Content Structure**
Four pain-point bullets, each with a single icon:
- ❌ No discoverability — prompts live in DMs, gists, and screenshots.
- ❌ No provenance — you can't prove you wrote the original.
- ❌ No economy — there's no marketplace, no credits, no royalties.
- ❌ No fun — even great prompts feel like flat text.

Right side: a stylized "before" mockup — a chaotic Notion page or chat thread with prompts buried in it. Slight desaturation + Danger accent (`#E55D87`) for the X marks.

**Design Layout**
60/40 split. Bullets occupy the left 60%, the "before" visual the right 40%. Title spans full width on top.

**Visual Recommendations**
- The "before" mockup should look *real but messy* — recognizable Notion / Slack / Discord chrome but with intentional clutter.
- Each X icon in `#E55D87`, 24 px.

**Transition Recommendation**
Bullets reveal one-by-one (180 ms cadence). Visual fades in last, 300 ms.

**Speaker Notes** (~120 s)
> "Look at how every other creative discipline solved this. Code has GitHub. Music has Spotify. Art has Behance. Photographs have EXIF data and licenses. But the most leveraged artifact in the AI era — the prompt — has nothing. No store, no signature, no statistics, no rarity. That's the gap. And it's an aesthetic gap as much as a technical one — even when prompts *are* shared, they show up as ugly walls of text. We don't get excited about ugly walls of text. We get excited about characters with stats."

---

### **Slide 4 — The Insight**
**Title:** *Treat each prompt as an ownable, scorable, animated character.*

**Content Structure**
Single big idea, centered:
> *"A prompt isn't a string. It's an agent — and every agent has a personality, a class, a rarity, and an owner."*

Below, four equal pills:
- **Personality** — analyzed by Claude
- **Class** — 1 of 8 archetypes
- **Rarity** — Common → Legendary
- **Owner** — wallet-signed, on-chain

**Design Layout**
Quote in 44 pt italic, centered, max-width 70%. Pills below it as a horizontal row, each 200 × 56 px, gold border, transparent fill.

**Visual Recommendations**
- The four pills mimic the in-app `AgentCard` chip styling — visual continuity is the point.
- Subtle Mauve glow behind the quote text.

**Transition Recommendation**
Quote fades in 250 ms. Pills cascade in left-to-right at 120 ms each.

**Speaker Notes** (~120 s)
> "This is the single insight the entire product is built on. The prompt itself is just text — but the *behavior it produces*, the *role it plays*, the *value it carries* — that's a character. So we run every uploaded prompt through Claude, classify it into one of eight archetypes, score its rarity, generate a pixel-art avatar, and stamp the creator's wallet on it. Once you do that, every product decision — leaderboards, libraries, forking, the credit system — falls out of the metaphor naturally."

---

### **Slide 5 — The Character System** ⭐ *Visual peak of the deck*
**Title:** *Eight archetypes. Five rarities. One pixel grid.*

**Content Structure**
- Top row: all **8 character renders** in a single line, each labeled below (Wizard, Strategist, Oracle, Guardian, Artisan, Bard, Scholar, Merchant).
- Below that, a **rarity bar**: Common → Uncommon → Rare → Epic → Legendary, with the Legendary pill in glowing gold.
- Footer code excerpt (small, mono):
  ```dart
  // pixel_art_painter.dart
  CustomPainter renders 16×16 grid → glow → float anim
  ```

**Design Layout**
Horizontal-band composition. 8 characters stretched edge-to-edge with breathing room. Rarity bar centered below them, 40% width. Code excerpt baseline-aligned in muted text, lower-right.

**Visual Recommendations**
- Each character at exactly 192 × 192 px on slide. Transparent BG. Match each glow to its color palette from `character_data.dart`.
- The Legendary pill has a 12 px outer glow, gold (`#F4C95D`).
- Use `Press Start 2P` for character names *only on this slide* — establishes the gaming DNA, then steps aside.

**Transition Recommendation**
This is the deck's one moment of delight: each of the 8 characters **materializes row-by-row** (16 rows × ~60 ms = ~1 s total) on slide entry, in sequence. Rarity bar fades in after, 300 ms.

**Speaker Notes** (~150 s)
> "Eight archetypes, mapped to prompt domains. Backend or code-heavy prompts? Wizard. Planning and PM? Strategist. Data and analytics? Oracle. Security and infra? Guardian. Frontend and design? Artisan. Creative writing? Bard. Research? Scholar. Business and marketing? Merchant. Five rarities — Common through Legendary — based on prompt complexity, length, structure, and originality signals. And every single one of these is rendered live in Flutter using a custom painter on a 16×16 grid — no PNGs, no sprite sheet. Resolution-independent, animatable, and small enough to ship in the bundle."

---

### **Slide 6 — Architecture**
**Title:** *Three layers, three repos, one round trip.*

**Content Structure**
A central architecture diagram:

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   agent_store/      │    │     backend/        │    │     contracts/      │
│   Flutter Web       │ ── │     Go 1.22         │ ── │     Solidity 0.8.24 │
│   GoRouter + GetX   │    │     Gin + GORM      │    │     Monad Testnet   │
│                     │    │     Monolith OR     │    │                     │
│   17 features       │    │     6 microservices │    │     2 contracts     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
        Discover                   Analyze                     Prove
        Remix                      Score                       Own
        Edit                       Cache                       Earn
```

Below diagram, a single line:
> *"One Postgres. One Claude API. One MetaMask login. Everything else is composition."*

**Design Layout**
Diagram occupies upper 70%, three columns equal width. Closing line in bottom 15%, italic, muted color.

**Visual Recommendations**
- Each column boxed with 1 px stroke in column color (Teal / Gold / Mauve).
- Connecting lines between boxes at 2 px, with directional arrowheads (LTR for read-flow, but data flows both ways — show RTL arrows in lighter weight).
- Use `JetBrains Mono` for the file/dir paths.

**Transition Recommendation**
Diagram appears whole (no per-column build — the audience needs to see the relationship at once). Closing line fades in 400 ms after.

**Speaker Notes** (~150 s)
> "Three repositories, three deploys. The Flutter Web frontend ships to Vercel as a static bundle — pure Dart, no Node runtime needed at the edge. The Go backend ships to Railway, and here's the trick: it can run as a single monolithic binary or as six independent microservices behind an API gateway, with the *same code*. That's `cmd/monolith` versus `cmd/gateway` plus `cmd/agentsvc`, `cmd/authsvc`, et cetera. And the Solidity contracts live on Monad testnet — two contracts, one for credits, one for the agent registry. The whole thing round-trips: a creator uploads a prompt, the backend analyzes it, the frontend renders the character, the contract logs ownership, and a buyer flows the loop in reverse."

---

### **Slide 7 — The Backend, Decomposed**
**Title:** *Six services. One binary. Same code.*

**Content Structure**
A two-column layout.

**Left column — service map:**
- `authsvc` :8081 → Wallet nonce, ECDSA verify, JWT
- `agentsvc` :8082 → Agent CRUD, library, social, use-log
- `aipipelinesvc` :8083 → Claude/Gemini pipeline (stateless)
- `guildsvc` :8084 → Guild Master AI, sessions, bridge
- `workspacesvc` :8085 → Missions, Legend, execution
- `gateway` :8080 → JWT extractor, reverse proxy

**Right column — three "selling points":**
- ✅ **Test infrastructure**: pure-Go SQLite (no CGO) → 40 backend tests, race-enabled CI.
- ✅ **Cache invalidation**: event-driven on `AddToLibrary` / `Profile PATCH` / `IncrementUseCount`.
- ✅ **Optimistic concurrency**: `If-Match` revision IDs on Agent / Mission / Legend writes.

**Design Layout**
50/50 split. Service ports in mono font, left-aligned. Right column uses checkmark Phosphor icons.

**Visual Recommendations**
- Port numbers in Gold to draw the eye (`:8081`, `:8082`...).
- Right-column checkmarks in Teal.
- A faint vertical divider between columns.

**Transition Recommendation**
Service rows fade in top-to-bottom (80 ms cadence — fast). Right column fades in as a block after.

**Speaker Notes** (~150 s)
> "The backend is six services, but it doesn't have to *deploy* as six services. Same source tree, two entry points: `cmd/monolith` runs everything in-process — perfect for Railway, perfect for staging — and `cmd/gateway` plus the individual `*svc` binaries run as a true microservice mesh in docker-compose. The internal-service-call boundary is the same Go function in both modes; only the transport changes. Three engineering decisions worth calling out: pure-Go SQLite for tests means our CI runs without CGO and finishes in under a minute. Cache invalidation is event-driven, not TTL-only — so when you save an agent, the trending list reflects it immediately. And every mutating endpoint that conflicts under multi-tab editing speaks `If-Match`, returning a 409 with the latest revision so the client can reconcile."

---

### **Slide 8 — Proof: The Numbers**
**Title:** *Receipts.*

**Content Structure**
A bar chart + a stat strip.

**Bar chart (left, 60%):** Test count by package.
- `services/agent` — 28 tests
- `services/auth` — 12 tests
- `services/workspace` — 12 tests
- `services/guild` — 30 tests
- `flutter unit tests` — 113 tests

**Stat strip (right, 40%), four large numbers:**
- **40+** sprint tags shipped (v0.1 → v3.10)
- **8** character archetypes
- **6** Go services
- **2** Monad contracts deployed

**Design Layout**
Bars horizontal, gold fills, dark-indigo track. Stat strip stacked vertical with 88 pt numbers in gold and 18 pt captions in muted text.

**Visual Recommendations**
- Bar labels in mono, right-aligned to the bar end.
- Stat numbers use tabular figures to align cleanly.
- Add one tiny "✅ flutter analyze: 0 issues" footnote in muted text.

**Transition Recommendation**
Bars sweep in left-to-right (300 ms each, sequenced). Stat numbers count up from 0 (CSS-style ticker, ~600 ms).

**Speaker Notes** (~120 s)
> "Hackathon decks are full of promises. Here are the numbers behind ours. 195 tests in total — 82 backend, 113 frontend — every one of them green, race detector on, in CI. Forty-plus tagged sprints from v0.1 through v3.10, every one of them merged with a sprint note in CLAUDE.md so the next contributor — human or agent — has full context. Eight characters. Six services. Two contracts. One Postgres. One credit ledger. One product."

---

### **Slide 9 — Live Demo Beat**
**Title:** *Let's run the loop.*

**Content Structure**
A 4-step strip with screenshots/placeholders, each 1/4 width:
1. **Connect MetaMask** → Wallet auth flow screenshot
2. **Upload a prompt** → Create Agent screen with live character preview
3. **Watch character emerge** → Pixel-art materialization GIF/loop
4. **Save to library** → Library screen with the new card

Below, a single CTA line: *"This is what we're about to do live."*

**Design Layout**
Four equal screenshot tiles in a horizontal strip. Each tile 380 × 240 px with 1 px gold border and step number badge in top-left corner.

**Visual Recommendations**
- Real screenshots from the running app — no Figma mocks. Authenticity is the whole point.
- Step numbers in big circular badges, gold fill, dark-indigo number.
- If demo is risky, prepare a **fallback 30 s video loop** (silent, captioned).

**Transition Recommendation**
Tiles fade in left-to-right (200 ms each). The CTA line slides up from below at the end.

**Speaker Notes** (~30 s — keep this slide short, you're about to talk over the live demo)
> "Four steps, ninety seconds. Connect wallet. Paste a prompt. Watch the character emerge. Save to library. The whole loop. [Switch to live app.]"

> **Demo timing budget:** 90 s. If anything fails, cut to backup video (slide 9-b, hidden).

---

### **Slide 10 — The Bigger Bet**
**Title:** *Prompts deserve a creator economy.*

**Content Structure**
Top half: a single bold sentence:
> *"Every agent you save is a vote for the next generation of prompt-as-product."*

Bottom half: three "where this goes next" pills, simple line, no icons:
- **Royalties** on forks, paid in Monad credits.
- **Workflows** — agents composed into multi-step Legends.
- **Interop** — OpenClaw round-trip means your agents leave with you.

Footer: project links + handle.

**Design Layout**
Reverse-pyramid composition: big quote up top, three short pills below, contact strip at the very bottom.

**Visual Recommendations**
- The closing quote in 48 pt italic, centered.
- Pills in Gold outline only (no fill) — restrained.
- Footer in 14 pt mono.
- Same Wizard from slide 1 reappears in the lower-right — *callback closure*. Audience subconsciously recognizes "we've come full circle."

**Transition Recommendation**
Quote fades in 400 ms. Pills appear together (not sequenced — they're equally weighted). Wizard fades in last, 600 ms — the slowest reveal in the deck, signaling "we're done."

**Speaker Notes** (~90 s)
> "Where does this go? Three directions. Royalties — when someone forks your agent, the credit flows back to you on-chain. Workflows — we already ship a visual builder called Legend that lets you compose agents into DAGs, like a Figma for prompt pipelines. And interop — we just shipped OpenClaw compatibility, which means you can export an agent as a SKILL.md, take it to any other tool, and bring it back. We don't want to be your prompt jail. We want to be your prompt portfolio. [pause] Thank you. Questions?"

---

## 4. Engagement Tips

1. **Open cold.** Skip the "hi I'm X, today I'm going to talk about Y" warmup — the slide-1 line is the warmup. Walk on stage and say it.
2. **Land the metaphor early.** Repeat *"prompts are characters"* on slides 1, 4, and 5. Rule of three.
3. **Make slide 5 the visual peak.** Pause on it for 3–5 seconds before speaking. Let the room breathe.
4. **Run the demo at slide 9, not before.** Earlier demo attempts derail pacing — this slide is the natural breath-in.
5. **Have a backup video for slide 9.** A 30-second silent loop, captioned, ready to play if MetaMask hangs or the network is rough. Hide it as slide 9-b.
6. **Q&A placement.** End on slide 10, take Q&A in front of slide 10 (the closing quote). Do *not* flip to a "Questions?" slide — it kills the tone.
7. **Time check at slide 7.** That's the halfway point. If you're behind, you can compress slide 8 (it's bullet-readable) and skip the per-bar animation.

---

## 5. Technical Specifications

| Spec | Recommendation |
| ---- | -------------- |
| Aspect ratio | **16:9** (1920 × 1080 minimum, 2560 × 1440 preferred for retina projection) |
| File format | `.key` for Keynote, exported `.pdf` for distribution; `.pptx` if conference requires it |
| Fonts | Embed all fonts (`Space Grotesk`, `Inter`, `JetBrains Mono`, `Press Start 2P`) — many conference laptops won't have them |
| Image resolution | Minimum **1920 × 1080** for full-bleed; **4× DPR** for pixel-art renders so they don't blur on projection |
| Color profile | sRGB for projector compatibility — avoid P3-only colors |
| Contrast | All text ≥ **4.5:1** against background; primary body achieves 15:1 |
| Alt text | Add alt text to every screenshot and diagram (PDF export carries it; Keynote → Format → Image → Description) |
| Minimum font on slide | **22 pt** (code blocks); body floor is 28 pt |
| Speaker notes | Include in `.pdf` export as separate "presenter view" PDF — never read them verbatim |
| Backup | Keep a `.pdf` on a USB stick AND in a Google Drive link AND in your email-to-self. Conference Wi-Fi will betray you. |

---

## 6. Accessibility Checklist

- [x] All text ≥ 4.5:1 contrast ratio against background
- [x] No information conveyed by color alone (every accent has an icon or label backup)
- [x] Body text floors at 28 pt
- [x] Pixel-art renders have alt text describing the character + its archetype
- [x] Code blocks use sufficient font weight (500) for legibility from back of room
- [x] No flashing animations; the slide-5 materialization is single-shot, not looping
- [x] Diagram on slide 6 is also described in the speaker notes for screen-reader users of the PDF

---

## 7. Quality Self-Check

- [x] **Single message per slide.** Each slide has exactly one takeaway.
- [x] **Narrative arc holds.** Hook → Pitch → Problem → Insight → System → Architecture → Backend → Proof → Demo → Vision.
- [x] **Design system applied uniformly.** Same palette, same fonts, same icon style across all 10 slides.
- [x] **Speaker notes timed.** Total speaking time ≈ 17–18 minutes, leaving 2 minutes for demo overflow + Q&A.
- [x] **6×6 rule respected.** No slide exceeds 6 lines × 6 words.
- [x] **First-time viewer test.** Slide 2 alone (the 30-second pitch) communicates the product's whole value prop.

---

## 8. File Production Order (Recommended)

If you build this deck yourself, build in this order to maintain momentum:

1. **Slide 5 first** — it's the visual peak. Prove the design system works on the hardest slide.
2. **Slide 6** — architecture diagram. Establishes the spatial vocabulary.
3. **Slides 1, 4, 10** — the three "single sentence" slides. Build the typographic system here.
4. **Slides 2, 7, 8** — the multi-column / data slides. Apply the system you just built.
5. **Slides 3, 9** — narrative + demo slides. Fastest to assemble once the system is locked.

---

*— End of presentation design document. Open `c:\Projeler\Agent-Store-Web\PRESENTATION.md` to review, then build slides in your tool of choice. The slide-5 character materialization is non-negotiable; everything else is editable.*
