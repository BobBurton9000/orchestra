---
agent: orchestrator
description: Create a simple stage-1 implementation plan from inline text or a GitHub/Azure DevOps URL using the Orchestra implementation-plan template
name: orchestra.plan.create
argument-hint: "describe the implementation request to plan"
---

# Goal
Create one simple stage-1 implementation plan for the developer request and save it to `.agents/orchestra/<branch-name>/plan.md` using [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md).

The plan must be implementation-only and sequential. Do not add investigative or exploratory tasks.

# Variables
- `{{ request }}`: The developer request to be planned. This may be:
   - Inline implementation text
   - A URL to a GitHub issue or pull request
   - A URL to an Azure DevOps work item
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)

# Invocation Pattern
This prompt is executed with a required implementation request.

- Example: `/orchestra.plan.create add role-based access control for admin routes`
- Example: `<this-command> migrate billing webhook processing to async jobs`
- Example: `<this-command> https://github.com/<owner>/<repo>/issues/123`
- Example: `<this-command> https://dev.azure.com/<org>/<project>/_workitems/edit/456`

Inference rules:
1. Treat the full invocation text as `{{ request }}`.
2. If `{{ request }}` is a supported URL, resolve canonical request details using GitHub CLI for GitHub URLs or Azure DevOps MCP services for Azure DevOps URLs before creating the plan.
3. If no request is provided, return `ERROR: no implementation request provided`.

# Required Outcomes
1. The template [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) was used as the base structure.
2. The output directory `.agents/orchestra/<branch-name>/` exists after execution.
3. The final file path is `.agents/orchestra/<branch-name>/plan.md`.
4. The plan contains all required sections from the stage-1 template, including `Goal`, `TDD Strategy (Red Start, Green Finish)`, and `Sequential Task List`.
5. The `Original Source Files` section contains only file names (not full file contents) when source artifacts are available.
6. The task list is sequential and actionable from start to finish.
7. A `plan-review` subagent review is completed against the generated stage-1 plan and the final verdict is `APPROVED`.
8. If the first review returns `CHANGES REQUESTED`, the plan is revised and re-reviewed iteratively until the verdict is `APPROVED`.
9. The approved plan contains no open questions and no unresolved architectural issues.
10. If `.agents/orchestra/<branch-name>/plan.md` already exists, no overwrite occurs until the developer explicitly confirms.
11. No files outside of `.agents/` are modified.

# Steps
1. Validate input. If `{{ request }}` is empty, return `ERROR: no implementation request provided`.
2. Classify input type:
   - Inline request text
   - GitHub URL (issue or pull request)
   - Azure DevOps work item URL
3. If input is a supported URL, resolve request context using GitHub CLI or Azure DevOps MCP services:
   - GitHub URLs: use GitHub CLI to fetch issue or pull request details including title, description, acceptance context, and linked discussion relevant to implementation scope.
   - Azure DevOps URLs: use Azure DevOps MCP tools to fetch work item title, description, acceptance criteria, and relevant linked items.
4. If URL parsing or remote resolution fails, return a concrete error and do not invent missing requirements.
5. Normalize the resulting request into a concise implementation brief.
6. Read [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) and follow its sections exactly.
7. Extract source artifact names (file names only) from request context when available and populate `Original Source Files`.
8. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
9. Ensure `.agents/orchestra/<branch-name>/` exists. Create it if missing.
10. Check whether `.agents/orchestra/<branch-name>/plan.md` already exists.
11. If the file exists, ask the developer to choose:
   - Overwrite the existing plan
   - Cancel operation
12. If overwrite is confirmed, or no file exists, generate the simple plan from the normalized request and write `.agents/orchestra/<branch-name>/plan.md`.
13. Delegate review of `.agents/orchestra/<branch-name>/plan.md` to the `plan-review` agent.
14. If the `plan-review` verdict is `CHANGES REQUESTED`, update `.agents/orchestra/<branch-name>/plan.md` to address all required changes and run `plan-review` again.
15. Repeat step 14 until the verdict is `APPROVED`.
16. Ensure the approved plan is concise, has no open questions or unresolved architectural issues, and is ready for stage-2 chunking.
17. Do not execute the plan.

# Response To User
If created:
```
Implementation plan created: .agents/orchestra/<branch-name>/plan.md
Template used: [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md)
Plan review verdict: APPROVED
Next step: /orchestra.plan.chunk
Status: Ready for chunking
```

If existing file requires confirmation:
```
Implementation plan already exists: .agents/orchestra/<branch-name>/plan.md
Choose one: Overwrite | Cancel
```

If cancelled:
```
Operation cancelled. Existing plan preserved.
```

If input missing:
```
ERROR: no implementation request provided
```

If unsupported URL or remote resolution fails:
```
ERROR: could not resolve request from provided URL
Reason: <parsing failure | unsupported host | GitHub CLI fetch failure | Azure DevOps MCP fetch failure>
```
