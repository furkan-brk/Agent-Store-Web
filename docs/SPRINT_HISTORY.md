# Sprint History — Agent Store

> Detailed sprint notes archived from `CLAUDE.md`. Newest first. Source of truth
> for "what got built, why it was decided that way." `CLAUDE.md` keeps only the
> top-level checklist; deep detail lives here.

---

## v3.12 Bug Bash (2026-05-05) ✅ — branch `sprint/v3.12-bug-bash`

Full codebase audit + fix sprint. 6 independent audit agents (backend, frontend,
coverage, static analysis, Legend deep-dive, responsive inventory) produced a
unified triage. PRs landed in 6 worktrees, all merged with conflict resolution
into `sprint/v3.12-bug-bash`. `go vet` ✅, `flutter analyze` 0 issues ✅,
189 unit + 95 widget Flutter tests ✅, all backend packages ✅.

### Security

- **P0-1 Auth bypass** (`pkg/middleware/strip_wallet_header.go` NEW): Global
  Gin middleware strips inbound `X-Wallet-Address` header before `JWTExtractor`
  runs. Any caller who set this header manually could impersonate any wallet.
  Registered first in all three entry points: `cmd/monolith`, `cmd/gateway`,
  `cmd/agentsvc`. 6 unit tests including the spoof scenario.

### Backend P1 fixes (14 issues)

- **P1-1 Pipeline goroutine ctx** (`services/aipipeline/run_stages.go`): context
  cancellation now propagates into stage goroutines; previously a cancelled
  pipeline could leak goroutines until all stages returned.
- **P1-2 notifyOnce dedup** (`services/agent/notification.go`): replaced
  SELECT-then-INSERT racy dedup with `ON CONFLICT DO NOTHING` on DedupKey unique
  index. `computeNotifyDedupKey` hashes (wallet, type, link, hour-bucket) → 32-char
  hex. `CreateNotification` uses `rawDedupCounter` (sync/atomic) + UnixNano so
  bulk raw inserts never collide on empty key.
- **P1-3 ensureUniqueSlug retry** (`services/workspace/mission_service.go`):
  slug collisions now retried up to 5× with incremental suffix; DB unique index
  enforced so concurrent creates don't race through duplicates.
- **P1-4 Scheduler CAS** (`services/workspace/scheduler.go`): `RunDueSchedules`
  uses `UPDATE … WHERE next_run_at = ?` + `RowsAffected` check so two
  concurrent ticks cannot both claim the same run slot.
- **P1-5/6 ResumeExecution rate-limit + atomic flip**
  (`services/workspace/legend_service.go`): cap at 3 resume attempts per
  execution ID (`WorkflowExecution.ResumeAttempts` field); status flip uses
  `UPDATE … WHERE status = 'failed'` to prevent two concurrent resume calls
  from both advancing.
- **P1-7 AgentVersion snapshot retry** (`services/agent/versioning.go`):
  `snapshotAgentVersion` retries up to 3× on unique-(agent_id, version) conflict;
  `isAgentVersionUniqueConflict` classifier guards the dialect-portable error shape.
- **P1-8 APIKey prefix index** (`pkg/models/api_key.go`): added
  `index:idx_api_key_prefix` on `Prefix` column so prefix-lookup O(log n) not O(n).
- **P1-9 Fuzzy search cap** (`services/agent/search_rank.go`): `maxQueryTokens=5`
  prevents O(N×M) Levenshtein on huge queries; pre-filter skips Levenshtein when
  zero literal title-token hits; `sort.SliceStable` replaces insertion sort.
- **P1-10 GetForYou case-insensitive** (`services/agent/social.go`): library
  lookup now uses `WHERE LOWER(user_wallet) = LOWER(?)` so mixed-case wallet
  addresses don't silently return empty For You feed.
- **P1-11 GetUserRank LIMIT** (`services/agent/leaderboard_extras.go`): ordered
  query capped at 200; separate `COUNT(DISTINCT LOWER(creator_wallet))` for Total
  prevents full-table sort on large datasets.
- **P1-12 LastUsedAt sync** (`pkg/middleware/api_key_auth.go`): removed async
  goroutine from LastUsedAt update — synchronous write (~1ms), eliminates ~50%
  test flakiness from goroutine racing `t.Cleanup`.
- **P1-13 GuildMember dedup** (`pkg/models/guild.go` +
  `services/guild/migrate.go`): added composite `uniqueIndex:idx_guild_member_pair`
  on (GuildID, AgentID); `dedupeGuildMembers()` migration helper runs before
  AutoMigrate to clean existing duplicates without violating the new constraint.
- **P1-14 MissionRun testutil** (`internal/testutil/db.go`): `MissionRun`
  confirmed in use by `services/workspace/scheduler.go` (v3.11.4 T7 cron);
  added documenting comment, kept in AutoMigrate list.
- **skill.md route** (`cmd/monolith/main.go`): wired missing
  `GET /agents/:id/skill.md` route — handler existed in `services/agent/handler.go`
  since v3.11.x but monolith never registered it.

