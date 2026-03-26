---
agent: orchestrator
name: orchestra.stage6.review
description: Repeatedly inspect the current pull request, wait for pending checks, resolve reviewer feedback, respond to comments, and continue until the pull request is approved or a real blocker prevents progress
argument-hint: "optional: focus on a reviewer, file, or feedback category"
---

# Goal
Drive the current pull request to approval by repeatedly checking status, resolving feedback, validating the branch, pushing updates, and responding to reviewers until the pull request is confirmed as approved or a real external blocker prevents progress.

# Agent Use Policy
During this stage, Orchestra may use all agents.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `{{ review-focus }}`: Optional invocation hint restricting attention to a reviewer, file, or category without ignoring blocking or major feedback.

# Required Outcomes
1. Orchestra follows Procedure A and Procedure B exactly as the operating loop.
2. If merge checks are pending, Orchestra waits 60 seconds and re-runs Procedure A.
3. If there are new unresolved comments that have not been responded to, Orchestra proceeds to Procedure B.
4. If an approver has approved the pull request and there are no blocking requested changes, the prompt completes successfully.
5. Feedback is actioned when it is within scope regardless of priority.
6. Feedback is actioned when it is major priority or higher regardless of scope.
7. After actioning a comment, respond to it if it has not already been responded to.
8. The loop continues until the pull request is approved or a real blocker outside Orchestra control is encountered.

# Procedure A: Check The Status Of The Pull Request
1. Resolve the current pull request using the active pull request tool first, with fallback to the currently open pull request tool.
2. Retrieve current review comments, review submissions, actionable discussion comments, and status checks.
3. Classify the current state:
   - `Checks pending`
   - `Feedback requires action`
   - `Approved`
   - `Blocked`
4. If merge checks are pending, wait 60 seconds using the terminal and then restart Procedure A.
5. If there are new unresolved comments that have not been responded to, continue to Procedure B.
6. If an approver has approved the pull request and there are no unresolved blocking requested changes, exit successfully.
7. If the pull request cannot progress due to a real external blocker, return `Blocked` with evidence.

# Procedure B: Resolve Feedback
1. Build the actionable feedback backlog from review comments, review submissions, and actionable general discussion comments.
2. Apply `{{ review-focus }}` when provided, but do not skip in-scope items or major-priority items.
3. Route the backlog through `scope-guard`.
4. For each item:
   - Action it if it is within scope regardless of priority.
   - Action it if it is major priority or higher regardless of scope.
   - Do not silently ignore lower-priority out-of-scope feedback; capture it as explicit follow-up.
5. Delegate each actionable item to the narrowest appropriate specialist agents.
6. After each meaningful change:
   - Re-run targeted validation.
   - Re-run relevant `code-review.*` agents when appropriate.
7. Commit and push the resulting changes when needed so the pull request reflects the latest state.
8. Respond to each actioned comment that has not already been responded to.
9. When Procedure B is complete, restart Procedure A.

# Constraints
1. The goal is approval, not endless local perfectionism.
2. Avoid scope creep except where major-priority review feedback justifies it.
3. Prefer the smallest correct change that resolves the feedback.
4. If direct response posting is unavailable, prepare exact ready-to-post responses and report that as an external blocker.

# Response To User
If approved:
```
Branch: <branch-name>
Pull request: <url>
Checks: Passed
Review status: Approved
Final status: Complete
```

If blocked:
```
Branch: <branch-name>
Pull request: <url|None>
Checks: <Pending|Failed|Unknown>
Review status: <Waiting|Blocked>
Blocker: <concrete external blocker>
Final status: Blocked
```