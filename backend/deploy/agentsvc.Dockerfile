FROM golang:1.22-alpine AS builder
WORKDIR /app

# 1. Copy dependency manifests first (cached layer)
COPY go.mod go.sum ./

# 2. Download deps — this layer is cached until go.mod/go.sum change
RUN if [ -d vendor ] && [ -f vendor/modules.txt ]; then \
        echo "vendor dir found"; \
    else \
        go mod download; \
    fi

# 3. Copy source (only this layer invalidates on code changes)
COPY . .

# 4. Build
RUN set -eux; \
	if [ -f vendor/modules.txt ]; then \
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -ldflags="-s -w" -o service ./cmd/agentsvc; \
	else \
		CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o service ./cmd/agentsvc; \
	fi

# Runtime stage — merged layers
FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/service .
RUN mkdir -p ./uploads/agents && chown -R appuser:appgroup ./service ./uploads
USER appuser
EXPOSE 8082
ENV GOMEMLIMIT=204MiB GOGC=50
CMD ["./service"]