### Frontend P0 fixes

- **Legend FocusNode leak** (`legend_screen.dart`): `_shortcutFocus` hoisted to
  state field (`late final`), initialized in `initState`, disposed in `dispose`.
  Previously recreated on every build → leaked on every rebuild.
- **Legend toolbar overflow** (`legend_toolbar_overflow.dart` NEW):
  `LegendToolbarOverflowMenu` collapses secondary toolbar buttons into
  `PopupMenuButton` below `kLegendToolbarCollapseWidth = 1100px`; Execute pinned
  trailing and never collapses.
- **Dialog controller disposal** (3 sites):
  - `mission_editor_dialog.dart` NEW: StatefulWidget owns + disposes titleCtrl/promptCtrl.
  - `creator_dialogs.dart` NEW: `CreatorEditAgentDialog`, `CreatorSetPriceDialog`,
    `CreatorRegenerateAvatarDialog` — each owns its controllers + disposes them.
    Viewport clamp: `math.min(500/380/420, MediaQuery…size.width - 32)`.
  - `legend_text_input_dialog.dart` NEW: `LegendTextInputDialog` +
    `LegendExecuteInputDialog` own + dispose their controllers.
- **creator_dashboard_screen**: replaced 3 inline `StatefulBuilder` dialogs
  with the new extracted dialog widgets; removed leaked `priceCtrl`/`titleCtrl`/
  `descCtrl`/`tagCtrl` references.

### Frontend P1 fixes

- **AppAnimations constants** (`lib/app/animations.dart` NEW): centralizes magic
  hover/transition durations that were scattered as inline literals.
- **Card Editor SyncStatusBanner** (`card_editor/widgets/sync_status_banner.dart`
  NEW): shows between toolbar and split-view when syncStatus ≠ idle/saved —
  consistent with Mission/Legend pattern.
- **mini_chat bubble max-width** (`agent_detail/widgets/mini_chat_widget.dart`):
  `LayoutBuilder` replaces hardcoded `width:280` so chat bubbles don't overflow
  on narrow viewports.
- **settings_sidebar testPath override** (`settings/widgets/settings_sidebar.dart`):
  `currentPath` optional parameter enables widget tests without a real GoRouter.
- **Creator/developer dialog widths**: all modal dialogs clamped to
  `math.min(maxW, MediaQuery.of(ctx).size.width - 32)`.

### Karar notları

- **Conflict resolution — legend_screen.dart**: HEAD's defensive null-safety
  (`cast<WorkflowEdge?>().firstWhere … orElse: () => null`) kept over PR2's
  `orElse: () => _edges.first` (wrong edge on not-found). PR2's
  LegendTextInputDialog comment kept; old `ctrl = TextEditingController(…)`
  dropped (dialog manages its own now).
- **creator_dashboard conflict**: 3 inline StatefulBuilder blocks vs 3 extracted
  widgets — accepted PR2 (extracted) for all 3; added viewport clamp to
  `creator_dialogs.dart` because it had hardcoded widths (500/380/420).
- **Merge order**: PR3 batches (all backend, no Legend) merged first; PR4
  frontend merged second; PR2 (Legend-touching) merged last after confirming
  user's uncommitted Legend files were already committed in v3.11.5.

### Yeni dosyalar

- `backend/pkg/middleware/strip_wallet_header.go` + `_test.go`
- `backend/services/workspace/mission_slug_test.go`
- `backend/services/workspace/legend_resume_rate_limit_test.go`
- `backend/services/workspace/scheduler_test.go`
- `backend/services/agent/versioning_retry_test.go`
- `backend/services/guild/dedupe_test.go`
- `agent_store/lib/features/legend/widgets/legend_toolbar_overflow.dart`
- `agent_store/lib/features/legend/widgets/legend_text_input_dialog.dart`
- `agent_store/lib/features/missions/widgets/mission_editor_dialog.dart`
- `agent_store/lib/features/creator/widgets/creator_dialogs.dart`
- `agent_store/lib/features/card_editor/widgets/sync_status_banner.dart`
- `agent_store/lib/app/animations.dart`
- `agent_store/lib/shared/utils/legend_error_dialog.dart`

---

## v3.11.4 Closure Sprint (2026-05-05) ✅ 17/17 — backlog 75/75 closed

Backend (9): T1 Discovery analytics · T2 GM KPI · T3 Template metrics ·
T4 Pipeline resilience (per-stage timeout+retry) · T5 Leaderboard
category+me+rewards · T6 Guild events · T7 Mission scheduling (cron) ·
T8 Post-run reflection · T9 Rating verified+copy+achievements (+40 tests).
Frontend (8): T11 Smart suggest · T12 Leaderboard extras (3 widgets) ·
T13 Creator bulk action bar · T14 Trial CTA · T15 Guild events UI ·
T16 Mission schedule dialog · T17 KPI Discovery+GM sections + T17b
Achievement section (+30 tests). Branch `sprint/v3.11.4-closure` 11 commits.

