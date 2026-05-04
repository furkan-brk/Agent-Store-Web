# Yedek Demo Video Çekim Senaryosu

> **Hedef:** 90 saniye kayıt. Sahnede demo fail olursa anında oynatılacak.
> **Format:** mp4, 1920×1080, 30fps, **dahili ses + kısa voice-over**
> **Çekim aracı:** OBS Studio (ücretsiz) veya ShareX recording mode
> **Toplam çekim süresi:** ~30 dk (kayıt + edit + render)
> **Çekim öncesi:** `setup.ps1` çalışmış, http://localhost yeşil

---

## 🎬 Çekim öncesi hazırlık (10 dk)

### Ortam
- [ ] Tarayıcı zoom **%125**, pencere boyutu **1920×1080**
- [ ] Tarayıcı tab'ı **tek** (sadece http://localhost)
- [ ] Bookmarks bar gizli (`Ctrl+Shift+B`)
- [ ] Dev tools kapalı, console kapalı
- [ ] MetaMask popup'ı için browser pencere konumu sabit
- [ ] OBS scene: full window capture, 30fps, 8000kbps, mp4 output

### Demo state
- [ ] http://localhost yüklü, Store grid görünür
- [ ] Library'de 3-4 hazır agent var (Wizard + Artisan + Guardian önerilir)
- [ ] Demo cüzdanına 1000 kredi grant edilmiş
- [ ] Guild Master'a girilmemiş (videoda "ilk kez" gösterilecek)
- [ ] Tarayıcı history'de http://localhost'a doğru gitmek için 1-2 prefetch

### Voice-over
- [ ] Mikrofon hazır (built-in olabilir, ama harici daha iyi)
- [ ] Sessiz ortam, kayıt sırasında kapı/telefon olmasın
- [ ] Aşağıdaki script'i ezberlenmiş ya da prompt'larda hazır

---

## 🎤 Voice-over script (90 sn)

> **Tempo:** orta-hızlı, net, samimi. Her cümle bir aksiyona denk.
> **Ses:** dümdüz, monolog değil — küçük vurgu farkları olsun.

```
[00:00 — Frontend açılıyor]
"Agent Store, gamified bir AI agent marketplace. Şimdi tek bir
multi-agent akışını 90 saniyede özetleyeceğim."

[00:05 — Store grid'i pan]
"Burası store. Her kart bir agent prompt — pixel-art karakteriyle,
kategorisiyle, nadirlik kademesiyle."

[00:12 — Connect Wallet → MetaMask sign]
"Auth wallet ile. MetaMask nonce'ı imzalıyor, backend ecrecover
yapıyor, JWT dönüyor. Üç saniye."

[00:20 — Library'ye git → bir agent'a tıkla → geri çık]
"Library kütüphanem. Bir Wizard backend agent'ım var. Stats, prompt
preview, mini chat. Ama asıl ilginç olan başka — Guild Master'a geçelim."

[00:30 — Guild Master ekranı, problem yaz]
"Guild Master ekranı. Buraya problem statement yazıyorum:
'Login akışı için takım öner — backend, frontend, security.'"

[00:42 — Suggest team butonu]
"Suggest. LLM beş saniyede üç agent öneriyor: Wizard backend için,
Artisan frontend, Guardian security review. Her birinin neden seçildiği
de yazılı."

[00:55 — Add to Legend]
"Add to Legend. Ekran direkt DAG editöre geçti, üç node bağlanmış
hâlde geldi. Per-node model seçiyorum: sonnet, haiku, opus. Toplam
14 kredi."

[01:08 — Execute]
"Execute. Topological sort, sırayla yürüyor. Wizard 8 saniye,
Artisan 4, Guardian 12. Her birinin çıktısı bir sonrakine input."

[01:22 — Final output]
"Final output: login spec, kod taslağı, güvenlik kontrol listesi.
Krediler on-chain düştü. Bu OpenClaw multi-agent'ın görsel,
LLM-driven, web-native versiyonu."

[01:30 — Black]
```

