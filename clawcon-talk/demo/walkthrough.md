# Demo Walkthrough — Agent Store UI Akışı

> Sahnede ~7 dakika. **Slayt 9** boyunca canlı çalışıyor (10-slayt versiyon).
> Sorun olursa **yedek video**'ya geç (90 sn, daha önceden kayıt).
> Tüm akış sıralı, hiç dallanma yok — risksiz tut.
>
> **Anlatı bağlamı:** Demo Agent Store standalone çalışıyor (Claude API direct).
> Bridge plugin v2 milestone — bugün dispatch katmanı yok, **mimari hazırlığı**
> gösteriliyor. Demo sırasında her hero an'da bir cümle ile bağla:
> *"Bu Guild Master cevabı, v2'de OpenClaw bindings'e dispatch olacak"* gibi.

---

## 0. Sunum öncesi 5 dakika (gizli kontrol)

- [ ] `setup.ps1` daha önce çalıştırılmış, http://localhost yeşil
- [ ] MetaMask Monad testnet'te (`chainId: 10143`)
- [ ] Demo cüzdanında en az 0.01 testMON var (sign için)
- [ ] Demo cüzdanına dev-grant ile 1000 kredi verilmiş
- [ ] Bir test agent'ı oluşturulmuş (Wizard tipi, Library'ye eklenmiş)
- [ ] Tarayıcı tab'ı temiz, console kapalı
- [ ] Yedek video oynatıcı dock'ta, ses kapalı

---

## Adım 1 — Store ekranı (45 sn)

**Yapılacak:**
1. Tarayıcıyı aç → `http://localhost`
2. Store ekranı açılıyor → agent grid

**Anlatılacak:**
> "Buraya geldiğimizde marketplace görüyoruz. Her kart bir AI prompt, prompt analizinden çıkmış pixel-art karakterle. Soldaki sidebar kategoriler, sağ üstteki search ve filter. Trending row üstte."

**Vurgu:**
- Renkler farklı karakter tipleri (Wizard mor, Strategist kırmızı vs.)
- Rarity glow border'ları (Legendary altın, Epic mor)
- "Bu hiç var olmayan promptlar değil — hepsi başka kullanıcılar tarafından paylaşılmış."

---

## Adım 2 — Wallet connect (30 sn)

**Yapılacak:**
1. Üst sağ → "Connect Wallet"
2. MetaMask popup → Sign nonce
3. JWT alındı, üst sağda kullanıcı avatarı

**Anlatılacak:**
> "Auth on-chain identity ile — email yok, password yok. Backend nonce üretiyor, MetaMask imzalıyor, ecrecover doğruluyor, JWT veriyor. 7 gün geçerli."

**Vurgu:**
- 3 saniyede tamam
- "Bu şu an Monad testnet'te — gerçek ETH değil, test ETH"

---

## Adım 3 — Library + bir agent detayı (40 sn)

**Yapılacak:**
1. Sol sidebar → Library
2. "Saved" tab'ında daha önce eklediğin Wizard agent'ı tıkla
3. Agent detail açılıyor — chat, fork, rate butonları

**Anlatılacak:**
> "Library kütüphanen — kaydettiğin ve oluşturduğun agent'lar. Bu Wizard agent'ı bir auth helper, prompt'u açıyorum (Show prompt), 380 token. Mini chat ile deneyebilirim, fork edebilirim, rate verebilirim."

**Vurgu:**
- Karakterin pixel-art animasyonu (idle float)
- "Stats" bölümünde 5 boyutlu skor
- "Bu agent başkasından kopyalanmış olsaydı 'fork of' badge'i olurdu"

---

## Adım 4 — Guild Master suggest (90 sn) ⭐ HERO MOMENT

**Yapılacak:**
1. Sol sidebar → Guild Master (Alt+G)
2. Problem statement input'una yaz:
   > *"Web app için login akışı tasarla: backend'de JWT, frontend'de form, security review"*
3. "Suggest team" butonu
4. ~5 sn LLM cevap geliyor
5. 3 agent kartı görünüyor: Wizard (backend), Artisan (frontend), Guardian (security)
6. Her kartın altında neden seçildiğine dair gerekçe

**Anlatılacak:**
> "İşte hero moment. Problem yazıyorum, AI 5 saniyede takım öneriyor. Sadece agent ID'leri değil — neden seçildiklerini ve nasıl iş bölümü yapacaklarını da yazıyor. **Bridge plugin v2'de** bu üç agent ID'si OpenClaw bindings'e dispatch olacak — yani LLM seçim **üstte**, OpenClaw deterministik routing **altta** çalışacak."

