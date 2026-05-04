# Hikâye 1 — Solo Kurucu (Elif)
# Slayt 3–4 · ~7 dk · HYBRID demo

## Persona

**Elif**, 29 yaşında, SaaS kurucu. Küçük ekip (3 kişi), B2B proje yönetim aracı.
Müşteri sayısı artıyor → haftalık destek ticket'ı: 60+.
Hepsine bakan: Elif. Haftada 8 saat yalnızca ticket'lara gidiyor.

ChatGPT'yi denedi — her seferinde bağlamı tekrar anlatmak zorunda.
Multi-agent framework'leri okudu — routing config göz korkutucu.
"Sadece doğru kişiyi bul" diyor.

## Slayt 3 — Problem Setup (120s)

**Başlık**: Hikâye 1: Solo Kurucu

Konuşma metni:
```
"Elif gerçek bir kullanıcı tipi. İsmini değiştirdim, senaryoyu değiştirmedim.

SaaS kurucu. 3 çalışan. Müşteri desteğini kendisi yapıyor.
Haftada 60 ticket: çökme bildirimi, faturalandırma sorusu, özellik isteği.
Hepsini okuyor, etiketliyor, önceliklendiriyor, taslak yanıt yazıyor.

Multi-agent biliyor. Ama kim, hangi ajan, nasıl? Bunları bilmiyor.
Ve öğrenmeye vakti yok.

Guild Master'ı açtı. Şunu yazdı."
```

## Slayt 4 — DEMO (360s)

**Başlık**: DEMO — Guild Master

### Canli demo adımları (6 dk bütçesi)

1. **Aç** (10s)
   - Tarayıcıya git: `http://localhost/guild-master`
   - Göster: temiz, boş arayüz

2. **Problem yaz** (15s)
   - Text area'ya yaz: `"Müşteri şikayetlerini kategorize et, öncelik ver ve taslak yanıt yaz"`
   - "Find Team" butonuna bas

3. **AI analiz** (5–15s bekleme)
   - "Analiz ediyor..." → spinner göster
   - Konuşma: "5 saniye içinde yanıt gelmezse devam edeceğim."

4. **Suggestion panelini aç** (60s)
   - Goal: ne yapılacak
   - Plan: adımlar
   - Matching agents: Oracle + Bard + Strategist
   - Her biri için: reason + confidence chip
   - Konuşma: "Oracle veri analizi yapıyor — ticket etiketleme güçlü.
     Bard iletişim tone'u kuruyor — taslak yanıt.
     Strategist eskalasyon kararı veriyor."

5. **"Save as Mission"** (15s)
   - Butona bas → Mission sayfasına redirect
   - Konuşma: "Elif bunu bir Mission yaptı. Yarın 1 tıkla tekrar."

6. **Köprü cümlesi** (15s)
   ```
   "Elif problem yazdı → AI doğru ekibi seçti → kayıt altına aldı.
   Routing config yok. Agent yazma yok. 90 saniye.

   Mehmet'e geçelim — o ekibi seçmekle değil, çalıştırmakla ilgileniyor."
   ```

### Fallback senaryosu (API down ise)

```
"Demo tanrıları bugün sabırsız — cached örneği gösterelim."
→ demo/fallback-fixtures.md içindeki S1_SUGGESTION_FIXTURE'ı aç
→ JSON'u tarayıcıda göster veya fixture'ı önceden açık tut
→ Suggestion panelini ekrana yapıştır
```

## Timing drill notları

- Problem yazma: max 15s (önceden ezberle)
- API bekleme: max 15s (daha fazlası = fallback'e geç)
- Suggestion panel açıklama: max 90s (3 agent, her biri 30s)
- Save as Mission: 15s
- Köprü: 15s
- **TOPLAM**: ~150s demo + 120s setup = 270s = 4.5 dk (buffer var)

## Sık sorulan sorular (S1 için)

**"Guild Master ne kadar kredi harcıyor?"**
→ Suggest endpoint: 1-3 kredi (model seçimine göre). Mission oluşturma: 0.

**"Save as Mission ne demek tam olarak?"**
→ Guild Master çıktısı (goal + plan + agents) Mission objesine dönüşüyor. Daha sonra Manuel veya Legend DAG üzerinde çalıştırılabilir.

**"Suggestion doğru mu? Hallüsinasyon var mı?"**
→ Claude agent profillerini prompt'tan analiz ediyor. Aynı problem için tutarlı öneriler üretiyor. Yanlış takım önerirse kullanıcı override edebilir.
