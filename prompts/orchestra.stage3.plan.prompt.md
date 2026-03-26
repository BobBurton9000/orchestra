---
agent: orchestrator
description: Read the current task and all branch research in full, then produce an execution-ready branch plan using the Orchestra implementation-plan template and iterate with plan-review until approved
name: orchestra.stage3.plan
argument-hint: "optional: planning constraints, sequencing priorities, or delivery emphasis"
---

# Goal
Read the full branch task and all research produced so far, then produce an execution-ready plan at `.agents/orchestra/<branch-name>/plan.md` using [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md).

This stage replaces the older separate planning and chunking flow. The resulting plan must be detailed enough to execute directly without requiring a separate chunk-plan artifact.

# Agent Use Policy
During this stage, Orchestra may use any agent except the `code-review.*` agents.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<task-path>`: `.agents/orchestra/<branch-name>/task.md`
- `<research-dir>`: `.agents/orchestra/<branch-name>/research`
- `<plan-path>`: `.agents/orchestra/<branch-name>/plan.md`
- `{{ planning-constraints }}`: Optional bounded hint for sequencing, scope emphasis, or delivery constraints.

# Invocation Pattern
- Example: `/orchestra.stage3.plan`
- Example: `<this-command> split the work into low-risk increments first`

Inference rules:
1. `<task-path>` must exist or return `ERROR: task document not found`.
2. `<research-dir>` must contain research documents or return `ERROR: research documents not found`.
3. If `{{ planning-constraints }}` conflicts with task or research evidence, preserve correctness and note the mismatch in the response.

# Required Outcomes
1. Orchestra reads the following in full, every line, before planning starts:
   - `<task-path>`
   - Every document in `<research-dir>`
2. The template [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) is used as the base structure.
3. The final file path is `.agents/orchestra/<branch-name>/plan.md`.
4. The plan is execution-ready, sequential, and concrete enough that stage 4 can act on it directly.
5. The plan contains no unresolved architectural questions.
6. A `plan-review` subagent review is completed and the final verdict is `APPROVED`.
7. If review returns `CHANGES REQUESTED`, the plan is revised and re-reviewed until the verdict is `APPROVED`.
8. No files outside `.agents/orchestra/<branch-name>/` are modified.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Confirm `<task-path>` exists. If missing, return `ERROR: task document not found`.
3. Confirm `<research-dir>` exists and contains research documents. If not, return `ERROR: research documents not found`.
4. Read `<task-path>` in full.
5. Read every research document in `<research-dir>` in full.
6. Read [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md) and follow its sections exactly.
7. Build an execution-ready plan that incorporates the research findings, resolves open questions, and sequences the work in the safest practical order.
8. Apply `{{ planning-constraints }}` when provided unless it would break correctness.
9. Write the plan to `<plan-path>`.
10. Delegate review of `<plan-path>` to the `plan-review` agent.
11. If the verdict is `CHANGES REQUESTED`, update `<plan-path>` and re-run `plan-review`.
12. Repeat step 11 until the verdict is `APPROVED`.
13. Do not execute the plan.

# Response To User
If successful:
```
Task: .agents/orchestra/<branch-name>/task.md
Research: .agents/orchestra/<branch-name>/research/
Plan created: .agents/orchestra/<branch-name>/plan.md
Template used: [implementation-plan.template.md](orchestra.templates/implementation-plan.template.md)
Plan review verdict: APPROVED
Next step: /orchestra.stage4.execute
```

If task is missing:
```
ERROR: task document not found
```

If research is missing:
```
ERROR: research documents not found
```