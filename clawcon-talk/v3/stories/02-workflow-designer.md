# Hikâye 2 — Workflow Tasarımcısı (Mehmet)
# Slayt 5–6 · ~7 dk · HYBRID demo

## Persona

**Mehmet**, 26 yaşında, junior PM. Dijital yayın editörü için çalışıyor.
Haftalık haber bülteni operasyonu: kaynakları oku → özetle → kalite kontrol → formatla → gönder.
Bugün 3 farklı araç, manuel copy-paste, 45 dk / gün.

Zapier biliyor, n8n biliyor. Ama AI agent zinciri farklı.
"Sessions spawn ne demek" bilmiyor. YAML yazmak istemiyor.
"Bunu bir diyagram olarak çizmek istiyorum" diyor.

## Slayt 5 — Problem Setup (90s)

**Başlık**: Hikâye 2: Workflow Tasarımcısı

Konuşma metni:
```
"Mehmet'in sorunu farklı. O ne yapacağını biliyor.
Kaynak oku, özetle, kontrol et, formatla, gönder.
Sırası belli. Mantığı belli.

Ama bunu YAML veya Python'a çevirmek istemek istemiyor.
Görsel bir şey istiyor. 'Çiz' demek istiyor.

Legend bu yüzden var."
```

## Slayt 6 — DEMO (360s)

**Başlık**: DEMO — Legend DAG

### Canlı demo adımları (6 dk bütçesi)

1. **Aç ve orientasyon** (15s)
   - `/legend` → boş kanvas veya son workflow
   - Konuşma: "Drag-drop DAG kanvası. Her node bir agent."

2. **Template galerisi** (20s)
   - "Templates" butonuna bas → 6 şablon göster
   - "Content Pipeline" seç → yükle
   - Konuşma: "Sıfırdan başlamak zorunda değilsin."

3. **Kanvası tanıt** (30s)
   - 4 node göster: START → RSS Reader → Summarizer → Formatter → END
   - Node'a tıkla → model seçici aç (haiku/sonnet/opus dropdown)
   - Konuşma: "Her node için farklı model. Haiku hızlı ve ucuz.
     Sonnet daha güçlü ama 3 kredi."

4. **Canlı düzenleme** (30s)
   - Yeni node ekle: "Quality Check" (haiku, 1cr)
   - Summarizer ile bağla
   - Konuşma: "Mehmet buraya bir kalite kontrol adımı ekledi.
     Sürükle, bağla, tamam."

5. **Execute** (30–120s)
   - Execute butonuna bas
   - Topological sort → node'lar sırayla yanıp söner
   - Konuşma: "Topological sort — cycle yok, sıra doğru."
   - **Eğer API yavaşsa: backup video'ya geç (backup-video/legend-execute.mp4)**

6. **Execution history** (30s)
   - History panelini aç
   - Tamamlanan çalışmayı göster: süre, node çıktıları, "Rerun" butonu
   - Konuşma: "Her çalışma kaydedildi. Mehmet yarın 'Rerun' diyecek."

7. **Kredi + on-chain** (15s)
   - Credit balance göster: -6 kredi düştü
   - Konuşma: "6 kredi Monad testnet'te işlendi. Şeffaf, takip edilebilir."

8. **Köprü cümlesi** (15s)
   ```
   "Mehmet kodu yazmadan pipeline kurdu.
   Agent seçti, bağladı, çalıştırdı.
   Zeynep'e geçelim — o çalıştırmak değil, görünür olmak istiyordu."
   ```

### Fallback senaryosu

```
Template seçimi + drag-drop kısmı CANLI yap (düşük risk).
Execute kısmı için:
  → "Execute'ü canlı göreceğiz — veya backup'a geçeceğiz."
  → 5 saniyede progress bar başlamazsa: backup-video/legend-execute.mp4
  → Video: 60 saniye, full execute akışı
```

## Timing drill notları

- Orientasyon: 15s
- Template + yükleme: 20s
- Kanvas tanıtma: 30s
- Model seçici: 20s (sadece göster, açıklama)
- Node ekleme + bağlama: 30s
- Execute bekleme: max 60s (sonra video)
- History: 30s
- Kredi: 15s
- Köprü: 15s
- **TOPLAM**: ~235s demo + 90s setup = 325s = 5.4 dk (buffer var)

## Teknik notlar (demo güvenilirliği için)

- Demo öncesi: `docker compose up` çalışıyor mu kontrol et
- Demo cüzdanında en az 1000 kredi olsun
- Legend önceden açık tut, fresh reload yok (slower)
- Template listesi boş gelirse: manuel node ekle (S3 seviyesinde basit)

## Sık sorulan sorular (S2 için)

**"Parallel execution var mı?"**
→ Şu an sequential. Parallel dispatch OpenClaw entegrasyonu ile gelecek. Fanout node planlı.

**"Cycle detection nasıl?"**
→ Topological sort Kahn algoritması. Cycle varsa execute başlamaz, hata gösterir.

**"6 kredi kaç para?"**
→ Testnet'te testMON ile. Mainnet'te fiyatlandırma henüz belirlenmedi — early access phase.

**"Node çıktısı bir sonrakine nasıl geçiyor?"**
→ Execution context feeding: her node'un stdout'u bir sonrakinin prompt context'ine ekleniyor.
