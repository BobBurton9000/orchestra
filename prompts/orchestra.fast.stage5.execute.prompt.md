---
agent: orchestrator
description: Execute a refined implementation plan with a lightweight stage 5 flow
---
# Goal
Execute the current plan chunk by chunk, keep plan status accurate on disk, and finish with validated, in-scope work that is ready for review.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. In-scope chunks in `.agents/orchestra/<branch-name>/plan.md` were implemented or explicitly marked not applicable with justification.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 5 as the current branch stage.
3. Chunk and task statuses in the plan were kept current on disk during execution.
4. Validation, review feedback, and risk reconciliation were completed for the implemented work.
5. An execution report was written at `.agents/orchestra/<branch-name>/execution-report.md` using the [execution-report.template](orchestra.templates/execution-report.template.md).
6. Final integration and manual testing defined by the plan were completed before the stage was considered done.

# Steps
1. Read `.agents/orchestra/<branch-name>/plan.md` as the canonical execution source. If the file does not exist, return `ERROR: no plan found for branch <branch-name>`.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 5
	Prompt: orchestra.fast.stage5.execute
	Name: Execute
	```
3. Read [execution-report.template](orchestra.templates/execution-report.template.md) and use it to structure `.agents/orchestra/<branch-name>/execution-report.md`.
4. Execute the plan chunk by chunk, keeping task and chunk status current in `.agents/orchestra/<branch-name>/plan.md`. Consult specialist agents when helpful.
5. For each chunk, complete implementation, code review, validation, and any necessary follow-up fixes before marking it complete.
6. Reconcile risks and run the plan's final operations, with integration testing before manual testing.
7. Write the execution report and submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Plan source: <path>
Execution report: <path>
Completed chunks: <number>/<number>
Final status: <Go|No-Go>
```