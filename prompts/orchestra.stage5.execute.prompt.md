---
agent: orchestrator
description: Execute a refined implementation plan chunk by chunk until all quality gates pass and the work is shippable
---
# Goal
Execute a refined implementation plan by coordinating specialist agents chunk by chunk, validating continuously, and recursively fixing issues until all in-scope work is complete and shippable.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. All in-scope [chunks](orchestra.snippets/chunk.md) in `ai/orchestra/documents/<branch-name>/plan.md` are implemented, or any non-implemented chunk is explicitly justified as not applicable.
2. Every completed [chunk](orchestra.snippets/chunk.md) has recorded quality-gate evidence showing an initial failing or incomplete state and final passing verification by applicable sub agents.
3. No completed chunk has unresolved required code review feedback.
4. The plan's [risk](orchestra.snippets/risk.md) assessment is reconciled against the implemented changes for each chunk and across the completed branch.
5. Final integration testing and manual browser verification for touched user-facing areas and plan-defined final operations are complete.
6. One execution report is written at `ai/orchestra/documents/<branch-name>/execution-report.md` using `../templates/execution-report.template.md`.
7. No unresolved execution issues remain.
8. All changes remain within the plan's intended scope boundaries.
9. CI is confirmed passing through the `run-tests` skill after judge submission and before the branch is considered complete.
10. Technically weak code is not advanced solely because tests pass.

# Steps
1. **Load the plan and template**: Read `ai/orchestra/documents/<branch-name>/plan.md` as the canonical execution source. If the file does not exist, return `ERROR: no plan found for branch <branch-name>`. Read `../templates/execution-report.template.md` to determine the execution report structure. Extract chunk order, chunk validation, task units, review checkpoints, risk assessment, and final operations.
2. **Prepare chunk execution map**:
	1. Build an execution queue from the ordered chunks in the plan while preserving chunk dependencies.
	2. For each [chunk](orchestra.snippets/chunk.md), derive the manual user journeys, integration tests, and unit tests that act as the chunk completion quality gate.
	3. If a chunk does not have a valid quality gate, return to plan refinement rather than inventing execution scope.
3. **Establish chunk quality gates**:
	1. For the current chunk, establish the plan-defined manual and/or automated checks that prove chunk completion.
	2. Check that the quality gates fail initially, or record concrete evidence that the chunk is not yet complete when a literal failing check is unsafe, destructive, or not practical.
	3. Treat the resulting gate definition as the authoritative completion bar for the current chunk.
4. **Break the chunk into units of work**:
	1. Decompose the current chunk into individual units of work that map cleanly to the plan's tasks and changed files.
	2. Keep units small, explicit, and traceable to the chunk's expected outcome and risk profile.
	3. If validation or review finds missing work, create ad hoc units of work and incorporate them into the current chunk rather than drifting scope.
5. **Implement and review units of work**:
	1. Assign each unit of work to the specialist sub agent or sub agents best suited to implement it.
	2. After each unit is implemented, run the applicable code review sub agents.
	3. Address review feedback recursively until there is no unresolved review feedback for the unit.
	4. Do not treat a unit as complete until its required review checkpoints are satisfied.
6. **Validate and close the chunk**:
	1. Once all units of work for the current chunk are complete, run the chunk quality gates established in step 3.
	2. Have applicable sub agents independently verify that the quality gates pass.
	3. If any quality gate fails or verification raises a finding, create the minimum necessary ad hoc units of work and repeat from step 5 for the current chunk.
	4. Reconcile all relevant [risk](orchestra.snippets/risk.md) entries for the current chunk, updating mitigation status, residual risk, and evidence based on the implemented result.
	5. For touched user-facing areas, use manual browser verification to confirm the functionality behaves as expected across the affected flows.
	6. Only after these checks pass may the chunk be marked complete.
7. **Run final branch validation**:
	1. Execute the plan's `Final Operations` in order, with `Integration Testing` before `Manual Testing`.
	2. Run a final cross-change code review sweep across the completed branch and address any remaining findings.
	3. Reconcile the full plan risk assessment against the final implemented branch so the execution report reflects current residual risk rather than planned risk only.
	4. Confirm all in-scope chunks are complete and that no out-of-scope implementation drift was introduced.
8. **Write report and submit completion**:
	1. Write the execution report using `../templates/execution-report.template.md`.
	2. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)
	3. After judge submission, use the `run-tests` skill to confirm CI passes before considering the branch complete.
	4. If CI fails, create the minimum necessary ad hoc units of work, resolve the failure, refresh the execution report evidence as needed, and repeat from the relevant implementation or validation step.

# Response To User
```
Branch: <branch-name>
Plan source: <path>
Execution report: <path>
Completed chunks: <number>/<number>
Ad hoc task units created: <number>
Final status: <Go|No-Go>
```