---
agent: agent
description: Extract a learning from the current chat session and compile it into a reusable Orchestra skill
name: orchestra.learn
argument-hint: "describe the learning or pattern discovered in this session"
---
# Extract Session Learning into a Skill

Review the current chat session and extract a reusable, generalised piece of knowledge — a pattern, convention, gotcha, or technique — and compile it into an Orchestra skill document that a future LLM agent can use directly.

## Discovery process (do this before writing)

Work through these steps sequentially. Do not start writing the skill until all four are done.

1. **Identify the learning (iterative).** Re-read the user request and full chat history. Propose a one-sentence definition of the insight, technique, or pattern discovered — it must be generalisable, not specific to this one ticket or task. Present it to the user and ask whether it is correct. After every response from the user that is not an explicit confirmation (i.e. anything other than "yes", "ok", "correct", "that's right", or equivalent short affirmations), incorporate their feedback, restate the revised one-sentence definition with optimised phrasing, and ask for confirmation again. Only proceed to step 2 once the user has explicitly confirmed the definition is correct. Do not interpret alternative suggestions or corrections as confirmation — always restate and re-ask.
2. **Locate grounding evidence.** Find the real code, config, or documentation in the repository that demonstrates the learning. Record exact file paths, class names, method names, and line-level details. Do not describe things you haven't read.
3. **Define the scope boundary.** Determine what the skill applies to and what it explicitly does NOT apply to. Identify look-alike situations where a future agent might incorrectly use this skill.
4. **Validate with examples.** Find at least two concrete cases in the codebase or session history that illustrate the learning — one positive (the pattern applied correctly) and one negative (the anti-pattern or the problem it prevents).

## Requirements

1. **Frontmatter** — include these fields:
   - `name`: kebab-case slug that names the concept
   - `description`: one precise sentence that allows another LLM to decide whether this skill is relevant

2. **Quick Reference table** (first section) — every key symbol involved: class name, file path, and one-line purpose. Must be comprehensive enough to navigate the codebase without further searching.

3. **Goals and Non-Goals** — explicit scope boundary. Non-goals must name specific look-alike situations that are out of scope, preventing a future agent from over-applying the skill.

4. **The Learning** — a clear, direct explanation of what was discovered. State the insight in a single paragraph before expanding. Reference real code. Use tables over prose where structure exists.

5. **Behaviour Examples** — at least two concrete examples showing the pattern in action, referencing real file paths and class/method names from the codebase.

6. **Anti-Patterns** — a dedicated section listing what NOT to do and why, derived directly from the problem this session uncovered.

7. **Design Decisions** — if the learning involves a non-obvious choice, document: what was decided, the alternative, and why this choice was made. Omit this section if no design decision is involved.

## Output

- Write the skill document to `.agents/skills/zz-orchestra.<name>/SKILL.md`.
- Required frontmatter:
  ```yaml
  ---
  name: <name>
  description: '<one precise sentence>.'
  ---
  ```
- Sections must appear in this order:
  1. Quick Reference
  2. Goals and Non-Goals
  3. The Learning
  4. Behaviour Examples
  5. Anti-Patterns
  6. Design Decisions _(if applicable)_

- Every code block must reference a real file path in a comment or caption. Do not write hypothetical code.
- Use tables over prose wherever structure is possible.
- Do not include task lists, implementation steps, or status-tracked work items.
- Your final response should confirm the path created and state the one-sentence learning in plain English.