### Backend phase 1 (T1–T9 minus T4/T7)

7/9 backend tasks complete in first wave; closes 9 of 11 missing backlog
items + 3 partial→full upgrades. Backend +27 unit tests. `go vet ./...`
clean, `go build ./...` clean.

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
  complete this sprint. POST /guild-master/sessions/:id/reflect-on-execution
  + GET /reflections.
- **T9 Rating verified + copy analytics + achievements** (3 sub-tasks):
  - **T9a**: GetRatings(verifiedOnly bool) — EXISTS join on PurchasedAgent.
  - **T9b**: POST /agents/:id/copy-analytics → RecordActivity prompt_copy.
  - **T9c**: `Achievement` model + `services/agent/achievements.go`.
    CheckAndAwardAchievements eligibility (first_agent, first_sale,
    first_fork, hundred_saves, top_creator). Idempotent via composite unique.

**Yeni endpoint'ler** (16): GET /admin/kpi/discovery · GET /admin/kpi/guild-master ·
POST /agents/impressions · POST /agents/:id/copy-analytics · GET /legend/templates/metrics ·
POST /user/legend/templates/:id/used · GET /leaderboard/category/:cat · GET /leaderboard/me ·
GET /leaderboard/weekly-rewards · POST /admin/leaderboard/award-weekly · GET /guilds/:id/events ·
POST /guild-master/sessions/:id/reflect-on-execution · GET /guild-master/sessions/:id/reflections ·
GET /users/:wallet/achievements.

**Açık kalanlar (closed in next wave)**: T4 Pipeline resilience · T7 Mission
scheduling (cron) · T11–T17 frontend (8 task).

---

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
  policy — sadece resumed run complete olunca düş; original failed run partial
  spend refund yok. `POST /user/legend/executions/:execId/resume` dual-auth
  (`AuthOrAPIKey("execute:legend")`). **Karar**: model adı `WorkflowExecution`
  — yeni model değil, mevcut'a field eklendi.
- **Bulk Operations**: `POST /agents/bulk` body `{action, ids[], payload}`.
  4 action: `remove_from_library`, `tag_add`, `tag_remove`, `regenerate_image`.
  `bulkActionCost(action, n)` quota guard (regenerate=3 each). Per-id error
  tolerance, max 100 ids enforcement. `services/agent/bulk_actions.go`.
- **Agent Versioning + Rollback**: `AgentVersion` model. `UpdateAgent` →
  `snapshotAgentVersion` best-effort. **Karar**: Rollback **2 versiyon ekler** —
  current state'i önce snapshot'lar, sonra historical fields'ı uygular, sonra
  post-rollback'i de snapshot'lar; rollback reversible olur. LRU eviction at 20
  (subquery via `Pluck`, sqlite + postgres uyumlu).
- **KPI Funnel**: `services/agent/funnel.go` `GetFunnelMetrics(wallet, since)` —
  SuggestToExecute, EditToPublish, PublishToFirstSaveMedianMs, TrialToPurchase
  ratios + Daily metrics. Raw SQL aggregations (`strftime` dialect-agnostic).
  **Karar**: empty denominator için ratio = -1. Cache 5dk TTL.
  `GET /admin/kpi/funnel?since=7d|30d|90d`.
- **API Key Scope Middleware**: `pkg/middleware/api_key_auth.go` — `APIKeyAuth(scope)`
  + `AuthOrAPIKey(scope)` helpers. Header parse (`X-API-Key` veya `Authorization:
  Bearer agst_...`). **Karar**: middleware `pkg/middleware/` altında — import
  cycle önle. **Karar**: `AuthOrAPIKey` JWT öncelikli — JWT varsa API key path
  bypass. Pilot 3 endpoint dual-auth.
- **Notification Auto-Creation Hooks**: `notifyOnce(wallet, type, title, body, link)`
  helper — IsPrefEnabled check + `notificationDedupCheck` 1h window. Wired:
  FollowUser→followee, AddToLibrary→creator, ForkAgent→original creator,
  Legend execution complete→wallet, RecordPurchase→creator+buyer.
  **Karar**: synchronous (RecordActivity nil-DB guard pattern). Self-notifications
  skipped. Legend execution notifications workspace'ten direct DB write.

**Frontend** (5 task):
- **Workflow Versioning Diff UI**: `/legend?id=X&compare=v1,v2` query param.
  `lib/features/legend/widgets/version_diff_panel.dart` — node-by-node split
  (added=green border, removed=red strikethrough, modified=yellow). Backend
  v3.10 `LegendWorkflowVersion` reuse.
- **Execution Observability Panel**: `/legend/observability/:executionId` route.
  5 özet kart + `observability_chart.dart` (pure-Dart CustomPainter bar chart,
  no chart lib dep) + DataTable.
- **Card Presets + Before/After Diff**: 19 preset (8 character types + 2 universal).
  `applyPreset()` history snapshot + draft merge + dirty flag. PreviewChangesButton
  → `card_diff_modal.dart` split-view. Pure `diffFields` helper.
