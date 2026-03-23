---
agent: orchestrator
description: Expand the branch implementation plan into detailed delivery chunks and tasks using the Orchestra implement-chunk template
name: orchestra.plan.chunk
argument-hint: "optional: chunking constraints, sequencing priorities, or focus areas"
---

# Goal
Expand the existing branch plan at `.agents/orchestra/<branch-name>/plan.md` into a detailed chunked implementation plan and save it to `.agents/orchestra/<branch-name>/chunk-plan.md` using the canonical Orchestra template at [implement-chunk.template.md](orchestra.templates/implement-chunk.template.md).

The resulting plan must remain implementation-only and must not include investigative or exploratory tasks.

# Variables
- `<branch-name>`: [branch-name](orchestra.snippets/branch-name.md)
- `<source-plan-path>`: `.agents/orchestra/<branch-name>/plan.md`
- `<chunk-plan-path>`: `.agents/orchestra/<branch-name>/chunk-plan.md`
- `{{ chunking-constraints }}`: Optional invocation hint for chunk size, order, ownership boundaries, or delivery constraints.

# Invocation Pattern
This prompt is executed with an optional chunking constraint hint.

- Example: `/orchestra.plan.chunk`
- Example: `<this-command> keep chunks under one day of implementation each`
- Example: `<this-command> split frontend and backend work into separate chunks`

Inference rules:
1. If `{{ chunking-constraints }}` is present, treat it as a bounded chunking hint.
2. If `{{ chunking-constraints }}` conflicts with technical reality of the plan, preserve plan correctness and note the mismatch in output.
3. If `<source-plan-path>` does not exist, return `ERROR: plan not found`.

# Required Outcomes
1. `<source-plan-path>` is read as the canonical stage-1 implementation source.
2. The template [implement-chunk.template.md](orchestra.templates/implement-chunk.template.md) was used as the base structure.
3. The final file path is `.agents/orchestra/<branch-name>/chunk-plan.md`.
4. Every chunk and task in the resulting plan has `Status` initialized to `pending`.
5. Chunk definitions are sequential, actionable, and implementation-focused.
6. Chunk tasks include explicit files-to-change notes and validation intent.
7. No files outside `.agents/` are modified.
8. The resulting plan is ready for `/orchestra.plan.execute`.

# Steps
1. Resolve `<branch-name>` using [branch-name](orchestra.snippets/branch-name.md).
2. Confirm `<source-plan-path>` exists. If missing, return `ERROR: plan not found`.
3. Read `<source-plan-path>` and treat it as the stage-1 planning input.
4. Read [implement-chunk.template.md](orchestra.templates/implement-chunk.template.md) and follow its sections exactly.
5. Convert the stage-1 sequential tasks into delivery chunks that preserve end-to-end sequence.
6. Decompose each chunk into explicit tasks, with intent, steps, file targets, expected outcomes, and review checkpoints.
7. Apply `{{ chunking-constraints }}` when provided, unless it would break correctness or dependency order.
8. Initialize all generated chunk and task statuses to `pending`.
9. Write the expanded chunked plan to `<chunk-plan-path>` and preserve `<source-plan-path>` unchanged.
10. Do not execute the plan.

# Response To User
If successful:
```
Chunked implementation plan created: .agents/orchestra/<branch-name>/chunk-plan.md
Template used: [implement-chunk.template.md](orchestra.templates/implement-chunk.template.md)
Status: Ready for execution
```

If plan is missing:
```
ERROR: plan not found
```

If constraints conflict:
```
Chunking completed with adjustments
Reason: <constraint mismatch and applied correction>
```
