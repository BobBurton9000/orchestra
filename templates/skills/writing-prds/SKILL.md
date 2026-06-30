---
name: writing-prds
description: Guidance for authoring Product Requirements Documents (PRDs) for discrete features. Use when creating, updating, or reviewing a PRD under docs/product/requirements/, or when a user asks for a product requirements doc, feature spec, or PRD.
---

# Writing PRDs

## Purpose

A **Product Requirements Document (PRD)** specifies what a discrete feature must do, why it matters, and how users experience it — at the level of behaviour and contract, not implementation. A PRD is the bridge between the evergreen product vision (`docs/product/vision.md`, `docs/product/domain-model.md`) and the engineering work that realises it.

Use this skill when:

- A user asks for a "PRD", "product requirements doc", "feature spec", or "requirements document" for a discrete feature.
- You are creating or updating a file under `docs/product/requirements/`.
- You are reviewing a drafted PRD against the canonical structure.

Do **not** use this skill for:

- Evergreen product artifacts (vision, domain model, UI/UX, style guide) — see the `product-documentation` skill.
- Architectural decision records — see the `developer-documentation` skill.
- Implementation plans — those follow `docs/plankit-implementation-plan.template.md`.

## When to write a PRD vs an ADR vs an implementation plan

| Artifact | Question it answers | Where it lives |
|---|---|---|
| **PRD** | What should the feature do, and why? | `docs/product/requirements/NNNN-title.md` |
| **ADR** | What architectural choice did we make, and why? | `docs/dev/adr/NNNN-title.md` |
| **Implementation plan** | How do we build it, module by module? | authored per `docs/plankit-implementation-plan.template.md` |

A single feature often produces all three. The PRD is written first and drives the others: the ADR records any architecturally significant decision the PRD implies, and the implementation plan turns the PRD's requirements into tasks. If a feature has no architectural decision worth recording, no ADR is needed — but a feature that changes the data model or reverses a prior decision almost always does.

## Process

1. **Understand the problem.** Read the relevant evergreen docs (`vision.md`, `domain-model.md`, `ui-ux.md`) and any existing code or ADRs the feature touches. Do not draft blind.
2. **Ask clarifying questions before writing.** Use the `question` tool to resolve design tensions that materially change the document (storage model, coupling rules, migration strategy, UX flow). Do not ask questions you can answer by reading the repo.
3. **Draft against the template.** Copy `docs/prd.template.md`, strip the per-section guidance comments, and fill every section. If a section does not apply, write "Not applicable" with a one-line reason — do not delete the heading.
4. **Review with the user.** Get approval on the draft before saving. Adjust based on feedback.
5. **Save with the next number.** Determine the next sequential `NNNN` by listing `docs/product/requirements/`, then write `NNNN-kebab-case-title.md`. Sequential numbering is mandatory even if earlier PRDs are superseded — gaps are expected and fine.
6. **Cross-link.** If the PRD supersedes or informs an ADR, reference the ADR by number in the PRD's metadata block and in §8.

## File location and naming

- **Directory:** `docs/product/requirements/`
- **Naming:** `NNNN-descriptive-title-with-dashes.md` (mirrors the ADR convention in `docs/dev/adr/`)
- **Template:** `docs/prd.template.md` — the canonical structure. Do not invent a different shape.

## Section-by-section guidance

The template is fully narrated and is the source of truth for each section's purpose and content. The summary below is a quick reference, not a substitute for reading the template before authoring.

| § | Section | One-line intent |
|---|---|---|
| 1 | Problem | The user-experienced pain, not the implementation gap. |
| 2 | Goals | Verifiable outcomes the feature must achieve. |
| 3 | Non-Goals | What a reader might expect but is deliberately excluded. |
| 4 | Users & Use Cases | Who benefits and in what concrete situations. |
| 5 | Requirements | Functional capabilities plus the rules and edge cases that resolve ambiguity. |
| 6 | User Experience | Flows, key screens, and where existing screens change. |
| 7 | Data Model & API Changes | The persisted and transmitted shape changes, diffed against the domain model. |
| 8 | Migration & Rollout | How existing data and users transition without regression. |
| 9 | Open Questions | Unresolved, scoped, answerable questions blocking sections. |
| 10 | Acceptance Criteria | Gherkin scenarios per the `writing-gherkin` skill. |
| 11 | Out-of-Scope Follow-ups | Likely future work this feature surfaces. |

## Review checklist

When reviewing a drafted PRD, check these in order:

1. **Shape:** Are all 11 sections present, in order, with no headings renamed or omitted?
2. **Problem vs solution:** Does §1 describe user pain, free of implementation rationale?
3. **Testable goals:** Can each goal in §2 be confirmed by performing an action?
4. **Non-goals are specific:** Does §3 name things someone might plausibly ask for, not trivial exclusions?
5. **Rules resolve ambiguity:** Does §5 state what happens at the boundaries (toggle off, conflicting data, missing required field)?
6. **Existing screens addressed:** Does §6 name every existing screen the feature touches?
7. **Domain model diff:** Does §7 diff against `docs/product/domain-model.md` rather than restating it?
8. **Migration stated:** Does §8 give a concrete transition for existing records?
9. **Open questions are open:** Are all questions in §9 genuinely unresolved (not already answered elsewhere in the doc)?
10. **Gherkin quality:** Do the scenarios in §10 follow the `writing-gherkin` skill — one behaviour each, concrete `Given`/`When`/`Then`, observable outcomes?
11. **Follow-ups are concrete:** Are items in §11 specific enough to become their own ticket or PRD?

## Common mistakes

- **Writing the solution in §1.** The problem section must not prescribe implementation. Save columns, classes, and queries for §7.
- **Restating the domain model.** §7 should *diff* against `docs/product/domain-model.md`, not copy it. Reference the existing model and describe only what changes.
- **Leaving edge cases implicit.** "Obviously it keeps the data" is the most common source of implementation drift. State the rule explicitly in §5.
- **Bundling behaviours in Gherkin.** One scenario per behaviour. A scenario that creates, edits, toggles, and filters is four scenarios.
- **Resolved questions left in §9.** Once a question is answered, fold the answer into the relevant section and remove the question.
- **Skipping the clarifying-questions step.** PRDs drafted without resolving design tensions (storage model, coupling, migration) get rewritten in review. Ask first.
- **Inventing a template.** The structure is fixed by `docs/prd.template.md`. If you feel a section is missing, raise it as an open question — do not add ad hoc sections.

## Example references

- `docs/product/requirements/0001-explicit-buy-sell-make-capabilities.md` — the first PRD written against this template, covering a reversion of inferred capability logic to explicit user-controlled toggles. Use it as a reference for tone, section length, and how to handle a PRD that supersedes an ADR.

## See also

- `product-documentation` skill — for evergreen product artifacts (vision, domain model, UI/UX).
- `developer-documentation` skill — for ADRs that a PRD may require.
- `writing-gherkin` skill — for the Acceptance Criteria section.
- `immutable-migration-patches` skill — for the migration strategy section when a schema change is involved.