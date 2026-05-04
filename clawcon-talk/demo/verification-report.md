# Setup Doğrulama Raporu

> Tarih: 2026-05-04
> Komut: prerequisite checks (Docker, Flutter, .env, web build, mmdc)
> **Tam `docker compose up` ÇALIŞTIRILMADI** — sadece prereq doğrulaması yapıldı.

## ✅ Hazır olanlar

| Kontrol | Durum | Detay |
|---------|-------|-------|
| Flutter | ✅ | `Flutter 3.32.0 • channel [user-branch]` — uyumlu |
| Web build | ✅ | `agent_store/build/web/index.html` zaten mevcut — `flutter build web` adımı **atlanabilir** |
| `.env` | ✅ | `C:\Projeler\Agent-Store-Web\.env` mevcut |
| `docker-compose.yml` | ✅ | 7 servis tanımlı (postgres, redis, gateway + 5 mikroservis, frontend) |

## ⚠️ Sahneye gitmeden mutlaka düzeltilecek

| Kontrol | Durum | Aksiyon |
|---------|-------|---------|
| **Docker daemon** | ❌ NOT RUNNING | Docker Desktop'ı başlat (Windows tray'inde "Docker Desktop is starting" → "running") |
| **mmdc** (mermaid CLI) | ⏳ Kurulumda (background) | `npm install -g @mermaid-js/mermaid-cli` çalışıyor; bu rapor yazılırken devam ediyor |

### Docker Desktop nasıl başlatılır

```powershell
# Otomatik başlatma (varsa Start menü kısayolu)
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Manuel: Start Menu → "Docker Desktop" ara → çalıştır
# Tray icon'da "Docker Desktop is running" göründüğünde hazır
```

Sonra:
```powershell
docker version          # Server.Version cevap vermeli
docker compose version  # v2.x mevcut olmalı
```

## 🚀 Sahne öncesi tam doğrulama

Bu raporun yazıldığı an:
- Flutter, web build, .env: hazır
- Docker daemon: kapalı (manuel başlatma gerekiyor)
- mmdc: kurulum devam ediyor

Önerilen yapılacaklar (sırayla):

```powershell
# 1. Docker Desktop'ı başlat (manuel — GUI'den)
# tray'de yeşil göründüğünde devam et

# 2. mmdc kurulumunun bittiğini doğrula
mmdc --version
# Çıktı: 11.x veya benzeri bir sürüm

# 3. Diyagramları render et
cd C:\Projeler\Openclaw\clawcon-talk\diagrams
Get-ChildItem *.mmd | ForEach-Object {
    mmdc -i $_.Name -o ($_.BaseName + ".svg") -t dark -b transparent
}

# 4. setup.ps1 dene
cd C:\Projeler\Openclaw\clawcon-talk
.\demo\setup.ps1

# Bu komut:
#  a) flutter build web ATLAYACAK (zaten mevcut)
#  b) docker compose up -d --build çalıştıracak
#  c) Health check yapacak (90s timeout)
#  d) Sahne hazırlığı talimatlarını yazdıracak
```

## 📊 Servis kontrol matrisi (sahne öncesi)

setup.ps1 başarılı çalıştıktan sonra her birini doğrula:

```powershell
# Frontend
Invoke-WebRequest http://localhost -UseBasicParsing
# 200 OK + nginx Flutter web bekler

# Gateway
Invoke-RestMethod http://localhost:8080/health
# {"status":"ok"} bekler

# Tüm servisler
Invoke-RestMethod http://localhost:8080/health/full
# 5 servis healthy bekler

# Postgres (host'tan, container 5432 → host 5433 mapping)
docker exec agent_store_db pg_isready -U agent_user
# /var/run/postgresql:5432 - accepting connections

# Redis
docker exec agent_store_redis redis-cli ping
# PONG
```

## 🔧 Bilinen takılma noktaları

### "frontend container starts but http://localhost returns nothing"

- `agent_store/build/web` boş veya eski olabilir
- Yenilenmesi: `cd agent_store; flutter build web --release`
- Sonra `docker compose restart frontend`

### "gateway health döner ama /health/full hata veriyor"

- Bir mikroservis henüz hazır değil
- `docker compose logs --tail=50 <servisadı>`
- En sık: `aipipelinesvc` Claude API key olmadan başlatılırsa erken fail
- Çözüm: `.env`'de `CLAUDE_API_KEY=sk-ant-...` dolu olduğunu doğrula

### "MetaMask Monad testnet'te yok"

- MetaMask → Networks → Add Network → Custom RPC
- Network Name: `Monad Testnet`
- RPC URL: `https://testnet-rpc.monad.xyz`
- Chain ID: `10143`
- Currency Symbol: `MON`
- Block Explorer: (varsa Monad'ın resmi explorer URL'si)

### "Demo cüzdanında kredi yok"

```powershell
# JWT al (browser'dan veya curl ile)
$nonce = Invoke-RestMethod "http://localhost:8080/api/v1/auth/nonce/0xYourWallet"
# personal_sign yap, signature al
$jwt = (Invoke-RestMethod -Method POST `
  -Uri "http://localhost:8080/api/v1/auth/verify" `
  -Body (@{wallet="0x..."; signature="0x..."} | ConvertTo-Json) `
  -ContentType "application/json").jwt

# Dev grant
Invoke-RestMethod -Method POST `
  -Uri "http://localhost:8080/api/v1/user/credits/dev-grant" `
  -Headers @{Authorization="Bearer $jwt"} `
  -Body (@{amount=1000} | ConvertTo-Json) `
  -ContentType "application/json"
```

## 🎯 Verdiklerimiz / vermediklerimiz

**Bugün doğrulanan:**
- Flutter, .env, web build dosyalarının fiziksel mevcudiyeti
- docker-compose.yml'in syntax-valid olduğu (Read ile okudum)
- setup.ps1'in içerik olarak doğru olduğu (frontend build adımı doğru sırada)

**Bugün doğrulanmayan (Docker kapalı olduğu için):**
- `docker compose up` gerçekten çalışıyor mu
- `/health/full` 5 servisi healthy gösteriyor mu
- http://localhost gerçekten Agent Store yüklüyor mu
- MetaMask connect → JWT akışı end-to-end çalışıyor mu
- Guild Master suggest LLM cevap veriyor mu
- Legend execute DAG başarıyla çalışıyor mu

**Sunum öncesi MUTLAKA test edilecek:**
1. Docker Desktop başlat
2. setup.ps1 çalıştır
3. http://localhost → Connect Wallet → Sign → JWT al
4. Dev grant ile 1000 kredi
5. Library'ye 2-3 agent ekle
6. Guild Master demo problem'ini sor → cevap geldiğini gör
7. Add to Legend → execute → final output

Bu 7 adım demo'nun **tam end-to-end testi**. Gönülden uyararım: sunumdan **3 gün önce** bu testi en az 2 farklı zaman diliminde yap.
