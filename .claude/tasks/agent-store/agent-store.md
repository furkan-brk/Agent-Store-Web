# Agent Store — Master Sprint Tracker
> Takım: agent-store | Son guncelleme: 2026-03-17
> Blok 1-15: v2.0 Sprint (tamamlandi) | Blok 16+: v3.0 Sprint (aktif)

---

# FAZA 1 — v2.0 Sprint (2026-02-23 ~ 2026-02-24) ✅ TAMAMLANDI

---

## Blok 1 — Resim Sistemi (Replicate) ✅
> Agent: Backend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 1.1 | REPLICATE_API_KEY config'e ekle | `config/config.go` | ✅ |
| 1.2 | ReplicateService olustur | `services/replicate_service.go` | ✅ |
| 1.3 | GeminiService.GenerateImage -> Replicate primary | `services/agent_service.go` | ✅ |
| 1.4 | AgentService'e ReplicateService inject et | `services/agent_service.go` | ✅ |
| 1.5 | Router'a REPLICATE_API_KEY gecir | `api/router.go` | ✅ |
| 1.6 | main.go guncelle | `cmd/server/main.go` | ✅ |

---

## Blok 2 — Store & Discovery ✅
> Agent: Frontend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 2.1 | Trending Row widget | `features/store/widgets/trending_row.dart` | ✅ |
| 2.2 | Category Sidebar widget | `features/store/widgets/category_sidebar.dart` | ✅ |
| 2.3 | Store screen'i yeniden duzenle | `features/store/screens/store_screen.dart` | ✅ |
| 2.4 | ApiService.getTrending() ekle | `shared/services/api_service.dart` | ✅ |

---

## Blok 3 — Agent Detail ✅
> Agent: Frontend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 3.1 | Mini chat widget | `features/agent_detail/widgets/mini_chat_widget.dart` | ✅ |
| 3.2 | Radar chart widget (fl_chart) | `features/agent_detail/widgets/radar_chart_widget.dart` | ✅ |
| 3.3 | Similar agents widget | `features/agent_detail/widgets/similar_agents_widget.dart` | ✅ |
| 3.4 | Agent detail screen yeniden duzenle + fork butonu | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ |
| 3.5 | fl_chart bagimliligi ekle | `pubspec.yaml` | ✅ |
| 3.6 | ApiService.chatWithAgent() + forkAgent() | `shared/services/api_service.dart` | ✅ |

---

