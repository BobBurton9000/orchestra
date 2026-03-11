---
agent: orchestrator
description: Produce repository-grounded research needed to achieve the target state described by gherkin.md
name: orchestra.stage2.research
---
# Goal
Create only the research documents needed to implement the target state described by `.agents/orchestra/<branch-name>/gherkin.md`, grounded in real repository evidence and organized for downstream planning.

`gherkin.md` is the canonical source for this flow, must not be replaced with `story.md`, and may only be modified in stage 2 to append the final `Related Gherkin` section defined by the shared template.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. One or more research documents were produced at `.agents/orchestra/<branch-name>/research/<topic-name>.md` using the [research.template](orchestra.templates/research.template.md).
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 2 as the current branch stage.
3. All claims were grounded in real files, symbols, and tests.
4. Only useful research topics directly relevant to achieving the target Gherkin state were included.
5. `.agents/orchestra/<branch-name>/gherkin.md` was updated only by appending or replacing the final `Related Gherkin` section using the [branch-gherkin.template](orchestra.templates/branch-gherkin.template.md).
6. The `Related Gherkin` section included only existing Gherkin statements from the project-root `.gherkin/` tree that share a product boundary, dependency, workflow, or regression surface with the changed work and should be considered for re-testing.
7. No implementation task lists or status tracking were included.

# Steps
1. Read `.agents/orchestra/<branch-name>/gherkin.md` as the canonical source. If the file does not exist, return `ERROR: no gherkin summary found for branch <branch-name>`. Do not fall back to `.agents/orchestra/<branch-name>/story.md`.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 2
	Prompt: orchestra.stage2.research
	Name: Research
	```
3. Read [branch-gherkin.template](orchestra.templates/branch-gherkin.template.md) and preserve its structure when enriching `.agents/orchestra/<branch-name>/gherkin.md`.
4. Read [research.template](orchestra.templates/research.template.md) and use it as the required structure for each research document.
5. Research the repository for adjacent features, patterns, boundaries, integration points, and tests that matter to achieving the target state described by `gherkin.md`. Consult specialist agents when helpful.
6. Search the project-root `.gherkin/` tree for existing Gherkin that is related to the target work in `.agents/orchestra/<branch-name>/gherkin.md`. Treat a scenario as related only when it shares a product boundary, dependency, workflow, or regression surface with the changed work. Include unchanged files and unchanged scenarios from changed files only when they meet that bar.
7. Append or replace the final `## Related Gherkin` section in `.agents/orchestra/<branch-name>/gherkin.md` so it stays at the end of the file and contains only those related existing Gherkin statements, grouped by repository-relative path. Use this structure:

	````md
	## Related Gherkin

	### <repository-relative path>
	```gherkin
	<existing related gherkin statements to re-test>
	```
	````
8. Do not duplicate target-state content already captured under `Changed Files` unless unchanged statements from the same file are also related and need to be re-tested.
9. Exclude scenarios that are merely adjacent by naming, folder proximity, or broad feature area if they do not create a realistic regression or integration risk for the changed work.
10. Split findings into distinct topics only where that improves clarity. Prefer a small set of focused research documents over exhaustive writeups.
11. Write the research documents under `.agents/orchestra/<branch-name>/research/`, grounded in repository evidence.
12. Do not modify any other section of `.agents/orchestra/<branch-name>/gherkin.md`.
13. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Gherkin source: .agents/orchestra/<branch-name>/gherkin.md
Related Gherkin entries added: <number>
Topic research documents created: <number>
Topic document paths: <comma-separated paths>
```