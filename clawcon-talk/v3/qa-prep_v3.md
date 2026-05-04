# Q&A Hazırlık V3
# 5 keskin cevap — 25 değil. Derinlemesine hazırla, ötesini improv yap.

## Kural

Her cevap max 45 saniye. Uzunsa kes. Soru genişletilirse "Konuşmada devam edelim" de.

---

## Q1. OpenClaw'la nasıl çalışıyor? Bugün entegre mi?

**Beklenen soru**: "Guild Master / Legend şu an OpenClaw runtime'ını kullanıyor mu?"

**Cevap** (30s):
```
"Bugün: hayır. Agent Store şu an Claude API'ye doğrudan bağlı.
OpenClaw entegrasyonu planlanıyor — RFC ile Q4 2026 milestone.

Karar bilinçli: önce ürünü valide ettim.
Kullanıcılar agent kartları seviyor mu? Guild Master faydalı mı? Kredi anlamlı mı?
Evet, evet, evet. Şimdi foundation katmanına bakıyorum.

Bu akşam RFC'yi konuşabiliriz — veya DM."
```

---

## Q2. Monetization ne? Nasıl para kazanacaksın?

**Beklenen soru**: "Kredi sistemi var ama nasıl para geliyor? Freemium mu? Subscription mı?"

**Cevap** (30s):
```
"Şu an testnet — gerçek para yok. Bu kasıtlı.

Model tartışılıyor: creator royalty (birinin agentini kullananlar kredi öder, %30 creator'a gider),
subscription premium credits, enterprise private agent hosting.

Şu anda ürünü inşa ediyorum. Monetization gelecek — ama önce değer.
Henüz karar verilmedi."
```

---

## Q3. Neden pixel-art? Gerçek görsel sistemi yerine?

**Beklenen soru**: "Pixel-art karakterler neden? AI generated image daha iyi görünmez miydi?"

**Cevap** (30s):
```
"Birkaç sebep.

Hız: pixel-art Flutter CustomPainter ile <1ms render. AI image: 2-10 saniye.

Tutarlılık: 8 karakter × 5 nadir derece = 40 variant. Kontrollü paleta.

Kimlik: kullanıcılar 'benim Wizard'ım' diyor. AI image randomize — tekrarlanamaz.

Ve açıkçası — oyun estetiği. Agent Store'u bir marketplace olarak değil,
bir dünyanın kapısı olarak kuruyorum."
```

---

## Q4. Neden Gemini de var, sadece Claude değil?

**Beklenen soru**: "Legend'da Gemini de varmış — neden iki model?"

**Cevap** (20s):
```
"Cost ve diversity.

Gemini Flash haiku gibi hızlı ve ucuz. Claude Opus güçlü ama pahalı.
Per-node seçim: kullanıcı her adım için doğru modeli seçsin.
Pipeline'da her şeyi opus yapmak saçma — kaynak israfı."
```

---

## Q5. Production'da kaç kullanıcı? Gerçekten çalışıyor mu?

**Beklenen soru**: "Bu demo değil, gerçek mi? Gerçek kullanıcı var mı?"

**Cevap** (30s):
```
"Testnet — yani gerçek Monad ama test tokeni.

Kullanıcı sayısını paylaşmıyorum ama: sunum öncesi sistemde anonim activity logları var.
Cold open'daki 09:14 session gerçek bir kullanıcı.

Production deploy: Railway backend, Vercel frontend. CI/CD çalışıyor.
Bugün deploy edilmiş kod bu.

Public beta: repo public olduktan sonra, muhtemelen bu ayın sonunda."
```

---

## Hazır olmayan sorular için

```
"Bunun için net bir cevabım yok şu an — ama düşünüyorum.
DM at, konuşalım."

ASLA: "Bilmiyorum" demek → "Bunu araştıracağım, DM at."
ASLA: 2 dakikadan uzun cevap vermek → kes, "sonra devam edelim"
```

## Konuşma kapatma cümlesi

Eğer soru bitmiyorsa:
```
"Hepinize teşekkür ediyorum. DM açık, repo yakında public.
Özellikle Guild Master → OpenClaw bridge konusunda konuşmak isteyenler bulun beni."
```
