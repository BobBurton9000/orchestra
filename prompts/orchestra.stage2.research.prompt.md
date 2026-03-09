---
agent: orchestrator
description: Produce contextual research documents to support story refinement
---
# Goal
Research the repository for related features, architecture and system patterns, then produce documentation optimised as context for downstream LLM agents.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Required Outcomes
1. One document per distinct research topic discovered was produced using the file path `.agents/orchestra/<branch-name>/research/<topic-name>.md`.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was updated to identify stage 2 as the current branch stage.
3. At least 1 document was created.
4. All claims were grounded in real repository evidence (files, symbols, tests).
5. Only real file paths and symbol names were used.
6. Every code block referenced a real file path in a caption or comment.
7. Related features, reusable architecture, and established system patterns were identified.
8. No task lists, implementation checklists, or status tracking were included.
9. Documentation gaps were resolved via recursive specialist passes until no critical context gaps remained.

# Steps
1. **Load and frame the plan**: Read `.agents/orchestra/<branch-name>/story.md` as canonical source. If the file does not exist, return `ERROR: no story found for branch <branch-name>`.
2. **Update current stage marker**: Update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content. If the file does not exist, return `ERROR: current stage marker not found for branch <branch-name>`.

   ```md
   # Current Stage

   Stage: 2
   Prompt: orchestra.stage2.research
   Name: Research
   ```
3. **Load the template**: Read [research.template](orchestra.templates/research.template.md) to determine what information you need to acquire per research topic. 
4. **Specialist sub agent discovery pass**:
	1. Choose all sub agents applicable to the plan and ensure the combined pass covers:
		1. Candidate files, symbols, call paths, and adjacent features
		2. Architecture boundaries, extension points, and system patterns
		3. Concrete implementation conventions and hotspots for each relevant surface
		4. Tests that define existing behavior and expected invariants
		5. Auth, validation, and data-handling patterns when relevant
5. **Merge evidence map**
	1. Build a single evidence-backed map of files, symbols, flows, and tests.
	2. Exclude items not directly relevant to the plan boundary.
6. **Recursive gap-closure loop**:
	1. Return to step 4 (Specialist sub agent discovery pass) when any of the following exists:
		- Missing key symbol ownership
		- Missing tests for claimed behaviour
		- Architecture flow not traceable across real files
		- Unclear system pattern recommendation
		- Contradiction between sub agent finding
	2. The maximum number of times you can (and must, if required) loop is specified in [loop-count](orchestra.config/loop-count.md).
	3. If still incomplete after the maximum loop count has been exhausted, refer to [orchestrator-decision-policy](orchestra.snippets/orchestrator-decision-policy.md)
7. **Topic decomposition**:
	1. Partition findings into distinct documentation topics
	2. Topic split rule: create separate topics when concerns differ by capability boundary, subsystem boundary, or life-cycle responsibility.
	3. If uncertain, prefer more granular topics over one large mixed topic.
8. **Write research documents**: For each topic, create a separate research document using the Required Document Structure in this prompt.
9. **Submit completion to judge sub agent**: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Story source: <path>
Topic research document created: <number>
Topic document paths: <comma-seperated paths>
Discovery rounds: <number>
```