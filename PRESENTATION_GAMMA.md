<!--
================================================================
GLOBAL VISUAL STYLE — reference only, NOT a slide
Apply these in Gamma after import (Settings → Theme).

Background:        #0B0B1A  (deep indigo, near-black, no gradients)
Primary accent:    #F4C95D  (gold — Legendary, blockchain, climax moments)
Secondary accent:  #3FE0C5  (teal — UI, Flutter, "shipped today")
Tertiary accent:   #9B7BFF  (mauve — Wizard, lore, story moments)
Danger / coming:   #E55D87  (pink — "coming next" column, future state)

Image style across the deck:
  - 16-bit pixel art for characters and the meta-loop
  - Hand-drawn Excalidraw aesthetic for diagrams
  - Cinematic dark UI for product screenshots
  - Real screenshots beat AI generation 10× — use them whenever possible

Avoid at all costs:
  - Stock office photography
  - "AI hands typing on keyboards" generic imagery
  - Glowing brain illustrations
  - Generic crypto deck aesthetics

Voice rules (consistent throughout):
  - Address the audience as "you" — second person, command-tense where it lands
  - Use RPG vocabulary for product features (party, quest, mana, starter)
  - Cut engineer-speak (no "DAG", "pipeline", "stack" — instead: party, journey, tools)

Gamma theme: "Oasis" or "Nocturne" (dark). Override accent colors above.
================================================================
-->

# Your best prompts are invisible labor.

A creator economy for the most-copied, least-owned artifact of the AI era.

*ClawCon · 10 slides · 20 minutes*

### 🎨 Visual Brief — Slide 1 (Hook)

**Primary:** A single 16-bit pixel-art **Wizard** (purple `#9B7BFF` + midnight blue), lower-left third of the frame. Holding a glowing tablet. Soft mauve outer glow at 24px. ~70% negative space.

**Gamma prompt:**
> *"16-bit pixel art wizard character holding a glowing tablet, deep purple and midnight blue color palette, character positioned in lower-left third of frame on solid dark indigo background hex 0B0B1A, soft mauve outer glow, retro pixel art style, ample negative space upper-right, no text, cinematic mood"*

**Alternative asset:** Render the Wizard from `agent_store/lib/features/character/character_data.dart` at 4× DPR, transparent PNG, drop into Gamma directly.

**Composition:** Character lower-left. Title text upper-right. The deliberate diagonal asymmetry sets up the visual rhyme on slide 9 where the same Wizard appears upper-right.

---

# What is Agent Store?

A platform where every prompt becomes a **character you own — and a teammate you can send on a quest**.

## The loop

**Discover → Collect → Fork → Compose → Battle → Trade**

A six-station creator economy for AI prompts. Pixel-art characters on the surface. Monad-signed ownership underneath. Portable across Claude Code, Cursor, and OpenClaw the moment you decide to leave.

> Three layers. One creator loop. Zero lock-in.

### 🎨 Visual Brief — Slide 2 (Pitch + Meta-Loop) ⭐ key takeaway visual

**Primary:** A **6-station circular flow diagram** — the engagement flywheel. A small pixel-art character (random archetype, gold trail) traveling clockwise around the loop, frozen mid-journey at the **Compose** station. Each station labeled with its verb in mono font.

Stations (clockwise from top):
1. **Discover** (teal — magnifying glass icon)
2. **Collect** (mauve — bookmark icon)
3. **Fork** (gold — branch icon)
4. **Compose** (teal — node-link icon, character is *here*)
5. **Battle** (gold — crossed swords, dimmed = "coming")
6. **Trade** (gold — coin icon, dimmed = "coming")

**Gamma prompt:**
> *"Circular flowchart on dark indigo background hex 0B0B1A: six stations arranged in a clean circle with thin glowing gold connecting arrows, each station a small icon labeled with one verb — Discover Collect Fork Compose Battle Trade. A small 16-bit pixel art character traveling between stations leaving a faint gold trail. Stations 5 and 6 slightly dimmed to suggest 'coming soon'. Hand-drawn Excalidraw aesthetic, no extra decoration, retro game UI feel"*

