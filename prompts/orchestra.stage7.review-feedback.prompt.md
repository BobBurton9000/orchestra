---
agent: orchestrator
description: Retrieve unresolved GitHub reviewer comments, address critical or high feedback, and reply as Orchestra after committing and pushing fixes
---
# Goal
Use GitHub MCP tooling to retrieve unresolved pull request reviewer comments, address critical or high feedback that should be fixed before merge, commit and push the resulting changes, and reply to the addressed comments as Orchestra so the automation is clearly differentiated from the user.

# Variables
`<branch-name>` = [branch-name](wiki/branch-name.md)

# Required Outcomes
1. The active or current pull request for `<branch-name>` is identified, or a concrete error is returned if no pull request can be resolved.
2. Unresolved reviewer comments are retrieved using GitHub MCP tooling.
3. Every unresolved reviewer comment classified as `Critical` or `High` is either addressed with changes or explicitly reported as blocked with a concrete reason.
4. The judge sub agent confirms that addressed `Critical` or `High` reviewer comments have been correctly addressed before any commit is pushed.
5. No addressed `Critical` or `High` reviewer comment is left without a GitHub reply describing the changes made.
6. Any code changes made to address reviewer feedback are committed and pushed on the source branch.
7. Reviewer comment replies clearly identify the responder as `Orchestra`.
8. Reviewer comment replies are written using `../templates/reviewer-comment-reply.template.md`.
9. No unrelated or lower-severity review feedback is fixed unless it is required to safely address the targeted comments.

# Severity Rules
- `Critical`: must be fixed before merge because the comment identifies a release blocker, serious security issue, data integrity risk, or fundamentally incorrect behaviour.
- `High`: must be fixed before merge because the comment identifies a significant correctness, reliability, safety, or integration problem.
- `Major`: treat as synonymous with `High` for this prompt.
- Ignore `Medium`, `Low`, `Minor`, `Nit`, or stylistic-only feedback unless directly required to safely implement a `Critical` or `High` fix.

# Comment Classification Rules
1. Prefer the reviewer's explicit severity words when present.
2. Treat `blocker` as `Critical`.
3. Treat `major` as `High`.
4. If severity is not explicit, use the applicable sub agents to infer severity from merge and release risk.
5. If severity still cannot be established, do not assume it is in scope for this stage.

# Steps
1. **Load PR and change context**: Resolve the active or current pull request for `<branch-name>` using GitHub MCP tooling. Read `ai/orchestra/documents/<branch-name>/story.md`, `ai/orchestra/documents/<branch-name>/plan.md`, and `ai/orchestra/documents/<branch-name>/execution-report.md` when present to ground the response context.
2. **Retrieve unresolved reviewer comments**:
	1. Use GitHub MCP tooling to retrieve unresolved review comments or unresolved review threads for the pull request.
	2. Normalize each comment into: comment identifier, file or diff location, author, unresolved status, comment text, and explicit severity if present.
	3. Filter to unresolved comments only.
3. **Classify review comments**:
	1. Apply the `Comment Classification Rules` and `Severity Rules`.
	2. Build the in-scope set from unresolved `Critical` and `High` comments only.
	3. If no unresolved `Critical` or `High` comments remain, return the response contract with a no-op status and do not create a new commit.
4. **Plan and implement fixes**:
	1. Group related in-scope comments into the smallest safe implementation units.
	2. Delegate implementation to the appropriate specialist sub agents.
	3. Run the relevant code review and validation sub agents for each fix unit.
	4. Repeat until each in-scope comment is either addressed with evidence or determined to be concretely blocked.
5. **Judge addressed feedback before publication**:
	1. Before creating any commit, submit the addressed in-scope comments to the judge sub agent using [submit-to-judge](wiki/submit-to-judge.md).
	2. Ask the judge to determine whether the targeted `Critical` and `High` comments were correctly addressed based on the implemented changes and validation evidence.
	3. If the judge does not establish that the feedback was correctly addressed, return to step 4 and continue fixing before attempting to commit.
6. **Commit and push changes**:
	1. Stage only the files required to address the in-scope reviewer feedback.
	2. Create a non-empty commit using a non-interactive git command.
	3. Push the updated source branch.
	4. Capture the commit SHA for use in reviewer replies.
7. **Reply to reviewer comments as Orchestra**:
	1. For each addressed comment, post a GitHub reply using GitHub MCP tooling.
	2. Use `../templates/reviewer-comment-reply.template.md` as the reply structure.
	3. Start each reply with `Orchestra:`.
	4. Summarize the change made, include a markdown link to the relevant file or diff when useful, and include the commit SHA when useful.
	5. For blocked comments, reply as `Orchestra:` with the concrete blocker instead of pretending the issue was fixed.
	6. If the repository tooling supports resolving review threads safely, resolve the thread only after the reply is posted and the fix is verified.
	7. Ensure the reply clearly differentiates Orchestra's action from any user-authored comments.
8. **Finalize response**:
	1. Report the pull request URL, number of in-scope comments addressed, number blocked, and commit SHA if changes were made.
	2. Return only the response contract from this prompt.

# Response To User
```
Branch: <branch-name>
Pull request: <url>
Addressed comments: <number>
Blocked comments: <number>
Commit: <sha|None>
Final status: <Updated|No qualifying comments|Blocked|ERROR>
```