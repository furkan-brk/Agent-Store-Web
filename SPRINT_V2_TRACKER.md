# Agent Store — v2.0 Sprint Tracker
> Team Leader tarafından tutulur. Her task tamamlandığında güncellenir.
> Son güncelleme: 2026-02-23

---

## 🏷️ Sprint Durumu: IN PROGRESS — Blok 13 (sonraki özellikler) hazır

---

## 📦 Blok 1 — Resim Sistemi (Replicate) ✅
> Agent: **Backend**
> Model: `nerijs/pixel-art-xl` (Replicate), Gemini Imagen fallback

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 1.1 | REPLICATE_API_KEY config'e ekle | `config/config.go` | ✅ DONE | Backend |
| 1.2 | ReplicateService oluştur | `services/replicate_service.go` | ✅ DONE | Backend |
| 1.3 | GeminiService.GenerateImage → Replicate primary | `services/agent_service.go` | ✅ DONE | Backend |
| 1.4 | AgentService'e ReplicateService inject et | `services/agent_service.go` | ✅ DONE | Backend |
| 1.5 | Router'a REPLICATE_API_KEY geçir | `api/router.go` | ✅ DONE | Backend |
| 1.6 | main.go güncelle | `cmd/server/main.go` | ✅ DONE | Backend |

---

## 📦 Blok 2 — Store & Discovery ✅
> Agent: **Frontend**

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 2.1 | Trending Row widget | `features/store/widgets/trending_row.dart` | ✅ DONE | Frontend |
| 2.2 | Category Sidebar widget | `features/store/widgets/category_sidebar.dart` | ✅ DONE | Frontend |
| 2.3 | Store screen'i yeniden düzenle | `features/store/screens/store_screen.dart` | ✅ DONE | Frontend |
| 2.4 | ApiService.getTrending() ekle | `shared/services/api_service.dart` | ✅ DONE | Frontend |

---

## 📦 Blok 3 — Agent Detail ✅
> Agent: **Frontend**

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 3.1 | Mini chat widget | `features/agent_detail/widgets/mini_chat_widget.dart` | ✅ DONE | Frontend |
| 3.2 | Radar chart widget (fl_chart) | `features/agent_detail/widgets/radar_chart_widget.dart` | ✅ DONE | Frontend |
| 3.3 | Similar agents widget | `features/agent_detail/widgets/similar_agents_widget.dart` | ✅ DONE | Frontend |
| 3.4 | Agent detail screen yeniden düzenle + fork butonu | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ DONE | Frontend |
| 3.5 | fl_chart bağımlılığı ekle | `pubspec.yaml` | ✅ DONE | Frontend |
| 3.6 | ApiService.chatWithAgent() + forkAgent() | `shared/services/api_service.dart` | ✅ DONE | Frontend |

---

