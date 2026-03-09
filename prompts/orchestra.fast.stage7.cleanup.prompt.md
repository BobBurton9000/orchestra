---
agent: agent
description: Delete the temporary Orchestra branch workspace with a lightweight stage 7 flow
---
# Goal
Delete the completed branch workspace under `.agents/orchestra/<branch-name>/` and verify that nothing outside that directory was touched.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. The directory `.agents/orchestra/<branch-name>/` was deleted recursively, or a concrete error was returned.
2. No temporary Orchestra files remained under that directory after successful cleanup.
3. No files or directories outside `.agents/orchestra/<branch-name>/` were modified or deleted.

# Steps
1. Treat `.agents/orchestra/<branch-name>/` as the only cleanup target. If that directory does not exist, return `ERROR: branch workspace not found for <branch-name>`.
2. Delete `.agents/orchestra/<branch-name>/` recursively.
3. Verify the directory no longer exists.

4. If a stage marker is being updated before cleanup, use:

	```md
	# Current Stage

	Stage: 7
	Prompt: orchestra.fast.stage7.cleanup
	Name: Cleanup
	```

# Response To User
```
Branch: <branch-name>
Removed directory: .agents/orchestra/<branch-name>/
Final status: <Cleaned|ERROR>
```