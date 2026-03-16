FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
COPY . .
RUN set -eux; \
	if [ -f vendor/modules.txt ]; then \
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o service ./cmd/authsvc; \
	else \
		go mod download; \
		CGO_ENABLED=0 GOOS=linux go build -o service ./cmd/authsvc; \
	fi

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/service .
RUN chown appuser:appgroup ./service
USER appuser
EXPOSE 8081
CMD ["./service"]
