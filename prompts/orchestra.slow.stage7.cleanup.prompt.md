---
agent: agent
description: Delete the temporary Orchestra branch workspace after all work is finished and the branch is ready to merge
model: Claude Haiku 4.5 (copilot)
---
# Goal
Delete the temporary Orchestra branch workspace for a completed branch after implementation and review feedback work are finished and the branch is about to be merged.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. The directory `.agents/orchestra/<branch-name>/` was deleted recursively, or a concrete error was returned if deletion could not be completed.
2. No temporary planning, research, execution, or review-feedback documents remained under `.agents/orchestra/<branch-name>/` after successful cleanup.
3. No files or directories outside `.agents/orchestra/<branch-name>/` were modified or deleted.

# Steps
1. **Resolve branch workspace**: Treat `.agents/orchestra/<branch-name>/` as the only cleanup target. If that directory does not exist, return `ERROR: branch workspace not found for <branch-name>`.
2. **Delete branch workspace**: Remove `.agents/orchestra/<branch-name>/` recursively.
3. **Verify cleanup**: Confirm `.agents/orchestra/<branch-name>/` no longer exists.
4. **Finalize response**: Return only the response contract from this prompt.

# Response To User
```
Branch: <branch-name>
Removed directory: .agents/orchestra/<branch-name>/
Final status: <Cleaned|ERROR>
```