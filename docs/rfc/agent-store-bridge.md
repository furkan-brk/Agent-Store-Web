# RFC: `agent-store-bridge` Plugin

> **Status:** Draft (pre-Clawcon)
> **Targets:** v2 (Q4 2026) → v3 (Q2 2027)
> **Owner:** Agent Store team
> **Companion doc:** [`README.md` § Bridge plugin](../../README.md#bridge-plugin-rfc)

This RFC scaffolds the `agent-store-bridge` OpenClaw plugin that connects
the Agent Store platform (Flutter Web + Go + Monad) to OpenClaw's
multi-agent runtime. It is the contract that lets a Legend visual
workflow execute as an OpenClaw `sessions_spawn` chain — without forcing
either system to take a hard dependency on the other.

## 1 — Goals

1. **Opt-in dispatch.** A user with both Agent Store and OpenClaw can
   "Run in OpenClaw" any Agent / Legend workflow they own or have
   purchased. Users without OpenClaw are unaffected.
2. **Honest abstractions.** Bridge does **not** become a manager-of-
   managers. It maps Agent Store primitives onto OpenClaw primitives
   1:1 and stops there.
3. **Loose coupling.** Plugin sits at the OpenClaw plugin boundary so
   OpenClaw minor-version upgrades don't break Agent Store.
4. **Wallet identity.** A user's Monad wallet drives an OpenClaw
   `auth-profiles.json` entry per agent — the same JWT lifetime is
   reused so the user signs once.

## 2 — Non-goals (v2)

- **Reverse-register.** Surfacing OpenClaw-only agents inside Agent
  Store is a v3 concern (see § 8).
- **Bridging the editor.** Card Editor stays canonical for prompt
  authoring; OpenClaw imports a snapshot, not a live mirror.
- **Cross-tenant fan-out.** A bridge run is single-user.

## 3 — Architecture sketch

```
Browser  ── HTTPS ──▶  Agent Store backend  ── /skill.md/.workspace ──▶  OpenClaw
                            │                                              │
                            └─ JWT (wallet auth)            agent-store-bridge plugin
                                                                           │
                                                                  sessions_spawn chain
```

Three artifacts cross the boundary:

| Artifact | Producer | Consumer |
|----------|----------|----------|
| `SKILL.md` (per agent) | Agent Store `GET /agents/:id/skill.md` (public, redacted; full when authed) | OpenClaw `~/.openclaw/workspace/skills/<slug>/` |
| Workspace bundle (`team.json` + N skills) | Agent Store Legend export OR Library "Export as Workspace" | OpenClaw workspace import |
| `auth-profiles.json` per agent | Bridge plugin (templated from wallet JWT) | OpenClaw provider auth |

## 4 — Mapping table

The mapping between Agent Store and OpenClaw primitives is the heart
of the plugin. A change here is a breaking change for the bridge.

| Agent Store concept                   | OpenClaw primitive                          | Notes |
|---------------------------------------|---------------------------------------------|-------|
| `Agent` (id + prompt + traits)        | `agentId` + `SKILL.md` + workspace metadata | Slug = lower-kebab(title), max 50 chars |
| `Library` + `Store`                   | `agents.list` + ClawHub                     | Library is the "owned" subset |
| Monad wallet auth → JWT               | `auth-profiles.json` per agent              | Plugin renders the file at install time |
| `Guild Master` LLM team selector      | OpenClaw `bindings` (deterministic)         | Bridge converts the suggestion → binding once; OpenClaw never re-asks an LLM |
| `Legend DAG` visual workflow          | `sessions_spawn` chain                      | One agent node = one spawn; START / END are no-ops on the OpenClaw side |
| `Card Editor` (per-agent AGENTS.md)   | `AGENTS.md` per workspace                   | One-shot snapshot at export time |
| Per-node model (haiku / sonnet / opus)| `tools.allow/deny` + runtime model override| Mapped via per-spawn `model:` arg |
| Mission (single prompt + plan)        | `sessions_spawn` (single child)             | A mission is the trivial 1-node DAG |

### 4.1 — Legend DAG → `sessions_spawn` chain

The Legend canvas is a directed acyclic graph of `WorkflowNode`s with
five types: `start | agent | mission | guild | end`. The bridge maps
this 1:1:

```text
START          → no-op / parent context only
agent (refId)  → sessions_spawn { agentId: refId, model: <node.metadata.model> }
mission (slug) → sessions_spawn { agentId: <mission's solo agent>, prompt: <mission.prompt> }
guild (refId)  → sequence: spawn(prep) → spawn(guild members) → spawn(synth)
END            → final result aggregation
```

Edges define the spawn order. Fan-out (one node feeding many) maps to
parallel `sessions_spawn` calls; fan-in (many feeding one) maps to a
single child that receives concatenated parent transcripts.

A topological sort already exists in
`agent_store/lib/features/legend/utils/dag_utils.dart`
(`getOrderedAgentNodes`) — the bridge plugin re-runs the same algorithm
on the imported `team.json` so the OpenClaw side does not need DAG
intelligence.

### 4.2 — Wallet auth → `auth-profiles.json`

```jsonc
// rendered by the bridge at install / refresh time
{
  "agent-store": {
    "type": "bearer",
    "token": "<JWT issued by /api/v1/auth/verify>",
    "expiresAt": "<unix-epoch>",
    "renew": "POST https://api.agentstore.xyz/api/v1/auth/refresh"
  }
}
```

JWT renewal is **the user's responsibility** in v2 — the bridge
displays a one-line warning when the token is < 1 day from expiry. v3
will add automatic renewal via `/auth/refresh`.

## 5 — Public artifacts (already shipped pre-RFC)

The Agent Store backend already serves the bridge's two main inputs:

- **`GET /api/v1/agents/:id/skill.md`** — public endpoint; serves a
  redacted `SKILL.md` (frontmatter intact, prompt placeholder) for
  unauthenticated callers and the full version for owners/purchasers.
  See `backend/services/agent/skill_export.go` (`BuildSkillMd` /
  `BuildPublicSkillMd`).

- **Legend Export → "OpenClaw Workspace"** and **Library →
  "Export Workspace"** produce the combined `team.json` + N
  `SKILL.md` JSON bundle. See `agent_store/lib/features/legend/
  services/claude_export_service.dart#generateOpenclawWorkspace`.

Together these two outputs are the **only contract** v2 needs from
Agent Store — the bridge can be built without further server work.

## 6 — Plugin shape (sketch)

```text
agent-store-bridge/
├── manifest.json           # name, openclaw min/max, capabilities
├── README.md
├── src/
│   ├── install.ts          # render auth-profiles.json from wallet JWT
│   ├── importWorkspace.ts  # accept team.json + N SKILL.md, write to ~/.openclaw
│   ├── runLegend.ts        # accept LegendWorkflow JSON, produce sessions_spawn chain
│   └── refresh.ts          # warn-on-expiring-jwt + (v3) auto-refresh
└── test/                   # Vitest
```

Plugin advertises `capabilities: ["sessions_spawn", "auth.bearer"]` so
OpenClaw can refuse to load it on hosts missing `sessions_spawn`.

## 7 — Open questions

- **Q1.** Should the bridge live in this repo (`/bridge`) or be its
  own repo? Argument for: tighter mapping changes; argument against:
  OpenClaw plugins live in ClawHub.
- **Q2.** What's the minimum OpenClaw version we target? Need to
  confirm the `sessions_spawn(model: ...)` override landed in a tagged
  release before claiming v2 GA.
- **Q3.** How do we handle a guild node when one of the suggested
  agents is OpenClaw-only? In v2 we **reject the bridge run**; v3
  closes this by reverse-register.

## 8 — v3 — Reverse-register (Q2 2027)

OpenClaw agents register themselves into the Agent Store library so a
user's `Library` shows both worlds. Out of scope for this RFC; tracked
separately.

## 9 — Versioning & compatibility

- v2.0.0 — initial GA. Plugin major version is pinned to OpenClaw
  major. Breaking change in mapping table § 4 = bridge major bump.
- v2.x — additive only (new node types, new metadata fields).
- v3.0.0 — reverse-register; expected to land alongside Agent Store
  v4.0.

## 10 — Validation plan

1. **Manual smoke** — drag-drop a `library-openclaw-workspace.json`
   into OpenClaw, confirm 5+ skills appear under
   `~/.openclaw/workspace/skills/`.
2. **Deeplink** — click `openclaw://install-skill?url=…` from a fresh
   browser session; expect OpenClaw to fetch the public SKILL.md and
   show the redacted body.
3. **Authed deeplink** — same with a signed-in session (JWT in OS
   keychain via `auth-profiles.json`); expect full prompt.
4. **Legend run** — kick a 3-node Legend workflow; expect 3 child
   sessions in OpenClaw whose transcripts are visible from
   `agents.list`.

---

*Discussion: open a thread in ClawHub once the post-Clawcon revision
lands. Don't merge mapping changes silently — they're the contract.*
