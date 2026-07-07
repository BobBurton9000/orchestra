---
agent: agent
description: Draft a PRD for a discrete feature by clarifying with the user, then save it under the project's requirements directory using the writing-prds skill
name: create-prd
argument-hint: "describe the feature or problem the PRD should address"
---
# Goal
Draft a PRD for the supplied feature or problem and save it under the project's requirements directory, following the `writing-prds` skill (the single source of truth for structure, location, naming, and process).

# Steps
1. Load the `writing-prds` skill before drafting.
2. Research the project's existing product context (vision, domain model, UI/UX, style, existing PRDs/requirements, related ADRs and code). Do not assume specific filenames or locations — discover them.
3. Ask clarifying questions before drafting. Use the `question` tool to resolve design tensions that materially change the document (scope, storage, coupling, migration, UX). Do not ask what the repo already answers; do not draft until the material tensions are resolved.
4. Draft against the template referenced by the skill: strip per-section guidance comments, fill every section, and write "Not applicable" with a one-line reason for any section that does not apply (do not delete headings).
5. Present the draft to the user and get approval before saving.
6. Determine the next sequential `NNNN` by listing the requirements directory, then save as `NNNN-kebab-case-title.md`.
7. If the PRD supersedes or informs an ADR, reference it by number in the metadata block and §8.

# Response To User
- `Status: Completed` or `Status: ERROR`
- `Output: <path>`
- One-line summary of the feature.