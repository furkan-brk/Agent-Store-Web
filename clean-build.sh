#!/usr/bin/env bash
# clean-build.sh — Stop containers, wipe all Docker cache, rebuild from scratch.
set -euo pipefail

COMPOSE_FILE="$(dirname "$0")/docker-compose.yml"

echo "==> Stopping and removing containers..."
docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans 2>/dev/null || true

echo "==> Removing project images..."
docker rmi agent-store-web-backend agent-store-web-frontend 2>/dev/null || true

echo "==> Pruning build cache (all unused layers)..."
docker builder prune -af

echo "==> Pruning unused volumes..."
docker volume prune -f

echo "==> Pruning dangling images..."
docker image prune -f

echo "==> Rebuilding from scratch (no cache)..."
docker compose -f "$COMPOSE_FILE" build --no-cache --pull

echo "==> Starting services..."
docker compose -f "$COMPOSE_FILE" up -d

echo ""
echo "==> Services:"
docker compose -f "$COMPOSE_FILE" ps