**Alternative (better):** Build in **Excalidraw** — 6 nodes in circle, gold curved arrows, drop a tiny PNG of a real Agent Store character at the Compose node. ~15 minutes, looks better than any AI generation.

**Composition:** Loop diagram fills upper 65%. The single tagline "Three layers. One creator loop. Zero lock-in." sits in lower 20%, centered, 36pt.

**Key change from v1:** This slide *replaces* the "See it / Own it / Ship it" three-column pitch. The loop diagram is the **single souvenir** the audience takes home — every later slide reinforces a station on this loop.

---

# Open your best prompt right now.

*Where is it?*

A note app. A chat thread. A folder you stopped naming three months ago.

The prompt that earned its keep — that gave you a real *"holy shit, this works"* moment — and right now, neither you nor your laptop knows exactly where it lives.

## You've already searched all of these this week

- The **Discord DM** where you sent it to a friend
- The **Notion page** from that one productive Tuesday
- The **screenshot** you took because copy-paste was broken
- The **private repo** you forked from your own private repo

You can't find it. Nobody can. And the next time you need it, you'll just rewrite it from scratch — losing the four hours of iteration that made it good in the first place.

This isn't a missing feature. It's a missing category.
**We built Agent Store to be the first place worth looking.**

### 🎨 Visual Brief — Slide 3 (The Problem, second-person)

**Primary:** An **empty search bar** centered on dark indigo, single blinking cursor inside. Above the bar, placeholder text in muted gray: *"the prompt I wrote last month..."*. Below, **zero results** + a faint loading spinner that never resolves.

**Gamma prompt:**
> *"Minimalist UI illustration on dark indigo background hex 0B0B1A: a single empty search bar centered in the frame, thin gold border, blinking cursor inside, placeholder text in muted gray reads 'the prompt I wrote last month'. Below the bar, empty space and a faint loading spinner. Lots of negative space, dark mode aesthetic, conceptual feeling of searching for something lost, no other UI elements"*

**Alternative:** Real screenshot of any search interface (Notion, Slack, macOS Spotlight) with a half-typed prompt query and zero results — desaturated.

**Composition:** Search bar fills upper 40% as anchor. The "Where is it?" question + four-bullet list sit beneath it as the *thoughts* of the person staring at that empty search.

---

# Watch your prompt become a Wizard.

## Before
A 847-character system prompt sitting in a `.txt` file. Plain text. Zero metadata. Zero rendering. One owner — maybe.

## After
The same prompt, **30 seconds later**, on the canvas:

> ✨ **LEGENDARY** ✨
>
> 🧙 **Wizard** · Backend / Code
> Score **94 / 100** · Owner `0xAB12...CD34`
> *Saved by 47 · forked 12× · used 312 times*
> *"Born from a 3am Stack Overflow thread."*

A class. A rarity. A score. A signature. A fan club.

> **A prompt isn't a string. It's an agent.**

Once you see your own work transformed like this, every product decision — leaderboards, libraries, forking, royalties, **battles** — falls out of the metaphor naturally.

### 🎨 Visual Brief — Slide 4 (Loot-Box Transformation) ⭐⭐ dopamine slide

**Primary:** A **3-frame storyboard** showing the transformation as a loot-box reveal:

1. **Frame 1 — "Before"**: Plain monospace text of the actual prompt on dark gray, fading to black. Lifeless.
2. **Frame 2 — "Reveal"**: The text dissolves into mauve glow particles, a silhouette of the Wizard emerging from the center. Mid-animation feel.
3. **Frame 3 — "After"**: The full Wizard pixel-art character, gold border, **"LEGENDARY"** banner stamped diagonally across the top in `Press Start 2P` font. Stat panel beside it (Score 94, Forks 12, Used 312×, "saved by 47"). Mauve outer glow.

The frames flow left-to-right with thin gold arrows between them.

