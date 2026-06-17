---
name: tech-debt-register
description: Use ONLY when reading, editing, or maintaining `docs/tech-debt.md`, the authoritative open-item tech-debt register. Entries are actionable prompts, not full specifications or history.
---
# Tech Debt Register

## Purpose

This skill governs how to read, edit, and maintain the project's open-item tech-debt register when working directly on the register, so it stays a scannable, action-oriented source of truth.

## Format

`docs/tech-debt.md` is a **table-based open-item register**, not a changelog. It is a single markdown table with exactly three columns:

| Area | Item | Notes |
|---|---|---|

- `Area` — the workstream or feature area. Reuse existing labels consistently; prefer current labels rather than inventing variants.
- `Item` — a short action phrase.
- `Notes` — brief additive context, rationale, or dependency only. No historical commentary.

## Rules

- **Open items only.** Resolved items are deleted immediately. Do not retain closed items or add historical sections.
- **Add or remove rows.** Never append dated entries, bullet lists, or closed-item records.
- **Split mixed work.** If a row bundles completed and open work together, split it so only open work remains.
- **No metadata columns.** No dates, owners, status columns, or historical summaries.
- **British English** spelling.
- Keep the file scannable. Prefer short phrases over long explanations. The register is a set of reminders, not a specification document.
