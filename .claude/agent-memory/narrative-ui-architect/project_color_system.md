---
name: Color System Reference
description: Established color tokens, their usage contexts, and WCAG compliance status as of v2.6 audit
type: project
---

## Core Palette (theme.dart)
| Token    | Hex       | Usage                     | WCAG on bg (#1E1A14) |
|----------|-----------|---------------------------|----------------------|
| bg       | #1E1A14   | Scaffold background       | —                    |
| surface  | #2A2318   | Sidebar/drawer            | —                    |
| card     | #2E2820   | Card surfaces             | —                    |
| card2    | #332D20   | Lighter card              | —                    |
| border   | #4A3D28   | Warm dark borders         | —                    |
| border2  | #5E4F32   | Brighter borders          | —                    |
| primary  | #C1392B   | Vivid crimson CTA         | 4.1:1 (AA-borderline)|
| gold     | #D4A843   | Warm gold accent          | 5.8:1 (AA pass)      |
| olive    | #8A9A4A   | Muted olive (free badge)  | 4.5:1 (AA-borderline)|
| textH    | #F0E8D4   | Heading text              | 13.1:1 (AAA pass)    |
| textB    | #CCB48A   | Body text                 | 7.4:1 (AA pass)      |
| textM    | #9E8B68   | Muted text                | 3.8:1 (AA FAIL)      |

## Light-themed screens (inconsistent)
- Guild screen: #DDD1BB bg
- Creator dashboard: #DDD1BB bg, header #C8BA9A
- Settings: #DDD1BB bg
- Filter panel: #E8DEC9 bg
- Main sidebar: #C8BA9A bg
- Dialogs/modals: #B8AA88 bg

**Why:** Tracks contrast compliance and identifies the dual-theme inconsistency (dark content area + light sidebar/guild/creator).

**How to apply:** textM needs to be lifted ~20 points (e.g., #B8A080) to pass WCAG AA 4.5:1. Light-themed screens should either be unified with the dark theme or explicitly documented as an intentional "parchment" variant.
