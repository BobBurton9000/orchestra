---
agent: orchestrator
description: Produce an implementation plan from a story and research documents
---
# Goal
Convert a finalised story into an implementation plan by coordinating and consulting specialist agents until the plan is concrete, coherent and execution-ready.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. One implementation plan file was produced at `.agents/orchestra/<branch-name>/plan.md` using the [implementation-plan.template](orchestra.templates/implementation-plan.template.md).
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 3 as the current branch stage.
3. At least 1 architecture diagram was included.
4. Skeletons were provided for all added or changed modules.
5. A concrete [risk](orchestra.snippets/risk.md) assessment grounded in the story, repository evidence and implementation approach was included.
6. The risk assessment was validated by all applicable sub agents consulted during planning.
7. The implementation was broken into explicit [chunks](orchestra.snippets/chunk.md).
8. A comprehensive ordered task list with explicit files and measurable outcomes, grouped under the relevant chunk, was produced.
9. Every implementation task contained explicit code review checkpoints aligned to its technical risk.
10. The `Final Operations` section ended in template order with `Integration Testing` then `Manual Testing`.
11. All plan ambiguities were resolved into explicit decisions before finalising.
12. `Open Questions` was `None` unless blocked by a required external fact.

# Steps
1. **Load and normalise story context**: Read `.agents/orchestra/<branch-name>/story.md` as the canonical source. If the file does not exist, return `ERROR: no story found for branch <branch-name>`. If research documents exist in `.agents/orchestra/<branch-name>/research/`, load them as supplemental context. Extract the goal, scope, acceptance criteria, constraints, decisions and risks.
2. **Update current stage marker**: Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 3
	Prompt: orchestra.stage3.plan
	Name: Plan
	```
3. **Load the template**: Read [implementation-plan.template](orchestra.templates/implementation-plan.template.md) to determine what information is required and the exact section order to follow.
4. **Specialist sub agent planning pass**:
	1. Choose all sub agents applicable to the story and ensure the combined pass covers:
		1. Affected modules, files and relevant repository patterns
		2. Architecture flow, boundaries, integration points and migration concerns
		3. Concrete implementation chunks, their sequencing and the measurable validation surface for each chunk
		4. Concrete [risk](orchestra.snippets/risk.md) identification, safeguards and residual concerns across the relevant delivery surfaces
		5. Code review expectations for correctness, simplicity, reuse, abstraction opportunity, naming, readability and design integrity where relevant
		6. Integration and manual testing derived from the acceptance criteria
		7. Auth, validation, data and abuse-case safeguards when relevant
		8. Challenge on sequencing, dependencies and task actionability
5. **Merge draft plan**:
	1. Merge specialist outputs into one draft aligned to the template.
	2. Ensure the draft contains a [risk](orchestra.snippets/risk.md) assessment with concrete risks, likely impact, expected safeguards, and the applicable sub agents that validated each entry.
	3. Ensure the risk assessment is aligned with the chunking, architecture, testing plan and review checkpoints.
	4. Ensure the plan is decomposed into chunks where each chunk represents a measurable increment of delivery.
	5. Ensure each chunk defines the manual user journeys, integration tests, and where appropriate for sufficiently small chunks, unit tests that prove the chunk is complete.
	6. Ensure each task contains status, intent, atomic steps, files, expected outcome and review checkpoints.
	7. Ensure every task belongs to exactly one chunk.
	8. Ensure module skeletons align with existing repository patterns.
	9. Treat the newly merged draft as the only authoritative plan candidate for subsequent passes.
6. **Recursive refinement loop**:
	1. Return to step 4 (Specialist sub agent planning pass) when any of the following exists:
		- Missing risk assessment or risk entries that are vague, generic or not validated by the applicable sub agents
		- Missing chunk boundaries or unclear chunk purpose
		- A chunk cannot be validated through manual user journeys, integration tests, or, where appropriate for sufficiently small chunks, unit tests
		- Vague or non-testable acceptance mapping
		- Missing file references
		- Missing dependency sequencing
		- Architecture and task mismatch
		- Missing or vague review checkpoints for implementation tasks
		- Incomplete testing strategy
		- Unresolved contradiction between sub agent findings
	2. The maximum number of times you can (and must, if required) loop is specified in [loop-count](orchestra.config/loop-count.md).
	3. If still incomplete after the maximum loop count has been exhausted, refer to [orchestrator-decision-policy](orchestra.snippets/orchestrator-decision-policy.md) and encode conservative minimal-risk decisions explicitly in the plan.
7. **Final quality and template compliance pass**:
	1. Verify the exact section order from [implementation-plan.template](orchestra.templates/implementation-plan.template.md).
	2. Remove generic research tasks and speculative placeholders.
	3. Ensure the risk assessment is concrete, implementation-relevant and validated by all applicable sub agents consulted.
	4. Ensure chunk ordering is dependency-aware and that each chunk is independently measurable.
	5. Ensure review checkpoints are concrete and proportionate to the risk of each task.
	6. Ensure the testing plan maps to the story acceptance criteria.
	7. Ensure `Open Questions` is `None` unless truly blocked by a missing external fact.
8. **Submit completion to judge sub agent**: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Story source: <path>
Generated plan: <path>
Task count: <number>
Open questions: <None|count>
```
