---
agent: orchestrator
description: Refine an implementation plan in place with a lightweight stage 4 flow
---
# Goal
Refine the existing plan until it is concrete, executable, and free of important delivery or release issues, while preserving the plan's original scope.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. The existing plan was refined in place at `.agents/orchestra/<branch-name>/plan.md`.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 4 as the current branch stage.
3. Important plan issues were identified and resolved directly in the plan.
4. Chunk structure, validation, risk assessment, and review checkpoints remained concrete and executable.
5. The plan still matched the [implementation-plan.template](orchestra.templates/implementation-plan.template.md).

# Steps
1. Read `.agents/orchestra/<branch-name>/plan.md` as the canonical plan. If the file does not exist, return `ERROR: no plan found for branch <branch-name>`.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 4
	Prompt: orchestra.fast.stage4.refine
	Name: Refine
	```
3. Read [implementation-plan.template](orchestra.templates/implementation-plan.template.md) and preserve its structure while refining the plan.
4. Audit the plan for concrete delivery, release, sequencing, validation, risk, and review-checkpoint issues. Consult specialist agents when helpful.
5. Apply the smallest safe refinements directly to the plan until it is execution-ready.
6. Preserve scope discipline. Do not add speculative redesign or nice-to-have work.
7. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Plan source: <path>
Updated plan: <path>
Final verdict: <Go|No-Go>
```