- **Bulk Operations + Versioning UI**: T10a Library bulk select (Select mode
  toggle, _BulkActionBar floating bar). T10b Creator Dashboard bulk regenerate
  defer'd to v3.11.4. T10c Card editor History dialog with Restore.
  `lib/shared/state/bulk_select_state.dart` ChangeNotifier helper.
- **KPI Funnel Panel**: `/admin/kpi` route + sidebar "Insights" nav. 7d/30d/90d
  window selector + 4 metric kart (delta chip + color coding).

**Yeni endpoint'ler** (8): POST /user/legend/executions/:execId/resume ·
POST /agents/bulk · GET /agents/:id/versions + /:v + POST /:v/rollback ·
GET /admin/kpi/funnel · GET /keyed/agents · POST /agents upgrade → AuthOrAPIKey.

---

## v3.11.2 Cross-Cutting Polish (2026-05-05)
10 task; settings sectioning + i18n iskelet + theme toggle + notification center +
API keys + wallet UX trio + rating moderation. Backend +28 unit, Frontend +24 test.

**Backend** (4 task):
- **Notification Center**: `NotificationPref` + `NotificationEvent` models —
  composite uniqueness on (wallet, channel, type), cursor index on (wallet, id DESC).
  `ListPrefs` (default seed: 3 type × 2 channel = 6 entries via `Create(map)` to
  bypass GORM `default:true` stomp), cursor pagination, `MarkRead`/`MarkAllRead`.
- **API Keys**: `APIKey` model (Wallet, Name, KeyHash bcrypt, Prefix size:32,
  Scopes CSV). `CreateKey` generates `agst_` + 32 hex (crypto/rand), bcrypt hash,
  returns plaintext **once**. 3 sabit scope: `read:agents`, `write:agents`,
  `execute:legend`. **Karar**: `SetAPIKeyBcryptCostForTest(bcrypt.MinCost)`
  testlerde — production `bcrypt.DefaultCost` (10).
- **Per-Action Credit Breakdown**: `CreditTransaction.Action` + `Metadata`.
  **Karar**: yeni ledger tablosu yerine `normaliseLedgerAction` helper legacy
  `Type` değerlerini map ediyor. Backward compat: empty Action OK.
- **Rating Moderation**: `RatingFlag` model + `AgentRating.Hidden`. `FlagRating`
  transaction + FOR UPDATE lock + auto-hide at ≥3 flags. Rate-limit: 3 flag /
  wallet / 5dk. **Karar**: `isAbusive(rating.Comment)` 3-vote threshold by-pass.

**Frontend** (6 task):
- **Settings Sectioning**: 4 alt route (`/settings`, `/settings/notifications`,
  `/settings/appearance`, `/settings/developer`). PageHeader + GoRouter nested.
- **i18n iskelet**: `flutter_localizations` + `intl` + `l10n.yaml`
  (`synthetic-package: false` + `output-dir: lib/l10n/gen`). LocaleController.
- **Theme Toggle**: `AppTheme.lightTheme` (parchment palette: bgLight=0xFFF5F1E8,
  cardLight=0xFFEDE6D3, textHLight=0xFF2A1F0E). Shared `_build()` helper.
  ThemeController (mode obs: dark/light/system).
- **Notification UI**: 3×2 SwitchListTile.adaptive matrix + cursor inbox +
  mark-all-read CTA.
- **Developer/API Key UI**: Create modal → plaintext key one-time-show +
  Clipboard.setData + warning. List: masked prefix + scopes chip.
- **Wallet UX trio**: `wallet_errors.dart` (8 error code map + `friendlyError(e)`),
  `tx_timeline.dart` (4-step linear stepper, TxState enum sync), `credit_history_screen.dart`
  per-action ikon (shopping_cart/flash_on/image/add_circle).

**Yeni endpoint'ler** (10): GET/PATCH /user/notifications/prefs · GET /user/notifications/inbox ·
POST /user/notifications/inbox/:id/read · POST /user/notifications/inbox/mark-all-read ·
POST/GET /user/api-keys · DELETE /user/api-keys/:id · POST /agents/:id/ratings/:ratingID/flag.

---

## v3.11.1 User-Facing Polish (2026-05-05)
8 task; user'ın ilk gün gördüğü iyileştirmeler. Backend +17 unit, Frontend +37 test.

**Backend** (3 task):
- **Fuzzy + weighted search**: `ListAgents` artık dolu `search` parametresinde
  GORM'dan **limit 200 aday seti** çekip Go-side weighted (title 3×, tag 2×,
  desc 1×) + Levenshtein fuzzy re-rank uyguluyor. `services/agent/search_rank.go`
  helpers. `pg_trgm` extension bağımlılığı yok. **Karar**: fuzzyThreshold 0.7→0.6.
- **Similar agents endpoint**: `GET /agents/:id/similar?limit=5`. Aynı
  character_type, save_count desc, source agent excluded, 5dk cache.
