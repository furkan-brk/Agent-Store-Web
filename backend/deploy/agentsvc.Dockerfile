FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
COPY . .
RUN set -eux; \
	if [ -f vendor/modules.txt ]; then \
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o service ./cmd/agentsvc; \
	else \
		go mod download; \
		CGO_ENABLED=0 GOOS=linux go build -o service ./cmd/agentsvc; \
	fi

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/service .
RUN mkdir -p ./uploads/agents && chown -R appuser:appgroup ./service ./uploads
USER appuser
EXPOSE 8082
CMD ["./service"]
