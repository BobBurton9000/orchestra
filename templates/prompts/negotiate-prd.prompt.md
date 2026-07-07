---
description: Negotiate an implementation plan from a PRD with the architect, driven by review feedback, and write it to .temp/<branch-name>/implementation-plan-<prd-slug>.md
---
# Goal
Produce a converged implementation plan from a PRD by orchestrating the architect through review rounds driven by judge and scope-guard, then persist the plan to `.temp/<branch-name>/implementation-plan-<prd-slug>.md`.

# Variables
- `{{ file }}`: The PRD path supplied by the user.
  - If `{{ file }}` contains no `/`, resolve it as `docs/product/requirements/{{ file }}`.
  - Accept the argument with or without a trailing `.md`.
  - If the resolved path does not exist, return `ERROR: PRD file not found`.
  - If `{{ file }}` is empty, return `ERROR: no PRD file provided`.
- `<branch-name>`: Resolve the current branch using `git branch --show-current`, then normalize it by replacing `/` and whitespace with `-` so the result is safe to use as one directory name.
- `<prd-slug>`: Derive a concise deterministic slug from the PRD filename stem. Strip the leading `NNNN-` number prefix, lowercase it, replace whitespace and path separators with `-`, remove characters that are unsafe for filenames, collapse repeated `-`, trim leading and trailing `-`, and keep it short but recognizable.
- `<output-dir>`: `.temp/<branch-name>/`
- `<output-path>`: `.temp/<branch-name>/implementation-plan-<prd-slug>.md`

# Invocation Pattern
This prompt is executed with a required PRD file path.

- Example: `/negotiate-prd 0001-explicit-buy-sell-make-capabilities`
- Example: `/negotiate-prd docs/product/requirements/0001-explicit-buy-sell-make-capabilities.md`
- Example: `<this-command> <prd path>`

Inference rules:
1. Treat the full invocation text as `{{ file }}`.
2. If `{{ file }}` is empty, return `ERROR: no PRD file provided`.
3. Resolve `<branch-name>` from the current git branch, then normalize it before using `<output-dir>` or `<output-path>`.
4. Derive `<prd-slug>` from the PRD filename stem before using `<output-path>`.
5. If slug generation would be empty after normalization, use `prd` as the fallback slug.
6. If `<output-path>` already exists, read it first and update it in place so earlier plan notes remain aligned with the latest negotiation output unless the user supplies a new PRD file.

# Required Outcomes
1. `<output-path>` exists after execution.
2. The only permitted workspace edits are creating `<output-dir>` if needed and creating or updating `<output-path>`.
3. No code, test, configuration, or documentation files outside `<output-path>` are modified.
4. The plan follows every section of `docs/plankit-implementation-plan.template.md`, with no headings renamed or omitted.
5. Every requirement in PRD §5 and every acceptance criterion in PRD §10 is traced to at least one task in the plan.
6. No task in the plan falls outside the PRD's stated scope.
7. The negotiation runs at most 9 review rounds before stopping. If unresolved issues remain after round 9, fold them into the plan's "User Inputs Required" section and report them as outstanding follow-ups.
8. The final chat response reports only completion status, output path, rounds taken (out of 9), and any outstanding follow-ups.

# Agent Capability Resolution
This prompt delegates work by capability, not by agent name. When resolving which agent to use for a capability, pick the narrowest available agent that fits the work.

| Capability needed | Must be able to | Typical agent examples |
|---|---|---|
| Research | Search codebase, read files, compile findings into a report without writing code or making judgements | `information-gatherer` |
| Planning | Produce and revise an implementation plan as markdown against the canonical template | `architect` |
| Completeness verdict | Independently decide whether the plan covers every PRD requirement and acceptance criterion | `judge` |
| Scope verdict | Reject plan tasks that fall outside the PRD's stated scope | `scope-guard` |
| Document write | Write the converged plan markdown to `<output-path>` | `scribe` |

Dispatch to whichever available agent best fulfils the capability. The agent landscape varies across projects; adapt accordingly.

# Negotiation Loop
Run at most 9 review rounds. Each round follows the same shape.

## Round 0 (once, before review rounds)
Delegate a research agent to read and return the full content of:
- the PRD at the resolved `{{ file }}` path
- `docs/product/vision.md` if present
- `docs/product/domain-model.md` if present
- `docs/product/ui-ux.md` if present
- any ADRs under `docs/dev/adr/` referenced by the PRD metadata block

Return the consolidated content to the orchestrator. No plan is drafted in this round.

## Round n (n = 1..9)
1. Delegate the planning agent to draft (round 1) or revise (rounds 2+) the implementation plan as markdown.
   - Pass the full PRD content and evergreen doc excerpts gathered in round 0.
   - Pass the consolidated reviewer feedback from the previous round (round 1 has none).
   - Reference `docs/plankit-implementation-plan.template.md` as the required structure.
   - Instruct the planning agent to load the `writing-prds` skill before starting.
2. In parallel, delegate the two reviewers:
   - Completeness reviewer: decide whether every PRD §5 requirement and every PRD §10 acceptance criterion is traced to at least one plan task. Return `Approved` or `Rejected` with specific gaps.
   - Scope reviewer: decide whether any plan task falls outside the PRD's stated scope. Return `Approved` or `Rejected` with specific creep items.
3. If both reviewers return `Approved`, the plan has converged. Go to Persist.
4. If either reviewer returns `Rejected`, consolidate the feedback into a single revision brief and continue to the next round.

## Stop Condition
- On convergence (both reviewers approve) at any round 1..9: go to Persist.
- After 9 unconverged rounds: stop. Delegate the planning agent one final time to fold the outstanding issues into the plan's "User Inputs Required" section, then go to Persist. Report the unresolved issues as outstanding follow-ups in the final response.

# Persist
1. Ensure `<output-dir>` exists.
2. Delegate a document-writing agent to write the converged plan markdown to `<output-path>`.
   - If the plan has unresolved items after round 9, the planning agent must have folded them into §"User Inputs Required" before handoff.
3. If `<output-path>` already exists, read it first and update it in place so earlier plan notes remain aligned unless the user supplied a new PRD file.

# Constraints
1. Do not implement code.
2. Do not edit product code.
3. Do not run tests.
4. Do not widen the plan's scope beyond the PRD.
5. Do not auto-commit the generated plan file. Leave it uncommitted for the user to review.
6. Do not run more than 9 review rounds before stopping with follow-ups.
7. The orchestrator delegates every step; it performs no direct work.

# Steps
1. Validate input. If `{{ file }}` is empty, return `ERROR: no PRD file provided`.
2. Resolve the PRD path. If the file does not exist, return `ERROR: PRD file not found`.
3. Resolve and normalize `<branch-name>`.
4. Derive `<prd-slug>` from the PRD filename stem.
5. Ensure `<output-dir>` exists.
6. If `<output-path>` already exists, read it in full before negotiating so refinements preserve prior plan notes unless the user supplied a new PRD file.
7. Run Round 0: delegate a research agent to gather the PRD and relevant evergreen docs, return the consolidated content.
8. Run Rounds 1..9 as described in Negotiation Loop until convergence or the stop condition.
9. On convergence or stop, delegate a document-writing agent to write the converged plan to `<output-path>`.
10. Return only:
    - `Status: Completed` or `Status: ERROR`
    - `Rounds: <n> of 9`
    - `Output: <output-path>`
    - `Outstanding follow-ups: <list | none>`

# Response To User
Status: <Completed|ERROR>
Rounds: <n> of 9
Output: <output-path>
Outstanding follow-ups: <list|none>