- **Mission→Legend bridge**: `POST /user/missions/:id/to-legend`.
  `BridgeService.MissionToLegend` + `buildSingleNodeWorkflow(title, prompt)`
  (START→MISSION_AGENT→END, 3 nodes / 2 edges). **Karar**: workspace package
  guild package'ı import etmesin diye **interface + adapter pattern** —
  `workspace.MissionLegendBridge` interface, `cmd/monolith/main.go`'da adapter.

**Frontend** (5 task + 1 bridge UI):
- **Prompt template galerisi**: 10 hazır template, 8 karakter tipine dengeli +
  modal dialog. Step 1 header'da "Use template" butonu.
- **Similar agents ribbon**: `similar_agents_ribbon.dart`. Loading 3× ShimmerBox(180×220),
  error/empty silent fail. **Test hook**: `fetchOverride` + `cardBuilder`.
- **Mention preview hover kartı**: `mention_preview_card.dart` (width 280).
  `_MentionItem` StatefulWidget, OverlayEntry, sağ kenar taşarsa flip-left.
- **Prompt redaction toggle**: `prompt_redaction.dart` pure helper'lar
  (`shouldOfferPromptToggle`, `displayedPromptBody`). >500 char prompt'larda toggle.
- **Pre-publish quality score**: `_QualityScoreCard` Step 2'de (length 40 +
  tags 30 + character match 30). ≥80 yeşil "Excellent". Pure-Dart scorer extract:
  `lib/features/create_agent/data/quality_score.dart`.
- **Credit early-check banner**: `kAgentCost = 10` constant + `hasInsufficientCredits`
  getter. Step 0 üstünde turuncu banner + Top-up CTA.
- **Open in Legend ikonu**: Mission Marketplace `_MissionCard`'a Icons.flash_on
  + `_openInLegend()` spinner state.

**Yeni endpoint'ler**: GET /agents/:id/similar?limit=5 · POST /user/missions/:id/to-legend.

---

## v3.10 Pro Tools (2026-05-04)
21 files changed (3 new backend + 1 new frontend screen).

**Backend** (7 domains):
- **Legend preflight validator**: `PreflightWorkflow` endpoint — loads workflow,
  parses nodes, runs `validateWorkflowStructure`, estimates credits via
  `creditCostForModel` map (haiku=1, sonnet=3, opus=10).
- **Legend workflow versioning**: `LegendWorkflowVersion` model.
  `snapshotWorkflowVersion()` after every `SaveUserWorkflow` (best-effort).
  `ListWorkflowVersions` (max 20, newest first) + `GetWorkflowVersion`.
- **Mission marketplace**: `Public bool` field on `UserMission`.
  `ListPublicMissions(catPrefix)`, `ImportPublicMission` (slug uniqueness via
  `ensureUniqueSlug`), `SetMissionPublic`.
- **Guild invite links**: `GuildInvite` model (32-char crypto/rand hex token,
  ExpiresAt, MaxUses, UsesCount). `CreateInvite` (owner-only, 7-day default).
- **Guild permissions**: `Permissions string` JSON array on `GuildMember`.
  Validates against 5 known keys.
- **Compatibility explainability**: 3-factor breakdown (type diversity 40pt,
  rarity balance 30pt, role completeness 30pt).
- **Creator analytics**: `GetCreatorInsights` with `since` param (7d/30d/90d).
  Daily grouping via `strftime('%Y-%m-%d', ...)` (works SQLite+PostgreSQL).

**Frontend** (4 items): api_service +12 methods · Legend preflight dialog
(`_showPreflightAndExecute()`) · Mission Marketplace screen · Guild Detail
invite link dialog + `_CompatibilitySection`.

**Karar**: Legend node checkpoint/resume (L) + Mission scheduling (cron)
deferred to v3.11 (complexity + no scheduler infra yet).

---

## v3.9 Discovery + Engagement (2026-05-04)

**Backend** — `social.go` + `social_test.go`:
- **UserFollow model**: composite `uniqueIndex:idx_follow_pair`. `FollowUser`
  uses `clause.OnConflict{DoNothing:true}`, `UnfollowUser` hard deletes.
- **UserActivity model**: `idx_activity_wallet_time` composite index;
  `RecordActivity` has nil-DB guard. **Karar**: synchronous (not goroutine)
  because t.Cleanup resets `database.DB` before goroutines finish.
- **GetActivityFeed**: ID-cursor pagination (`before_id`).
- **GetForYou**: character_type majority from user's library → ranked store agents,
  excludes saved IDs + own agents; trending fallback when < 5 results;
  5-min cache keyed `for-you|<wallet>`.
- **GetLeaderboardWindowed**: raw SQL LEFT JOIN; works in both SQLite + PostgreSQL.
- **RenderOGHTML**: escapes `&"<>`; served at `/og/agent/:id` as text/html with
  `Cache-Control: public, max-age=3600`.

