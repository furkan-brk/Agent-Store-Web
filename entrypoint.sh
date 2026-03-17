#!/bin/sh
set -e

# Start rembg ML server in background
echo "Starting rembg server on :5000..."
uvicorn rembg_server:app --host 127.0.0.1 --port 5000 --log-level warning &
REMBG_PID=$!

# Wait for rembg to be ready (max 60s)
for i in $(seq 1 60); do
  if wget -q --spider http://127.0.0.1:5000/health 2>/dev/null; then
    echo "rembg ready"
    break
  fi
  sleep 1
done

# Start monolith (foreground)
exec ./monolith