**Gamma prompt:**
> *"Three-frame horizontal storyboard on dark indigo background hex 0B0B1A: Frame 1 wall of plain monospace code text on dark gray fading to black. Frame 2 same text dissolving into mauve purple glow particles with a faint character silhouette emerging from center. Frame 3 a fully revealed 16-bit pixel art wizard character in deep purple, gold border, banner across the top reading LEGENDARY in retro arcade font, stat panel beside the character with numeric labels Score 94 Forks 12 Used 312, mauve outer glow. Thin gold arrows between frames. Loot-box reveal aesthetic, retro RPG feel"*

**Alternative (best):** Build manually in Figma — Frame 1 a screenshot of a real `.txt` file, Frame 3 a screenshot of an actual Agent Store agent detail page with stats. Frame 2 a quick Procreate dissolve overlay. ~30 minutes.

**Composition:** Storyboard fills upper 65%. Quote *"A prompt isn't a string. It's an agent."* sits in lower 20%, 56pt, centered, the deck's biggest text.

---

# Pick your starter.

The first time you upload a prompt and watch it become a character, you don't go back to text — **you start collecting**.

## The starter trio

**🧙 Wizard — Legendary**
Born from backend prompts. *"You are a senior Go engineer..."* Purple, midnight. Stats run high in **Precision** and **Depth**.

**🎯 Strategist — Epic**
Forged from PM and planning prompts. Red, gold. Heavy on **Coordination** and **Foresight**. The party leader.

**🎵 Bard — Rare**
Conjured from creative writing. Green, lime. Maxes **Charisma** and **Improvisation**. The one nobody expects to win the fight, who wins the fight.

## The other five

**Oracle** (data) · **Guardian** (security) · **Artisan** (frontend) · **Scholar** (research) · **Merchant** (business)

Five rarities: **Common → Uncommon → Rare → Epic → Legendary**.
A 16×16 grid. A `CustomPainter`. **800 lines of Dart**. No PNGs, no sprite sheets, no asset pipeline.

### 🎨 Visual Brief — Slide 5 (Hero Cards / Starter Select) ⭐⭐⭐ visual peak

**Primary:** **Three full-size hero cards** filling the upper 60% of the slide — Wizard (Legendary, gold border), Strategist (Epic, purple border), Bard (Rare, blue border). Each card shows: character render at 256×256, name banner with rarity, stat radar chart (4 axes: Precision, Depth, Coordination, Charisma), one lore line at bottom in italic.

Beneath the trio: a **horizontal mini-strip of the other 5 archetypes** at 96×96 each, no stats, just the silhouettes — implying "and 5 more to collect."

**Gamma prompt:**
> *"Three full-size RPG character cards on dark indigo background hex 0B0B1A. Card 1 Wizard purple legendary with gold border and banner reading LEGENDARY. Card 2 Strategist red and gold epic with purple border. Card 3 Bard green and lime rare with blue border. Each card has a 16-bit pixel art character render, a stat radar chart with 4 axes, and one lore line in italic at the bottom. Below the three cards a horizontal strip of 5 smaller character silhouettes in muted colors. Pokemon starter-select aesthetic, retro RPG card game feel, no extra UI"*

**Alternative (strongly recommended):** Render the actual 8 characters from the live app at 4× DPR. Build the 3 hero cards in Figma using real pixel art + the in-app radar chart. The other 5 as miniatures. ~45 minutes. Will **destroy** any AI generation.

**Composition:** 3 hero cards in upper 60%, equal width, 24px gutters. 5 miniature strip in middle 15%. Closing line about 800-lines-of-Dart sits at bottom 15%, mono font, muted.

**Key change from v1:** This slide *no longer* claims "you cannot go back to text" (overclaim). Instead it says "you start collecting" — which is the actual emotional hook for game mechanics. The roster table is gone; the **covet object** is here.

---

# Three layers. Three repos. One round trip.

```
┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│   agent_store/     │   │     backend/       │   │    contracts/      │
│   Flutter Web      │ ⇄ │     Go 1.22        │ ⇄ │   Solidity 0.8.24  │
│   17 features      │   │   6 services       │   │   Monad Testnet    │
└────────────────────┘   └────────────────────┘   └────────────────────┘
```

> One Postgres. One Claude API. One MetaMask login.
> **Everything else is composition.**