**Frontend**: leaderboard window selector (3 chips), `_FollowSection` sliver
(optimistic Follow/Unfollow), `_ActivityFeedSection` (cursor load-more),
`_ForYouMiniCard` horizontal row in store discovery, library empty state
trending nudge cards.

---

## v3.8 Explainability + Action Bridge (2026-05-04)
9 task; 4 backend + 4 frontend + 1 test/docs.

**Backend** (4 task):
- **Structured suggest output**: `GuildSuggestion`'a Goal + Plan ([]PlanStep)
  + Owners ([]OwnerAssignment) + Risks + SuccessCriteria + ConfidencePerType
  eklendi. Tolerant parser eski legacy shape'i de yakalıyor (geri uyumlu).
- **Per-agent reasoning + confidence**: `MatchingAgent` wrapper (embedded
  `models.Agent` + Reason/Confidence/Contribution). `roundConfidence` 2 decimal.
- **Chat history persistence**: `models.GuildMasterSession` (Wallet, Title,
  Problem, MessagesJSON jsonb, SuggestionJSON jsonb). SessionService — CRUD +
  `AppendMessages` (FOR UPDATE locked transaction + 4 KB content cap +
  role validation: user/agent/system).
- **Action bridge endpoints**: `services/guild/bridge.go` BridgeService.
  `ToMission` Goal+Plan+Owners+Risks+Success'i Markdown prompt'una dökerek
  UserMission yaratır. `ToLegend` fan-out/fan-in DAG yaratır (1 START →
  N agent nodes → 1 END), grid-positioned.

**Frontend** (3 task):
- **SuggestPanel widget**: pure presentational 5-section card. Bottom sheet modal.
- **Action bridge UI**: GuildMaster sol panel'inde "Save as Mission" + "Open in
  Legend" buton çifti.
- **Sessions UI**: bottom sheet listesi (active session highlight, swipe-action
  delete, tap-to-resume). `findTeam` artık session create + suggest çağırıyor.

**Karar**: Mission/Legend bridge'leri *direct DB write* ile yapılıyor
(workspace service'i HTTP ile çağırmak yerine `models.UserMission` /
`models.UserLegendWorkflow` Create) — monolith bağlam altında library reuse.

---

## v3.7 Reliability Closure (2026-05-04)
12 task tamamlandı; "stabilite açığı" maddelerinin tümü kapatıldı.

**Backend** (5 task):
- **Legend Workflow optimistic concurrency**: `UserLegendWorkflow.RevisionID
  uint64` + `BeforeUpdate` hook + `LegendRevisionMismatchError{Current
  *LegendWorkflowDTO}` + handler-level `If-Match` parse → 409 + full body.
  Mission/Agent pattern'i bire bir reuse. Backward compat: header opsiyonel.
- **AgentUseLog cooldown**: yeni `AgentUseLog{AgentID, Wallet, IPHash, CreatedAt}`
  (60s wallet+IP cooldown, fail-open, SHA-256 IP hash).
- **save_count event-driven invalidation**: `AddToLibrary` artık `agents|*` +
  `trending` cache bust ediyor; `RemoveFromLibrary` symmetric. Dialect-agnostic
  `CASE WHEN` clamp at 0.
- **Profile PATCH cache invalidation**: `UpdateProfile` username/bio güncellemesi
  sonrası creator name içeren cache anahtarlarını bust eder.
- **Username collision policy**: `services/agent/username.go` — reserve list
  (admin/api/store/guild/legend/system + 25 kelime), `ErrUsernameTaken/Reserved/Format`,
  `SuggestAlternativeUsernames`. Handler 409 + suggestions.

**Frontend** (6 task — biri zaten mevcut):
- **Legend conflict-aware sync**: `LegendWorkflow.revisionId` field +
  `withRevisionId(int)` helper. `If-Match` header gönderir, 409'da
  `ConflictException` fırlatır.
- **Tx state machine UI**: `tx_state.dart` (pure-Dart enum + TxStateX extension
  — 6 state, label/color/icon) + `purchase_button.dart` (PurchaseStatusButton +
  Monad explorer deep-link).
- **Network guard banner**: ZATEN MEVCUT (router.dart `_NetworkBanner` +
  `NetworkGuard` GetxController). Yeni kod yazılmadı.
- **Nonce reuse koruması**: `ApiService.abandonSignature(wallet)` →
  `POST /auth/abandon`.
- **Create Agent draft persistence**: 5s autosave timer + SharedPreferences,
  publish'te clear, post-frame "Continue draft?" dialog.
- **Rating moderation UI**: `AgentRating.Helpful int64` + `RatingHelpfulVote`
  modeli (composite unique index dedup). Atomic `MarkRatingHelpful`
  (FOR UPDATE lock + INSERT vote + counter bump), self-helpful 403.

**Karar**: Mission/Agent revision pattern'i Legend'e port edildi — yeni
framework yaratmak yerine 1:1 reuse. `_NetworkBanner` zaten v3.7-8.x sprint'inde
implement edilmişti, gereksiz yere yeniden yazmadık.

