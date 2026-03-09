---
agent: orchestrator
description: Create a single implementation plan for the developer's request
---
# Goal
Create one implementation plan for the current branch using the implementation plan template and any available story or research context. Keep the prompt lightweight and let the orchestrator determine the necessary planning depth.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. One implementation plan file was produced at `.agents/orchestra/<branch-name>/plan.md` using the [implementation-plan.template](orchestra.templates/implementation-plan.template.md).
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 3 as the current branch stage.
3. The plan followed the template order and was concrete enough to execute.
4. `Open Questions` was `None` unless blocked by a required external fact.

# Steps
1. Read `.agents/orchestra/<branch-name>/story.md` as the canonical source. If the file does not exist, return `ERROR: no story found for branch <branch-name>`. If research documents exist in `.agents/orchestra/<branch-name>/research/`, use them as supporting context.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 3
	Prompt: orchestra.fast.stage3.plan
	Name: Plan
	```
3. Read [implementation-plan.template](orchestra.templates/implementation-plan.template.md) and use it as the required structure for the plan.
4. Produce a single execution-ready implementation plan at `.agents/orchestra/<branch-name>/plan.md`. Make concrete decisions, break the work into clear chunks and tasks, include file targets, validation, risks, and final testing, and consult specialist agents when helpful.
5. Resolve ambiguities conservatively from repository evidence and available context. Only leave an item in `Open Questions` when an external fact is required.
6. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Story source: <path>
Generated plan: <path>
Open questions: <None|count>
```