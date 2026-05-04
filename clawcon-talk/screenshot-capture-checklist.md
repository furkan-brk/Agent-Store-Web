# Gerçek UI Screenshot Yakalama Listesi

> **Neden bu liste?** Gamma'nın AI image generation'ı **gerçek Agent Store UI'ını yapamaz** — sadece o tarzda mockup üretir. Sahnedeki güvenilirlik için **gerçek ekran görüntülerini kendin yakala**, Gamma'da "Replace image" ile koy.
> Toplam: 12 screenshot · ~15 dk yakalama süresi

---

## Ön hazırlık (5 dk)

- [ ] `setup.ps1` çalıştırılmış, http://localhost yeşil
- [ ] MetaMask Monad testnet'te (chainId 10143)
- [ ] Demo cüzdanına 1000 kredi grant edilmiş
- [ ] Library'de en az 3-4 agent var (farklı karakter tipleri: Wizard, Artisan, Guardian önerilir)
- [ ] Tarayıcı zoom **%125** (slayt projeksiyon için — text okunur olsun)
- [ ] Tarayıcı tab'ı temiz, console kapalı, dev tools kapalı
- [ ] Pencere boyutu **1920×1080 veya 16:9 oranında** (Gamma slayt aspect ratio'sıyla uyumlu)
- [ ] Screenshot tool: Windows `Win+Shift+S` veya ShareX (önerilen — pencere yakalama daha temiz)

---

## Yakalanacak screenshot'lar

### S01 — Store ekranı (Slayt 10)

**Yapılacak:**
- Store ekranı, agent grid görünümü
- Sol sidebar'da kategoriler görünüyor
- En az 6-8 agent kart görünür durumda (farklı karakter tipleri ve nadirlikler)
- Trending row üstte aktif

**Özen:**
- Legendary ve Epic nadirlikteki kartlar görünsün (altın/mor glow border)
- En az bir Wizard, Artisan, Guardian karakter tipi kapsama girsin

**Dosya:** `screenshots/01-store-grid.png`

---

### S02 — Wallet connect modal (Slayt 13)

**Yapılacak:**
- Connect Wallet butonu tıklandı
- MetaMask popup'ı görünür (browser'ın sağ üstünde)
- "Sign message" prompt'u görünür durumda
- Arka planda Agent Store ekranı blurlu/dimli

**Özen:**
- MetaMask popup'ında Monad testnet badge görünsün
- Account address ilk-son karakterleri görünür (orta hash kısımları censoredsa daha iyi)
- Tek bir clean shot — yarım açılmış popup OLMASIN

**Dosya:** `screenshots/02-wallet-connect.png`

---

### S03 — Agent detail (alt görsel, Slayt 16)

**Yapılacak:**
- Bir Wizard veya Artisan agent detay sayfası
- Karakter pixel-art animasyonu görünür durumda
- Stats radar chart aktif
- Mini chat panel açık (boş veya bir mesaj yazılmış)

**Özen:**
- Prompt preview kısmı görünsün (`Show prompt` veya truncated state)
- "Add to Library" / "In Library" butonu net
- Rating yıldızları görünsün

**Dosya:** `screenshots/03-agent-detail.png`

---

### S04 — Library (alt görsel, Slayt 16)

**Yapılacak:**
- Library ekranı, "Saved" tab aktif
- 4-6 agent kart grid
- "Created" tab'ına geçiş ipucu (badge sayıları)

**Dosya:** `screenshots/04-library.png`

---

### S05 — Card Editor split-view (Slayt 16, ikincil)

**Yapılacak:**
- Card Editor açık, sol formda 2-3 alan dolu
- Sağda canlı preview kart pixel-art ile render edilmiş
- Üstte sync status badge görünür ("Saved" veya "Saving...")

**Özen:**
- Undo/Redo butonları toolbar'da görünsün (state'leri belli olsun)
- Form section'lardan en az birinde değişiklik yapılmış olsun (preview canlı güncellemesini göstersin)

**Dosya:** `screenshots/05-card-editor.png`

---

### S06 — Guild Master input (Slayt 14, hero) ⭐

**Yapılacak:**
- Guild Master ekranı
- Problem statement input'una yazılmış: *"Web app için login akışı tasarla: backend'de JWT, frontend'de form, security review"*
- "Suggest team" butonu vurgulu (hover state ya da gold glow)

**Özen:**
- Boş ekran değil — text yazılmış olsun
- Cevap **henüz gelmemiş** olsun (henüz button basılmadı)

**Dosya:** `screenshots/06-guild-master-input.png`

---

### S07 — Guild Master suggest cevap (Slayt 14, hero) ⭐⭐

**Yapılacak:**
- Yukarıdaki problem'e LLM cevabı dönmüş
- 3 agent kartı görünür (Wizard, Artisan, Guardian)
- Her birinin altında neden seçildiği (rationale) görünür
- "Add to Legend" gold button altta vurgulu

**Özen:**
- Mission önerisi (3-step plan) görünsün
- Cevap full görünsün — kesik olmasın

**Dosya:** `screenshots/07-guild-master-suggest.png`

---

### S08 — Legend boş canvas (Slayt 15, ikincil)

**Yapılacak:**
- Legend ekranı yeni workflow ile açılmış (Blank template)
- Sol sidebar'da node palette
- Üst toolbar'da Templates, Save, Execute butonları
- Canvas boş

**Dosya:** `screenshots/08-legend-empty.png`

---

### S09 — Legend dolu DAG (Slayt 15, hero) ⭐

**Yapılacak:**
- Legend canvas'ta tam workflow çizilmiş:
  - Start node (yeşil)
  - 3 agent node (Wizard mor, Artisan pembe, Guardian gri) — bağlanmış
  - End node (altın)
