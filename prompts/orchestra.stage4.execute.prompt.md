---
agent: orchestrator
name: orchestra.stage4.execute
description: Execute the current branch plan with review and validation loops, keep an append-only chronological execution diary, and merge branch gherkin into the project living gherkin base when applicable
argument-hint: "optional: specific task focus or execution constraint"
---

# Goal
Implement the branch plan at `.agents/orchestra/<branch-name>/plan.md` with high technical excellence, keep an append-only chronological diary in `.agents/orchestra/<branch-name>/execution-report.md`, prevent or undo scope creep discovered during review loops, and finish only when the required validations are satisfied or a real hard-stop blocker remains.

If branch Gherkin exists, merge it into the project-root `.gherkin/` living base as part of execution and validation.

# Agent Use Policy
During this stage, Orchestra may use all agents.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<task-path>`: `.agents/orchestra/<branch-name>/task.md`
- `<research-dir>`: `.agents/orchestra/<branch-name>/research`
- `<plan-path>`: `.agents/orchestra/<branch-name>/plan.md`
- `<gherkin-path>`: `.agents/orchestra/<branch-name>/gherkin.feature`
- `<execution-report-path>`: `.agents/orchestra/<branch-name>/execution-report.md`
- `{{ execution-scope }}`: Optional invocation hint narrowing execution to a specific plan task, slice, or constraint.

# Invocation Pattern
- Example: `/orchestra.stage4.execute`
- Example: `<this-command> focus on the authentication work first`
- Example: `<this-command> execute only the lowest-risk slice`

Inference rules:
1. If `<plan-path>` is missing, return `ERROR: plan not found`.
2. If `{{ execution-scope }}` conflicts with the plan, prioritize plan correctness and note the mismatch in the response.
3. If `<gherkin-path>` exists, it becomes an execution input and must be integrated into the project-root `.gherkin/` living base.

# Required Outcomes
1. Orchestra reads the following in full, every line, before implementation starts:
   - `<task-path>`
   - Every document in `<research-dir>`
   - `<plan-path>`
2. `<plan-path>` is treated as the canonical implementation source.
3. All relevant in-scope plan tasks are implemented in production-quality code.
4. Frequent review loops are run using the `code-review.*` agents, and `scope-guard` is used before accepting follow-up work that broadens scope.
5. If review or validation uncovers already-applied scope creep, the smallest safe undo is delegated before completion.
6. Automated validation from the plan is executed where practical and recorded with exact commands and outcomes.
7. Manual QA is executed for user-facing flows where relevant and recorded with evidence.
8. `<execution-report-path>` is written using [execution-report.template.md](orchestra.templates/execution-report.template.md).
9. `<execution-report-path>` is an append-only chronological diary:
   - Append an entry before and after every meaningful delegation, review cycle, validation run, blocker resolution attempt, and scope decision.
   - Never delete or rewrite earlier diary entries.
10. If `<gherkin-path>` exists, the branch Gherkin is merged into the appropriate project-root `.gherkin/` living base location and the report records what changed.
11. Blocked is allowed only for hard-stop constraints that cannot be resolved in-session.
12. Final status is not `Go` while unresolved critical defects, failing required checks, or unresolved hard-stop blockers remain.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Confirm `<task-path>` exists. If missing, return `ERROR: task document not found`.
3. Confirm `<plan-path>` exists. If missing, return `ERROR: plan not found`.
4. Read `<task-path>` in full.
5. Read every research document in `<research-dir>` in full.
6. Read `<plan-path>` in full.
7. Read [execution-report.template.md](orchestra.templates/execution-report.template.md) and initialize `<execution-report-path>` if it does not already exist.
8. Read [manual-testing-instructions.md](orchestra.config/manual-testing-instructions.md) when user-facing validation is required.
9. Build the execution backlog from `<plan-path>`, constrained by `{{ execution-scope }}` when provided.
10. Before each meaningful action, append a diary entry to `<execution-report-path>` recording what is about to happen and why.
11. Execute implementation iteratively by delegating to the narrowest appropriate specialist agents.
12. After each meaningful code increment:
   - Run relevant `code-review.*` agents.
   - Run `scope-guard` before accepting any review-driven expansion of scope.
   - Resolve in-scope findings.
   - If already-applied scope creep is identified, delegate the smallest safe undo and re-validate the affected area.
   - Append the outcome to `<execution-report-path>`.
13. Run required automated validation from the plan and append exact command outcomes to `<execution-report-path>`.
14. Run manual QA for user-facing flows and append evidence to `<execution-report-path>`.
15. If `<gherkin-path>` exists:
   - Review the project-root `.gherkin/` tree.
   - Merge the branch Gherkin into the appropriate living base file or create the correct new living Gherkin file when none exists.
   - Re-validate the resulting behaviour.
   - Append the integration details and evidence to `<execution-report-path>`.
16. Maintain a self-resolution loop:
   - Build the current open issues list from reviews, tests, manual QA, and Gherkin work.
   - Resolve each item and re-run the minimum required validations to prove closure.
   - Repeat until the issue list is empty or only true hard-stop blockers remain.
17. Append the final status and evidence to `<execution-report-path>`.
18. Return only the response contract.

# Response To User
```
Branch: <branch-name>
Task: .agents/orchestra/<branch-name>/task.md
Plan: .agents/orchestra/<branch-name>/plan.md
Execution report: .agents/orchestra/<branch-name>/execution-report.md
Gherkin merged: <yes|no>
Validation: <Passed|Failed|Blocked>
Final status: <Go|Blocked|ERROR>
```