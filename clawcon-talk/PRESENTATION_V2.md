# GAMMA PROMPT V2 — Agent Store with OpenClaw
# Digital_Sorcery estetiği · 10 slayt · 35 dk
#
# KULLANIM:
# 1. "=== GAMMA BAŞLANGICI ===" satırından sonrasını kopyala
# 2. gamma.app → "Generate from text" → yapıştır
# 3. Gamma açıldıktan sonra TEMA AYARLARI'nı uygula (aşağıya bak)
#
# ─────────────────────────────────────────────
# TEMA AYARLARI (Gamma → Themes → Custom)
# ─────────────────────────────────────────────
#   Background:   #0a0612   (derin mor-siyah void)
#   Surface:      #12082a   (kart/kod-blok zemini)
#   Heading:      #f5c842   (altın — büyük başlıklar)
#   Body text:    #e2d9f3   (açık mor-beyaz)
#   Accent 1:     #7c3aed   (OpenClaw moru — foundation)
#   Accent 2:     #f59e0b   (Agent Store altını — product)
#   Accent 3:     #10b981   (Bridge yeşili — bağlantı)
#   Code font:    JetBrains Mono
#   Body font:    Inter veya Manrope
#   Heading font: Inter ExtraBold
#
# ─────────────────────────────────────────────
# GLOBAL AI IMAGE STİL PROMPTU
# (Gamma image generation'da her görsele önce bunu ekle)
# ─────────────────────────────────────────────
#   dark fantasy RPG aesthetic, deep purple-black void background (#0a0612),
#   dramatic volumetric god-rays in purple and gold,
#   glowing arcane runes, energy particles, magical architecture,
#   premium dark UI with gold trim and purple glow borders,
#   cinematic composition, NO faces, NO people, NO text overlays,
#   abstract and symbolic, inspired by premium game UI art
#
# ─────────────────────────────────────────────
# NOTLAR
# ─────────────────────────────────────────────
#   — Her "---" = yeni slayt
#   — [VISUAL: ...] = AI görsel prompt
#   — <!-- --> = konuşma notları → Gamma Notes paneli
#   — S6 ve S9 için gerçek Agent Store screenshot kullan

=== GAMMA BAŞLANGICI — BURADAN AŞAĞISINI KOPYALA ===

---

# Agent Store **with** OpenClaw
## Multi-Agent'ın eksik yarısını tamamlıyorum.

**Furkan Berk** · Clawcon · 2026

[VISUAL: A towering ancient fortress carved in deep purple obsidian, viewed from far below. The foundation glows with intricate purple runes labeled "OpenClaw". Above it, floating and radiant, a golden city of holographic agent cards and pixel-art marketplace windows labeled "Agent Store". Between them: a thin luminous green conduit, the bridge. Dramatic god-ray lighting. Dark void sky. Cinematic, no people, no text]

<!--
[0:00–1:00]
"Selam Clawcon. Bugün size bir framework anlatmayacağım.
OpenClaw'ın üstüne kurduğum ürün katmanını anlatacağım: Agent Store.

Tek başına bir ürün değil — OpenClaw'la BERABER çalışmak üzere tasarlandı.
En altta OpenClaw multi-agent runtime. Ortada bridge. Üstte Agent Store.
En üstte kullanıcı.

Bu sunum o stack'in nasıl ortaya çıktığının hikayesi.
10 slayt, 35 dakika, sonunda canlı demo."
-->

---

# İki framework yetmez. **İki katman lazım.**

Multi-agent dünyasında herkes routing'i çözüyor.
Hiç kimse son kullanıcıya **ürün** vermiyor.

🔧 **Orchestration Motoru**
İzolasyon · routing · security · sessions
→ *OpenClaw bunu mükemmel çözüyor*

🎮 **Ürün Katmanı**
Marketplace · UX · gamification · on-chain economy
→ *VISION.md bu alanı bilinçli olarak dışarıda bırakıyor*

> O boşluğu ben doldurdum. Adı: **Agent Store.**

[VISUAL: A dramatic split-screen divided by a vertical crack of emerald green energy. LEFT: a dark purple dungeon engine room — glowing server racks, abstract terminal streams, rune-covered routing trees, labeled "OpenClaw". RIGHT: a warm golden marketplace — floating agent portrait cards, pixel-art characters, glowing coin particles, labeled "Agent Store". The green crack in the center is the connection point. No people, cinematic dark fantasy]

<!--
[1:00–4:00]
"Multi-agent dünyasında bir paradoks var: framework'ler mükemmel izolasyon sunuyor.
Ama son kullanıcı için marketplace, gamification, on-chain economy yok.
Çünkü framework'ler bu katmanı core'a koymuyor — koymalarına gerek de yok.

