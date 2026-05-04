# Demo Walkthrough V3
# 3 mini-demo · ~18 dk toplam · stories/ klasöründeki detaylı script'lere bak

## Ön hazırlık (sunum öncesi 30 dk)

```powershell
# 1. Backend + Frontend çalıştır
cd C:\Projeler\Agent-Store-Web
docker compose up -d

# 2. Sağlık kontrolü
curl http://localhost:8080/health
# → {"status":"ok"}

# 3. Flutter web
# → http://localhost (nginx üzerinden)

# 4. Demo cüzdanı kontrol
# MetaMask → Monad Testnet (ChainID: 10143)
# Balance: min 0.01 testMON + 1000 kredisi olsun

# 5. Tarayıcı hazırlığı
# Tab 1: http://localhost (store)
# Tab 2: http://localhost/guild-master
# Tab 3: http://localhost/legend
# Tab 4: http://localhost/create-agent
# (4 tab önceden açık — yükleme gecikmesi olmasın)
```

## Demo 1: Guild Master (S1 — Elif) · ~4.5 dk

Detaylı script: `stories/01-solo-founder.md`

**Özet adımlar:**
1. `/guild-master` tab'ına geç
2. Problem yaz: `"Müşteri şikayetlerini kategorize et, öncelik ver ve taslak yanıt yaz"`
3. "Find Team" → (max 15s bekleme, sonra fallback)
4. Suggestion paneli: Oracle + Bard + Strategist + reason/confidence göster
5. "Save as Mission" → redirect
6. Köprü cümlesi → Tab 3'e geç

**Kritik: 10s bekleme kuralı**
5s'de spinner dönüyorsa devam et. 10s'de yanıt gelmiyorsa:
→ `"API biraz yavaş — cached örneği göstereyim."`
→ fallback-fixtures.md → S1_SUGGESTION_FIXTURE ekranını aç

---

## Demo 2: Legend DAG (S2 — Mehmet) · ~5.4 dk

Detaylı script: `stories/02-workflow-designer.md`

**Özet adımlar:**
1. `/legend` tab'ına geç
2. "Templates" → "Content Pipeline" → Yükle
3. Kanvası tanıt: 4 node → node'a tıkla → model seçici (haiku/sonnet dropdown)
4. Yeni node ekle: "Quality Check" → drag, bağla
5. Execute → (max 60s bekleme, sonra video)
6. Execution history → Rerun butonu
7. Credit balance (−6 cr) göster
8. Köprü cümlesi → Tab 4'e geç

**Kritik: Execute fallback**
Execute'e bastıktan sonra 15s progress bar yoksa:
→ `"Execute'ü video ile göstereyim — aynı akış."`
→ backup-video/legend-execute.mp4 oynat (dock'ta hazır)

---

## Demo 3: Create Agent + Karakter (S3 — Zeynep) · ~3.4 dk

Detaylı script: `stories/03-creator.md`

**Özet adımlar:**
1. `/create-agent` tab'ına geç
2. Prompt yapıştır (önceden kopyalanmış):
   ```
   Academic writing editor: analyze structure, rewrite unclear sections,
   fix citation format (APA/MLA), improve academic tone.
   ```
3. Live preview → Scholar karakter belirlenir → animasyon
4. Title: "Academic Writing Editor" + kısa description
5. (Opsiyonel, varsa vakit) Card Editor açıp kapat
6. Publish → leaderboard'a git → kartı göster
7. Public profile → ratings + follower
8. Köprü → slayt 9'a geç

**Güvenilirlik**: Bu demo en stabil. Fallback gerekmez ama eğer:
Claude API timeout → default "Wizard" karakter gelir — kabul et, devam et.

---

## Genel fail planı

```
1. Tek bir demo crash: "Bugün demo tanrıları sabırsız — aynı akışın videosuna bakalım."
   → backup-video/ klasöründen ilgili .mp4'ü oynat

2. Internet tamamen yok: "Demo offline — story ile anlatacağım."
   → Her hikâyeyi bullet point + fallback-fixtures.md ekranı ile anlat

3. Monad RPC down: Demo 1 + 3 etkilenmez. Demo 2'de credit settlem. bypass — "Testnet biraz titiz."

4. Docker crash: Sunum öncesi restart — sunum anında değil.
   → "Demo ortamı bugün bize izin vermedi — ama bu proje open source, repo'yu göstereceğim."
```

---

## Timing özeti

| Demo | Budget | Buffer ile max |
|------|--------|---------------|
| D1 (Guild Master) | 4.5 dk | 6 dk |
| D2 (Legend) | 5.4 dk | 7 dk |
| D3 (Create Agent) | 3.4 dk | 5 dk |
| **Toplam** | **13.3 dk** | **18 dk** |

Demo + setup + köprüler + opening + closing = ~35 dk. Demo'lar 14 dk üzerine çıkmamalı.
