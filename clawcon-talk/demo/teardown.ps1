# Demo temizliği — Agent Store stack'ini durdur
$ErrorActionPreference = "Continue"
$AgentStorePath = "C:\Projeler\Agent-Store-Web"

if (Test-Path $AgentStorePath) {
    Set-Location $AgentStorePath
    Write-Host "==> docker compose down" -ForegroundColor Cyan
    docker compose down --remove-orphans
    Write-Host "✓ Stack durduruldu" -ForegroundColor Green
} else {
    Write-Host "Agent Store path yok: $AgentStorePath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Volume'leri de silmek istersen:" -ForegroundColor DarkGray
Write-Host "  cd $AgentStorePath; docker compose down -v" -ForegroundColor White
