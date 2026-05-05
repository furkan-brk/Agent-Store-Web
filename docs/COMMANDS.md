# Development Commands

> Agent Store günlük komut referansı. Daha kapsamlı bağlam için `CLAUDE.md` ve
> `docs/ARCHITECTURE.md`. Yazılım sürümü tutmuyor — komutlar bayatladıkça günceller.

---

## Backend (Go) — `cd backend/`

```bash
# All tests (race detector + coverage)
go test ./... -race -coverprofile=coverage.out -covermode=atomic

# Single package
go test ./services/agent/... -v

# Single test by name
go test ./services/agent/... -run TestListAgents -v

# Vet
go vet ./...

# Run monolith locally (PRIMARY mode — all services in-process, connects to local postgres)
go run ./cmd/monolith

# Run individual microservice (example: agent service on port 8082)
PORT=8082 go run ./cmd/agentsvc

# Run API gateway (routes to microservices)
go run ./cmd/gateway

# Seed database
go run ./cmd/seed
```

### Writing Backend Tests
Tests use an in-memory SQLite DB via `internal/testutil` (pure-Go via
`github.com/glebarez/sqlite` — no CGO required):

```go
func TestMyFeature(t *testing.T) {
    db := testutil.NewTestDB(t)  // migrates all tables, cleans up via t.Cleanup
    _ = db
    // call service functions directly — they read database.DB global
}
```

> **Kural**: `pkg/models/` altına yeni model eklersen `internal/testutil/db.go`
> içindeki `AutoMigrate` listesine de eklemen gerek. Eklemezsen testler
> "no such table" ile patlar.

---

## Frontend (Flutter) — `cd agent_store/`

```bash
flutter pub get
flutter analyze --no-fatal-infos          # daily check
flutter analyze --fatal-infos              # CI gate
flutter test --reporter expanded
flutter test --reporter compact            # CI / quick check

# Run a specific test file
flutter test test/unit/card_editor_controller_test.dart

# Build for web
flutter build web
```

### Test Konvansiyonları
- `test/unit/` — pure-Dart helpers, controllers (no widget tree)
- `test/widget/` — `flutter_test` ile widget tree assertions
- Mocking: `mocktail` + `fake_async`
- `dart:js_interop` / `package:web` çeken kod test dışı: logiği `_helper.dart`'a
  extract et (örnek: `mention_filter.dart`, `tx_state.dart`, `quality_score.dart`)

---

## Docker (full stack)

```bash
cp .env.example .env                       # fill in API keys first
docker-compose up --build                  # full microservices stack
docker-compose up postgres backend         # DB + monolith mode only
```

---

## Contracts (Hardhat) — `cd contracts/`

```bash
npm install
npm run compile
npm test
npm run deploy:local                       # local hardhat node
npm run deploy                             # Monad testnet
```

---

## Common Workflows

### Yeni endpoint ekleme
1. `services/<pkg>/handler.go` — handler fn
2. `services/<pkg>/router.go` — route mount
3. `services/<pkg>/service.go` — business logic
4. `services/<pkg>/<feature>_test.go` — unit test (testutil pattern)
5. Frontend: `lib/shared/services/api_service.dart` — client method
6. Cache invalidation lazımsa: `s.cache.DeletePrefix("...")` mutation site'ında

### Yeni Flutter ekran
1. `lib/features/<feature>/screens/<name>_screen.dart`
2. Eğer state varsa: `lib/features/<feature>/controllers/<name>_controller.dart` (GetX)
3. `lib/app/router.dart` — GoRoute kaydı + AppShell sidebar (gerekirse)
4. `test/widget/<name>_screen_test.dart` (mocktail ile API mocking)
5. `ResponsiveLayout` veya `AppBreakpoints.isNarrow()` kullan — fixed-width Row'ları
   `Wrap` veya `LayoutBuilder` ile sar

### Yeni model (DB)
1. `pkg/models/<entity>.go` — GORM struct
2. `internal/testutil/db.go` — `AutoMigrate` listesine ekle (zorunlu)
3. `services/<pkg>/migrate.go` (varsa) — production migration listesine ekle
4. Unique index gerekiyorsa `uniqueIndex:idx_...` tag, race-safe insert için
   `clause.OnConflict{DoNothing}` pattern

---

## Validation Pipeline (CI'da `.github/workflows/ci.yml`)

```bash
# Backend
cd backend && go vet ./... && go test ./... -race -coverprofile=coverage.out

# Frontend
cd agent_store && flutter analyze --fatal-infos && flutter test --reporter compact
```

**Sprint kapanış kontrolü**: hem backend hem frontend bu listede yeşil olmalı.
Lokal ortamda Windows App Control politikası test binary'lerini blokluyorsa
(auth + aipipeline pkg'larında olabilir), GitHub Actions sonucuna güven —
Linux runner'da temiz çalışır.
