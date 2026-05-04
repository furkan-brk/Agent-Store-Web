# RFC: Agent Store ↔ OpenClaw Bridge Plugin

| Field | Value |
|-------|-------|
| **RFC ID** | `agent-store-bridge` |
| **Status** | Draft |
| **Author** | Furkan Berk (`@furkan-brk`) |
| **Date** | 2026-05-04 |
| **Target version** | OpenClaw v2026.Q4 / Agent Store v4.0 |
| **Discussion** | (Clawcon sonrası ClawHub forum thread'i açılacak) |
| **Related** | `docs.openclaw.ai/concepts/multi-agent`, `VISION.md:106-118` |

---

## Summary

Agent Store, OpenClaw multi-agent foundation'ının üstüne web-native bir UX/marketplace/economy katmanı sunan bağımsız bir üründür. Bu RFC, Agent Store'un Guild Master ve Legend output'unu OpenClaw bindings'e dispatch eden, OpenClaw runtime'ından da Agent Store library'sine reverse-register eden iki yönlü bir plugin'i — `agent-store-bridge` — tanımlar.

## Motivation

OpenClaw VISION (`VISION.md:106-118`) marketplace orchestration ve heavy UX katmanlarını **kasıtlı olarak** core'a almaz. Agent Store bu boşluğu doldurur:

- Son-kullanıcı agent prompt marketplace
- Wallet-tabanlı identity + on-chain credit ekonomisi
- Visual DAG workflow editor (Legend)
- LLM-driven team selection (Guild Master)
- Pixel-art gamification + rarity sistemi

Bugünkü Agent Store standalone — Claude API'yi doğrudan çağırıyor. Bridge plugin enterprise kullanıcılar ve ClawHub ekosisteminden değer almak isteyen developerlar için kritik:

| Kullanım senaryosu | Bugün | Bridge ile |
|--------------------|-------|------------|
| Self-hosted OpenClaw deployment'ında Agent Store kullanmak | ❌ | ✅ |
| Agent Store agentlarını OpenClaw plugin'leriyle compose etmek | ❌ | ✅ |
| Per-agent isolation/sandbox kurallarını OpenClaw runtime'a devretmek | ❌ | ✅ |
| ClawHub plugin'lerini Agent Store kullanıcısına açmak | ❌ | ✅ |
| Multi-tenant SaaS'da tenant başına ayrı OpenClaw deployment | ❌ | ✅ |

## Goals

1. **G1.** Agent Store'un Guild Master + Legend output'unu OpenClaw bindings'e map eden, deterministik dispatch sağlayan bir plugin yazmak.
2. **G2.** Agent Store agent record'larını (`character_type`, `rarity`, `prompt`, `traits`) OpenClaw `agentId` + `workspace` metadata'sına çeviren bir export formatı tanımlamak.
3. **G3.** OpenClaw runtime'ından Agent Store library'sine reverse-register imkanı sunmak (v2 hedefi).
4. **G4.** Mevcut OpenClaw kullanıcılarını rahatsız etmeden, **opt-in** olarak çalışmak.
5. **G5.** ClawHub'da `bundle-style` plugin olarak yayınlamak (VISION önerisine uygun).

## Non-goals

- ❌ Agent Store'un Postgres / Redis / Solidity backend'ini OpenClaw'a taşımak — gamification ve economy Agent Store'un kendi backend'inde kalır
- ❌ AI pipeline service'i OpenClaw'a portlamak — domain-specific (character type detection, rarity scoring, profile analysis) Agent Store'da kalır
- ❌ Wallet-tabanlı authentikasyonu OpenClaw'a kur — bridge sadece JWT → `agentId` mapping yapar
- ❌ Manager-of-managers / nested planner — VISION ile çelişir, bu plugin de kabul etmez
- ❌ Agent Store'u OpenClaw'a "esir" almak — Agent Store standalone çalışabilir kalır

## Design

### Architecture

```text
┌──────────────────────────────────────────────────┐
│  USER (browser)                                  │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│  AGENT STORE (Flutter Web + Go microservices)    │
│  ┌────────────────────────────────────────────┐  │
│  │ Guild Master → suggests team               │  │
│  │ Legend DAG → drag-drop workflow            │  │
│  └────────────────┬───────────────────────────┘  │
└───────────────────┼──────────────────────────────┘
                    │  team profile JSON
┌───────────────────▼──────────────────────────────┐
│  agent-store-bridge plugin (this RFC)            │
│  ┌────────────────────────────────────────────┐  │
│  │ 1. Receive team profile                    │  │
│  │ 2. Map agent_ids → OpenClaw bindings       │  │
│  │ 3. Map node graph → sessions_spawn chain   │  │
│  │ 4. Dispatch to OpenClaw runtime            │  │
│  └────────────────┬───────────────────────────┘  │
└───────────────────┼──────────────────────────────┘
                    │  OpenClaw API calls
┌───────────────────▼──────────────────────────────┐
│  OPENCLAW MULTI-AGENT RUNTIME                    │
│  routing precedence + isolation + sessions_spawn │
└──────────────────────────────────────────────────┘
```

### Public API

#### 1. Custom channel: `agent-store://`

Plugin bir custom channel kaydeder:

```typescript
import { definePlugin } from "openclaw/plugin-sdk";

export default definePlugin({
  id: "agent-store-bridge",
  version: "0.1.0",
  channels: {
    "agent-store": {
      ingest: async (msg, ctx) => {
        const teamProfile = parseAgentStorePayload(msg);
        return dispatchToOpenClawBindings(teamProfile, ctx);
      },
    },
  },
});
```

#### 2. Team profile schema (zod-validated)

```typescript
const TeamProfileSchema = z.object({
  request_id: z.string().uuid(),
  user_wallet: z.string(),
  jwt: z.string(),

  team_id: z.string(),
  agents: z.array(z.object({
    agent_id: z.string(),
    character_type: z.enum(["Wizard", "Strategist", "Oracle",
                             "Guardian", "Artisan", "Bard",
                             "Scholar", "Merchant"]),
    prompt: z.string(),
    model: z.enum(["haiku", "sonnet", "opus"]),
    role: z.string().optional(),
    traits: z.record(z.unknown()).optional(),
  })),

  pipeline: z.object({
    mode: z.enum(["sequential", "parallel"]),
    nodes: z.array(z.object({
      node_id: z.string(),
      agent_id: z.string(),
      depends_on: z.array(z.string()),
    })),
  }),

  input_message: z.string(),

  context: z.object({
    credits_budget: z.number().int().positive(),
    timeout_seconds: z.number().int().positive().max(600),
    sandbox_default: z.enum(["off", "docker", "all"]).default("off"),
  }),
});
```

#### 3. Mapping rules

| Agent Store concept | OpenClaw primitive | Mapping |
|---------------------|--------------------|---------|
| `user_wallet` (0xABC...) | `agentId` prefix | `agent_user_<wallet[2:8]>_<wallet[-6:]>` |
| `agents[].agent_id` | OpenClaw `agentId` | `as_agent_<agent_id_short>` |
| `agents[].prompt` | `agentDir/AGENTS.md` content | direct write |
| `agents[].model` | OpenClaw agent `model` config | `claude-3-5-haiku-latest` / `claude-sonnet-4-6` / `claude-opus-4-6` |
| `agents[].character_type` | `agentDir/SOUL.md` (persona) | template render with type |
| `pipeline` (sequential) | `sessions_spawn` chain | each node → spawn next |
| `pipeline` (parallel) | broadcast group | all nodes spawn concurrently |
| `context.sandbox_default` | per-agent `sandbox.mode` | direct |
| `context.credits_budget` | (no direct equiv) | tracked by bridge only |

#### 4. Bindings generation

Bridge, her team profile için ephemeral bindings üretir:

```json5
// Generated at runtime, NOT persisted to user openclaw.json
{
  "bindings": [
    {
      "agentId": "as_agent_wizard_8f3a",
      "match": {
        "channel": "agent-store",
        "accountId": "team_login_flow_v1",
        "peer": { "kind": "node", "id": "node_1" }
      }
    }
  ]
}
```

Bindings request bittikten sonra **invalidate edilir**.

#### 5. Reverse-register API (v2 milestone)

```typescript
// CLI
openclaw agent-store register \
  --agent my-coding-agent \
  --as-character Wizard \
  --as-rarity Rare

// Or via plugin API
ctx.plugin("agent-store-bridge").registerAgent({
  agentId: "my-coding-agent",
  storeMetadata: {
    character: "Wizard",
    rarity: "Rare",
    description: "...",
  },
});
```

OpenClaw'da tanımlı bir agent, Agent Store store ekranına bir kart olarak görünür.

### Security model

- **Auth:** Agent Store JWT, OpenClaw bridge tarafından doğrulanır (JWKS önerilir)
- **Isolation:** Her wallet için ayrı `agentDir` — bridge ephemeral agent oluşturup request bittikten sonra cleanup yapar
- **Sandbox:** Default `docker` — Agent Store user-supplied prompt'ları için
- **Rate limit:** Bridge plugin OpenClaw operator'ünün koyduğu rate-limit'lere uyar
- **No auth-profile sharing:** "Never reuse `agentDir`" kuralına uyulur

### Compatibility

- **OpenClaw versiyon:** v2026.Q4+ (plugin-sdk v3+)
- **Agent Store versiyon:** v4.0+
- **Backward compatibility:** Plugin opt-in
- **Forward compatibility:** Reverse-register API v2'de eklenir

## Implementation plan

| # | Milestone | Hedef | Açıklama |
|---|-----------|-------|----------|
| **M1** | Plugin scaffold | Q4 2026 | `definePlugin`, channel kaydı, zod schema |
| **M2** | Sequential dispatch | Q4 2026 | TeamProfile → bindings → `sessions_spawn` chain |
| **M3** | Wallet auth bridge | Q1 2027 | JWT → agentId mapping, ephemeral agentDir |
| **M4** | Parallel dispatch | Q1 2027 | Broadcast group entegrasyonu |
| **M5** | Reverse-register | Q2 2027 | OpenClaw → Agent Store library push |
| **M6** | ClawHub publish | Q2 2027 | Bundle-style plugin, signed release |

### Open questions

1. **JWT verification:** Shared secret env'de mi, JWKS endpoint mi? (Önerim: JWKS)
2. **AgentDir lifecycle:** Cleanup TTL ne olmalı? (Önerim: 24h)
3. **Cost reconciliation:** OpenClaw API maliyetleri Agent Store credit'leriyle nasıl ilişkilendirilir? (Önerim: webhook)
4. **Failure recovery:** Pipeline ortasında fail — retry/abort/partial? (Önerim: config-driven, default partial+log)
5. **Plugin tools manifestine erişim:** Reverse-register sırasında OpenClaw plugin tools'larını Agent Store kullanıcısına nasıl expose edelim?

## Alternatives considered

### A1. Agent Store'u tamamen OpenClaw plugin olarak yazmak

❌ **Reddedildi** — On-chain economy, Postgres schema, Flutter Web build pipeline plugin sınırlarını aşar. Agent Store bağımsız ürün olarak değer üretir; plugin formu **dispatch katmanı** için doğru.

### A2. OpenClaw multi-agent'ı Agent Store backend'inde direkt embed etmek (no plugin)

❌ **Reddedildi** — Tight coupling, OpenClaw versiyon güncellemelerinde her seferinde test gerektirir. Plugin formu loose coupling sağlar.

### A3. Generic `multi-agent-bridge` plugin (Agent Store'a özel değil)

🤔 **Düşünüldü** — Agent Store domain-specific schema'lara ihtiyacı var. Generic köprü v2 milestone olabilir, ama önce somut kullanım case'ini olgunlaştırmak gerek.

### A4. Reverse direction önce: OpenClaw → Agent Store

🤔 **Düşünüldü ama dispatch yönü daha kritik** — Reverse direction (OpenClaw plugin'lerini Agent Store kullanıcısına açma) gelecek faz.

## Stakeholders

- **Author:** Furkan Berk (Agent Store maintainer)
- **OpenClaw maintainers:** RFC review, plugin-sdk uyum kontrolü, ClawHub publish onayı
- **Agent Store users:** Self-hosted OpenClaw'a bağlanma talebi olanlar
- **OpenClaw enterprise users:** Bridge'den faydalanabilecek tenant

## Adoption strategy

1. **Sunum öncesi:** Bu RFC draft'ı Clawcon sunumunda referans olarak gösterilir
2. **Sunum sonrası:** ClawHub forum thread'i açılır, community feedback toplanır
3. **2-4 hafta:** RFC v2 — feedback'lere göre revize
4. **M1-M2 implementation:** Author tarafından, açık geliştirme ile
5. **Beta:** Agent Store v4.0 beta + bridge plugin v0.1 beta birlikte yayınlanır
6. **GA:** ClawHub'da bundle-style plugin olarak resmi yayın

## Appendix A: Reference implementation skeleton

```typescript
// agent-store-bridge/src/index.ts

import { definePlugin, defineChannel } from "openclaw/plugin-sdk";
import { z } from "zod";

const TeamProfileSchema = z.object({ /* ... */ });

export default definePlugin({
  id: "agent-store-bridge",
  version: "0.1.0",

  channels: {
    "agent-store": defineChannel({
      ingest: async (msg, ctx) => {
        const claims = await verifyJwt(msg.jwt, ctx.config.jwksUrl);
        const team = TeamProfileSchema.parse(msg.body);
        const agentMap = await buildEphemeralAgents(team, claims, ctx);

        const result = team.pipeline.mode === "sequential"
          ? await executeSequential(team, agentMap, ctx)
          : await executeParallel(team, agentMap, ctx);

        scheduleCleanup(agentMap, 24 * 3600);
        await reportCostToAgentStore(team.request_id, result.cost, ctx);

        return result;
      },
    }),
  },
});
```

## Appendix B: Glossary

- **Agent Store:** Web-native AI agent marketplace platform (`github.com/furkan-brk/Agent-Store-Web`)
- **Guild Master:** Agent Store'un LLM-driven team selector
- **Legend:** Agent Store'un visual DAG workflow editor
- **Ephemeral agent:** Bridge'in request başına oluşturduğu, request bitince temizlenen geçici OpenClaw agent
- **Reverse-register:** OpenClaw runtime'ındaki bir agent'ı Agent Store library'sine kaydetme (v2)

---

*Bu RFC sürekli güncellenecektir.*
