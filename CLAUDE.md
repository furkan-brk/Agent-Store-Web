# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Agent Store — CLAUDE.md
> Team Leader tarafından tutulur. Sprint detayları `docs/SPRINT_HISTORY.md`'de
> arşivleniyor; bu dosya scaffolding + güncel durum için tutulur.

## Proje Özeti
AI Agent prompt paylaşım platformu. Kullanıcılar agent promptlarını keşfeder,
kütüphanesine ekler, kendi promptunu yükler. Her prompt analiz edilerek benzersiz
pixel-art karakter üretilir. Giriş Monad testnet cüzdanı ile yapılır; kredi
sistemi on-chain yönetilir.

---

## Development Commands

### Backend (Go) — from `backend/`
```bash
# Run all tests (race detector + coverage)
go test ./... -race -coverprofile=coverage.out -covermode=atomic

# Run a single package's tests
go test ./services/agent/... -v

# Run a single test by name
go test ./services/agent/... -run TestListAgents -v

# Vet
go vet ./...

# Run monolith locally (single binary, connects to local postgres)
go run ./cmd/monolith

# Run individual microservice (example: agent service on port 8082)
PORT=8082 go run ./cmd/agentsvc

# Run API gateway (routes to microservices)
go run ./cmd/gateway

# Seed database
go run ./cmd/seed
```

### Frontend (Flutter) — from `agent_store/`
```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded

# Run a specific test file
flutter test test/unit/card_editor_controller_test.dart

# Build for web
flutter build web
```

### Docker (full stack)
```bash
cp .env.example .env  # fill in API keys first
docker-compose up --build              # full stack
docker-compose up postgres backend     # DB + monolith only
```

### Contracts (Hardhat) — from `contracts/`
```bash
npm install && npm run compile && npm test
npm run deploy:local    # local hardhat node
npm run deploy          # Monad testnet
```

### Writing Backend Tests
Tests use an in-memory SQLite DB via `internal/testutil`:
```go
func TestMyFeature(t *testing.T) {
    db := testutil.NewTestDB(t)  // migrates all tables, cleans up via t.Cleanup
    _ = db
    // call service functions directly — they read database.DB global
}
```
**New models added to `pkg/models/` must also be added to the `AutoMigrate` list
in `internal/testutil/db.go`.**

---

## Teknoloji Yığını
| Katman     | Teknoloji                                         |
| ---------- | ------------------------------------------------- |
| Frontend   | Flutter Web (Dart)                                |
| Backend    | Go 1.22 + Gin + GORM                              |
| Veritabanı | PostgreSQL 16                                     |
| Blockchain | Monad Testnet (EVM) · Solidity 0.8.24             |
| Konteyner  | Docker + docker-compose                           |
| Deploy     | Vercel (Flutter static) + Railway/Fly.io (Go API) |
| AI         | Claude API + Gemini Flash + Replicate pixel-art   |

---

## Mimari
```
Agent_Store_Full/
├── agent_store/          # Flutter Web frontend
│   ├── lib/
│   │   ├── app/          # Router, Theme
│   │   ├── features/     # store | agent_detail | library | create_agent | wallet
│   │   │                 # character | card_editor | guild_master | missions
│   │   │                 # legend | leaderboard | settings | insights
│   │   ├── shared/       # models | services | widgets | state
│   │   └── core/         # constants | utils
│   ├── test/{unit,widget}/
│   └── nginx.conf
├── backend/              # Go monolith + microservices
│   ├── cmd/
│   │   ├── monolith/     # ← PRIMARY: all services in-process
│   │   ├── gateway/      # API gateway (reverse proxy + JWT + CORS)
│   │   ├── authsvc/      # :8081
│   │   ├── agentsvc/     # :8082
│   │   ├── aipipelinesvc/# :8083 (stateless)
│   │   ├── guildsvc/     # :8084
│   │   ├── workspacesvc/ # :8085
│   │   └── seed/
│   ├── pkg/
│   │   ├── config/       # Shared env config
│   │   ├── database/     # GORM connect + SetForTest
│   │   ├── models/       # All GORM models (shared)
│   │   ├── middleware/   # JWT auth, CORS, rate limiter, API-key auth
│   │   ├── cache/        # In-process cache store
│   │   └── claude/       # Claude API client
│   ├── services/
│   │   ├── agent/        # CRUD, library, social, use-log, skill export, etc.
│   │   ├── auth/         # Nonce, ECDSA verify, JWT issue
│   │   ├── aipipeline/   # Gemini/Claude analyze, score, avatar, chat
│   │   ├── guild/        # Guild CRUD, GuildMaster AI, sessions, bridge, KPI
│   │   ├── workspace/    # Missions, Legend workflows, execution
│   │   └── gateway/      # JWT extractor, proxy, health
│   └── internal/testutil/# SQLite in-memory test helpers
├── contracts/            # Solidity (Hardhat)
├── docs/
│   ├── rfc/
│   └── SPRINT_HISTORY.md # Detailed sprint notes (v0.1 → v3.11.4)
├── docker-compose.yml
└── CLAUDE.md             # ← bu dosya
```

