# Backup Video Recording Script V3
# 3 × 90-120 sn video · OBS veya Windows Game Bar
# D6'da çek (cmt 09 Mayıs 2026)

## Kayıt kurulumu

```powershell
# OBS Studio (önerilen):
# Çözünürlük: 1920×1080 veya 1440×900
# FPS: 60
# Bitrate: 8000 kbps (local recording)
# Format: MP4
# Ses: kapalı veya çok kısık (demo video, konuşma yok)

# Windows Game Bar alternatif:
# Win+G → Capture → Record
# Daha düşük kalite ama hızlı başlatılır
```

## Video 1: Guild Master (D1 senaryosu — Elif) · ~90s

**Dosya adı**: `guild-master-demo.mp4`

**Akış** (kamera sallama, fazla scroll yok):

```
[0:00–0:05]  Guild Master aç — boş ekran göster
[0:05–0:15]  Problem yaz: "Müşteri şikayetlerini kategorize et, öncelik ver ve taslak yanıt yaz"
[0:15–0:18]  "Find Team" butonuna tıkla
[0:18–0:35]  Spinner bekle — API düşünüyor
[0:35–0:55]  Suggestion panel: Oracle (%91) + Bard (%87) + Strategist (%78) — her biri 5–7s göster
[0:55–1:05]  "Save as Mission" tıkla
[1:05–1:15]  Mission sayfasında: başarı, yeni mission kaydedildi
[1:15–1:20]  Son kare: Mission ekranında dur, fade veya cut
```

**Kayıt öncesi hazırlık**:
- Guild Master temiz state — önceki session'ı kapat
- API sağlıklı: `curl http://localhost:8080/health`
- Demo cüzdanı bağlı

**Take sayısı**: Min 2 take al, en iyisini seç.

---

## Video 2: Legend Execute (D2 senaryosu — Mehmet) · ~120s

**Dosya adı**: `legend-execute-demo.mp4`

**Akış**:

```
[0:00–0:05]  Legend aç — boş kanvas
[0:05–0:15]  "Templates" → "Content Pipeline" → tıkla
[0:15–0:25]  Template yüklendi — 4 node görünür
[0:25–0:40]  Bir node'a tıkla → model seçici aç → haiku seç → kapat
             Drag ile yeni node ekle "Quality Check" → Summarizer'a bağla
[0:40–0:45]  Execute butonuna bas
[0:45–1:15]  Execute çalışıyor: node'lar sırayla highlight olsun
             Her node tamamlandığında küçük animasyon
             [En uzun kısım — gerçek zamanlı çek]
[1:15–1:25]  Execute tamamlandı: yeşil tik, toplam süre
[1:25–1:40]  History panelini aç: 4 node sonucu + süreleri
[1:40–1:50]  "Rerun" butonunu göster — tıklama (repeat takip etmek için)
[1:50–2:00]  Credit balance: −6 kr görünür
```

**Kayıt öncesi hazırlık**:
- Execute öncesi: backend + Monad RPC sağlıklı
- Kredi yeterli (min 50 cr — birkaç take için)
- Legend'da önceki workflow temizle

**Take sayısı**: Min 3 take al (execute bazen timeout edebilir).

---

## Video 3: Create Agent + Karakter (D3 senaryosu — Zeynep) · ~90s

**Dosya adı**: `create-agent-demo.mp4`

**Akış**:

```
[0:00–0:05]  Create Agent aç — boş form
[0:05–0:20]  Prompt yapıştır:
             "Academic writing editor: analyze structure, rewrite unclear sections,
              fix citation format (APA/MLA), improve academic tone."
[0:20–0:30]  Title: "Academic Writing Editor" yaz
[0:30–0:45]  Live preview'ı bekle: Scholar karakter animasyonu beliriyor
             Rarity badge: Uncommon
[0:45–0:55]  Publish butonuna bas → success animasyonu
[0:55–1:10]  Leaderboard'a git: yeni kart görünür, Scholar badge
[1:10–1:20]  Karta tıkla → agent detayına git → rating + save count
[1:20–1:30]  Public profile: follower count + created agents
```

**Kayıt öncesi hazırlık**:
- Create Agent formu boş
- Aynı wallet'ı kullan (demo cüzdanı)

**Take sayısı**: Min 2 take (en güvenli demo).

---

## Video kalite kontrol

Her video için:
- [ ] Minimum 1920×1080 çözünürlük
- [ ] Sıkışık/lag kare yok
- [ ] URL bar kırpılmış veya gizli
- [ ] Ses: müzik veya narration gerekmiyor — sessiz demo
- [ ] Süre: 90–120s arası (daha uzunsa kırp)

---

## Video storage

```
Kaydet:
  1. C:\Projeler\Agent-Store-Web\clawcon-talk\v3\backup-video\
  2. USB stick (backup)
  3. Google Drive / OneDrive (cloud backup)

Sunum anında:
  → 3 video ayrı VLC penceresinde hazır
  → Dock'a sabitle
  → Sunum sırasında alt+tab ile geç
```

---

## Tahmini çekim süresi

- Setup + test + 2-3 take × 3 video: ~3 saat
- D6 (Cumartesi) için planlama: sabah kurulum, öğleden sonra çekim