## 📦 Blok 4 — Kullanıcı Profili ✅
> Agent: **Frontend**

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 4.1 | Profile screen | `features/profile/screens/profile_screen.dart` | ✅ DONE | Frontend |
| 4.2 | Profile stats inline (header'da) | `profile_screen.dart` içinde | ✅ DONE | Frontend |
| 4.3 | Router'a /profile ve /profile/:wallet ekle | `app/router.dart` | ✅ DONE | Frontend |
| 4.4 | ApiService.getUserProfile() | `shared/services/api_service.dart` | ✅ DONE | Frontend |

---

## 📦 Blok 5 — Backend Endpointler ✅
> Agent: **Backend**

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 5.1 | GetTrending() servisi | `services/agent_service.go` | ✅ DONE | Backend |
| 5.2 | ForkAgent() servisi | `services/agent_service.go` | ✅ DONE | Backend |
| 5.3 | ChatWithAgent() servisi (Gemini Flash) | `services/agent_service.go` | ✅ DONE | Backend |
| 5.4 | GetUserProfile() servisi | `services/agent_service.go` | ✅ DONE | Backend |
| 5.5 | Yeni handler'lar (Trending/Fork/Chat/Profile) | `api/handlers/agent_handler.go` | ✅ DONE | Backend |
| 5.6 | Router güncelle (5 yeni route) | `api/router.go` | ✅ DONE | Backend |

---

## 📦 Blok 6 — Blockchain / Credits
> Agent: **Backend + Frontend**

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 6.1 | Agent oluşturmada kredi düş (10) | `services/agent_service.go` | ✅ DONE | Backend |
| 6.2 | Fork'ta kredi düş (5) | `services/agent_service.go` | ✅ DONE | Backend |
| 6.3 | Wallet screen credits güncellemesi | `features/wallet/screens/wallet_connect_screen.dart` | ✅ DONE | Frontend |

---

## 📦 Blok 7 — Docker Rebuild + Deploy ✅
> Agent: **Team Leader**

| # | Görev | Durum |
|---|---|---|
| 7.1 | `docker compose build backend` | ✅ DONE — 0 hata |
| 7.2 | `docker compose build frontend` | ✅ DONE — 0 hata |
| 7.3 | `docker compose up -d` | ✅ DONE — 3 servis UP |
| 7.4 | E2E test: create agent → Replicate image görünüyor mu | ⏳ Manuel test gerekli |

---

## 🔑 API Keys (tümü .env'de)
| Servis | Durum | Kullanım |
|---|---|---|
| Gemini | ✅ | Prompt analizi + chat |
| Replicate | ✅ | Pixel art image generation |
| Claude | ❌ kredi bitti | — |

---

## 📌 Teknik Notlar
- Replicate: `nerijs/pixel-art-xl` — `Prefer: wait` sync mode, output URL → base64
- fl_chart: `0.69.2` çözümlendi
- Trending skoru: `save_count*3 + use_count*2` (DB query, ORDER BY)
- Fork: Replicate yeni image → Gemini fallback → orijinal image fallback
- Chat: agent.Prompt system context + userMessage → Gemini Flash → use_count+1

---

## 📦 Blok 8 — Leaderboard + Credit History
> Agent: **Backend + Frontend**

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 8.1 | CreditTransaction modeli | `models/credit_transaction.go` | ✅ DONE | Backend |
| 8.2 | deductCredits helper + CreateAgent/Fork kredi düşme | `services/agent_service.go` | ✅ DONE | Backend |
| 8.3 | GetCreditHistory servisi | `services/agent_service.go` | ✅ DONE | Backend |
| 8.4 | GetLeaderboard servisi | `services/agent_service.go` | ✅ DONE | Backend |
| 8.5 | Credit History + Leaderboard handler'lar | `api/handlers/agent_handler.go` | ✅ DONE | Backend |
| 8.6 | Yeni rotalar (/credits/history, /leaderboard) | `api/router.go` | ✅ DONE | Backend |
| 8.7 | Wallet screen redesign (kredi gösterimi + uyarı) | `features/wallet/screens/wallet_connect_screen.dart` | ✅ DONE | Frontend |
| 8.8 | Credit History ekranı | `features/wallet/screens/credit_history_screen.dart` | ✅ DONE | Frontend |
| 8.9 | Leaderboard ekranı | `features/leaderboard/screens/leaderboard_screen.dart` | ✅ DONE | Frontend |
| 8.10 | ApiService: getCreditHistory + getLeaderboard | `shared/services/api_service.dart` | ✅ DONE | Frontend |
| 8.11 | Router: /credits/history + /leaderboard + sidebar | `app/router.dart` | ✅ DONE | Frontend |

---

---

## 📦 Blok 9 — UX v2.6 (Purchase + Auth Gates + Art + Cleanup)
> Agent: **5 parallel general-purpose agents**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 9.1 | PurchasedAgent modeli | `models/purchased_agent.go` | ✅ DONE | Monad Purchase |
| 9.2 | Agent.Price alanı | `models/agent.go` | ✅ DONE | Monad Purchase |
| 9.3 | PurchasedAgent AutoMigrate | `internal/database/db.go` | ✅ DONE | Monad Purchase |
| 9.4 | RecordPurchase / IsPurchased / SetAgentPrice servisleri | `services/agent_service.go` | ✅ DONE | Monad Purchase |
| 9.5 | RecordPurchase / GetPurchaseStatus / SetAgentPrice handler'lar | `api/handlers/agent_handler.go` | ✅ DONE | Monad Purchase |
| 9.6 | 3 yeni route: /purchase, /purchase-status, /price | `api/router.go` | ✅ DONE | Monad Purchase |
| 9.7 | sendTransaction JS köprüsü | `web/index.html` | ✅ DONE | Monad Purchase |
| 9.8 | WalletService.sendTransaction() | `shared/services/wallet_service.dart` | ✅ DONE | Monad Purchase |
| 9.9 | AgentModel.price alanı | `shared/models/agent_model.dart` | ✅ DONE | Monad Purchase |
| 9.10 | ApiService: purchaseAgent / getPurchaseStatus / setAgentPrice | `shared/services/api_service.dart` | ✅ DONE | Monad Purchase |
| 9.11 | AgentDetail: auth guard (fork/library), credit display, fork ⚡5 | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ DONE | UX Guard |
| 9.12 | CreateAgent: credit gate (⚡10 check dialog), submit ⚡10 | `features/create_agent/screens/create_agent_screen.dart` | ✅ DONE | UX Guard |
| 9.13 | Library: 2-tab (Saved/Created) + stats header | `features/library/screens/library_screen.dart` | ✅ DONE | Library Consolidator |
| 9.14 | Profile ekranı kaldırıldı (routes + sidebar) | `app/router.dart` | ✅ DONE | Library Consolidator |
| 9.15 | Store: auth-aware save, empty search state, branded loader, category resets search | `features/store/screens/store_screen.dart` | ✅ DONE | Store UX |
| 9.16 | character_data.dart: 32×32 (\_scale2x), kariteli arkaplan | `features/character/character_data.dart` | ✅ DONE | Art Director |
| 9.17 | pixel_art_painter.dart: dynamic gridSize, checkered bg, ps=width/gridSize | `features/character/pixel_art_painter.dart` | ✅ DONE | Team Leader (painter fix) |
| 9.18 | Go build doğrulaması | — | ✅ EXIT 0 | Team Leader |

---

---

## 📦 Blok 10 — Purchase UI + Creator Tools + Guild Polish + Store Badges
> Agent: **5 parallel general-purpose agents**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 10.1 | Buy butonu UI (fiyat gösterimi + Monad ödeme modal) | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ DONE | Purchase UI |
| 10.2 | Creator fiyat ayarlama (Library'den owned agent fiyatı güncelle) | `features/library/screens/library_screen.dart` | ✅ DONE | Creator Tools |
| 10.3 | AgentCard fiyat badge (store'da fiyat gösterimi) | `features/store/widgets/agent_card.dart` | ✅ DONE | Store Badges |
| 10.4 | Guild polish (üye listesi, join/leave, agent showcase) | `features/guild/screens/guild_screen.dart` + `guild_detail_screen.dart` | ✅ DONE | Guild Polish |
| 10.5 | Mini chat geçmişi (localStorage persist) | `features/agent_detail/widgets/mini_chat_widget.dart` | ✅ DONE | Chat History |

---

## 📦 Blok 11 — Performance Optimization Sprint
> Agent: **4 parallel optimizers + Team Leader**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 11.1 | PixelArtPainter: shouldRepaint + transparent-only checker + breathScale koşullu | `features/character/pixel_art_painter.dart` | ✅ DONE | Optimizer 1 |
| 11.2 | AnimationController: rarity-aware hız + static skip + RepaintBoundary | `shared/widgets/pixel_character_widget.dart` | ✅ DONE | Optimizer 2 |
| 11.3 | Store: search debounce 400ms + cacheExtent + RepaintBoundary per card | `features/store/screens/store_screen.dart` + `agent_card.dart` | ✅ DONE | Optimizer 3 |
| 11.4 | Backend: DB indexes + SELECT optimization + connection pool | `models/agent.go` + `services/agent_service.go` + `database/db.go` | ✅ DONE | Optimizer 4 |
| 11.5 | Go build doğrulaması | — | ✅ EXIT 0 | Team Leader |

---

## 📦 Blok 12 — Rating, Sort/Filter, Credit Top-up, Notifications, Onboarding ✅
> Agent: **5 parallel general-purpose agents**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 12.1 | Rating & Reviews sistemi (backend model+endpoint + frontend yıldız widget) | `models/agent_rating.go` + `services/agent_service.go` + `features/agent_detail/rating_widget.dart` | ✅ DONE | Rating Agent |
| 12.2 | Store sort dropdown (newest/popular/saves/price asc/desc/oldest) | `features/store/screens/store_screen.dart` + `services/agent_service.go` | ✅ DONE | Sort/Filter Agent |
| 12.3 | Credit top-up (MON ile kredi satın alma: 0.1/0.5/1.0/5.0 MON butonları) | `features/wallet/screens/wallet_connect_screen.dart` + `services/agent_service.go` + `config/config.go` | ✅ DONE | Credit Top-up Agent |
| 12.4 | Notification panel (sidebar zil badge + bildirim dialog + localStorage) | `shared/services/notification_service.dart` + `shared/widgets/notification_panel.dart` + `app/router.dart` | ✅ DONE | Notification Agent |
| 12.5 | Onboarding modal (ilk ziyaret → 4-adım wallet rehberi, localStorage flag) | `shared/widgets/onboarding_modal.dart` + `features/store/screens/store_screen.dart` | ✅ DONE | Onboarding Agent |
| 12.6 | Go build doğrulaması | — | ✅ EXIT 0 | Team Leader |
| 12.7 | Docker --no-cache rebuild + docker compose up | — | ✅ 3 servis UP | Team Leader |

---

## 📦 Blok 13 — Agent Detail Polish + Search Improvements + Profile + Settings ✅
> Agent: **5 parallel general-purpose agents**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 13.1 | Agent Detail: tab pill indicator + tags chips + inline similar agents | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ DONE | Detail Polish |
| 13.2 | Search recent searches (localStorage, horizontal chips, clear) | `features/store/screens/store_screen.dart` | ✅ DONE | Search Agent |
| 13.3 | Public profile sayfası (/profile/:wallet) — agent grid + stats | `features/profile/screens/public_profile_screen.dart` | ✅ DONE | Profile Agent |
| 13.4 | Settings/About ekranı + sidebar Settings NavItem | `features/settings/screens/settings_screen.dart` + `app/router.dart` | ✅ DONE | Settings Agent |
| 13.5 | Create Agent 3-adım flow (step indicator + Next/Back + validation) | `features/create_agent/screens/create_agent_screen.dart` | ✅ DONE | Create Flow Agent |
| 13.6 | Router: /settings + /profile/:wallet + imports | `app/router.dart` | ✅ DONE | Team Leader |
| 13.7 | Flutter analyze (0 error) + Docker rebuild + 3 servis UP | — | ✅ DONE | Team Leader |

---

## 📦 Blok 14 — Creator Dashboard + Multi-Filter + Compare + Achievements + Share ✅
> Agent: **5 parallel general-purpose agents**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 14.1 | Creator Analytics Dashboard (/creator) — 4 stat kart + DataTable + sidebar NavItem | `features/creator/screens/creator_dashboard_screen.dart` + `app/router.dart` | ✅ DONE | Creator Agent |
| 14.2 | Store Multi-Filter — RangeSlider fiyat + 8 tag FilterChip + active badge + AnimatedSwitcher | `features/store/widgets/filter_panel.dart` + `store_screen.dart` + `api_service.dart` | ✅ DONE | Filter Agent |
| 14.3 | Agent Compare Modal — IntrinsicHeight VS layout + dual radar + stat bars + details | `features/agent_detail/widgets/compare_modal.dart` + `agent_detail_screen.dart` | ✅ DONE | Compare Agent |
| 14.4 | Achievement Badges — 8 rozet, AchievementRow, Library Created tab entegrasyonu | `shared/widgets/achievement_badge.dart` + `features/library/screens/library_screen.dart` | ✅ DONE | Achievement Agent |
| 14.5 | Share Button — Clipboard API + SnackBar checkmark + AppBar icon | `features/agent_detail/screens/agent_detail_screen.dart` | ✅ DONE | Share Agent |
| 14.6 | Flutter analyze (0 error) + Docker rebuild + 3 servis UP | — | ✅ DONE | Team Leader |

---

## 📦 Blok 15 — Explore + Guild Battle + Collections + Profile Bio + UX Polish ✅
> Agent: **5 parallel general-purpose agents + Team Leader**
> Son güncelleme: 2026-02-24

| # | Görev | Dosya | Durum | Agent |
|---|---|---|---|---|
| 15.1 | Explore ekranı (/explore) — category tiles + tag cloud + stats overview | `features/explore/screens/explore_screen.dart` | ✅ DONE | Explore Agent |
| 15.2 | Guild Battle sistemi — stat-bazlı simüle savaş + animasyonlu sonuç modal | `features/guild/screens/guild_detail_screen.dart` + `features/guild/widgets/battle_modal.dart` | ✅ DONE | Battle Agent + Team Leader |
| 15.3 | Agent Collections — kütüphanede localStorage tabanlı klasör/koleksiyon sistemi | `features/library/screens/library_screen.dart` + `shared/services/collection_service.dart` | ✅ DONE | Collections Agent |
| 15.4 | Profil Bio/Username — wallet ekranından kullanıcı adı + bio güncelleme | `features/wallet/screens/wallet_connect_screen.dart` + backend PATCH /user/profile | ✅ DONE | Profile Agent + Team Leader |
| 15.5 | UX Polish — global keyboard shortcuts + tooltip'ler + empty state iyileştirmeleri | `app/router.dart` + `features/store/screens/store_screen.dart` | ✅ DONE | UX Agent |
| 15.6 | Go build doğrulaması + Docker recreate | — | ✅ EXIT 0 / 2 servis UP | Team Leader |

---

## ✅ Tamamlanan Bloklar
- ✅ **Blok 1** — Replicate image generation entegrasyonu (Backend, 2026-02-23)
- ✅ **Blok 2** — Store & Discovery (TrendingRow + CategorySidebar) (Frontend, 2026-02-23)
- ✅ **Blok 3** — Agent Detail (MiniChat + RadarChart + SimilarAgents + Fork) (Frontend, 2026-02-23)
- ✅ **Blok 4** — Kullanıcı Profili (Frontend, 2026-02-23)
- ✅ **Blok 5** — Backend Endpointler (trending/fork/chat/profile) (Backend, 2026-02-23)
- ✅ **Blok 6** — Blockchain Credits entegrasyonu (Backend + Frontend, 2026-02-23)
- ✅ **Blok 8** — Leaderboard + Credit History (Backend + Frontend, 2026-02-23)
- ✅ **Blok 9** — UX v2.6: Monad Purchase + Auth Gates + 32×32 Art + Library Consolidation (2026-02-24)
- ✅ **Blok 10** — Purchase UI + Creator Tools + Guild Polish + Store Badges + Chat History (2026-02-24)
- ✅ **Blok 11** — Performance Optimization Sprint (2026-02-24)
- ✅ **Blok 12** — Rating + Sort/Filter + Credit Top-up + Notifications + Onboarding (2026-02-24)
- ✅ **Blok 13** — Agent Detail Polish + Search + Profile + Settings + Create Flow (2026-02-24)
- ✅ **Blok 14** — Creator Dashboard + Multi-Filter + Compare + Achievements + Share (2026-02-24)
- ✅ **Blok 15** — Explore + Guild Battle + Collections + Profile Bio + UX Polish (2026-02-24)

> **Not:** Guild Polish sonrası backend'e `POST/DELETE /guilds/:id/join` route'ları eklendi (`guild_service.go` + `guild_handler.go` + `router.go`). Go build: EXIT 0 ✅
