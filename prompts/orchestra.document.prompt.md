---
description: Create an Orchestra-style feature document that explains behavior, architecture, and design decisions — optimised as LLM context for future agents
name: orchestra.document
argument-hint: "describe the existing feature you want documented"
---
# Prompt Goal: Create Orchestra Feature Documentation
Document an existing feature so that a future LLM agent can read this file alone and immediately know: what the feature does, which files implement it, what the key symbols are, what decisions were already made, and what to avoid. Ground every claim in real code — no abstract descriptions of things you haven't read.

## Discovery process (do this before writing)
Work through these steps sequentially. Do not start writing the document until all four are done.

1. **Identify the feature boundary.** Re-read the user request. Write a one-sentence definition of the feature that names at least one concrete class or file.
2. **Enumerate all affected files.** Search the codebase to find every file that is part of, or directly used by, this feature. List each file with its exact relative path. You will need this list for the frontmatter and the Quick Reference section.
3. **Read the key files.** For each major file: note the class name, namespace, public interface (method signatures), and any injected dependencies. Do not paraphrase — record the real names.
4. **Locate the tests.** Find integration or unit tests that exercise this feature. Tests are ground-truth documentation of expected behaviour; use them to validate your understanding.

## Requirements

1. **Frontmatter** — include these fields:
   - `name`: kebab-case slug
   - `description`: one precise sentence that allows another LLM to decide whether this document is relevant to its task

2. **Quick Reference table** (first section in the document body) — a plain table listing every key symbol in this feature: class name, file path, and one-line purpose. This is the most important section for LLM navigation; it must be comprehensive.

3. **Goals and Non-Goals** — explicit scope boundary. The non-goals section must name specific things that _look_ related but are out of scope, so a future LLM does not over-apply this context.

4. **Architecture diagram** — a Mermaid diagram showing data flow between real named components. Use actual class or method names, not generic boxes.

5. **Data and API surface** — document every public interface, constructor signature, method, config key, or database column that defines the contract for this feature. Use the exact names from the code. Prefer tables over prose.

6. **Behaviour examples** — at least two concrete examples showing input → processing → output, referencing the real code paths involved.

7. **Design decisions** — for each non-obvious design choice, document: what was decided, what the alternative was, and why this choice was made. This prevents future agents from "fixing" intentional design.

8. **Anti-patterns** — a dedicated section listing what NOT to do and why. This is as valuable as positive guidance for preventing LLM mistakes.

## Output
- Write the primary document to `.agents/skills/zz-orchestra.<name>/SKILL.md`.
- Required frontmatter:
  ```yaml
  ---
  name: <name>
  description: '<one precise sentence>.''
  ---
  ```
- Sections must appear in this order:
  1. Quick Reference
  2. Goals and Non-Goals
  3. Architecture
  4. Data and API Surface
  5. Behaviour Examples
  6. Design Decisions
  7. Anti-Patterns

- If the topic warrants it, split large sections into supporting files (e.g. `data-model.md`, `flows.md`). SKILL.md must link to each file with a one-sentence description of what it covers.
- Every code block must reference a real file path in a comment or caption. Do not write hypothetical code.
- Use tables over prose wherever structure is possible.
- Do not include implementation task lists, checklists of coding steps, or status-tracked work items.