OpenClaw'ın VISION dokümanı bu konuda çok net: core lean kalsın, üst katman ayrı yazılsın.
Bu kısıtlayıcı değil. Bu bir tasarım kararı.

Ben de tam o ikinci katmanı — ürün katmanını — yazdım.
Bu sunum hem OpenClaw'ın multi-agent gücünü hem de o gücün üstüne
ürün nasıl kurulur sorusunu yanıtlayacak."
-->

---

# Hiç sürpriz yok. **Deterministik zemin.**

**Tek Gateway. N izole agent.** Her birinin 5 boyutta izolasyonu var — hiç LLM yok.

| Boyut | Dosya |
|-------|-------|
| 📁 Workspace | `~/.openclaw/workspace-<agent>/` |
| 🔐 Auth profile | `agentDir/auth-profiles.json` |
| 💾 Session store | `agentDir/sessions/` |
| 🛠 Tool policy | `tools.allow / tools.deny` per agent |
| 📦 Sandbox | `off` / `docker` per agent |

**8-Kademeli Routing — her mesaj tek bir yere gider:**

| 01 peer | 02 parentPeer | 03 guild+roles | 04 guild |
|---------|---------------|----------------|----------|
| 05 teamId | 06 accountId | 07 channel | **08 default** |

> Aynı input her zaman aynı agent'a gider. Test edilebilir. Debug edilebilir. Güvenli.
> Agent Store yarın bu güvenleri miras alacak.

[VISUAL: A mystical underground vault with 5 sealed stone chambers stacked vertically, each pulsing with purple runes representing an isolation dimension. On the right, an 8-tier decision pyramid carved in obsidian — each level glows brighter toward the top (peer match) and dims toward the base (default). Ancient arcane architecture, magical data streams flowing between chambers, deep purple-gold palette, no people]

<!--
[4:00–9:00]
"OpenClaw multi-agent'ı 5 dakikada özetleyeceğim.

Her agent 5 boyutta izole: workspace, auth profile, session store, tool policy, sandbox.
Hepsi ayrı dosyalarda. agentDir paylaşmak yasak — zod schema seviyesinde enforce ediliyor.

Routing config-driven, deterministik. 8 kademeli precedence:
en spesifik (peer match) → en genel (default agent).
Aynı input, her zaman, aynı agent. Hallüsinasyon yok.

Bu primitifler Agent Store'un üstüne kurulduğu zemin.
Bugün bridge yok — bridge v2 milestone'unda bu güvenleri devralacak."
-->

---

# VISION bir kapıyı **açık bıraktı.**

> *"What we will not merge: Agent-hierarchy frameworks,*
> *marketplace orchestration, heavy UX layers —*
> ***as a default architecture.***"
>
> — VISION.md, satır 106–118

**Üç kelime her şeyi değiştiriyor:** `"as a default architecture"`

---

🚫 **Yasaklamıyor**
Orchestration'ı engellemez. Yalnızca core'a almaz.

📐 **Sınırı Biliyor**
Üst katmanı ayrı proje olarak yazmayı teşvik eder.

✅ **Kapıyı Açık Bırakıyor**
Agent Store tam bu kapıdan geçiyor —
çelişmeden, **üstüne kurarak.**

[VISUAL: An ancient illuminated manuscript open on a dark altar, its pages glowing with amber arcane text. The phrase "as a default architecture" radiates golden light as if enchanted. Above the book floats a tall golden archway, its door wide open with brilliant light pouring through — symbolizing the strategic opening VISION intentionally leaves. Deep purple shadows, mystical candlelight, no people]

<!--
[9:00–11:00] — KRİTİK GEÇİŞ (kelime kelime hazırla — vision-pivot-script.md)

(Slayt geçer. 3 saniye sessizlik. Quote okunur.)

"'as a default architecture' — üç kelime.
VISION son-kullanıcı UX'ini REDDETMIYOR.
Diyor ki: core'a koymayacağız. Üst katman ayrı yazılsın.

Ben de yazdım. Agent Store.
OpenClaw'ın üstüne kurulan modern ürün katmanı.
VISION beni tamamlayıcı olmaya yönlendirdi. Şimdi o katmanı görelim."
-->

---

# Her katmanın **görevi var.**

