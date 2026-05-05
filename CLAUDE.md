# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Agent Store — CLAUDE.md
> Team Leader tarafından tutulur. Her sprint sonrası güncellenir.

## Proje Özeti
AI Agent prompt paylaşım platformu. Kullanıcılar agent promptlarını keşfeder, kütüphanesine ekler, kendi promptunu yükler. Her prompt analiz edilerek benzersiz pixel-art karakter üretilir. Giriş Monad testnet cüzdanı ile yapılır; kredi sistemi on-chain yönetilir.

---

## Development Commands

### Backend (Go) — from `backend/`
```bash
# Run all tests (race detector + coverage)
go test ./... -race -coverprofile=coverage.out -covermode=atomic

# Run a single package's tests
go test ./services/agent/... -v
go test ./services/auth/... -v

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
# Copy .env.example → .env and fill in API keys first
cp .env.example .env

# Start all services
docker-compose up --build

# Start only DB + backend (monolith mode)
docker-compose up postgres backend
```

### Contracts (Hardhat) — from `contracts/`
```bash
npm install
npm run compile
npm test
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
New models added to `pkg/models/` must also be added to the `AutoMigrate` list in `internal/testutil/db.go`.


---


## Teknoloji Yığını
| Katman     | Teknoloji                                            |
| ---------- | ---------------------------------------------------- |
| Frontend   | Flutter Web (Dart)                                   |
| Backend    | Go 1.22 + Gin + GORM                                 |
| Veritabanı | PostgreSQL 16                                        |
| Blockchain | Monad Testnet (EVM) · Solidity 0.8.24                |
| Konteyner  | Docker + docker-compose                              |
| Deploy     | Vercel (Flutter static) + Railway/Fly.io (Go API)    |
| AI         | Claude API (prompt analiz + karakter tipi belirleme) |

---

## Mimari
```
Agent_Store_Full/
├── agent_store/          # Flutter Web frontend
│   ├── lib/
│   │   ├── app/          # Router, Theme
│   │   ├── features/     # store | agent_detail | library | create_agent | wallet | character
│   │   │                 # card_editor | guild_master | missions | legend | leaderboard
│   │   ├── shared/       # models | services | widgets
│   │   └── core/         # constants | utils
│   ├── test/unit/        # Dart unit tests (mocktail + fake_async)
│   └── nginx.conf
├── backend/              # Go microservices
│   ├── cmd/
│   │   ├── monolith/     # ← PRIMARY: single binary (all services in-process)
│   │   ├── gateway/      # API gateway (reverse proxy, JWT extraction, CORS)
│   │   ├── authsvc/      # Auth service          :8081
│   │   ├── agentsvc/     # Agent service         :8082
│   │   ├── aipipelinesvc/# AI pipeline service   :8083 (stateless)
│   │   ├── guildsvc/     # Guild service         :8084
│   │   ├── workspacesvc/ # Workspace service     :8085
│   │   └── seed/         # DB seeder
│   ├── pkg/
│   │   ├── config/       # Shared env config (all services)
│   │   ├── database/     # GORM connect + SetForTest hook
│   │   ├── models/       # All GORM models (shared across services)
│   │   ├── middleware/    # JWT auth, CORS, rate limiter
│   │   ├── cache/        # In-process cache store
│   │   └── claude/       # Claude API client
│   ├── services/
│   │   ├── agent/        # CRUD, library, social, use-log, skill export
│   │   ├── auth/         # Nonce, ECDSA verify, JWT issue
│   │   ├── aipipeline/   # Gemini/Claude analyze, score, avatar, chat
│   │   ├── guild/        # Guild CRUD, GuildMaster AI, sessions, bridge
│   │   ├── workspace/    # Missions, Legend workflows, execution
│   │   └── gateway/      # JWT extractor, proxy, health
│   └── internal/testutil/# SQLite in-memory test helpers
├── contracts/            # Solidity (Hardhat)
│   ├── contracts/        # AgentStoreCredits.sol | AgentRegistry.sol
│   └── scripts/          # deploy.js
├── docker-compose.yml    # Full microservices stack
└── CLAUDE.md             # ← bu dosya
```

### Backend Deployment Modes
- **Monolith** (`cmd/monolith`): All services run in-process. Used for Railway deploy and simple setups. Internal service calls are direct function calls (no HTTP between services).
- **Microservices** (`cmd/gateway` + individual `*svc` binaries): Each service runs in its own container. The gateway proxies by URL prefix. Used in full docker-compose.
- **Internal endpoints** (`/internal/*`): Used for cross-service calls in microservices mode — not exposed publicly. The gateway does NOT proxy `/internal/` routes.
- **Inter-service URL resolution**: `pkg/config/config.go:svcDefault()` — Railway uses `.railway.internal` hostnames; docker-compose uses `*svc` container names.

---

## API Endpointleri (Go)
| Method | Path                        | Açıklama                           |
| ------ | --------------------------- | ---------------------------------- |
| POST   | /api/v1/auth/nonce          | Cüzdan için nonce üret             |
| POST   | /api/v1/auth/verify         | İmzayı doğrula → JWT döndür        |
| GET    | /api/v1/agents              | Agent listesi (filtre + sayfalama) |
| POST   | /api/v1/agents              | Yeni agent oluştur                 |
| GET    | /api/v1/agents/:id          | Agent detayı                       |
| POST   | /api/v1/agents/:id/generate | Karakter üret (Claude AI)          |
| GET    | /api/v1/user/library        | Kütüphane                          |
| POST   | /api/v1/user/library/:id    | Kütüphaneye ekle                   |
| DELETE | /api/v1/user/library/:id    | Kütüphaneden çıkar                 |
| GET    | /api/v1/user/credits        | Kredi sorgula                      |

---

## Veritabanı Şeması
```
users           : wallet_address (PK), nonce, credits, created_at
agents          : id, title, description, prompt, category, creator_wallet,
                  character_type, character_data (JSON), rarity, tags, created_at
library_entries : user_wallet, agent_id, saved_at
```

---

## Karakter Sistemi (Gamification)
Prompt → Claude API analiz → character_type → Flutter CustomPainter pixel-art

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

## Docker Servisleri
```yaml
services:
  postgres   → port 5432
  backend    → port 8080
  frontend   → port 80  (nginx static)
  contracts  → migration/deploy (one-shot)
```

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

## Dosya Haritası (Team Leader tarafından oluşturuldu)

### Backend (Go) — key entry points
| Dosya                                    | Açıklama                                     |
| ---------------------------------------- | -------------------------------------------- |
| `cmd/monolith/main.go`                   | PRIMARY entry: all services in-process       |
| `cmd/gateway/main.go`                    | API gateway (proxy mode, mock auth in dev)   |
| `pkg/config/config.go`                   | Shared env config for all services           |
| `pkg/database/db.go`                     | GORM connect + `SetForTest` hook             |
| `pkg/models/`                            | All GORM models (shared)                     |
| `services/auth/service.go`               | Nonce üret, ECDSA doğrula, JWT               |
| `services/agent/service.go`              | Agent CRUD, kütüphane, kredi                 |
| `services/aipipeline/service.go`         | Gemini/Claude pipeline (stateless)           |
| `services/guild/guildmaster.go`          | GuildMaster AI suggest + chat                |
| `services/workspace/legend_service.go`   | Legend workflow save/execute                 |
| `internal/testutil/db.go`               | SQLite in-memory test DB (no CGO)            |

### Frontend (Flutter Web) — 17 dosya ✅
| Dosya                                            | Açıklama                                  |
| ------------------------------------------------ | ----------------------------------------- |
| `lib/main.dart`                                  | MaterialApp.router giriş noktası          |
| `lib/app/theme.dart`                             | Koyu tema (indigo + dark bg)              |
| `lib/app/router.dart`                            | GoRouter + AppShell sidebar               |
| `lib/core/constants/api_constants.dart`          | API URL sabitleri                         |
| `lib/features/character/character_types.dart`    | CharacterType + CharacterRarity enum      |
| `lib/features/character/character_data.dart`     | 8 karakter × 16×16 pixel matrix           |
| `lib/features/character/pixel_art_painter.dart`  | CustomPainter + glow + float animasyon    |
| `lib/shared/widgets/pixel_character_widget.dart` | Karakter widget (frame + stats + badge)   |
| `lib/shared/models/agent_model.dart`             | AgentModel.fromJson                       |
| `lib/shared/services/api_service.dart`           | HTTP istemcisi (auth, agents, library)    |
| `lib/shared/services/wallet_service.dart`        | MetaMask köprüsü (JS interop)             |
| `lib/features/store/screens/store_screen.dart`   | Agent grid, arama, filtre                 |
| `lib/features/store/widgets/agent_card.dart`     | Karakter + meta kart                      |
| `lib/features/agent_detail/screens/`             | Detay + prompt kopyala + kütüphane toggle |
| `lib/features/library/screens/`                  | Kayıtlı agentlar grid                     |
| `lib/features/create_agent/screens/`             | Form + canlı karakter önizleme            |
| `lib/features/wallet/screens/`                   | MetaMask bağla / kredi görüntüle          |
| `Dockerfile + nginx.conf`                        | Flutter web build + nginx SPA             |

### Blockchain (Solidity) — 6 dosya ✅
| Dosya                             | Açıklama                              |
| --------------------------------- | ------------------------------------- |
| `contracts/AgentStoreCredits.sol` | ERC-20 benzeri kredi sistemi          |
| `contracts/AgentRegistry.sol`     | Agent sahipliği + içerik hash kaydı   |
| `hardhat.config.js`               | Monad testnet + localhost ağ konfigü  |
| `package.json`                    | Hardhat + OpenZeppelin bağımlılıkları |
| `scripts/deploy.js`               | Deploy + deployments.json kaydı       |
| `test/AgentStoreCredits.test.js`  | Mocha/Chai birim testleri (7 test)    |

## Sprint Notları
- [x] v0.1 — Proje iskeleti + Docker + CLAUDE.md (Team Leader)
- [x] v0.2 — Go API: auth, agent CRUD, character service (Backend)
- [x] v0.3 — Flutter UI: store, detail, library, create, wallet (Frontend)
- [x] v0.4 — 8 pixel-art karakter, rarity sistemi, animasyon (Gamification Master)
- [x] v0.5 — Solidity kontratlar, Monad testnet deploy scripti (Blockchain Expert)
- [x] v0.6 — flutter pub get + go mod tidy (go.sum 132 satır, flutter bağımlılıkları ok)
- [x] v0.7 — Web3 JS interop: index.html MetaMask köprüsü + dart:js_interop wallet_service
- [x] v1.0 — docker-compose up: 3 servis UP (postgres healthy, backend :8080, frontend :80) ✅
- [x] v1.1 — Claude AI entegrasyonu + keyword fallback (Backend)
- [x] v1.2 — Railway + Vercel deploy, GitHub Actions CI/CD (Team Leader)
- [x] v1.3 — E2E bug düzeltme (Backend + Frontend)
- [x] v2.0 — Gemini Flash analiz + Gemini Imagen karakter üretimi (Gamification Master + Backend)
- [x] **v2.1 — Replicate pixel-art-xl entegrasyonu** (Backend) ✅ 0 hata
- [x] **v2.2 — Trending + Category sidebar + Store UX** (Frontend) ✅ 0 hata
- [x] **v2.3 — Mini chat + Radar chart + Fork butonu** (Frontend + Backend) ✅ 0 hata
- [x] **v2.4 — Kullanıcı Profili ekranı** (Frontend + Backend) ✅ 0 hata
- [x] **v2.5 — Blockchain Credits + Leaderboard** (Backend + Frontend) → Blok 6 + 8 ✅
- [x] **v2.6 — Docker rebuild + E2E test** (Team Leader) ✅ 9/9 container UP, 20 E2E test passed
- [x] **v3.0 — Legend: Touch/Touchpad + Claude Agent Export + Live Claude Execution** (Frontend + Backend) ✅ 16 task
- [x] **v3.1 — UX Improvement Sprint** (Frontend) ✅ Guild emoji→Material Icon, keyboard nav, Mission redesign, hover consistency
- [x] **v3.2 — UX Overhaul + DB Persistence Fix** (Frontend + Backend) ✅ 24 task
- [x] **v3.3 — Legend v3.5: Undo/Redo, Templates, Clone, History UI** (Frontend) ✅ 4 feature
- [x] **v3.4 — Card Editor: split-view live editing + auto-save + undo/redo + export** (Frontend + Backend) ✅
- [x] **v3.5 — Legend overflow fixes + GuildMaster @-mention library/store sectioning** (Frontend) ✅
- [~] **v3.11.4 — Closure Sprint** (Backend partial) — 7/9 backend done: T1 Discovery analytics funnel · T2 Guild Master KPI · T3 Template metrics · T5 Leaderboard category+me+weekly rewards · T6 Guild member event log · T8 Post-run reflection · T9 Rating verified filter + copy analytics + achievements. Backend +27 tests. Backlog: 67/75 closed (89%). Remaining: T4 pipeline resilience, T7 cron mission scheduling, all 8 frontend (T11-T17).
- [x] **v3.11.3 — Pro Tools Closure** (Backend + Frontend) ✅ Legend node checkpoint/resume (WorkflowExecution.NodeStates), bulk operations (4 actions + quota guard), agent versioning + rollback (LRU 20), KPI funnel queries, API key scope middleware (dual-auth pilot), notification auto-creation hooks (notifyOnce 1h dedup), workflow versioning diff UI, observability panel (CustomPainter chart), card presets (19) + before/after diff, library bulk select + version history dialog, KPI funnel panel
- [x] **v3.11.2 — Cross-Cutting Polish** (Backend + Frontend) ✅ notification center, API keys (bcrypt + scopes), per-action credit breakdown, rating moderation, settings sectioning, i18n iskelet, theme toggle (light parchment), notification UI, developer UI, wallet error dictionary + tx timeline + per-action history icons
- [x] **v3.11.1 — User-Facing High-Impact Polish** (Backend + Frontend) ✅ fuzzy search, similar agents, mission→legend bridge, prompt template gallery, mention preview, redaction toggle, quality score, credit early-check
- [x] **v3.10 — Pro Tools** (Backend + Frontend) ✅ preflight, workflow versioning, mission marketplace, guild invite/permissions, compatibility explainability, creator analytics
- [x] **v3.9 — Discovery + Engagement** (Backend + Frontend) ✅ social follow, For You, leaderboard time windows, OG meta, activity feed
- [x] **v3.8 — Explainability + Action Bridge** (Backend + Frontend) ✅ 9 task
- [x] **v3.7 — Reliability Closure** (Backend + Frontend) ✅ 12 task
- [~] **v3.6 — Quality Foundation + Mobile Pass + Bug Bash** (in progress)
  - ✅ Quality: testutil package (sqlite-in-memory via glebarez/sqlite), `pkg/database/db.go` dialector swap, 40 backend tests (auth 12, agent 28), 43 Flutter tests (CardEditor 18, MentionFilter 15, LegendService 10), CI workflow (`.github/workflows/ci.yml`)
  - ✅ Shared `ResponsiveLayout` widget (`lib/shared/widgets/responsive_layout.dart`)
  - ⏳ Mobile Batch 1 (8 screens) — pending visual verification pass
  - ⏳ 2-day bug bash — pending

## v3.11.4 Closure Sprint — Backend Partial (2026-05-05)
7/9 backend tasks complete; closes 9 of 11 missing backlog items + 3 partial→full
upgrades. Backend +27 unit tests. `go vet ./...` clean, `go build ./...` clean.
Frontend (T11–T17) and remaining backend (T4 pipeline resilience, T7 cron mission
scheduling) deferred to v3.11.4.next session due to time/quota constraints.

**Done** (7 backend):
- **T1 Discovery analytics funnel** (3.2.1 #5): `services/agent/discovery_funnel.go`.
  GetDiscoveryFunnel returns search→save / impression→open / open→save ratios
  with -1 sentinel for empty denominators. New event types: `search`,
  `agent_impression`, `agent_open`. Wired into ListAgents (search recording)
  and GetAgent (open recording). POST /agents/impressions bulk endpoint
  (max 100 ids). GET /admin/kpi/discovery (creator-scoped, 5min cache).
  Reuses funnelSinceCutoff + ratio helpers from funnel.go.
- **T2 Guild Master KPI** (3.2.2 #5): `services/guild/kpi.go`. SuggestAcceptanceRate,
  ChatToActionRate, RerunRate. **Karar**: guild package agent package'ı
  IMPORT ETMİYOR — `recordGMActivity` helper UserActivity rows'u direkt
  database.DB ile yazıyor (notifyExecutionResult pattern reuse). Rerun rate
  Go-side group-by session_id (json_extract dialect divergence yok).
  Wired into Suggest, TeamChat, BridgeService.ToMission/ToLegend.
  GET /admin/kpi/guild-master.
- **T3 Template kalite metrikleri** (3.2.3 #5): `LegendTemplateUsage` model,
  `services/workspace/template_metrics.go`. RecordTemplateUse / RecordTemplateExecution
  (1h post-instantiation window) / GetTemplateMetrics (top by usage + success
  rate). Dialect-neutral SUM(CASE WHEN) aggregation. -1 sentinel SuccessRate
  when no completed runs. GET /legend/templates/metrics.
- **T5 Leaderboard kategori + me + ödül** (closes 3.2.9 #3, #4, #5 in one task):
  `services/agent/leaderboard_extras.go`. GetLeaderboardByCategory (top 10 per
  cat), GetUserRank (rank + 4 neighbors with IsMe flag, off-board → bottom 5
  hint), RecordWeeklyLeaderReward (top1=100/top2=50/top3=30/top4-10=10 credits,
  ISO week format YYYY-Www, idempotent via composite unique). New
  `WeeklyLeaderReward` model. **Karar**: admin endpoint X-Admin-Token +
  ADMIN_API_TOKEN env, fail-closed when env empty (v3.11.4 stopgap pending
  RBAC sprint). 4 endpoints: /leaderboard/category/:cat, /leaderboard/me,
  /leaderboard/weekly-rewards, POST /admin/leaderboard/award-weekly.
- **T6 Guild member event log** (3.2.12 #5): `GuildMemberEvent` model,
  `services/guild/events.go`. LogMemberEvent (best-effort) + ListGuildEvents
  (newest first, max 50). Wired into AddMember, JoinGuild, LeaveGuild,
  RemoveMember, SetMemberPermissions sites. GET /guilds/:id/events?limit=20.
- **T8 Post-run reflection** (3.2.15 #4): `GuildMasterReflection` model,
  `services/guild/reflection.go`. SessionService.RecordReflection /
  ListReflections — wallet-scoped via session ownership check (foreign wallet
  → ErrSessionNotFound to avoid leaking session existence). 4000 char summary
  cap. **Karar**: explicit POST only, no auto-record on Legend execution
  complete this sprint. Adapter+interface defer to v3.11.5 if FE wires it.
  POST /guild-master/sessions/:id/reflect-on-execution + GET /reflections.
- **T9 Rating verified + copy analytics + achievements** (3 sub-tasks, closes
  3 partial→full upgrades 3.2.5 #2, 3.2.5 #4, 3.2.10 #3):
  - **T9a**: GetRatings(verifiedOnly bool) — EXISTS join on PurchasedAgent.
    Backward compat: false default preserves all behavior.
  - **T9b**: POST /agents/:id/copy-analytics → RecordActivity prompt_copy.
  - **T9c**: `Achievement` model + `services/agent/achievements.go`.
    CheckAndAwardAchievements eligibility checks (first_agent, first_sale,
    first_fork via UserActivity agent_forked events, hundred_saves,
    top_creator). Idempotent via composite unique (wallet, type) +
    OnConflict-DoNothing. Wired into CreateAgent (line 552), ForkAgent,
    RecordPurchase. GET /users/:wallet/achievements.

**Yeni dosyalar** (10 + 7 test = 17):
- Backend models (5): `gm_reflection.go`, `guild_event.go`, `template_usage.go`,
  `weekly_reward.go`, `achievement.go`
- Backend services (5): `discovery_funnel.go`, `guild/kpi.go`, `guild/events.go`,
  `guild/reflection.go`, `agent/leaderboard_extras.go`,
  `workspace/template_metrics.go`, `agent/achievements.go`
- Tests (7): discovery_funnel_test.go, kpi_test.go (guild), events_test.go,
  reflection_test.go, leaderboard_extras_test.go, template_metrics_test.go,
  achievements_test.go, rating_verified_test.go

**Yeni endpoint'ler** (16):
- `GET /api/v1/admin/kpi/discovery?since=`
- `GET /api/v1/admin/kpi/guild-master?since=`
- `POST /api/v1/agents/impressions` (bulk)
- `POST /api/v1/agents/:id/copy-analytics`
- `POST /api/v1/agents/:id/ratings/:ratingID/flag` already existed; GetRatings now accepts `?verified_only=true`
- `GET /api/v1/legend/templates/metrics`
- `POST /api/v1/user/legend/templates/:templateId/used`
- `GET /api/v1/leaderboard/category/:cat?window=`
- `GET /api/v1/leaderboard/me?window=`
- `GET /api/v1/leaderboard/weekly-rewards?weeks=`
- `POST /api/v1/admin/leaderboard/award-weekly` (admin token)
- `GET /api/v1/guilds/:id/events?limit=`
- `POST /api/v1/guild-master/sessions/:id/reflect-on-execution`
- `GET /api/v1/guild-master/sessions/:id/reflections`
- `GET /api/v1/users/:wallet/achievements`

**Açık kalanlar (defer)**:
- T4 Pipeline resilience (per-stage timeout/retry, partial success cache) — 3.2.6 #2
- T7 Mission scheduling (cron, robfig/cron/v3 + monolith goroutine + UserActivity
  marker) — 3.2.13 #3
- T11–T17 frontend (8 task: smart suggestions, leaderboard UI extension, Creator
  Dashboard bulk UI, trial→purchase CTA, guild event log UI, mission schedule
  dialog, KPI panel discovery+GM sections + achievement badges UI)

**Backlog kapanışı**: 67/75 (89%). 8 madde kaldı: T4 + T7 + 6 frontend partial/items.

**Branch**: `sprint/v3.11.4-closure` (push edilmedi — uncommitted nothing).
**Commits**: d7fd1ce (T9), [next] (T6+T2), [next] (T1), [next] (T3), [next] (T5),
[next] (T8). 6 incremental commits, all passing.

## v3.11.3 Pro Tools Closure (2026-05-05)
11 task; Legend resume + bulk ops + agent versioning + KPI funnel + API key
middleware + notification hooks + frontend diff/observability/presets/bulk UI/KPI panel.
Backend +33 unit (services/agent ~159 + workspace + middleware), Frontend +14 test
(174→196). `go vet ./...` clean, `flutter analyze` 0 issue.

**Backend** (6 task):
- **Legend Node Checkpoint/Resume**: `WorkflowExecution.NodeStates` (text JSON
  checkpoint blob — `{node_id: {status, output, duration_ms}}`). `services/workspace/
  legend_service.go` per-node `nodeCheckpoint` writes inside `ExecuteWorkflow`,
  `loadNodeStates`/`saveNodeStates` helpers, `ResumeExecution(wallet, execID)`
  skip completed + reuse output, re-execute pending/failed. **Karar**: kredi
  policy — sadece resumed run complete olunca düş; original failed run partial spend
  refund yok. `POST /user/legend/executions/:execId/resume` dual-auth (`AuthOrAPIKey
  ("execute:legend")`). **Karar**: plan "LegendExecution" diyordu, gerçek model adı
  `WorkflowExecution` — yeni model değil, mevcut'a field eklendi (backward compat:
  empty string = no checkpoints). 6 unit test.
- **Bulk Operations**: `POST /agents/bulk` body `{action, ids[], payload}`. 4 action:
  `remove_from_library`, `tag_add`, `tag_remove`, `regenerate_image`.
  `bulkActionCost(action, n)` quota guard (regenerate=3 each). Per-id error tolerance
  (success/failure list). Max 100 ids enforcement. `services/agent/bulk_actions.go`.
  6 unit test.
- **Agent Versioning + Rollback**: `AgentVersion` model (AgentID index, Version int
  sequential, FieldsJSON snapshot, composite unique). `UpdateAgent` →
  `snapshotAgentVersion` best-effort. **Karar**: Rollback **2 versiyon ekler** —
  current state'i önce snapshot'lar, sonra historical fields'ı uygular, sonra
  post-rollback'i de snapshot'lar; rollback'in kendisi reversible olur.
  LRU eviction at 20 (subquery via `Pluck`, sqlite + postgres uyumlu — `LIMIT` on
  `DELETE` yok). 5 unit test.
- **KPI Funnel**: `services/agent/funnel.go` `GetFunnelMetrics(wallet, since)` —
  `SuggestToExecute`, `EditToPublish`, `PublishToFirstSaveMedianMs`, `TrialToPurchase`
  ratios + `Daily []DailyFunnelMetric`. Raw SQL aggregations (`strftime` dialect-
  agnostic). **Karar**: empty denominator için ratio = -1 (UI "—" gösterir, "0%"
  yanıltıcı değil). **Karar**: `MIN(saved_at)` sqlite'ta string döner — yeni
  `parseFlexTimestamp` helper iki dialect'i de handle eder, query değişmiyor.
  Cache `funnel|<wallet>|<since>` 5dk TTL. `GET /admin/kpi/funnel?since=7d|30d|90d`.
  5 unit test.
- **API Key Scope Middleware**: `pkg/middleware/api_key_auth.go` — `APIKeyAuth(scope)`
  + `AuthOrAPIKey(scope)` helpers. Header parse (`X-API-Key` veya `Authorization:
  Bearer agst_...`), prefix lookup → bcrypt verify → revoked + scope check → wallet
  inject. **Karar**: middleware `pkg/middleware/` altında (services/agent değil) —
  import cycle önle, `apiKeyNamespacePrefix` constant duplicate. **Karar**:
  `AuthOrAPIKey` JWT öncelikli — JWT varsa API key path tamamen bypass, internal
  microservice trafiği etkilenmez. Async `LastUsedAt` update goroutine + nil-DB
  guard (RecordActivity pattern). Pilot 3 endpoint dual-auth: `POST /agents`
  (`write:agents`), yeni `GET /keyed/agents` (`read:agents`), `/legend/executions/
  :id/resume` (`execute:legend`). 6 unit test.
- **Notification Auto-Creation Hooks**: `notifyOnce(wallet, type, title, body, link)`
  helper — IsPrefEnabled check + `notificationDedupCheck` 1h window + `CreateNotification`
  best-effort. Wired sites: `FollowUser`→followee, `AddToLibrary`→creator,
  `ForkAgent`→original creator, Legend execution complete (success+failed)→wallet,
  `RecordPurchase`→creator+buyer. **Karar**: synchronous (RecordActivity nil-DB
  guard pattern, t.Cleanup race önleme). Self-notifications (creator saving own
  agent, follower notifying themselves) skipped. Legend execution notifications
  workspace'ten direct DB write (circular import önle). 6 unit test.

**Frontend** (5 task):
- **Workflow Versioning Diff UI**: `/legend?id=X&compare=v1,v2` query param.
  `lib/features/legend/widgets/version_diff_panel.dart` — node-by-node split
  (added=green border, removed=red strikethrough, modified=yellow + field-level
  diff). "Compare versions" toolbar dialog (2 dropdown). Backend v3.10
  `LegendWorkflowVersion` reuse. 4 widget test.
- **Execution Observability Panel**: `/legend/observability/:executionId` route.
  `observability_screen.dart` 5 özet kart + `observability_chart.dart` (pure-Dart
  CustomPainter bar chart, **no chart lib dep**) + DataTable (node id/status/
  output preview/duration/credits). 3 widget test.
- **Card Presets + Before/After Diff**: `lib/features/card_editor/data/card_presets.dart`
  19 preset (8 character types + 2 universal). `card_editor_controller.dart`
  `applyPreset()` history snapshot + draft merge + dirty flag.
  `editor_toolbar.dart` `PresetMenuButton` PopupMenuButton (kategori filter) +
  `PreviewChangesButton`. `card_diff_modal.dart` split-view (sol original AgentCard,
  sağ draft) + change-chip list (`Wrap` of "field: 'Old' → 'New'"). Pure
  `diffFields` helper extract for testability. 5 unit test.
- **Bulk Operations + Versioning UI**:
  - **T10a Library bulk select**: `library_screen.dart` "Select" mode toggle,
    Checkbox overlay, `_BulkActionBar` floating bottom bar, `_bulkRemoveSelected`
    flow. `lib/shared/state/bulk_select_state.dart` — `ChangeNotifier`-backed
    pure helper (testability).
  - **T10b Creator Dashboard bulk regenerate**: defer'd to v3.11.4 — Creator
    Dashboard `StatelessWidget`, refactor non-trivial. Reusable
    `BulkSelectState` helper, `bulkAgentAction` API, `_BulkActionBar` widget
    pattern hazır — port "wire 4 things" iş.
  - **T10c Card editor History dialog**: `version_history_dialog.dart` list +
    Restore (with `fetchOverride` / `rollbackOverride` test seams) +
    ConfirmDialog. `editor_toolbar.dart` History icon (Icons.history).
    `card_editor_screen.dart` `onShowHistory` + `onReload` callback wired.
  - 4 yeni API method: `bulkAgentAction`, `getAgentVersions`, `getAgentVersion`,
    `rollbackAgentVersion`. 6 test (3 unit + 3 widget).
- **KPI Funnel Panel**: `/admin/kpi` route + sidebar "Insights" nav item.
  `funnel_panel_screen.dart` 7d/30d/90d window selector + 4 `_FunnelCard`
  metric kart (Suggest→Execute, Edit→Publish, Publish→FirstSave, Trial→Purchase
  + delta chip + color coding). `funnel_card.dart` widget. `getFunnelMetrics`
  API. 3 widget test.

**Yeni dosyalar**:
- `backend/pkg/models/agent_version.go`
- `backend/pkg/middleware/{api_key_auth.go, api_key_auth_test.go}`
- `backend/services/agent/{bulk_actions,versioning,funnel}.go` + 3 test
- `backend/services/agent/notification_hooks_test.go`
- `backend/services/workspace/legend_resume_test.go`
- `agent_store/lib/features/legend/widgets/{version_diff_panel,observability_chart}.dart`
- `agent_store/lib/features/legend/screens/observability_screen.dart`
- `agent_store/lib/features/card_editor/data/card_presets.dart`
- `agent_store/lib/features/card_editor/widgets/{card_diff_modal,version_history_dialog}.dart`
- `agent_store/lib/shared/state/bulk_select_state.dart`
- `agent_store/lib/features/insights/screens/funnel_panel_screen.dart`
- `agent_store/lib/features/insights/widgets/funnel_card.dart`
- `agent_store/test/{widget/{version_diff,observability_chart,version_history,funnel_panel}_test.dart, unit/{card_presets,bulk_select_state}_test.dart}`

**Genişletilen modeller/dosyalar**:
- `pkg/models/workspace.go` (`WorkflowExecution.NodeStates`)
- `internal/testutil/db.go` + `services/agent/migrate.go` + `services/workspace/migrate.go`
  (AgentVersion + WorkflowExecution AutoMigrate)
- `services/workspace/{legend_service.go (nodeCheckpoint, ResumeExecution,
  notifyExecutionResult), handler.go, router.go}`
- `services/agent/{service.go (UpdateAgent snapshot + AddToLibrary/ForkAgent/
  RecordPurchase notifyOnce + ForkAgent nil-aiClient guard), social.go (FollowUser
  notify + slices.Contains), notification.go (notifyOnce, notificationDedupCheck,
  IsPrefEnabled), handler.go, router.go (6 yeni route + dual-auth pilot)}`
- `services/agent/handler.go` 5 yeni handler (BulkAction, ListAgentVersions,
  GetAgentVersion, RollbackAgentVersion, GetFunnelMetrics)
- `agent_store/lib/app/router.dart` (3 yeni route + Insights sidebar)
- `agent_store/lib/features/legend/screens/legend_screen.dart` (compare query +
  `_VersionDiffOverlay` + Compare toolbar button)
- `agent_store/lib/features/card_editor/{controllers/card_editor_controller.dart
  (applyPreset), widgets/editor_toolbar.dart (3 yeni button), screens/
  card_editor_screen.dart (callback wiring)}`
- `agent_store/lib/features/library/screens/library_screen.dart` (bulk mode)
- `agent_store/lib/shared/services/api_service.dart` (5 yeni method)

**Yeni endpoint'ler** (8):
- `POST /api/v1/user/legend/executions/:execId/resume` (dual-auth)
- `POST /api/v1/agents/bulk`
- `GET /api/v1/agents/:id/versions` + `/:v` + `POST /:v/rollback`
- `GET /api/v1/admin/kpi/funnel?since=7d|30d|90d`
- `GET /api/v1/keyed/agents` (dual-auth pilot)
- `POST /api/v1/agents` upgrade → `AuthOrAPIKey("write:agents")`

**Açık tasklar (post-launch)**: Full i18n string sweep (mevcut 30+ ekran),
Notification WebSocket/SSE, Agent versioning UI'da diff view (current vs version v),
Bulk operations scheduling (cron-trigger), KPI A/B test framework, API key middleware
tüm endpoint'lere full sweep, Mobile responsive observability + funnel panel,
Creator Dashboard bulk regenerate UI (T10b refactor).

## v3.11.2 Cross-Cutting Polish (2026-05-05)
10 task; settings sectioning + i18n iskelet + theme toggle + notification center +
API keys + wallet UX trio + rating moderation. Backend +28 unit (services/agent
126/126 passing), Frontend +24 test (174/174 passing). `go vet ./...` clean,
`flutter analyze` 0 issue.

**Backend** (4 task):
- **Notification Center**: `NotificationPref` + `NotificationEvent` models
  (`pkg/models/notification.go`) — composite uniqueness on (wallet, channel, type),
  cursor index on (wallet, id DESC). Service `services/agent/notification.go`:
  `ListPrefs` (default seed: 3 type × 2 channel = 6 entries via `Create(map)` to
  bypass GORM `default:true` stomp), `UpdatePref` upsert, `ListInbox` cursor
  pagination (v3.9 GetActivityFeed pattern), `MarkRead`, `MarkAllRead`,
  `CreateNotification` helper. 7 unit test (default seed, upsert validation,
  cursor, mark-read idempotency, wallet isolation, mark-all bulk, disabled-pref drop).
- **API Keys**: `APIKey` model (Wallet, Name, KeyHash bcrypt, Prefix size:32,
  Scopes CSV, LastUsedAt/RevokedAt nullable). Service `api_keys.go`: `CreateKey`
  generates `agst_` + 32 hex (crypto/rand), bcrypt hash, returns plaintext **once**;
  `ListKeys` returns masked (KeyHash JSON `-`); `RevokeKey` tombstones.
  3 sabit scope: `read:agents`, `write:agents`, `execute:legend`.
  **Karar**: `SetAPIKeyBcryptCostForTest(bcrypt.MinCost)` testlerde — production
  `bcrypt.DefaultCost` (10) kullanır. 5 unit test.
- **Per-Action Credit Breakdown**: `CreditTransaction.Action` + `Metadata` field'ları
  eklendi. **Karar**: yeni ledger tablosu yerine `normaliseLedgerAction` helper
  legacy `Type` değerlerini map ediyor (`create`→`agent_create`, `fork`→`agent_fork`,
  `workflow_execute`/`legend_run_node`→`legend_node`, `purchase`→`agent_purchase`,
  `regenerate_image`→`image_regen`). `RecordPurchase`, `RegenerateImage`,
  `TopUpCredits` artık Action+Metadata yazıyor. Backward compat: empty Action OK.
  4 unit test.
- **Rating Moderation**: `RatingFlag` model (composite unique
  `idx_rating_flag_unique` on rating_id+reporter_wallet) + `AgentRating.Hidden`
  field. `FlagRating` transaction ile FOR UPDATE lock + `clause.OnConflict{DoNothing}`
  insert + count + auto-hide at ≥3 flags. Rate-limit: 3 flag / wallet / 5dk.
  **Karar**: `isAbusive(rating.Comment)` kullanılarak 3-vote threshold by-pass —
  abusive content olan bir rating tek flag'le anında hidden olur (profanity word
  list + URL count >2 heuristic). `GetRatings` artık `WHERE hidden=false` filtreliyor.
  5 unit test.

**Frontend** (6 task):
- **Settings Sectioning + Routing**: `lib/features/settings/widgets/settings_sidebar.dart`
  (SettingsSidebar + SettingsLayout). 4 alt route (`/settings`, `/settings/notifications`,
  `/settings/appearance`, `/settings/developer`). PageHeader (v3.2) + GoRouter nested.
  **Karar**: SettingsLayout drives via `MaterialApp.router` — widget testler real
  GoRouter config gerekir (plain MaterialApp `GoRouterState.of` errors).
- **i18n iskelet**: `flutter_localizations` + `intl` + `l10n.yaml` config
  (`synthetic-package: false` + `output-dir: lib/l10n/gen` — default synthetic
  Flutter SDK build'inde dosya materialise olmuyor). `lib/l10n/{app_en,app_tr}.arb`
  ~30 string sadece yeni Settings ekranları için. `LocaleController` GetX +
  SharedPreferences `locale_v1`. 3 unit test.
- **Theme Toggle**: `AppTheme.lightTheme` (parchment palette: `bgLight=0xFFF5F1E8`,
  `cardLight=0xFFEDE6D3`, `card2Light=0xFFE3DABF`, `textHLight=0xFF2A1F0E`,
  `textMLight=0xFF5C4A2E`). Shared `_build()` helper iki variant'ı senkron tutar.
  `ThemeController` (mode obs: dark/light/system, SharedPreferences `theme_mode_v1`).
  `main.dart` MaterialApp.router Obx-wrap, `theme: lightTheme`, `darkTheme: darkTheme`.
  Appearance UI: theme radio + language dropdown. 3 unit test.
- **Notification UI**: `notifications_screen.dart` + `NotificationPrefsController`.
  ApiService 5 yeni metod (getNotificationPrefs/updateNotificationPref/
  getNotificationInbox cursor/markNotificationRead/markAllNotificationsRead).
  3×2 SwitchListTile.adaptive matrix + cursor inbox + mark-all-read CTA. 4 test.
- **Developer/API Key UI**: `developer_screen.dart`. ApiService 3 metod
  (createApiKey/listApiKeys/revokeApiKey). Create modal: name + 3 scope checkbox →
  plaintext key one-time-show + Clipboard.setData + warning. List: masked prefix +
  scopes chip + last-used relative + revoke ConfirmDialog. 3 widget test.
- **Wallet UX trio (T10)**:
  - `wallet_errors.dart`: `WalletError` class + Map (kodlar: `-32603`, `4001`,
    `4100`, `4901`, `4902`, `-32002`, `network_error`, `insufficient_funds`).
    `friendlyError(e)` helper. `WalletService` catch'leri buna bağlandı.
  - `tx_timeline.dart`: 4-step linear stepper (Signed→Broadcast→Mined→Confirmed),
    TxState enum (v3.7) sync. `_showPurchaseTimeline()` modal bottom sheet
    `purchaseAgentFlow` öncesi. `tx_timeline.dart` `TxState`/`TxStateX` re-export
    eder — caller tek import.
  - `credit_history_screen.dart` per-action ikon (shopping_cart/flash_on/image/
    add_circle/history fallback) + tooltip (action+metadata).
  - 6 wallet error test + 5 timeline widget test.

**Yeni dosyalar**:
- `backend/pkg/models/{notification,api_key,rating_flag}.go`
- `backend/services/agent/{notification,api_keys,rating_moderation}.go` + 3 test
- `backend/services/agent/credits_history_test.go`
- `agent_store/lib/controllers/{locale_controller,theme_controller}.dart`
- `agent_store/{l10n.yaml, lib/l10n/{app_en,app_tr}.arb}` + auto-gen
- `agent_store/lib/features/settings/widgets/settings_sidebar.dart`
- `agent_store/lib/features/settings/screens/{appearance,notifications,developer}_screen.dart`
- `agent_store/lib/shared/services/wallet_errors.dart`
- `agent_store/lib/features/agent_detail/widgets/tx_timeline.dart`
- `agent_store/test/unit/{locale_controller,theme_controller,wallet_errors,notification_prefs}_test.dart`
- `agent_store/test/widget/{tx_timeline,developer_screen}_test.dart`

**Genişletilen modeller/dosyalar**:
- `pkg/models/{agent_rating.go (Hidden bool), credit_transaction.go (Action+Metadata)}`
- `internal/testutil/db.go` + `services/agent/migrate.go` (4 yeni model AutoMigrate)
- `services/agent/{service.go (normaliseLedgerAction, appendLedger, GetRatings filter),
  handler.go (9 yeni handler), router.go (9 yeni route)}`
- `agent_store/pubspec.yaml` (flutter_localizations + intl + generate:true)
- `agent_store/lib/main.dart` (locale + theme + l10n delegates wired)
- `agent_store/lib/app/{theme.dart (lightTheme variant), router.dart (3 yeni route)}`
- `agent_store/lib/shared/services/api_service.dart` (8 yeni metod)
- `agent_store/lib/shared/services/wallet_service.dart` (friendlyError catch'leri)
- `agent_store/lib/features/wallet/screens/credit_history_screen.dart` (action ikon)
- `agent_store/lib/features/agent_detail/screens/agent_detail_screen.dart` (timeline modal)

**Yeni endpoint'ler** (10):
- `GET/PATCH /api/v1/user/notifications/prefs`
- `GET /api/v1/user/notifications/inbox?before=&limit=`
- `POST /api/v1/user/notifications/inbox/:id/read`
- `POST /api/v1/user/notifications/inbox/mark-all-read`
- `POST/GET /api/v1/user/api-keys` + `DELETE /api/v1/user/api-keys/:id`
- `POST /api/v1/agents/:id/ratings/:ratingID/flag`

**Açık tasklar (v3.11.3'e defer)**: API key scope-based middleware enforcement,
notification event auto-creation hooks (CreateAgent/LibraryAdd/LegendExecute push),
mevcut tüm ekranların i18n string sweep'i, WebSocket/SSE notification, Legend node
checkpoint/resume, workflow diff UI, observability paneli, agent versioning, bulk
operations, KPI panosu.

## v3.11.1 User-Facing Polish (2026-05-05)
8 task; user'ın ilk gün gördüğü iyileştirmeler — `eksiklikleri-könçürleme.md`
backlog'unun v3.11 fazlarına bölünmüş ilk halkası. Backend +17 unit, Frontend +37 test.
`go vet ./...` clean, `flutter analyze` 0 issue, 150 frontend test yeşil (113 pre-existing + 37 new).

**Backend** (3 task):
- **Fuzzy + weighted search**: `ListAgents` (`services/agent/service.go`) artık dolu
  `search` parametresinde GORM'dan **limit 200 aday seti** çekip Go-side weighted
  (title 3×, tag 2×, desc 1×) + Levenshtein fuzzy re-rank uyguluyor. Boş query path
  ve cache anahtarı değişmedi (deterministik re-rank). Yeni helper:
  `services/agent/search_rank.go` (`scoreAgent`, `levenshteinSimilarity`,
  `tokenize`, `rankAgentsByQuery`, `rankBySimilarity`). `pg_trgm` extension
  bağımlılığı yok — SQLite test + PostgreSQL prod aynı kod path. **Karar**:
  fuzzyThreshold 0.7→0.6 ("wziard"≈"wizard" Lev=0.667 sınırın üstü olsun).
- **Similar agents endpoint**: `GET /api/v1/agents/:id/similar?limit=5`. Aynı
  character_type, save_count desc, source agent excluded, 5dk cache (key:
  `similar|<id>|<limit>`). `AddToLibrary`/`RemoveFromLibrary` cache bust'larına
  `s.cache.DeletePrefix("similar|")` eklendi.
- **Mission→Legend bridge**: `POST /api/v1/user/missions/:id/to-legend`.
  `BridgeService.MissionToLegend(wallet, missionID)` yeni metod +
  `buildSingleNodeWorkflow(title, prompt)` helper (START→MISSION_AGENT→END,
  3 nodes / 2 edges). Empty/whitespace prompt → 422. **Karar**: workspace
  package guild package'ı import etmesin diye **interface + adapter pattern** —
  `workspace.MissionLegendBridge` interface, `cmd/monolith/main.go`'da
  `missionBridgeAdapter` ile guild→workspace LegendDraftResult dönüşümü.
  Standalone `cmd/workspacesvc` binary 503 döner (cross-service wiring
  monolith-only).

**Frontend** (5 task + 1 bridge UI):
- **Prompt template galerisi**: `lib/features/create_agent/data/prompt_templates.dart`
  (10 hazır template, 8 karakter tipine dengeli) +
  `widgets/prompt_templates_dialog.dart` modal (legend_templates_dialog pattern,
  MouseRegion + AnimatedContainer 150ms gold 0.08 alpha). Step 1 header'da
  "Use template" butonu, seçim → `_promptCtrl.text` + tag chip append.
- **Similar agents ribbon**: yeni
  `lib/features/agent_detail/widgets/similar_agents_ribbon.dart`. Loading 3×
  ShimmerBox(180×220, radius 14), error/empty silent fail. **Test hook**:
  `fetchOverride` + `cardBuilder` parametreleri (AgentCard hover animasyonları
  + 4.4px overflow widget test'i kırıyordu — production caller'lar null geçer).
- **Mention preview hover kartı**: yeni
  `lib/features/guild_master/widgets/mention_preview_card.dart` (width 280,
  description 2 line + characterType + rarity border + mini avatar). Composer
  `_MentionItem` StatefulWidget'a dönüştü, `OverlayEntry` ile float, sağ kenar
  taşarsa otomatik flip-left (`MediaQuery.size.width` check).
- **Prompt redaction toggle**: yeni
  `lib/features/agent_detail/widgets/prompt_redaction.dart` pure helper'lar
  (`shouldOfferPromptToggle`, `displayedPromptBody`).
  `agent_detail_controller.dart` `promptShowFull` Rx. >500 char prompt'larda
  toggle row (Icons.unfold_more/less + char count).
- **Pre-publish quality score**: mevcut `_PromptQualityBadge` (Step 1, charCount-only)
  korundu; yeni `_QualityScoreCard` Step 2'de (length 40 + tags 30 + character
  match 30). ≥80 yeşil "Excellent", 50-79 sarı "Good", <50 kırmızı + öneri.
  **Karar**: backend `promptScore` post-publish döndüğü için Step 2'de
  `_approximatePromptMatchScore()` heuristik (`CreateAgentController.keywordsFor()`
  ile keyword hit count) — live preview character detection ile aynı map.
  Pure-Dart scorer extract: `lib/features/create_agent/data/quality_score.dart`
  (16 unit test).
- **Credit early-check banner**: `kAgentCost = 10` constant +
  `hasInsufficientCredits` getter. Step 0 üstünde `_CreditWarningBanner`
  (Obx-driven), turuncu, "10 credits needed, you have X" + Top-up CTA →
  `/wallet`. **Karar**: test pure getter contract'ı izliyor (private widget mount
  yerine), v3.6 mention_filter pattern'i.
- **Open in Legend** ikonu (T3.5): `api_service.dart` `missionToLegend(id)` →
  POST endpoint, dönen workflow ID. Mission Marketplace `_MissionCard`'a
  Icons.flash_on (gold) + `_openInLegend()` spinner state. Missions ana ekranı
  hem desktop icon column hem mobile PopupMenu varyantı. Success: snackbar +
  `context.go('/legend?id=$wfId')`.

**Yeni dosyalar**:
- `backend/services/agent/{search_rank.go, search_rank_test.go, similar_test.go}`
- `backend/services/guild/bridge_mission_test.go`
- `agent_store/lib/features/create_agent/data/{prompt_templates.dart, quality_score.dart}`
- `agent_store/lib/features/create_agent/widgets/prompt_templates_dialog.dart`
- `agent_store/lib/features/agent_detail/widgets/{similar_agents_ribbon.dart, prompt_redaction.dart}`
- `agent_store/lib/features/guild_master/widgets/mention_preview_card.dart`
- `agent_store/test/{unit/{prompt_templates,similar_ribbon,prompt_redaction,quality_score}_test.dart, widget/{mention_preview,credit_banner}_test.dart}`

**Genişletilen dosyalar**: `backend/services/agent/{service,handler,router}.go`,
`backend/services/guild/bridge.go`, `backend/services/workspace/{handler,router}.go`,
`backend/cmd/monolith/main.go`, `agent_store/lib/shared/services/api_service.dart` (2
yeni metod), `agent_store/lib/controllers/{create_agent_controller,agent_detail_controller}.dart`,
`agent_store/lib/features/create_agent/screens/create_agent_screen.dart`,
`agent_store/lib/features/agent_detail/screens/agent_detail_screen.dart`,
`agent_store/lib/features/guild_master/widgets/mention_composer.dart`,
`agent_store/lib/features/missions/screens/{mission_marketplace,missions}_screen.dart`.

**Yeni endpoint'ler**:
- `GET /api/v1/agents/:id/similar?limit=5` (optionalAuth)
- `POST /api/v1/user/missions/:id/to-legend` (auth)

**Açık tasklar (v3.11.2/.3'e defer)**: i18n iskeleti, theme toggle, notification
center, API keys, wallet error dictionary, per-action credit breakdown, Legend node
checkpoint/resume, workflow diff UI, observability paneli, agent versioning, bulk
operations, KPI panosu. `könçürleme.md` 7 UX şikayeti ayrı "UX Bug Bash" sprint'ine.

## v3.10 Pro Tools (2026-05-04)
21 files changed (3 new backend + 1 new frontend screen), `go build ./... && flutter analyze` both clean.

**Backend** (7 domains):
- **Legend preflight validator**: `PreflightWorkflow` endpoint — loads workflow, parses nodes, runs `validateWorkflowStructure`, estimates credits via `creditCostForModel` map (haiku=1, sonnet=3, opus=10). Returns `{valid, issues[], estimated_credits, node_count, agent_node_count}`.
- **Legend workflow versioning**: `LegendWorkflowVersion` model (wallet, workflowID, version, name, nodesJSON, edgesJSON). `snapshotWorkflowVersion()` called after every `SaveUserWorkflow` (best-effort, non-fatal). `ListWorkflowVersions` (max 20, newest first) + `GetWorkflowVersion` endpoints.
- **Mission marketplace**: `Public bool` field on `UserMission`. `ListPublicMissions(catPrefix)`, `ImportPublicMission(wallet, clientID)` (slug uniqueness via `ensureUniqueSlug`), `SetMissionPublic(wallet, clientID, public)` endpoints.
- **Guild invite links**: `GuildInvite` model (32-char crypto/rand hex token, ExpiresAt, MaxUses, UsesCount). `CreateInvite` (owner-only, 7-day default), `GetInvite`, `AcceptInvite` (increments uses_count), `DeleteInvite` endpoints.
- **Guild permissions**: `Permissions string` JSON array on `GuildMember`. `SetMemberPermissions` validates against 5 known keys (`edit_agents`, `invite_members`, `kick_members`, `change_compatibility`, `manage_roles`).
- **Compatibility explainability**: `ExplainCompatibility` — 3-factor breakdown (type diversity 40pt, rarity balance 30pt, role completeness 30pt). Uses `CharacterRarity` string-cast for map lookup.
- **Creator analytics**: `GetCreatorInsights` with `since` param (7d/30d/90d). Queries library_entries + agent_use_logs + UserActivity; daily grouping via `strftime('%Y-%m-%d', ...)` (works SQLite+PostgreSQL). Per-agent `AgentInsight{TotalSaves, TotalUses, TotalForks, Daily[]DailyMetric}`.

**Frontend** (4 items):
- **api_service.dart**: 12 new methods — preflight, versions, getPublicMissions, importPublicMission, setMissionPublic, createGuildInvite, getGuildInvite, acceptGuildInvite, setMemberPermissions, explainCompatibility, getCreatorInsights.
- **Legend preflight dialog**: `_showPreflightAndExecute()` wraps Execute button — fetches `/preflight`, shows cost notice on success, issue list on warnings, blocks on invalid. `_PreflightRow` helper widget.
- **Mission Marketplace screen** (`lib/features/missions/screens/mission_marketplace_screen.dart`): category filter chips + search bar + list + per-item import button (spinner during import). Route `/missions/marketplace` + sidebar nav item.
- **Guild Detail**: invite link dialog (copy to clipboard, shows token URL), `_CompatibilitySection` widget with expandable 3-factor breakdown (linear progress bars per factor).

**New files**: `backend/services/agent/analytics.go`, `backend/services/guild/invite.go`, `agent_store/lib/features/missions/screens/mission_marketplace_screen.dart`.
**New models**: `LegendWorkflowVersion`, `GuildInvite`, `UserMission.Public`.
**Karar**: Legend node checkpoint/resume (L) + Mission scheduling (cron) deferred to v3.11 (complexity + no scheduler infra yet).

## v3.8 Explainability + Action Bridge (2026-05-04)
9 task; 4 backend + 4 frontend + 1 test/docs. Closes the "açıklanabilirlik
+ tek tık akış geçişi" track of the eksiklikleri-könçürleme.md backlog.
Mission detail "Add to Legend" CTA + mention preview hover kartı v3.9'a
deferred (mission detail tek dosya 33KB list+edit ekranı; ayrı detail
route ve Mission→Legend bridge endpoint yok).

**Backend** (4 task):
- **Structured suggest output kontratı**: `GuildSuggestion`'a Goal +
  Plan ([]PlanStep) + Owners ([]OwnerAssignment) + Risks +
  SuccessCriteria + ConfidencePerType eklendi. AI system prompt'u
  yeni JSON shape'i zorunlu kılıyor; tolerant parser eski legacy
  shape'i de yakalıyor (geri uyumlu). Yeni helper'lar:
  `filterConfidencePerType` (0..1 clamp + percent normalisation),
  `normalisePlan` (re-numbering + empty drop), `filterOwners`
  (type whitelist), `trimStrings`.
- **Per-agent reasoning + confidence**: `MatchingAgent` wrapper
  (embedded `models.Agent` + Reason/Confidence/Contribution). Composite
  rankCandidates skoru `roundConfidence` ile 2 decimal'a yuvarlanır.
- **Chat history persistence**: yeni `models.GuildMasterSession`
  (Wallet, Title, Problem, MessagesJSON jsonb, SuggestionJSON jsonb,
  MessageCount). `services/guild/sessions.go` SessionService — CRUD
  endpoints + `AppendMessages` (FOR UPDATE locked transaction +
  4 KB content cap + role validation: user/agent/system).
- **Action bridge endpoints**: `services/guild/bridge.go` BridgeService.
  `ToMission` Goal + Plan + Owners + Risks + Success criteria'yı
  Markdown prompt'una dökerek UserMission yaratır (yeni `slugify`
  helper Mission slug regex'ine uyumlu). `ToLegend` fan-out/fan-in
  DAG yaratır (1 START → N agent nodes → 1 END), grid-positioned.

**Frontend** (3 task tamamlandı, 1 deferred):
- **SuggestPanel widget** (`suggest_panel.dart`): pure presentational
  5-section card (Goal / Plan / Owners / Risks+Success criteria
  yan yana / Confidence by type linear progress / Matching agents
  with reason + confidence chip). Bottom sheet'te modal olarak açılır.
- **Action bridge UI**: GuildMaster sol panel'inde "Save as Mission"
  + "Open in Legend" buton çifti + disabled hint label. Open in
  Legend success → `LegendService.refresh()` + `context.go('/legend?id=...')`.
- **Sessions UI**: "View plan" yanında "Sessions" link butonu,
  bottom sheet listesi (active session highlight, swipe-action delete,
  tap-to-resume). `loadSessionList`/`selectSession`/`deleteSession`
  controller methods. `findTeam` artık session create + suggest
  (session_id ile) çağırıyor — backend structured suggestion'ı
  saklasın. SharedPreferences fallback korundu (offline path).

**Test/CI**:
- Backend: yeni `services/guild/sessions_test.go` (14 test —
  CRUD, wallet scoping, message validation, content cap, suggestion
  persist, list ordering) + `services/guild/guildmaster_test.go`
  (16 test — confidence clamp/normalise, plan renumber, owners
  whitelist, slugify, buildMissionPrompt sections). Toplam +30 yeni
  backend unit. testutil yeni `GuildMasterSession` model'ini
  AutoMigrate ediyor.
- Frontend: 83 mevcut test yeşil, `flutter analyze` 0 issue.

**Yeni dosyalar**:
- `backend/pkg/models/guildmaster.go` (GuildMasterSession)
- `backend/services/guild/sessions.go` (SessionService + CRUD)
- `backend/services/guild/bridge.go` (BridgeService — Mission/Legend draft)
- `backend/services/guild/{sessions,guildmaster}_test.go`
- `agent_store/lib/features/guild_master/widgets/suggest_panel.dart`

**Genişletilen modeller/dosyalar**:
- `GuildSuggestion.{Goal,Plan,Owners,Risks,SuccessCriteria,ConfidencePerType}`
- `MatchingAgent` (yeni wrapper, embedded `models.Agent` + 3 ek alan)
- `services/guild/{guildmaster,handler,router,migrate}.go`
- `services/guild/handler.go` Suggest endpoint `session_id` opsiyonel param
- `agent_store/lib/controllers/guild_master_controller.dart`
  (currentSessionId, sessionList, isBridgeLoading, lastBridgeMessage,
  saveAsMission, openInLegend, loadSessionList, deleteSession,
  selectSession)
- `agent_store/lib/shared/services/api_service.dart` (8 yeni method:
  list/create/get/append/delete sessions + bridge to-mission/to-legend
  + suggestGuild's optional sessionId param)
- `agent_store/lib/features/guild_master/screens/guild_master_screen.dart`
  (`_BridgeActions` widget + `_showSuggestPanelSheet` + `_showSessionsSheet`)

**Yeni endpoint'ler**:
- `GET/POST /api/v1/guild-master/sessions`
- `GET/PATCH/DELETE /api/v1/guild-master/sessions/:id`
- `POST /api/v1/guild-master/sessions/:id/messages`
- `POST /api/v1/guild-master/sessions/:id/to-mission`
- `POST /api/v1/guild-master/sessions/:id/to-legend`
- `POST /api/v1/guild-master/suggest` body'sine opsiyonel `session_id`

**Karar**: Mission/Legend bridge'leri *direct DB write* ile yapılıyor
(workspace service'i HTTP ile çağırmak yerine `models.UserMission` /
`models.UserLegendWorkflow` Create). Tutarlılık için workspace
service'iyle aynı modeli paylaşıyor — monolith bağlam altında bu
katman cross-cutting yerine library reuse oluyor.

## v3.9 Discovery + Engagement (2026-05-04)

**Backend** — `backend/pkg/models/social.go` + `backend/services/agent/social.go` + `social_test.go`:
- **UserFollow model**: composite `uniqueIndex:idx_follow_pair` (follower+followee), `FollowUser`
  uses `clause.OnConflict{DoNothing:true}` (idempotent), `UnfollowUser` hard deletes.
- **UserActivity model**: `idx_activity_wallet_time` composite index; `RecordActivity` has
  nil-DB guard (`if database.DB == nil { return }`) — goroutine-safe after race-condition fix.
  All `RecordActivity` calls in CreateAgent/AddToLibrary/ForkAgent are **synchronous** (not goroutines)
  to avoid t.Cleanup reset race in tests.
- **GetActivityFeed**: ID-cursor pagination (`before_id`), scope limited to target wallet,
  ordered by id DESC.
- **GetForYou**: character_type majority from user's library → ranked store agents, excludes
  saved IDs + own agents (`strings.ToLower(a.CreatorWallet) == wallet`); trending fallback
  when < 5 results; 5-min cache keyed `for-you|<wallet>`.
- **GetLeaderboardWindowed**: raw SQL LEFT JOIN on `library_entries.saved_at >= cutoff` +
  `agent_use_logs.created_at >= cutoff`; works in both SQLite (tests) and PostgreSQL (prod).
- **RenderOGHTML**: escapes `&`, `"`, `<`, `>`; `meta http-equiv refresh` → SPA; served at
  `/api/v1/og/agent/:id` as `text/html; charset=utf-8` with `Cache-Control: public, max-age=3600`.
- **24 new tests** in social_test.go (follow CRUD, activity cursor, For You exclusions,
  OG meta fields/truncation/escaping, leaderboard windowed time filtering).

**Frontend**:
- `api_constants.dart`: `agentsForYou` + `users` endpoints added.
- `api_service.dart`: `followUser`, `unfollowUser`, `getFollowStatus`, `getActivityFeed`
  (cursor), `getForYou`, `getLeaderboard` now accepts `window` param.
- `leaderboard_controller.dart`: `window = 'all'.obs` + `selectWindow` + windowed `load`.
- `leaderboard_screen.dart`: `_WindowSelector` — 3 chips (7 Days / 30 Days / All Time)
  with `AnimatedContainer` gold highlight on selected.
- `public_profile_screen.dart`: `_FollowSection` sliver (follower/following count pills +
  optimistic Follow/Unfollow — flip state, revert on API failure); `_ActivityFeedSection`
  sliver (timeline, type icons, relative timestamps, load-more cursor).
- `store_controller.dart`: `forYouAgents` + `forYouLoading` + `loadForYou` (auth-gated,
  no-op if unauthenticated or already populated) + `refreshForYou` (clears + reloads).
- `store_screen.dart`: `_ForYouMiniCard` horizontal row inside `_buildDiscovery()` —
  auth-only, lazy skeleton placeholders while loading, divider separator.
- `library_screen.dart`: `_buildEmptySavedState` now renders 5 trending nudge cards
  (`_TrendingNudgeCard`) pulled from permanent `StoreController.trendingAgents`; save
  action triggers `_ctrl.load()` to exit empty state immediately.

**Yeni dosyalar**: `backend/pkg/models/social.go`, `backend/services/agent/social.go`,
`backend/services/agent/social_test.go`.

**Karar**: `RecordActivity` synchronous (not goroutine) because t.Cleanup resets
`database.DB` before goroutines finish — avoids "no such table" flakiness in tests.

## v3.7 Reliability Closure (2026-05-04)
12 task tamamlandı; "stabilite açığı" maddelerinin tümü kapatıldı. Backlog
dosyası `eksiklikleri-könçürleme.md`'deki 14 alana yayılmış 5 sprintlik
yol haritasının ilk halkası.

**Backend** (5 task):
- **Legend Workflow optimistic concurrency**: `UserLegendWorkflow.RevisionID
  uint64` + `BeforeUpdate` hook + `LegendRevisionMismatchError{Current
  *LegendWorkflowDTO}` + handler-level `If-Match` parse → 409 + full body.
  Mission/Agent pattern'i bire bir reuse — yeni framework yaratılmadı.
  `recordToDTO` helper extract'i empty `[]` normalisation için. Backward
  compat: header opsiyonel → eski client'lar last-write-wins almaya devam.
- **AgentUseLog cooldown**: yeni `AgentUseLog{AgentID, Wallet, IPHash,
  CreatedAt}` modeli + `services/agent/use_log.go` (60s wallet+IP
  cooldown, fail-open, SHA-256 IP hash). `IncrementUseCount(agentID,
  wallet, ipHash)` signature genişletildi; trusted internal caller'lar
  empty parametrelerle bypass eder.
- **save_count event-driven invalidation**: `AddToLibrary` artık
  `agents|*` + `trending` cache bust ediyor; `RemoveFromLibrary` symmetric
  hale getirildi (önceden save_count azaltmıyordu). Dialect-agnostic
  `CASE WHEN` clamp at 0 (sqlite tests + postgres prod uyumu).
- **Profile PATCH cache invalidation**: `UpdateProfile` username/bio
  güncellemesi sonrası creator name içeren cache anahtarlarını bust eder.
- **Username collision policy**: yeni `services/agent/username.go` —
  reserve list (admin/api/store/guild/legend/system + 25 kelime),
  `ErrUsernameTaken/Reserved/Format`, `SuggestAlternativeUsernames`.
  Handler 409 + suggestions, 422 reserved/format, 400 diğer.

**Frontend** (6 task — biri zaten mevcut):
- **Legend conflict-aware sync**: `LegendWorkflow.revisionId` field +
  `withRevisionId(int)` helper. `ApiService.saveLegendWorkflow`
  `If-Match` header gönderir, 409'da `ConflictException` fırlatır
  (mevcut `conflict_resolver.dart` reuse). `LegendService.saveWorkflow`
  ConflictException'ı catch'lemeden controller'a propagate eder.
- **Tx state machine UI**: yeni `tx_state.dart` (pure-Dart enum +
  TxStateX extension — 6 state, label/color/icon) + `purchase_button.dart`
  (PurchaseStatusButton + Monad explorer deep-link). `AgentDetailController`
  `txState/txHash/txFailureReason` Rx'leri + `purchaseAgentFlow` end-to-end
  driver. Pattern: enum extract `mention_filter.dart`/v3.6 pattern'iyle
  aynı — `package:web` import'u testleri kırmıyor.
- **Network guard banner**: ZATEN MEVCUT (`router.dart` `_NetworkBanner` +
  `NetworkGuard` GetxController + `network_guard_pure.dart`). Yeni kod
  yazılmadı.
- **Nonce reuse koruması**: yeni `ApiService.abandonSignature(wallet)` →
  `POST /auth/abandon` (backend zaten implement edilmiş). `AuthController`
  imza reject veya verify fail path'lerinde explicit invalidate çağırıyor.
- **Create Agent draft persistence**: 5s autosave timer + SharedPreferences
  (`create_agent_draft_v1`), publish'te clear, post-frame "Continue draft?"
  dialog. dispose'da pending flush.
- **Rating moderation UI**: `AgentRating.Helpful int64` + yeni
  `RatingHelpfulVote` modeli (composite unique index dedup). Atomic
  `MarkRatingHelpful` (`FOR UPDATE` lock + INSERT vote + counter bump),
  self-helpful 403. UI: comment TextField + per-rating thumbs-up
  (optimistic update, server count reconcile).

**Test/CI**:
- Backend: `services/agent/{username_test.go (10), use_log_test.go (7)}`,
  `services/workspace/legend_service_test.go (12)` — toplam 29 yeni unit.
  testutil yeni model'leri (UserLegendWorkflow, AgentUseLog,
  RatingHelpfulVote) AutoMigrate ediyor. Mevcut testler ile birlikte
  agent + auth + aipipeline + workspace tüm package'lar yeşil.
- Frontend: `test/unit/tx_state_test.dart` (8 test) — TxStateX state
  machine matrix. Mevcut 75 test + yeni 8 = **83 test, hepsi yeşil**.
  `flutter analyze` 0 issue.

**Yeni dosyalar**:
- `backend/services/agent/{use_log.go, username.go, username_test.go,
  use_log_test.go}`
- `backend/services/workspace/legend_service_test.go`
- `agent_store/lib/features/agent_detail/widgets/{tx_state.dart,
  purchase_button.dart}`
- `agent_store/test/unit/tx_state_test.dart`

**Genişletilen modeller**: `Agent.RevisionID` (zaten vardı), `UserLegendWorkflow.RevisionID`,
`AgentRating.Helpful`, yeni: `AgentUseLog`, `RatingHelpfulVote`.

**Yeni endpoint'ler**: `POST /auth/abandon` (backend zaten vardı, FE bağlandı),
`POST /agents/:id/ratings/:ratingID/helpful`. Legend save artık If-Match destekler.

**Karar**: Mission/Agent revision pattern'i Legend'e port edildi —
yeni framework yaratmak yerine 1:1 reuse (`If-Match` parse + error
type + `recordToDTO` helper). `_NetworkBanner` zaten v3.7-8.x
sprint'inde implement edilmişti, gereksiz yere yeniden yazmadık —
backlog'daki "eksiklikler" listesinin %15'i bu tür already-built
maddelerdi (Store URL persist, Library URL persist, Card Editor
revision-hash, Settings sectioning, Library custom collections,
achievement rozetleri).

**Sonraki sprintler** (`.claude/plans/c-projeler-agent-store-web-claude-tasks-deep-tower.md`):
v3.8 Explainability + Action Bridge → v3.9 Discovery + Engagement →
v3.10 Pro Tools → v3.11 Polish + Cross-Cutting.

## v3.2 UX Overhaul + DB Persistence Fix (2026-03-22)
6 feature, 24 task:
- **CRITICAL BUG FIX**: docker-compose gateway depends_on missing workspacesvc (502 Bad Gateway root cause)
- **Shared Widget Library**: PageHeader, EmptyState, ErrorState, ConfirmDialog — reused across 8+ screens
- **Mission/Legend DB Persistence**: Exponential backoff retry (3 attempts), SyncStatus enum + ValueNotifier, forceSyncToBackend(), 5-min periodic sync timer, sync status banner UI
- **Store Dual Sidebar**: Left category sidebar (200px) + right filter/trending sidebar (260px) for >1024px desktop, 3-column layout with LayoutBuilder breakpoints
- **Legend UX**: Toolbar sync indicator, keyboard shortcuts (Ctrl+S save, Escape deselect, Ctrl+/ help), unsaved changes warning (PopScope), 4-step onboarding overlay
- **Screen Polish**: Missions PageHeader + sync banner + ConfirmDialog, Library ConfirmDialog, Settings/CreditHistory/PublicProfile/CreatorDashboard/AgentDetail improvements
- **Cross-Cutting**: AppAnimations class (standardized hover durations), animation consistency across cards
- **Yeni dosyalar**: page_header.dart, empty_state.dart, error_state.dart, confirm_dialog.dart, animations.dart, category_sidebar.dart, filter_sidebar.dart, legend_onboarding.dart

## v3.1 UX Sprint Detaylari (2026-03-22)
4 feature, 13 task tamamlandi:
- **Guild Emoji Migration**: roleIcon emoji (Unicode) → Material Icons (IconData + Color getters), member role icons → Icons.psychology/shield/bolt/lightbulb/gps_fixed
- **Keyboard Navigation**: Sidebar FocusTraversalGroup + FocusableActionDetector, Store grid FocusableActionDetector, Alt+Backspace browser back, `/` search focus, Escape dismiss, Enter activate
- **Mission Redesign**: Page header icon, search bar, category filter chips, stat row, card-based layout, hover effects, skeleton loading, edit/duplicate/delete CRUD, empty state
- **UX Consistency**: Hover effects on all screens (store, guild, mission, leaderboard), all text English, Store dual sidebar preserved
- **Yeni**: AppShellState.searchFocusNode (cross-widget search focus), _GoBackIntent (Alt+Backspace)

## v3.0 Legend Sprint Detaylari (2026-03-22)
3 feature, 16 task tamamlandi:
- **Touch & Touchpad**: onPan→onScale, pinch-zoom, two-finger pan, adaptive port sizes (44px touch), trackpad 0.01 step zoom, mobile layout (<768px drawer + floating FABs)
- **Claude Export**: ClaudeExportService (8 format: team config, agent .md, CLAUDE.md, .cursorrules, JSON, clipboard, context, CLI package), DAG topological sort, import parser (team config + agent .md + context)
- **Live Claude Execution**: backend/pkg/claude/client.go, dual-engine (Gemini/Claude), per-node model selection (haiku=1cr, sonnet=3cr, opus=10cr), execution context feeding
- **Yeni dosyalar**: input_mode.dart, dag_utils.dart, claude_export_service.dart, legend_export_dialog.dart, backend/pkg/claude/client.go
- **Karar**: JSZip yerine combined JSON (dependency-free), WorkflowNode metadata nullable (backward compat)

## v3.3 Legend v3.5 (2026-04-02)
4 feature, tüm Flutter frontend:
- **Undo/Redo**: `_CanvasSnapshot` history stack (max 50), `_pushHistory()` tüm canvas mutation'larında, toolbar Undo/Redo butonları (disabled state ile), Ctrl+Z/Ctrl+Y kısayolları
- **Workflow Templates**: `legend_templates.dart` (6 şablon: Blank, Multi-Agent Pipeline, Research+Summarize, Code Review Chain, Mission-Led, Guild Collaboration), `legend_templates_dialog.dart` hover kartlı modal, toolbar Templates butonu, ID remapping ile çakışma önleme
- **Clone/Duplicate + Delete Confirm**: `_duplicateWorkflow()` tam node ID remapping ile, Load dialog'a Duplicate ikonu, silme işlemi için onay AlertDialog
- **Execution History UI**: Her çalışma satırı genişletilebilir (expandable node detayları), süre etiketi (Xs/Xm), tamamlanan çalışmalar için Rerun butonu, `onRerun` callback
- **Yeni dosyalar**: `legend_templates.dart`, `legend_templates_dialog.dart`
- **`_ToolbarButton`**: `disabled` parametresi eklendi (gri renk + onTap=null)

## v3.5 Polish (2026-04-27)
- **Legend overflow fixes**: toolbar workflow name `Flexible` + `ellipsis`; toolbar's 12+ button right-cluster wrapped in `SingleChildScrollView(scrollDirection: horizontal, reverse: true)` so narrow viewports scroll instead of overflowing; onboarding step `Text` `maxLines`/`overflow`; execution-history node label `ellipsis`.
- **GuildMaster @-mention sectioning**: backend `/user/library` endpoint never set `owned: true` on agent JSON, so frontend always rendered everything as "Store". Fix: `GuildMasterController.ensureLibraryLoaded` now tags library entries via `copyWith(owned: true)` before merging. Composer split into separate `lib.take(6)` + `store.take(8)` (was single `take(8)`) so store hits never crowd library out.

## v3.6 Quality Foundation (2026-04-27, partial)
83 tests + CI gate; mobile pass + bug bash deferred.
- **Backend test infra**: `pkg/database/db.go` now exposes `ConnectWithDialector` + `SetForTest`; production code path unchanged. New `internal/testutil/` package with sqlite in-memory DB (pure-Go via `github.com/glebarez/sqlite` — no CGO), agent/user/wallet factories, ECDSA signing helper.
- **Backend tests**: `services/auth/service_test.go` (12 tests, real ECDSA round-trip; 87-100% on covered functions), `services/agent/service_test.go` (28 tests covering ListAgents filter/pagination/sort/cache, GetAgent, AddToLibrary idempotency + save_count, RemoveFromLibrary, GetLibrary isolation, IsPurchased, UpdateAgent owner check + whitelist + traits/profile JSON merge, BatchGetAgents prompt redaction, GetCategories, GetTrending, IncrementUseCount).
- **Flutter test infra**: `mocktail` + `fake_async` added. New `test/unit/` and `test/widget/` directories. Default counter test removed.
- **Flutter tests**: `test/unit/card_editor_controller_test.dart` (18 tests — history, undo/redo, dirty tracking, reDetectFromPrompt, history limit), `test/unit/mention_filter_test.dart` (15 tests — section split, library-first ordering, `kMentionLibraryLimit=6` + `kMentionStoreLimit=8` caps, case-insensitive filter), `test/unit/legend_service_test.dart` (10 tests — `newWorkflow`, singleton stability, `workflows` immutability, SyncStatus contract).
- **Mention composer refactor**: extracted `filterAgentSuggestions` into standalone `lib/features/guild_master/widgets/mention_filter.dart` so tests don't pull `MonacoEditorWidget` (`dart:js_interop` blocks `flutter test` on non-web).
- **CI**: new `.github/workflows/ci.yml` — `backend-test` (go vet + race-enabled test + coverage artifact upload) and `frontend-test` (flutter analyze + flutter test) jobs run on PR + main push. Existing `deploy.yml` untouched.
- **Shared infra**: `lib/shared/widgets/responsive_layout.dart` — `ResponsiveLayout(mobile, tablet?, desktop)` LayoutBuilder helper using existing `AppBreakpoints`. `isNarrow(BuildContext)` helper for the AppShell-aligned 768px split.

## v3.4 Card Editor (2026-04-26)
Split-view canlı kart editörü — vintage koyu tema:
- **Backend genişletme**: `PUT /api/v1/agents/:id` whitelist'i artık prompt, category, subclass, price, card_version, service_description, profile_mood/role_purpose, traits, stats kabul ediyor. character_data JSON merge ile stats/traits/profile içeriği güvenle güncelleniyor; owner check değişmedi. (`backend/services/agent/{handler,service}.go`)
- **CardEditorController**: `_original` + `draft` AgentModel, debounced save (600ms), undo/redo history stack (max 50, v3.3 Legend pattern'i), SyncStatus enum (idle/dirty/saving/saved/error), exponential backoff retry, `reDetectFromPrompt()` keyword scoring re-run.
- **Split-view ekran**: sol form panel (6 accordion section: Identity, Prompt, Taxonomy, Stats, Narrative, Visuals) + sağ canlı `AgentCard` preview (`RepaintBoundary` + S/M/L boyut toggle). Mobile fallback stacked layout.
- **Reusable field widget'ları**: EditTextField, EditLongText, EditTagChips, EditStatSlider, EditSubclassPicker — hepsi controller'a `updateField()` callback'iyle bağlı.
- **Type/rarity politikası**: manuel override YOK; "Re-detect from prompt" butonu mevcut keyword scoring'i tekrar çalıştırır → yeni type seçilirse subclass otomatik resetlenir.
- **Toolbar**: SyncStatusBadge (renkli pill), Undo/Redo butonları (disabled state'li), Save (Ctrl+S), Clone (`/agents/:id/fork` zincirleme + yeni ID'ye redirect), Export ▼ menü (JSON pretty + PNG 3× DPR), Close. Ctrl+Z/Y/S/Esc kısayolları + PopScope unsaved-changes onayı (v3.2 ConfirmDialog).
- **Giriş noktaları (3)**: Agent Detail title row'da Edit Card butonu (sadece `isOwnAgent`), Library kartı hover'da gold edit pencil (sadece creator), Creator Dashboard'da yeni "Manage Card" aksiyonu (mevcut quick edit dialog'un yanına).
- **Export**: `dart:js_interop` + `package:web` ile Blob+AnchorElement download; JSON `toJson()` (character_data nested), PNG `RepaintBoundary.toImage(pixelRatio: 3.0)`.
- **Yeni rota**: `/agent/:id/edit` → `CardEditorScreen`, binding GetX `Get.put` tag-scoped.
- **Yeni dosyalar**: `lib/features/card_editor/{controllers/card_editor_controller.dart, bindings/card_editor_binding.dart, screens/card_editor_screen.dart, services/card_export_service.dart, widgets/{editor_preview_panel.dart, editor_toolbar.dart, sections/editor_sections.dart, fields/editor_fields.dart}}` + `agent_model.dart`'a `toJson()`/`toUpdatePayload()`.

## Sprint Takip Dosyalari
- `SPRINT_V2.md` — Detayli plan ve teknik kararlar
- `SPRINT_V2_TRACKER.md` — Task bazli ilerleme takibi (Team Leader gunceller)
- `.claude/tasks/agent-store/LEGEND_V3_PLAN.md` — Legend v3.0 sprint plani
- `.claude/tasks/agent-store/ux_sprint.md` — v3.2 UX Overhaul sprint plani
