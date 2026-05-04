# Clawcon Sunum Materyalleri

**Konu:** Agent Store **with** OpenClaw — Multi-Agent için ürün katmanı
**Format:** 10 slayt · 35 dk · hibrit demo (canlı + yedek video) · ortalama 3.5 dk/slayt — yoğun anlatım
**Sunum aracı:** Gamma (gamma.app)
**Demo projesi:** `C:\Projeler\Agent-Store-Web` (Flutter Web + Go + Solidity)

## 🎯 Anlatı özeti

> OpenClaw multi-agent **alttaki sağlam zemini** sağlıyor: izolasyon, routing, security.
> VISION'ın stratejik tercihi: **core lean kalsın, üst katman ayrı yazılsın**.
> Agent Store **tam o üst katman**: marketplace + UX + gamification + on-chain economy.
> Bugün standalone çalışıyor (Claude API direct).
> **Bridge plugin v2** OpenClaw'a dispatch zincirini açacak — RFC Q4 2026.
>
> Anahtar mesaj: *"with OpenClaw"* — rakip değil tamamlayıcı.

---

## 📁 Dosya haritası

```
clawcon-talk/
├── README.md                          # ← buradasın
│
├── PRESENTATION.md                    # ⭐ ANA DOSYA — Gamma'ya yapıştırılacak (10 slayt)
├── vision-pivot-script.md             # Slayt 4 kelime-kelime metin (~120 sn)
├── rfc-agent-store-bridge.md          # ⭐ RFC: bridge plugin v2 spec (Q4 2026)
├── twitter-thread.md                  # 12 tweet promo thread (T-7 gün)
├── slides.md                          # ESKİ — plugin temelli ilk versiyon (deprecated)
│
├── screenshot-capture-checklist.md    # 12 gerçek UI screenshot için liste
├── qa-prep.md                         # 25+ olası soru ve hazır cevap
├── backup-video-script.md             # 90 sn yedek video çekim senaryosu
├── rehearsal-checklist.md             # 1 hafta + 1 gün + 2 saat önce kontrol
│
├── diagrams/
│   ├── README.md                      # mmdc render komutları
│   ├── *.mmd                          # 6 mermaid kaynak dosya
│   ├── *.svg                          # ⭐ 6 SVG zaten render edildi (Gamma'ya hazır)
│   ├── isolation-tree.mmd/.svg        # Slayt 3 — OpenClaw 5-boyut izolasyon
│   ├── routing-precedence.mmd/.svg    # Slayt 3 — OpenClaw 8-kademe routing
│   ├── agent-store-vs-openclaw.mmd/.svg # Slayt 5 — stack mimarisi
│   ├── layered-mapping.mmd/.svg       # Slayt 5 — feature ↔ primitive mapping
│   ├── guild-master-flow.mmd/.svg     # Slayt 6 — Guild Master akışı
│   └── legend-dag-example.mmd/.svg    # Slayt 7 — Legend DAG örneği
│
└── demo/
    ├── setup.ps1                      # Windows: flutter build + docker compose
    ├── setup.sh                       # macOS/Linux/WSL eşdeğeri
    ├── teardown.ps1                   # docker compose down
    ├── walkthrough.md                 # 7 adım UI demo (~5 dk)
    ├── expected-output.md             # Hızlı kontrol + fail planı
    └── verification-report.md         # ⭐ Setup prereq doğrulama raporu (2026-05-04)
```

---

## 🚀 Kullanım sırası

### 1. Sunum içeriğini hazırla

#### Gamma'da deck oluştur
```text
1. PRESENTATION.md'i aç
2. "🎨 GÖRSEL YÖNERGESİ" bölümünü oku — stack/katman teması
3. "🎬 SLAYTLAR BAŞLIYOR" satırından sonrasını kopyala
4. gamma.app → "Generate from text" → yapıştır → Generate
5. Gamma'da theme settings'i Görsel Yönergesi'ne göre ayarla
6. AI image generation'lar ilk geçişte yeterli — sonra screenshot'larla değiştir
```

#### Gerçek UI screenshot'ları yakala
`screenshot-capture-checklist.md`'i takip et. **Slayt 14 ve 15 için mutlaka gerçek screenshot kullan**.

#### (Opsiyonel) Mermaid diyagramlarını render et
```powershell
cd diagrams
npm install -g @mermaid-js/mermaid-cli
Get-ChildItem *.mmd | ForEach-Object {
    mmdc -i $_.Name -o ($_.BaseName + ".svg") -t dark -b transparent
}
```

