# Agent Store — CLAUDE.md
> Team Leader tarafından tutulur. Her sprint sonrası güncellenir.

## Proje Özeti
AI Agent prompt paylaşım platformu. Kullanıcılar agent promptlarını keşfeder, kütüphanesine ekler, kendi promptunu yükler. Her prompt analiz edilerek benzersiz pixel-art karakter üretilir. Giriş Monad testnet cüzdanı ile yapılır; kredi sistemi on-chain yönetilir.


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
│   ├── lib/c
│   │   ├── app/          # Router, Theme
│   │   ├── features/     # store | agent_detail | library | create_agent | wallet | character
│   │   ├── shared/       # models | services | widgets
│   │   └── core/         # constants | utils
│   ├── Dockerfile
│   └── nginx.conf
├── backend/              # Go REST API
│   ├── cmd/server/
│   ├── internal/
│   │   ├── api/          # handlers | middleware | router
│   │   ├── models/
│   │   ├── services/     # agent | auth | ai | character
│   │   ├── database/
│   │   └── config/
│   └── Dockerfile
├── contracts/            # Solidity (Hardhat)
│   ├── contracts/        # AgentStoreCredits.sol | AgentRegistry.sol
│   └── scripts/          # deploy.js
├── docker-compose.yml
└── CLAUDE.md             # ← bu dosya
```

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

### Backend (Go) — 14 dosya ✅
| Dosya                                    | Açıklama                                     |
| ---------------------------------------- | -------------------------------------------- |
| `cmd/server/main.go`                     | Giriş noktası, config + DB + router başlatır |
| `config/config.go`                       | Env değişkenlerinden yapılandırma yükler     |
| `internal/database/db.go`                | GORM bağlantısı + AutoMigrate                |
| `internal/models/user.go`                | User modeli (wallet_address PK, credits)     |
| `internal/models/agent.go`               | Agent + LibraryEntry modelleri               |
| `internal/services/auth_service.go`      | Nonce üret, imza doğrula, JWT                |
| `internal/services/agent_service.go`     | Agent CRUD, kütüphane, kredi                 |
| `internal/services/character_service.go` | Prompt analiz → karakter tipi + nadir derece |
| `internal/api/router.go`                 | Gin router + CORS kurulumu                   |
| `internal/api/handlers/auth_handler.go`  | GET /auth/nonce, POST /auth/verify           |
| `internal/api/handlers/agent_handler.go` | CRUD + library endpoints                     |
| `internal/api/middleware/auth.go`        | JWT doğrulama middleware                     |
| `Dockerfile`                             | Multi-stage Go build                         |

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
- [x] **v3.10 — Pro Tools** (Backend + Frontend) ✅ preflight, workflow versioning, mission marketplace, guild invite/permissions, compatibility explainability, creator analytics
- [x] **v3.9 — Discovery + Engagement** (Backend + Frontend) ✅ social follow, For You, leaderboard time windows, OG meta, activity feed
- [x] **v3.8 — Explainability + Action Bridge** (Backend + Frontend) ✅ 9 task
- [x] **v3.7 — Reliability Closure** (Backend + Frontend) ✅ 12 task
- [~] **v3.6 — Quality Foundation + Mobile Pass + Bug Bash** (in progress)
  - ✅ Quality: testutil package (sqlite-in-memory via glebarez/sqlite), `pkg/database/db.go` dialector swap, 40 backend tests (auth 12, agent 28), 43 Flutter tests (CardEditor 18, MentionFilter 15, LegendService 10), CI workflow (`.github/workflows/ci.yml`)
  - ✅ Shared `ResponsiveLayout` widget (`lib/shared/widgets/responsive_layout.dart`)
  - ⏳ Mobile Batch 1 (8 screens) — pending visual verification pass
  - ⏳ 2-day bug bash — pending

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
Split-view canlı kart editörü — lor-card-maker'dan UX ilhamı, tema vintage koyu (LoR görselleri YOK):
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

## OpenClaw Compatibility Sprint (2026-05-04)
Drop-in compatibility between Agent Store agents/workflows and OpenClaw workspace.
Round-trip: export → drop into `~/.openclaw/workspace/skills/` → re-import recovers prompt.

**Backend** (3 files):
- **`services/agent/skill_export.go`**: `SkillSlug()` (mirrors Flutter `_slugify` exactly —
  lowercase → strip non-alnum/space/dash → collapse spaces→dash → max 50 → trim trailing dash)
  + `BuildSkillMd()` (hand-rolled YAML frontmatter with `name/description/version/when_to_use/
  model/metadata.openclaw/agent_store` blocks + prompt body). No external YAML dep.
- **`services/agent/handler.go`**: `GetAgentSkillMd` — owner OR purchaser gate (403 else),
  `Content-Disposition: attachment` download as `<slug>-SKILL.md`.
- **`services/agent/router.go`**: `GET /api/v1/agents/:id/skill.md` (auth-gated).
- **`skill_export_test.go`**: 13 tests — slug edge cases, frontmatter completeness, prompt
  preservation, description truncation, empty tags, `---` inside prompt.

**Frontend** (7 files):
- **`claude_export_service.dart`**: `generateOpenclawSkill(AgentModel)` — mirrors Go BuildSkillMd;
  `isOpenclawSkill(String)` — detects by `metadata:\n  openclaw:` presence;
  `parseOpenclawSkill(String)` — line-scanner for flat + agent_store sub-block, strips `# Title`
  heading from body; `generateOpenclawWorkspace(wf, agents)` — virtual JSON file map with per-agent
  SKILL.md + team.json (same pattern as existing CLI package — no zip).
