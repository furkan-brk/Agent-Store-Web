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
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o service ./cmd/aipipelinesvc; \
	else \
		CGO_ENABLED=0 GOOS=linux go build -o service ./cmd/aipipelinesvc; \
	fi

# Runtime stage — merged layers
FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/service .
RUN chown appuser:appgroup ./service
USER appuser
EXPOSE 8083
CMD ["./service"]
