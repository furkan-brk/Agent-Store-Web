---
name: Backend Audit v2.6 Findings
description: Security and code quality audit results from comprehensive Go backend review (2026-03-13)
type: project
---

Comprehensive audit completed on the Go backend covering security, performance, and code quality.

**Key changes made:**
1. `deductCredits` now uses `clause.Locking{Strength: "UPDATE"}` (proper GORM v2 API) instead of deprecated `gorm:query_option`
2. `CreditTransaction.TxHash` changed from `string` to `*string` with `uniqueIndex` -- PostgreSQL ignores NULLs in unique indexes, so deductions (nil TxHash) don't conflict while topup hashes are enforced unique at DB level
3. TopUpCredits txHash duplicate check moved inside the DB transaction to eliminate TOCTOU race
4. RecordPurchase wrapped in `database.DB.Transaction()` to prevent TOCTOU races on duplicate purchase checks
5. All silently-ignored DB errors now either return errors or log warnings (non-critical paths)
6. Guild name length validation added (max 50 chars)
7. ListGuilds limit clamped to minimum 1 (defaults to 20)
8. Auth nonce save now returns error on failure instead of silently ignoring

**Why:** Security audit identified TOCTOU races, deprecated GORM APIs, and silently swallowed errors that could mask production issues.

**How to apply:** When adding new DB operations, always handle errors. Use `database.DB.Transaction()` for multi-step operations with uniqueness checks. Use `clause.Locking{Strength: "UPDATE"}` for row locks, not `gorm:query_option`.