### 2. Demo ortamını kur

```powershell
.\demo\setup.ps1
```

### 3. Yedek video çek

`backup-video-script.md`'i takip et.

### 4. Q&A hazırlığı

`qa-prep.md` — özellikle Q1 (anlatı), Q2.1 (bridge plugin), Q5 (zor sorular) kategorileri.

### 5. Provalar

`rehearsal-checklist.md`:
- **1 hafta önce:** Tam dress rehearsal
- **1 gün önce:** Mini rehearsal
- **2 saat önce:** Final dry run

### 6. Sahne anı

`demo/walkthrough.md` ezberinde olsun.

### 7. Sahne sonrası

```powershell
.\demo\teardown.ps1
```

---

## 📋 Sunum öncesi master checklist

### 1 hafta önce
- [ ] `PRESENTATION.md` baştan sona oku — yeni anlatı (with OpenClaw) net mi?
- [ ] `vision-pivot-script.md` Slayt 4 metnini ezberle (~120 sn)
- [ ] Gamma'da deck'i oluştur, theme settings uygula
- [ ] `screenshot-capture-checklist.md` — 12 screenshot yakala
- [ ] Mermaid diyagramları SVG'ye render et
- [ ] `demo/setup.ps1` farklı bir makinede dene
- [ ] `qa-prep.md` — özellikle Q1.1, Q1.2, Q2.1 sesli prova
- [ ] `rehearsal-checklist.md` — dress rehearsal
- [ ] `backup-video-script.md` — yedek video kaydı

### 1 gün önce
- [ ] Demo cüzdanı: 0.01+ testMON, 1000 kredi
- [ ] Tarayıcı tab'ları temiz, MetaMask Monad testnet'te
- [ ] Yedek video oynatıcı dock'ta
- [ ] Sahne ekranında deck'in nasıl göründüğünü test et
- [ ] `rehearsal-checklist.md` — 1 gün önce mini rehearsal

### Sahne anı
- [ ] `demo/setup.ps1` final çalıştırma
- [ ] Demo akış son provası
- [ ] Laptop tam şarj + adapter
- [ ] HDMI/USB-C adapter
- [ ] Yedek video USB stick'te de var

---

## 🎯 Sunum hedefleri

1. **OpenClaw multi-agent'ı foundation olarak konumlandırmak** (Bölüm 1, ~7 dk)
2. **VISION'ın "core lean, üst katman ayrı" pozisyonunu pivot olarak kullanmak** (~60 sn, kritik)
3. **Agent Store'u OpenClaw'ın üstündeki ürün katmanı olarak sunmak** (Bölüm 2, ~10 dk)
4. **Bridge plugin v2 milestone'unu net açıklamak** (~2 dk)
5. **Canlı demo ile Guild Master + Legend'ı göstermek** (~5 dk)
6. **Tamamlayıcılık vurgusu — rakip değil with-OpenClaw**

## 📡 Sunum sonrası

- [ ] Gamma deck'i public link olarak paylaş
- [ ] Agent Store repo'sunu public yap
- [ ] **Bridge plugin RFC açma** (`clawhub.ai/rfc/agent-store-bridge`)
- [ ] Blog yazısı: *"Building a product layer on OpenClaw multi-agent"*

## ⚠️ Anlatı tutarlılığı kontrolü

Her slaytta kontrol et:
- ✅ Agent Store **tamamlayıcı** olarak sunuluyor mu? (rakip değil)
- ✅ OpenClaw'a karşı eleştirel ton var mı? (olmamalı)
- ✅ Bridge plugin gerçekçi mi? (v2 milestone, RFC açılacak — bugün yok)
- ✅ "with OpenClaw" mesajı her slaytta hissediliyor mu?
- ✅ Stack şeması motifi tutarlı mı? (alt-orta-üst katman)

## 🔗 Plan referansı

Bu materyaller şu plana göre üretildi:
`C:\Users\Furkan Berk\.claude\plans\bana-team-agent-ile-hidden-turing.md`

İlk versiyon (plugin-temelli) `slides.md` dosyasında.
İkinci versiyon (framework vs ürün karşılaştırması) `git log`'da.
**Mevcut versiyon: "with OpenClaw" — Agent Store üst katman.**