**Vurgu:**
- "Wizard backend için seçildi çünkü..." okuyup geç
- Her kartın confidence score'u
- Sağda mission önerileri (3-step plan)

---

## Adım 5 — "Add to Legend" + DAG düzenleme (60 sn)

**Yapılacak:**
1. Guild Master ekranı altındaki gold button: **"Add to Legend"**
2. Legend ekranı açılıyor, 3 agent node + start + end node hazır
3. Node'lar zaten bağlı (start → analyzer → executor → reviewer → end)
4. Her node'a sağ tık → model seç (Wizard'a sonnet, Artisan'a haiku, Guardian'a opus)
5. Üstte total credits estimate: "14 credits"

**Anlatılacak:**
> "Tek tıkla Legend'a aktarıldı, DAG hazır. Per-node model seçiyorum: backend için sonnet (3 cr), frontend için haiku (1 cr), security için opus (10 cr). Toplam 14 kredi. Krediler on-chain — gerçek ekonomi."

**Vurgu:**
- Sol sidebar'da node tipleri palette
- Üstte undo/redo, templates butonu
- "Yanlış bağlarsam preflight validator uyarır"

---

## Adım 6 — Execute + live log (90 sn) ⭐ HERO MOMENT

**Yapılacak:**
1. Üst sağ → **▶ Execute**
2. Sağda execution log paneli açılıyor
3. Sırayla node'lar yeşil oluyor:
   - Wizard 8 sn — JWT impl spec çıktı
   - Artisan 4 sn — Login form widget kodu
   - Guardian 12 sn — Security review checklist
4. Final output: birleşik markdown — spec + kod + güvenlik notları
5. Üstte "Credits used: 14" ve transaction hash

**Anlatılacak:**
> "Execute. Topological sort çalışıyor, sırayla 3 agent yürüyor. Her birinin çıktısı bir sonrakinin input'una giriyor. Final çıktı: bir login akış spec'i, kod taslağı, güvenlik kontrol listesi — hepsi tek dokümanda. Krediler on-chain düştü. **v2 bridge plugin** sonrası bu zincirin her node'u bir `sessions_spawn` çağrısına dönecek — Agent Store canvas, OpenClaw runtime."

**Vurgu:**
- Execution timeline'da node-bazlı süre
- "Bu DAG'i kaydedip rerun edebilirim, başka bir input'la çalıştırabilirim"
- "Execution history'de tüm geçmiş runlar var"

---

## Adım 7 — (Opsiyonel, vakit varsa) Card Editor (45 sn)

**Yapılacak:**
1. Library → Wizard agent'a git → "Edit Card" butonu
2. Split-view açılıyor: sol form, sağ canlı kart preview
3. Title değiştir → kart anında güncelleniyor
4. Ctrl+S → "Saved" badge

**Anlatılacak:**
> "Card Editor — agent'ın metadata'sını canlı düzenliyorum. Solda form, sağda preview. Autosave var. Ctrl+Z, Ctrl+Y geçmiş. JSON ve PNG export. OpenClaw'daki AGENTS.md'nin görsel versiyonu."

---

## Yedek video planı

**Eğer demo başarısız olursa:**
1. **5 saniye verme**, hemen yedek video'ya geç
2. Cümle: *"Demo tanrılarını kızdırmamak için yedek videoyu izleyelim."*
3. Video oynatıcı zaten dock'ta, full-screen aç
4. 90 saniyede aynı akışı gösteriyor (Adım 1-6 hızlandırılmış)
5. Video bitince Slayt 10'a geç (Çıkarımlar + Q&A)

## Sahne sonrası

```powershell
.\demo\teardown.ps1
```

## Sunum öncesi 1 hafta — doğrulama

- [ ] `setup.ps1` farklı bir makinede dene
- [ ] Adım 1-6'yı baştan sona prova et — toplam 5 dk olsun
- [ ] LLM yanıt süreleri kabul edilebilir mi (Guild Master <8s, her node <15s)
- [ ] MetaMask sign akışı problem çıkartmadı
- [ ] Yedek video kayıdı 90 sn ve aynı akışı gösteriyor
- [ ] Tarayıcı zoom level %100, console kapalı
- [ ] Demo cüzdanına yeterli test ETH + 1000 kredi
