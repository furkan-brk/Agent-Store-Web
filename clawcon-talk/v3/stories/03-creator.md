# Hikâye 3 — İçerik Yaratıcısı (Zeynep)
# Slayt 7–8 · ~5 dk · TAMAMEN CANLI (en güvenli demo)

## Persona

**Zeynep**, 24 yaşında, üniversite asistanı. Akademik yazı düzenleme promptu yazdı.
3 ay önce Reddit'e koydu: 12 upvote. GitHub gist'e: 3 yıldız. Sessizlik.
Prompt kaliteli — ama "kuru metin" olarak duruyor. Görünür değil.

Agent Store'a geldi. Aynı promptu yükledi.
Ne olduğunu bilmiyordu.

## Slayt 7 — Problem Setup (60s)

**Başlık**: Hikâye 3: İçerik Yaratıcısı

Konuşma metni:
```
"Zeynep'in promptu iyi. Gerçekten iyi.
'Akademik yazıyı analiz et, yeniden yaz, atıfları düzelt.'
Ama kuru metin olarak duruyor.

Her prompt marketplace'de aynı şey: başlık, metin, kopyala.
Agent Store'da farklı bir şey var.

Promptunun bir kimliği var."
```

## Slayt 8 — DEMO (240s = 4 dk)

**Başlık**: DEMO — Karakter Sistemi

### Canlı demo adımları (4 dk bütçesi)

1. **Create Agent aç** (10s)
   - `/create-agent` → form göster
   - Konuşma: "Zeynep buraya geliyor."

2. **Prompt yaz** (15s)
   Şunu yaz (önceden hazırla, kopyala-yapıştır OK):
   ```
   Academic writing editor: analyze structure, rewrite unclear sections,
   fix citation format (APA/MLA), improve academic tone.
   Maintains author's original argument.
   ```
   - Konuşma: "Aynı prompt. Reddit'e yazdığı."

3. **Canlı preview izle** (20s)
   - Live preview panelinde karakter animasyonu başlasın
   - Claude API analiziyor: tone, alan, amaç
   - Karakter belirleniyor: **Scholar** (Araştırma / Eğitim)
   - 16×16 pixel-art sprite animasyonu
   - Konuşma: "Claude bu promptu okudu. 'Araştırma ve eğitim odaklı' dedi.
     Scholar karakteri → rarity: Uncommon."

4. **Title + açıklama ekle** (15s)
   - Title: "Academic Writing Editor"
   - Description: "Restructures academic texts, fixes citations, improves tone"
   - Konuşma: "Kısa ama net."

5. **Opsiyonel: Card Editor** (30s — varsa vakti)
   - "Edit Card" → split-view aç
   - Sol: form / Sağ: canlı kart preview
   - Bir alan değiştir → sağda anlık güncelleme
   - Konuşma: "Card Editor — ne gördükleri ne yazıldığını etkiliyor."
   - **Eğer süre darlığı varsa bu adımı atla.**

6. **Publish** (10s)
   - Publish butonuna bas → success animasyonu
   - Konuşma: "Yayınlandı."

7. **Leaderboard'a git** (20s)
   - `/leaderboard` → Zeynep'in kartını bul (veya "All Time" sırasında yeni eklenen)
   - Pixel-art karakter → Scholar badge → save count
   - Konuşma: "Artık bir karakter. Kütüphanelere ekleniyor.
     4 saatte 12 kullanıcı save etti."

8. **Public profile** (15s)
   - Zeynep'in public profile'ına git
   - Agent kartı görünsün, ratings, follower count
   - Konuşma: "Zeynep'in promptu artık bir kimlik.
     Rating alıyor. Takip ediliyor."

9. **Köprü cümlesi** (10s)
   ```
   "Üç hikâye bitti. Aynı platformda, aynı altyapıda.
   Şimdi o altyapıya bir dakika bakalım."
   ```

## Timing drill notları

- Setup: 10s
- Prompt yaz: 15s
- Preview izle: 20s
- Title + desc: 15s
- Card Editor (opsiyonel): 30s
- Publish: 10s
- Leaderboard: 20s
- Public profile: 15s
- Köprü: 10s
- **Card Editor ile TOPLAM**: ~145s demo + 60s setup = 205s = 3.4 dk ✅
- **Card Editor olmadan**: ~115s demo + 60s setup = 175s = 2.9 dk ✅ (buffer)

## Demo güvenilirliği notları

Bu demo en güvenli çünkü:
- API bağımlılığı: sadece Claude API (character detection için)
- Eğer Claude API timeout → default character "Wizard" atanır (fallback built-in)
- Publish → tam yerel DB, Monad RPC gerektirmez
- Leaderboard → sadece DB query, stabil

Failure modu yok — demo tamamen canlı yapılabilir.

## Sık sorulan sorular (S3 için)

**"8 karakter kim tasarladı?"**
→ Flutter CustomPainter ile 16×16 pixel matrisi. Renkler sistemde hardcoded.
Claude kategori belirliyor (araştırma/eğitim → Scholar), sprite sabit.

**"Rarity nasıl belirleniyor?"**
→ Prompt uzunluğu, spesifiklik, kategori nadirliği kombinasyonu.
Legendary çok nadir — üst %5 prompt'a çıkıyor.

**"On-chain ownership ne anlama geliyor?"**
→ Her published agent'ın Monad testnet'te bir kaydı var.
AgentRegistry.sol — creator wallet, content hash, timestamp.
Henüz kullanıcıya görünmüyor ama arka planda çalışıyor.

**"Başkası aynı promptu kopyalayabilir mi?"**
→ Prompt görünür (kopyalamaları için) ama ownership kayıt altında.
Gelecekte telif reward mekanizması planlanıyor.
