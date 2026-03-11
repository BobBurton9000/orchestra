---
agent: orchestrator
description: Refine an implementation plan in place using explicit user feedback while preserving the template structure
name: orchestra.stage4.refine
argument-hint: "Optional user feedback to apply to the current plan"
---
# Goal
Refine the existing plan only in response to explicit user feedback, while preserving the plan's original scope and the [implementation-plan.template](orchestra.templates/implementation-plan.template.md) structure.

If no usable feedback is provided, do nothing.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Invocation Pattern
This prompt may be executed with optional free-form feedback text.

- Example structure with feedback: `<this-command> split chunk 2 into backend and frontend work`
- Example structure with no feedback: `<this-command>`

Inference rules:
1. Treat the full invocation text as requested user feedback.
2. If the invocation text is empty or does not contain usable plan feedback, do not change the plan.

# Required Outcomes
1. The existing plan was either refined in place at `.agents/orchestra/<branch-name>/plan.md` or intentionally left unchanged because no usable feedback was provided.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 4 as the current branch stage.
3. Only feedback-driven changes were applied.
4. The plan still matched the [implementation-plan.template](orchestra.templates/implementation-plan.template.md).
5. `.agents/orchestra/<branch-name>/gherkin.md` remained unchanged.

# Steps
1. Read `.agents/orchestra/<branch-name>/plan.md` as the canonical plan. If the file does not exist, return `ERROR: no plan found for branch <branch-name>`.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 4
	Prompt: orchestra.stage4.refine
	Name: Refine
	```
3. Read [implementation-plan.template](orchestra.templates/implementation-plan.template.md) and preserve its structure while editing the plan.
4. If no usable user feedback was provided, do not modify `.agents/orchestra/<branch-name>/plan.md`. Return the response contract with `Feedback applied: No`.
5. If usable user feedback was provided, apply the smallest safe refinements directly to the plan to address that feedback.
6. Preserve scope discipline. Do not add autonomous speculative redesign or nice-to-have work beyond what is required to keep the plan coherent after applying the feedback.
7. Do not modify `.agents/orchestra/<branch-name>/gherkin.md`.
8. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Plan source: .agents/orchestra/<branch-name>/plan.md
Feedback applied: <Yes|No>
Updated plan: .agents/orchestra/<branch-name>/plan.md
Final verdict: <Go|No-Go>
```