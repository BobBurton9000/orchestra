---
agent: orchestrator
description: Create a single implementation plan from inline text or a GitHub/Azure DevOps URL using MCP services and the Orchestra implementation-plan template
name: orchestra.plan.create
argument-hint: "describe the implementation request to plan"
---

# Goal
Create one implementation plan for the developer request and save it to `.agents/orchestra/<branch-name>/plan.md` using the canonical Orchestra template at [prompts/orchestra.templates/implementation-plan.template.md](prompts/orchestra.templates/implementation-plan.template.md).

The plan must contain only implementation work. Do not add investigative or exploratory tasks.

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
2. If `{{ request }}` is a supported URL, resolve canonical request details using MCP services before creating the plan.
3. If no request is provided, return `ERROR: no implementation request provided`.

# Required Outcomes
1. The template [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) was used as the base structure.
2. The output directory `.agents/orchestra/<branch-name>/` exists after execution.
3. The final file path is `.agents/orchestra/<branch-name>/plan.md`.
4. Every delivery chunk and task in the plan has a status field initialized to `pending`.
5. The plan is sequential, actionable, and implementation-focused.
6. If `.agents/orchestra/<branch-name>/plan.md` already exists, no overwrite occurs until the developer explicitly confirms.
7. No files outside of `.agents/` are modified.
8. If the request is a supported URL, MCP services are used to fetch and normalize source details before drafting the plan.

# Steps
1. Validate input. If `{{ request }}` is empty, return `ERROR: no implementation request provided`.
2. Classify input type:
   - Inline request text
   - GitHub URL (issue or pull request)
   - Azure DevOps work item URL
3. If input is a supported URL, resolve request context using MCP services:
   - GitHub URLs: use GitHub MCP tools to fetch issue/PR details including title, description, acceptance context, and linked discussion relevant to implementation scope.
   - Azure DevOps URLs: use Azure DevOps MCP tools to fetch work item title, description, acceptance criteria, and relevant linked items.
4. If URL parsing or MCP resolution fails, return a concrete error and do not invent missing requirements.
5. Normalize the resulting request into a concise implementation brief and use that brief as the planning source.
6. Read [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) and follow its sections exactly.
7. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
8. Ensure `.agents/orchestra/<branch-name>/` exists. Create it if missing.
9. Check whether `.agents/orchestra/<branch-name>/plan.md` already exists.
10. If the file exists, ask the developer to choose:
   - Overwrite the existing plan
   - Cancel operation
11. If overwrite is confirmed, or no file exists, generate the plan from the normalized request and write `.agents/orchestra/<branch-name>/plan.md`.
12. Ensure the written plan is concise, comprehensive, and ready for execution.
13. Do not execute the plan.

# Response To User
If created:
```
Implementation plan created: .agents/orchestra/<branch-name>/plan.md
Template used: [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md)
Status: Ready for execution
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

If unsupported URL or MCP resolution fails:
```
ERROR: could not resolve request from provided URL
Reason: <parsing failure | unsupported host | MCP fetch failure>
```
