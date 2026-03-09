---
agent: orchestrator
description: Automatically resolve pull request merge conflicts against the target branch, validate the result, and push the updated source branch
argument-hint: "Optional: specify the target branch if it should not be inferred from the pull request or default branch"
---
# Goal
Automatically resolve merge conflicts on the current working branch or active pull request by reconciling the source branch with the correct target branch, validating the result, and pushing the updated branch when the conflict resolution is safe.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Invocation Pattern
This prompt may be executed with an optional target branch hint in the invocation text.

Inference rules:
1. If the invocation explicitly names a target branch, use that branch.
2. Otherwise, if an active or current pull request can be resolved, use the pull request base branch.
3. Otherwise prefer `master` if it exists locally or on the default remote.
4. If `master` does not exist, use `main` if it exists locally or on the default remote.
5. If none of those branches exist, return `ERROR: no target branch could be resolved`.

# Required Outcomes
1. The source branch and target branch are resolved explicitly before any merge or rebase operation begins.
2. The latest target branch state is fetched before conflict resolution work starts.
3. Real merge conflicts are surfaced using a non-interactive git workflow, or an existing conflicted working tree is detected and adopted safely.
4. Every resolvable conflict is addressed automatically using repository evidence and the plan or execution artifacts when available.
5. No conflict marker (`<<<<<<<`, `=======`, `>>>>>>>`) remains in the working tree after resolution.
6. No file remains in an unmerged git state before validation begins.
7. Relevant validation, code review, and judge confirmation are completed before any resolved branch is pushed.
8. If changes were required, a non-empty conflict-resolution commit is created and pushed on the source branch.
9. No unrelated local changes are mixed into the conflict-resolution commit.
10. If a conflict cannot be resolved safely, the response returns a concrete blocker rather than leaving the branch half-resolved.

# Resolution Rules
1. Prefer merging the target branch into the source branch to surface conflicts unless repository evidence clearly requires a rebase-based update flow.
2. Preserve target-branch changes by default unless the source branch intentionally supersedes them and that intent is supported by story, plan, execution, review, or repository evidence.
3. Resolve generated files, lock files, and derived artifacts by rerunning their canonical generator or package manager when possible rather than hand-editing the merged output.
4. Delegate conflicted files to the narrowest specialist sub agents that match the affected code.
5. If a conflict reveals a deeper correctness issue rather than a straightforward textual conflict, treat it as implementation work and loop through implementation, review, and validation before finishing.
6. Never force-push or discard user work unless the repository workflow explicitly requires it and the action is justified by repository evidence.

# Steps
1. **Load branch and pull request context**:
	1. Resolve the current source branch and determine whether an active or current pull request exists for `<branch-name>`.
	2. Resolve the target branch using the `Invocation Pattern` rules.
	3. Read `.agents/orchestra/<branch-name>/story.md`, `.agents/orchestra/<branch-name>/plan.md`, and `.agents/orchestra/<branch-name>/execution-report.md` when present so conflict decisions are grounded in the intended branch behaviour.
2. **Check repository safety before merging**:
	1. Inspect the working tree for unrelated unstaged or uncommitted local changes.
	2. If unrelated local changes cannot be separated safely from the conflict-resolution work, return `ERROR: working tree is not safe for automatic conflict resolution`.
	3. Fetch the latest target branch state from the default remote before attempting resolution.
3. **Surface the conflicts**:
	1. If the repository is already in a merge or rebase conflict state, inventory the unmerged files and adopt that state as the starting point.
	2. Otherwise, use a non-interactive git operation to bring the target branch into the source branch and intentionally surface real conflicts.
	3. If the source branch is already up to date and no conflicts exist, return the response contract with `Final status: No conflicts`.
4. **Resolve conflicted files automatically**:
	1. Enumerate conflicted files and group them into the smallest safe resolution units.
	2. Delegate each unit to the appropriate specialist sub agents with explicit instructions to reconcile both sides of the conflict, preserve intended source-branch behaviour, and incorporate required target-branch updates.
	3. For each resolved unit, run the relevant code review and validation sub agents before advancing.
	4. If a conflicted file is generated or derived, regenerate it using the authoritative toolchain when possible and verify the result.
	5. Repeat until every unmerged file is either resolved with evidence or reported as concretely blocked.
5. **Validate the resolved branch**:
	1. Confirm there are no unmerged paths and no remaining conflict markers anywhere in the repository.
	2. Run targeted automated validation for the touched areas and use the `run-tests` skill for the repository-level checks required by the branch workflow.
	3. For touched user-facing flows, perform manual browser verification when the resolved files affect runtime behaviour that should be checked visually or interactively.
	4. Re-run the applicable code review sub agents on the resolved diff.
6. **Judge the resolution before publication**:
	1. Submit the resolved conflict set to the judge sub agent using [submit-to-judge](orchestra.snippets/submit-to-judge.md).
	2. Ask the judge to determine whether the conflict resolution preserves the intended branch behaviour, correctly incorporates required target-branch changes, and is established by the available evidence.
	3. If the judge does not establish that the conflicts were resolved correctly, return to step 4 and continue until the result is established or concretely blocked.
7. **Commit and push the resolution**:
	1. Stage only the files required for conflict resolution and any validation-generated updates that are required to keep the branch consistent.
	2. Create a non-empty commit using a non-interactive git command.
	3. Push the updated source branch without rewriting history unless repository evidence clearly requires a rebase workflow.
	4. Capture the commit SHA and pull request URL when available.
8. **Finalize response**:
	1. Report the source branch, target branch, number of conflicted files resolved, number blocked, commit SHA, and pull request URL when available.
	2. Return only the response contract from this prompt.

# Response To User
```
Branch: <branch-name>
Target branch: <target-branch>
Pull request: <url|None>
Resolved files: <number>
Blocked files: <number>
Commit: <sha|None>
Final status: <Resolved|No conflicts|Blocked|ERROR>
```