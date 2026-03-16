FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
COPY . .
RUN set -eux; \
	if [ -f vendor/modules.txt ]; then \
		echo "Using vendored dependencies"; \
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o server ./cmd/server; \
	else \
		echo "vendor/modules.txt not found, downloading modules"; \
		go mod download; \
		CGO_ENABLED=0 GOOS=linux go build -o server ./cmd/server; \
	fi

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/server .
RUN chown appuser:appgroup ./server
USER appuser
EXPOSE 8080
CMD ["./server"]
