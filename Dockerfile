FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
COPY backend/ .
RUN set -eux; \
	if [ -f vendor/modules.txt ]; then \
		echo "Using vendored dependencies"; \
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -ldflags="-s -w" -o monolith ./cmd/monolith; \
	else \
		echo "vendor/modules.txt not found, downloading modules"; \
		go mod download; \
		CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o monolith ./cmd/monolith; \
	fi

FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Install rembg Python dependencies
RUN pip install --no-cache-dir "rembg[cpu]" fastapi uvicorn pillow numpy

# Pre-download ML model at build time
COPY rembg/download_model.py /tmp/download_model.py
RUN python /tmp/download_model.py || true && rm -f /tmp/download_model.py

# Copy rembg server
COPY rembg/server.py ./rembg_server.py

# Copy Go monolith binary
COPY --from=builder /app/monolith .
RUN mkdir -p ./uploads/agents

# Copy entrypoint
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
ENV GOMEMLIMIT=400MiB GOGC=50
CMD ["./entrypoint.sh"]
