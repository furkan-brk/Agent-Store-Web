# Modules — Agent Store

> Uygulamadaki tüm modüllerin (frontend feature'lar, backend servisler, paylaşımlı
> katmanlar, akıllı kontrat'lar) yüksek seviyeli haritası. Detaylı feature
> davranışları için `FEATURES.md`, mimari karar için `ARCHITECTURE.md`, sprint
> kayıtları için `SPRINT_HISTORY.md`.

İçindekiler:
1. [Frontend Feature Modülleri](#1-frontend-feature-modülleri)
2. [Frontend Paylaşımlı Modüller](#2-frontend-paylaşımlı-modüller)
3. [Frontend Controller Modülleri](#3-frontend-controller-modülleri)
4. [Backend Servis Modülleri](#4-backend-servis-modülleri)
5. [Backend Paylaşımlı Paketler](#5-backend-paylaşımlı-paketler)
6. [Veritabanı Modülleri (Modeller)](#6-veritabanı-modülleri-modeller)
7. [Blockchain Modülleri](#7-blockchain-modülleri)
8. [DevOps & Deploy Modülleri](#8-devops--deploy-modülleri)

---

## 1. Frontend Feature Modülleri

`agent_store/lib/features/` altında her klasör tek bir kullanıcı yüzeyi (ekran +
widget'lar + lokal data) sağlar. Tüm rotalar `app/router.dart`'ta toplanır.

| Modül            | Klasör                                | Sorumluluk                                                                           | Rotalar                                  |
| ---------------- | ------------------------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------- |
| **Store**        | `features/store/`                     | Agent keşfi: arama, kategori, trend şeridi, filtre paneli, kart grid                | `/`                                      |
| **Agent Detail** | `features/agent_detail/`              | Tek agent görünümü: prompt redaction, mini chat, radar chart, rating, satın al, fork, similar agents | `/agent/:id`                             |
| **Card Editor**  | `features/card_editor/`               | Sahibi olduğun agent'ın split-view editörü (6 accordion bölüm + canlı önizleme)     | `/agent/:id/edit`                        |
| **Library**      | `features/library/`                   | Kaydedilen + satın alınan agent'lar; bulk select, koleksiyon, achievement rozetleri | `/library`                               |
| **Create Agent** | `features/create_agent/`              | 3 adımlı agent yaratma sihirbazı (Basic Info → Prompt → Review)                    | `/create`                                |
| **Wallet**       | `features/wallet/`                    | MetaMask bağlama, Monad zinciri kontrolü, kredi geçmişi                            | `/wallet`, `/credits/history`            |
| **Guild**        | `features/guild/`                     | Guild listesi, oluşturma, detay, üye/davet/permission yönetimi                     | `/guild`, `/guild/create`, `/guild/:id`  |
| **Guild Master** | `features/guild_master/`              | AI takım kurma chat'i, @mention composer, suggest panel, oturum yönetimi            | `/guild-master`                          |
| **Missions**     | `features/missions/`                  | Mission CRUD, expand, marketplace import, schedule, runs                           | `/missions`, `/missions/marketplace`     |
| **Legend**       | `features/legend/`                    | Görsel workflow (DAG) editörü, exec, observability, template, version diff         | `/legend`, `/legend/observability/:id`   |
| **Leaderboard**  | `features/leaderboard/`               | 3 tab (creators / uses / rating) + kategori, "me", weekly rewards                  | `/leaderboard`                           |
| **Creator**      | `features/creator/`                   | Yaratıcı dashboard'u: kendi agent'ları, insights, bulk actions                     | `/creator`                               |
| **Insights**     | `features/insights/`                  | Funnel KPI panel (Discovery, GM, Trial→Purchase, Edit→Publish)                     | `/admin/kpi`                             |
| **Settings**     | `features/settings/`                  | Profile + Notifications + Appearance + Developer (API keys) hub                    | `/settings`, `/settings/{notifications,appearance,developer}` |
| **Profile**      | `features/profile/`                   | Public profil görünümü (kendin + başkası): agents grid, achievements, follow      | `/profile/:wallet`                       |
| **Character**    | `features/character/`                 | `CharacterType` × `Rarity` enum'ları + 24 alt sınıf + renk paleti                | (rendering only)                         |
| **Explore**      | `features/explore/`                   | (Reserved — currently no active screen)                                            | —                                        |

### Frontend Feature İç Yapısı (kanonik şablon)

```
features/<name>/
  screens/      # Sayfa (StatefulWidget shell, controller bind)
  widgets/      # Kompozisyon parçaları (composer, panel, chip)
  data/         # Sabit listeler (template, kategori, demo data)
  services/     # Sayfaya özgü domain servisleri (LegendService gibi)
  bindings/     # GetX binding'leri (lifecycle scope)
  controllers/  # Sayfaya özgü reaktif controller (genelde lib/controllers/'a yükselir)
  models/       # Sayfaya özgü model (Legend WorkflowNode gibi)
  utils/        # Sayfaya özgü saf yardımcılar (dag_utils, mention_filter)
```

---

## 2. Frontend Paylaşımlı Modüller

`agent_store/lib/shared/` — tüm feature'ların reuse ettiği primitiveler. Yeni
kod yazarken bu listedekiler **yeniden yazılmaz**.

### 2.1 Shared Widgets (`shared/widgets/`)

| Widget                    | Görev                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------ |
| `PageHeader`              | Sayfa başlığı + ikon + alt başlık standardı                                          |
| `EmptyState`              | "Henüz veri yok" görseli + CTA                                                       |
| `ErrorState`              | Hata + retry butonu                                                                  |
| `ConfirmDialog`           | Tek kapı yıkıcı eylem onayı (delete, sign out, fork)                                 |
| `ResponsiveLayout`        | `AppBreakpoints.isMobile` kontrolü + 768px narrow split                              |
| `AppAnimations`           | Hover süre sabitleri + page transition wrapper                                       |
| `WalletGuard`             | Action başlamadan cüzdan bağlantısını snackbar/dialog ile zorlar                    |
| `OnboardingModal`         | İlk açılışta 3 sayfalık tanıtım                                                      |
| `NotificationBell` + `NotificationPanel` | Sidebar/AppBar bildirim widget'ları + dropdown                            |
| `SkeletonWidgets`         | Yükleme placeholder'ları (kart, satır, grid)                                         |
| `ConflictDialog`          | 409 If-Match çakışmasında kullanıcının kararını alır (overwrite/discard/merge)       |
| `AchievementBadge`        | Achievement rozet rozeti (rarity glow + tooltip)                                     |
| `PixelCharacterWidget`    | CustomPainter pixel-art karakter (glow + float anim)                                 |
| `MonacoEditorWidget`      | Web view tabanlı kod/prompt editor                                                   |

### 2.2 Shared Services (`shared/services/`)

| Servis                  | Görev                                                                              |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `ApiService`            | Tüm REST çağrılarının tek giriş noktası (Dio + JWT header)                         |
| `WalletService`         | MetaMask köprüsü: `eth_requestAccounts`, `personal_sign`, `wallet_switchEthereumChain` |
| `WalletErrors`          | Web3 error → kullanıcı dostu mesaj eşlemesi                                        |
| `MissionService`        | Mission CRUD + SyncStatus + offline queue                                          |
| `CollectionService`     | Library tab koleksiyonları                                                         |
| `NotificationService`   | Inbox + tercih + okundu işaretleme                                                 |
| `NetworkGuard`          | Monad chainId değişimi izle, yanlış zincirde banner göster                        |
| `ConflictResolver`      | 409 If-Match çakışmalarını dialog ile çözer                                       |
| `AppTelemetryService`   | Route + action telemetry pings                                                     |
| `LocalKvStore`          | Web localStorage / mobile prefs cross-platform anahtar-değer                      |

### 2.3 Shared State (`shared/state/`)

| Module             | Görev                                                          |
| ------------------ | -------------------------------------------------------------- |
| `BulkSelectState`  | Library + Creator dashboard çoklu seçim modeli                 |
| `QueryState`       | Generic loading / error / data / empty state container         |

### 2.4 Shared Models (`shared/models/`)

`AgentModel`, `MissionModel`, `GuildModel` — JSON serialize/deserialize + minimal
view-helper getter'lar.

### 2.5 Core (`lib/core/`)

| Modül                   | Görev                                                       |
| ----------------------- | ----------------------------------------------------------- |
| `constants/api_constants.dart` | Backend URL'leri (env'e göre prod/dev)               |
| `utils/input_mode.dart` | Touch / Mouse / Touchpad ayrımı (Legend pan/zoom için)     |

---

## 3. Frontend Controller Modülleri

`agent_store/lib/controllers/` — uzun ömürlü GetX controller'ları. Her sayfa
genelde 1 controller'a sahiptir; permanent olarak register edilirler.

| Controller                  | İçerik                                                                |
| --------------------------- | --------------------------------------------------------------------- |
| `AuthController`            | Wallet bağlama, JWT, kredi balance, username, network state           |
| `StoreController`           | Store grid: query, kategori, sort, debounce, pagination               |
| `LibraryController`         | Saved/Purchased tab, search, sort, filter, URL round-trip             |
| `AgentDetailController`     | Tek agent state, library toggle, fork, rate, chat, purchase          |
| `CreateAgentController`     | 3 adımlı wizard, draft persist, AI analyze stage progress             |
| `CreatorController`         | Kendi agent'ları + creator insights + bulk operations                 |
| `GuildController`           | Guild listesi + membership + compatibility                            |
| `GuildDetailController`     | Detay sayfası, üye/davet/permission                                   |
| `GuildMasterController`     | Chat session, mention parsing, suggest, team build, bridge actions    |
| `LeaderboardController`     | 3 tab (creators/uses/rating) + period filter                          |
| `LocaleController`          | TR/EN dil değiştirme                                                  |
| `ThemeController`           | Dark/Parchment tema değiştirme                                        |
| `SettingsController`        | Notification prefs, API keys, network                                 |
| `StartupPreloadController`  | Açılışta paralel preload (categories, library, credits, prefs)        |

---

## 4. Backend Servis Modülleri

`backend/services/<svc>/` — her servis ayrı paket. **Monolith mode**'da hepsi
tek `cmd/monolith/main.go` binary'sinde in-process çalışır; **microservices
mode**'da ayrı container'larda + gateway proxy ile.

### 4.1 `services/auth` — Authentication Service (port `:8081`)

- **Sorumluluk**: Cüzdan tabanlı kimlik doğrulama (nonce + ECDSA + JWT).
- **Anahtar dosyalar**: `service.go` (NonceFor, VerifySignature, IssueJWT),
  `handler.go` (HTTP), `router.go`, `migrate.go`.
- **Endpoint prefix**: `/api/v1/auth/*`
- **Bağımlılıklar**: `pkg/database` (User), `pkg/middleware` (rate limit).

### 4.2 `services/agent` — Agent Service (port `:8082`)

- **Sorumluluk**: Agent CRUD, library, kredi, rating, social (follow), use-log,
  fork, chat, trial, purchase, achievements, leaderboard, notification,
  API keys, version history, bulk actions, funnel KPI.
- **Anahtar dosyalar**:
  - `service.go` — temel CRUD + library + kredi
  - `handler.go` + `router.go` — HTTP yüzey
  - `social.go` — follow/unfollow + activity feed
  - `analytics.go` — store/agent telemetry
  - `discovery_funnel.go` — search→save / impression→open / open→save funnel
  - `funnel.go` — cross-cutting KPI funnel
  - `use_log.go` — agent kullanım kaydı
  - `versioning.go` — agent version history + rollback
  - `notification.go` + `notification_hooks.go` — `notifyOnce` helper
  - `api_keys.go` — `pat_*` token'lar + scope dual-auth
  - `rating_moderation.go` — flag + helpful vote
  - `achievements.go` — first_agent / first_sale / first_fork / 100_saves / top_creator
  - `leaderboard_extras.go` — kategori + rank + weekly reward
  - `bulk_actions.go` — `/agents/bulk` (remove from library, add tag, regen image)
  - `skill_export.go` — `/agents/:id/skill.md` (OpenClaw deeplink hedefi)
  - `regenerate_pipeline.go` — analyze/profile/avatar yeniden çalıştır (timeout+retry)
  - `username.go` — username uniqueness + reservation
  - `search_rank.go` — text relevance scorer
- **Internal endpoint'ler**: `/internal/agents/:id`, `/internal/credits/deduct`,
  `/internal/credits/:wallet`, `/internal/agents/:id/increment-use`.

### 4.3 `services/aipipeline` — AI Pipeline Service (port `:8083`, stateless)

- **Sorumluluk**: AI çağrılarının orkestrasyonu. **Tüm endpoint'ler `/internal/`** —
  frontend'e açık değil; agent service tüketir.
- **Anahtar dosyalar**:
  - `service.go` — pipeline orkestrasyonu
  - `claude.go` — Claude API client
  - `gemini.go` — Gemini Flash client
  - `character.go` — prompt → CharacterType + Rarity skorlayıcı
  - `score.go` — kalite skorlaması
  - `rembg.go` — Replicate background removal
  - `run_stages.go` — analyze → profile → avatar zinciri (timeout + retry)
  - `router.go` — `/internal/{analyze,profile,score,avatar,chat,compatibility,character}`

### 4.4 `services/guild` — Guild & GuildMaster Service (port `:8084`)

- **Sorumluluk**: Guild CRUD, davet/join/leave, üye permission'ları, GuildMaster
  AI suggest+chat, oturumlar, bridge (mission/legend draft), KPI, reflection.
- **Anahtar dosyalar**:
  - `service.go` — Guild CRUD + member ops
  - `guildmaster.go` — Suggest + TeamChat (Claude calls)
  - `sessions.go` — chat oturumu + mesaj append
  - `bridge.go` — session → mission/legend draft
  - `invite.go` — token tabanlı davet
  - `events.go` — member event log (audit)
  - `kpi.go` — Suggest→Execute, Chat→Action, Rerun rate
  - `reflection.go` — post-execution refleksiyon notu
  - `router.go`

### 4.5 `services/workspace` — Workspace Service (port `:8085`)

- **Sorumluluk**: Mission CRUD + Legend workflow CRUD/execute/resume + template
  metrics + scheduler (cron mission re-runs).
- **Anahtar dosyalar**:
  - `mission_service.go` — CRUD + sync + expand + marketplace
  - `legend_service.go` — workflow CRUD + execute (DAG topological run) + resume
  - `scheduler.go` — cron mission scheduler
  - `template_metrics.go` — usage + execution success oranı
  - `handler.go` + `router.go`

### 4.6 `services/gateway` — API Gateway (HTTP port)

- **Sorumluluk**: Public API girişi. JWT'yi `Authorization` header'dan parse
  edip `X-Wallet-Address` internal header'ına dönüştürür, alt servislere
  reverse-proxy yapar.
- **Anahtar dosyalar**:
  - `proxy.go` — URL prefix → target service map
  - `jwt.go` — JWT validate
  - `health.go` — `/health`

> **Not**: Internal endpoint'ler (`/internal/*`) gateway'de proxy'lenmez —
> sadece servisler arası in-cluster çağrı için.

---

## 5. Backend Paylaşımlı Paketler

### 5.1 `pkg/config` — `config.go`
- Env değişkenleri (DATABASE_URL, CLAUDE_API_KEY, GEMINI_API_KEY, REPLICATE_API_TOKEN, JWT_SECRET, ADMIN_API_TOKEN).
- `svcDefault()` — Railway `.railway.internal` vs docker-compose `*svc` resolver.

### 5.2 `pkg/database` — `db.go`
- GORM connect (Postgres prod, sqlite test).
- `IsReady()` — readiness flag (middleware kullanıyor).
- `SetForTest(db)` — test override.

### 5.3 `pkg/middleware`
| Dosya                   | Görev                                                  |
| ----------------------- | ------------------------------------------------------ |
| `cors.go`               | CORS allow-list                                        |
| `db_readiness.go`       | DB hazır değilse 503                                   |
| `ratelimit.go`          | Per-wallet + per-IP rate limit (token bucket)          |
| `internal_auth.go`      | Gateway'den gelen `X-Wallet-Address` zorunlu          |
| `optional_auth.go`      | Header varsa auth, yoksa anonim                        |
| `api_key_auth.go`       | `pat_*` token validation + scope check                 |
| `auth_or_apikey.go`     | JWT VEYA API key (JWT öncelikli)                       |
| `strip_wallet_header.go`| Inbound `X-Wallet` header'ı sıyır (gateway dışı sızıntı önle) |

### 5.4 `pkg/cache` — `cache.go`
- In-process key→value cache, TTL + `DeletePrefix("agents|")` pattern.

### 5.5 `pkg/claude` — `client.go`
- Düşük seviyeli Claude API HTTP client.

### 5.6 `pkg/httputil` — `client.go`
- Servisler arası HTTP çağrı için ortak client (timeout, retry).

### 5.7 `pkg/gamification` — `synergy.go`
- Guild içi karakter kombinasyonlarının synergy bonusunu hesaplar.

### 5.8 `internal/testutil`
| Dosya          | Görev                                                                    |
| -------------- | ------------------------------------------------------------------------ |
| `db.go`        | `NewTestDB(t)` — sqlite in-memory + tüm modelleri AutoMigrate (CGO yok) |
| `auth.go`      | Test fixture user + JWT helper                                           |
| `factories.go` | Agent, mission, guild factory'leri                                       |

> **Zorunlu kural**: Yeni model eklediğinde `internal/testutil/db.go`
> AutoMigrate listesine de ekle, aksi halde testler patlar.

---

## 6. Veritabanı Modülleri (Modeller)

`pkg/models/` — tüm GORM model'ları. Aynı paket altında — servisler arası
shared.

### Çekirdek
- `User` — wallet (PK), nonce, credits, username, created_at
- `Agent` — id, title, description, prompt, category, creator_wallet, character_type, character_data (JSON), rarity, tags, revision_id, save_count, generated_image, ...
- `LibraryEntry` — user_wallet, agent_id, saved_at
- `PurchasedAgent` — purchase ledger

### Sosyal
- `UserFollow`, `UserActivity`

### Mission / Legend
- `UserMission` (`workspace.go` içinde), `UserLegendWorkflow`, `WorkflowExecution` (NodeStates JSON), `LegendWorkflowVersion`, `LegendTemplateUsage`

### Agent advanced
- `AgentVersion` (history), `AgentUseLog`, `AgentRating` (Hidden + Helpful), `RatingFlag`, `RatingHelpfulVote`

### Guild
- `Guild`, `GuildMember`, `GuildMasterSession`, `GuildMemberEvent`, `GuildInvite`, `GuildMasterReflection`

### Achievement / Reward
- `Achievement`, `WeeklyLeaderReward`

### Notification / Auth / Credits
- `NotificationPref`, `NotificationEvent`, `APIKey`, `CreditTransaction`, `CreditLedger`

---

## 7. Blockchain Modülleri

`contracts/` — Hardhat projesi.

| Dosya                             | Açıklama                                                       |
| --------------------------------- | -------------------------------------------------------------- |
| `contracts/AgentStoreCredits.sol` | ERC-20 benzeri on-chain kredi (mint, burn, transfer)           |
| `contracts/AgentRegistry.sol`     | Agent sahipliği + içerik hash kaydı                            |
| `scripts/deploy.js`               | Monad testnet deploy + `deployments.json` yazımı              |
| `hardhat.config.js`               | Monad testnet RPC (`https://testnet-rpc.monad.xyz`, chainId `10143`) + localhost |

**Auth akışı**: `eth_requestAccounts` → `personal_sign(nonce)` → backend
`/auth/verify` → JWT.

---

## 8. DevOps & Deploy Modülleri

| Dosya                          | Görev                                                   |
| ------------------------------ | ------------------------------------------------------- |
| `docker-compose.yml`           | 9 container (postgres, gateway, authsvc, agentsvc, aipipelinesvc, guildsvc, workspacesvc, frontend, observability) |
| `Dockerfile`                   | Multi-stage Go build                                    |
| `agent_store/Dockerfile`       | Flutter Web build + nginx serve                         |
| `agent_store/nginx.conf`       | SPA fallback + static serve                             |
| `vercel.json`                  | Flutter Web Vercel config                               |
| `railway.toml`                 | Railway monolith deploy config                          |
| `.github/workflows/ci.yml`     | PR/main: `go vet`, race tests, `flutter analyze`, `flutter test` |
| `clean-build.sh`               | Lokal full rebuild script                              |

---

## Modül Bağımlılık Akışı (özet)

```
Browser (Flutter Web)
  ├── auth → MetaMask (eth_requestAccounts, personal_sign)
  └── HTTPS → Gateway (JWT validate, X-Wallet inject)
              ├── /auth/*      → authsvc
              ├── /agents/*    → agentsvc ─── /internal/* ──> aipipelinesvc
              │                       └── /internal/* ──> (no public)
              ├── /guilds/*, /guild-master/* → guildsvc ── /internal/* ──> agentsvc + aipipelinesvc
              ├── /missions/*, /legend/*      → workspacesvc ── /internal/* ──> agentsvc + aipipelinesvc
              └── (all)        ← PostgreSQL (shared models)

Monad Testnet (off-path)
  ├── AgentStoreCredits.sol ← chain explorer + on-chain credits
  └── AgentRegistry.sol     ← agent ownership claims
```

---

## Sonraki Adımlar

- Yeni feature eklerken **bu listeye reuse hedefi olarak bak**: shared widget,
  servis veya pattern var mı?
- Yeni servis ekleneceğinde monolith vs microservices ayrımına dikkat et
  (`cmd/monolith/main.go` ve gateway proxy).
- Yeni model eklendiğinde `internal/testutil/db.go` `AutoMigrate` listesi
  güncellenmeli (zorunlu).