- Her node'da model badge görünür (sonnet/haiku/opus)
- Üstte "Total: 14 credits" görünür
- Sağ panel açık (execution log için yer var ama henüz çalışmıyor)

**Özen:**
- Bağlantı çizgileri net (hover state'siz, temiz)
- Node renkleri parlak olsun

**Dosya:** `screenshots/09-legend-dag.png`

---

### S10 — Legend execution running (Slayt 15, ikincil)

**Yapılacak:**
- DAG çalışıyor: bir node "running" state'inde (pulse/glow animation)
- Önceki node'lar yeşil (tamamlanmış)
- Sağ panelde execution log akıyor (timestamp'lar görünür)

**Özen:**
- Animation'ı dondurmak için snipping tool'un quick capture'ı
- Veya bir frame'de pulse durumu yakalanmış olsun

**Dosya:** `screenshots/10-legend-running.png`

---

### S11 — Legend final output (Slayt 21, hero demo)

**Yapılacak:**
- DAG bitti, tüm node'lar yeşil
- Final output panel açık, markdown render edilmiş cevap görünüyor
- Üstte "Credits used: 14" + tx hash kısa gösterimi
- Execution time görünür ("32s")

**Dosya:** `screenshots/11-legend-final.png`

---

### S12 — Side-by-side comparison (Slayt 17, opsiyonel)

**Yapılacak:**
- Bu screenshot DEĞİL — `diagrams/agent-store-vs-openclaw.mmd`'i mmdc ile SVG'ye render et
- Mermaid SVG'yi Gamma'da kullan

```powershell
cd C:\Projeler\Openclaw\clawcon-talk\diagrams
mmdc -i agent-store-vs-openclaw.mmd -o agent-store-vs-openclaw.svg -t dark -b transparent
```

**Dosya:** `diagrams/agent-store-vs-openclaw.svg`

---

## Yakalama sırası önerisi

Workflow odaklı sırayla yakala (her ekrana sadece bir kez girmen yeterli):

1. **Store sayfası** → S01
2. **Connect wallet** → S02 (bu sahneyi atlama, MetaMask popup gerçek olsun)
3. **Library** → S04
4. **Library'den bir agent'a tıkla** → S03 (Agent Detail)
5. **Detail'da Edit Card butonuna bas** → S05 (Card Editor)
6. **Sol sidebar → Guild Master** → S06 (input yazılı, cevap yok)
7. **Suggest team butonuna bas, cevap gelsin** → S07
8. **Add to Legend** → S08 olmaz çünkü dolu gelir; önce S09'u yakala
9. **DAG hazır** → S09
10. **Execute** → bir node çalışırken yakalama yap → S10
11. **Tamamlandığında** → S11
12. **Mermaid SVG render** → S12

---

## Gamma'ya yerleştirme

Her screenshot'u ilgili slayta:

1. Gamma'da slayt seç
2. Otomatik üretilmiş görsele tıkla → "Replace image" → Upload
3. `screenshots/0X-name.png` dosyasını seç
4. Gamma görseli slayta sığacak şekilde otomatik resize eder
5. Gerekirse "Image fit" ayarını "Cover" yerine "Contain" yap (UI screenshot'larında metin kesilmesin)

## Hangi slayt hangi screenshot (10-slayt versiyon)

| Slayt | İçerik | Screenshot/Diagram |
|-------|--------|---------------------|
| 1 — Title | Layered stack diagram | (Gamma AI yeterli) |
| 2 — İki yarı | Split engine/product | (Gamma AI yeterli) |
| 3 — OpenClaw foundation | Stack + 8-tier tree + JSON | `routing-precedence.svg` + `isolation-tree.svg` |
| 4 — VISION pivot | Quote | (Gamma AI yeterli) |
| 5 — Agent Store stack | Architecture + mapping | `agent-store-vs-openclaw.svg` + `layered-mapping.svg` |
| 6 — **Guild Master** ⭐ | LLM team selector | **S06 + S07** (gerçek UI) |
| 7 — **Legend DAG** ⭐ | Visual workflow | **S08 + S09 + S10** (gerçek UI) + `legend-dag-example.svg` |
| 8 — Bridge plugin | Architecture + roadmap | `guild-master-flow.svg` veya custom |
| 9 — **DEMO** ⭐⭐ | Live walkthrough backdrop | S01 + S07 + S09 (3'lü grid) |
| 10 — Closing | Final stack + URLs | (Gamma AI yeterli) |

**Hero slaytlar (mutlaka gerçek screenshot):** 6, 7, 9
**SVG diyagram slaytları:** 3, 5, 7, 8 (zaten render edildi `diagrams/*.svg`)
**Gamma AI yeterli:** 1, 2, 4, 10

## Backup plan: AI mockup yeterli mi?

Eğer screenshot yakalama zamanın yoksa:

1. Gamma'nın AI üretimini olduğu gibi bırak (slayt 10, 13 için kabul edilebilir)
2. Slayt 14 (Guild Master) ve 15 (Legend) için **mutlaka gerçek screenshot kullan** — bunlar hero slaytları, audience'a "ürün gerçek" mesajını vermeli
3. Slayt 17 (karşılaştırma) için Mermaid SVG (zaten var)

## ShareX kullanıyorsan

Önerilen ShareX preset:
- **Capture mode:** Active window (or region)
- **After capture:** Save to `C:\Projeler\Openclaw\clawcon-talk\screenshots\`
- **File naming:** `%y-%mo-%d_%h-%mi-%s.png` → sonra manuel rename
- **Image effects:** None (UI net görünmeli, blur yok)
- **DPI:** Native (zoom %125'te yakaladığın için ek scale yapma)
