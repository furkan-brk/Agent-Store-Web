# GAMMA PROMPT V3 — Agent Store: Üç Kullanıcı, Üç Çözüm
# Story-first · Sade dark · 10 slayt · 35 dk
# Clawcon 2026 — Furkan Berk
#
# KULLANIM:
# 1. "=== GAMMA BAŞLANGICI ===" satırından sonrasını kopyala
# 2. gamma.app → "Generate from text" → yapıştır
# 3. Her [SCREENSHOT: dosya.png] için screenshots/ klasöründen gerçek PNG yükle
#
# ─────────────────────────────────────────────
# TEMA AYARLARI (Gamma → Themes → Custom)
# ─────────────────────────────────────────────
#   Background:   #0a0a0f   (derin siyah)
#   Surface:      #131320   (kart / blok zemini)
#   Heading:      #ffffff   (beyaz başlıklar)
#   Body text:    #c9c9e0   (açık lavanta)
#   Accent 1:     #7c3aed   (mor — interaktif)
#   Accent 2:     #f59e0b   (amber — vurgu / CTA)
#   Accent 3:     #10b981   (yeşil — başarı / execute)
#   Code font:    JetBrains Mono
#   Body font:    Plus Jakarta Sans veya Inter
#   Heading font: Inter ExtraBold
#
#   NOT: AI görsel üretimi KULLANMA.
#   Her slayta gerçek UI screenshot veya minimal tipografi koy.
#   Fantasy/drama estetiği yok.
#
# ─────────────────────────────────────────────
# SLAYT NOTLARI
# ─────────────────────────────────────────────
#   Her "---" = yeni slayt
#   [SCREENSHOT: dosya.png] = gerçek screenshot yükle (screenshots/ klasöründen)
#   <!-- --> = konuşma notları → Gamma Notes paneli
#
# ─────────────────────────────────────────────

=== GAMMA BAŞLANGICI — BURADAN AŞAĞISINI KOPYALA ===

---

# Bu sabah bir kullanıcı, **90 saniyede** bir şey yaptı.

```
09:14:22  →  Guild Master açıldı
09:14:28  →  "Müşteri şikayetlerini kategorize et, öncelik ver, taslak yanıt yaz"
09:14:34  →  AI analiz ediyor...
09:14:39  →  Takım önerisi: Oracle + Bard + Strategist
09:14:41  →  "Save as Mission" →  kaydedildi
09:15:52  →  Oturum kapandı
```

> Bir satır kod yazmadı.
> Agent ne olduğunu bilmiyordu.
> **90 saniye.**

[SCREENSHOT: store-grid-overview.png]

<!--
[0:00–3:00]
"Selam Clawcon.

Bu sabah sistemimin loglarına baktım. Anonim bir kullanıcı, 09:14'te giriş yapmış.
Guild Master'ı açmış. Bir şey yazmış. 17 saniye beklemiş. Kaydetmiş. Oturumu kapatmış.

Bu kişi bir PM veya bir kurucu — bilmiyorum. Ama 'agent' kelimesini hayatında belki
10 kez duymuştur.

Bu akşam kendi müşteri destek sürecini bir AI takımına delege etmiş.
90 saniyede.

Bugün bu üç soruyu yanıtlayacağım:
Nasıl oldu? Başka kim ne yapıyor? Bu neden önemli?

10 slayt, 35 dakika."
-->

---

# Bugün **üç hikâye** anlatacağım.

| 👤 Solo Kurucu | ⚙️ Workflow Tasarımcısı | 🎨 İçerik Yaratıcısı |
|---|---|---|
| Ekip yok, zaman yok | Kod yok, vizyon var | Prompt var, görünürlük yok |
| **Guild Master** | **Legend** | **Karakter sistemi** |
| 5 sn'de ekip kurdu | DAG çizdi, çalıştırdı | Promptuna kimlik verdi |

[SCREENSHOT: persona-trio-pixel-art.png]

<!--
[3:00–4:30]
"Üç farklı kişi. Üç farklı problem. Aynı platform.

İlki: solo kurucu. Müşteri desteğini yönetemez hale gelmiş.
İkincisi: junior PM. Çoklu-adımlı otomasyon kurmak istiyor, ama YAML yazmak istemiyor.
Üçüncüsü: içerik üreticisi. Harika bir prompt yazdı, ama kimse görmüyor.

