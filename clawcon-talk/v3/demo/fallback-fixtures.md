# Fallback Fixtures — Cached API Responses
# API down veya yavaş olduğunda kullanılacak statik veriler

## Nasıl kullanılır

1. Bu dosyayı sunum öncesi tarayıcıda aç (Notepad++ veya VS Code)
2. Demo fail olursa: pencereyi tam ekran yap, JSON veya ekran görüntüsünü göster
3. Konuşma: "Demo tanrıları bugün sabırsız — cached örneği göstereyim."

---

## S1_SUGGESTION_FIXTURE — Guild Master Yanıtı

**Input**: "Müşteri şikayetlerini kategorize et, öncelik ver ve taslak yanıt yaz"

**Beklenen çıktı (Suggestion Panel formatı)**:

```json
{
  "goal": "Müşteri şikayetlerini otomatik olarak kategorize etmek, önceliklendirmek ve taslak yanıtlar üretmek",
  "plan": [
    { "step": 1, "title": "Şikayet alın", "description": "Gelen ticket metnini alın ve ön işlemden geçirin" },
    { "step": 2, "title": "Kategori belirle", "description": "Şikayeti: çökme / faturalandırma / özellik isteği / diğer olarak sınıflandırın" },
    { "step": 3, "title": "Öncelik ata", "description": "Kritik / yüksek / orta / düşük — SLA kurallarına göre" },
    { "step": 4, "title": "Taslak yanıt üret", "description": "Kategoriye uygun empati tonunda taslak yaz" }
  ],
  "matching_agents": [
    {
      "name": "Oracle",
      "type": "oracle",
      "reason": "Yapılandırılmamış metinden kategori ve öncelik verisi çıkarmada güçlü",
      "confidence": 0.91
    },
    {
      "name": "Bard",
      "type": "bard",
      "reason": "Empati tonunu koruyarak hızlı ve tutarlı taslak yanıtlar üretiyor",
      "confidence": 0.87
    },
    {
      "name": "Strategist",
      "type": "strategist",
      "reason": "Kritik ticket'ları genel kuyruktan ayırt eder, eskalasyon kararı verir",
      "confidence": 0.78
    }
  ],
  "risks": ["LLM tutarsızlığı önemli ticket'larda manuel kontrol gerektirebilir"],
  "success_criteria": ["Ticket başına yanıt süresi %40 azalır", "Kategori doğruluğu >%85"]
}
```

**Açıklama konuşması**:
```
"Bu Guild Master'ın önerisi. Üç agent:
Oracle — kategorizasyon ve önceliklendirme, güven skoru %91.
Bard — empati tonunda taslak yanıt, %87.
Strategist — kritik ticket eskalasyonu, %78.

Elif bunları 'Save as Mission' yaptı. Yarın 1 tıkla tekrar çalışacak."
```

---

## S2_EXECUTE_FIXTURE — Legend DAG Execution Log

**Senaryo**: Content Pipeline template, 4 node, execute çalıştı

**Execution history gösterisi** (screenshot mevcutsa: `screenshots/legend-execution-running.png`):

```
✅ Çalışma #7 — 2026-05-05 09:14
   Toplam süre: 42s | Harcanan: 6 kredi

   🟢 START              [0ms]
   🟣 Kaynak Okuyucu     [8.2s] ✅ 3 kaynak işlendi
   🩷 Özetleyici         [18.4s] ✅ 847 kelime → 124 kelime özet
   ⚪ Kalite Kontrol     [7.1s] ✅ 2 tutarsızlık düzeltildi
   🔵 Formatter          [8.3s] ✅ Bülten şablonuna dönüştürüldü
   🟡 END                [42.0s]

   📊 Kredi: -6 | Başarı: 4/4 node
```

**Açıklama konuşması**:
```
"Bu Legend'ın execution history'si. 42 saniyede 4 node sırayla çalıştı.
Her node'un çıktısı görünüyor. 6 kredi harcandı — Monad testnet'te kayıt altında.
'Rerun' butonuyla yarın aynı şeyi 1 tıkla yapacak."
```

---

## S3 için fallback gerekmiyor

Create Agent demosu tamamen stabil. Claude API timeout olursa
→ default "Wizard" karakter atanır — kabul et ve devam et:
```
"Claude bu prompt için 'Wizard' dedi — Backend/Kod odaklı yorumladı.
Bu kesinlikle Academic Writer için Scholar olmayı tercih ederim,
ama sistemin mantığını görüyorsunuz: prompt → analiz → karakter."
```

---

## Genel hazırlık

- Bu dosyayı sunum öncesinde PDF olarak export et
- USB stick'e de kaydet (internet yoksa açık olsun)
- Fallback JSON'u bir tarayıcı tab'ında formatlı göster (jsonformatter.org benzeri)
