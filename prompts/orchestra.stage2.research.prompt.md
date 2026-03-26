---
agent: orchestrator
description: Create branch-scoped research documents for the current task by investigating the existing end-to-end user experience and the relevant architecture and structure in parallel
name: orchestra.stage2.research
argument-hint: "optional: focus the research on a specific workflow, subsystem, or risk"
---

# Goal
Read the current branch task document, create `.agents/orchestra/<branch-name>/research/`, and compile supporting research documents that prepare the team to plan with fewer surprises.

The mandatory research topics are:
1. Existing E2E user experience
2. Architecture and Structure

# Agent Use Policy
During this stage, Orchestra may use any agent except the `code-review.*` agents.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<task-path>`: `.agents/orchestra/<branch-name>/task.md`
- `<research-dir>`: `.agents/orchestra/<branch-name>/research`
- `{{ research-focus }}`: Optional hint that narrows the investigation without skipping the mandatory topics.

# Invocation Pattern
- Example: `/orchestra.stage2.research`
- Example: `<this-command> focus on checkout failure paths`

Inference rules:
1. If `<task-path>` is missing, return `ERROR: task document not found`.
2. `{{ research-focus }}` may narrow emphasis but must not remove the mandatory research topics.

# Required Outcomes
1. `<task-path>` is read in full before research starts.
2. `<research-dir>` exists after execution.
3. Orchestra delegates the mandatory research topics in parallel.
4. The following files are created in `<research-dir>`:
   - `existing-e2e-user-experience.md`
   - `architecture-and-structure.md`
5. `existing-e2e-user-experience.md` documents the current workflow, surrounding behaviours, observed edge cases, and what must keep working after implementation.
6. `architecture-and-structure.md` documents relevant patterns, interfaces, boundaries, symbols, dependencies, anti-patterns, and reuse opportunities.
7. If a mandatory topic is genuinely not applicable, the document still exists and records that determination with evidence.
8. No files outside `.agents/orchestra/<branch-name>/` are modified.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Confirm `<task-path>` exists. If missing, return `ERROR: task document not found`.
3. Read `<task-path>` in full and treat it as the canonical research brief.
4. Ensure `<research-dir>` exists.
5. Delegate the mandatory research topics in parallel:
   - **Existing E2E user experience**
     - Use browser testing and product or UX oriented agents when applicable.
     - Investigate the current user workflow surrounding the task.
     - Record what exists today, what neighbouring behaviour appears coupled to it, and what would obviously regress if implementation is careless.
   - **Architecture and Structure**
     - Use architecture, debugger, information-gathering, domain, platform, data, integration, security, and other relevant agents as needed.
     - Record relevant code patterns, symbols, file locations, interfaces, anti-patterns, and structural constraints.
6. Use [research.template.md](orchestra.templates/research.template.md) as the base structure for each research document.
7. Write the delegated findings to:
   - `.agents/orchestra/<branch-name>/research/existing-e2e-user-experience.md`
   - `.agents/orchestra/<branch-name>/research/architecture-and-structure.md`
8. If `{{ research-focus }}` was provided, apply it as emphasis inside both documents without skipping required evidence.
9. Return only the response contract.

# Response To User
```
Task: .agents/orchestra/<branch-name>/task.md
Research folder: .agents/orchestra/<branch-name>/research/
Created:
- .agents/orchestra/<branch-name>/research/existing-e2e-user-experience.md
- .agents/orchestra/<branch-name>/research/architecture-and-structure.md
Status: Ready for planning
```