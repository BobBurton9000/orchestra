---
agent: orchestrator
description: Create a standalone branch-scoped implementation playbook from inline text or a GitHub or Azure DevOps URL so a human can audit the proposed direction before execution starts
name: orchestra.create-playbook
argument-hint: "describe the implementation request to turn into a playbook"
---

# Goal
Create one standalone implementation playbook for the developer request and save it to `.orchestra/<branch-name>/playbook-<playbook-slug>.md` using [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md).

This prompt is intentionally standalone. Its job is to produce an auditable proposed direction after doing the necessary up-front research and resolving open questions. It does not participate in the stage workflow automatically.

# Variables
- `{{ request }}`: The developer request to be turned into a playbook. This may be:
  - Inline implementation text
  - A URL to a GitHub issue or pull request
  - A URL to an Azure DevOps work item
- `<branch-name>`: Resolve the current branch using [branch-name](orchestra.snippets/branch-name.md), then normalize it by replacing `/` and whitespace with `-` so the result is safe to use as one directory name.
- `<playbook-slug>`: Derive a concise deterministic slug from `{{ request }}`. Lowercase it, replace whitespace and path separators with `-`, remove characters that are unsafe for filenames, collapse repeated `-`, trim leading and trailing `-`, and keep it short but recognizable.
- `<output-dir>`: `.orchestra/<branch-name>/`
- `<output-path>`: `.orchestra/<branch-name>/playbook-<playbook-slug>.md`

# Invocation Pattern
This prompt is executed with a required implementation request.

- Example: `/orchestra.create-playbook add role-based access control for admin routes`
- Example: `<this-command> migrate billing webhook processing to async jobs`
- Example: `<this-command> https://github.com/<owner>/<repo>/issues/123`
- Example: `<this-command> https://dev.azure.com/<org>/<project>/_workitems/edit/456`

Inference rules:
1. Treat the full invocation text as `{{ request }}`.
2. If `{{ request }}` is a supported URL, resolve canonical request details using GitHub CLI for GitHub URLs or Azure DevOps MCP services for Azure DevOps URLs before creating the playbook.
3. If no request is provided, return `ERROR: no implementation request provided`.
4. Resolve `<branch-name>` from the current git branch, then normalize it before using `<output-dir>` or `<output-path>`.
5. Derive `<playbook-slug>` from `{{ request }}` before using `<output-path>`.
6. If slug generation would be empty after normalization, use `playbook` as the fallback slug.

# Required Outcomes
1. The template [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) was used as the base structure.
2. The output directory `<output-dir>` exists after execution.
3. The final file path is `<output-path>`.
4. The playbook contains all required sections from the template.
5. The playbook is implementation-focused, sequential, and concrete enough for a human to audit direction and risk.
6. Research needed to remove open questions is performed before writing the final playbook.
7. The approved playbook contains no unresolved architectural questions.
8. A `plan-review` subagent review is completed against the generated playbook and the final verdict is `APPROVED`.
9. If the first review returns `CHANGES REQUESTED`, the playbook is revised and re-reviewed iteratively until the verdict is `APPROVED`.
10. If `<output-path>` already exists, no overwrite occurs until the developer explicitly confirms.
11. No files outside `<output-dir>` are modified.

# Steps
1. Validate input. If `{{ request }}` is empty, return `ERROR: no implementation request provided`.
2. Classify input type:
   - Inline request text
   - GitHub URL (issue or pull request)
   - Azure DevOps work item URL
3. If input is a supported URL, resolve request context using GitHub CLI or Azure DevOps MCP services:
   - GitHub URLs: fetch issue or pull request details including title, description, acceptance context, and linked discussion relevant to implementation scope.
   - Azure DevOps URLs: fetch work item title, description, acceptance criteria, and relevant linked items.
4. If URL parsing or remote resolution fails, return a concrete error and do not invent missing requirements.
5. Normalize the resulting request into a concise implementation brief.
6. Perform targeted repository and product research needed to eliminate open questions before finalizing the playbook.
7. Read [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) and follow its sections exactly.
8. Extract source artifact names when available and populate `Original Source Files`.
9. Resolve and normalize `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
10. Derive `<playbook-slug>` from `{{ request }}`.
11. Ensure `<output-dir>` exists. Create it if missing.
12. Check whether `<output-path>` already exists.
13. If the file exists, ask the developer to choose:
    - Overwrite the existing playbook
    - Cancel operation
14. If overwrite is confirmed, or no file exists, generate the playbook from the normalized request and write `<output-path>`.
15. Delegate review of `<output-path>` to the `plan-review` agent.
16. If the `plan-review` verdict is `CHANGES REQUESTED`, update `<output-path>` to address all required changes and run `plan-review` again.
17. Repeat step 16 until the verdict is `APPROVED`.
18. Do not execute the playbook.

# Response To User
If created:
```
Implementation playbook created: .orchestra/<branch-name>/playbook-<playbook-slug>.md
Template used: [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md)
Plan review verdict: APPROVED
Status: Ready for human audit
```

If existing file requires confirmation:
```
Implementation playbook already exists: .orchestra/<branch-name>/playbook-<playbook-slug>.md
Choose one: Overwrite | Cancel
```

If cancelled:
```
Operation cancelled. Existing playbook preserved.
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