Bu üçü Agent Store'da farklı özellikleri kullandı.
Hikâyelerini sırayla anlatacağım."
-->

---

# Hikâye 1: **Solo Kurucu**

> *"Bir AI agent'a ihtiyacım olduğunu biliyorum.*
> *Hangisi? Nasıl? Kimi çağırıyorum?"*

**Elif**, SaaS kurucusu. Yazılım ürünü, 3 çalışan, müşteri sayısı artıyor.
Haftalık 60+ destek ticket'ı. Hepsine bakan: kendisi.

Her ticket için:
- okuma → etiketleme → önceliklendirme → taslak yanıt → düzeltme

Bu iş onun **saatlerini** yiyor.

Multi-agent framework biliyor.
Routing config bilmiyor. Agent yazma vakti yok.

**Elif'in sorusu: Kim bu işi yapmalı?**

[SCREENSHOT: guild-master-empty.png]

<!--
[4:30–6:30]
"Elif gerçek bir kullanıcı tipi. İsmini değiştirdim ama skenaryoyu değiştirmedim.

Müşteri şikayetleri var: çökme bildirimleri, faturalandırma soruları, özellik istekleri.
Hepsini Elif karşılıyor. Haftada 8 saat gidiyor.

ChatGPT'ye 'yardım et' yazıyor ama her seferinde bağlamı tekrar anlatmak zorunda.
Sistemli bir çözüm istemiyor. Sadece 'doğru kişiyi' buluyor.

Agent Store'da Guild Master var. Elif ona şunu yazdı:
'Müşteri şikayetlerini kategorize et, öncelik ver, taslak yanıt yaz.'

Ne olduğunu gösterelim."
-->

---

# DEMO — Guild Master

**Elif'in akışı:**

1. **Problem yaz** — doğal dil, teknik jargon yok
2. **AI takım önerir** — her agent için gerekçe + güven skoru
3. **Kabul et** — tek tık
4. **"Save as Mission"** — tekrar çalıştırılabilir görev

[SCREENSHOT: guild-master-suggestion.png]

---

🧙 **Oracle** — *Veri analizi · Şikayet etiketleme · Önceliklendirme*
`Güven: %91` · *"Yapılandırılmamış metinden kategori çıkarmada güçlü"*

🎤 **Bard** — *İletişim · Taslak yanıt üretimi · Ton ayarı*
`Güven: %87` · *"Empati tonunu koruyarak hızlı taslak üretiyor"*

📊 **Strategist** — *Önceliklendirme · SLA takibi · Eskalasyon kararı*
`Güven: %78` · *"Kritik ticket'ları genel kuyruktan ayırt ediyor"*

> Elif bu üçünü "Save as Mission" yaptı.
> Yarın tekrar aynı şeyi yapacak — **tek tıkla.**

<!--
[6:30–12:30] — CANLI DEMO (veya fallback fixture)
ADIMLAR:
1. Guild Master'ı aç (localhost:80/guild-master)
2. Problem yaz: "Müşteri şikayetlerini kategorize et, öncelik ver, taslak yanıt yaz"
3. "Find Team" → AI suggestion gelsin (5-10 sn)
4. Suggestion panel göster: Goal + Plan + her agent için reason/confidence
5. "Save as Mission" → Mission sayfasına git → başarı

FALLBACK: API 10sn'de yanıt vermezse:
"Demo tanrıları bugün öfkeli — cached örneği gösteriyorum."
→ demo/fallback-fixtures.md içindeki S1 fixture'ını aç.

KÖPRÜ (her demo sonrası):
"Bu Guild Master: problem → AI team → Mission.
Sıradaki hikâyeye geçelim — bu sefer ekibi seçmek değil,
onların nasıl çalışacağını çizmek."
-->

---

# Hikâye 2: **Workflow Tasarımcısı**

> *"n8n biliyorum. Zapier biliyorum.*
> *AI agent zinciri kurmayı bilmiyorum."*

**Mehmet**, product manager. Haber bülteni operasyonu:
kaynakları oku → özetle → kalite kontrol → formatla → gönder.

Bugün 3 farklı araç, manuel copy-paste, 45 dk / gün.

Multi-step AI pipeline'ı kurmak istiyor.
Ama YAML, kod, CLI — bunlar değil.

