# =============================================================================
# Clawcon Demo Setup — Agent Store
# =============================================================================
# Sahnede temiz bir Agent Store ortamı kurar.
# Sunum öncesi BIR KEZ çalıştır. teardown.ps1 ile geri al.
#
# Önkoşullar:
#   - Docker Desktop çalışıyor
#   - Flutter SDK kurulu (3.x), `flutter` PATH'te
#   - C:\Projeler\Agent-Store-Web içinde .env dosyası dolu
#     (en azından: JWT_SECRET, CLAUDE_API_KEY, MONAD_RPC_URL)
#   - MetaMask tarayıcı eklentisi kurulu
#   - Monad testnet'te bir test cüzdanı (test ETH'siyle)
# =============================================================================

$ErrorActionPreference = "Stop"
$AgentStorePath = "C:\Projeler\Agent-Store-Web"
$FlutterAppPath = "$AgentStorePath\agent_store"
$WebBuildPath = "$FlutterAppPath\build\web"

Write-Host "==> Clawcon demo setup başlıyor (Agent Store)" -ForegroundColor Cyan

# --- 0. Path kontrolü --------------------------------------------------------
if (-not (Test-Path $AgentStorePath)) {
    Write-Host "    ✗ Agent Store path yok: $AgentStorePath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$AgentStorePath\.env")) {
    Write-Host "    ⚠ .env yok. .env.example'dan kopyala ve doldur:" -ForegroundColor Yellow
    Write-Host "      cd $AgentStorePath; cp .env.example .env" -ForegroundColor White
    Write-Host "    Zorunlu: JWT_SECRET (openssl rand -hex 32), CLAUDE_API_KEY" -ForegroundColor White
    exit 1
}

# --- 1. Docker durumu --------------------------------------------------------
Write-Host "==> Docker kontrolü"
$dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
if (-not $dockerVersion) {
    Write-Host "    ✗ Docker çalışmıyor. Docker Desktop başlat." -ForegroundColor Red
    exit 1
}
Write-Host "    docker $dockerVersion" -ForegroundColor Green

# --- 2. Flutter web build (frontend container bunu bekliyor) -----------------
Write-Host "==> Flutter web build kontrolü"

if (-not (Test-Path "$WebBuildPath\index.html")) {
    Write-Host "    Flutter web build yok, oluşturuluyor (3-5 dk)..." -ForegroundColor Yellow

    Set-Location $FlutterAppPath
    flutter --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✗ Flutter PATH'te değil veya bozuk." -ForegroundColor Red
        exit 1
    }

    Write-Host "    flutter pub get..." -ForegroundColor DarkGray
    flutter pub get
    if ($LASTEXITCODE -ne 0) { Write-Host "    ✗ pub get başarısız" -ForegroundColor Red; exit 1 }

    Write-Host "    flutter build web --release..." -ForegroundColor DarkGray
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { Write-Host "    ✗ build başarısız" -ForegroundColor Red; exit 1 }

    Write-Host "    ✓ Web build tamam" -ForegroundColor Green
} else {
    Write-Host "    ✓ Web build mevcut: $WebBuildPath" -ForegroundColor Green
    Write-Host "      (Eski olabilir — yenilemek için: cd $FlutterAppPath; flutter build web --release)" -ForegroundColor DarkGray
}

# --- 3. Eski containerları durdur (varsa) ------------------------------------
Set-Location $AgentStorePath
Write-Host "==> Eski containerlar durduruluyor (varsa)"
docker compose down --remove-orphans 2>$null

# --- 4. Tüm stack'i kaldır ---------------------------------------------------
Write-Host "==> Stack build + up (5-8 dk sürebilir, ilk seferse)"
docker compose up -d --build

# --- 5. Health check ---------------------------------------------------------
Write-Host "==> Servisler hazır olana kadar bekleniyor (max 90s)"

$maxAttempts = 30
$attempt = 0
$healthy = $false

while ($attempt -lt $maxAttempts -and -not $healthy) {
    Start-Sleep -Seconds 3
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            Write-Host "    ✓ Gateway healthy (HTTP $($response.StatusCode))" -ForegroundColor Green
        }
    } catch {
        # Henüz hazır değil
    }
    $attempt++
    Write-Host "    ... $attempt/$maxAttempts" -NoNewline -ForegroundColor DarkGray
    Write-Host "`r" -NoNewline
}

if (-not $healthy) {
    Write-Host "`n    ✗ Gateway 90 saniyede hazır olmadı. Loglar:" -ForegroundColor Red
    docker compose logs --tail=50 gateway
    exit 1
}

# --- 6. Frontend kontrolü ----------------------------------------------------
try {
    $fe = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($fe.StatusCode -eq 200) {
        Write-Host "    ✓ Frontend healthy" -ForegroundColor Green
    }
} catch {
    Write-Host "    ⚠ Frontend henüz cevap vermiyor — birkaç saniye bekle" -ForegroundColor Yellow
}

# --- 7. Full health check ----------------------------------------------------
Write-Host "==> Tüm servisler"
try {
    $fullHealth = Invoke-RestMethod -Uri "http://localhost:8080/health/full" -TimeoutSec 5
    $fullHealth | ConvertTo-Json -Depth 3 | Write-Host
} catch {
    Write-Host "    ⚠ /health/full erişilemedi ama /health çalışıyor — devam." -ForegroundColor Yellow
}

# --- 8. Sahne hazırlığı bilgilendirme ----------------------------------------
Write-Host ""
Write-Host "==> Setup tamam." -ForegroundColor Green
Write-Host ""
Write-Host "  📍 Frontend:           http://localhost" -ForegroundColor Yellow
Write-Host "  🛠 API health:         http://localhost:8080/health" -ForegroundColor Yellow
Write-Host "  🛠 API health (full):  http://localhost:8080/health/full" -ForegroundColor Yellow
Write-Host "  🗄 Postgres:           localhost:5433 (container 5432)" -ForegroundColor DarkGray
Write-Host "  🔴 Redis:              localhost:6379" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Sahne öncesi:" -ForegroundColor Cyan
Write-Host "    1. http://localhost'u tarayıcıda aç, Store grid yüklensin"
Write-Host "    2. Connect Wallet → MetaMask → Sign nonce → JWT al"
Write-Host "    3. (Opsiyonel) demo cüzdana 1000 kredi grant et:"
Write-Host '       Invoke-RestMethod -Method POST `' -ForegroundColor DarkGray
Write-Host '         -Uri "http://localhost:8080/api/v1/user/credits/dev-grant" `' -ForegroundColor DarkGray
Write-Host '         -Headers @{ Authorization = "Bearer $jwt" } `' -ForegroundColor DarkGray
Write-Host '         -Body (@{ amount = 1000 } | ConvertTo-Json) -ContentType "application/json"' -ForegroundColor DarkGray
Write-Host "    4. Library'ye 1-2 agent ekle (Store'dan kaydet)"
Write-Host "    5. demo\walkthrough.md'i ezberle"
Write-Host ""
Write-Host "  Sunum sonrası:"
Write-Host "    .\demo\teardown.ps1" -ForegroundColor White