### 🎨 Visual Brief — Slide 6 (Architecture, slim)

**Primary:** A clean **hand-drawn Excalidraw diagram** of three connected boxes. Teal (Flutter) ⇄ Gold (Go) ⇄ Mauve (Solidity). Bidirectional thin gold arrows. Each box labeled with its repo name in mono font. **No icons, no logos, no stack trivia.**

**Gamma prompt:**
> *"Hand-drawn Excalidraw aesthetic diagram on dark indigo background hex 0B0B1A: three rectangular boxes in a horizontal row. Left box teal label agent_store. Middle box gold label backend. Right box mauve label contracts. Bidirectional thin gold arrows connecting each box to the next. Slight pencil-drawn imperfection in lines, sketchy hand-drawn look, no fill colors only borders, technical architecture diagram"*

**Alternative:** Build directly in **Excalidraw**, dark theme, export SVG. 5 minutes. Definitive.

**Composition:** Diagram fills upper 60%. The single tagline "Everything else is composition." sits in lower 20%, 44pt, centered.

**Key change from v1:** The "Why this stack, exactly" three bullets are GONE. They stalled the deck at the act-2/3 hinge. Architecture is now a glance-able diagram + one closing line.

---

# Run it on your own servers. Share the marketplace.

The blockchain isn't decoration. It's the **federation protocol** that lets sovereign deployments and an open marketplace exist at the same time.

## The architecture in one sentence

Each organization can run its own Agent Store backend — on its own VPC, behind its own firewall, against its own Postgres. But the **marketplace layer lives on Monad**. Every public agent, every fork, every credit transfer is on-chain. Instances discover each other through the registry.

> *Your team. Your servers. Your prompts.*
> *Everyone else's marketplace.*

## What this unlocks

**🏛 Provenance, not custody**
We don't hold your prompts. On-prem deployments mean nobody else does either. The chain holds the *receipt* that you authored them — and that receipt outlives any single server.

**🔗 Federation, not platform**
Your on-prem Agent Store talks to mine through Monad — directly, peer-to-peer. The marketplace **is the protocol**, not a service running on someone's AWS. If every centralized Agent Store instance vanishes tomorrow, your marketplace doesn't.

**💰 Forks become royalties — across instances**
When someone in another organization forks your agent, the credit flows on-chain to your wallet. No invoicing. No platform middle-man. No trust assumption between companies that have never met.

## Why Monad, specifically

- **10,000 TPS target** — instance-to-instance discovery feels instant, not blockchain-slow
- **Sub-cent gas** — micro-credit transactions stay invisible to creators
- **EVM-compatible** — MetaMask works, Solidity tooling works, every audit firm already speaks it

> **The blockchain isn't the product. It's the connective tissue.**

### 🎨 Visual Brief — Slide 7 (Federation Architecture) ⭐ defends the blockchain choice

**Primary:** A **federation diagram** showing three separate company data centers, each running its own Agent Store instance, all connected through a central Monad chain band running across the middle. Each company's instance is its own color (teal, mauve, gold). Their internal databases stay private (locked-icon visual), but their public agents publish "up" to the chain band, and they discover each other "through" the chain.

