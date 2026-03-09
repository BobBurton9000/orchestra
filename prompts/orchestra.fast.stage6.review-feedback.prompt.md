---
agent: orchestrator
description: Address qualifying pull request review feedback with a lightweight stage 6 flow
---
# Goal
Resolve unresolved pull request review feedback that should block merge, make only the necessary fixes, and reply on GitHub as Orchestra.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. The active or current pull request for `<branch-name>` was identified, or a concrete error was returned.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 6 as the current branch stage.
3. Unresolved reviewer comments were retrieved and only qualifying comments were acted on.
4. Addressed qualifying comments were fixed, validated, and replied to as `Orchestra`.
5. Any required code changes were committed and pushed.
6. Unfixable qualifying comments were reported as blocked with a concrete reason.

# Steps
1. Resolve the active or current pull request for `<branch-name>` and gather relevant branch context.
2. Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

	```md
	# Current Stage

	Stage: 6
	Prompt: orchestra.fast.stage6.review-feedback
	Name: Review Feedback
	```
3. Retrieve unresolved reviewer comments using GitHub tooling.
4. Focus only on comments that are serious enough to require action before merge. Consult specialist agents when helpful.
5. Implement the smallest safe fixes, validate them, and confirm they are ready before publishing.
6. Commit and push only the required changes.
7. Reply to each addressed or blocked qualifying comment as `Orchestra`, using [reviewer-comment-reply.template](orchestra.templates/reviewer-comment-reply.template.md) for structure.

# Response To User
```
Branch: <branch-name>
Pull request: <url>
Addressed comments: <number>
Blocked comments: <number>
Commit: <sha|None>
Final status: <Updated|No qualifying comments|Blocked|ERROR>
```