---
name: commit-changes
description: >-
  Commits uncommitted work in the Flutter or backend git roots, split by kind
  of change. Use when the user says "Commit backend changes", "Commit Flutter
  changes", "Commit frontend changes", or asks to commit with separated commits.
---

# Commit changes (Flutter / backend)

## Triggers

- `Commit backend changes`
- `Commit Flutter changes` / `Commit frontend changes`
- Similar phrasing that names which repo and asks to commit

## Repo roots

Use `git -C <absolute-path>` (do not rely on Shell `working_directory` alone — nested `backend/` can resolve to the Flutter root).

| Phrase | Repo |
|--------|------|
| backend | Flutter workspace `backend/` (separate git root: Bitbucket `backend-of-principles-app`) |
| Flutter / frontend | Flutter workspace root (GitHub `flutter-frontend-of-principles`) |

Do not commit the MAUI repo unless the user names it.

## Authorship (required)

- Never add `Co-authored-by`, Cursor/AI trailers, or any contributor attribution for the agent.
- Never pass `--author`, never change `user.name` / `user.email`, never amend to rewrite author.
- Commits must use the existing local git identity only (today: Bohdan Bats).

## How to commit

1. Status, full diff, and recent `git log` in that repo only (`git -C …`).
2. Group into **separate commits by kind** (feature vs fix vs refactor vs tests vs docs/rules vs config). Prefer focused commits over one dump. Keep a feature and its tests together when they are one unit.
3. Stage only files for the current commit; use HEREDOC messages in this repo’s style (imperative, why-focused, ~1–2 sentences).
4. No secrets (`.env`, real API keys, app passwords). Warn and skip those files.
5. Do not push unless asked.
6. After all commits: `git status` and briefly list the new commit subjects.

Follow the user’s global git safety rules (no force push, no amend unless those rules allow it, no `--no-verify`).
