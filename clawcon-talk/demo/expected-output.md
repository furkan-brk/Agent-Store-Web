# Demo — Beklenen Akış Özeti

`walkthrough.md`'deki sahne adımlarının özet versiyonu. Sunum öncesi son kontrol için.

## Hızlı kontrol listesi

```text
[ ] http://localhost yeşil           → Store grid görünüyor
[ ] Connect Wallet → MetaMask → JWT  → 3 saniyede tamam
[ ] Library → 1+ agent kayıtlı       → Wizard veya başka tip
[ ] Guild Master suggest             → 5-8 sn cevap, 3-5 agent
[ ] "Add to Legend"                  → DAG ekranı, node'lar hazır
[ ] Execute                          → 25-40 sn toplam, final output
[ ] Credits düştü                    → Üstte yeni bakiye
```

## Toplam süre

- Adım 1-3 (Store + Wallet + Library): ~2 dk
- Adım 4-5 (Guild Master + Legend setup): ~2.5 dk
- Adım 6 (Execute): ~1.5 dk
- **Total:** ~5 dk

## Eğer LLM yavaşsa

`.env`'de model değiştir:
- `GEMINI_MODEL=gemini-2.0-flash-exp` (en hızlı)
- veya `CLAUDE_MODEL=claude-3-5-haiku-latest`

Ama opus seçilen demo node'unu **mutlaka** sonnet'e çek — opus 30+ saniye sürebilir, sahne için çok uzun.

## Sahne fail moduna geçiş cümlesi

Her şey hazır olsun — eğer demo bir noktada takılırsa:

> *"Sahnede demo tanrılarını kızdırmamak için yedek videoyu izleyelim — aynı akışı 90 saniyede özetliyor."*

Sonra video → Slayt 10 (Çıkarımlar + Q&A). Toplam kayıp süre: ~30 sn. Akıştan kopulmuyor.
