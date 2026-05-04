# Agent Store **with** OpenClaw
## Multi-Agent için ürün katmanı

> **Tek dosya. Gamma ile sunum hazırlamak için.**
> Türkçe içerik · İngilizce görsel prompt'lar · **10 slayt** · 35 dk hedef
> Demo projesi: `C:\Projeler\Agent-Store-Web` (Flutter Web + Go + Solidity)
> Slayt başına ortalama 3.5 dk — dolu slaytlar, derin anlatım, canlı demo merkezde.

---

# 📖 Bu dosyayı Gamma'da nasıl kullan?

1. **Aşağıdaki "🎨 GÖRSEL YÖNERGESİ" bölümünü oku.** Gamma'da `Themes` panelinden manuel uygula.
2. **"🎬 SLAYTLAR BAŞLIYOR" satırından itibaren olan içeriği kopyala** ve Gamma'nın "Generate from text" girişine yapıştır. Her `---` Gamma için yeni slayt.
3. Her slaytın altındaki `> [Visual: ...]` satırı Gamma'nın AI image generation prompt'u.
4. Konuşma notları her slaytın sonunda `<!-- ... -->` HTML comment'i olarak — Gamma'nın "Notes" özelliğine kopyala.
5. Slaytlar **dolu** — Gamma bazılarını otomatik 2 sayfaya bölebilir, sorun değil.

---

# 🎨 GÖRSEL YÖNERGESİ (Gamma theme settings için)

## Tema kişiliği
**"Bir altta sağlam framework, üstte modern ürün."** Mimari katman vurgusu — alt katmanlar daha teknik/koyu, üst katmanlar daha renkli. **Stack** estetiği: katmanlar arası akış, integration point'ler, "üstüne kuruyoruz" hissi.

## Renk paleti

| Rol | Hex | Kullanım |
|-----|-----|----------|
| **Background (deep)** | `#0d1117` | Ana koyu zemin |
| **Surface (raised)** | `#161b22` | Card/code-block zemini |
| **OpenClaw layer** | `#7c3aed` | Alt katman vurgusu (mor) — foundation |
| **Agent Store layer** | `#f59e0b` | Üst katman vurgusu (altın) — product |
| **Bridge / integration** | `#10b981` | İki katmanı birleştiren noktalar (yeşil) |
| **Pixel-art highlight** | `#ec4899` | Gamification öğeleri (pembe) |
| **Text primary** | `#e6edf3` | Ana metin |

> Gamma'da: "Custom theme" → Background = `#0d1117`, Heading = `#7c3aed`, Body = `#e6edf3`, Accent = `#f59e0b`.

## Tipografi
- **Headings:** Inter, Manrope veya Geist
- **Body:** Inter veya Source Sans
- **Code/CLI:** JetBrains Mono, Fira Code

## Görsel stil
- 10 slayt **dolu** — her slaytın belirgin bir merkezi var
- Ana motif: **dikey katman şeması** (foundation → middleware → product → user)
- Hero slaytlar (Guild Master, Legend, Demo) için **gerçek UI screenshot** kullan (`screenshot-capture-checklist.md`)
- Diğerlerinde Gamma AI image generation yeterli

## Gamma image generation için global stil prompt'u

```
dark technical aesthetic with layered architecture motif,
purple-to-gold vertical gradient suggesting foundation-to-product layers,
subtle gaming/pixel-art accents only in upper layers, no people, no faces,
abstract architecture diagrams with glowing integration points,
clean composition, premium developer documentation feel
```

## Süre dağılımı (10 slayt × 3.5 dk = 35 dk)

| Slayt | Bölüm | Süre |
|-------|-------|------|
| 1 | Title + Hook | 1 dk |
| 2 | Multi-agent'ın iki yarısı | 3 dk |
| 3 | OpenClaw foundation (yoğun) | 5 dk |
| 4 | **VISION pivot** ⭐ | 2 dk |
| 5 | Agent Store stack + mapping | 5 dk |
| 6 | **Guild Master** ⭐ | 3 dk |
| 7 | **Legend DAG** ⭐ | 3 dk |
| 8 | Bridge plugin v2 + dürüstlük | 3 dk |
| 9 | **DEMO** ⭐⭐ | 7 dk |
| 10 | Çıkarımlar + Q&A | 3 dk |
| | **Total** | **35 dk** |

