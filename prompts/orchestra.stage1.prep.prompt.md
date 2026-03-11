---
agent: orchestrator
description: Capture the uncommitted .gherkin diff into an immutable branch gherkin summary for downstream research and planning
name: orchestra.stage1.prep
---
# Goal
Inspect the current uncommitted changes under `./.gherkin` only and compile the changed Gherkin into one branch-scoped summary document at `.agents/orchestra/<branch-name>/gherkin.md`.

That summary represents the target Gherkin state for this branch. It does not need to preserve prior versions. Stage 2 may append only the `Related Gherkin` section defined by the shared template. After that, `gherkin.md` becomes immutable for later stages.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. The uncommitted diff was inspected only for files under `./.gherkin`.
2. A summary file was created at `.agents/orchestra/<branch-name>/gherkin.md` using the [branch-gherkin.template](orchestra.templates/branch-gherkin.template.md).
3. The summary compiled only the current target-state Gherkin from changed files and did not attempt to reproduce the previous file contents.
4. If files under `./.gherkin` were deleted, their paths were recorded explicitly in the summary.
5. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was created or updated to identify stage 1 as the current branch stage.
6. The summary file reserved the final `Related Gherkin` section for stage 2 enrichment.
7. The summary file was established as immutable for later stages in this flow after stage 2 enrichment completes.
8. The summary used the stable Markdown structure defined by the shared template.

# Steps
1. Inspect the current uncommitted git state limited to `./.gherkin`, including staged changes, unstaged changes, renames, deletions, and untracked files. If no relevant changes exist, return `ERROR: no uncommitted .gherkin changes found`.
2. Ensure `.agents/orchestra/<branch-name>/` exists.
3. Create or update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content:

	```md
	# Current Stage

	Stage: 1
	Prompt: orchestra.stage1.prep
	Name: Prep
	```
4. Read [branch-gherkin.template](orchestra.templates/branch-gherkin.template.md) and use it as the required structure for `.agents/orchestra/<branch-name>/gherkin.md`.
5. Create `.agents/orchestra/<branch-name>/gherkin.md` as the canonical summary of the changed Gherkin state for this branch.
6. Use the following structure derived from the template:

	````md
	# Gherkin Summary

	## Changed Files

	### <repository-relative path>
	```gherkin
	<current target-state gherkin content>
	```

	## Deleted Files
	- <repository-relative path>

	## Related Gherkin
	_None identified yet._
	````
7. For each added, modified, copied, or renamed file under `./.gherkin`, include its current repository-relative path and the current target-state Gherkin content.
8. For each deleted file under `./.gherkin`, record the deleted repository-relative path in the `Deleted Files` section.
9. Leave the `Related Gherkin` section empty except for `_None identified yet._`. Stage 1 must not populate it.
10. Do not include unchanged `.gherkin` files.
11. Do not include prior file versions, textual diffs, or unrelated repository context.
12. Mark `.agents/orchestra/<branch-name>/gherkin.md` as reserved for a stage 2 append to `Related Gherkin`, then immutable working context for later stages in this flow.
13. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Gherkin summary: .agents/orchestra/<branch-name>/gherkin.md
Changed gherkin files compiled: <number>
Deleted gherkin files noted: <number>
Final status: <Prepared|ERROR>
```