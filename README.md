# Agent Store

Agent Store, AI agent prompt'larını keşfetme, üretme, kütüphaneye ekleme ve
workflow içinde çalıştırma deneyimini oyunlaştıran full-stack bir platformdur.

Frontend Flutter Web, backend Go mikroservisleri, veri katmanı PostgreSQL +
Redis, on-chain tarafı ise Monad Testnet üzerinde Solidity kontratları ile
çalışır.

## İçerik

- [Öne Çıkan Özellikler](#öne-çıkan-özellikler)
- [Mimari Özeti](#mimari-özeti)
- [Built to integrate with OpenClaw](#built-to-integrate-with-openclaw)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Geliştirme Modları](#geliştirme-modları)
- [API Özeti](#api-özeti)
- [Test ve Kalite](#test-ve-kalite)
- [Dokümantasyon Haritası](#dokümantasyon-haritası)

## Öne Çıkan Özellikler

- Prompt bazlı agent marketplace (listeleme, filtreleme, kategori, trending)
- Wallet tabanlı auth akışı (nonce + signature + JWT)
- Agent kart sistemi (type, rarity, trait, stat, görsel üretim)
- Library ve kredi akışları
- Guild + Guild Master yardımcı akışları
- Mission ve Legend workflow editörü/çalıştırıcısı
- Agent Card Editor (canlı önizleme, autosave, undo/redo, export)

## Mimari Özeti

```text
Frontend (Flutter Web)
	|
	v
Gateway (Go, :8080)
	|-- authsvc (:8081)
	|-- agentsvc (:8082)
	|-- aipipelinesvc (:8083)
	|-- guildsvc (:8084)
	|-- workspacesvc (:8085)
	|
	+-- postgres (:5432 container, :5433 host)
	+-- redis (:6379)
```

## Built to integrate with OpenClaw

Agent Store, [OpenClaw](https://docs.openclaw.ai) multi-agent foundation'ının
üstüne **modern ürün katmanı** olarak tasarlandı. Yani:

- **OpenClaw çözer:** per-agent isolation, deterministic routing, security primitives
- **Agent Store ekler:** marketplace, web UX, gamification, on-chain economy

OpenClaw'ın `VISION.md` dokümanı bu üst katmanı **kasıtlı olarak** core'a almaz
("core lean kalsın"). Agent Store tam o boşluğu doldurur.

### Stack mimarisi

```text
👤 User (browser)
   ↓
🎮 Agent Store (this repo)
   • Flutter Web (Vercel)
   • Go microservices behind API gateway
   • Postgres + Redis
   • Solidity contracts (Monad testnet)
   ↓
🌉 Bridge plugin (v2 milestone — RFC açık)
   • Team profile → OpenClaw bindings
   • Legend DAG → sessions_spawn chain
   • Wallet → ephemeral agentDir
   ↓
⚙️ OpenClaw multi-agent runtime (optional, opt-in)
   • routing precedence
   • per-agent isolation
   • per-agent sandbox
```

### Mevcut durum (v3.6) ve roadmap

| Faz | Durum | Açıklama |
|-----|-------|----------|
| **v1 — Standalone** | ✅ Bugün | Agent Store Claude API'yi doğrudan çağırıyor; OpenClaw entegrasyonu YOK |
| **v2 — Bridge plugin** | 🔜 Q4 2026 | `agent-store-bridge` plugin → OpenClaw'a dispatch |
| **v3 — Reverse-register** | 🗓 Q2 2027 | OpenClaw agentlarını Agent Store library'sine register |

### Agent Store ↔ OpenClaw mapping

| Agent Store özelliği | OpenClaw primitif'i |
|----------------------|---------------------|
| Agent kart + character_type + rarity | `agentId` + workspace metadata |
| Library + Store | `agents.list` + ClawHub |
| Wallet auth (JWT) | `auth-profiles.json` per agent |
| **Guild Master** (LLM team selector) | bindings (deterministic, post-LLM) |
| **Legend DAG** (visual workflow) | `sessions_spawn` chain |
| Card Editor | `AGENTS.md` per workspace |
| Per-node model (haiku/sonnet/opus) | `tools.allow/deny` + agent runtime |

### Bridge plugin RFC

Plugin spesifikasyonu: bkz. [`docs/rfc/agent-store-bridge.md`](docs/rfc/agent-store-bridge.md)
(Clawcon sunumu öncesi taslak; sunum sonrası ClawHub'da forum thread'i açılır.)

Anahtar tasarım kararları:
- **Opt-in:** Bridge yüklenmezse Agent Store standalone çalışmaya devam eder
- **Loose coupling:** Plugin sınırı OpenClaw versiyon güncellemelerine dayanıklı
- **Honest abstractions:** Manager-of-managers değil — VISION'a uyumlu

### Niye OpenClaw?

Agent Store kendi başına çalışan bir multi-agent ürün. Peki niye bridge?

1. **Self-hosted enterprise:** Kendi OpenClaw deployment'ında Agent Store kullanmak
2. **Sandbox/isolation güvencesi:** OpenClaw'ın per-agent docker sandbox'ını miras almak
3. **ClawHub plugin'leri:** OpenClaw plugin ekosistemini Agent Store kullanıcılarına açmak
4. **Multi-tenant SaaS:** Tenant başına ayrı OpenClaw deployment

Standalone Agent Store yeterli olan kullanıcı için bridge zorunlu değil — hibrit tasarım.

---

## Hızlı Başlangıç

### Gereksinimler

- Docker + Docker Compose
- Go 1.22+
- Flutter 3.x
- Node.js 18+

### 1) Repo ve ortam değişkenleri

```bash
git clone https://github.com/furkan-brk/Agent-Store-Web.git
cd Agent-Store-Web
cp .env.example .env
```

En azından aşağıdaki alanları doldurun:

- `JWT_SECRET`
- `CLAUDE_API_KEY` (AI özellikleri için)
- `CREDITS_CONTRACT_ADDRESS` (on-chain kredi akışları için)

### 2) Full stack'i Docker ile kaldır

```bash
docker compose up -d --build
```

Kontrol URL'leri:

- Frontend: `http://localhost`
- API Gateway health: `http://localhost:8080/health`
- Full health: `http://localhost:8080/health/full`

### 3) Flutter hot reload (opsiyonel, hybrid)

```bash
docker compose up -d postgres redis gateway authsvc agentsvc aipipelinesvc guildsvc workspacesvc
docker compose stop frontend

cd agent_store
flutter run -d chrome
```

## Geliştirme Modları

- Tam Docker (prod-benzeri): CI/CD davranışını en iyi yansıtan mod
- Hybrid (backend Docker + Flutter hot reload): günlük geliştirme için en hızlı mod

Detaylı adımlar için: [DEVELOPMENT.md](DEVELOPMENT.md)

## API Özeti

Tüm frontend çağrıları gateway üzerinden gider: `http://localhost:8080/api/v1/...`

Ana route grupları:

- `/api/v1/auth/*` (nonce, verify)
- `/api/v1/agents/*` (listeleme, detay, üretim, chat, fork, purchase, rating)
- `/api/v1/user/*` (library, credits, profile, missions, legend)
- `/api/v1/guilds/*` ve `/api/v1/guild-master/*`
- `/api/v1/leaderboard`, `/api/v1/users/:wallet`, `/api/v1/images/*`

Detaylı endpoint tablosu için: [GUIDE.md](GUIDE.md)

## Test ve Kalite

### Backend

```bash
cd backend
go vet ./...
go test ./... -race -coverprofile=coverage.out -covermode=atomic
```

### Frontend

```bash
cd agent_store
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

### Smart Contracts

```bash
cd contracts
npm install
npm run compile
npm run test
```

## Dokümantasyon Haritası

- [GUIDE.md](GUIDE.md): Detaylı mimari, servis ve API rehberi
- [DEVELOPMENT.md](DEVELOPMENT.md): Lokal geliştirme akışları ve debug
- [CLAUDE.md](CLAUDE.md): Sprint geçmişi, feature notları, takım çalışma kaydı

## Lisans

MIT - bkz. [LICENSE](LICENSE)
