FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
COPY backend/ .
RUN set -eux; \
	if [ -f vendor/modules.txt ]; then \
		echo "Using vendored dependencies"; \
		CGO_ENABLED=0 GOOS=linux go build -mod=vendor -ldflags="-s -w" -o gateway ./cmd/gateway; \
	else \
		echo "vendor/modules.txt not found, downloading modules"; \
		go mod download; \
		CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o gateway ./cmd/gateway; \
	fi

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
COPY --from=builder /app/gateway .
EXPOSE 8080
ENV GOMEMLIMIT=204MiB GOGC=50
CMD ["./gateway"]
