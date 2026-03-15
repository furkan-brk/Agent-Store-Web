---
name: Never hardcode secrets in code
description: All secrets (JWT_SECRET, API keys, etc.) must come from env vars — no hardcoded fallbacks in scripts or app code
type: feedback
---

Never hardcode secrets, API keys, JWT secrets, or any credentials into source code — including as "fallback" values in seed/test scripts.

**Why:** The user commits these files to git. Any hardcoded secret would be exposed in version history permanently, even if later removed.

**How to apply:** All scripts (seed, test, migration, CLI tools) must require secrets via environment variables and `log.Fatal()` if missing. No `if secret == "" { secret = "..." }` patterns. Use `.env` files (gitignored) for local dev.