**Mehmet'in sorusu: Bunu görsel olarak çizebilir miyim?**

[SCREENSHOT: legend-canvas-template.png]

<!--
[12:30–14:00]
"Mehmet'in sorunu farklı. O ne yapacağını biliyor.
Ama kurmayı bilmiyor. Kodla ifade etmek istemiyor.

Agent Store'da Legend var: drag-drop DAG kanvası.
Node'ları bağlıyorsun, her birine model seçiyorsun,
execute diyorsun — sırayla yürür.

Bugün Claude API'ye doğrudan bağlı.
Multi-agent runtime entegrasyonu OpenClaw üzerinden planlanıyor.

Şimdi gösterelim."
-->

---

# DEMO — Legend DAG

**Mehmet'in akışı:**

```
🟢 START
  ↓
🟣 Kaynak Okuyucu   (haiku  · 1 cr)   — RSS + web scrape
  ↓
🩷 Özetleyici       (sonnet · 3 cr)   — ana nokta çıkar
  ↓
⚪ Kalite Kontrol   (haiku  · 1 cr)   — tutarsızlık bul
  ↓
🔵 Formatter        (haiku  · 1 cr)   — bülten şablonu
  ↓
🟡 END                  Toplam: 6 kredi
```

✅ Template galeri — 6 hazır şablon, 1 tıkla yükle
✅ Drag-drop — node ekle/sil/bağla
✅ Per-node model — her adım için farklı güç
✅ Execute → topological sort → paralel çalışır
✅ Execution history — her çalışma kaydedilir, **Rerun**

[SCREENSHOT: legend-execution-running.png]

<!--
[14:00–20:00] — CANLI DEMO (hybrid)
ADIMLAR:
1. Legend'a gir (/legend)
2. "Templates" → "Content Pipeline" şablonunu seç
3. Kanvasta node'ları göster, per-node model seçimini aç
4. Bir node ekle/sil — drag-drop göster
5. Execute → sonuçları izle (ya da backup video)
6. Execution history → "Rerun" butonunu göster

FALLBACK: Execute kısmı için backup video hazır (backup-video/legend-execute.mp4).
Template seçimi + drag-drop kısmı canlı, execute kısmı video.

KÖPRÜ:
"Mehmet artık pipeline'ını çizdi. Çalıştırdı.
6 kredi harcandı — Monad testnet'te on-chain kayıt var.

Üçüncü hikâyeye geçiyoruz. Bu sefer çalışma değil, kimlik."
-->

---

# Hikâye 3: **İçerik Yaratıcısı**

> *"Harika bir prompt yazdım.*
> *Ama kimse görmüyor. Kimse paylaşmıyor.*
> *Kuru metin — ilgi çekmiyor."*

**Zeynep**, üniversite asistanı. Akademik yazı düzenleme promptu yazdı.
3 ay önce Reddit'e koydu. 12 upvote. Sonra sessizlik.

Agent Store'a geldi.
Aynı promptu yükledi.

**Ne oldu?**

[SCREENSHOT: create-agent-form.png]

<!--
[20:00–21:00]
"Zeynep'in sorunu görünürlük. İçerik kalitesi sorun değil.
Sununun değil.

Çoğu prompt marketplace'de şu var: başlık, metin, kopyala.
Agent Store'da farklı bir şey var: promptun bir karakteri var."
-->

---

# DEMO — Karakter Sistemi

**Zeynep'in akışı:**

1. **Prompt yapıştır** — "Akademik yazıyı analiz et, yeniden yaz, atıfları düzelt"
2. **Claude AI analiz eder** — prompt tonunu, amacını, alanını çıkarır
3. **Karakter belirlenir** → **Scholar** (Bej · Kahve · Araştırma / Eğitim)
4. **Pixel-art avatar üretilir** — 16×16 sprite, rarity: Uncommon
5. **Card Editor** → başlık, açıklama, vurgu rengi ince ayar
6. **Publish** → leaderboard'a düşer → sosyal grafik

[SCREENSHOT: create-agent-live-preview.png]

---

| Karakter | Prompt tipi | Nadir derece |
|----------|------------|--------------|
| Scholar | Araştırma / Eğitim | Uncommon |
| Wizard | Backend / Kod | Rare |
| Oracle | Veri / Analitik | Common |
| Guardian | Güvenlik / Infra | Epic |
| Bard | Yaratıcı / Yazarlık | Legendary |

