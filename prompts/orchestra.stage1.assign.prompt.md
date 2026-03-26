---
agent: orchestrator
description: Ingest a task from inline text or a GitHub or Azure DevOps URL, normalize it into branch-scoped task.md, and generate complementary gherkin.feature when user-facing behaviour needs clearer acceptance language
name: orchestra.stage1.assign
argument-hint: "describe the task or provide the issue or work item URL"
---

# Goal
Ingest the task in whatever form it is supplied, normalize it into a branch-scoped task document, and save that document to `.agents/orchestra/<branch-name>/task.md`.

If the task is behaviour-oriented and non-technical Gherkin would clarify application behaviour, generate complementary Gherkin and save it to `.agents/orchestra/<branch-name>/gherkin.feature`.

# Agent Use Policy
During this stage, Orchestra may use any agent except the `code-review.*` agents.

# Variables
- `{{ task-input }}`: The task request. This may be:
  - Inline text
  - A GitHub issue or pull request URL
  - An Azure DevOps work item URL
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<task-path>`: `.agents/orchestra/<branch-name>/task.md`
- `<gherkin-path>`: `.agents/orchestra/<branch-name>/gherkin.feature`

# Invocation Pattern
- Example: `/orchestra.stage1.assign fix duplicate invoice emails`
- Example: `<this-command> https://github.com/<owner>/<repo>/issues/123`
- Example: `<this-command> https://dev.azure.com/<org>/<project>/_workitems/edit/456`

Inference rules:
1. Treat the full invocation text as `{{ task-input }}`.
2. If `{{ task-input }}` is empty, return `ERROR: no task provided`.
3. If `{{ task-input }}` is a supported URL, resolve canonical task details before writing any artifact.
4. If remote resolution fails, return a concrete error and do not invent missing requirements.

# Required Outcomes
1. `<task-path>` exists after execution.
2. The template [task.template.md](orchestra.templates/task.template.md) is used as the base structure.
3. The task document captures the normalized problem, expected outcome, scope boundaries, relevant actors, constraints, risks, and source references.
4. If the source already contains usable acceptance criteria or Gherkin, preserve that meaning rather than rewriting it loosely.
5. If no Gherkin is supplied and the work is a behaviour change or bug fix with user-observable impact, create complementary non-technical Gherkin at `<gherkin-path>`.
6. If the work is purely technical and non-technical Gherkin would add noise, do not create `<gherkin-path>` and explain why in `<task-path>`.
7. No files outside `.agents/orchestra/<branch-name>/` are modified.

# Task Document Structure
Write `<task-path>` using [task.template.md](orchestra.templates/task.template.md).

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Ensure `.agents/orchestra/<branch-name>/` exists.
3. Resolve the task source:
   - For GitHub URLs, fetch the issue or pull request title, body, acceptance clues, and materially relevant discussion.
   - For Azure DevOps URLs, fetch the work item title, description, acceptance criteria, and linked context that materially affects scope.
   - For inline text, treat the invocation as the primary source.
4. Normalize the task into plain language suitable for the project team.
5. Use product, architecture, debugging, security, UX, or information-gathering agents as needed to remove obvious ambiguity before writing the artifact.
6. Read [task.template.md](orchestra.templates/task.template.md) and follow its sections exactly.
7. Write `<task-path>` using the template structure.
8. Decide whether complementary Gherkin is appropriate:
   - Create it when the task changes user-facing behaviour, workflow, or acceptance expectations and no adequate Gherkin already exists.
   - Do not create it for purely technical refactors, infrastructure-only work, or internal cleanup with no user-observable behaviour change.
9. If Gherkin is needed, write `<gherkin-path>` with concise non-technical scenarios grounded in the task source.
10. If Gherkin is not needed, record the reason in the `## Gherkin Decision` section of `<task-path>`.
11. Return only the response contract.

# Response To User
If task and Gherkin created:
```
Task captured: .agents/orchestra/<branch-name>/task.md
Gherkin created: .agents/orchestra/<branch-name>/gherkin.feature
Status: Ready for research
```

If task created without Gherkin:
```
Task captured: .agents/orchestra/<branch-name>/task.md
Gherkin created: None
Reason: <why complementary gherkin was not appropriate>
Status: Ready for research
```

If input missing:
```
ERROR: no task provided
```

If URL resolution fails:
```
ERROR: could not resolve task from provided URL
Reason: <parsing failure | unsupported host | GitHub CLI fetch failure | Azure DevOps MCP fetch failure>
```