### Backend Deployment Modes
- **Monolith** (`cmd/monolith`): All services run in-process. Used for Railway
  deploy and simple setups. Internal calls are direct function calls.
- **Microservices** (`cmd/gateway` + individual `*svc` binaries): Each service
  in its own container. Gateway proxies by URL prefix. Used in full docker-compose.
- **Internal endpoints** (`/internal/*`): Cross-service calls in microservices
  mode — not exposed publicly. Gateway does NOT proxy `/internal/` routes.
- **Inter-service URL resolution**: `pkg/config/config.go:svcDefault()` —
  Railway uses `.railway.internal` hostnames; docker-compose uses `*svc`
  container names.

---

## Core API Endpoints (Go)
> Domain bazlı seçilmiş örnekler. Tüm endpoint listesi için
> `docs/SPRINT_HISTORY.md` ve `services/*/router.go` dosyaları.

| Method | Path                        | Açıklama                  |
| ------ | --------------------------- | ------------------------- |
| POST   | /api/v1/auth/nonce          | Cüzdan için nonce üret    |
| POST   | /api/v1/auth/verify         | İmzayı doğrula → JWT      |
| GET    | /api/v1/agents              | Agent listesi             |
| POST   | /api/v1/agents              | Yeni agent oluştur        |
| GET    | /api/v1/agents/:id          | Agent detayı              |
| POST   | /api/v1/agents/:id/generate | Karakter üret (Claude AI) |
| GET    | /api/v1/user/library        | Kütüphane                 |
| POST   | /api/v1/user/library/:id    | Kütüphaneye ekle          |
| DELETE | /api/v1/user/library/:id    | Kütüphaneden çıkar        |
| GET    | /api/v1/user/credits        | Kredi sorgula             |

---