- **`legend_export_dialog.dart`**: New "OpenClaw Compatible" section after context row — "OpenClaw
  Skills" (SKILL.md per agent, preview first agent) + "OpenClaw Workspace" (bundle JSON).
- **`legend_screen.dart`**: Tab 4 "SKILL.md" in import dialog — `_tabLabels` + `_tabHints` +
  `_tabHints` extended; `_validate` case 4 via `isOpenclawSkill`; `_buildImportResult` case 4
  creates single-node workflow from parsed SKILL.md (same pattern as case 2 Agent .md).
- **`api_service.dart`**: `fetchAgentSkillMd(int id)` returns raw Markdown text (not JSON).
- **`agent_detail_screen.dart`**: `_downloadSkillMd()` + red extension icon button (owner +
  purchaser, uses `hasAccess`); `import 'api_service.dart'` added.
- **`editor_toolbar.dart`**: `onExportSkillMd` callback + "Export as SKILL.md" popup menu entry
  (red extension icon).
- **`card_editor_screen.dart`**: `_onExportSkillMd()` + `dart:js_interop` + `package:web` import;
  wired into `_Editor` widget constructor and `EditorToolbar`.

**Tests**:
- `skill_export_test.go`: 13 backend unit tests — all pass.
- `test/unit/openclaw_export_test.dart`: 30 Flutter unit tests — generate/parse/isOpenclawSkill/
  workspace round-trips — all pass. Total Flutter suite: 113/113.

**Karar**: `generateOpenclawWorkspace` returns combined JSON (no zip/tarball) — consistent with
v3.0 decision to avoid JSZip dependency (`_downloadCliPackage` pattern). Import tab uses explicit
tab 4 (not auto-detect in tab 2) for clearer UX — user explicitly selects SKILL.md format.
Prompt-access gate mirrors backend: `hasAccess` (owner OR purchaser) for download button.

## Sprint Takip Dosyalari
- `SPRINT_V2.md` — Detayli plan ve teknik kararlar
- `SPRINT_V2_TRACKER.md` — Task bazli ilerleme takibi (Team Leader gunceller)
- `.claude/tasks/agent-store/LEGEND_V3_PLAN.md` — Legend v3.0 sprint plani
- `.claude/tasks/agent-store/ux_sprint.md` — v3.2 UX Overhaul sprint plani
