---
agent: orchestrator
name: orchestra.review-feedback
description: Address all reviewer feedback on the current PR by retrieving the canonical feedback set from the active pull request first, then the currently open pull request if needed, and resolving each actionable item deterministically.
argument-hint: "optional: restrict to specific reviewer, comment, file, or feedback category"
---

# Goal
Address reviewer feedback for the current pull request using a single standard retrieval flow, resolve every actionable item deterministically, validate affected changes, and leave the result ready for user review without committing or pushing automatically.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `{{ feedback-scope }}`: Optional invocation hint restricting the run to a reviewer, comment, file, category, or explicitly named subset of feedback.

# Invocation Pattern
This prompt is executed against the current pull request with an optional feedback scope hint.

- Example: `/orchestra.review-feedback`
- Example: `<this-command> reviewer alice only`
- Example: `<this-command> only comments on src/auth/**`

Inference rules:
1. Resolve the current pull request by calling the active pull request tool first.
2. If no active pull request can be resolved, use the currently open pull request tool.
3. If neither tool resolves a pull request, return `ERROR: no current pull request could be resolved`.
4. Treat the resolved pull request as the canonical review target for the entire run.
5. If `{{ feedback-scope }}` is present, narrow the feedback backlog to that scope without ignoring any directly referenced item.
6. If `{{ feedback-scope }}` conflicts with the resolved pull request data, prioritise the pull request data and report the mismatch in the final response.

# Standard Feedback Retrieval
Build the reviewer-feedback backlog in this exact order:
1. Resolve the current pull request using the active pull request tool, with fallback to the currently open pull request tool.
2. Read the pull request review comments and review submissions from that resolved pull request.
3. Retrieve the same pull request by number using the issue or pull request details tool and merge any actionable general pull request discussion comments that request a change.
4. Normalise the combined feedback into unique items keyed by reviewer, source comment or review id, affected file or location when present, and requested change summary.
5. Mark each item exactly once as `Action required`, `No action`, or `Blocked`.

# Required Outcomes
1. The current pull request is resolved explicitly before any implementation work starts.
2. Reviewer feedback is retrieved through the `Standard Feedback Retrieval` flow and not from ad hoc chat summarisation.
3. Every actionable reviewer item in scope is classified exactly once as `Resolved`, `No action`, or `Blocked`.
4. `No action` is used only when repository evidence, current code, or superseding later review state establishes that no change is required.
5. Duplicate, obsolete, or already-addressed feedback is not implemented twice and is captured as `No action` with evidence.
6. Each `Resolved` item results in the necessary code, test, or documentation changes for the concern it raises.
7. Targeted validation is re-run for every touched area, and broader validation is run when the feedback indicates systemic risk.
8. Relevant code-review agents are re-run after meaningful fixes.
9. No commit or push is created automatically.
10. If any in-scope reviewer item cannot be resolved safely, the response returns it as a concrete blocker rather than implying completion.

# Resolution Rules
1. Treat reviewer-reported correctness, security, data integrity, compatibility, and reliability issues as blockers until disproved or fixed.
2. Prefer repository evidence over reviewer phrasing when determining the precise fix, but never dismiss a reviewer concern without evidence.
3. Narrow implementation work to the smallest change that fully resolves the concern.
4. Delegate each item to the narrowest specialist agent or agent group that matches the affected area.
5. Re-run the most relevant reviewer agents after fixes so the branch is not left with unchallenged regressions.
6. Do not post GitHub comments or review events unless the user explicitly asks for that in a separate request.

# Steps
1. **Resolve branch and pull request context**:
   1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
   2. Resolve the current pull request using the `Invocation Pattern` rules.
   3. Read `.agents/orchestra/<branch-name>/plan.md` and `.agents/orchestra/<branch-name>/execution-report.md` when present so fixes stay grounded in the intended branch behaviour.
2. **Build the reviewer-feedback backlog**:
   1. Execute the `Standard Feedback Retrieval` flow.
   2. Remove exact duplicates and collapse materially identical comments into one backlog item.
   3. Apply `{{ feedback-scope }}` when present.
   4. Classify each item as `Action required`, `No action`, or `Blocked pending investigation`.
3. **Resolve actionable feedback iteratively**:
   1. Delegate each actionable item to the narrowest appropriate specialist sub agents.
   2. If a comment identifies a defect but not the fix, route investigation through the debugger or architect before implementation.
   3. After each meaningful fix, run the relevant code-review agents and route any serious findings back into implementation before continuing.
   4. Continue until every in-scope actionable item is `Resolved`, `No action`, or `Blocked`.
4. **Validate the updated branch**:
   1. Run targeted automated validation for the touched areas.
   2. Run broader validation when feedback reveals cross-cutting risk or when targeted checks are insufficient evidence.
   3. If user-facing behaviour changed, run manual browser verification for the affected flows.
5. **Prepare the result for user review**:
   1. Leave changes uncommitted unless the repository workflow explicitly requires a local commit and the user asked for it.
   2. Do not push automatically.
   3. Capture the pull request URL when available.
6. **Finalize response**:
   1. Report the branch, pull request URL, feedback source used, number of items resolved, number marked no action, number blocked, validation outcome, and final status.
   2. Return only the response contract from this prompt.

# Response To User
```
Branch: <branch-name>
Pull request: <url|None>
Feedback source: <Active pull request|Open pull request>
Resolved items: <number>
No action items: <number>
Blocked items: <number>
Validation: <Passed|Failed|Blocked|Not run>
Final status: <Resolved locally|Blocked|ERROR>
```