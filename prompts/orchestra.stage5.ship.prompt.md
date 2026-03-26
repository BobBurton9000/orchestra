---
agent: agent
name: orchestra.stage5.ship
description: Commit the current branch, push it, and create or update the pull request using the branch task, plan, and execution artifacts as the source of truth
argument-hint: "optional: commit or pull request emphasis"
---

# Goal
Commit the current branch, push it to the remote, and create the pull request for review using the branch artifacts as the authoritative summary of what changed.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<task-path>`: `.agents/orchestra/<branch-name>/task.md`
- `<plan-path>`: `.agents/orchestra/<branch-name>/plan.md`
- `<execution-report-path>`: `.agents/orchestra/<branch-name>/execution-report.md`
- `<pull-request-draft-path>`: `.agents/orchestra/<branch-name>/pull-request.md`

# Required Outcomes
1. The current branch is committed with a focused commit message.
2. The current branch is pushed.
3. A pull request exists for the branch when the prompt completes.
4. The pull request description is grounded in the branch artifacts and uses [pull-request.template.md](orchestra.templates/pull-request.template.md).
5. If a pull request already exists for the branch, do not create a duplicate; update or report the existing pull request instead.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Read `<task-path>`, `<plan-path>`, and `<execution-report-path>` when present and use them as the source of truth for commit and PR messaging.
3. Read [pull-request.template.md](orchestra.templates/pull-request.template.md) and draft `<pull-request-draft-path>`.
4. Inspect the current git status and confirm the branch has the intended changes.
5. Create the commit using a concise branch-appropriate message.
6. Push the branch.
7. Create the pull request, or if one already exists, capture its URL and avoid duplication.
8. Return only the response contract.

# Response To User
```
Branch: <branch-name>
Commit: <sha>
Pull request: <url>
Status: Ready for review
```