---
agent: orchestrator
description: Create a single implementation plan to achieve the target state described by gherkin.md
name: orchestra.stage3.plan
---
# Goal
Create one implementation plan for the current branch using the implementation plan template and the target state captured in `.agents/orchestra/<branch-name>/gherkin.md`, plus any supporting research context.

Keep the prompt lightweight, let the orchestrator determine the necessary planning depth, and do not modify `gherkin.md`.

`gherkin.md` is the only canonical source for this flow and must not be replaced with `story.md`.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. One implementation plan file was produced at `.agents/orchestra/<branch-name>/plan.md` using the [implementation-plan.template](orchestra.templates/implementation-plan.template.md).
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 3 as the current branch stage.
3. The plan followed the template order and was concrete enough to execute.
4. The plan used `.agents/orchestra/<branch-name>/gherkin.md` as the canonical source context in place of a story document.
5. `.agents/orchestra/<branch-name>/gherkin.md` remained unchanged.
6. `Open Questions` was `None` unless blocked by a required external fact.

# Steps
1. Read `.agents/orchestra/<branch-name>/gherkin.md` as the canonical source. If the file does not exist, return `ERROR: no gherkin summary found for branch <branch-name>`. Do not fall back to `.agents/orchestra/<branch-name>/story.md`. If research documents exist in `.agents/orchestra/<branch-name>/research/`, use them as supporting context.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 3
	Prompt: orchestra.stage3.plan
	Name: Plan
	```
3. Read [implementation-plan.template](orchestra.templates/implementation-plan.template.md) and use it as the required structure for the plan.
4. Produce a single execution-ready implementation plan at `.agents/orchestra/<branch-name>/plan.md`.
5. In the plan's `Source Context`, use the change intent from `gherkin.md` in place of a story document while preserving the template structure.
6. Make concrete decisions, break the work into clear chunks and tasks, include file targets, validation, risks, and final testing, and consult specialist agents when helpful.
7. Resolve ambiguities conservatively from repository evidence and available context. Only leave an item in `Open Questions` when an external fact is required.
8. Do not modify `.agents/orchestra/<branch-name>/gherkin.md`.
9. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Gherkin source: .agents/orchestra/<branch-name>/gherkin.md
Generated plan: .agents/orchestra/<branch-name>/plan.md
Open questions: <None|count>
```