---

# 🎬 SLAYTLAR BAŞLIYOR — buradan aşağısını Gamma'ya yapıştır

---

# Agent Store **with** OpenClaw
## Multi-Agent için ürün katmanı

Furkan Berk · Clawcon · 2026

> [Visual: vertical layered stack diagram. Bottom layer purple labeled "OpenClaw Multi-Agent Runtime". Middle thin green strip labeled "Bridge / API". Top layer gold labeled "Agent Store: UX + Marketplace + Economy". User icon at very top. Clean architectural diagram, dark background.]

<!--
[0:00-1:00] "Selam Clawcon! Bugün size OpenClaw multi-agent'ın
üstüne kurduğum ürün katmanını anlatacağım: Agent Store. Tek başına
bir ürün değil — OpenClaw'la BERABER düşünülmesi gereken bir
UX/marketplace/economy katmanı.

Stack şeklinde: en altta OpenClaw multi-agent runtime, ortada bridge
katmanı, üstte Agent Store, en üstte son kullanıcı. Bu sunum o stack'in
nasıl ortaya çıktığının ve niye böyle ayrıştığının hikayesi.

10 slayt, 35 dakika, sonunda canlı demo. Başlayalım."
-->

---

# Multi-agent'ın **iki yarısı** var

**Bir multi-agent ürünü için iki katman lazım:**

🔧 **Orchestration motoru:** izolasyon, routing, security, sessions
🎮 **Ürün katmanı:** marketplace, UX, gamification, on-chain economy

OpenClaw birinciyi olağanüstü çözüyor.
**İkinciyi VISION'ı gereği core'a almıyor** (`VISION.md:106-118`).

> Bu sunum o boşluğun nasıl doldurulduğunun hikayesi.

> [Visual: split-screen composition. LEFT half (purple): technical engine internals — gears, terminal, abstract isolation cells. RIGHT half (gold): colorful product UI — marketplace cards, wallet icon, pixel-art characters. Connected at center with a thin green "bridge" strip. Subtle "OpenClaw" text on left, "Agent Store" on right.]

<!--
[1:00-4:00] "Multi-agent dünyasında bir paradoks var: framework'ler
mükemmel izolasyon sunuyor, ama son kullanıcı için marketplace,
gamification, on-chain economy YOK. Çünkü framework'ler bu katmanı
core'a koymuyor — koymalarına gerek de yok.

OpenClaw'ın VISION dokümanı bu konuda çok net: 'core lean kalsın,
ağır UX katmanlarını üstte yazın'. Bu kısıtlayıcı değil — TASARIM
KARARI. İki yarıyı net ayırıyor.

Ben tam o ikinci yarıyı — ürün katmanını — yazdım. Adı Agent Store.
Bu sunum hem OpenClaw'ın multi-agent gücünü gösterecek hem de
o gücün üstüne bir ürün nasıl kurulur, mimari ve gerçek koddan
örnekleyecek."
-->

---

# OpenClaw multi-agent foundation

**Tek Gateway, N izole agent.** Her birinin 5 boyutta izolasyonu:

| Boyut | Dosya |
|-------|-------|
| 📁 Workspace | `~/.openclaw/workspace-<agent>/` |
| 🔐 Auth profile | `<agentDir>/auth-profiles.json` |
| 💾 Session store | `<agentDir>/sessions/` |
| 🛠 Tool policy | `tools.allow/deny` per agent |
| 📦 Sandbox | `off` / `docker` per agent |

**8-kademeli routing precedence** (deterministik, hiç LLM yok):
`peer → parentPeer → guild+roles → guild → teamId → accountId → channel → default`