## Veritabanı Şeması (özet)
Çekirdek tablolar:
```
users           : wallet_address (PK), nonce, credits, created_at
agents          : id, title, description, prompt, category, creator_wallet,
                  character_type, character_data (JSON), rarity, tags,
                  revision_id, save_count, created_at
library_entries : user_wallet, agent_id, saved_at
```
Genişletilmiş modeller (sprint'lere göre eklendi):
`UserFollow`, `UserActivity`, `UserMission`, `UserLegendWorkflow`,
`WorkflowExecution` (NodeStates), `LegendWorkflowVersion`, `AgentVersion`,
`GuildMasterSession`, `GuildMemberEvent`, `GuildInvite`, `Achievement`,
`AgentRating` (Hidden+Helpful), `RatingFlag`, `RatingHelpfulVote`,
`NotificationPref`, `NotificationEvent`, `APIKey`, `WeeklyLeaderReward`,
`LegendTemplateUsage`, `GuildMasterReflection`, `AgentUseLog`.

---

## Karakter Sistemi (Gamification)
Prompt → Claude/Gemini analiz → character_type → Flutter CustomPainter pixel-art

| Karakter   | Prompt Tipi         | Renk Paleti      |
| ---------- | ------------------- | ---------------- |
| Wizard     | backend / kod       | Mor, Gece mavisi |
| Strategist | planlayıcı / PM     | Kırmızı, Altın   |
| Oracle     | veri / analitik     | Sarı, Turuncu    |
| Guardian   | güvenlik / infra    | Gri, Mavi        |
| Artisan    | frontend / tasarım  | Pembe, Turkuaz   |
| Bard       | yaratıcı / yazarlık | Yeşil, Limon     |
| Scholar    | araştırma / eğitim  | Bej, Kahve       |
| Merchant   | iş / pazarlama      | Altın, Lacivert  |

Nadir dereceler: Common → Uncommon → Rare → Epic → Legendary

---

## Blockchain (Monad Testnet)
- **AgentStoreCredits.sol**: ERC-20 benzeri on-chain kredi
- **AgentRegistry.sol**: Agent sahipliği kaydı
- Giriş akışı: `eth_requestAccounts` → `personal_sign(nonce)` → backend doğrula → JWT
- RPC: `https://testnet-rpc.monad.xyz` · ChainID: `10143`

---

## Team Agents
| Agent                    | Sorumluluk                                |
| ------------------------ | ----------------------------------------- |
| Team Leader (Claude ana) | Koordinasyon, entegrasyon, CLAUDE.md      |
| Backend                  | Go API, veritabanı, servisler             |
| Frontend                 | Flutter UI, routing, state                |
| Gamification Master      | Pixel-art karakterler, rarity sistemi     |
| Blockchain Expert        | Solidity kontrat, Web3 auth, Monad deploy |

---

## Key File Map

### Backend (Go) — entry points
| Dosya                                  | Açıklama                                   |
| -------------------------------------- | ------------------------------------------ |
| `cmd/monolith/main.go`                 | PRIMARY entry: all services in-process     |
| `cmd/gateway/main.go`                  | API gateway (proxy mode, mock auth in dev) |
| `pkg/config/config.go`                 | Shared env config                          |
| `pkg/database/db.go`                   | GORM connect + `SetForTest` hook           |
| `pkg/middleware/api_key_auth.go`       | API-key + dual-auth helpers                |
| `pkg/models/`                          | All GORM models (shared)                   |
| `services/auth/service.go`             | Nonce üret, ECDSA doğrula, JWT             |
| `services/agent/service.go`            | Agent CRUD, kütüphane, kredi               |
| `services/aipipeline/service.go`       | Gemini/Claude pipeline (stateless)         |
| `services/guild/guildmaster.go`        | GuildMaster AI suggest + chat              |
| `services/guild/bridge.go`             | Mission/Legend draft from GM session       |
| `services/workspace/legend_service.go` | Legend workflow save/execute/resume        |
| `internal/testutil/db.go`              | SQLite in-memory test DB (no CGO)          |

### Frontend (Flutter Web) — anchors
| Dosya                                            | Açıklama                            |
| ------------------------------------------------ | ----------------------------------- |
| `lib/main.dart`                                  | MaterialApp.router giriş            |
| `lib/app/theme.dart`                             | Dark + light (parchment) variantlar |
| `lib/app/router.dart`                            | GoRouter + AppShell                 |
| `lib/core/constants/api_constants.dart`          | API URL sabitleri                   |
| `lib/features/character/character_types.dart`    | CharacterType + Rarity enum         |
| `lib/features/character/pixel_art_painter.dart`  | CustomPainter + glow + float        |
| `lib/shared/widgets/{page_header,empty_state,error_state,confirm_dialog,responsive_layout}.dart` | Shared UI primitives |
| `lib/shared/widgets/animations.dart`             | AppAnimations (hover durations)     |
| `lib/shared/services/api_service.dart`           | HTTP istemcisi                      |
| `lib/shared/services/wallet_service.dart`        | MetaMask köprüsü                    |
| `lib/shared/services/wallet_errors.dart`         | Friendly wallet error map           |

### Blockchain (Solidity)
| Dosya                             | Açıklama                            |
| --------------------------------- | ----------------------------------- |
| `contracts/AgentStoreCredits.sol` | ERC-20 benzeri kredi sistemi        |
| `contracts/AgentRegistry.sol`     | Agent sahipliği + içerik hash kaydı |
| `hardhat.config.js`               | Monad testnet + localhost ağ konfig |
| `scripts/deploy.js`               | Deploy + deployments.json kaydı     |

---

## Established Patterns
Yeni kod yazarken bu pattern'leri **reuse et, yeniden yazma**:

- **Shared widgets**: `PageHeader`, `EmptyState`, `ErrorState`, `ConfirmDialog`,
  `AppAnimations`, `ResponsiveLayout` (uses `AppBreakpoints`, 768px narrow split).
- **SyncStatus**: enum (idle/dirty/saving/saved/error) + ValueNotifier +
  exponential backoff retry (3 attempts) + 5-min periodic sync. Mission, Legend,
  Card Editor hepsi aynı pattern.
- **Optimistic concurrency**: `RevisionID uint64` + `BeforeUpdate` GORM hook +
  handler-level `If-Match` parse → 409 + full-body. Agent, Mission, Legend
  workflow tümünde aynı kalıp.
- **Test utility**: backend için `testutil.NewTestDB(t)` — yeni model eklersen
  AutoMigrate listesini de güncelle.
- **Mention filter**: Pure-Dart helper extract pattern (`mention_filter.dart`,
  `tx_state.dart`, `quality_score.dart` örnekleri) — `dart:js_interop` testleri
  kırıyorsa logiği ayrı dosyaya çek.
- **Cache invalidation**: `s.cache.DeletePrefix("agents|")` event-driven
  (AddToLibrary / RemoveFromLibrary / UpdateProfile / regenerate cache bust).
- **Notification helper**: `notifyOnce(wallet, type, title, body, link)` —
  IsPrefEnabled + 1h dedup + best-effort.
- **RecordActivity**: synchronous (NOT goroutine) — t.Cleanup race önle.
- **Bridge interface pattern**: `services/workspace` `services/guild`'i import
  etmesin diye interface + adapter (`cmd/monolith/main.go`'da wire).
- **Dialect-agnostic SQL**: `strftime('%Y-%m-%d', ...)`, `CASE WHEN` aggregations,
  raw SQL LEFT JOIN — SQLite test + PostgreSQL prod aynı path.

---

## Sprint Index
> Detaylar: `docs/SPRINT_HISTORY.md`. Burada sadece çek-listesi.

- [x] v0.1 → v2.6 — Scaffolding, AI integration, Replicate pixel-art, Trending,
      Mini chat + radar, Profile, Blockchain credits, E2E tests
- [x] v3.0 — Legend: Touch/Touchpad + Claude Agent Export + Live Claude Execution
- [x] v3.1 — UX Improvement Sprint (Guild emoji→Material, keyboard nav,
      Mission redesign, hover consistency)
- [x] v3.2 — UX Overhaul + DB Persistence Fix (24 task — shared widgets,
      SyncStatus, Store dual sidebar, Legend onboarding)
- [x] v3.3 — Legend v3.5: Undo/Redo, Templates, Clone, History UI
- [x] v3.4 — Card Editor: split-view live editing + auto-save + undo/redo + export
- [x] v3.5 — Legend overflow fixes + GuildMaster @-mention library/store sectioning
- [~] v3.6 — Quality Foundation (83 tests + CI gate); mobile pass + bug bash deferred
- [x] v3.7 — Reliability Closure (12 task — Legend optimistic concurrency,
      AgentUseLog cooldown, save_count invalidation, username collision policy,
      tx state machine, draft persistence, rating helpful)
- [x] v3.8 — Explainability + Action Bridge (9 task — structured suggest output,
      MatchingAgent reasoning, GuildMasterSession persistence, Mission/Legend bridges)
- [x] v3.9 — Discovery + Engagement (UserFollow, UserActivity feed, ForYou,
      leaderboard time windows, OG meta)
- [x] v3.10 — Pro Tools (preflight, workflow versioning, mission marketplace,
      guild invites/permissions, compatibility explainability, creator analytics)
- [x] v3.11.1 — User-Facing Polish (fuzzy search, similar agents,
      Mission→Legend bridge, prompt template gallery, mention preview,
      redaction toggle, quality score, credit early-check)
- [x] v3.11.2 — Cross-Cutting Polish (notification center, API keys + bcrypt + scopes,
      per-action credit breakdown, rating moderation, settings sectioning,
      i18n iskelet, theme toggle, wallet UX trio)
- [x] v3.11.3 — Pro Tools Closure (Legend resume, bulk operations, agent versioning
      + rollback, KPI funnel, API key middleware, notification hooks, diff/observability/
      presets/bulk UI/KPI panel)
- [x] v3.11.4 — Closure Sprint (17/17 ✅). Backend (9):
      Discovery analytics, GM KPI, Template metrics, Pipeline resilience,
      Leaderboard category+me+rewards, Guild events, Mission scheduling (cron),
      Post-run reflection, Rating verified+copy+achievements. Frontend (8):
      Smart suggest, Leaderboard extras, Creator bulk action bar, Trial CTA,
      Guild events UI, Mission schedule dialog, KPI panel sections, Achievement
      section.
- [x] v3.11.5 — True 75/75 Closure (5 backlog gaps). Honest audit caught 4
      "already-built" claims (verified ✅ in code) + 5 partial/deferred items
      now shipped: Library Custom Collections cascade-on-Future bug fix
      (`(await getAll())..add(...)`), Card Editor batch tag/category UI
      (PopupMenu + tag dialog), Leaderboard widget integration (YouAreHereRail
      in header + collapsible footer with category + weekly rewards), Mission
      scheduling **real execution** (MissionRun model + ExpandMissionTags
      wired via MissionExpander interface, GET /missions/:id/runs endpoint),
      Post-run reflection auto-record (workspace.ReflectionTarget interface +
      adapter; notifyExecutionResult parses "guildmaster:<id>" workflow
      clientID → calls SessionService.RecordReflection on completed runs).
      Plus 6 backend tests (1 scheduler + 5 reflection auto-record).
      **Backlog: 75/75 (100%) — verified end-to-end.**

---

## Sprint Takip Dosyalari
- `docs/SPRINT_HISTORY.md` — **Tüm sprint detayları** (this file's archive)
- `SPRINT_V2.md` — v2 plan ve teknik kararlar (legacy)
- `SPRINT_V2_TRACKER.md` — v2 task tracker (legacy)
- `.claude/tasks/agent-store/LEGEND_V3_PLAN.md` — Legend v3.0 sprint plani
- `.claude/tasks/agent-store/ux_sprint.md` — v3.2 UX Overhaul sprint plani
