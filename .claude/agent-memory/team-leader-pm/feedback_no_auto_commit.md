---
name: No auto-commit
description: Never create git commits without explicit user approval — always wait for consent before committing
type: feedback
---

Never commit code changes without the user's explicit consent.

**Why:** User wants full control over what goes into the git history. Unsolicited commits feel intrusive and can include unfinished or unwanted changes.

**How to apply:** After making code changes, present the diff or summary and wait for the user to say "commit" or similar before running any `git commit`. This applies to all agents on the team — propagate this rule when delegating tasks.
