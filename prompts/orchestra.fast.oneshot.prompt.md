---
agent: orchestrator
description: Run a condensed fast flow that imports, researches, plans, refines, and executes in one pass
argument-hint: "Paste a url, attach a document to the chat or add some text"
---
# Goal
Run a condensed fast workflow for the current branch by turning the provided source into story, research, plan, refinement, and execution outputs in one pass, while keeping the workflow lightweight and evidence-driven.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Invocation Pattern
This prompt is executed with a URL, free-form requirements text argument or an attached document.

- Example structure of URL import: `<this-command> <url>`
- Example structure of free-form argument: `<this-command> <freeform requirements text>`
- Example structure of attached document: `<this-command>`

Inference rules:
1. If invocation contains an `http://` or `https://` URL, treat the first URL as the canonical source.
2. If invocation contains an attached file, treat that file as the canonical source.
3. If invocation also contains extra text, treat that text as supplemental context.
4. If nothing usable is provided, return `ERROR: no source content provided`.

# Required Outcomes
1. A local raw copy of the source was created at `.agents/orchestra/<branch-name>/story.source.md`.
2. A story was created at `.agents/orchestra/<branch-name>/story.md` using the [story.template](orchestra.templates/story.template.md).
3. Any necessary research documents were created under `.agents/orchestra/<branch-name>/research/` using the [research.template](orchestra.templates/research.template.md).
4. A plan was created and refined in place at `.agents/orchestra/<branch-name>/plan.md` using the [implementation-plan.template](orchestra.templates/implementation-plan.template.md).
5. An execution report was written at `.agents/orchestra/<branch-name>/execution-report.md` using the [execution-report.template](orchestra.templates/execution-report.template.md).
6. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to reflect the oneshot flow.
7. The resulting branch outputs were concrete enough to execute and were left in an executed, validated state for the implemented scope.

# Steps
1. Resolve the provided source content. If nothing usable is provided, return `ERROR: no source content provided`.
2. Ensure `.agents/orchestra/<branch-name>/` exists and save the canonical source to `.agents/orchestra/<branch-name>/story.source.md`.
3. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content:

	```md
	# Current Stage

	Stage: 5
	Prompt: orchestra.fast.oneshot
	Name: One Shot
	```
4. Read [story.template](orchestra.templates/story.template.md), [research.template](orchestra.templates/research.template.md), [implementation-plan.template](orchestra.templates/implementation-plan.template.md), and [execution-report.template](orchestra.templates/execution-report.template.md). Use them as the required output structures.
5. Produce the story from the source, resolving ambiguity conservatively from source and repository evidence.
6. Produce only the research documents needed to support planning and execution.
7. Produce the implementation plan, then refine it in place until it is concrete and execution-ready.
8. Execute the refined plan for the intended fast-flow scope, keep chunk and task status current in the plan, run validation and final testing, and write the execution report. Consult specialist agents when helpful.
9. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Imported source: .agents/orchestra/<branch-name>/story.source.md
Story: .agents/orchestra/<branch-name>/story.md
Research documents: <number>
Plan: .agents/orchestra/<branch-name>/plan.md
Execution report: .agents/orchestra/<branch-name>/execution-report.md
Final status: <Go|No-Go>
```