> Zeynep'in promptu artık bir **karakter**.
> Kütüphanelere ekleniyor. Rating alıyor. Takip ediliyor.

[SCREENSHOT: leaderboard-screen.png]

<!--
[21:00–27:00] — TAMAMEN CANLI (en güvenli demo)
ADIMLAR:
1. /create-agent'a git
2. "Academic writing editor: analyze, restructure, fix citations. Formal tone. APA style." yaz
3. Claude analiz → Scholar type → live pixel-art preview izle
4. Card Editor'da açıklama yaz → Save
5. Publish → leaderboard'a git → kartı göster
6. Public profile'a git → ratings + follower count göster

KÖPRÜ:
"Zeynep'in promptu artık bir karakter.
Kütüphanelere ekleniyor. 4 saatte 12 kullanıcı save etti.

Şimdi bir adım geri çekilelim — bu üç hikâye aynı altyapı üzerinde çalıştı."
-->

---

# Aynı altyapı. **Üç farklı çözüm.**

```
              👤  Elif / Mehmet / Zeynep
                          │
          ┌───────────────┼───────────────┐
          │               │               │
    Guild Master      Legend DAG     Create Agent
    (team suggest)    (workflow)    (karakter sys.)
          │               │               │
          └───────────────┼───────────────┘
                          │
              ┌───────────┴──────────┐
              │   Agent Store Core   │
              │  auth · kredi · char │
              │  sosyal · discovery  │
              └───────────┬──────────┘
                          │
                    Go mikroservisler
                    Monad testnet
                    PostgreSQL
```

> Biz **son kullanıcı ürün katmanıyız.**
> Routing, izolasyon, session orchestration: OpenClaw runtime'ın işi.
> Kullanıcıya dokunan her şey: Agent Store'un işi.

[SCREENSHOT: agent-store-architecture-collage.png]

<!--
[27:00–30:00]
"Bu üç hikâyede fark ettiniz mi — hiçbirinde 'multi-agent routing' geçmedi.
Elif 'Oracle + Bard + Strategist' dedi. Mehmet 'pipeline' dedi. Zeynep 'Scholar' dedi.

Arka planda session yönetimi var, izolasyon var, dispatch var.
Ama kullanıcı bunları görmiyor. Görmemeli de.

Bu ayrımı bilerek yaptık.
OpenClaw runtime'ı güçlü bir zemin sağlıyor: routing, isolation, session.
Agent Store bu zeminin üstünde yaşıyor — son kullanıcıya dokunan katman.

İki proje farklı sorulara cevap veriyor.
OpenClaw: 'Mesaj nereye gider?'
Agent Store: 'Kullanıcı ne yapar, ne görür, ne hisseder?'

Birlikte tam bir resim."
-->

---

# **Sıra sizde.**

---

🔗 **Dene:** testnet.agentstore.xyz *(geliştirme aşamasında)*
📦 **Kaynak:** github.com/furkan-brk/agent-store-web *(yakında public)*

---

**Bug buldun mu?** → DM aç.
**Feature fikrin var mı?** → RFC açalım.
**Benzer bir şey mi kuruyorsun?** → Konuşalım.

---

> Multi-agent ekosistemi altyapıda güçlü.
> **Ürün katmanı hâlâ boş.**
> Birlikte dolduralım.

## Sorular?

<!--
[30:00–35:00]
"Üç hikâyeyi anlattım.

Elif, müşteri desteğini 90 saniyede delege etti.
Mehmet, newsletter pipeline'ını kod yazmadan kurdu.
Zeynep, promptuna kimlik verdi ve görünür oldu.

Bunların hiçbirini single-agent ChatGPT prompt'u ile yapamazsınız.
Bunların hiçbiri için bir framework kurmak zorunda değilsiniz.

Bu Agent Store'un tezi: son kullanıcı multi-agent'ı kullanabilir —
eğer doğru ürün katmanı varsa.

Sorularınızı bekliyorum. Özellikle sert olanları."

---
SONRADAN PAYLAŞ:
- GitHub repo linki (public olduktan sonra)
- Talk notları / slides PDF
- RFC: Q4 2026
-->