```json5
{ id: "family",
  groupChat: { mentionPatterns: ["@family"] },
  sandbox: { mode: "all", docker: { ... } },
  tools: { allow: ["read"], deny: ["exec", "write"] } }
```

> Bu Agent Store'un üstüne kurulduğu zemin. Yarın bridge plugin ile bu güvenleri miras alacak.

> [Visual: vertical 5-layer stack on the left (one box per isolation dimension, purple gradient). On the right: 8-tier decision tree (small) showing routing precedence. Bottom: small JSON code snippet. All elements connected by thin lines suggesting "these are the OpenClaw primitives".]

<!--
[4:00-9:00] "OpenClaw multi-agent'ı 5 dakikada özetleyeceğim.

Her agent 5 boyutta izole: workspace, auth profile, session store,
tool policy, sandbox. Hepsi ayrı dosyalarda, zod schema seviyesinde
enforce ediliyor. agentDir'ı paylaşmak yasak — refresh token'lar
kazara klonlanmasın diye.

Routing config-driven, deterministik. 8 kademeli precedence ağacı:
en spesifikten — peer match — en geneline — default agent. Aynı
input her zaman aynı agent'a gidiyor. Test edilebilir, debug edilebilir,
predictable.

Aşağıdaki JSON örneği aile agent'ı: sadece mention edildiğinde cevap
veriyor, sadece read tool'una izinli, Docker sandbox'ta koşuyor.
Çocuğum yanlışlıkla agent'a sistemde bir şey sildirir korkusu sıfır.

Bu primitif'ler Agent Store'un üstüne kurulduğu zemin. Bugün direkt
kullanmıyor — bridge plugin v2 milestone'unda kullanacak.

Şimdi VISION'ın bu yapıyı niye böyle bıraktığına geçelim — sunumun
dönüm noktası."
-->

---

# VISION'ın stratejik tercihi

> *"What we will not merge:*
>
> *Agent-hierarchy frameworks, marketplace orchestration,*
> *heavy UX layers — **as a default architecture**.*"

`VISION.md:106-118`

**Üç kelimeye dikkat:** *"as a default architecture"*

OpenClaw orchestration'ı **yasaklamıyor.** Diyor ki:
- Default değil
- Core'da değil
- **Üst katman olarak ayrı yaz**

> Ben de yazdım. Adı Agent Store.
> OpenClaw ile çelişmiyor — onun **üstüne** kuruyor.

> [Visual: elegant blockquote rendered as if from an old leather book on dark wooden surface. Phrase "as a default architecture" highlighted in gold. Below: a thin gold arrow pointing UP from the quote to a labeled "Agent Store" layer above. Suggests "the door VISION leaves open".]

