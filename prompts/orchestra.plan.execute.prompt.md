---
agent: orchestrator
name: orchestra.plan.execute
description: Execute the branch implementation plan to a high technical standard, produce evidence in execution-report.md, enforce manual QA quality gates, and prevent review-driven scope creep during execution
argument-hint: "optional: specific chunk/task focus or execution constraint"
---

# Goal
Implement the branch chunked plan at `.agents/orchestra/<branch-name>/chunk-plan.md` with high technical excellence, keep the chunk/task status fields in that plan updated as execution progresses, prevent or undo scope creep discovered during review loops, and then write `.agents/orchestra/<branch-name>/execution-report.md` using [execution-report.template.md](orchestra.templates/execution-report.template.md).

Execution is complete only when all required quality gates pass, there are no unresolved blockers/issues, and the execution report is fully populated with evidence.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<chunk-plan-path>`: `.agents/orchestra/<branch-name>/chunk-plan.md`
- `<gherkin-path>`: `.agents/orchestra/<branch-name>/gherkin.feature`
- `<execution-report-path>`: `.agents/orchestra/<branch-name>/execution-report.md`
- `{{ execution-scope }}`: Optional invocation hint narrowing execution to specific chunks, tasks, or constraints.

# Invocation Pattern
This prompt is executed with an optional execution scope hint.

- Example: `/orchestra.plan.execute`
- Example: `<this-command> execute only chunk 2`
- Example: `<this-command> prioritise backend tasks first`

Inference rules:
1. If `{{ execution-scope }}` is present, treat it as a bounded execution hint and apply it without violating required quality gates.
2. If `{{ execution-scope }}` conflicts with the plan, prioritise plan correctness and return a concrete mismatch note in the response.
3. If `<chunk-plan-path>` is missing, return `ERROR: chunk plan not found`.
4. If `<gherkin-path>` exists, manual verification must cover all statements in that file, including `Related Gherkin`.

# Required Outcomes
1. `<chunk-plan-path>` is read and treated as the canonical implementation source.
2. All relevant plan chunks/tasks within scope are implemented in code with production-quality changes.
3. `<chunk-plan-path>` remains a live execution source of truth: relevant chunk and task `Status` fields are updated in place as work progresses, using `pending`, `in_progress`, `completed`, or `blocked`.
4. Task statuses are updated as execution advances: mark a task `in_progress` before active implementation, `completed` only after its implementation and required validations/review checkpoints are satisfied, and `blocked` only for hard-stop constraints that cannot be self-resolved in-session.
5. Chunk statuses are kept in sync with their child tasks: mark a chunk `in_progress` when scoped work starts, `completed` only when its scoped tasks are completed and its chunk-level validation passes, and `blocked` only when a hard-stop constraint prevents completion.
6. Frequent code-review loops are run using code-review agents, and `scope-guard` is used to prevent review findings from broadening implementation beyond the approved plan.
7. If review or validation uncovers already-applied scope creep, the smallest safe undo is delegated before completion.
8. Automated validation from the plan is executed (or explicitly marked `not applicable` or `not practical` with reasons) and evidence is captured.
9. Manual QA is executed with manual testing agents and evidence is captured for all required scenarios.
10. If `<gherkin-path>` exists, 100% of `Given/When/Then/And/But` statements are independently verified true, or the run remains `Blocked`.
11. Any initial false/blocked Gherkin statements are resolved and documented in blocker resolution evidence before final `Go`.
12. **Self-resolution loop (required)**: All detected blockers, failures, defects, or quality gate violations automatically trigger immediate resolution attempts and full re-validation; repeat until the issue set is empty.
13. `<execution-report-path>` is written using [execution-report.template.md](orchestra.templates/execution-report.template.md) structure.
14. `Blocked` is allowed only for hard-stop constraints that cannot be self-resolved in-session (for example: missing required external credentials/access, unavailable mandatory dependency/service, or explicit user hold). These constraints must be evidenced in the report with attempted mitigations.
15. Final status is not `Go` if unresolved critical/high defects, failing quality gates, unverified required statements, any open blocker/issue remains, or plan statuses are out of sync with actual execution state.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Confirm `<chunk-plan-path>` exists. If missing, return `ERROR: chunk plan not found`.
3. Load execution context:
   - Read `<chunk-plan-path>`.
   - Read `<gherkin-path>` if present.
   - Read [execution-report.template.md](orchestra.templates/execution-report.template.md).
   - Read [manual-testing-instructions.md](orchestra.config/manual-testing-instructions.md) when `<gherkin-path>` is present.
4. Build an execution backlog from plan chunks/tasks, constrained by `{{ execution-scope }}` when provided.
5. Treat `<chunk-plan-path>` as a live tracker during execution:
   - Before starting a chunk or task, update its `Status` to `in_progress` in `<chunk-plan-path>`.
   - After each meaningful increment, reconcile task/chunk statuses in `<chunk-plan-path>` so they match the current state of the work.
   - When a task clears its implementation, review checkpoints, and required validations, update it to `completed`.
   - When all scoped tasks for a chunk are `completed` and the chunk validation passes, update the chunk to `completed`.
   - If a hard-stop constraint prevents progress, update the affected task/chunk to `blocked` and capture the evidence for the execution report.
6. Execute implementation iteratively by delegating to the appropriate specialist programmer agents.
7. After each meaningful code increment, delegate review to relevant code-review agents, then run `scope-guard` against the resulting findings before accepting any follow-up work:
   - Resolve in-scope findings through the appropriate implementation or debugging agents.
   - Do not implement out-of-scope improvement requests in this execution run.
   - If `scope-guard` determines already-applied work exceeded the plan scope, delegate the smallest safe undo and then re-run the affected review and validation checks.
8. Run required automated validation from the plan:
   - Unit tests
   - Integration tests
   - Other plan-defined checks
   Record exact commands and outcomes.
9. Run manual QA validation using manual testing agents for plan journeys and user-facing flows.
10. If `<gherkin-path>` exists, perform complete statement-level independent verification:
   - Verify every `Given/When/Then/And/But` statement from both `Changed Files` and `Related Gherkin`.
   - Record source section, file path, scenario, exact statement, validating agent, result (`true|false|blocked`), and evidence.
   - If any statement is `false` or `blocked`, treat as a blocker: resolve, re-test, and re-verify until true; only hard-stop constraints may remain `blocked`.
11. Run a self-resolution closure loop across all findings (code review, tests, manual QA, Gherkin, and plan checkpoints):
   - Build a current open-issues list.
   - Resolve each item, then re-run the minimum required validations to prove closure.
   - Update the affected task/chunk `Status` fields in `<chunk-plan-path>` after each issue is resolved or confirmed blocked.
   - Keep out-of-scope items out of the open-issues list for implementation and surface them as follow-up for the user instead.
   - Repeat until open-issues list is empty.
   - If any issue remains due to a hard-stop constraint, document evidence and mark final status `Blocked`.
12. Reconcile execution outcomes against plan risks and checkpoints.
13. Perform a final status reconciliation in `<chunk-plan-path>` so every in-scope chunk/task accurately reflects the completed, pending, or blocked state before writing the report.
14. Write `<execution-report-path>` using the execution-report template, ensuring all sections contain concrete evidence.
15. Return final response using the response contract.

# Response To User
```
Branch: <branch-name>
Plan: <chunk-plan-path>
Execution report: <execution-report-path>
Executed chunks: <count>
Changed files: <count>
Manual verification: <pass|fail|blocked>
Gherkin coverage: <verified>/<total> (<pass|fail|not-applicable>)
Final status: <Go|Blocked|ERROR>
```