```
👤  USER / tarayıcı
 │
🎮  Agent Store
 │  Flutter Web + Go mikroservisleri
 │  authsvc · agentsvc · guildsvc · workspacesvc
 │
🌉  Bridge Plugin v2          ← RFC açılıyor Q4 2026
 │  TeamProfile → bindings → sessions_spawn
 │
⚙️  OpenClaw Multi-Agent Runtime
    routing · isolation · sessions · auth-profiles
```

**Her özellik bir OpenClaw primitifine karşılık geliyor:**

| Agent Store | OpenClaw Primitifi |
|-------------|-------------------|
| Agent kart + rarity | `agentId` + workspace metadata |
| Wallet auth (JWT) | `auth-profiles.json` per agent |
| **Guild Master** | bindings (deterministik) |
| **Legend DAG** | `sessions_spawn` chain |
| Per-node model seçimi | per-agent model config |
| Library + Store | `agents.list` + ClawHub |

> Bridge plugin bu tablonun iskeleti — her satır bir mapping kuralı.

[VISUAL: A vertical cross-section of an arcane tower cut open from the side to reveal 4 glowing internal floors. Bottom floor radiates PURPLE with routing runes labeled "OpenClaw Runtime". Second floor is a thin luminous GREEN bridge layer labeled "Bridge Plugin v2". Third floor glows AMBER-GOLD labeled "Agent Store" with tiny floating UI cards. Top floor blazes WHITE-TEAL labeled "User". Magical energy currents flow between floors. Fantasy architecture, cinematic lighting, no people]

<!--
[11:00–16:00]
"Stack'i göstereyim. Kullanıcı tarayıcıdan giriyor.
Flutter Web frontend, API Gateway Go'da, beş mikroservis arkasında.

Aşağıda — bridge plugin katmanı.
Agent Store'un Guild Master ve Legend output'unu OpenClaw bindings'e dispatch ediyor.
v2 milestone'um. Hazır olduğunda kullanıcı arka planda OpenClaw'dan faydalanıyor.

En altta OpenClaw runtime: routing, isolation, sessions_spawn.

Sağdaki tablo kritik: hiçbir Agent Store özelliği boşlukta değil.
Wallet auth → auth-profile. Guild Master → bindings. Legend → sessions_spawn chain.
Bu mapping bridge plugin'in iskeleti.

Şimdi iki hero feature'ı göstereyim: Guild Master ve Legend."
-->

---

# Yanlış takımla **hiçbir iş bitmez.**

OpenClaw routing deterministik —
kim her zaman nereye gider **önceden biliniyor.**

Agent Store dinamik —
gelen **probleme göre** doğru takımı seçiyor.

---

**① Problem yaz**
`"Web app için login akışı: backend + frontend + security review"`

**② Guild Master analiz eder**
Problemi okur. Agent profillerini puanlar. Takımı oluşturur.

**③ Takım hazır**
🧙 **Wizard** — JWT impl · 🎨 **Artisan** — Login form · 🛡 **Guardian** — CSRF review
*Her agent için gerekçe + güven skoru*

**④ Add to Legend →**
Tek tık. DAG hazır.
Bridge v2'de bu üç agent ID → OpenClaw bindings'e dispatch.

[VISUAL: A grand circular war council chamber in dark stone with golden fixtures. At the center, a hovering arcane crystal orb pulses with intelligence (the Guild Master LLM). Surrounding it: 3 ornate hero portrait cards floating in the air — a purple-robed Wizard with glowing JWT rune, a rose-gold Artisan with design tools, a silver-armored Guardian with shield. Each card displays a glowing confidence percentage badge. Chamber walls are deep purple obsidian with golden trim. Cinematic lighting from above, no faces — only stylized card art]

<!--
[16:00–19:00]
"Guild Master sunumun kalplerinden biri.

Kullanıcı problem yazıyor — 'Login akışı, backend, frontend, security.'
LLM 5 saniyede 3 agentlık takım öneriyor: Wizard backend, Artisan frontend, Guardian security.
Her birinin neden seçildiğine dair gerekçe. Confidence skoru.

OpenClaw'da routing deterministikti — 'wallet X her zaman family agent'a gitsin.'
Agent Store'da DİNAMİK: aynı kullanıcı bir saniye backend takımı, bir saniye design takımı.

Bridge plugin v2'de bu üç agent ID OpenClaw bindings'e çevriliyor.
LLM-driven SEÇİM üstte, deterministik ROUTING altta.
Halüsinasyon seçimde olabilir ama dispatch deterministik. İki dünyanın en iyisi.

'Add to Legend' bir sonraki hero feature'a taşıyor."
-->

---

# Kod yazma. **Çiz.**

