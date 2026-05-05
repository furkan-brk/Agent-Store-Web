# Features — Agent Store

> Uygulamadaki **tüm kullanıcı feature'larının** listesi. Her feature için
> davranışlar (ne yapar), kullanıcı aksiyonları (ne tıklar/yazar), arka plan
> aksiyonları (sistem ne yapar) ve ilgili kurallar/limitler. Modül haritası için
> `MODULES.md`, mimari/sprint detayları için `ARCHITECTURE.md` &
> `SPRINT_HISTORY.md`.

---

## İçindekiler
1. [Authentication & Wallet](#1-authentication--wallet)
2. [Store / Discovery](#2-store--discovery)
3. [Agent Detail](#3-agent-detail)
4. [Library](#4-library)
5. [Create Agent (Wizard)](#5-create-agent-wizard)
6. [Card Editor (Owner)](#6-card-editor-owner)
7. [Guild](#7-guild)
8. [Guild Master (AI Team Builder)](#8-guild-master-ai-team-builder)
9. [Missions](#9-missions)
10. [Legend (Visual Workflow)](#10-legend-visual-workflow)
11. [Leaderboard](#11-leaderboard)
12. [Creator Dashboard](#12-creator-dashboard)
13. [Insights / KPI Funnel](#13-insights--kpi-funnel)
14. [Settings Hub](#14-settings-hub)
15. [Public Profile](#15-public-profile)
16. [Notification Center](#16-notification-center)
17. [Achievements](#17-achievements)
18. [Credits & Wallet](#18-credits--wallet)
19. [Developer / API Keys](#19-developer--api-keys)
20. [OpenClaw / SKILL.md Integration](#20-openclaw--skillmd-integration)
21. [Onboarding & Shortcuts](#21-onboarding--shortcuts)
22. [Cross-Cutting Behaviors](#22-cross-cutting-behaviors)

---

## 1. Authentication & Wallet

**Yüzey**: `/wallet` ekranı, sidebar Connect butonu, AppShell network banner.

### Kullanıcı aksiyonları
- "Connect Wallet" butonuna basar.
- MetaMask popup'ında hesap seçer.
- Personal-sign promptunda nonce'u imzalar.
- Yanlış zincirde "Switch to Monad" banner butonuna tıklar.
- "Disconnect" butonuyla oturumu kapatır.

### Davranışlar
- `eth_requestAccounts` ile cüzdan adresi alınır.
- `GET /api/v1/auth/nonce/:wallet` → backend nonce üretir.
- `personal_sign(nonce)` ile imzalanır.
- `POST /api/v1/auth/verify` → ECDSA recover ile cüzdan doğrulanır → JWT döner.
- JWT `localStorage`'a yazılır + `AuthController` reactive state'i günceller.
- `NetworkGuard` chainId'yi izler; `0x279f` (10143) değilse kalıcı banner.
- Banner'daki butonla `wallet_switchEthereumChain` çağrısı; ağ kayıtlı değilse
  `wallet_addEthereumChain` ile ekler.
- Vazgeçilen imzalar: `POST /auth/abandon` ile nonce iptal.

### Kurallar
- Auth endpoint'leri 20 req/min rate-limit.
- Auth gerektiren her aksiyondan önce `WalletGuard.checkWithSnackBar` çağrılır.
- Friendly error mapping: `wallet_errors.dart` (kullanıcı reddi, locked
  wallet, vs.).

---

## 2. Store / Discovery

**Yüzey**: `/` (StoreScreen) — sol kategori sidebar + arama bar + trending row +
filtre paneli + agent kart grid.

### Kullanıcı aksiyonları
- Arama kutusuna yazar (`/` kısayolu ile odaklanır).
- Kategori chip'lerinden birini seçer.
- Sol sidebar'dan kategori dalına gider.
- Sıralama (newest, top rated, most saved) seçer.
- Filtre panelinden character/rarity/min-rating filtreler.
- Trending row'da agent'a tıklar.
- Card üstündeki `Save` (bookmark) ikonuna basar.
- Card'a tıklayıp detay sayfasına gider.
- Sonsuz scroll ile daha fazla yükler.

### Davranışlar
- Search debounce: 300ms; her tuşta server'a gitmez.
- `GET /api/v1/agents?q=&category=&sort=` paginated fetch.
- Trending: `GET /api/v1/agents/trending` (cached 5min).
- Categories: `GET /api/v1/agents/categories`.
- Save: `POST /api/v1/user/library/:id`. Auth yoksa snackbar + redirect.
- **Discovery funnel telemetry**:
  - Arama yapıldığında server-side `search` event kaydı (T1).
  - Kart viewport'a girince `agent_impression` event'i toplu (`POST /agents/impressions`, max 100 ID).
  - Karta tıklayınca `agent_open` event'i (`GET /agents/:id` içinde).
  - Save sonrası funnel oranları güncellenir.
- Skeleton loader: ilk yüklemede placeholder kartlar.
- Onboarding modal ilk açılışta tek sefer (`OnboardingModal.shouldShow`).

### Kurallar
- Anonim kullanıcı görüntüleyebilir, "Save" için cüzdan zorunlu.
- Search query 200 char limit, prompt cache layer için.

---

## 3. Agent Detail

**Yüzey**: `/agent/:id` — 3 sekmeli görünüm: Overview, Stats, Reviews.

### Kullanıcı aksiyonları
- Save / Unsave (kalp/bookmark).
- Fork (kendine kopyala).
- Mini chat penceresinde mesaj yaz/cevap al.
- Rate (1–5 yıldız + opsiyonel yorum).
- Review'lerde "Helpful" / "Flag" tıkla.
- "Edit" butonu (yalnız sahibe görünür) → Card Editor'a gider.
- "Compare" modal'da iki agent karşılaştır.
- "Export" → Claude .md / CLAUDE.md / .cursorrules / JSON / clipboard / context / CLI package indirilir.
- "Trial" → 1 saatlik script token ile harici Claude Code kullanımı.
- "Purchase" → on-chain kredi düşümü ile premium agent satın al.
- "Add to Mission" → mevcut bir mission'a ekle.
- "Use in Legend" → workflow'a node olarak çek.
- Similar Agents ribbon'undan başka agent'a atla.
- "Copy prompt" (sadece sahip/satın alan tüm görür; diğerleri redacted).

### Davranışlar
- `GET /api/v1/agents/:id` (optional auth) — sahip/satın alan ise prompt full,
  değilse redacted.
- Mini chat: `POST /agents/:id/chat` — sayfa içinde streaming yanıt.
- Fork: `POST /agents/:id/fork` — kredi düşer, yeni agent oluşur (atomic
  deduct+create).
- Rate: `POST /agents/:id/rate` — 1 oy/wallet, mevcut oyu günceller. Verified
  filter: yalnız satın alan kullanıcıların oyları (`?verified=true`).
- Helpful: `POST /agents/:id/ratings/:ratingID/helpful`.
- Flag: `POST /agents/:id/ratings/:ratingID/flag` — moderation için.
- Trial: `POST /agents/:id/trial` → `trial_token` döner; `GET /trial/:token/script`
  ile public script.
- Purchase: kredi düşer + `PurchasedAgent` row + `RecordActivity purchase`.
- Copy prompt: auth varsa `POST /agents/:id/copy-analytics` event (T9b
  funnel).
- Radar chart: agent'ın 5 stat'ını görselleştirir (creativity, reasoning,
  factuality, speed, depth).
- Similar agents: `GET /agents/:id/similar` — character/category aynı.
- Compare modal: stats radar + prompt diff yan yana.
- TX state widget: pending/confirmed/failed badge'i (purchase için).
- Trial CTA: trial bitiminde `TrialEndCTA` modalı satın al/extend önerir.

### Kurallar
- Owner detection: `creator_wallet == AuthController.wallet`.
- Prompt redaction: ilk 50 karakter + "..." + glow effect.
- Save = library entry; fork = yeni `Agent` row + parent_id.
- Chat rate limit: 30 msg/min/wallet.
- Fork rate limit: 10/h/wallet.

---

## 4. Library

**Yüzey**: `/library` — 2 tab: Saved (kullanıcının kütüphaneye eklediği) ve
Created (kendi yarattığı).

### Kullanıcı aksiyonları
- Tab değiştir (Saved / Created).
- Arama, sort (newest, oldest, alphabetical), filter (kategori).
- Tek bir agent'a tıklayıp detaya gider.
- Bookmark ikonuyla "remove from library".
- Bulk select moduna geçer (long-press / checkbox).
- Bulk: birden fazla seçtikten sonra **Remove**, **Add Tag**, **Regenerate
  Image** action'ları.
- Achievement rozetlerini görüntüler.
- "Export to Legend" → seçilen agent'lardan workflow draft.
- "Open in Claude Code" → seçilen agent'ın SKILL.md deeplink'i.

### Davranışlar
- `GET /api/v1/user/library` — sadece authenticated.
- Filter/sort URL'e yansır (round-trip share/refresh için).
- Bulk action: `POST /api/v1/agents/bulk` (auth zorunlu, body içinde
  `action` + `agent_ids[]`).
- Skeleton loading + EmptyState (boş kütüphane).
- Achievement section: `GET /users/:wallet/achievements` (T17b).
- Saved tab'da agent silinince optimistic UI + rollback hata varsa.

### Kurallar
- Auth zorunlu (anonim → wallet connect ekranı).
- Bulk select max 100 ID/req.
- "Created" tabında "Edit" CTA'sı her kart üstünde.

---

## 5. Create Agent (Wizard)

**Yüzey**: `/create` — 3 adım: **Basic Info → Prompt → Review**.

### Kullanıcı aksiyonları
- Title (zorunlu, ≤80 char), description, kategori seçer.
- Prompt yazar (≥20 char) veya "Use Template" ile prompt template galerisinden
  birini seçer.
- Quality score göstergesi canlı güncellenir (kelime sayısı, boş satır, fiil
  kullanımı vb. heuristic).
- "Tags" inputu (template'den otomatik gelir).
- Review adımında özet + tahmin edilen karakter (preview pixel-art).
- "Create Agent" submit.
- Auth yoksa Wallet Connect inline ekran.

### Davranışlar
- **Draft persist**: 3 alan (title, desc, prompt) 5 sn'lik debounce ile
  `LocalKvStore`'a yazılır (`create_agent_draft_v1`). Tab kapanır/yenilenirse
  geri yüklenir; başarılı submit'te temizlenir.
- Submit: `POST /api/v1/agents` (writeAgentsAuth — JWT veya `write:agents`
  scope'lu API key).
- Backend pipeline (atomic):
  1. Kredi düşülür (atomic `deductCreditsTx`).
  2. Agent row yaratılır.
  3. AI pipeline asynchronously analyze → profile → avatar zinciri (T4
     resilience: per-stage timeout + retry).
  4. `character_type`, `rarity`, `tags`, `generated_image` doldurulur.
- Submit sonrası loading sayfası → tamamlandığında `/agent/:id`'ye redirect.
- Quality score ≥60 önerilir (zorunlu değil).
- Achievement: ilk agent → `first_agent` rozeti.

### Kurallar
- Create rate limit: 10/h/wallet.
- Body size limit: 2MB.
- Title max 80, prompt min 20, prompt max ~10K char.
- Wallet zorunlu (yoksa wizard içinde inline connect).
- Min kredi yetmiyorsa kredi yükleme ekranı.

---

## 6. Card Editor (Owner)

**Yüzey**: `/agent/:id/edit` — sahip kontrolü; değilse redirect.

### Kullanıcı aksiyonları
- 6 accordion bölümün herhangi birini açar:
  1. Identity (title, description, category)
  2. Prompt (Monaco editor)
  3. Character / Visual (manual override + regenerate)
  4. Tags
  5. Pricing (free / credit-gated)
  6. Visibility / Status
- Canlı önizleme panelinde değişiklikleri izler.
- **Ctrl+Z / Ctrl+Y** ile undo/redo.
- **Ctrl+S** ile kaydet (auto-save de var).
- "Regenerate Image" — backend Replicate ile yeni pixel-art üretir.
- "View Versions" → version history dialog.
- "Diff" — eski versiyonla karşılaştır.
- "Rollback" — eski versiyona dön.
- "Export PNG/JSON" — kart kombinasyonunu indir.
- "Set Price" → kredi miktarı.
- "Delete Agent" (confirm dialog).

### Davranışlar
- 600ms debounce auto-save.
- Optimistic concurrency: `If-Match` header ile `RevisionID`. 409 dönerse
  `ConflictDialog` ile overwrite/discard/merge seçimi.
- Versioning: her save bir `AgentVersion` row.
  - `GET /agents/:id/versions`, `GET /:v`, `POST /:v/rollback`.
- Regenerate image: `POST /agents/:id/regenerate-image` (rate-limit: 10/h/wallet).
- Regenerate pipeline: `POST /agents/:id/regenerate-pipeline` — analyze+profile+avatar
  zinciri timeout+retry ile.
- Cache invalidation: save → `cache.DeletePrefix("agents|")`.
- Keyboard shortcut + PopScope guard (kaydedilmemiş değişiklikte uyar).

### Kurallar
- Yalnız `creator_wallet` sahibi açabilir.
- Title/desc/prompt aynı limitler (Create wizard ile aynı).
- Body 2MB, save rate kısıtsız (debounce yeterli).

---

## 7. Guild

**Yüzey**: `/guild`, `/guild/create`, `/guild/:id`.

### Kullanıcı aksiyonları
- **Liste**: arama, oluştur butonu, kart tıkla.
- **Oluştur**: ad, açıklama, agent seçimleri (kütüphaneden), submit.
- **Detay**:
  - Üyeleri listele (her biri agent + permission badge).
  - "Join" / "Leave" buton.
  - "Add Member" → kütüphaneden agent ekle.
  - "Remove Member" (admin permission gerekli).
  - "Set Permissions" — owner/editor/viewer.
  - "Compatibility" view — synergy badge'i + "Explain" butonu.
  - "Create Invite" — paylaşılabilir token URL.
  - "Accept Invite" — `/guild/invite/:token` linkiyle giriş.
  - "Events" — audit timeline (kim katıldı/ayrıldı/permission değişti).
  - "Send to Guild Master" — chat oturumu başlat.
  - "Send to Legend" — workflow draft oluştur.

### Davranışlar
- `GET /guilds`, `GET /guilds/:id`, `POST /guilds`, `POST /guilds/:id/members` vs.
- Compatibility: backend agent character'larını `pkg/gamification/synergy.go`
  ile skorlar.
- Explain: `GET /guilds/:id/explain` — neden bu skor (synergy detayı).
- Invite: `POST /guilds/:id/invite` → token; `GET /guilds/invite/:token`
  preview; `POST /guilds/invite/:token/accept`.
- Permission: `PUT /guilds/:id/members/:memberId/permissions`.
- Events log (T6): tüm join/leave/permission/remove → `GuildMemberEvent` row,
  `GET /guilds/:id/events`.
- Team formation widget: 5 slotlu pano + drag-drop.

### Kurallar
- Sadece auth.
- Permission cascade: owner > editor > viewer.
- Kendi guild'inden ayrılırsa son ise guild boşalır.

---

## 8. Guild Master (AI Team Builder)

**Yüzey**: `/guild-master` — chat interface.

### Kullanıcı aksiyonları
- "Yeni oturum" oluştur veya geçmişten birini aç.
- Chat kutusuna mesaj yazar.
- **@mention composer**: `@` yazınca library + store agent'ları popup'ta
  görünür (lib max 6, store max 8).
- Mention seçince mesaja "preview card" eklenir.
- "Suggest Team" tıklar → AI 3-5 agent öner.
- Önerideki agent'ları kabul/red eder.
- "Send to Mission" → seçilen team'den mission draft.
- "Send to Legend" → seçilen team'den workflow draft.
- "Reflect on Execution" → workflow çalıştıktan sonra not bırak.
- "Export Chat" → markdown indir.
- Oturumu sil/yeniden adlandır.

### Davranışlar
- `POST /guild-master/sessions` yeni oturum, `GET /sessions` liste.
- `POST /guild-master/sessions/:id/messages` mesaj append.
- `POST /guild-master/suggest` — Claude ile takım önerisi.
- `POST /guild-master/chat` — Claude ile sohbet (oturum bağlamında).
- Bridge:
  - `POST /sessions/:id/to-mission` — backend mission service'e draft yazar.
  - `POST /sessions/:id/to-legend` — workspace service'e workflow draft.
- Reflection (T8): `POST /sessions/:id/reflect-on-execution`, max 4000 char.
- KPI (T2): Suggest→Execute, Chat→Action, Rerun rate aktivite eventleriyle
  hesaplanır.
- Mention filter pure-Dart `mention_filter.dart` (test edilebilir).

### Kurallar
- Suggest + chat: 20 req/min/wallet rate-limit.
- Sadece kendi oturumunu görebilir (foreign wallet → ErrSessionNotFound).
- Reflection wallet-scope.

---

## 9. Missions

**Yüzey**: `/missions` (kişisel) + `/missions/marketplace` (public).

### Kullanıcı aksiyonları
- Mission listesi: arama, kategori chip (All/Code/Writing/Data/Design/Research).
- "Yeni Mission" CRUD modalı (ad, prompt, agent ataması).
- Mission'ı düzenle / sil.
- "Make Public" toggle → marketplace'a paylaş.
- "Import" public mission'ı kendi listesine kopyala.
- "Send to Legend" → workflow'a köprüle.
- "Schedule" — cron pattern (T7).
- "View Runs" — geçmiş otomatik çalıştırmalar.
- "Expand" — AI ile mission promptunu detaylandır.

### Davranışlar
- Local-first: `MissionService` tüm değişiklikleri local cache'e yazar →
  `SyncStatus` (idle/dirty/saving/saved/error) badge'i göster.
- Periyodik sync 5 dk; exponential backoff retry (3 deneme).
- `POST /user/missions/sync` batch sync.
- Marketplace:
  - `GET /missions/public` (auth gerekmez).
  - `PATCH /user/missions/:id/public` — toggle.
  - `POST /user/missions/:id/import` — kişiselleştir.
- Schedule (T7): `POST /missions/:id/schedule` cron string. Scheduler
  workspace servisinde tetikleyince `UserActivity` marker yazar (v3.11.4
  iskeleti). `GET /missions/:id/runs` çalıştırma geçmişi.
- Expand: `POST /missions/expand` Claude/Gemini.
- Bridge: `POST /missions/:id/to-legend` (v3.11.1).

### Kurallar
- Auth zorunlu (kişisel CRUD).
- Public mission read-only başkası için.
- Sync banner: dirty olduğunda gri "•", saved olduğunda yeşil "✓".

---

## 10. Legend (Visual Workflow)

**Yüzey**: `/legend` — DAG canvas + sol palette + sağ properties paneli.

### Kullanıcı aksiyonları
- Canvas'a sol palette'ten node sürükle (Start, Agent, Mission, Guild,
  Decision, End).
- Node'ların çıkış portundan giriş portuna sürükleyerek edge çiz.
- Node'a tıklayıp sağ panelde özelliklerini düzenle (label, model seçimi:
  Haiku=1cr / Sonnet=3cr / Opus=10cr).
- Edge'i sil (klavye Delete).
- **Ctrl+Z / Ctrl+Y** undo/redo.
- Pan (orta tuş / iki parmak), zoom (Ctrl+wheel veya pinch).
- "Save" (Ctrl+S) — sürüm oluşturur.
- "Templates" → hazır şablon galerisi (6 template).
- "Clone" — workflow'u çoğalt.
- "Execute" — DAG'ı topological order'da çalıştırır.
- "Preflight" — node'ların geçerliliğini kontrol et (eksik prompt, döngü vs.).
- "Versions" → geçmiş sürümler + diff panel.
- "Rollback" eski sürüme dön.
- "Export to Claude Code" — seçilebilir 8 format.
- "Observability" — son execution'ı detayda izle (`/legend/observability/:id`).
- "Resume" — başarısız execution'ı son başarılı node'dan devam ettir.

### Davranışlar
- Workflow shape: nodes (id, type, label, x, y, refId, model) + edges (from, to).
- DAG validation: `dag_utils.dart` cycle detect + reachability.
- `POST /user/legend/workflows` save (revision_id ile optimistic concurrency).
- `POST /user/legend/workflows/:id/execute` — server-side topological execution.
- Execution stream: `WorkflowExecution` row, NodeStates JSON (running/done/error/skipped).
- Preflight (v3.10): `GET /workflows/:id/preflight`.
- Versions (v3.10): `GET /workflows/:id/versions`, `GET /:versionId`, diff panel.
- Resume (v3.11.3): `POST /executions/:execId/resume` (dual-auth: JWT veya
  `execute:legend` API key).
- Templates (T3): seçilince `POST /user/legend/templates/:id/used` kaydı.
  Template metrics public okuma.
- Observability ekranı: tüm node'ların execution log'u, model kullanımı,
  süre, kredi tüketimi, hata mesajı.
- Onboarding overlay ilk açılışta.
- Touch / Mouse / Touchpad detection (`input_mode.dart`) — pan/zoom UX
  ayarlaması.
- Hata dialogu: `legend_error_dialog.dart` Friendly retry/dismiss.

### Kurallar
- Execute rate limit: 20/min/wallet.
- Model seçim kredi maliyeti haiku=1, sonnet=3, opus=10.
- Body 2MB.
- Resume yalnız `failed` status execution'larda.

---

## 11. Leaderboard

**Yüzey**: `/leaderboard` — 3 tab: Top Creators, By Uses, By Rating.

### Kullanıcı aksiyonları
- Tab değiştir.
- Period filter (all-time / 7d / 30d).
- Kategoriye göre filtrele.
- "Show me my rank" — kendi rütbesini gör.
- Weekly rewards listesini görüntüle.
- Bir creator'a tıkla → public profile.

### Davranışlar
- `GET /leaderboard` — varsayılan (creators).
- `GET /leaderboard/category/:cat` (T5) — kategoriye göre top 10.
- `GET /leaderboard/me` (T5) — `IsMe` flag'li 4 komşu + off-board ise
  alttan 5 hint.
- `GET /leaderboard/weekly-rewards` (T5) — haftalık ödül listesi (top1=100,
  top2=50, top3=30, top4-10=10 kredi).
- Admin: `POST /admin/leaderboard/award-weekly` — ISO week (`YYYY-Www`),
  idempotent unique constraint, `X-Admin-Token` zorunlu.
- 3 widget (T12): top creator card, my rank ribbon, weekly rewards row.

### Kurallar
- Public read.
- Award endpoint'i `ADMIN_API_TOKEN` env yoksa fail-closed.

---

## 12. Creator Dashboard

**Yüzey**: `/creator` — kullanıcının yarattığı agent'lar.

### Kullanıcı aksiyonları
- Kendi agent'larının grid view'i.
- Insights kartı: total saves, uses, rating, fork count.
- Agent kart üstünde "Edit" / "Delete" / "Regenerate Image".
- Bulk action bar (T13): seç → Remove/AddTag/RegenImage/Publish.
- "Funnel" CTA'sı → `/admin/kpi`.

### Davranışlar
- `GET /api/v1/user/creator/insights` (v3.10).
- Agent grid: `creator_wallet == myself` filter.
- Bulk: `POST /agents/bulk`.
- Empty state: "Henüz yarattığın agent yok → Create Agent CTA".
- Unauth state: Wallet Connect CTA.

### Kurallar
- Sadece sahip kendi insights'ını görür.

---

## 13. Insights / KPI Funnel

**Yüzey**: `/admin/kpi` — creator-scoped KPI panel.

### Kullanıcı aksiyonları
- Pencere seç: 7d / 30d / 90d.
- Funnel kartlarını incele.
- "Discovery" tab'ı (T17) — search→save, impression→open, open→save oranları.
- "Guild Master" tab'ı (T17) — Suggest→Execute, Chat→Action, Rerun.
- "Creator Funnel" — Edit→Publish, Publish→FirstSave, Trial→Purchase.

### Davranışlar
- `GET /admin/kpi/funnel?since=7d|30d|90d`.
- `GET /admin/kpi/discovery` (T1).
- `GET /admin/kpi/guild-master` (T2).
- `-1` döner = denominator yok (UI "—" göster).
- 5 dk cache (server-side).

### Kurallar
- Creator-scoped (kendi event'leri).
- Auth zorunlu.

---

## 14. Settings Hub

**Yüzey**: `/settings` index + 3 alt rota.

### 14.1 Profile (`/settings`)
- Wallet bağlı/bağlı değil göster.
- Username düzenle (`PATCH /user/profile`).
- Network detayı.
- About (versiyon, link).
- "Sign Out" — confirm dialog → JWT ve cache temizle.
- Danger zone: "Delete account" (confirm).

### 14.2 Notifications (`/settings/notifications`)
- 6+ tercih toggle (new save, follow, fork, mission, etc.).
- `GET/PATCH /user/notifications/prefs`.
- Inbox'taki son N mesaj.
- "Mark all read".

### 14.3 Appearance (`/settings/appearance`)
- Tema: Dark / Parchment.
- Dil: TR / EN.
- Animation density (reduced motion).
- ThemeController + LocaleController persist (LocalKvStore).

### 14.4 Developer (`/settings/developer`)
- API key oluştur / liste / iptal.
- Scope seç: `read:agents`, `write:agents`, `execute:legend`.
- Token yalnızca oluşturulurken bir kez gösterilir (`pat_*`).
- "Copy" + "Hide" butonu.
- `GET/POST/DELETE /user/api-keys`.

### Kurallar
- Auth zorunlu (anonim → wallet connect).
- API key revoke'tan sonra cache'siz hemen geçersiz.

---

## 15. Public Profile

**Yüzey**: `/profile/:wallet` — başkası ya da kendisi.

### Kullanıcı aksiyonları
- Kendi profil ise: "Edit" / "Share" CTA.
- Başkası: "Follow / Unfollow".
- Agent grid (yarattığı public).
- Achievement section (T17b).
- Activity feed (son aktiviteler).
- "Followers" / "Following" listeleri.
- "Share" — link panoya kopyala.

### Davranışlar
- `GET /api/v1/users/:wallet` profil.
- `POST/DELETE /users/:wallet/follow` follow toggle.
- `GET /users/:wallet/followers`, `GET /following`.
- `GET /users/:wallet/feed` aktivite feed'i.
- `GET /users/:wallet/achievements`.
- `GET /users/:wallet/follow-status` (auth varsa).
- OG meta: `/api/v1/og/agent/:id` server-side rendered share preview.

### Kurallar
- Public read (auth yok).
- Follow auth zorunlu.

---

## 16. Notification Center

**Yüzey**: Sidebar/AppBar'da bell ikonu + dropdown panel.

### Kullanıcı aksiyonları
- Bell'e tıkla → panel açılır.
- Bildirimi okundu işaretle.
- "Mark all read".
- Bildirime tıklayınca link'e gider (agent, guild, mission detail).

### Davranışlar
- `GET /user/notifications/inbox` — listede.
- Unread badge sayısı reactive.
- Tipler: new_save, follow, fork, agent_published, mission_complete,
  legend_run_complete, weekly_reward, achievement, ...
- `notifyOnce(wallet, type, title, body, link)` — server-side dedup 1 saat
  pencere + kullanıcı tercih kontrolü (`IsPrefEnabled`).

### Kurallar
- Tercih kapalıysa hiç oluşmaz.
- 1h dedup aynı (wallet+type+target) için.

---

## 17. Achievements

**Yüzey**: Public profile'de section, library'de küçük rozetler.

### Tipler (T9c)
- `first_agent` — ilk agent yaratımı.
- `first_sale` — ilk premium agent satışı.
- `first_fork` — ilk fork edilmen.
- `hundred_saves` — 100 save eşiği.
- `top_creator` — leaderboard top 10.

### Davranışlar
- Eligible event sonrası `CheckAndAwardAchievements` çağrılır.
- Idempotent: composite unique (wallet+type).
- Public read: `GET /users/:wallet/achievements`.
- UI: rarity glow + tooltip.

---

## 18. Credits & Wallet

**Yüzey**: `/wallet`, `/credits/history`, sidebar footer.

### Kullanıcı aksiyonları
- Sidebar footer'da kredi sayacı görür.
- `/credits/history` ledger detayını açar (giriş/çıkış).
- "Top Up" — kredi yükle (placeholder, dev-grant dev modunda).
- TX timeline: pending/confirmed/failed badge.

### Davranışlar
- `GET /user/credits` balance.
- `GET /user/credits/history` ledger.
- `POST /user/credits/topup` placeholder (prod: gerçek on-chain).
- `POST /user/credits/dev-grant` dev-only.
- Atomic deduct+create: kredi düşümü ile DB row aynı transaction
  (`deductCreditsTx`, `appendLedgerTx`).
- TX state: `tx_state.dart` pure helper (test edilebilir).

### Kurallar
- Min credits gerektiren aksiyonda yetmiyorsa "Insufficient credits" CTA.
- On-chain top-up Monad testnet'te.

---

## 19. Developer / API Keys

**Yüzey**: `/settings/developer`.

### Kullanıcı aksiyonları
- API key oluştur (isim + scope check).
- Token kopyala (sadece bir kez!).
- Listeyi izle (created_at, last_used_at, scopes).
- Revoke (silme onayı).

### Davranışlar
- Token format: `pat_<32-byte-base64>` — DB'de SHA256 hash saklı, plain
  yalnızca yaratımda dönülür.
- Scope-gated dual-auth middleware: `AuthOrAPIKey("read:agents")` vs.
- v3.11.3'te uygulanan dual-auth endpointler:
  - `GET /keyed/agents` → `read:agents`
  - `POST /agents` → `write:agents`
  - `POST /executions/:execId/resume` → `execute:legend`
- `LastUsedAt` async update (RecordActivity benzeri sync write — t.Cleanup race önle).

### Kurallar
- Revoke immediate (cache yok).
- Token yaratımı auth zorunlu.

---

## 20. OpenClaw / SKILL.md Integration

**Yüzey**: Agent detail "Use in Claude Code" → install modal.

### Kullanıcı aksiyonları
- "Open in Claude Code" tıkla → install modal.
- "Install" deeplink'i (`openclaw://install-skill?url=...`) Claude Code
  uygulamasını açar.

### Davranışlar
- Public endpoint: `GET /agents/:id/skill.md` — OptionalAuth.
  - **Anonim** → redacted SKILL.md (metadata + ilk 50 char prompt + indirme
    için cüzdan/satın alma çağrısı).
  - **Owner / purchaser** → tam SKILL.md.
- Library workspace export: seçilen agent'lardan toplu SKILL.md zip indirme.
- Bridge RFC: `docs/rfc/openclaw-bridge.md`.

### Kurallar
- Anonim erişim sadece redacted; tam içerik için cüzdan + sahip/satın alan
  kontrolü.

---

## 21. Onboarding & Shortcuts

**Yüzey**: Tüm app — ilk açılış + klavye.

### İlk açılış
- `OnboardingModal` 3 sayfa (welcome, characters, gamification).
- "Skip" / "Next" / "Get Started".
- Shown-once flag `LocalKvStore`'da.

### Klavye kısayolları (AppShell)
- `Alt+S` — Store
- `Alt+L` — Library
- `Alt+C` — Create
- `Alt+G` — Guild
- `Alt+W` — Legend
- `/` — Store search'e odak
- `Esc` — modal/dialog kapat
- `Alt+Backspace` — geri

### Davranışlar
- `_AppShell` global Shortcuts widget'ında tanımlı Intent'ler.
- Search FocusNode: store'a register, `/` ile cross-widget focus.

---

## 22. Cross-Cutting Behaviors

Aşağıdakiler her feature'da ortak çalışır.

### 22.1 Wallet Guard
- Auth gerektiren her aksiyondan önce `WalletGuard.checkWithSnackBar`.
- Yoksa snackbar + redirect `/wallet`.

### 22.2 Sync Status (Mission, Legend, Card Editor)
- `SyncStatus` enum: idle / dirty / saving / saved / error.
- `ValueNotifier`'la reaktif.
- 5 dk periyodik sync + exponential backoff retry (3 deneme).

### 22.3 Optimistic Concurrency (Agent, Mission, Legend)
- `RevisionID uint64` her save'de artar (GORM `BeforeUpdate` hook).
- Handler `If-Match` parse → mismatch'te 409 + tam body.
- UI 409'da `ConflictDialog` (overwrite / discard / merge).

### 22.4 Cache Invalidation
- Save / fork / library edit / regenerate sonrası
  `s.cache.DeletePrefix("agents|")` event-driven.

### 22.5 Notifications (notifyOnce)
- `notifyOnce(wallet, type, title, body, link)` helper:
  - Tercih kontrolü (`IsPrefEnabled`)
  - 1 saat dedup penceresi
  - Best-effort (hata fırlamaz, log'a yazar)

### 22.6 Activity Feed
- Public follow feed her aksiyon için marker yazar (purchase, save, fork,
  agent_create, ...).
- `RecordActivity` SYNCHRONOUS (NOT goroutine) — testlerde `t.Cleanup` race
  önlemek için. Aynı kural async DB write'lara da geçerli (LastUsedAt vb.).

### 22.7 Network Banner
- `NetworkGuard` chainId değişimini dinler. Yanlış zincirde AppShell üst
  banner: "Switch to Monad Testnet".

### 22.8 Rate Limiting (özet)
| Endpoint                              | Limit               |
| ------------------------------------- | ------------------- |
| `/auth/*`                             | 20/min              |
| `POST /agents` (create)               | 10/h/wallet         |
| `POST /agents/:id/regenerate-image`   | 10/h/wallet         |
| `POST /agents/:id/fork`               | 10/h/wallet         |
| `POST /agents/:id/chat`               | 30/min/wallet       |
| `POST /guild-master/{suggest,chat,...}`| 20/min/wallet      |
| `POST /legend/workflows/:id/execute`  | 20/min/wallet       |

### 22.9 Body Size Limit
- Tüm yazma endpoint'lerinde 2MB cap.

### 22.10 Skeleton Loading + Empty/Error States
- Tüm async sayfalarda `SkeletonWidgets`, `EmptyState`, `ErrorState` reuse.
- Confirm yıkıcı eylemler `ConfirmDialog` ile.

### 22.11 Telemetri / Audit
- Route view: `AppTelemetryService.onRouteSeen(loc)`.
- User actions: `UserActivity` rows.
- Guild events: `GuildMemberEvent` audit log.

### 22.12 Locale & Theme
- TR/EN dil değiştirme, `/l10n/gen/*`.
- Dark + Parchment 2 tema. Persist `LocalKvStore`.

### 22.13 Responsive
- `AppBreakpoints.isMobile` (~768px split).
- AppShell: wide (sidebar) vs narrow (bottom nav + drawer).

---

## Sonraki Yapılabilecekler

- Mobile pass + bug bash (deferred — v3.11.5 sonrası planlanıyor).
- Mission scheduling actual exec (T7 v3.11.4'te marker only; gerçek run v3.11.5'te).
- RBAC sprint — admin endpoint'lerin `X-Admin-Token` stopgap'ından çıkması.
- Polish (v3.11): UX consistency, edge case'ler, accessibility geçişi.