---

## v3.6 Quality Foundation (2026-04-27, partial)
83 tests + CI gate; mobile pass + bug bash deferred.

- **Backend test infra**: `pkg/database/db.go` now exposes `ConnectWithDialector`
  + `SetForTest`. New `internal/testutil/` package with sqlite in-memory DB
  (pure-Go via `github.com/glebarez/sqlite` — no CGO), agent/user/wallet factories,
  ECDSA signing helper.
- **Backend tests**: `services/auth/service_test.go` (12 tests, real ECDSA round-trip;
  87-100% on covered functions), `services/agent/service_test.go` (28 tests).
- **Flutter test infra**: `mocktail` + `fake_async` added. `test/unit/` and
  `test/widget/` directories.
- **Flutter tests**: card_editor_controller_test.dart (18), mention_filter_test.dart
  (15), legend_service_test.dart (10).
- **Mention composer refactor**: extracted `filterAgentSuggestions` into standalone
  `lib/features/guild_master/widgets/mention_filter.dart` so tests don't pull
  `MonacoEditorWidget` (`dart:js_interop` blocks `flutter test` on non-web).
- **CI**: `.github/workflows/ci.yml` — `backend-test` (go vet + race-enabled test
  + coverage artifact upload) and `frontend-test` jobs run on PR + main push.
- **Shared infra**: `lib/shared/widgets/responsive_layout.dart` —
  `ResponsiveLayout(mobile, tablet?, desktop)` LayoutBuilder helper using
  existing `AppBreakpoints`. `isNarrow(BuildContext)` helper.

---

