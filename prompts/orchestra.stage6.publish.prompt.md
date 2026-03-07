---
agent: orchestrator
description: Commit the completed branch changes and open a GitHub pull request against an inferred target branch
argument-hint: "Optional: specify the target branch if it should not default to master or main"
---
# Goal
Commit the completed branch changes and open a GitHub pull request using the execution artifacts as source evidence, targeting an explicit branch inferred from the prompt when provided, otherwise `master`, or if that does not exist, `main`.

# Variables
`<branch-name>` = [branch-name](wiki/branch-name.md)

# Invocation Pattern
This prompt may be executed with an optional target branch hint in the invocation text.

Inference rules:
1. If the invocation explicitly names a target branch, use that branch.
2. Otherwise prefer `master` if it exists locally or on the default remote.
3. If `master` does not exist, use `main` if it exists locally or on the default remote.
4. If none of those branches exist, return `ERROR: no target branch could be resolved`.

# Required Outcomes
1. A non-empty commit is created on the current working branch for the intended publication changes.
2. The commit only contains the completed in-scope work and supporting documents needed for publication.
3. A GitHub pull request is opened from the current branch to the resolved target branch.
4. The pull request title and body are grounded in the story, plan and execution report rather than ad hoc summary text.
5. The pull request body is written using `../templates/pull-request.template.md`.
6. The target branch is resolved from the prompt when specified, otherwise `master`, otherwise `main`.
7. If commit or PR publication is blocked, the response returns a concrete error rather than silently skipping the step.

# Steps
1. **Load publication context**: Read `ai/orchestra/documents/<branch-name>/story.md`, `ai/orchestra/documents/<branch-name>/plan.md`, and `ai/orchestra/documents/<branch-name>/execution-report.md` as the canonical publication sources. If any required file does not exist, return `ERROR: missing publication source for branch <branch-name>`. Read `../templates/pull-request.template.md` to determine the PR body structure.
2. **Resolve target branch**:
	1. Determine whether the invocation text specifies a target branch.
	2. If it does, use that branch.
	3. Otherwise resolve `master` if it exists locally or on the default remote.
	4. If `master` does not exist, resolve `main` if it exists locally or on the default remote.
	5. If the resolved target branch is the same as the current branch, return `ERROR: source and target branches are the same`.
3. **Prepare commit scope**:
	1. Inspect the working tree and identify the files that belong to the completed in-scope work.
	2. Refuse to publish if there are no relevant changes to commit.
	3. Refuse to publish if unrelated changes cannot be separated safely from the intended publication scope.
	4. Derive a commit message grounded in the completed work and repository conventions.
4. **Create commit**:
	1. Stage the intended publication files.
	2. Create a non-empty commit on the current branch using a non-interactive git command.
	3. Capture the resulting commit SHA as publication evidence.
5. **Prepare pull request content**:
	1. Derive the PR title from the story title, execution result, or branch purpose.
	2. Populate the PR body using `../templates/pull-request.template.md`.
	3. Ground the PR body in real evidence from the story, plan, execution report, validation evidence, and residual risk reconciliation.
6. **Open the pull request**:
	1. Prefer GitHub MCP or GitHub API tooling when available to create the pull request.
	2. If GitHub MCP or API tooling is unavailable, use another non-interactive repository-supported publication method.
	3. Capture the pull request number and URL as publication evidence.
7. **Finalize publication response**:
	1. Confirm the commit SHA, source branch, resolved target branch, and pull request URL.
	2. Return only the response contract from this prompt.

# Response To User
```
Branch: <branch-name>
Target branch: <target-branch>
Commit: <sha>
Pull request: <url>
Final status: <Published|ERROR>
```