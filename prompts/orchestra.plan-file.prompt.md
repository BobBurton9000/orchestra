---
agent: orchestrator
description: "Research a workspace goal, clarify requirements, and write a detailed planning-only implementation plan to `.orchestra/<branch-name>/plan-<plan-slug>.md` without starting implementation"
name: orchestra.plan-file
argument-hint: "outline the goal or problem to research"
handoffs:
  - label: Start Implementation
    agent: agent
    prompt: Start implementation
    send: true
  - label: Open in Editor
    agent: agent
    prompt: Open the generated plan file in `.orchestra/` for further refinement.
    send: true
    showContinueOn: false
---

# Goal
Research the developer request, clarify important ambiguities with the user, and produce a detailed actionable plan at `.orchestra/<branch-name>/plan-<plan-slug>.md`.

This prompt is planning-only. It must never start implementation.

# Variables
- `{{ request }}`: The developer request to research and plan.
- `<branch-name>`: Resolve the current branch using [branch-name](orchestra.snippets/branch-name.md), then normalize it by replacing `/` and whitespace with `-` so the result is safe to use as one directory name.
- `<plan-slug>`: Derive a concise deterministic slug from `{{ request }}`. Lowercase it, replace whitespace and path separators with `-`, remove characters that are unsafe for filenames, collapse repeated `-`, trim leading and trailing `-`, and keep it short but recognizable.
- `<plan-dir>`: `.orchestra/<branch-name>/`
- `<plan-path>`: `.orchestra/<branch-name>/plan-<plan-slug>.md`

# Invocation Pattern
This prompt is executed with a required goal or problem statement.

- Example: `/orchestra.plan-file add audit logging for failed login attempts`
- Example: `<this-command> investigate flaky webhook retries and outline a fix`

Inference rules:
1. Treat the full invocation text as `{{ request }}`.
2. If `{{ request }}` is empty, return `ERROR: no planning request provided`.
3. Resolve `<branch-name>` from the current git branch, then normalize it before using `<plan-dir>` or `<plan-path>`.
4. Derive `<plan-slug>` from `{{ request }}` before using `<plan-path>`.
5. If slug generation would be empty after normalization, use `plan` as the fallback slug.
4. If `<plan-path>` already exists, read it first and update it in place so earlier decisions remain in sync.

# Required Outcomes
1. `<plan-path>` exists after execution.
2. The only permitted workspace edits are creating `<plan-dir>` if needed and creating or updating `<plan-path>`.
3. No implementation work is started and no code, test, or configuration files outside `<plan-path>` are modified.
4. Discovery research is completed before the final plan is presented.
5. Material ambiguities are clarified with the user instead of being silently assumed.
6. The final plan is shown in chat as a scannable summary; the file is for persistence, not a substitute for presenting the plan.
7. The plan is detailed enough for another agent or developer to execute without reopening fundamental design questions.
8. When the user requests revisions, `<plan-path>` is updated to keep the persisted plan aligned with the latest approved direction.

# Plan Document Structure
Write `<plan-path>` as markdown with these sections in this order:
1. `## Plan: {Title}`
2. A short TL;DR covering what will change, why it matters, and the recommended implementation direction.
3. `**Steps**` with explicit sequencing, dependencies, and parallelism where relevant.
4. `**Relevant files**` with full workspace paths and brief notes on what to modify or reuse, including specific functions, types, or patterns when known.
5. `**Verification**` with concrete automated and manual validation steps.
6. `**Decisions**` when assumptions, inclusions, exclusions, or chosen tradeoffs need to be recorded.
7. `**Further Considerations**` only when a remaining choice should be surfaced with a recommendation.

Additional plan rules:
1. Keep the plan concise enough to scan but specific enough to execute.
2. Group long plans into named phases that are independently verifiable.
3. Call out which steps can run in parallel and which steps block later work.
4. Define explicit scope boundaries, including what is deliberately excluded.
5. Do not include implementation code in the plan.
6. Do not end with blocking questions; ask clarification questions during the workflow instead.

# Steps
1. Validate input. If `{{ request }}` is empty, return `ERROR: no planning request provided`.
2. Resolve and normalize `<branch-name>`.
3. Derive `<plan-slug>` from `{{ request }}`.
4. Ensure `<plan-dir>` exists.
5. If `<plan-path>` already exists, read it in full before researching so refinements preserve prior decisions unless the user changes them.
6. Start discovery:
   - Gather repository context, analogous implementations, and likely blockers.
   - Use the `Explore` subagent for read-only discovery.
   - When the task spans multiple largely independent areas, launch 2 or 3 `Explore` subagents in parallel, one per area.
7. Update your working understanding from the discovery findings.
8. If discovery surfaces major ambiguity, conflicting constraints, or meaningful design alternatives, use `#tool:vscode/askQuestions` to clarify intent with the user before finalizing the plan.
9. If the answers materially change scope or approach, loop back through discovery for the affected area before drafting the final plan.
10. Draft the complete plan using the required structure and ensure it includes dependencies, verification, relevant files, architecture references, scope boundaries, and captured decisions.
11. Write or update `<plan-path>`.
12. Present the plan to the user in chat as a scannable summary and identify `<plan-path>` for persistence.
13. If the user asks for changes, revise both the chat-presented plan and `<plan-path>` until the plan is approved.
14. If the user asks to implement, stop planning and direct them to use the handoff rather than starting implementation inside this prompt.

# Response To User
If successful:
```
Plan file: .orchestra/<branch-name>/plan-<plan-slug>.md
Status: Ready for review
Next step: Use Start Implementation when the plan is approved
```

If input is missing:
```
ERROR: no planning request provided
```