# Agent Store

AI Agent prompt paylaşım platformu. Promptları keşfet, pixel-art karakter üret, Monad testnet cüzdanınla giriş yap.

---

## İçindekiler

- [Gereksinimler](#gereksinimler)
- [Mimari](#mimari)
- [Yerel Geliştirme (Docker)](#yerel-geliştirme-docker)
- [Ortam Değişkenleri](#ortam-değişkenleri)
- [Sadece Backend](#sadece-backend)
- [Sadece Frontend](#sadece-frontend)
- [Smart Contracts](#smart-contracts)
- [Production Deploy](#production-deploy)
- [API Endpointleri](#api-endpointleri)
- [Sorun Giderme](#sorun-giderme)

---

## Gereksinimler

| Araç | Minimum | Notlar |
|------|---------|--------|
| Docker Desktop | 24+ | Tüm servisleri çalıştırmak için |
| Git | herhangi | |
| Node.js | 18+ | Yalnızca smart contract geliştirme için |
| Flutter SDK | 3.x stable | Yalnızca yerel frontend geliştirme için |

> Go ve PostgreSQL kurmanıza gerek yok — Docker her şeyi halleder.

---

## Mimari

Backend, birbirinden bağımsız çalışan **mikroservisler** mimarisine geçirilmiştir. Tüm frontend istekleri tek bir `gateway` üzerinden geçer; gateway JWT'yi doğrular ve isteği ilgili servise proxy'ler.

```
┌──────────────────────────────────────────────────────────┐
│                     Frontend (Flutter)                   │
└───────────────────────┬──────────────────────────────────┘
                        │ :80
                        ▼
┌──────────────────────────────────────────────────────────┐
│                  Gateway  :8080                          │
│  • CORS · JWT extract · Reverse proxy · Health agg.     │
└──┬──────────┬─────────┬────────────┬────────────┬───────┘
   │          │         │            │            │
   ▼ :8081    ▼ :8082   ▼ :8083      ▼ :8084      ▼ :8085
 authsvc  agentsvc  aipipelinesvc  guildsvc  workspacesvc
             │            │
             └──→ Redis    └──→ Gemini / Claude AI
             └──→ Uploads volume
```

### Servisler

| Servis | Port | Sorumluluk |
|--------|------|------------|
| `gateway` | 8080 | Giriş noktası — JWT, CORS, proxy |
| `authsvc` | 8081 | Nonce üretme, imza doğrulama, JWT |
| `agentsvc` | 8082 | Agent CRUD, kütüphane, kredi, leaderboard, kullanıcı profili |
| `aipipelinesvc` | 8083 | Prompt analiz → karakter tipi (Gemini / Claude fallback) |
| `guildsvc` | 8084 | Guild yönetimi, AI guild-master chat |
| `workspacesvc` | 8085 | Missions, Legend workflow yürütme |
| `postgres` | 5433* | PostgreSQL 16 (*yerel portforward) |
| `redis` | 6379 | Rate-limit önbelleği |
| `frontend` | 80 | nginx — Flutter Web static dosyaları |

---

## Yerel Geliştirme (Docker)

### 1. Repoyu klonla

```bash
git clone <repo-url>
cd Agent-Store-Web
```

### 2. `.env` dosyasını oluştur

```bash
cp .env.example .env
```

Asgari zorunlu değerler:

```env
JWT_SECRET=herhangi_bir_gizli_deger
GEMINI_API_KEY=AIza...        # Gemini analiz için (yoksa Claude fallback)
CLAUDE_API_KEY=sk-ant-...     # opsiyonel — Gemini yoksa devreye girer
```

Diğer tüm değişkenlerin varsayılanları zaten çalışır durumdadır.

### 3. Servisleri başlat

```bash
docker compose up -d
```

İlk çalıştırmada image'lar build edilir (~3–7 dk, 7 servis). Sonraki başlatmalar hızlıdır.

### 4. Servislerin hazır olmasını bekle

```bash
docker compose ps
```

Beklenen çıktı:

```
agent_store_db            ... Up (healthy)   0.0.0.0:5433->5432/tcp
agent_store_redis         ... Up (healthy)   0.0.0.0:6379->6379/tcp
agent_store_authsvc       ... Up (healthy)
agent_store_agentsvc      ... Up (healthy)
agent_store_aipipelinesvc ... Up (healthy)
agent_store_guildsvc      ... Up (healthy)
agent_store_workspacesvc  ... Up (healthy)
agent_store_gateway       ... Up             0.0.0.0:8080->8080/tcp
agent_store_frontend      ... Up             0.0.0.0:80->80/tcp
```

### 5. Aç

| Adres | Ne açılır |
|-------|-----------|
| http://localhost | Flutter frontend |
| http://localhost:8080/health | Gateway sağlık kontrolü |
| http://localhost:8080/health/full | Tüm servislerin sağlık durumu |
| http://localhost:8080/api/v1/agents | Agent listesi (JSON) |

### Servisleri durdur

```bash
docker compose down          # container'ları durdur (veri korunur)
docker compose down -v       # container + veritabanı verisi sil
```

### Logları izle

```bash
docker compose logs -f gateway       # gateway logları (canlı)
docker compose logs -f agentsvc      # agent servis logları
docker compose logs -f aipipelinesvc # AI pipeline logları
docker compose logs -f               # tüm servisler
```

### Kodu değiştirdikten sonra yeniden build

```bash
# Belirli bir servis değiştiyse (örnek: agentsvc):
docker compose build agentsvc && docker compose up -d agentsvc

# Tüm backend servisleri:
docker compose build gateway authsvc agentsvc aipipelinesvc guildsvc workspacesvc
docker compose up -d

# Frontend değiştiyse (önce flutter build, sonra):
docker compose restart frontend
```

---

## Ortam Değişkenleri

`.env` dosyasına koyulur (kök dizin). Varsayılanlar köşeli parantez içinde.

### Zorunlu / Önemli

| Değişken | Açıklama | Varsayılan |
|----------|----------|------------|
| `JWT_SECRET` | JWT imzalama anahtarı | `dev_secret_change_me` |
| `GEMINI_API_KEY` | Google Gemini API anahtarı (AI analiz + karakter) | _(boş — Claude'a düşer)_ |
| `CLAUDE_API_KEY` | Anthropic Claude API anahtarı (Gemini yoksa fallback) | _(boş — keyword matching)_ |

### Veritabanı

| Değişken | Açıklama | Varsayılan |
|----------|----------|------------|
| `POSTGRES_DB` | Veritabanı adı | `agent_store` |
| `POSTGRES_USER` | Veritabanı kullanıcısı | `agent_user` |
| `POSTGRES_PASSWORD` | Veritabanı şifresi | `agent_pass` |
| `POSTGRES_HOST` | PostgreSQL host | `postgres` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` |
| `DATABASE_URL` | Tam DSN (Railway otomatik doldurur) | _(boş)_ |

### Ağ / CORS / Blockchain

| Değişken | Açıklama | Varsayılan |
|----------|----------|------------|
| `PORT` | Servis port (her servis kendi set eder) | `8080` |
| `ALLOWED_ORIGINS` | CORS izinli originler (virgülle) | `http://localhost:80,...` |
| `MONAD_RPC_URL` | Monad testnet RPC | `https://testnet-rpc.monad.xyz` |
| `CREDITS_CONTRACT_ADDRESS` | Deploy edilmiş kontrat adresi | _(boş)_ |
| `TREASURY_WALLET` | On-chain kredi hazine cüzdanı | _(boş)_ |

### Servis URL'leri (Docker içinde otomatik, sadece Railway'de gerekebilir)

| Değişken | Açıklama | Varsayılan (Docker) |
|----------|----------|---------------------|
| `AUTH_SERVICE_URL` | Auth servisi URL | `http://authsvc:8081` |
| `AGENT_SERVICE_URL` | Agent servisi URL | `http://agentsvc:8082` |
| `AIPIPELINE_SERVICE_URL` | AI Pipeline servisi URL | `http://aipipelinesvc:8083` |
| `GUILD_SERVICE_URL` | Guild servisi URL | `http://guildsvc:8084` |
| `WORKSPACE_SERVICE_URL` | Workspace servisi URL | `http://workspacesvc:8085` |

> Production için `.env.production.example` dosyasına bakın.

---

## Sadece Backend

### Bağımlılıkları yenile

```bash
cd backend
go mod tidy
go mod vendor   # Railway deploy için önerilir
```

> `backend/vendor/` varsa Docker build otomatik `-mod=vendor` ile derler.

### Belirli servisi Docker ile çalıştır

```bash
# Sadece altyapı + auth + agent servisleri:
docker compose up -d postgres redis authsvc agentsvc aipipelinesvc gateway
```

### Go kurulu değilse derleme testi

```bash
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$(pwd)/backend:/app" \
  -w //app golang:1.22-alpine \
  go build -o /tmp/s ./cmd/gateway
```

---

## Sadece Frontend

Flutter SDK kuruluysa Docker olmadan çalıştır:

```bash
cd agent_store

# Bağımlılıkları kur
flutter pub get

# Geliştirme sunucusu (localhost:8080'de gateway çalışıyor olmalı)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Release build
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080
# Çıktı: agent_store/build/web/
```

---

## Smart Contracts

### Kurulum

```bash
cd contracts
npm install
```

### Derleme ve Test

```bash
npm run compile      # Solidity derle
npm run test         # Mocha/Chai testleri çalıştır (7 test)
```

### Yerel ağa deploy

```bash
# Terminal 1 — yerel Hardhat node başlat
npm run node

# Terminal 2 — deploy
npm run deploy:local
```

### Monad Testnet'e deploy

`contracts/.env` dosyası oluştur:

```env
DEPLOYER_PRIVATE_KEY=0x<cüzdan-private-key>
MONAD_RPC_URL=https://testnet-rpc.monad.xyz
```

```bash
npm run deploy
```

Deploy sonrası çıktıdan `CREDITS_CONTRACT_ADDRESS` değerini alıp kök `.env`'e ekle.

> Monad testnet faucet: https://faucet.monad.xyz (test MON için)

---

## Production Deploy

### Backend → Railway (Mikroservisler)

Her mikroservis Railway'de **ayrı bir servis** olarak deploy edilir:

1. [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo**
2. Her servis için ayrı `Root Directory` / `Dockerfile` belirt:
   | Servis | Dockerfile |
   |--------|-----------|
   | gateway | `backend/deploy/gateway.Dockerfile` |
   | authsvc | `backend/deploy/authsvc.Dockerfile` |
   | agentsvc | `backend/deploy/agentsvc.Dockerfile` |
   | aipipelinesvc | `backend/deploy/aipipelinesvc.Dockerfile` |
   | guildsvc | `backend/deploy/guildsvc.Dockerfile` |
   | workspacesvc | `backend/deploy/workspacesvc.Dockerfile` |
3. **PostgreSQL** plugin ekle — `DATABASE_URL` otomatik inject edilir
4. **Redis** plugin ekle — `REDIS_URL` otomatik inject edilir
5. **Variables** sekmesine `.env.production.example` içindeki değerleri gir
6. Servisler arası iletişim için Railway internal URL'leri kullan:
   ```
   AUTH_SERVICE_URL=http://authservice.railway.internal:8081
   AGENT_SERVICE_URL=http://agentservice.railway.internal:8082
   ...
   ```

### Frontend → Vercel

1. [vercel.com](https://vercel.com) → **New Project** → GitHub reposu seç
2. **Framework Preset**: Other
3. **Root Directory**: `agent_store`
4. **Build Command**: `flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL`
5. **Output Directory**: `build/web`
6. **Environment Variables**'a `API_BASE_URL=https://<gateway-railway-url>.up.railway.app` ekle

### GitHub Actions ile otomatik CI/CD

`main` branch'e her push'ta otomatik deploy tetiklenir. Repo ayarlarında gerekli secrets:

**Secrets:**

| İsim | Nereden alınır |
|------|----------------|
| `RAILWAY_TOKEN` | Railway → Account Settings → Tokens |
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens |
| `VERCEL_ORG_ID` | Vercel → Team/Account Settings |
| `VERCEL_PROJECT_ID` | Vercel → Project Settings |

**Variables:**

| İsim | Değer |
|------|-------|
| `API_BASE_URL` | `https://<gateway>.up.railway.app` |

---

## API Endpointleri

Base URL: `http://localhost:8080` (geliştirme). Tüm istekler gateway üzerinden geçer.

JWT, `Authorization: Bearer <token>` header'ı ile gönderilir.

### Auth

| Method | Path | Auth | Açıklama |
|--------|------|------|----------|
| GET | `/health` | — | Gateway sağlık |
| GET | `/health/full` | — | Tüm servislerin sağlık durumu |
| GET | `/api/v1/auth/nonce/:wallet` | — | Cüzdan için nonce üret |
| POST | `/api/v1/auth/verify` | — | İmzayı doğrula → JWT döndür |

### Agents

| Method | Path | Auth | Açıklama |
|--------|------|------|----------|
| GET | `/api/v1/agents` | — | Agent listesi (`?category=&search=&sort=&page=&limit=`) |
| GET | `/api/v1/agents/:id` | — | Agent detayı |
| POST | `/api/v1/agents` | JWT | Yeni agent oluştur |
| GET | `/api/v1/leaderboard` | — | Leaderboard (en yüksek puanlı agentlar) |
| POST | `/api/v1/trial` | — | Agent trial kullanımı |

### Kullanıcı

| Method | Path | Auth | Açıklama |
|--------|------|------|----------|
| GET | `/api/v1/user/library` | JWT | Kayıtlı agentlar |
| POST | `/api/v1/user/library/:id` | JWT | Kütüphaneye ekle |
| DELETE | `/api/v1/user/library/:id` | JWT | Kütüphaneden çıkar |
| GET | `/api/v1/user/credits` | JWT | Kredi sorgula |
| GET | `/api/v1/users/:wallet` | — | Kullanıcı profili |

### Guilds

| Method | Path | Auth | Açıklama |
|--------|------|------|----------|
| GET | `/api/v1/guilds` | — | Guild listesi |
| GET | `/api/v1/guilds/:id` | — | Guild detayı |
| POST | `/api/v1/guilds` | JWT | Guild oluştur |
| POST | `/api/v1/guilds/:id/join` | JWT | Guild'e katıl |
| DELETE | `/api/v1/guilds/:id/join` | JWT | Guild'den ayrıl |
| GET | `/api/v1/guilds/:id/compatibility` | — | Uyumluluk skoru |
| POST | `/api/v1/guild-master/suggest` | JWT | AI guild önerisi |
| POST | `/api/v1/guild-master/chat` | JWT | AI guild-master chat |

### Workspace (Missions & Legend)

| Method | Path | Auth | Açıklama |
|--------|------|------|----------|
| GET | `/api/v1/user/missions` | JWT | Mission listesi |
| POST | `/api/v1/user/missions` | JWT | Mission kaydet |
| DELETE | `/api/v1/user/missions/:id` | JWT | Mission sil |
| POST | `/api/v1/user/missions/expand` | JWT | Mission genişlet (AI) |
| GET | `/api/v1/user/legend/workflows` | JWT | Legend workflow listesi |
| POST | `/api/v1/user/legend/workflows` | JWT | Workflow kaydet |
| POST | `/api/v1/user/legend/workflows/:id/execute` | JWT | Workflow çalıştır (AI) |
| GET | `/api/v1/user/legend/executions` | JWT | Execution geçmişi |

---

## Sorun Giderme

### Servisler ayağa kalkmıyor / bağlantı hatası

```bash
docker compose logs -f
```

`aipipelinesvc` veya `agentsvc` hata veriyorsa bağımlı servisler henüz hazır olmayabilir. `depends_on` + `healthcheck` otomatik bekler, birkaç saniye sonra tekrar deneyin.

### Git Bash'te Docker path hatası

`//` veya `MSYS_NO_PATHCONV=1` kullanın:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "C:/path:/app" -w //app ...
```

### MetaMask bağlanmıyor

- MetaMask'ın tarayıcıda kurulu olduğundan emin olun
- **Monad Testnet** eklenmiş olmalı: RPC `https://testnet-rpc.monad.xyz`, Chain ID `10143`

### AI analiz çalışmıyor, karakter tipi hep aynı

`.env`'de `GEMINI_API_KEY` ve `CLAUDE_API_KEY` boş bırakılmışsa keyword matching devreye girer. Bu normaldir — API key eklenince AI analizi aktif olur.

### Frontend değişiklikleri görünmüyor

```bash
# Flutter release build al, ardından container'ı yeniden başlat:
cd agent_store && flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080
cd .. && docker compose restart frontend
```

Tarayıcıda hard refresh yapın (Ctrl+Shift+R).

### PostgreSQL port çakışması

`docker-compose.yml` içinde PostgreSQL `5433:5432` olarak yayınlanmaktadır (yerel 5433). Eğer bilgisayarınızda başka bir PostgreSQL `5433`'ü kullanıyorsa `docker-compose.yml`'yi düzenleyin.
