---
agent: orchestrator
description: Produce repository-grounded research documents with a lightweight stage 2 flow
---
# Goal
Create only the research documents needed to support the current story, grounded in real repository evidence and organized for downstream planning.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. One or more research documents were produced at `.agents/orchestra/<branch-name>/research/<topic-name>.md` using the [research.template](orchestra.templates/research.template.md).
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 2 as the current branch stage.
3. All claims were grounded in real files, symbols, and tests.
4. Only useful research topics directly relevant to the story were included.
5. No implementation task lists or status tracking were included.

# Steps
1. Read `.agents/orchestra/<branch-name>/story.md` as the canonical source. If the file does not exist, return `ERROR: no story found for branch <branch-name>`.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 2
	Prompt: orchestra.fast.stage2.research
	Name: Research
	```
3. Read [research.template](orchestra.templates/research.template.md) and use it as the required structure for each research document.
4. Research the repository for adjacent features, patterns, boundaries, integration points, and tests that matter to the story. Consult specialist agents when helpful.
5. Split findings into distinct topics only where that improves clarity. Prefer a small set of focused research documents over exhaustive writeups.
6. Write the research documents under `.agents/orchestra/<branch-name>/research/`, grounded in repository evidence.
7. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Story source: <path>
Topic research documents created: <number>
Topic document paths: <comma-separated paths>
```