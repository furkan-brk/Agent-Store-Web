# CLAUDE.md

> Agent Store — top-level guidance for Claude Code. Detaylar ayrı dosyalarda.

## Proje Özeti
AI Agent prompt paylaşım platformu. Kullanıcılar agent promptlarını keşfeder,
kütüphanesine ekler, kendi promptunu yükler. Her prompt analiz edilerek benzersiz
pixel-art karakter üretilir. Giriş Monad testnet cüzdanı ile yapılır; kredi
sistemi on-chain yönetilir.

**Yığın özet**: Flutter Web · Go 1.22 + Gin + GORM · PostgreSQL 16 · Monad
testnet (Solidity 0.8.24) · Docker · AI: Claude + Gemini + Replicate pixel-art.

---

## 📚 Referans Dosyalar (önce buraya bak)

| Dosya | İçerik |
|---|---|
| **`docs/COMMANDS.md`** | Tüm dev komutları (Go, Flutter, Docker, Hardhat, test yazma kuralları, validation pipeline, common workflow) |
| **`docs/ARCHITECTURE.md`** | Mimari ağaç, deployment modları, API endpoint'leri, DB şeması, karakter sistemi, blockchain, key file map, team agents |
| **`docs/SPRINT_HISTORY.md`** | Tüm sprint detayları (v0.1 → güncel) — kararlar, yeni dosyalar, endpoint'ler, modeller |
| `docs/rfc/` | RFC'ler |
| `.claude/tasks/agent-store/` | Eski sprint planları (legacy) |

---

## Established Patterns
**Yeni kod yazarken aşağıdakileri reuse et, yeniden yazma**:

- **Shared widgets** (`lib/shared/widgets/`): `PageHeader`, `EmptyState`,
  `ErrorState`, `ConfirmDialog`, `AppAnimations`, `ResponsiveLayout` (uses
  `AppBreakpoints`, 768px narrow split)
- **SyncStatus**: enum (idle/dirty/saving/saved/error) + `ValueNotifier` +
  exponential backoff retry (3 attempts) + 5-min periodic sync — Mission, Legend,
  Card Editor aynı pattern
- **Optimistic concurrency**: `RevisionID uint64` + `BeforeUpdate` GORM hook +
  handler-level `If-Match` parse → 409 + full-body — Agent, Mission, Legend
  workflow tümünde aynı kalıp
- **Backend test utility**: `testutil.NewTestDB(t)` (sqlite in-memory, no CGO).
  Yeni model → `internal/testutil/db.go` `AutoMigrate` listesine ekle (zorunlu)
- **Pure-Dart helper extract**: widget `dart:js_interop` / `package:web` çekiyorsa
  testleri kırar — logiği ayrı `_helper.dart`'a çek (`mention_filter.dart`,
  `tx_state.dart`, `quality_score.dart` örnekleri)
- **Cache invalidation**: `s.cache.DeletePrefix("agents|")` event-driven —
  AddToLibrary / RemoveFromLibrary / UpdateProfile / regenerate cache bust
- **Notification helper**: `notifyOnce(wallet, type, title, body, link)` —
  IsPrefEnabled + 1h dedup + best-effort
- **RecordActivity**: synchronous (NOT goroutine) — t.Cleanup race önle. Aynı
  rule async DB write'larda da geçerli (LastUsedAt, vb.)
- **Bridge interface pattern**: `services/workspace` `services/guild`'i import
  etmesin diye interface + adapter (`cmd/monolith/main.go`'da wire)
- **Dialect-agnostic SQL**: `strftime('%Y-%m-%d', ...)`, `CASE WHEN`
  aggregations, raw SQL LEFT JOIN — SQLite test + PostgreSQL prod aynı path
- **Atomic deduct+create**: `deductCreditsTx` / `appendLedgerTx` — kredi düşürme
  ile DB write'ı tek transaction'da (CreateAgent, ForkAgent, RecordPurchase)

---

## Team Agents
| Agent | Sorumluluk |
|---|---|
| Team Leader (Claude ana) | Koordinasyon, entegrasyon, CLAUDE.md |
| Backend (`go-backend-architect`) | Go API, veritabanı, servisler |
| Frontend (`flutter-frontend-dev`) | Flutter UI, routing, state |
| Gamification Master | Pixel-art karakterler, rarity sistemi |
| Blockchain Expert (`blockchain-engineer`) | Solidity kontrat, Web3 auth, Monad deploy |

---

## Sprint Takibi
- Aktif sprint detayı: `docs/SPRINT_HISTORY.md`'nin başı
- v0.1 → güncel sprint zinciri: `docs/SPRINT_HISTORY.md`
- Legacy planlar: `.claude/tasks/agent-store/`