OpenClaw'da `sessions_spawn` zincirini kod olarak yazarsın.
Agent Store'da **canvas üzerinde sürüklersin.**

```
🟢 START
  ↓
🟣 Wizard    (sonnet · 3 cr)
  ↓
🩷 Artisan   (haiku  · 1 cr)
  ↓
⬜ Guardian  (opus   · 10 cr)
  ↓
🟡 END  ──  Toplam: 14 credits  ·  on-chain (Monad testnet)
```

✅ Drag-drop DAG — start · mission · agent · guild · end node tipleri
✅ Topological execute + cycle detection + undo/redo
✅ Per-node model: **haiku 1cr · sonnet 3cr · opus 10cr**
✅ Her execution on-chain kayıt

> Bridge v2'de her node → bir `sessions_spawn` çağrısına dönüşür.
> Canvas, OpenClaw'ın görsel arayüzü olacak.

[VISUAL: An ancient glowing quest map unrolled on a dark surface. A left-to-right path winds through 5 radiant waypoints connected by trails of golden light. First waypoint: emerald green (START). Second: deep purple with "3cr" rune (Wizard). Third: rose-pink with "1cr" (Artisan). Fourth: silver-gray with "10cr" (Guardian). Fifth: blazing amber-gold (END) with "14cr" floating above. Parchment texture, magical particles drifting, dark fantasy atmosphere, no people]

<!--
[19:00–22:00]
"Legend, sunumun ikinci hero feature'ı.
OpenClaw'ın sequential pipeline'ının görsel hâli.

Drag-drop DAG editor — node'ları bağlıyorsun, execute, topological sort çalışıyor, sırayla yürür.

Per-node model seçimi: haiku 1 kredi, sonnet 3, opus 10.
Kullanıcı her node'da opus yapmaktan caydırılıyor.
Krediler on-chain — Monad testnet üzerinde.

Bridge plugin v2'de canvas'taki her node bir sessions_spawn çağrısına çevriliyor.
Geliştirici sessions_spawn yazmak yerine canvas'ta çiziyor. Aynı sonuç, başka abstraction.

Şimdi bu sistemin bugünkü gerçeğini konuşalım."
-->

---

# Sana bir şeyi **itiraf etmem gerekiyor.**

> ⚠️ **Bugün:** Agent Store standalone çalışıyor — Claude API direct.
> 🎯 **Hedef:** `agent-store-bridge` plugin → OpenClaw'a dispatch.

```typescript
export default definePlugin({
  id: "agent-store-bridge",
  channels: {
    "agent-store": {
      ingest: async (msg, ctx) => {
        const team = await callGuildMasterAPI(msg);
        return executeAsBindings(team);
        // ← OpenClaw'a dispatch
      }
    }
  }
});
```

| Milestone | Tarih | Kapsam |
|-----------|-------|--------|
| M1 | Q4 2026 | Plugin scaffold + custom channel |
| M2 | Q4 2026 | Sequential dispatch (TeamProfile → bindings) |
| M3 | Q1 2027 | Wallet → ephemeral agentDir mapping |
| M4 | Q1 2027 | Parallel dispatch (broadcast group) |
| M5 | Q2 2027 | Reverse-register (Agent Store → ClawHub) |
| M6 | Q2 2027 | ClawHub publish + public RFC |

> 📋 RFC: **clawhub.ai/rfc/agent-store-bridge** — sunum sonrası açılacak · katıl, yorum yap

[VISUAL: A glowing stone archway portal at the center of a dark chamber. Left side of the portal blazes with golden Agent Store energy — floating card fragments, UI elements. Right side pulses with purple OpenClaw energy — routing runes, session trees. A thin but visible green beam of light passes through the arch — the bridge being built. Above the arch: 6 milestone markers carved in stone, first two glowing brightly, the rest awaiting their activation. Construction in progress, magical but unfinished, hopeful atmosphere, no people]

<!--
[22:00–25:00]
"Burada dürüst olayım — sunumun kritik anlarından biri.

Bugünkü Agent Store standalone. Claude API'yi doğrudan çağırıyor.
OpenClaw runtime'ı kullanmıyor.

Bu bir tasarım kararı: önce ürünü valide ettim.
Kullanıcılar agent kartları seviyor mu? Guild Master faydalı mı? On-chain ekonomi anlamlı mı?
Evet, evet, evet. Şimdi foundation geliyor.

v2 milestone: agent-store-bridge plugin.
Custom channel kaydı, Guild Master output'unu zod-validated team profile'a parse eder,
mapping rules ile OpenClaw bindings'e çevirir, sessions_spawn chain'ini tetikler.

