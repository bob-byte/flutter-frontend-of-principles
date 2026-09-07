---
name: update-project-context
description: Updates project Cursor rules and skills when product decisions, architecture, or conventions change. Use when the user says "update context", "update rules", "update skills", "remember this", or after a non-trivial product/architecture decision that should persist across sessions.
---

# Update project context

This repo uses `.cursor/rules/` and `.cursor/skills/` instead of a memory bank. Persist durable knowledge there; do not recreate `memory-bank/`.

## When to write

Update files when a decision should still be true in a future session (UX conventions, architecture, stack, workflows). Skip ephemeral git/merge status, one-off bugs, and chat-only scratch.

## Where to put it

| Kind | Location |
|------|----------|
| Always-on product/architecture/stack | `.cursor/rules/*.mdc` with `alwaysApply: true` |
| File-specific constraints | `.cursor/rules/*.mdc` with `globs` |
| Multi-step workflow | `.cursor/skills/<name>/SKILL.md` |
| Backend (.NET) conventions | `backend/.cursor/rules/*.mdc` (separate git root) |

Flutter always-on: `communication.mdc`, `project.mdc`, `architecture.mdc`, `stack.mdc`. File-specific: `road-guide.mdc`.

Backend always-on: `communication.mdc`, `project.mdc`, `architecture.mdc`, `stack.mdc`. File-specific: `api-controllers.mdc`, `ef-data.mdc`.

## How

1. Identify which rule or skill the change belongs to (one concern per file).
2. Edit in place; keep each rule under ~50 lines and actionable.
3. Do not duplicate the same fact across rules and skills. Skills hold procedures; rules hold constraints and facts.
4. Do not log "current focus" or progress lists. Git and the conversation already have that.
5. Chat replies stay English (see `communication.mdc`).

## Phrases that mean this skill

- "update context" / "update rules" / "update skills"
- "remember this" as a durable project convention
