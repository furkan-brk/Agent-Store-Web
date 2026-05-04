# Slayt 4 — VISION Pivot Konuşma Metni

> **Toplam süre:** ~120 saniye (9:00 — 11:00)
> **Stil:** Doğaçlama YOK. Bu geçiş sunumun en kritik anı; kelime-kelime ezberle.
> **Tempo:** Slayt 4'te **dur**. Quote'u sessizce göster, 3 saniye sus, sonra konuş.
> **Vurgu kelimeleri:** **kalın** olanlar — yüksek/yavaş söylenecek.
> **NOT:** 22-slayt versiyonundaydı Slayt 8'di. 10-slayt sıkıştırılmış versiyonda Slayt 4.

---

## SLAYT 4 — VISION quote (120 sn)

> *(Slayt geçer. Quote ekranda. 3 saniye sessizlik. Seyirci okusun.)*

"Buraya kadar — Slayt 3'te — size OpenClaw'ın multi-agent zeminini gösterdim. Per-agent izolasyon, deterministik routing, security primitif'leri. Sağlam, predictable, framework-grade.

Muhtemelen bazılarınız şunu düşünüyor:

*'Tamam, motor sağlam. Peki son kullanıcı bunu nasıl deneyimliyor? Marketplace nerede? Gamification? Cüzdanla giriş? Onboarding?'*

Bu çok doğal bir soru — modern bir AI agent ürününün buna ihtiyacı var.

OpenClaw bu konuda **çok net** bir tasarım kararı vermiş. VISION dokümanından:

> *(Quote'u SESLİ oku, vurguyla:)*

*'What we will not merge: Agent-hierarchy frameworks, marketplace orchestration, heavy UX layers — **as a default architecture**.'*

> *(Tekrar dur. 2 saniye.)*

Üç kelimeye dikkat: ***'as a default architecture'***.

VISION 'son kullanıcı UX'ini reddetmiyor' — sadece diyor ki **core'a koymayacağız, üst katman ayrı yazılsın**.

Ben de yazdım. Adı **Agent Store**. OpenClaw'ın **üstüne** kurulan modern ürün katmanı.

> *(Slayt 5'e geçerken son cümle:)*

VISION beni **tamamlayıcı** olmaya yönlendirdi. Şimdi nasıl tamamladığımı görelim."

---

## Tempo notları

- **"motor sağlam"** — vurgu yumuşak, övücü ton; OpenClaw'ı küçümsemeyecek
- **"son kullanıcı bunu nasıl deneyimliyor"** — sahici merak tonu, retorik değil
- **Quote'u okurken 'as a default architecture' kısmı yavaşlasın.**
- **"reddetmiyor"** — netleştirici ton, "core'a koymayacağız" cümlesinden ayır
- **"üstüne"** — vurguyla söyle, stack şeklini hatırlat
- **"tamamlayıcı"** — ana sözcük, ezberi buradan başlat
- **Son cümlede slayda geçişi senkronize et.** "Görelim" derken Slayt 5 (Agent Store stack) ekrana gelmeli.

## Eğer süre baskısı olursa (kısa versiyon — 40 sn)

> "VISION.md diyor ki: marketplace orchestration ve UX katmanını core'a koymayacağız — **as a default architecture**. Yani 'ayrı bir katman olarak yaz' diyor. Ben de yazdım. Adı Agent Store. OpenClaw'ın üstüne, son kullanıcının arayüzü olarak. Şimdi nasıl tamamladığımı görelim."

## Q&A: Olası eleştirilere hazır cevaplar

### "Niye direkt OpenClaw plugin'i değil?"

> "Plugin de yapardım. Hatta v2 milestone'um tam olarak bu — bridge plugin. Ama Agent Store önce standalone gelişti çünkü on-chain economy, Flutter Web build pipeline'ı, Postgres schema gibi şeyler plugin'in tek başına taşıyamayacağı boyutlarda. Plugin formu Agent Store'un dispatch katmanı olacak — Agent Store'un kendi backend'i ana yer."

### "Bugünkü Agent Store OpenClaw'ı kullanıyor mu?"

> "Standalone çalışıyor — Claude API'yi doğrudan çağırıyor. Bu sunumda bunu açıkça söyledim. Bridge plugin v2 hedefim, RFC açılacak. Bugün **mimari hazırlığını** gösteriyorum, **yarın** dispatch çalışacak."

### "Bu OpenClaw'la rakipleşir mi?"

> "Asla. Agent Store OpenClaw'ın multi-agent'ı **olmadan** anlamsız. Marketplace'i de izolasyon olmazsa enterprise için kullanılamaz. Birlikte tam ürün: OpenClaw orchestration + Agent Store UX. İkisi de var olmalı."

### "VISION'ı çiğniyor musun?"

> "VISION'ın söylediği tam olarak şu: **'as a default architecture'**. Yani core'a koymayalım. Ayrı bir ürün/katman olsun. Ben tam o yolu izledim. Agent Store opt-in, kurulmazsa OpenClaw etkilenmiyor. Bu **felsefenin yaşatılması**, çiğnenmesi değil."

### "Hibrit mı, OpenClaw'a tam taşıyacak mı?"

> "Hibrit kalacak. Agent Store'un kendi backend'i (Go microservices, Postgres, on-chain contracts) kalır — gamification ve economy oraya bağlı. Sadece kritik orchestration adımları (per-agent isolation, sandbox, auth-profile) OpenClaw'a delege edilir. İki katman arası net çizgi: data + UX Agent Store, isolation + dispatch OpenClaw."

---

## Prova kontrol listesi

- [ ] Quote'u kâğıttan okumadan söyleyebiliyorum
- [ ] "as a default architecture" vurgusu doğal duruyor
- [ ] "tamamlayıcı" ana sözcüğü vurguyla çıkıyor
- [ ] OpenClaw'ı **küçümsemiyor** veya **eleştirmiyorum** ton açısından
- [ ] Slayt 3 → 4 → 5 geçişleri konuşmayla senkron
- [ ] En az 3 Q&A cevabını sesli prova ettim
