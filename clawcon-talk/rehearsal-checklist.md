# Sahne Provası Checklist

> Sunumdan **1 hafta** ve **1 gün** öncesi yapılacak provalar.
> Her madde bir geçer/kalır kriteri içeriyor.

---

## 🗓 1 hafta önce — Tam dress rehearsal

### Hazırlık (30 dk)
- [ ] Boş bir oda + bir teknik arkadaş izleyici
- [ ] Sahnedeki gerçek ekipmana benzer setup (laptop + projeksiyon ya da büyük monitör)
- [ ] Gamma deck'i present mode'da aç
- [ ] `setup.ps1` çalıştırılmış, http://localhost yeşil
- [ ] Yedek video dock'ta, oynatılabilir
- [ ] Telefonda kronometre

### Prova (35 dk)
Sunumun tamamını **kesintisiz** geç. Notlar al.

**Geçer kriterleri:**
- [ ] Süre **30-37 dakika** arasında
- [ ] Slayt 8-9 (VISION pivot) — ezberlenmiş, doğal akmış
- [ ] Demo (Slayt 9) — 7 dakikada bitmiş
- [ ] Hiç slayt'ta uzun süre takılmadın (her birinde max 2 dk)
- [ ] Tutuk noktalar yok (3+ saniye bocalama olmamalı)

**Kalır kriterleri:**
- [ ] Süre 25 dk altında veya 40 dk üstünde — slayt sayısını ya da içeriği ayarla
- [ ] VISION pivot tutuk veya tonsuz — ezbere yeniden çalış (`vision-pivot-script.md`)
- [ ] Demo 7 dk üstüne çıktı — walkthrough'taki adımları kıs
- [ ] Bir slayttta 3+ dk takıldın — slaytı böl ya da kısalt

### İzleyiciden geri bildirim (15 dk)
**Sor:**
- "Hangi slayt çok kalabalık geldi?"
- "Hangi slayt boş geldi?"
- "VISION pivot anlatıyı taşıdı mı?"
- "Demo'daki en güçlü an neydi?"
- "5 saniyede özetle dersem ne anlamışsın?"

### Q&A simülasyonu (15 dk)
- [ ] `qa-prep.md`'den rastgele 5 soru soran arkadaşı dene
- [ ] Her cevap 60 sn altında
- [ ] "Cevabını bilmiyorum" cevabını en az 1 kez kullan (rahatlasın)
- [ ] Saldırgan ton scenario en az 1 deneme

---

## 🗓 1 gün önce — Mini rehearsal

### Hazırlık (15 dk)
- [ ] Sahne provası gibi setup
- [ ] Bu sefer **sesli** ama **kameraya** prova (kendini izleyeceksin)
- [ ] Telefon veya laptop kamerayla kayıt
- [ ] Yine 30-37 dk hedef

### Critical points only (20 dk)
Tam prova değil, sadece zor noktalar:

- [ ] **Açılış 30 sn** — enerji yüksek mi? Slayt 1'de duraksıyor musun?
- [ ] **Slayt 8-9 (VISION pivot)** — kelime-kelime ezber, ses tonu doğru
- [ ] **Slayt 14 + 15 (Guild Master + Legend)** — ürünü heyecanla anlatabiliyor musun?
- [ ] **Slayt 9 (Demo)** — ekran paylaşımı geçişi pürüzsüz mü?
- [ ] **Kapanış 30 sn** — kararlı son mu? Q&A daveti net mi?

### Kayıdı izle
- [ ] 1.5x hızında izle, "ee", "yani" sayısını say (5'ten az olsun)
- [ ] Vücut dili: çok kıpırdıyor musun? Eller doğal mı?
- [ ] Sesin monoton mu, vurgu farkları var mı?

---

## 🚨 Sahneye 2 saat kala — Final dry run

### Sadece kritik kontrol (15 dk)
- [ ] `setup.ps1` çalıştır → http://localhost yeşil
- [ ] MetaMask Monad testnet'te
- [ ] Demo cüzdanı yeterli kredi + test ETH
- [ ] Yedek video player'da test et (sesi ile birlikte)
- [ ] Gamma deck present mode'da çalışıyor (internet yoksa offline export?)
- [ ] Laptop tam şarj + adapter
- [ ] HDMI/USB-C adapter çantada
- [ ] Su şişesi konuşma sırasında erişilebilir

### Demo akış son provası
- [ ] Library → Guild Master → Legend execute akışı tek seferde 5 dk içinde
- [ ] LLM cevapları kabul edilebilir hızda (Guild Master <8s, her node <15s)
- [ ] Final output görünür ve okunabilir

---

## ⏰ Sahne anı — son 5 dakika

- [ ] Suyun yanında
- [ ] Laptop bağlı, ekran yansıtılıyor
- [ ] Gamma deck Slayt 1'de hazır
- [ ] Tarayıcı tab'ı açık ama henüz öne getirilmemiş
- [ ] Telefon **sessizde** ve **görünmez** yerde
- [ ] Derin nefes — 3 kez

---

## 📊 Süre dağılımı — 10 slayt versiyon (35 dk hedef)

| Slayt | Bölüm | Süre |
|-------|-------|------|
| 1 | Title + Hook | 1 dk |
| 2 | Multi-agent'ın iki yarısı | 3 dk |
| 3 | OpenClaw foundation (yoğun) | 5 dk |
| 4 | **VISION pivot** ⭐ | 2 dk |
| 5 | Agent Store stack + mapping | 5 dk |
| 6 | **Guild Master** ⭐ | 3 dk |
| 7 | **Legend DAG** ⭐ | 3 dk |
| 8 | Bridge plugin v2 + dürüstlük | 3 dk |
| 9 | **DEMO** ⭐⭐ | 7 dk |
| 10 | Çıkarımlar + Q&A | 3 dk |
| **Toplam** | | **35 dk** |

Q&A 10. slaytın içinde — sahnede ekstra 3-5 dk soru kabul edilebilir.

Eğer süre baskısı olursa öncelik:
1. Demo'dan Card Editor'ü çıkar (Adım 7'yi atla) — 1 dk kazanır
2. Slayt 3'ü hızlandır (foundation'ı tek paragrafta özetle) — 1 dk
3. Slayt 8'i kısalt (kod snippet'i atla, sadece roadmap göster) — 1 dk

---

## 🎯 Geçer/kalır final kriteri

Sunum başarılı sayılır eğer:

- ✅ Multi-agent kavramı **iki ayrı tasarım alanında ifade edildi**
- ✅ VISION pivot retorik dönüm noktasını yapabildi
- ✅ Demo en az **bir** hero an'ı gösterdi (Guild Master veya Legend)
- ✅ Q&A'da en az 3 soru aldın ve cevapladın
- ✅ Sahneden inerken kendine "evet, bunu söylemek istediğimi söyledim" dedin

Sunum başarısız sayılır eğer:

- ❌ Ana mesaj ("aynı problem, iki tasarım alanı") audience'a geçmedi
- ❌ Demo tamamen fail oldu **ve** yedek video da çalışmadı
- ❌ VISION pivot atlandı veya geçildi
- ❌ Süre 25 dk altına düştü ya da 45 dk üstüne çıktı

İlk listenin **5/5** olması ideal, **4/5** kabul edilebilir, **3/5 ve altı** retrospektif gerektirir.
