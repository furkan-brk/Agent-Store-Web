# Screenshot Checklist V3
# 12 PNG — her biri PRESENTATION_V3.md'de [SCREENSHOT: dosya.png] ile referans veriliyor

## Hazırlık

```powershell
# Docker çalışıyor olsun
cd C:\Projeler\Agent-Store-Web
docker compose up -d

# Demo cüzdanı bağlı, kredi dolu
# Tarayıcı: 1440×900 (minimum) ya da 1920×1080 zoom %100

# Screenshot aracı (tercih sırası):
# 1. Windows Snipping Tool (Win+Shift+S) → kırp → PNG kaydet
# 2. ShareX → tam region seç → PNG
# 3. Browser F12 → device toolbar → screenshot
```

---

## Çekilecek 12 Screenshot

### Slayt 1 — Cold open
- [ ] **`store-grid-overview.png`**
  - Store ana sayfası tam görünüm
  - Agent grid + sol sidebar + trending row
  - Birkaç agent kartı → pixel-art karakterler görünür olsun
  - Kaynaktan: `http://localhost`

### Slayt 2 — Persona trio
- [ ] **`persona-trio-pixel-art.png`**
  - 3 farklı agent kartı yan yana (Wizard + Oracle + Bard veya Scholar)
  - Agent kart grid'den 3 kart seç, ekrana sığsın
  - Alternatif: 3 farklı ayrı karakter ekran görüntüsünü collage et (Figma/Paint)
  - NOT: Bu slayt için gerçek screenshot yerine minimal bir 3-sütun grid de yeterli

### Slayt 3 — S1 setup
- [ ] **`guild-master-empty.png`**
  - Guild Master arayüzü, boş state
  - Input area görünür, "Find Team" butonu
  - Kaynaktan: `http://localhost/guild-master`

### Slayt 4 — S1 demo (2 screenshot)
- [ ] **`guild-master-suggestion.png`**
  - Suggestion panel açık
  - 3 agent önerisi + reason + confidence chip'leri
  - "Save as Mission" butonu görünür
  - Kaynaktan: Demo'yu canlı çalıştır, suggestion gelince screenshot

### Slayt 5 — S2 setup
- [ ] **`legend-canvas-template.png`**
  - Legend kanvası — "Content Pipeline" template yüklü
  - 4-5 node görünür, bağlantılar çizili
  - Model seçici bir node'da açık (haiku/sonnet seçenekleri)
  - Kaynaktan: `http://localhost/legend` → Templates → Content Pipeline

### Slayt 6 — S2 demo (2 screenshot)
- [ ] **`legend-execution-running.png`**
  - Execute çalışırken: progress bar + node'ların renk değişimi
  - Kaynaktan: Execute'e bastıktan 2-5 saniye sonra
- [ ] **`legend-execution-history.png`**
  - Execution history paneli açık
  - Tamamlanan çalışma: her node için süre + status + Rerun butonu
  - Kaynaktan: Execute tamamlandıktan sonra

### Slayt 7 — S3 setup
- [ ] **`create-agent-form.png`**
  - Create Agent formu boş/kısmen dolu
  - Prompt area görünür + character preview panel (sağ taraf)
  - Kaynaktan: `http://localhost/create-agent`

### Slayt 8 — S3 demo (2 screenshot)
- [ ] **`create-agent-live-preview.png`**
  - Prompt yazılmış, Scholar karakter (veya herhangi bir karakter) live preview'da
  - Pixel-art animasyonu + rarity badge görünür
  - Kaynaktan: Prompt yapıştır → karakter belirlendikten hemen sonra
- [ ] **`leaderboard-screen.png`**
  - Leaderboard tam görünüm
  - En az 3-4 agent kartı, altın vurgu + pixelart karakterler
  - Kaynaktan: `http://localhost/leaderboard`

### Slayt 9 — Stack collage
- [ ] **`agent-store-architecture-collage.png`**
  - MANUEL OLUŞTUR (Figma / Excalidraw / Paint)
  - Slayt 9'daki text diagram görselleştirmesi
  - 3 katman: User (üst) → Agent Store Core (orta) → Go + Monad + DB (alt)
  - Guild Master + Legend + Create Agent (yan yana, Agent Store katmanında)
  - Renk: mor + amber + sade dark bg
  - Boyut: 1200×600 minimum

---

## Kalite kontrol

Her screenshot için:
- [ ] Minimum 1200px genişlik
- [ ] Tarayıcı URL bar kırpılmış (gizlilik + estetik)
- [ ] Pixel-art karakterler net görünüyor (zoom edilebilir)
- [ ] Dark theme tutarlı (Gamma dark bg ile uyumlu)
- [ ] Kişisel bilgi / wallet address / gerçek email görünmüyor

## Dosya isimlendirme

Yukarıdaki isimler kesin — PRESENTATION_V3.md onları referans alıyor.
`screenshots/` klasörüne kaydet.
Gamma'ya yüklerken slayt bazında "Replace image" ile doğru slayta ekle.

## Tahmini süre

- Basit screenshot'lar (store, legend, guild): ~20 dk (4 × 5 dk)
- Demo çalıştırma + capture: ~60 dk (demo ortamı kur + her demo'yu çalıştır)
- Architecture collage: ~45 dk (Figma/Excalidraw'da)
- **Toplam**: ~2.5–3 saat (D2'de yap)