RFC dokümanı 600 satır. Sunum sonrası ClawHub'da açılacak.
Katkı isteyen her developer için entry point.

Şimdi bugün çalışan kısmı — standalone Agent Store'u — canlı görelim."
-->

---

# DEMO

**http://localhost → canlı çalışıyor ✅**

---

**01 🛒 Store**
Agent kart grid — pixel-art karakterler · rarity sistemi · trending row

**02 🔗 Wallet Connect**
MetaMask sign → JWT · 3 saniyede kimlik doğrulama

**03 🤖 Guild Master** ⭐
`"Login akışı için takım öner"` → 5 saniyede 3 agent suggest

**04 ▶️ Legend Execute** ⭐
3 node sırayla çalışır → topological sort → final output → krediler on-chain düşer

---

> Yarın bu akışın altında **OpenClaw runtime** olacak.
> Mimari aynı — dispatch farklı.

[VISUAL: A grand dark fantasy arena stage seen from audience perspective. A single dramatic spotlight illuminates center stage. The word "DEMO" is etched in massive golden arcane letters — glowing, magical, theatrical. Around the letters: three floating preview thumbnails in ornate frames showing abstract UI (marketplace grid left, agent suggest center, DAG canvas right). Smoke rises from the stage floor. Purple atmosphere, anticipatory energy, cinematic, no people]

<!--
[25:00–32:00] — 7 DAKİKA CANLI DEMO
(Walkthrough: demo/walkthrough.md adım adım izle)

Store → Wallet → Library → Guild Master → Add to Legend → Execute → (Opsiyonel) Card Editor

Her hero anında bridge v2 bağlantısını bir cümleyle kur:
"Bridge v2'de bu adım OpenClaw sessions_spawn'a dispatch olacak."

YEDEK: Demo fail olursa → "Demo tanrılarını kızdırmamak için yedek videoyu izleyelim."
90 saniyelik video, aynı akış, dock'ta hazır.
-->

---

# Bir framework **zemin hazırladı.**
# Bir ürün **üstünde yaşadı.**

---

🧱 **OpenClaw** — zemin
İzolasyon · deterministik routing · security
Framework'ün yaptığını framework yaptı. Mükemmel.

🎮 **Agent Store** — ürün
Marketplace · UX · gamification · on-chain economy
Ürünün yaptığını ürün yaptı. Hızlı, odaklı, valide edildi.

🌉 **Bridge Plugin v2** — bağlantı
Q4 2026. İki dünya birleşiyor.

📜 **VISION'ın bilgeliği**
Core lean kalsın, üst katman ayrı yazılsın —
Agent Store bu prensibin **living proof'u.**

---

> **Birlikte = tam ürün.**
> Marketplace + isolation + economy + UX.
> Eksik parça yok.

---

📦 `github.com/furkan-brk/Agent-Store-Web` — *(sunum sonrası public)*
📋 `clawhub.ai/rfc/agent-store-bridge` — *(Q4 2026 · katıl · yorum yap)*
📚 `docs.openclaw.ai/concepts/multi-agent`

## Sorular?

[VISUAL: The same towering obsidian fortress from Slide 1, now seen in full glory. The purple foundation (OpenClaw) blazes with strong runes. The golden floating city (Agent Store) radiates warm light. The green conduit bridge between them has grown thicker, fully active, energy flowing freely in both directions. Stars fill the sky above. The scene feels triumphant and complete — a finished architecture. Small glowing inscription at the base: "Clawcon 2026". Cinematic wide shot, hopeful but still dark-fantasy, no people]

<!--
[32:00–35:00]
"Sonuç — tek bir cümle:

OpenClaw'ın multi-agent zeminin üstüne son kullanıcı için web ürün katmanı yazdım.
İki taraf birbirini tamamlıyor.

Bunu yalnız yapmak istemiyorum.
RFC sunum sonrası açılacak. Katkı isteyen, denemek isteyen,
kendi multi-agent ürün katmanını yazan herkes — DM açık, repo public, foruma gelin.

Multi-agent dünyası hâlâ erken. Birlikte daha hızlı gideriz.

Sorular?"

OLASI Q&A: qa-prep.md
— "Bugün OpenClaw kullanıyor mu?" → Hayır, standalone; bridge v2
— "VISION'ı çiğnemiyor musun?" → 'as a default architecture' — opt-in, default değil
— "Niye önce standalone?" → Ürün validasyonu önce, foundation entegrasyonu sonra
— "5 saniyede özetle" → "OpenClaw'ın zeminin üstüne son-kullanıcı için web ürün katmanı"
-->
