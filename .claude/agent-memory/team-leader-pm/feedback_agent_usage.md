---
name: Trial system = encrypted CLI script with user's own API keys
description: Trial runs locally via downloaded Node.js script. Prompt is AES-encrypted, user provides their own API key locally. Prompt never visible, cost $0 to us.
type: feedback
---

When the user says "use agents" or "use agents like Claude", they mean exporting agent prompts for use in Claude Code, Cursor, and similar AI coding tools — NOT building a web chat interface.

**Trial system (v4 — final decision 2026-03-15)**: The trial feature uses an **Encrypted CLI Script** approach:
1. User selects AI provider (Claude/OpenAI/Gemini) + types a test message on the website
2. Backend generates a one-time token and returns a `curl` command
3. User copies the command into their terminal
4. Downloaded Node.js script has the prompt AES-256-CBC encrypted inside
5. Script asks for user's API key locally (never sent to us)
6. Script decrypts prompt in memory, calls AI API with user's key, shows only the response
7. Prompt is never displayed, never written to disk

**Previous iterations rejected:**
- v1: Server-side chat with our Gemini key → user doesn't want us paying API costs
- v2: Raw prompt download as CLAUDE.md → exposes the prompt to the user
- v3: Proxy model (user sends API key to us) → "No one would ever want to give us their API key"

**Why:** The user wants trials that (a) cost us $0, (b) keep the prompt hidden, and (c) don't require users to trust us with their API keys. The encrypted CLI script achieves all three with ~80% protection (determined hackers could still extract, but casual users cannot).

**How to apply:** Trial features should always use the encrypted CLI download pattern. Never expose raw prompt text to the frontend for non-purchased agents. Never ask users for their API keys on the website.
