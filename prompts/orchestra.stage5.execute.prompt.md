---
agent: orchestrator
description: Execute a refined implementation plan with the gherkin-driven stage 5 flow
name: orchestra.stage5.execute
---
# Goal
Execute the current plan chunk by chunk, keep plan status accurate on disk, and finish with validated, in-scope work that is ready for review.

Treat `.agents/orchestra/<branch-name>/gherkin.md` as immutable supporting context and do not modify it.

This stage is not complete until every Gherkin statement in `.agents/orchestra/<branch-name>/gherkin.md`, including statements under `Related Gherkin`, has been delegated to manual testing agents and independently verified as true with 100% coverage.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. In-scope chunks in `.agents/orchestra/<branch-name>/plan.md` were implemented or explicitly marked not applicable with justification.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 5 as the current branch stage.
3. Chunk and task statuses in the plan were kept current on disk during execution.
4. Validation, review feedback, and risk reconciliation were completed for the implemented work.
5. An execution report was written at `.agents/orchestra/<branch-name>/execution-report.md` using the [execution-report.template](orchestra.templates/execution-report.template.md).
6. Every Gherkin statement in `.agents/orchestra/<branch-name>/gherkin.md`, including `Related Gherkin`, was delegated to one or more manual testing agents and independently verified.
7. Final integration and manual testing defined by the plan were completed before the stage was considered done.
8. The stage finished only when manual verification reached 100% and all Gherkin statements were confirmed true.
9. `.agents/orchestra/<branch-name>/gherkin.md` remained unchanged.

# Steps
1. Read `.agents/orchestra/<branch-name>/plan.md` as the canonical execution source. If the file does not exist, return `ERROR: no plan found for branch <branch-name>`.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 5
	Prompt: orchestra.stage5.execute
	Name: Execute
	```
3. Read [execution-report.template](orchestra.templates/execution-report.template.md) and use it to structure `.agents/orchestra/<branch-name>/execution-report.md`.
4. Read [manual-testing-instructions](orchestra.config/manual-testing-instructions.md) before delegating manual verification.
5. Execute the plan chunk by chunk, keeping task and chunk status current in `.agents/orchestra/<branch-name>/plan.md`.
6. For each chunk, complete implementation, code review, validation, and any necessary follow-up fixes before marking it complete.
7. After implementation stabilises, enumerate every individual Gherkin statement in `.agents/orchestra/<branch-name>/gherkin.md`, including statements under `Changed Files` and `Related Gherkin`, and treat that list as the required manual verification scope.
8. Delegate manual verification of that scope to the appropriate manual testing agents. Use browser-oriented agents for UI or workflow assertions and other suitable manual testing agents for non-UI assertions when available. Do not self-attest these checks without agent delegation.
9. Require independent evidence for every statement: the validating agent, the scenario exercised, and whether the statement was confirmed true, blocked, or false.
10. If any Gherkin statement is false or blocked, do not mark the stage complete. Continue implementation, debugging, and validation work until that statement is verified as true.
11. Reconcile risks and run the plan's final operations, with integration testing before the final manual verification pass.
12. Do not modify `.agents/orchestra/<branch-name>/gherkin.md`
13. Before you can consider this prompt complete you must ask tester agents to independently verify all gherkin scenarios that appear in the `gherkin.md` file (including those previously tested). If any gherkin scenarios fail you must append chunks and tasks to your plan file to close gaps that you believe will make them succeed next time and return to step 5.
14. Write the execution report, including the full Gherkin verification ledger and final coverage status, and submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Plan source: <path>
Execution report: <path>
Completed chunks: <number>/<number>
Verified Gherkin statements: <number>/<number>
Final status: <Go>
```