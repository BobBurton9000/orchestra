---
agent: orchestrator
name: orchestra.plan.execute
description: Execute the branch implementation plan to a high technical standard, produce evidence in execution-report.md, and enforce manual QA quality gates
argument-hint: "optional: specific chunk/task focus or execution constraint"
---

# Goal
Implement the branch plan at `.agents/orchestra/<branch-name>/plan.md` with high technical excellence and complete quality assurance evidence, then write `.agents/orchestra/<branch-name>/execution-report.md` using [execution-report.template.md](orchestra.templates/execution-report.template.md).

Execution is complete only when all required quality gates pass, there are no unresolved blockers/issues, and the execution report is fully populated with evidence.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<plan-path>`: `.agents/orchestra/<branch-name>/plan.md`
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
3. If `<plan-path>` is missing, return `ERROR: plan not found`.
4. If `<gherkin-path>` exists, manual verification must cover all statements in that file, including `Related Gherkin`.

# Required Outcomes
1. `<plan-path>` is read and treated as the canonical implementation source.
2. All relevant plan chunks/tasks within scope are implemented in code with production-quality changes.
3. Frequent code-review loops are run using code-review agents, and critical/high findings are resolved before completion.
4. Automated validation from the plan is executed (or explicitly marked `not applicable` or `not practical` with reasons) and evidence is captured.
5. Manual QA is executed with manual testing agents and evidence is captured for all required scenarios.
6. If `<gherkin-path>` exists, 100% of `Given/When/Then/And/But` statements are independently verified true, or the run remains `Blocked`.
7. Any initial false/blocked Gherkin statements are resolved and documented in blocker resolution evidence before final `Go`.
8. **Self-resolution loop (required)**: All detected blockers, failures, defects, or quality gate violations automatically trigger immediate resolution attempts and full re-validation; repeat until the issue set is empty.
9. `<execution-report-path>` is written using [execution-report.template.md](orchestra.templates/execution-report.template.md) structure.
10. `Blocked` is allowed only for hard-stop constraints that cannot be self-resolved in-session (for example: missing required external credentials/access, unavailable mandatory dependency/service, or explicit user hold). These constraints must be evidenced in the report with attempted mitigations.
11. Final status is not `Go` if unresolved critical/high defects, failing quality gates, unverified required statements, or any open blocker/issue remains.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Confirm `<plan-path>` exists. If missing, return `ERROR: plan not found`.
3. Load execution context:
   - Read `<plan-path>`.
   - Read `<gherkin-path>` if present.
   - Read [execution-report.template.md](orchestra.templates/execution-report.template.md).
   - Read [manual-testing-instructions.md](orchestra.config/manual-testing-instructions.md) when `<gherkin-path>` is present.
4. Build an execution backlog from plan chunks/tasks, constrained by `{{ execution-scope }}` when provided.
5. Execute implementation iteratively by delegating to the appropriate specialist programmer agents.
6. After each meaningful code increment, delegate review to relevant code-review agents and route any serious findings back to implementation/debugging agents until resolved.
7. Run required automated validation from the plan:
   - Unit tests
   - Integration tests
   - Other plan-defined checks
   Record exact commands and outcomes.
8. Run manual QA validation using manual testing agents for plan journeys and user-facing flows.
9. If `<gherkin-path>` exists, perform complete statement-level independent verification:
   - Verify every `Given/When/Then/And/But` statement from both `Changed Files` and `Related Gherkin`.
   - Record source section, file path, scenario, exact statement, validating agent, result (`true|false|blocked`), and evidence.
   - If any statement is `false` or `blocked`, treat as a blocker: resolve, re-test, and re-verify until true; only hard-stop constraints may remain `blocked`.
10. Run a self-resolution closure loop across all findings (code review, tests, manual QA, Gherkin, and plan checkpoints):
   - Build a current open-issues list.
   - Resolve each item, then re-run the minimum required validations to prove closure.
   - Repeat until open-issues list is empty.
   - If any issue remains due to a hard-stop constraint, document evidence and mark final status `Blocked`.
11. Reconcile execution outcomes against plan risks and checkpoints.
12. Write `<execution-report-path>` using the execution-report template, ensuring all sections contain concrete evidence.
13. Return final response using the response contract.

# Response To User
```
Branch: <branch-name>
Plan: <plan-path>
Execution report: <execution-report-path>
Executed chunks: <count>
Changed files: <count>
Manual verification: <pass|fail|blocked>
Gherkin coverage: <verified>/<total> (<pass|fail|not-applicable>)
Final status: <Go|Blocked|ERROR>
```