<!--
[9:00-11:00] (KRİTİK GEÇİŞ — vision-pivot-script.md'ye bak)

(Slayt geçer. Quote ekranda. 3 saniye sessizlik.)

"Buraya kadar OpenClaw'ın multi-agent zemini gösterdim. Sağlam,
predictable, framework-grade. Muhtemelen düşünüyorsunuz: 'Tamam motor
sağlam — peki son kullanıcı bunu nasıl deneyimliyor? Marketplace?
Gamification? Wallet?'

Bu çok doğal soru. OpenClaw VISION'ı bu konuda çok net:

(Quote'u SESLİ oku, vurguyla) 'Agent-hierarchy frameworks, marketplace
orchestration, heavy UX layers as a default architecture'.

Üç kelimeye dikkat: 'as a default architecture'. VISION son-kullanıcı
UX'ini reddetmiyor — sadece diyor ki **core'a koymayacağız, üst
katman ayrı yazılsın**.

Ben de yazdım. Adı Agent Store. OpenClaw'ın üstüne kurulan modern ürün
katmanı. VISION beni TAMAMLAYICI olmaya yönlendirdi. Şimdi o katmanı
görelim."
-->

---

# Agent Store stack mimarisi

```text
👤 USER (browser)
   ↓
🎮 Agent Store (Flutter Web + Go microservices)
   ├── authsvc       (wallet auth: nonce + sign + JWT)
   ├── agentsvc      (CRUD, library, credits, ratings)
   ├── aipipelinesvc (analyze, profile, score, avatar)
   ├── guildsvc      (Guild Master suggest/chat)
   └── workspacesvc  (Legend DAG persist + execute)
   ↓
🌉 Bridge plugin (v2 milestone — RFC açık)
   ↓
⚙️ OpenClaw Multi-Agent Runtime
   (routing + isolation + sessions_spawn + auth-profiles)
   ↓
🔗 PostgreSQL · Redis · Monad on-chain
```

**Her Agent Store özelliği bir OpenClaw primitif'ine map oluyor:**

| Agent Store | OpenClaw |
|-------------|----------|
| Agent kart + character_type + rarity | `agentId` + workspace metadata |
| Wallet auth (JWT) | `auth-profiles.json` per agent |
| **Guild Master** (LLM team selector) | bindings (deterministic) |
| **Legend DAG** | `sessions_spawn` chain |
| Per-node model (haiku/sonnet/opus) | per-agent `model` config |
| Library + Store | `agents.list` + ClawHub |

> [Visual: vertical layered stack diagram on the left (very clean — User, Flutter, Gateway, microservices listed, green Bridge layer, OpenClaw runtime, Postgres+Monad). Two-column mapping table on the right with green arrows connecting Agent Store features (gold) to OpenClaw primitives (purple).]

<!--
[11:00-16:00] "Agent Store'un mimarisi: kullanıcı tarayıcıdan giriyor.
Flutter Web frontend Vercel'de host. API Gateway Go'da, beş mikroservis
arkasında: auth, agent, AI pipeline, guild, workspace. Her birinin net
rolü var.

Aşağıda — bridge plugin katmanı — Agent Store'un Guild Master + Legend
output'unu OpenClaw bindings'e dispatch ediyor. v2 milestone'um. Plugin
hazır olduğunda Agent Store kullanıcısı arka planda OpenClaw runtime'ından
faydalanmış oluyor.

En altta OpenClaw multi-agent runtime: routing precedence, isolation,
sessions_spawn chain'leri. Yan tarafta veri katmanı: Postgres durumsal
veri, Redis cache, Monad on-chain credit + agent registry.

Sağdaki tablo kritik: Agent Store'un hiçbir özelliği boşlukta değil.
Wallet auth OpenClaw'ın auth-profile'ının web versiyonu. Guild Master
bindings'in dinamik LLM-driven üstü. Legend DAG sessions_spawn zincirinin
canvas hâli. Bu mapping bridge plugin'in iskeleti.

Şimdi bu özelliklerin iki tanesini — sunumun iki hero feature'ını —
göstereceğim: Guild Master ve Legend."
-->

---

# Guild Master = LLM team selector

OpenClaw bindings deterministik — kim her zaman nereye gidiyor.
**Agent Store dinamik LLM-driven — gelen probleme göre takım seçiyor.**

```
Sen: "Web app login akışı: backend + frontend + security review"
            ↓
🤖 Guild Master LLM
            ↓
🧙 Wizard (backend-auth)      → JWT impl + nonce
🎨 Artisan (frontend-form)    → Login UI + validation
🛡 Guardian (security-review) → CSRF/replay analiz

+ 3 mission önerisi
+ 4 step plan
+ "Add to Legend" tek tık
```

**Bridge v2'de:** seçilen takım → OpenClaw bindings'e dispatch.
LLM seçim **üstte**, OpenClaw deterministik routing **altta**.

> [Visual: chat-style UI mockup on the left — text input at top with the typed problem, below 3 character portrait cards (Wizard purple, Artisan pink, Guardian gray) with role labels and confidence badges. Gold "Add to Legend" button at the bottom. On the right: a small annotation arrow saying "→ OpenClaw bindings (v2)".]

<!--
[16:00-19:00] "Guild Master sunumun kalplerinden biri. Kullanıcı problem
yazıyor — 'Login akışı için takım öner, backend, frontend, security'.
LLM 5 saniyede 3 agent'lık takım öneriyor: Wizard backend için, Artisan
frontend, Guardian security review. Her birinin neden seçildiğine dair
gerekçe yazıyor. Confidence skoru var.

OpenClaw'da bu işi bindings deterministik yapıyordu — 'wallet X her
zaman family agent'a gitsin'. Agent Store'da DİNAMİK: aynı kullanıcı
bir saniye backend takımı, bir saniye design takımı isteyebilir.

Bridge plugin v2'de bu üç agent ID'si OpenClaw bindings'e çevriliyor.
Yani LLM-driven SEÇİM üstte, deterministik ROUTING altta. Halüsinasyon
seçimde olabilir ama dispatch deterministik. İki dünyanın iyi yanı.

'Add to Legend' butonu bir sonraki ekrana — Legend'a — geçiriyor.
Şimdi onu görelim."
-->

---

# Legend = Visual `sessions_spawn` chain

OpenClaw'da kod, Agent Store'da **canvas**:

✅ Drag-drop DAG editor
✅ Node tipleri: start, mission, agent, guild, end
✅ Topological execute + cycle detection
✅ Per-node model: **haiku 1cr · sonnet 3cr · opus 10cr**
✅ Execution history, rerun, undo/redo, templates
✅ Krediler **on-chain** (Monad testnet)

**Bridge v2:** her node bir `sessions_spawn` çağrısına dönüyor.

```
START → Wizard (sonnet 3cr)
      → Artisan (haiku 1cr)
      → Guardian (opus 10cr)
      → END · Total: 14 credits
```

> [Visual: clean DAG editor mockup. 5 nodes left-to-right: green START → Wizard (purple) → Artisan (pink) → Guardian (gray) → gold END. Connecting arrows pulse subtly. Right panel shows execution log with timestamps and per-node model badges. Bottom shows "Total: 14 credits" with on-chain icon.]

<!--
[19:00-22:00] "Legend, sunumun ikinci hero feature'ı. OpenClaw'ın
sequential pipeline'ının görsel hâli. Drag-drop DAG editor — node'ları
bağlıyorsun, execute, topological sort çalışıyor, sırayla yürür.

Per-node model seçimi var: haiku 1 kredi, sonnet 3, opus 10 — gerçek
API maliyetlerine yakın. Kullanıcı 'opus her node'da' yapmaktan
caydırılıyor, 'sadece kritik node'larda opus' tercihi besleniyor.
Krediler on-chain — ERC-20 benzeri Monad kontratı.

Bridge plugin v2'de canvas'taki her node bir sessions_spawn çağrısına
çevriliyor. Geliştirici sessions_spawn yazmak yerine canvas'ta çiziyor.
Aynı sonuç, başka bir abstraction.

Execution history + rerun + undo/redo + templates — tipik product
feature'ları. Ama altında deterministik OpenClaw güvenleri olacak.

Şimdi tüm bunların bugünkü durumu hakkında dürüst olalım."
-->

---

# Bridge plugin v2 — dürüstlük + roadmap

**Bugünkü durum:** Agent Store **standalone** — Claude API direct.
**v2 hedefi:** `agent-store-bridge` plugin → OpenClaw'a dispatch.

```typescript
export default definePlugin({
  id: "agent-store-bridge",
  channels: {
    "agent-store": {
      ingest: async (msg, ctx) => {
        const team = await callGuildMasterAPI(msg);
        return executeAsBindings(team);  // ← OpenClaw'a dispatch
      }
    }
  }
});
```

**Roadmap:**

| Milestone | Hedef | Ne |
|-----------|-------|-----|
| M1 | Q4 2026 | Plugin scaffold + custom channel |
| M2 | Q4 2026 | Sequential dispatch (TeamProfile → bindings) |
| M3 | Q1 2027 | Wallet → ephemeral agentDir mapping |
| M4 | Q1 2027 | Parallel dispatch (broadcast group) |
| M5-6 | Q2 2027 | Reverse-register + ClawHub publish |

> RFC: `clawhub.ai/rfc/agent-store-bridge` — sunum sonrası açılacak

> [Visual: integration architecture diagram with green "BRIDGE PLUGIN" box in the center, connecting Agent Store on the left (gold) to OpenClaw on the right (purple). TypeScript code snippet visible on a side panel. Roadmap timeline at the bottom with 6 milestones marked.]

<!--
[22:00-25:00] "Burada dürüst olayım — sunumun en kritik anlarından biri.

Bugünkü Agent Store standalone. Claude API'yi DOĞRUDAN çağırıyor.
OpenClaw runtime'ı kullanmıyor. Code'da `backend/pkg/claude/client.go`
direkt Anthropic'e gidiyor.

Bu tasarım kararı: önce ürünü valide ettim. Kullanıcılar agent kart'ları
seviyor mu? Guild Master gerçekten faydalı mı? On-chain credit ekonomisi
anlamlı mı? Foundation iyi olunca OpenClaw bridge geldi.

v2 milestone'um bu plugin: agent-store-bridge. Custom channel olarak
kayıt oluyor, Guild Master output'unu zod-validated team profile'ına
parse ediyor, mapping rules ile OpenClaw bindings'e çeviriyor,
sessions_spawn chain'i tetikliyor.

Roadmap 6 milestone: M1-M2 Q4 2026, M3-M4 Q1 2027, M5-M6 Q2 2027.
RFC dokümanı 600 satır, sunum sonrası ClawHub forum'unda açılacak.
Katkı isteyen developerlar için entry point.

Bugün size mimarisini gösterdim, kodu yarın yazılacak. Şimdi bugün
çalışan kısmı — Agent Store standalone'unu — canlı görelim."
-->

---

# DEMO

`docker compose up -d --build` → `http://localhost`

**Akış (~7 dk):**

1. 🛒 **Store** — agent kart grid (pixel-art + rarity)
2. 🦊 **Wallet connect** — MetaMask sign → JWT
3. 📚 **Library** → bir Wizard agent detayı
4. 🤖 **Guild Master** → "Login akışı için takım öner" → 3 agent suggest ⭐
5. ➕ **Add to Legend** → DAG hazır gelir
6. ▶️ **Execute** → 3 node sırayla çalışır → final output ⭐
7. (Opsiyonel) **Card Editor** → split-view live edit

> v2 bridge'de bu akışın altında OpenClaw runtime olacak.
> Bugün standalone — yarın mimari aynı, dispatch farklı.

> [Visual: large central "▶ DEMO" with subtle gradient glow on a dark stage backdrop. Surrounding it 3 small screenshot thumbnails: Store grid (left), Guild Master suggest (center-bottom), Legend DAG (right). Captures sense of "live walkthrough about to happen".]

<!--
[25:00-32:00] CANLI DEMO — 7 dakika.

(Tarayıcıyı aç, http://localhost.)
"Store grid: her kart bir prompt + pixel-art karakter + rarity.
8 karakter tipi var, 5 nadirlik kademesi. Renk = kategori sezgisi."

(Connect Wallet → MetaMask sign.)
"3 saniyede JWT alıyoruz. Wallet = identity. OpenClaw'da agent başına
auth-profile vardı; burada kullanıcı başına cüzdan."

(Library → Wizard agent → detail.)
"Library kütüphanem. Bu Wizard backend agent. Stats radar chart, prompt
preview, mini chat — denenebilir. Şimdi asıl olaya geçelim — Guild
Master'a."

(Guild Master ekranı, problem yaz: 'Web app login akışı: backend + frontend + security'.)
"Suggest. 5 saniyede LLM cevap veriyor: Wizard backend, Artisan frontend,
Guardian security. Her birinin neden seçildiği yazılı, confidence skoru
var. Bridge v2'de bu üç agent ID'si OpenClaw bindings'e dispatch olacak."

(Add to Legend.)
"Direkt DAG editöre geçti, üç node bağlanmış geldi. Per-node model
seçiyorum: Wizard'a sonnet, Artisan'a haiku, Guardian'a opus. Toplam
14 kredi. Krediler on-chain — Monad testnet."

(Execute basıyorum.)
"Topological sort, sırayla yürüyor. Wizard 8 saniye, Artisan 4, Guardian
12. Her birinin çıktısı sonrakine input. Final çıktı: bir login akış
spec'i, kod taslağı, güvenlik kontrol listesi — hepsi tek dokümanda.
Krediler on-chain düştü."

(7 dk sonu.)
"Bu OpenClaw multi-agent'ın görsel, LLM-driven, web-native versiyonu.
Yarın bridge plugin ile altında OpenClaw runtime'ı çalışacak.

YEDEK PLAN: demo herhangi bir noktada fail olursa hemen yedek videoya
geç. 'Demo tanrılarını kızdırmamak için yedek videoyu izleyelim' deyip
oynatıcıya geç. 90 saniye, aynı akışı özetliyor."
-->

---

# Çıkarımlar + Sıradaki

🧱 **OpenClaw multi-agent** alttaki sağlam zemini sağlıyor — izolasyon, routing, security
🎮 **Agent Store** üstündeki ürün katmanını dolduruyor — marketplace, UX, economy
🌉 **Bridge plugin v2** dispatch zincirini OpenClaw'a açacak (Q4 2026)
📜 **VISION'ın bilgeliği:** core lean kalsın, üst katman ayrı yazılsın
🤝 **Birlikte = tam ürün:** marketplace + isolation + economy + UX

---

**Linkler:**
- 🐙 Repo: `github.com/furkan-brk/Agent-Store-Web`
- 📋 RFC: `clawhub.ai/rfc/agent-store-bridge` (yakında)
- 📊 Slaytlar: `[Gamma link]`
- 📚 OpenClaw multi-agent: `docs.openclaw.ai/concepts/multi-agent`

## Sorular?

> [Visual: final layered stack diagram, polished version — same as title slide but with green "BRIDGE" layer now thicker and labeled "v2 milestone" with a small clock icon. Below the stack: 4 URLs in monospace font on a single line. Top of slide: a small Captain Claw sword/anchor emblem in gold.]

<!--
[32:00-35:00] "Sonuç — 5 madde:

OpenClaw multi-agent foundation'u sağlıyor — izolasyon ve routing
güvencesi. VISION 'core lean' diyor, üst katmanı dışarı bırakıyor.
Ben Agent Store ile o üst katmanı yazdım — marketplace, UX, gamification,
on-chain economy. Bridge plugin v2 ile dispatch zincirini OpenClaw'a
açacağım. Birlikte: marketplace + isolation + economy + UX = tam ürün.

Bunu YALNIZ yapmak istemiyorum. RFC sunum sonrası açılacak. Katkı
isteyen, denemek isteyen, kendi multi-agent ürün katmanını yazan herkes —
DM açık, repo public, foruma gelin.

Multi-agent dünyası hâlâ erken. Birlikte daha hızlı gideriz.

Sorular?"

OLASI Q&A SORULARI VE CEVAPLARI: qa-prep.md
- "Bugün OpenClaw kullanıyor mu?" → Hayır, standalone; bridge v2
- "Niye direkt plugin değil?" → On-chain economy ve Postgres schema
  plugin sınırlarını aşar; standalone başlangıç sonra hibrit
- "VISION'ı çiğnemiyor musun?" → 'as a default architecture' — opt-in,
  default değil; felsefe yaşatılıyor
- "Hibrit mı, OpenClaw'a tam taşıyacak mı?" → Hibrit; data + UX Agent
  Store'da, isolation + dispatch OpenClaw'da
- "5 saniyede özetle" → "OpenClaw'ın multi-agent zeminin üstüne son-
  kullanıcı için web ürün katmanı"
-->

---
