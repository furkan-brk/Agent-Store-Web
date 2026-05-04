# Twitter/X Duyuru Thread

> **Sunum öncesi 1 hafta** atılmak üzere. 12 tweet, ~5dk okuma süresi.
> Hashtags: `#Clawcon` `#OpenClaw` `#MultiAgent` `#AgentStore`
> Mention: `@openclawhq` (varsa), Clawcon resmi hesabı

---

## 🎙 Sunum öncesi promo (T-7 gün)

### Tweet 1/12 (HOOK)

```
Multi-agent ürünler için iki kritik katman lazım:

1. Orchestration motoru → izolasyon, routing, security
2. UX/marketplace katmanı → kullanıcı deneyimi, economy

OpenClaw birinciyi olağanüstü çözüyor.
İkinciyi VISION'ı gereği core'a almıyor.

Ben ikinciyi yazdım. 🧵👇

#Clawcon
```

> [Visual: layered stack diagram screenshot — OpenClaw foundation + Agent Store top layer]

---

### Tweet 2/12

```
Bu sunumum Clawcon'da:

"Agent Store with OpenClaw"

OpenClaw multi-agent'ın üstüne kurulu modern ürün katmanı:
- Web-native marketplace
- Wallet auth + on-chain credits
- LLM-driven team selection
- Visual DAG workflow editor
- Pixel-art gamification

Tarih: [TARIH] · Saat: [SAAT]
```

---

### Tweet 3/12 (THE PROBLEM)

```
Multi-agent dünyasında bir paradoks var:

Framework'ler harika izolasyon sunuyor.
Ama son kullanıcı için marketplace, gamification, on-chain economy YOK.

Çünkü framework'ler bu katmanı core'a koymuyor.
"core lean kalsın" — VISION.md:113.

Doğru tercih ama boşluk bırakıyor.
```

---

### Tweet 4/12 (THE SOLUTION INTRO)

```
Agent Store, tam o boşluk için var.

OpenClaw ile çelişmiyor — onun üstünde.

Stack:
👤 USER
🎮 Agent Store (Flutter + Go + Solidity)
🌉 Bridge plugin (v2)
⚙️ OpenClaw multi-agent runtime
🔗 Postgres + Monad on-chain
```

> [Visual: stack architecture diagram]

---

### Tweet 5/12 (FEATURE 1)

```
🎮 Pixel-art karakter sistemi

Her prompt → AI analiz → 8 karakter tipinden biri:
🧙 Wizard (backend)
👑 Strategist (PM)
🔮 Oracle (data)
🛡 Guardian (security)
🎨 Artisan (frontend)
+ 3 daha

5 nadirlik kademesi: Common → Legendary

Cosmetic değil — kategori, koleksiyon, leaderboard buna dayanıyor.
```

> [Visual: row of pixel-art character cards]

---

### Tweet 6/12 (FEATURE 2 — HERO)

```
🤖 Guild Master = LLM team selector

Sen: "Web app login akışı: backend + frontend + security"
Guild Master:
  ✓ Wizard → JWT impl
  ✓ Artisan → Login form
  ✓ Guardian → CSRF/replay analiz
  + 3 mission + 4 step plan

Bridge v2'de bu seçim → OpenClaw bindings'e dispatch.
```

> [Visual: Guild Master suggest screenshot]

---

### Tweet 7/12 (FEATURE 3 — HERO)

```
🔧 Legend = Visual DAG workflow editor

OpenClaw'ın sequential `sessions_spawn` zincirinin görsel hâli.

✓ Drag-drop nodes
✓ Per-node model: haiku 1cr, sonnet 3cr, opus 10cr
✓ Topological execute + cycle detection
✓ Execution history, undo/redo, templates
✓ Krediler on-chain (Monad testnet)
```

> [Visual: Legend DAG screenshot with 3 connected agent nodes]

---

### Tweet 8/12 (HONESTY)

```
Dürüst olayım: bugünkü Agent Store standalone — Claude API'yi doğrudan çağırıyor.

Ama bu bir tasarım kararı:
1. Önce ürünü valide et (kullanıcılar agent kart'ları seviyor mu?)
2. Sonra altyapı genişlet (OpenClaw bridge)

v1 birinci faz. v2 = bridge plugin = OpenClaw'a dispatch.

Sunumda mimarisini göstereceğim.
```

---

### Tweet 9/12 (BRIDGE PLUGIN)

