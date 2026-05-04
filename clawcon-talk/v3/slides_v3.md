# Slides V3 — Ham Outline (Çalışma notları)
# PRESENTATION_V3.md'nin kaynak/çalışma kopyası
# Gamma'ya bu dosyayı kopyalama — PRESENTATION_V3.md'yi kullan

## Tez
Agent Store'un "multi-agent ürün katmanı" olduğunu AÇIKLAMA — GÖSTER.
3 gerçek kullanıcı senaryosu, her birinin 1 problemi, 1 çözümü, 1 demosu.

## Hikâye ekseni
Elif (solo kurucu) → Mehmet (workflow PM) → Zeynep (içerik yaratıcısı)
Her biri farklı bir özelliği temsil ediyor: Guild Master / Legend / Create Agent

## Slayt sırası ve süre bütçesi

| # | Başlık | Süre | Tip |
|---|--------|------|-----|
| 1 | Cold open — log transcript | 180s | Setup |
| 2 | Üç hikâye / üç persona | 90s | Setup |
| 3 | S1 setup — Elif, solo kurucu | 120s | Problem |
| 4 | S1 DEMO — Guild Master | 360s | Demo |
| 5 | S2 setup — Mehmet, workflow PM | 90s | Problem |
| 6 | S2 DEMO — Legend DAG | 360s | Demo |
| 7 | S3 setup — Zeynep, creator | 60s | Problem |
| 8 | S3 DEMO — Create Agent + char | 360s | Demo |
| 9 | Threading + stack diagram | 180s | Synthesis |
| 10 | Closing CTA + Q&A | 420s | Close |
| **Toplam** | | **2220s = 37dk** | |

NOT: 37 dk — biraz sıkı. Demo'larda hız kazan.
Eğer taşıyorsan S3'te Card Editor adımını atla (30sn kazanç).

## Geçiş cümleleri (slayt aralarında kullan)

**1→2**: "Bu kullanıcının adını bilmiyorum. Ama benzer üç kişiyi sizi tanıtacağım."
**2→3**: "Birincisi Elif. Önce onun dünyasına girelim."
**4→5**: "Elif ekibini kurdu. Mehmet ise ekibi nasıl çalıştıracağını çizdi."
**6→7**: "Mehmet pipeline'ını kurdu. Zeynep farklı bir şey istiyordu: görünürlük."
**8→9**: "Bu üç hikâye aynı platformda geçti. Altlarındaki ortak yapıyı gösterelim."
**9→10**: "Tek bir cümle kaldı. Ve sorularınız."

## Demo sırası özeti

| Hikâye | Demo adımları | Risk | Fallback |
|--------|---------------|------|----------|
| S1 | Guild Master → problem yaz → suggestion → Save as Mission | HYBRID | fixture JSON |
| S2 | Legend → template → drag-drop → execute | HYBRID | execute kısmı video |
| S3 | Create Agent → prompt yaz → karakter üret → publish | CANLI | - |

## Estetik notlar

- Gamma'da dark theme kullan (#0a0a0f background)
- Her slayta 1 gerçek screenshot — screenshots/ klasöründen
- Tablo ve kod blokları aktif kullan (dark bg üstünde güzel görünür)
- Avatar/karakter için kendi pixel-art sisteminizi kullan (S2 persona slide)
- AI image generation YAPMA — her slayt gerçek ekran veya minimal tipografi

## Revision log

- v3.0 (2026-05-04): İlk versiyon, V2'den tamamen bağımsız
