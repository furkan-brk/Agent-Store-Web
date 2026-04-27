# Agent Store

Agent Store, AI agent prompt'larını keşfetme, üretme, kütüphaneye ekleme ve
workflow içinde çalıştırma deneyimini oyunlaştıran full-stack bir platformdur.

Frontend Flutter Web, backend Go mikroservisleri, veri katmanı PostgreSQL +
Redis, on-chain tarafı ise Monad Testnet üzerinde Solidity kontratları ile
çalışır.

## İçerik

- [Öne Çıkan Özellikler](#öne-çıkan-özellikler)
- [Mimari Özeti](#mimari-özeti)
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
