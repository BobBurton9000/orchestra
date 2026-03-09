---
agent: orchestrator
description: Refine an implementation plan in place until no critical or high issues remain
---
# Goal
Recursively coordinate specialist agents to audit and refine an implementation plan until it is shippable with no Critical or High issues.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. The existing plan was refined in place at `.agents/orchestra/<branch-name>/plan.md`.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 4 as the current branch stage.
3. All Critical and High plan issues that affected delivery or release safety were identified.
4. Retained issues were resolved by refining the plan directly rather than deferring or hand-waving them away.
5. Valid [chunk](orchestra.snippets/chunk.md) structure, boundaries and sequencing were preserved throughout refinement.
6. Every [chunk](orchestra.snippets/chunk.md) remained independently measurable through manual user journeys, integration tests, or for sufficiently small chunks, unit tests.
7. A concrete [risk](orchestra.snippets/risk.md) assessment that remained aligned with the implementation plan and validated by the applicable sub agents was preserved.
8. The plan retained explicit code review checkpoints strong enough to enforce technical excellence during execution.
9. Review and refinement cycles were repeated until there were zero Critical issues and zero High issues.
10. Template consistency with the [implementation-plan.template](orchestra.templates/implementation-plan.template.md) was preserved.
11. A final shipping verdict was produced.

# Severity Rules
- `Critical`: must be fixed before implementation starts.
- `High`: must be fixed before release.
- Ignore `Medium` and `Low` unless there is clear evidence they escalate to `High` or `Critical` before release.

# Audit Response Required
When delegating an audit to a specialist sub agent, include the `Severity Rules` from this prompt in the delegated instructions and require the sub agent to classify every finding using exactly one of: `Critical`, `High`, `Medium`, `Low`.

Require each sub agent response to return findings in this structure:
```md
- Severity: <Critical|High|Medium|Low>
	Issue: <problem>
	Risk: <delivery or release impact>
	Minimal Fix: <smallest safe refinement>
```

If a sub agent does not provide severity or uses a different scale, treat that response as incomplete and re-prompt the sub agent with the required format.

# Steps
1. **Load baseline plan**: Read `.agents/orchestra/<branch-name>/plan.md` as the canonical plan. If the file does not exist, return `ERROR: no plan found for branch <branch-name>`. Preserve the original intent, scope and constraints.
2. **Update current stage marker**: Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 4
	Prompt: orchestra.slow.stage4.refine
	Name: Refine
	```
3. **Load the template**: Read [implementation-plan.template](orchestra.templates/implementation-plan.template.md) to preserve section order and template consistency while refining the plan.
4. **Run specialist sub agent audit pass**:
	1. Choose all sub agents applicable to the plan and ensure the combined audit covers:
		1. Structural and actionability gaps in chunks, tasks and sequencing
		2. Architecture coherence, integration safety and dependency ordering
		3. Chunk boundary quality, dependency ordering and whether each chunk remains a coherent measurable increment
		4. Risk assessment quality, completeness, mitigation strength and whether risk entries are still validated by the applicable sub agents
		5. Technical excellence coverage across correctness, simplicity, reuse, abstraction opportunity, naming, readability and design integrity
		6. Test strategy coverage against acceptance criteria, chunk validation, and release confidence
		7. Auth, validation, data and abuse-case controls when relevant
		8. Scope discipline and the fastest path to a shippable outcome
	2. Provide each sub agent with the `Severity Rules` and the `Audit Response Required` from this prompt.
	3. Require each sub agent to classify findings against release risk, not stylistic preference.
5. **Merge findings with severity**:
	1. Keep only `Critical` and `High` findings.
	2. For each retained finding, capture the issue, risk and minimal fix.
	3. Treat missing, weak or non-actionable review checkpoints as valid findings when they would allow technically poor code to pass through execution unchecked.
	4. Treat broken chunk boundaries, missing chunk validation, or tasks that do not belong to a coherent measurable chunk as valid findings when they weaken delivery confidence or release safety.
	5. Treat missing, generic, stale, or unvalidated risk assessment entries as valid findings when they weaken implementation safety, delivery confidence or release readiness.
	6. Reclassify findings using the `Severity Rules` when a sub agent's rationale is sound but the chosen severity does not match this prompt's thresholds.
6. **Apply minimal fixes to the plan**:
	1. Update the plan directly to resolve retained findings.
	2. Prefer the smallest safe changes that preserve delivery speed.
	3. Preserve chunk intent and split or re-scope chunks when measurability or boundary clarity is weak.
	4. Refresh risk entries, mitigations and validating sub agents whenever the plan changes invalidate or weaken the existing risk assessment.
	5. Strengthen or add task-level review checkpoints whenever the audit shows technical excellence would otherwise be under-enforced.
	6. After each refinement write, reload the canonical plan and treat it as the only authoritative plan for subsequent passes.
7. **Recursive refinement loop**:
	1. Return to step 4 (Run specialist sub agent audit pass) after each refinement.
	2. Require each new round of findings to be rebuilt from the reloaded canonical plan.
	3. Continue until all sub agents converge on zero `Critical` and zero `High` issues.
	4. The maximum number of times you can (and must, if required) loop is specified in [loop-count](orchestra.config/loop-count.md).
	5. If convergence is not reached after the maximum loop count has been exhausted, refer to [orchestrator-decision-policy](orchestra.snippets/orchestrator-decision-policy.md) and apply conservative minimal-risk refinements before auditing once more.
8. **Final quality pass**:
	1. Ensure every chunk still satisfies the [chunk](orchestra.snippets/chunk.md) definition.
	2. Ensure every chunk is independently measurable and has valid manual, integration, or appropriately scoped unit-test validation.
	3. Ensure the [risk](orchestra.snippets/risk.md) assessment remains concrete, implementation-relevant and validated by the applicable sub agents.
	4. Ensure every implementation task still includes review checkpoints appropriate to its technical risk.
	5. Ensure chunk and task sequencing remains executable end-to-end.
	6. Ensure testing sections still support release confidence.
	7. Ensure no speculative redesign or nice-to-have scope was introduced.
9. **Submit completion to judge sub agent**: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Plan source: <path>
Updated plan: <path>
Refinement rounds: <number>
Final verdict: <Go|No-Go>
Critical issues: 0
High issues: 0
```