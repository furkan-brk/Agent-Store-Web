# Architecture

> Agent Store mimarisi — referans dosyası. Pattern detayları için `CLAUDE.md`
> "Established Patterns" bölümü. Sprint detayları için `docs/SPRINT_HISTORY.md`.

---

## Yığın

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

## Dizin Ağacı

```
Agent_Store_Full/
├── agent_store/          # Flutter Web frontend
│   ├── lib/
│   │   ├── app/          # Router, Theme
│   │   ├── features/     # store | agent_detail | library | create_agent | wallet
│   │   │                 # character | card_editor | guild_master | missions
│   │   │                 # legend | leaderboard | settings | insights | profile
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
│   ├── COMMANDS.md       # Dev komutları
│   ├── ARCHITECTURE.md   # ← bu dosya
│   └── SPRINT_HISTORY.md # Detayli sprint notları
├── docker-compose.yml
└── CLAUDE.md             # Top-level pointer + established patterns
```

---

## Backend Deployment Modes

- **Monolith** (`cmd/monolith`): All services run in-process. Used for Railway
  deploy and simple setups. Internal calls are direct function calls (no HTTP
  between services).
- **Microservices** (`cmd/gateway` + individual `*svc` binaries): Each service
  in its own container. Gateway proxies by URL prefix. Used in full
  docker-compose.
- **Internal endpoints** (`/internal/*`): Cross-service calls in microservices
  mode — not exposed publicly. Gateway does NOT proxy `/internal/` routes.
- **Inter-service URL resolution**: `pkg/config/config.go:svcDefault()` —
  Railway uses `.railway.internal` hostnames; docker-compose uses `*svc`
  container names.

---

## Core API Endpoints (örnek)

> Tüm endpoint listesi için `services/*/router.go` dosyaları + sprint notları.

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

- **Sosyal**: `UserFollow`, `UserActivity`
- **Mission/Legend**: `UserMission`, `UserLegendWorkflow`,
  `WorkflowExecution` (NodeStates), `LegendWorkflowVersion`,
  `LegendTemplateUsage`
- **Agent**: `AgentVersion`, `AgentUseLog`, `AgentRating` (Hidden+Helpful),
  `RatingFlag`, `RatingHelpfulVote`
- **Guild**: `GuildMasterSession`, `GuildMemberEvent`, `GuildInvite`,
  `GuildMasterReflection`
- **Achievement/Reward**: `Achievement`, `WeeklyLeaderReward`
- **Notification/Auth**: `NotificationPref`, `NotificationEvent`, `APIKey`

Her yeni model eklerken `internal/testutil/db.go` `AutoMigrate` güncellenmeli
(zorunlu — yoksa testler patlar).

---

## Karakter Sistemi (Gamification)

Prompt → Claude/Gemini analiz → character_type → Flutter `CustomPainter`
pixel-art (`lib/features/character/pixel_art_painter.dart`).

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

**Nadir dereceleri**: Common → Uncommon → Rare → Epic → Legendary

---

## Blockchain (Monad Testnet)

- **AgentStoreCredits.sol**: ERC-20 benzeri on-chain kredi
- **AgentRegistry.sol**: Agent sahipliği kaydı
- Giriş akışı: `eth_requestAccounts` → `personal_sign(nonce)` → backend
  doğrula → JWT
- RPC: `https://testnet-rpc.monad.xyz` · ChainID: `10143`

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
| `pkg/middleware/strip_wallet_header.go`| Inbound X-Wallet header guard (v3.12)      |
| `pkg/models/`                          | All GORM models (shared)                   |
| `services/auth/service.go`             | Nonce üret, ECDSA doğrula, JWT             |
| `services/agent/service.go`            | Agent CRUD, kütüphane, kredi               |
| `services/aipipeline/service.go`       | Gemini/Claude pipeline (stateless)         |
| `services/guild/guildmaster.go`        | GuildMaster AI suggest + chat              |
| `services/guild/bridge.go`             | Mission/Legend draft from GM session       |
| `services/workspace/legend_service.go` | Legend workflow save/execute/resume        |
| `internal/testutil/db.go`              | SQLite in-memory test DB (no CGO)          |

### Frontend (Flutter Web) — anchors

| Dosya                                                                                            | Açıklama                            |
| ------------------------------------------------------------------------------------------------ | ----------------------------------- |
| `lib/main.dart`                                                                                  | MaterialApp.router giriş            |
| `lib/app/theme.dart`                                                                             | Dark + light (parchment) variantlar |
| `lib/app/router.dart`                                                                            | GoRouter + AppShell                 |
| `lib/core/constants/api_constants.dart`                                                          | API URL sabitleri                   |
| `lib/features/character/character_types.dart`                                                    | CharacterType + Rarity enum         |
| `lib/features/character/pixel_art_painter.dart`                                                  | CustomPainter + glow + float        |
| `lib/shared/widgets/{page_header,empty_state,error_state,confirm_dialog,responsive_layout}.dart` | Shared UI primitives                |
| `lib/shared/widgets/animations.dart`                                                             | AppAnimations (hover durations)     |
| `lib/shared/services/api_service.dart`                                                           | HTTP istemcisi                      |
| `lib/shared/services/wallet_service.dart`                                                        | MetaMask köprüsü                    |
| `lib/shared/services/wallet_errors.dart`                                                         | Friendly wallet error map           |

### Blockchain (Solidity)

| Dosya                             | Açıklama                            |
| --------------------------------- | ----------------------------------- |
| `contracts/AgentStoreCredits.sol` | ERC-20 benzeri kredi sistemi        |
| `contracts/AgentRegistry.sol`     | Agent sahipliği + içerik hash kaydı |
| `hardhat.config.js`               | Monad testnet + localhost ağ konfig |
| `scripts/deploy.js`               | Deploy + deployments.json kaydı     |

---

## Team Agents

| Agent                    | Sorumluluk                                |
| ------------------------ | ----------------------------------------- |
| Team Leader (Claude ana) | Koordinasyon, entegrasyon, CLAUDE.md      |
| Backend                  | Go API, veritabanı, servisler             |
| Frontend                 | Flutter UI, routing, state                |
| Gamification Master      | Pixel-art karakterler, rarity sistemi     |
| Blockchain Expert        | Solidity kontrat, Web3 auth, Monad deploy |