## v3.5 Polish (2026-04-27)
- **Legend overflow fixes**: toolbar workflow name `Flexible` + `ellipsis`;
  toolbar's 12+ button right-cluster wrapped in `SingleChildScrollView
  (scrollDirection: horizontal, reverse: true)` so narrow viewports scroll
  instead of overflowing; onboarding step `Text` `maxLines`/`overflow`;
  execution-history node label `ellipsis`.
- **GuildMaster @-mention sectioning**: backend `/user/library` endpoint never
  set `owned: true` on agent JSON. Fix: `GuildMasterController.ensureLibraryLoaded`
  now tags library entries via `copyWith(owned: true)` before merging. Composer
  split into separate `lib.take(6)` + `store.take(8)` (was single `take(8)`).

---

## v3.4 Card Editor (2026-04-26)
Split-view canlı kart editörü — vintage koyu tema:
- **Backend genişletme**: `PUT /agents/:id` whitelist'i artık prompt, category,
  subclass, price, card_version, service_description, profile_mood/role_purpose,
  traits, stats kabul ediyor. character_data JSON merge ile stats/traits/profile
  içeriği güvenle güncelleniyor; owner check değişmedi.
- **CardEditorController**: `_original` + `draft` AgentModel, debounced save
  (600ms), undo/redo history stack (max 50, v3.3 Legend pattern'i), SyncStatus
  enum (idle/dirty/saving/saved/error), exponential backoff retry,
  `reDetectFromPrompt()` keyword scoring re-run.
- **Split-view ekran**: sol form panel (6 accordion section: Identity, Prompt,
  Taxonomy, Stats, Narrative, Visuals) + sağ canlı `AgentCard` preview
  (`RepaintBoundary` + S/M/L boyut toggle). Mobile fallback stacked.
- **Type/rarity politikası**: manuel override YOK; "Re-detect from prompt"
  butonu mevcut keyword scoring'i tekrar çalıştırır → yeni type seçilirse
  subclass otomatik resetlenir.
- **Toolbar**: SyncStatusBadge (renkli pill), Undo/Redo, Save (Ctrl+S), Clone
  (`/agents/:id/fork` + redirect), Export ▼ (JSON pretty + PNG 3× DPR), Close.
  Ctrl+Z/Y/S/Esc + PopScope unsaved-changes onayı.
- **Giriş noktaları (3)**: Agent Detail title row Edit Card (sadece `isOwnAgent`),
  Library kartı hover'da gold edit pencil (sadece creator), Creator Dashboard
  "Manage Card".
- **Export**: `dart:js_interop` + `package:web` ile Blob+AnchorElement download.
- **Yeni rota**: `/agent/:id/edit` → `CardEditorScreen`, GetX tag-scoped binding.

---

## v3.3 Legend v3.5 (2026-04-02)
4 feature, tüm Flutter frontend:
- **Undo/Redo**: `_CanvasSnapshot` history stack (max 50), `_pushHistory()` tüm
  canvas mutation'larında, toolbar Undo/Redo butonları (disabled state ile),
  Ctrl+Z/Ctrl+Y kısayolları.
- **Workflow Templates**: `legend_templates.dart` (6 şablon: Blank, Multi-Agent
  Pipeline, Research+Summarize, Code Review Chain, Mission-Led, Guild Collaboration).
  `legend_templates_dialog.dart` hover kartlı modal. ID remapping ile çakışma önleme.
- **Clone/Duplicate + Delete Confirm**: `_duplicateWorkflow()` tam node ID
  remapping ile, Load dialog'a Duplicate ikonu, silme için onay AlertDialog.
- **Execution History UI**: Her satır expandable (node detayları), süre etiketi
  (Xs/Xm), tamamlanan çalışmalar için Rerun butonu, `onRerun` callback.
- **`_ToolbarButton`**: `disabled` parametresi eklendi (gri renk + onTap=null).

---

## v3.2 UX Overhaul + DB Persistence Fix (2026-03-22)
6 feature, 24 task:
- **CRITICAL BUG FIX**: docker-compose gateway depends_on missing workspacesvc
  (502 Bad Gateway root cause).
- **Shared Widget Library**: PageHeader, EmptyState, ErrorState, ConfirmDialog —
  reused across 8+ screens.
- **Mission/Legend DB Persistence**: Exponential backoff retry (3 attempts),
  SyncStatus enum + ValueNotifier, forceSyncToBackend(), 5-min periodic sync
  timer, sync status banner UI.
- **Store Dual Sidebar**: Left category sidebar (200px) + right filter/trending
  sidebar (260px) for >1024px desktop, 3-column layout with LayoutBuilder.
- **Legend UX**: Toolbar sync indicator, keyboard shortcuts (Ctrl+S, Escape,
  Ctrl+/), unsaved changes warning (PopScope), 4-step onboarding overlay.
- **Cross-Cutting**: AppAnimations class (standardized hover durations),
  animation consistency across cards.
- **Yeni dosyalar**: page_header.dart, empty_state.dart, error_state.dart,
  confirm_dialog.dart, animations.dart, category_sidebar.dart, filter_sidebar.dart,
  legend_onboarding.dart.

---

## v3.1 UX Sprint (2026-03-22)
4 feature, 13 task:
- **Guild Emoji Migration**: roleIcon emoji (Unicode) → Material Icons (IconData
  + Color getters), member role icons → Icons.psychology/shield/bolt/lightbulb/gps_fixed.
- **Keyboard Navigation**: Sidebar FocusTraversalGroup + FocusableActionDetector,
  Store grid FocusableActionDetector, Alt+Backspace browser back, `/` search
  focus, Escape dismiss, Enter activate.
- **Mission Redesign**: Page header icon, search bar, category filter chips,
  stat row, card-based layout, hover effects, skeleton loading, edit/duplicate/
  delete CRUD, empty state.
- **UX Consistency**: Hover effects on all screens, all text English, Store dual
  sidebar preserved.
- **Yeni**: AppShellState.searchFocusNode (cross-widget search focus),
  _GoBackIntent (Alt+Backspace).

---

## v3.0 Legend Sprint (2026-03-22)
3 feature, 16 task:
- **Touch & Touchpad**: onPan→onScale, pinch-zoom, two-finger pan, adaptive port
  sizes (44px touch), trackpad 0.01 step zoom, mobile layout (<768px drawer +
  floating FABs).
- **Claude Export**: ClaudeExportService (8 format: team config, agent .md,
  CLAUDE.md, .cursorrules, JSON, clipboard, context, CLI package), DAG
  topological sort, import parser.
- **Live Claude Execution**: `backend/pkg/claude/client.go`, dual-engine
  (Gemini/Claude), per-node model selection (haiku=1cr, sonnet=3cr, opus=10cr),
  execution context feeding.
- **Yeni dosyalar**: input_mode.dart, dag_utils.dart, claude_export_service.dart,
  legend_export_dialog.dart, backend/pkg/claude/client.go.
- **Karar**: JSZip yerine combined JSON (dependency-free), WorkflowNode metadata
  nullable (backward compat).

---

## v0.1 → v2.6 Roll-up
- v0.1 — Proje iskeleti + Docker + CLAUDE.md
- v0.2 — Go API: auth, agent CRUD, character service
- v0.3 — Flutter UI: store, detail, library, create, wallet
- v0.4 — 8 pixel-art karakter, rarity sistemi, animasyon
- v0.5 — Solidity kontratlar, Monad testnet deploy scripti
- v0.6 — flutter pub get + go mod tidy
- v0.7 — Web3 JS interop: index.html MetaMask köprüsü + dart:js_interop
- v1.0 — docker-compose up: 3 servis UP
- v1.1 — Claude AI entegrasyonu + keyword fallback
- v1.2 — Railway + Vercel deploy, GitHub Actions CI/CD
- v1.3 — E2E bug düzeltme
- v2.0 — Gemini Flash analiz + Gemini Imagen karakter üretimi
- v2.1 — Replicate pixel-art-xl entegrasyonu
- v2.2 — Trending + Category sidebar + Store UX
- v2.3 — Mini chat + Radar chart + Fork butonu
- v2.4 — Kullanıcı Profili ekranı
- v2.5 — Blockchain Credits + Leaderboard
- v2.6 — Docker rebuild + E2E test (9/9 container UP, 20 E2E test passed)