**Visual structure:**
- **Top row** — three "company" rectangles side-by-side, each labeled (e.g., "Acme Inc.", "Studio Bravo", "Solo Dev"), each with its own color, each containing a tiny stack icon (their on-prem instance + private Postgres icon)
- **Middle band** — horizontal "Monad" chain visualization (block-by-block links, gold), spanning full width
- **Arrows** — each company has two arrows: one pointing UP to the chain (publishing public agents) and one pointing DOWN from the chain (discovering others' agents)
- **Bottom strip** — the three contracts (`AgentRegistry`, `AgentStoreCredits`, optional federation contract), labeled in mono font

**Gamma prompt:**
> *"Federation architecture diagram on dark indigo background hex 0B0B1A: three rectangular boxes side-by-side at the top, each a different muted color (teal, mauve, gold), each labeled with a company name and containing a small server stack icon and a small lock icon. Middle of the frame a horizontal chain of small connected blocks in gold representing a blockchain, spanning full width. Bidirectional thin gold arrows connecting each top box to the chain. Below the chain, three small contract labels in monospace font. Hand-drawn Excalidraw aesthetic, technical architecture diagram, clean lines, no extra decoration"*

**Alternative (better):** Build in **Excalidraw** with the dark theme. 3 rectangles up top, a chain block-strip in the middle, arrows pointing both ways from each rectangle to the chain. Add a tiny "🔒 private" label inside each rectangle and a "🌐 public" label on the chain. ~15 minutes.

**Composition:** Diagram fills upper 55%. "Your team. Your servers. Your prompts. Everyone else's marketplace." couplet sits in middle 15%, 44pt, italic. The three "What this unlocks" blocks fill lower 30% as a 3-column row.

**Why this slide matters:** This is the slide that *kills the "why blockchain?" objection before it's asked*. It reframes Monad from "credit ledger" (decorative) to "federation protocol" (load-bearing). Enterprise-curious judges immediately understand the data-sovereignty angle. Skeptical judges get an answer they can't easily knock down: *the chain is the only piece that has to be shared; everything else stays yours.*

---

# Anatomy of a Legendary.

Meet **"The Code Reviewer"** — the most-forked Wizard in the store.

## The card

🧙 **Wizard** · Backend / Code · **LEGENDARY**
Owner `0xAB12...CD34` · Minted *Mar 14, 2026*

## What lives behind the card

| Panel | Reading |
| ----- | ------- |
| 📊 **Stats**     | Precision **94** · Depth **91** · Patience **88** · Conciseness **72** |
| 🌳 **Fork tree** | **47 forks** across **12 organizations** — each one a distinct branch |
| 💰 **Earnings**  | 47 × 3cr = **141 credits** routed on-chain to the creator's wallet |
| 🔥 **Activity**  | **312 invocations** this week · trending **#1** in `/backend` |
| 📜 **Lore**      | *"Born from a 3am Stack Overflow thread. Refined by 11 PRs."* |
| 🏆 **Rank**      | **#3** in Backend/Code · **#11** overall · saved by **1,247** wallets |

> *Your best prompt deserves a card like this.*

A class. A rarity. A score. A signature. A fan club. **A receipt.**
Every prompt that gets uploaded to Agent Store earns the chance to grow into one.

### 🎨 Visual Brief — Slide 8 (Anatomy of a Legendary) ⭐⭐ single covet object

**Primary:** A **single full-page character card layout** — left third holds the hero render, right two-thirds hold a 3×2 grid of small info panels. The character is large, glowing, *legendary* in every visual sense.

**Left panel (35% width) — The Card**
- Full-size 16-bit pixel-art **Wizard** character at ~480 px tall (purple `#9B7BFF` + midnight blue palette)
- Diagonal gold banner across the upper-third reading **"LEGENDARY"** in `Press Start 2P`
- Gold ornate border, mauve outer glow at 32 px
- Below the character: name plate "*The Code Reviewer*" in a serif display font
- Tiny mono line at the very bottom: `0xAB12...CD34 · minted Mar 14 2026`

**Right panel (65% width) — Six info cards in a 3×2 grid**
Each card is a small dark surface with:
- An emoji icon top-left
- A short label
- The metric value in large gold numbers
- One muted descriptor line

The six cards (in reading order, left-to-right top-to-bottom):
1. **📊 Stats** — radar chart of 4 axes
2. **🌳 Fork tree** — small branching diagram (parent + 12 sub-branches)
3. **💰 Earnings** — big gold number "141 cr" with "→ on-chain" caption
4. **🔥 Activity** — small line chart spiking upward
5. **📜 Lore** — italic quote, smaller font
6. **🏆 Rank** — three medal positions

**Gamma prompt (for the character card only — pair with manual panels):**
> *"A single large 16-bit pixel art wizard character on dark indigo background hex 0B0B1A, deep purple and midnight blue palette, ornate gold border around the character, diagonal gold banner across the top reading LEGENDARY in retro arcade font, soft mauve glow at 32 pixel radius around the entire frame, character at center-left of composition with empty space to the right for additional panels, retro RPG legendary card game aesthetic, no other text"*

**Alternative (strongly recommended):** Build the *entire slide* in **Figma**. Render the real Wizard from the live app at 4× DPR. Compose the 6 info panels manually with real (or seed) data — radar chart from the in-app widget, mini fork-tree with `react-flow`-style nodes, gold "141 cr" number. ~45 minutes of polish. The single highest-leverage character moment in the deck.

**Composition:** Title in upper 8%. Character card on left 35%, info grid on right 65%, both filling middle 75% of slide. Closing line *"Your best prompt deserves a card like this."* in lower 12%, italic, 44pt centered.

**Why this slide replaces "Receipts":** The deck already has Federation (slot 7) carrying technical credibility. A second engineering-proof slide dilutes rather than reinforces. *This* slide does something else entirely — it gives the audience **one specific, fully-realized character** to covet. Slot 5 said "Pick your starter." This slide says "Here's what your starter could become." It's the deck's only single-object slide; everything else is grids, diagrams, or stories. By isolating one Legendary, we make the value tangible — and we set up slot 9 ("Build your party") with maximum desire-pressure.

# Beyond the store: build your party.

> Discovery is the easy half. The other half is what makes creators **stay**.

## 🃏 Card Editor — your character workshop
Edit the prompt on the left. Watch the character mutate on the right — **live, every keystroke**. Auto-save with optimistic concurrency. **50 deep undo**. Export as PNG at 3× DPR or as JSON for forking.

## ⚔️ Legend — send your party on a quest
A canvas where your agents become **a party**. Drop a Scholar (research), an Oracle (scoring), a Wizard (code), a Bard (write the PR) — connect them. **Mana cost** per node: Haiku **1cr**, Sonnet **3cr**, Opus **10cr**. Run live against Claude. Full version history.

## 🎲 Guild Master — your AI dungeon master
Type a goal: *"Launch a Series A pitch by Friday."*
Guild Master returns a **structured campaign**: goal, owners by archetype, risks, success criteria, and matching agents from your library — each with a **confidence score and a reason**. One click to **save as Mission** or **open in Legend**.

## 🌉 OpenClaw bridge — your portfolio is portable
Export any agent as a `SKILL.md` with YAML frontmatter. Drop it into `~/.openclaw/workspace/skills/`. Round-trip back into Agent Store with full metadata preserved.

> **We're not your prompt jail. We're your prompt portfolio.**

### 🎨 Visual Brief — Slide 9 (The Climax) ⭐⭐⭐ narrative peak

**Why no UI screenshots in the AI prompts:** AI image generators (Gamma's included) produce garbled, unreadable fake UIs. We're not asking them to do that. Instead: **four RPG-themed pixel-art vignettes** — one per feature — that AI gen can actually produce well. Real product screenshots remain the optional "best version", but the vignettes are good enough to ship as-is.

**Primary:** A **2×2 grid of pixel-art RPG vignettes**, one per feature, dark indigo background, gold + mauve glow accents.

---

**🃏 Vignette 1 (top-left) — "The Character Workshop"**
> *"16-bit pixel art scene of a blacksmith's workshop at night, glowing gold anvil in the center, a small pixel-art wizard character in deep purple standing on the anvil being refined, spell scrolls and small glowing gemstones floating in the air around the workshop, dark indigo background hex 0B0B1A, mauve and gold magical lighting, retro RPG game aesthetic, no text, no UI elements, atmospheric"*

**⚔️ Vignette 2 (top-right) — "The Party on a Quest"**
> *"16-bit pixel art side-scrolling scene: four small distinct pixel characters walking left-to-right along a forest path. From front to back: a beige scholar with an open book, a yellow-orange oracle with a crystal, a purple wizard with a staff, a green bard with a lute. Above each character a small floating gem of different colors representing mana cost. Pine trees and stars in background, dark indigo sky hex 0B0B1A, soft glow on each character, retro fantasy RPG aesthetic, no text"*

**🎲 Vignette 3 (bottom-left) — "The Dungeon Master"**
> *"16-bit pixel art scene of a hooded figure in a deep mauve robe sitting at a wooden table in a dimly lit room, scattered dice on the table, a glowing crystal ball in front of them, four small floating holographic cards hovering above the table arranged in a fan, each card a different muted color (gold, teal, mauve, pink). Dark indigo background hex 0B0B1A, candle-light atmosphere, dramatic lighting, retro RPG dungeon master aesthetic, no readable text on cards"*

**🌉 Vignette 4 (bottom-right) — "The Portable Portfolio"**
> *"16-bit pixel art scene of a small wizard character walking through a glowing teal portal arch, carrying a small backpack with tiny character cards spilling out trailing behind them like a comet tail. Through the portal arch, faint silhouettes of three other doorways (suggesting other tools). Dark indigo background hex 0B0B1A, gold portal glow, sense of journey and freedom, retro pixel art aesthetic, no text"*

---

**Layout in Gamma:**
- Each vignette in its own quadrant of a 2×2 grid
- 1px gold border around each
- Equal 24px gutters
- Subtle drop shadow

**Optional upgrade (real screenshots, only if you have 30 min):**
1. Top-left → Card Editor split view (`/agent/:id/edit`) with a Wizard agent loaded
2. Top-right → Legend canvas with 4 nodes labeled "Scholar researches → Oracle scores → Wizard codes → Bard writes the PR", gold mana-cost badges on each
3. Bottom-left → Guild Master output showing structured Goal/Plan/Owners/Risks
4. Bottom-right → OpenClaw export modal showing the SKILL.md preview

If you take screenshots, **replace the vignettes**, don't mix the two — visual style consistency matters more than which medium.

**Composition:** Vignette/screenshot grid fills upper 60%. The four feature blocks beneath as a 4-column row. Closing quote *"We're not your prompt jail. We're your prompt portfolio."* in lower 15%, 44pt, gold accent on "portfolio".

**Why this works:** AI image gen handles concrete physical scenes (workshop, forest path, hooded figure, portal arch) far better than fake UIs. Each vignette is also a *self-contained metaphor* the audience can recall later — Card Editor = workshop, Legend = quest, Guild Master = DM, OpenClaw = portal. Same RPG vocabulary as the slide copy, now rendered visually.

---

# Shipped today. Coming next.

| ✅ Shipped today (`v3.10`)              | 🔮 Coming next                                |
| --------------------------------------- | --------------------------------------------- |
| 8 archetypes · 5 rarities · live render | **Battles** — Wizard vs Wizard, same task     |
| Card Editor · Legend · Guild Master     | **Royalties** — credits flow on fork, on-chain|
| OpenClaw round-trip (SKILL.md)          | **Workflows-as-NFTs** — Legend DAGs as assets |
| Mission Marketplace · Creator Insights  | **Interop** — Cursor, Claude Code, registries |
| 195 tests · 40+ sprints · 0 loose ends  | *Q3 2026, in that order.*                     |

---

> *Your best prompts were invisible labor.*
>
> **Now they have a name, a face, and an owner.**

### 🎨 Visual Brief — Slide 10 (Vision + Closing) ⭐ lyrical landing

**Primary:** The slide is split visually in half by a thin vertical gold line.
- **Left side** — clean two-column "Shipped today" list, teal `✅` checkmarks, mono font, all real and current.
- **Right side** — the same structure for "Coming next", but with one **mock battle screenshot** at the top: two character cards facing off (e.g., Wizard vs Wizard), HP-bar-style indicators labeled *task accuracy / latency / cost*, a faint "winner glow" on one. Pink `#E55D87` accent for the "coming" column.

Beneath the table, **dead center**, the closing couplet in 56pt:
> *Your best prompts were invisible labor.*
> **Now they have a name, a face, and an owner.**

**Bonus visual rhyme:** The same Wizard from slide 1 reappears in **upper-right** corner (mirrored from slide 1's lower-left). Subtle, ~20% opacity, signals "we've come full circle."

**Gamma prompt (for the battle screen):**
> *"Mock RPG battle screen on dark indigo background: two 16-bit pixel art wizard characters facing each other on a horizontal axis, between them three thin progress-bar indicators labeled 'task accuracy', 'latency', 'cost', one wizard has a faint gold winner glow around it, retro fighting-game UI aesthetic, no extra text, dramatic"*

**Composition:** Two-column comparison fills upper 55%. Closing couplet in middle 25%, the largest text in the deck. Wizard callback in upper-right at 20% opacity. Footer (Agent Store · stack list · Questions?) in lower 8%, 14pt mono, muted.

**Key change from v1:** This slide is now **architecturally split** between shipped and roadmap — agent-store-planner's flag that judges discount the deck if Battles/NFTs read as current. The lyrical hook callback ("invisible labor → name, face, owner") is now the deck's loudest closing — not the muted "Let's give them a shelf." The mock battle screen makes the future state a *picture*, not a bullet list.

---

**Agent Store** — Flutter Web · Go · Solidity · Monad Testnet
*Questions?*

<!--
================================================================
PRODUCTION CHECKLIST — reference only, NOT a slide

Pre-talk asset prep (estimated total: 2 hours, 15 minutes):

[ ] Render all 8 characters from the live app at 4× DPR (15 min)
    → presentation-assets/characters/{wizard,strategist,bard,...}.png

[ ] Slide 2 — Build the meta-loop diagram in Excalidraw (15 min)
    → 6 stations clockwise, gold curved arrows, drop one PNG character
    → at the Compose station mid-flight

[ ] Slide 4 — Build the 3-frame loot-box storyboard in Figma (30 min)
    → Frame 1: real .txt file screenshot
    → Frame 3: real Agent Store agent detail page screenshot
    → Frame 2: dissolve overlay (Procreate or Figma blur+particles)

[ ] Slide 5 — Build the 3 hero cards in Figma (45 min)
    → Real pixel art renders + radar chart from the in-app widget
    → Banner banners (LEGENDARY/EPIC/RARE) in Press Start 2P font
    → Plus the 5 miniature silhouettes strip below

[ ] Slide 6 — Excalidraw architecture diagram (5 min)
    → 3 boxes, gold bidirectional arrows, dark theme, export SVG

[ ] Slide 7 — Excalidraw federation diagram (15 min)
    → 3 company rectangles up top (teal/mauve/gold), each with server+lock icon
    → Horizontal Monad chain band in the middle (block-by-block links, gold)
    → Bidirectional arrows from each company to the chain (publish + discover)
    → "🔒 private" label inside each company, "🌐 public" on the chain

[ ] Slide 8 — Build the Legendary character anatomy card in Figma (45 min)
    → Real Wizard render from the live app at 4× DPR (left third)
    → Diagonal gold "LEGENDARY" banner + ornate border + mauve outer glow
    → 6 info panels in 3×2 grid (right two-thirds): radar chart, fork tree,
      earnings 141 cr, activity spike, lore italics, rank medals
    → Use real or carefully-seeded data; the single covet object of the deck

[ ] Slide 9 — Either 4 RPG vignettes (AI gen) OR 4 product screenshots (10–30 min)
    → Vignette path: workshop / party-on-quest / dungeon-master / portal scenes
    → Screenshot path: Card Editor split view, Legend canvas with RPG-labeled
      4-node DAG ("Scholar researches → Oracle scores → Wizard codes → Bard
      writes the PR"), Guild Master output, OpenClaw export modal
    → Don't mix the two — pick one medium for visual consistency

[ ] Slide 10 — Build mock battle screen in Figma (15 min)
    → Two real character pixel arts facing off
    → HP-bar indicators labeled task accuracy / latency / cost
    → Gold winner glow on one side

In Gamma (post-import):
[ ] Use Free-form import (not "Generate") — don't let it rewrite copy
[ ] Theme → "Oasis" or "Nocturne", override accent colors to deck palette
[ ] Replace every Gamma-generated image with the real assets above
[ ] Delete every "🎨 Visual Brief" section after import (it's for you, not audience)
[ ] Verify second-person voice on slides 3, 4, 5, 9, 10 lands consistently
================================================================
-->
