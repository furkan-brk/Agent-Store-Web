#!/usr/bin/env bash
# =============================================================================
# Clawcon Demo Setup — Agent Store (bash)
# =============================================================================
set -euo pipefail

AGENT_STORE_PATH="${AGENT_STORE_PATH:-/c/Projeler/Agent-Store-Web}"

echo "==> Clawcon demo setup başlıyor (Agent Store)"

# --- 0. Path kontrolü --------------------------------------------------------
if [[ ! -d "$AGENT_STORE_PATH" ]]; then
    echo "    ✗ Path yok: $AGENT_STORE_PATH"
    exit 1
fi

if [[ ! -f "$AGENT_STORE_PATH/.env" ]]; then
    echo "    ⚠ .env yok. .env.example'dan kopyala ve doldur."
    exit 1
fi

cd "$AGENT_STORE_PATH"
echo "    cwd = $AGENT_STORE_PATH"

# --- 1. Docker ---------------------------------------------------------------
if ! docker version --format "{{.Server.Version}}" >/dev/null 2>&1; then
    echo "    ✗ Docker çalışmıyor."
    exit 1
fi

# --- 2. Eski containerlar ----------------------------------------------------
docker compose down --remove-orphans 2>/dev/null || true

# --- 3. Build + up -----------------------------------------------------------
echo "==> docker compose up -d --build (5-8 dk olabilir)"
docker compose up -d --build

# --- 4. Health check ---------------------------------------------------------
echo "==> Gateway health bekleniyor (max 90s)"
for i in $(seq 1 30); do
    if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
        echo "    ✓ Gateway healthy"
        break
    fi
    sleep 3
    echo -n "    ... $i/30"$'\r'
done

# --- 5. Full health ---------------------------------------------------------
echo "==> Servisler"
curl -fsS http://localhost:8080/health/full | python -m json.tool 2>/dev/null || curl -fsS http://localhost:8080/health/full

echo ""
echo "==> Setup tamam."
echo ""
echo "  📍 Frontend:    http://localhost"
echo "  🛠 API health:  http://localhost:8080/health"
echo ""
echo "  Sahnede demo\walkthrough.md akışını izle"