## Blok 4 — Kullanici Profili ✅
> Agent: Frontend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 4.1 | Profile screen | `features/profile/screens/profile_screen.dart` | ✅ |
| 4.2 | Profile stats inline (header'da) | `profile_screen.dart` icinde | ✅ |
| 4.3 | Router'a /profile ve /profile/:wallet ekle | `app/router.dart` | ✅ |
| 4.4 | ApiService.getUserProfile() | `shared/services/api_service.dart` | ✅ |

---

## Blok 5 — Backend Endpointler ✅
> Agent: Backend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 5.1 | GetTrending() servisi | `services/agent_service.go` | ✅ |
| 5.2 | ForkAgent() servisi | `services/agent_service.go` | ✅ |
| 5.3 | ChatWithAgent() servisi (Gemini Flash) | `services/agent_service.go` | ✅ |
| 5.4 | GetUserProfile() servisi | `services/agent_service.go` | ✅ |
| 5.5 | Yeni handler'lar (Trending/Fork/Chat/Profile) | `api/handlers/agent_handler.go` | ✅ |
| 5.6 | Router guncelle (5 yeni route) | `api/router.go` | ✅ |

---

## Blok 6 — Blockchain / Credits ✅
> Agent: Backend + Frontend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 6.1 | Agent olusturmada kredi dus (10) | `services/agent_service.go` | ✅ |
| 6.2 | Fork'ta kredi dus (5) | `services/agent_service.go` | ✅ |
| 6.3 | Wallet screen credits guncellemesi | `features/wallet/screens/wallet_connect_screen.dart` | ✅ |

---

## Blok 7 — Docker Rebuild + Deploy ✅
> Agent: Team Leader | Tarih: 2026-02-23

| # | Gorev | Durum |
|---|---|---|
| 7.1 | `docker compose build backend` | ✅ 0 hata |
| 7.2 | `docker compose build frontend` | ✅ 0 hata |
| 7.3 | `docker compose up -d` | ✅ 3 servis UP |
| 7.4 | E2E test | ⚠️ Manuel test gerekli |

---

## Blok 8 — Leaderboard + Credit History ✅
> Agent: Backend + Frontend | Tarih: 2026-02-23

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 8.1 | CreditTransaction modeli | `models/credit_transaction.go` | ✅ |
| 8.2 | deductCredits helper + CreateAgent/Fork kredi dusme | `services/agent_service.go` | ✅ |
| 8.3 | GetCreditHistory servisi | `services/agent_service.go` | ✅ |
| 8.4 | GetLeaderboard servisi | `services/agent_service.go` | ✅ |
| 8.5 | Credit History + Leaderboard handler'lar | `api/handlers/agent_handler.go` | ✅ |
| 8.6 | Yeni rotalar (/credits/history, /leaderboard) | `api/router.go` | ✅ |
| 8.7 | Wallet screen redesign | `features/wallet/screens/wallet_connect_screen.dart` | ✅ |
| 8.8 | Credit History ekrani | `features/wallet/screens/credit_history_screen.dart` | ✅ |
| 8.9 | Leaderboard ekrani | `features/leaderboard/screens/leaderboard_screen.dart` | ✅ |
| 8.10 | ApiService: getCreditHistory + getLeaderboard | `shared/services/api_service.dart` | ✅ |
| 8.11 | Router: /credits/history + /leaderboard + sidebar | `app/router.dart` | ✅ |

---

## Blok 9 — UX v2.6 (Purchase + Auth Gates + Art + Cleanup) ✅
> Agent: 5 parallel agents | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 9.1 | PurchasedAgent modeli | `models/purchased_agent.go` | ✅ |
| 9.2 | Agent.Price alani | `models/agent.go` | ✅ |
| 9.3 | PurchasedAgent AutoMigrate | `internal/database/db.go` | ✅ |
| 9.4 | RecordPurchase / IsPurchased / SetAgentPrice servisleri | `services/agent_service.go` | ✅ |
| 9.5 | RecordPurchase / GetPurchaseStatus / SetAgentPrice handler'lar | `api/handlers/agent_handler.go` | ✅ |
| 9.6 | 3 yeni route: /purchase, /purchase-status, /price | `api/router.go` | ✅ |
| 9.7 | sendTransaction JS koprusu | `web/index.html` | ✅ |
| 9.8 | WalletService.sendTransaction() | `shared/services/wallet_service.dart` | ✅ |
| 9.9 | AgentModel.price alani | `shared/models/agent_model.dart` | ✅ |
| 9.10 | ApiService: purchaseAgent / getPurchaseStatus / setAgentPrice | `shared/services/api_service.dart` | ✅ |
| 9.11 | AgentDetail: auth guard, credit display, fork 5 kredi | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ |
| 9.12 | CreateAgent: credit gate (10 kredi check dialog) | `features/create_agent/screens/create_agent_screen.dart` | ✅ |
| 9.13 | Library: 2-tab (Saved/Created) + stats header | `features/library/screens/library_screen.dart` | ✅ |
| 9.14 | Profile ekrani kaldirildi (routes + sidebar) | `app/router.dart` | ✅ |
| 9.15 | Store: auth-aware save, empty search state, branded loader | `features/store/screens/store_screen.dart` | ✅ |
| 9.16 | character_data.dart: 32x32 scale2x, kariteli arkaplan | `features/character/character_data.dart` | ✅ |
| 9.17 | pixel_art_painter.dart: dynamic gridSize, checkered bg | `features/character/pixel_art_painter.dart` | ✅ |
| 9.18 | Go build dogrulamasi | — | ✅ EXIT 0 |

---

## Blok 10 — Purchase UI + Creator Tools + Guild Polish + Store Badges ✅
> Agent: 5 parallel agents | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 10.1 | Buy butonu UI (fiyat gosterimi + Monad odeme modal) | `agent_detail_screen.dart` | ✅ |
| 10.2 | Creator fiyat ayarlama (Library'den owned agent fiyati guncelle) | `library_screen.dart` | ✅ |
| 10.3 | AgentCard fiyat badge (store'da fiyat gosterimi) | `agent_card.dart` | ✅ |
| 10.4 | Guild polish (uye listesi, join/leave, agent showcase) | `guild_screen.dart` + `guild_detail_screen.dart` | ✅ |
| 10.5 | Mini chat gecmisi (localStorage persist) | `mini_chat_widget.dart` | ✅ |

---

## Blok 11 — Performance Optimization Sprint ✅
> Agent: 4 parallel optimizers + Team Leader | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 11.1 | PixelArtPainter: shouldRepaint + transparent-only + breathScale kosullu | `pixel_art_painter.dart` | ✅ |
| 11.2 | AnimationController: rarity-aware hiz + static skip + RepaintBoundary | `pixel_character_widget.dart` | ✅ |
| 11.3 | Store: search debounce 400ms + cacheExtent + RepaintBoundary per card | `store_screen.dart` + `agent_card.dart` | ✅ |
| 11.4 | Backend: DB indexes + SELECT optimization + connection pool | `models/agent.go` + `agent_service.go` + `db.go` | ✅ |
| 11.5 | Go build dogrulamasi | — | ✅ EXIT 0 |

---

## Blok 12 — Rating, Sort/Filter, Credit Top-up, Notifications, Onboarding ✅
> Agent: 5 parallel agents | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 12.1 | Rating & Reviews sistemi (backend + frontend yildiz widget) | `agent_rating.go` + `rating_widget.dart` | ✅ |
| 12.2 | Store sort dropdown (newest/popular/saves/price/oldest) | `store_screen.dart` + `agent_service.go` | ✅ |
| 12.3 | Credit top-up (MON ile kredi satin alma butonlari) | `wallet_connect_screen.dart` + `agent_service.go` | ✅ |
| 12.4 | Notification panel (sidebar zil badge + bildirim dialog) | `notification_service.dart` + `notification_panel.dart` | ✅ |
| 12.5 | Onboarding modal (ilk ziyaret 4-adim wallet rehberi) | `onboarding_modal.dart` + `store_screen.dart` | ✅ |
| 12.6 | Go build dogrulamasi | — | ✅ EXIT 0 |
| 12.7 | Docker --no-cache rebuild + docker compose up | — | ✅ 3 servis UP |

---

## Blok 13 — Agent Detail Polish + Search + Profile + Settings ✅
> Agent: 5 parallel agents | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 13.1 | Agent Detail: tab pill indicator + tags chips + inline similar | `agent_detail_screen.dart` | ✅ |
| 13.2 | Search recent searches (localStorage, horizontal chips, clear) | `store_screen.dart` | ✅ |
| 13.3 | Public profile sayfasi (/profile/:wallet) — agent grid + stats | `public_profile_screen.dart` | ✅ |
| 13.4 | Settings/About ekrani + sidebar Settings NavItem | `settings_screen.dart` + `router.dart` | ✅ |
| 13.5 | Create Agent 3-adim flow (step indicator + Next/Back + validation) | `create_agent_screen.dart` | ✅ |
| 13.6 | Router: /settings + /profile/:wallet + imports | `router.dart` | ✅ |
| 13.7 | Flutter analyze (0 error) + Docker rebuild + 3 servis UP | — | ✅ |

---

## Blok 14 — Creator Dashboard + Multi-Filter + Compare + Achievements + Share ✅
> Agent: 5 parallel agents | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 14.1 | Creator Analytics Dashboard (/creator) — 4 stat kart + DataTable | `creator_dashboard_screen.dart` + `router.dart` | ✅ |
| 14.2 | Store Multi-Filter — RangeSlider fiyat + 8 tag FilterChip | `filter_panel.dart` + `store_screen.dart` | ✅ |
| 14.3 | Agent Compare Modal — VS layout + dual radar + stat bars | `compare_modal.dart` + `agent_detail_screen.dart` | ✅ |
| 14.4 | Achievement Badges — 8 rozet, AchievementRow | `achievement_badge.dart` + `library_screen.dart` | ✅ |
| 14.5 | Share Button — Clipboard API + SnackBar + AppBar icon | `agent_detail_screen.dart` | ✅ |
| 14.6 | Flutter analyze (0 error) + Docker rebuild + 3 servis UP | — | ✅ |

---

## Blok 15 — Explore + Guild Battle + Collections + Profile Bio + UX Polish ✅
> Agent: 5 parallel agents + Team Leader | Tarih: 2026-02-24

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 15.1 | Explore ekrani (/explore) — category tiles + tag cloud + stats | `explore_screen.dart` | ✅ |
| 15.2 | Guild Battle sistemi — stat-bazli simule savas + animasyonlu sonuc | `guild_detail_screen.dart` + `battle_modal.dart` | ✅ |
| 15.3 | Agent Collections — kutuphanede localStorage tabanli klasor sistemi | `library_screen.dart` + `collection_service.dart` | ✅ |
| 15.4 | Profil Bio/Username — wallet ekranindan kullanici adi + bio guncelleme | `wallet_connect_screen.dart` + backend PATCH | ✅ |
| 15.5 | UX Polish — global keyboard shortcuts + tooltip'ler + empty state | `router.dart` + `store_screen.dart` | ✅ |
| 15.6 | Go build dogrulamasi + Docker recreate | — | ✅ EXIT 0 |

---
---

# FAZA 2 — v3.0 Sprint: Temizlik & Yeniden Yapilandirma (2026-03-17 ~)

## Sorun Analizi

| # | Sorun | Etki | Oncelik |
|---|---|---|---|
| S1 | 3 farkli storage mekanizmasi (SharedPreferences + localStorage + LocalKvStore) karisik kullaniliyor | Race condition, stale data, bakim zorlugu | KRITIK |
| S2 | MissionService/LegendService SharedPreferences'tan wallet okuyup LocalKvStore'a yaziyor | Async race, wallet degisikliginde stale | KRITIK |
| S3 | LibraryController 50 agent cekip client-side filtreliyor + recent searches cift yazma | Gereksiz veri transferi, out-of-sync riski | YUKSEK |
| S4 | 21+ yerde shrinkWrap anti-pattern, nested scrollable sorunlari | Performans kaybi, layout hatalari | YUKSEK |
| S5 | Cift sidebar (220px + 180px = 400px), hardcoded 9 kategori, adet gosterimi yok | Dar ekranlarda content sikisiyor | YUKSEK |

---

## Blok 16 — Storage Birlestirme (Unified Storage Layer) ✅
> Agent: flutter-univercity-dev | Tarih: 2026-03-17
> Sorun: S1 + S2

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 16.1 | LocalKvStore'a `clear()` metodu ekle | `local_kv_store_web/io/stub.dart` | ✅ |
| 16.2 | ApiService: SharedPreferences -> LocalKvStore (JWT token) | `shared/services/api_service.dart` | ✅ |
| 16.3 | WalletService: SharedPreferences -> LocalKvStore (wallet_address) | `shared/services/wallet_service.dart` | ✅ |
| 16.4 | MissionService: SharedPreferences kaldir -> LocalKvStore'dan wallet oku | `shared/services/mission_service.dart` | ✅ |
| 16.5 | LegendService: SharedPreferences kaldir -> LocalKvStore'dan wallet oku | `features/legend/services/legend_service.dart` | ✅ |
| 16.6 | OnboardingModal: direkt html.window.localStorage -> LocalKvStore | `shared/widgets/onboarding_modal.dart` | ✅ |
| 16.7 | StoreScreen: direkt localStorage (recent_searches) -> LocalKvStore | `features/store/screens/store_screen.dart` | ✅ |
| 16.8 | MiniChatWidget: direkt localStorage (chat_history) -> LocalKvStore | `features/agent_detail/widgets/mini_chat_widget.dart` | ✅ |
| 16.9 | CollectionService: direkt localStorage -> LocalKvStore (async API) | `shared/services/collection_service.dart` | ✅ |
| 16.10 | NotificationService: direkt localStorage -> LocalKvStore (async API) | `shared/services/notification_service.dart` | ✅ |
| 16.11 | SettingsScreen: Clear All Data -> LocalKvStore.instance.clear() | `features/settings/screens/settings_screen.dart` | ✅ |
| 16.12 | Async API caller guncellemeleri (5 dosya) | `library_controller, library_screen, notification_panel, auth_controller, agent_detail_controller` | ✅ |

**Dogrulama:**
- `shared_preferences` import -> sadece `local_kv_store_io.dart` ✅
- `html.window.localStorage` -> sadece `local_kv_store_web.dart` ✅
- `flutter analyze` -> **No issues found!** ✅

---

## Blok 17 — Duplicate Veri Temizligi ✅
> Agent: flutter-univercity-dev + go-backend-architect (paralel) | Tarih: 2026-03-17
> Sorun: S3

### Backend
| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 17.1 | `creator_wallet` query param destegi (zaten vardi, dogrulandi) | `services/agent/service.go` + `handler.go` | ✅ |
| 17.2 | `GET /api/v1/agents/categories` endpoint (adet bazli, 120s cache) | `services/agent/service.go` + `handler.go` + `router.go` | ✅ |
| 17.3 | CategoryCount struct + categoryLabels map + cache invalidation | `services/agent/service.go` | ✅ |

### Frontend
| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 17.4 | LibraryController: `listAgents(limit:50)` -> `listAgents(creatorWallet: wallet)` | `controllers/library_controller.dart` | ✅ |
| 17.5 | Recent searches: tum logic StoreController'a tasindi, screen'den direkt storage erisimi kaldirildi | `controllers/store_controller.dart` + `store_screen.dart` | ✅ |
| 17.6 | TrendingRow: trending data StoreController'a tasindi (permanent controller, skip-if-loaded) | `controllers/store_controller.dart` + `trending_row.dart` | ✅ |
| 17.7 | StoreController'a `submitSearch()` metodu eklendi (immediate, no double-debounce) | `controllers/store_controller.dart` | ✅ |
| 17.8 | StoreScreen: gereksiz Timer, dart:async, dart:convert import'lari kaldirildi | `features/store/screens/store_screen.dart` | ✅ |

**Dogrulama:**
- `flutter analyze` -> **No issues found!** ✅
- `go build ./...` -> **EXIT 0** ✅

---

## Blok 18 — Scrollable Widget Duzeltmeleri ⏳ SIRADA
> Agent: flutter-univercity-dev
> Sorun: S4

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 18.1 | MiniChatWidget: 2x ListView.builder -> tek CustomScrollView + SliverList | `features/agent_detail/widgets/mini_chat_widget.dart` | ⏳ |
| 18.2 | SettingsScreen: Top-level ListView -> SingleChildScrollView + Column | `features/settings/screens/settings_screen.dart` | ⏳ |
| 18.3 | Loading shimmer'lar: ListView(NeverScrollableScrollPhysics) -> Row/Column | Birden fazla dosya | ⏳ |
| 18.4 | GuildDetailScreen + GuildCreateScreen: nested scrollable audit & fix | `features/guild/screens/` | ⏳ |
| 18.5 | Genel audit: shrinkWrap + NeverScrollableScrollPhysics -> sliver veya Column | Tum 21+ dosya | ⏳ |

---

## Blok 19 — Sidebar & Kategori Yeniden Tasarimi ⏳
> Agent: flutter-univercity-dev + go-backend-architect + ui-designer
> Sorun: S5

| # | Gorev | Dosya | Durum |
|---|---|---|---|
| 19.1 | CategorySidebar -> CategoryChips widget (horizontal wrap, FilterChip) | `features/store/widgets/category_chips.dart` (YENI) | ⏳ |
| 19.2 | StoreScreen: sol sidebar kaldir -> uste inline CategoryChips + agent count badge | `features/store/screens/store_screen.dart` | ⏳ |
| 19.3 | CategoryChips: backend'den dinamik kategori listesi + adet badge | `features/store/widgets/category_chips.dart` | ⏳ |
| 19.4 | ApiService: `getCategories()` metodu ekle | `shared/services/api_service.dart` | ⏳ |
| 19.5 | StoreController: categories observable + loadCategories() | `controllers/store_controller.dart` | ⏳ |
| 19.6 | Eski category_sidebar.dart dosyasini sil | `features/store/widgets/category_sidebar.dart` | ⏳ |

---

## Blok 20 — Build Dogrulama & Test ⏳
> Agent: bug-hunter + Team Leader

| # | Gorev | Durum |
|---|---|---|
| 20.1 | `flutter analyze` -> 0 error | ⏳ |
| 20.2 | `go build ./...` -> EXIT 0 | ⏳ |
| 20.3 | `docker compose build --no-cache` -> tum servisler | ⏳ |
| 20.4 | `docker compose up -d` -> 3 servis UP | ⏳ |
| 20.5 | E2E: Store yuklenme -> kategori filtre -> arama -> agent detay | ⏳ |
| 20.6 | E2E: Wallet bagla -> mission olustur -> disconnect -> reconnect | ⏳ |
| 20.7 | grep: SharedPreferences import = 0 (local_kv_store_io haric) | ⏳ |
| 20.8 | grep: html.window.localStorage = 0 (local_kv_store_web haric) | ⏳ |

---

## Uygulama Sirasi

```
v2.0 (tamamlandi):
  Blok 1-7   -> Temel ozellikler (Replicate, Store, Detail, Profile, Backend, Credits, Docker)
  Blok 8-15  -> Ileri ozellikler (Leaderboard, Purchase, Perf, Rating, Creator, Explore, Guild)

v3.0 (aktif):
  Blok 16 ✅ -> Storage birlestirme (TEMEL — digerlerinin on kosulu)
  Blok 17 ✅ -> Duplicate veri temizligi (backend + frontend paralel)
  Blok 18 ⏳ -> Scrollable widget duzeltmeleri
  Blok 19 ⏳ -> Sidebar & kategori yeniden tasarimi
  Blok 20 ⏳ -> Build dogrulama & E2E test (son blok)
```

---

## Basari Kriterleri (v3.0)

- [x] `shared_preferences` import -> 0 dosyada (local_kv_store_io haric)
- [x] `html.window.localStorage` -> sadece local_kv_store_web.dart
- [x] LibraryController backend filtresi kullanir (client-side degil)
- [x] Recent searches tek yonlu akis (controller -> storage)
- [x] TrendingRow gereksiz re-fetch yapmiyor
- [x] Categories endpoint mevcut (GET /api/v1/agents/categories)
- [ ] shrinkWrap + NeverScrollableScrollPhysics -> 0 (Column/Sliver'a donusturulmus)
- [ ] Store ekraninda cift sidebar yok — inline category chips
- [ ] Kategori listesi backend'den dinamik geliyor
- [ ] flutter analyze -> 0 error (son dogrulama)
- [ ] go build -> EXIT 0 (son dogrulama)
- [ ] Docker 3 servis UP (son dogrulama)

---

## Teknik Notlar

### API Keys (.env)
| Servis | Durum | Kullanim |
|---|---|---|
| Gemini | ✅ | Prompt analizi + chat |
| Replicate | ✅ | Pixel art image generation |
| Claude | ❌ kredi bitti | — |

### Yeni Endpointler (v3.0)
| Method | Path | Aciklama | Blok |
|---|---|---|---|
| GET | /api/v1/agents?creator_wallet=0x... | Creator bazli filtreleme | 17 |
| GET | /api/v1/agents/categories | Kategori listesi + agent sayisi | 17 |