```
Bridge plugin v2 milestone:

→ Custom channel: `agent-store://`
→ Zod-validated team profile schema
→ Mapping: agent → OpenClaw agentId, DAG → sessions_spawn chain
→ Wallet → ephemeral agentDir
→ Reverse-register (v3): OpenClaw agentlarını Agent Store library'sine

RFC Q4 2026'da clawhub.ai'da açılacak. Katkı isteyene açık.
```

> [Visual: bridge plugin architecture diagram]

---

### Tweet 10/12 (DEMO TEASER)

```
Sunumda canlı demo:

1. http://localhost — Store grid
2. Connect MetaMask (Monad testnet)
3. Library → bir Wizard agent
4. Guild Master → "Login akışı için takım öner"
5. Add to Legend → DAG hazır
6. Execute → Wizard 8s, Artisan 4s, Guardian 12s
7. Final: spec + code + security checklist

Toplam ~5 dakika. Yedek video da hazır 😅
```

---

### Tweet 11/12 (PHILOSOPHY)

```
VISION.md'nin "core lean kalsın" pozisyonu beni kısıtlamadı, AÇTI.

Çünkü core orchestration'ı default'a koymadığı için Agent Store ortaya çıkabildi.

Eğer core'a girseydi her ürün aynı olurdu.

Bu felsefenin yaşatılması — sadece kelime olarak değil, ürün olarak.
```

---

### Tweet 12/12 (CTA)

```
Sunum sonrası:

✅ Agent Store repo public olacak: github.com/furkan-brk/Agent-Store-Web
✅ Bridge plugin RFC açılacak: clawhub.ai/rfc/agent-store-bridge
✅ Slaytlar paylaşılacak

Multi-agent ürün katmanı yazıyor musunuz? Tartışalım — DM'ler açık.

Görüşürüz Clawcon'da! 🚀

#Clawcon #OpenClaw #MultiAgent
```

---

## 🎬 Sunum sonrası tweet (T+0)

```
Clawcon'da bugün "Agent Store with OpenClaw" sunumum oldu! 🚀

Slaytlar: [Gamma link]
Repo: github.com/furkan-brk/Agent-Store-Web
Bridge plugin RFC: clawhub.ai/rfc/agent-store-bridge

Multi-agent ürün katmanı yazıyorsanız konuşmaktan mutluluk duyarım.

Sunumu kaçıranlar için kayıt: [link]

#Clawcon
```

---

## 🎯 Sunum öncesi 1 gün önce (T-1 gün) — short reminder

```
Yarın Clawcon'da:

"Agent Store with OpenClaw"
Multi-agent için ürün katmanı.

Saat [X], Salon [Y].

Canlı demo, yedek video, RFC taslağı — hepsi hazır.

[GIF: Captain Claw waving hello]
```

---

## 💡 Kullanım notları

1. **Tweet zamanlamaları:** T-7, T-3, T-1 günleri farklı angle'larla. Bu thread'in tamamı T-7'de atılır.
2. **Engagement:** Her tweet'in altına 3-5 yorum yap (kendi thread'in içinde — Twitter algoritması engagement bekliyor).
3. **Visual'lar:** Tweet 1, 4, 6, 7, 9 görsel beklesin. Diğerleri text-only OK.
4. **Hashtag stratejisi:** `#Clawcon` her tweet'te değil — ilk ve son'da. Algoritma fazla hashtag'i spam algılıyor.
5. **Mention etiği:** `@openclawhq` mention'ı bir kez (Tweet 1 veya 11). Spam görünmemek için.
6. **DM hazırlığı:** Thread sonrası gelecek DM'lere hazır şablon cevaplar:
   - "Plugin nasıl katkı veririm?" → RFC link + "M1 milestone'unda PR welcome"
   - "Agent Store'a kayıt nasıl?" → Vercel deploy URL + wallet onboarding
   - "Sunum kayıdı nerede?" → "Clawcon yayın olduğunda paylaşacağım"

## ⚠️ Tweet'lemeden önce kontrol

- [ ] Twitter handle gerçek (`@kullanici_adin`)
- [ ] Tarih + saat doğru
- [ ] Repo public yapıldı mı (Tweet 12 adresi çalışıyor mu)
- [ ] RFC link çalışıyor mu (`clawhub.ai/rfc/agent-store-bridge`)
- [ ] Görseller hazır (en az Tweet 1, 4, 6, 7, 9)
- [ ] Sunum tarih/saat resmi onaylı mı
- [ ] Clawcon resmi hesabını mention için isim doğru mu
