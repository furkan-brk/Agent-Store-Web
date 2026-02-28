# Agent Store — v2.0 Sprint Planı

## 🎯 Hedef
Platformu MVP'den gerçek bir ürüne taşımak:
güzel AI görseller, zengin keşif deneyimi, kullanıcı profili, mini chat, fork, blockchain krediler.

---

## 📦 Blok 1 — Resim Sistemi (Replicate)
> **Öncelik: KRİTİK** — Mevcut Gemini Imagen pixel art stilini tutarsız veriyor.

### Model Seçimi
- **Primary**: `nerijs/pixel-art-xl` — pixel art için fine-tune edilmiş SDXL
- **Fallback**: Gemini Imagen 3 (Replicate başarısız olursa)

### Değişecek Dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/internal/services/replicate_service.go` | YENİ — Replicate API entegrasyonu |
| `backend/internal/services/gemini_service.go` | GenerateImage → Replicate'e yönlendir |
| `backend/internal/services/agent_service.go` | ReplicateService inject |
| `backend/config/config.go` | REPLICATE_API_KEY ekle |
| `.env` | ✅ eklendi |

### Prompt Stratejisi
```
pixel art {charType} character, {imagePrompt from Gemini},
8-bit RPG game sprite, front facing, dark background,
crisp pixel art style, vibrant colors, professional game art
```

---

## 📦 Blok 2 — Store & Discovery
> **Öncelik: YÜKSEK** — Ana landing ekranı sıkıcı, keşif zayıf.

### Yeni Özellikler
- **Trending Section** — "Bu hafta en çok kaydedilen" (6 kart, yatay scroll)
- **Kategori Sidebar** — sol tarafta icon + label, tıklayınca filtrele
- **Featured Row** — Editor's Pick / Öne Çıkan agentlar (admin belirlemiş)
- **Boş state** — arama sonucu yoksa güzel illüstrasyon + öneri

### Değişecek Dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/internal/api/router.go` | GET /api/v1/agents/trending route ekle |
| `backend/internal/services/agent_service.go` | GetTrending() metodu |
| `backend/internal/api/handlers/agent_handler.go` | TrendingAgents handler |
| `agent_store/lib/features/store/screens/store_screen.dart` | Trending + sidebar |
| `agent_store/lib/features/store/widgets/trending_row.dart` | YENİ widget |
| `agent_store/lib/features/store/widgets/category_sidebar.dart` | YENİ widget |

### Trending Algoritma
```
score = save_count * 3 + use_count * 2 + (days_since_creation < 7 ? 20 : 0)
ORDER BY score DESC LIMIT 6
```

---

## 📦 Blok 3 — Agent Detail Geliştirme
> **Öncelik: YÜKSEK** — Agent detayı çok statik, etkileşim yok.

### Yeni Özellikler
- **Mini AI Chat** — Prompt'u Gemini Flash ile yerinde test et (sağ panel)
- **Stats Radar Chart** — 5 stat için spider/radar grafik (FL Charts paketi)
- **Benzer Agentlar** — Aynı kategoriden 4 agent (alt bölüm)
- **Fork Butonu** — "Bu Agent'ı Forkla" → Create form açılır, prompt dolu gelir

### Değişecek Dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/internal/api/router.go` | POST /api/v1/agents/:id/fork, POST /api/v1/agents/:id/chat |
| `backend/internal/services/agent_service.go` | ForkAgent(), ChatWithAgent() |
| `backend/internal/api/handlers/agent_handler.go` | Fork + Chat handler |
| `agent_store/lib/features/agent_detail/screens/agent_detail_screen.dart` | Yeniden düzenle |
| `agent_store/lib/features/agent_detail/widgets/mini_chat_widget.dart` | YENİ |
| `agent_store/lib/features/agent_detail/widgets/radar_chart_widget.dart` | YENİ |
| `agent_store/lib/features/agent_detail/widgets/similar_agents_widget.dart` | YENİ |
| `pubspec.yaml` | fl_chart paketi ekle |

### Chat Akışı
```
Kullanıcı → mesaj yazar → POST /api/v1/agents/:id/chat {message}
Backend → agent prompt + kullanıcı mesajını Gemini Flash'a gönderir
→ yanıt döner → use_count +1
```

---

