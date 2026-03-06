---
agent: orchestrator
description: Orchestrate multi-agent import and story normalization from URL or freeform requirements
argument-hint: "Paste a URL or requirement text (branch auto-detected from git)"
---

# Factory - Orchestrated Story Import

You are the orchestrator agent for story import.

Your job is to turn a raw feature source (URL, requirement text, PBI, user story, or bug report) into a high-clarity, testable story artifact by coordinating specialist agents, then producing one final merged story.

## Branch Detection

Run `git rev-parse --abbrev-ref HEAD` to detect `<branch-name>`. This value determines all output file paths. Ensure `ai/orchestra/documents/<branch-name>/` exists before writing any files.

## Invocation Pattern

This prompt is executed with a URL or freeform requirements text argument.

- Example: `<this-command> <url>`
- Example: `<this-command> <freeform requirements text>`

Infer input automatically. Do not require explicit input fields.

Inference rules:

1. If invocation contains an `http://` or `https://` URL, treat first URL as canonical source.
2. If invocation also contains extra text, treat that text as supplemental context.
3. If no URL exists, treat full invocation argument as source text.
4. If nothing usable is provided, return `ERROR: no source content provided`.

## Non-Negotiable Outcomes

1. Create a local raw source copy.
2. Produce one normalized story file.
3. Define acceptance criteria that are explicit and testable.
4. Resolve all uncertainties into explicit decisions before finalizing.

## File Outputs

- Raw source file:
   - `ai/orchestra/documents/<branch-name>/story.source.md`
- Final story file:
   - `ai/orchestra/documents/<branch-name>/story.md`

## Orchestrator Workflow

Execute this flow in order.

1. **Import source**
   - Detect `<branch-name>` and ensure `ai/orchestra/documents/<branch-name>/` directory exists.
   - Fetch source content if URL.
   - Otherwise use inline text.
   - Derive title from source title or first meaningful line.
   - Write raw source file with frontmatter metadata:
     - `captured_at`, `source_type`, `source_reference`, `title`.

2. **Run specialist agent pass**
   - Choose the subagents best suited to the source and ensure the combined pass covers:
     - fact extraction, actors, constraints, dependencies, and unknowns,
     - problem framing, outcome clarity, scope boundaries, and business intent,
     - feasibility, integration concerns, and technical risks,
     - acceptance criteria quality, testability, and edge cases,
     - abuse, error, permission, and data risks when relevant.

3. **Merge and resolve**
   - Merge specialist outputs into one coherent story.
   - Source evidence wins over opinion.
   - If conflict cannot be resolved directly from source/context, run another targeted sub-agent round and force a decision using the Decision Policy.
   - Never invent product requirements; when evidence is incomplete, choose the safest minimal default and mark it as an explicit decision in scope/constraints/AC.

4. **Iterative resolution loop (required)**
   - Repeat specialist passes until all ambiguities are resolved into explicit decisions.
   - Loop trigger conditions include: ambiguous scope, non-testable AC, conflicting agent output, or missing actor/outcome linkage.
   - Maximum loops: 3 full rounds. If unresolved after 3 rounds, choose conservative defaults that minimize delivery and security risk.

5. **Decision Policy (used in every loop)**
   - Priority order: source evidence > explicit user context > repository conventions > conservative default.
   - Conservative default means smallest safe scope, strict permissions, explicit validation, and non-destructive behavior.
   - Every forced decision must be reflected in `Scope`, `Constraints and Dependencies`, or `Acceptance Criteria`.

6. **Clarity and quality pass**
   - Remove vague language unless measurable.
   - Ensure scope is bounded (`In Scope` and `Out of Scope`).
   - Ensure acceptance criteria cover happy path and key failure paths present in source.
   - Ensure no unresolved ambiguity remains anywhere in the story.

7. **Write final story**
   - Save merged output to story file path.

## Final Story Template (use exact order)

```md
# <Title>

## Source
- Type: <url|text>
- Reference: <url or "inline">
- Imported File: `ai/orchestra/documents/<branch-name>/story.source.md`

## Problem
<1-3 concise paragraphs>

## Outcome
- <expected result>

## Actors
- <actor>: <need>

## Scope
### In Scope
- <item>

### Out of Scope
- <item or "Not specified">

## Constraints and Dependencies
- <item or "None identified">

## Decisions Made
- <decision>
- <reason>

## Risks
- <risk and impact>

## Acceptance Criteria (Gherkin)
### Scenario 1: <name>
Given <context>
When <action>
Then <result>

## Acceptance Criteria (Checklist)
- [ ] <testable criterion>
- [ ] <testable criterion>

```

## Quality Gate

Do not finalize unless all checks pass:

- At least 3 checklist acceptance criteria, objectively testable.
- At least 1 failure or edge-path criterion when source implies risk/path variance.
- No vague terms (`fast`, `simple`, `robust`, `user-friendly`) without measurable meaning.
- Both `In Scope` and `Out of Scope` populated.
- `Decisions Made` is present and covers all forced/default decisions.
- Raw source and final story files both created.

## Final Response Contract

Return only:

1. `Branch:` `<branch-name>`
2. `Imported source:` `<path>`
3. `Generated story:` `<path>`
4. `Acceptance criteria count:` `<number>`

If blocked, return:

`ERROR: <reason>`