---

## 🎥 Çekim adımları (15 dk)

### 1. Test çekimi (3 dk)
- 30 saniye boş video kaydet, ses + görüntü senkron mu kontrol et
- OBS audio mixer'da level kontrol et (-12 dB ile -6 dB arası ideal)

### 2. Asıl çekim — try 1
- OBS kayıt başlat (`Ctrl+Shift+R` shortcut atayabilirsin)
- 2 saniye bekle (intro pad)
- Senaryoyu uygula
- Bittiğinde 1 saniye bekle (outro pad)
- Kayıt durdur

### 3. İzle, beğenmediysen tekrar çek (5-10 dk)
- 90 saniye sınırını aşmadın mı?
- Voice-over net mi?
- Mouse hareketi sakin mi (random hareketler olmasın)?
- LLM cevap süresi kabul edilebilir mi?

### 4. Edit (5 dk)
- DaVinci Resolve (ücretsiz) veya Shotcut
- **Trim:** ilk ve son padding'i kes
- **Speed:** eğer 90 sn'yi aşıyorsa 1.1x speed (LLM beklemeleri kısaltılmış olur)
- **Audio normalize:** tek tıkla, voice-over yumuşasın
- **Export:** mp4, 1920×1080, 30fps, H.264, ~15-20 MB

### 5. Test — sahne hazırlığı
- Export'u oynatıcıda dene (VLC, Windows Media Player)
- Sahnedeki projeksiyonda test et — fontlar okunuyor mu?
- Ses sahnenin ses sisteminden çalıyor mu?

---

## 🚨 Sahne kullanım protokolü

### Demo başarısız olduğunda
1. **5 saniye bekleme**, hemen geçiş cümlesi:
   > *"Sahnede demo tanrılarını kızdırmamak için yedek videoyu izleyelim — aynı akışı 90 saniyede özetliyor."*
2. Tarayıcıdan **alt+tab**'la video player'a geç
3. Full-screen oynat
4. Bittiğinde Slayt 10'a geç (Çıkarımlar + Q&A)

### Video player nerede olsun?
- Windows Media Player veya VLC, taskbar'da pinned
- Video dosyası: `C:\Projeler\Openclaw\clawcon-talk\backup-demo.mp4`
- Çift tıklayınca direkt oynasın (default app olarak ayarla)

### Bilgisayar restart olursa?
- Video dosyasını **USB stick'e** de kopyala
- USB stick'i sahne masasında yedek olarak

---

## 📋 Çekim öncesi son kontrol

- [ ] Tarayıcı temiz state'de
- [ ] Library'de hazır agent'lar var
- [ ] MetaMask Monad testnet'te ve cüzdanda test ETH var
- [ ] Demo cüzdanı yeterli kredide (>14 cr)
- [ ] OBS audio level test edilmiş
- [ ] Voice-over script bir yerde açık (ikinci ekran veya kâğıt)
- [ ] Ofiste sessiz, telefon sessizde
- [ ] Pencere konumları sabit (MetaMask popup tutarlı yerde açılsın)

## 📋 Çekim sonrası kontrol

- [ ] mp4 oynatılabiliyor (test ettin)
- [ ] Süre 85-95 sn arası (90 hedef)
- [ ] Voice-over net (transcribe etsen anlaşılır mı)
- [ ] Görüntü 1920×1080 ve text okunabilir
- [ ] Sahne projeksiyonunda da test ettin
- [ ] USB stick'e kopyaladın

## 📋 Sahne anında

- [ ] Video player taskbar'da pinned
- [ ] `backup-demo.mp4` dosyası **iki yerde**: laptop + USB
- [ ] Sahne ses sistemi test edilmiş
- [ ] Geçiş cümlesini söyleyebiliyor musun (prova ettin)