## 📦 Blok 4 — Kullanıcı Profili
> **Öncelik: ORTA** — Platform social kimlik için profil şart.

### Yeni Ekranlar
- **`/profile`** — Kendi profilin (JWT'den wallet)
- **`/profile/:wallet`** — Başkasının profili (public)

### İçerik
```
┌─────────────────────────────────────────────┐
│  🟣 0x1234...abcd    [WALLET_ADDRESS]        │
│  Oluşturdu: 12  │  Toplam Save: 847  │  Sıra: #3 │
├─────────────────────────────────────────────┤
│  [Oluşturulan Agentlar]  [Kütüphane]        │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐                   │
│  │   │ │   │ │   │ │   │  ...               │
└─────────────────────────────────────────────┘
```

### Değişecek Dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/internal/api/router.go` | GET /api/v1/user/profile, GET /api/v1/users/:wallet |
| `backend/internal/services/agent_service.go` | GetUserProfile() |
| `backend/internal/api/handlers/agent_handler.go` | Profile handler |
| `agent_store/lib/app/router.dart` | /profile ve /profile/:wallet route |
| `agent_store/lib/features/profile/screens/profile_screen.dart` | YENİ ekran |
| `agent_store/lib/features/profile/widgets/profile_stats_card.dart` | YENİ |

---

## 📦 Blok 5 — Backend Tamamlama
> Blok 2-4 ile birlikte geliştirilecek.

### Yeni Endpointler
| Method | Path | Açıklama |
|---|---|---|
| GET | /api/v1/agents/trending | Trending agentlar (score bazlı) |
| POST | /api/v1/agents/:id/fork | Agent forkla (yeni agent oluştur) |
| POST | /api/v1/agents/:id/chat | Mini chat (Gemini Flash) |
| GET | /api/v1/user/profile | Kendi profilim |
| GET | /api/v1/users/:wallet | Başkasının profili |

### Fork Akışı
```
POST /api/v1/agents/:id/fork
→ Orijinal agent okunur
→ "Forked from: [title]" description eklenir
→ Yeni agent oluşturulur (aynı prompt, Gemini yeni image üretir)
→ Yeni agent ID'si döner
→ use_count +1 (orijinale)
```

---

## 📦 Blok 6 — Blockchain / Credits
> **Öncelik: DÜŞÜK** — Son blok, diğerleri tamamlandıktan sonra.

### Hedefler
- Credits bakiyesi gerçek zamanlı göster (wallet bağlandıktan sonra)
- Agent oluşturma → 10 kredi düş
- Fork → 5 kredi düş
- Credits geçmişi ekranı (tx log)

### Değişecek Dosyalar
| Dosya | Değişiklik |
|---|---|
| `agent_store/lib/features/wallet/screens/wallet_connect_screen.dart` | Credits prominent göster |
| `backend/internal/services/agent_service.go` | Kredi düşme mantığı |
| `backend/internal/models/user.go` | CreditTransaction modeli ekle |

---

## 🗓️ Uygulama Sırası

```
Gün 1-2:  Blok 1 — Replicate entegrasyonu + test
Gün 3-4:  Blok 5 — Backend endpointler (trending, fork, chat, profile)
Gün 5-6:  Blok 2 — Store trending + kategori sidebar
Gün 7-8:  Blok 3 — Agent Detail (mini chat + fork + radar chart)
Gün 9-10: Blok 4 — Kullanıcı Profili
Gün 11:   Blok 6 — Credits entegrasyonu
Gün 12:   Test + deploy
```

---

## 🔑 API Keys
| Servis | Key | Kullanım |
|---|---|---|
| Gemini | .env'de ✅ | Prompt analizi (type/tags/category) + chat |
| Replicate | .env'de ✅ | Pixel art image generation |
| Anthropic/Claude | .env'de ❌ (kredi bitti) | Kullanılmıyor |

---

## 📌 Teknik Kararlar

### Paket Eklemeleri (Flutter)
- `fl_chart: ^0.69.0` — radar chart için
- Diğer bağımlılıklar mevcut

### DB Değişiklikleri (GORM AutoMigrate)
- `credit_transactions` tablosu (opsiyonel, Blok 6)
- Mevcut tablolar yeterli

### Image Boyutu
- Replicate 512×512 döndürür → base64 ~200KB
- DB'de TEXT olarak saklanır (MVP için kabul edilebilir)
