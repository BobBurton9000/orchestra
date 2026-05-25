---
agent: agent
description: Extract a durable learning from the current chat session and compile it into a concise standalone Orchestra skill
name: learn
argument-hint: "describe the learning or pattern discovered in this session"
---
# Goal

Review the current chat session, extract one reusable and generalised learning, and compile it into a concise Orchestra skill that stands on its own without depending on volatile repository details.

# Variables

- `learning_hint`: the user-supplied description of the learning, pattern, convention, gotcha, or technique to capture.

# Invocation Pattern

Use this prompt when the user wants to preserve a lesson from the current session as a reusable skill for future agents.

# Required Outcomes

- Confirm a single-sentence definition of the learning with the user before writing the skill.
- Produce a skill that is durable, concise, and understandable without opening repository files.
- Keep examples minimal: include only the shortest positive and negative examples needed to teach the pattern.
- Use repository inspection only to prevent false claims or to confirm stable terminology, not to populate the document with brittle implementation details.
- Avoid file inventories, line references, exhaustive symbol lists, and codebase-specific examples unless the learning is inherently about a stable repository artifact.
- Write the skill document to `.agents/orchestra/skills/orchestra-<name>/SKILL.md`.

# Steps

1. **Identify the learning (iterative).** Re-read the user request and chat history. Propose a one-sentence definition of the insight in general terms. Present it to the user and ask whether it is correct. After every response that is not an explicit confirmation, incorporate the feedback, restate the revised one-sentence definition, and ask for confirmation again. Only continue once the user explicitly confirms.
2. **Validate the claim.** Check the session first. Inspect repository files only if needed to avoid making the skill inaccurate or to confirm stable naming. Gather the minimum evidence necessary; do not collect details that will not appear in the final skill.
3. **Set the boundary.** Define what the skill applies to, what it does not apply to, and the common look-alike situations where a future agent might over-apply it.
4. **Write for durability.** Prefer standalone guidance, short tables, and concise examples over repository-specific references. Mention a repository path only when it is genuinely required to understand the rule and likely to remain stable.
5. **Trim aggressively.** Remove any detail that is not needed for a future agent to correctly apply the learning.

# Response To User

## Skill Requirements

1. **Frontmatter**
  - Include `name`: kebab-case slug naming the concept.
  - Include `description`: one precise sentence that helps another LLM decide whether the skill is relevant.

2. **Quick Reference**
  - Make the first section a compact table.
  - Summarise the key patterns, rules, or example forms needed to apply the learning.
  - Do not turn this into a repository navigation index unless the repository artifact is itself the learning.

3. **Goals and Non-Goals**
  - State the scope explicitly.
  - Non-goals must call out look-alike situations that are out of scope so the skill is not over-applied.

4. **The Learning**
  - Start with one clear paragraph stating the insight directly.
  - Expand only where structure adds value.
  - Prefer general rules and durable terminology over file-specific implementation detail.

5. **Behaviour Examples**
  - Include at least two concise examples: one positive and one negative or boundary case.
  - Keep examples self-contained.
  - Use repository-derived examples only if they are essential, stable, and shorter than an equivalent standalone example.

6. **Anti-Patterns**
  - List what not to do and why.
  - Derive these directly from the failure mode or confusion uncovered in the session.

7. **Design Decisions**
  - Include this section only when the learning involves a meaningful choice between alternatives.
  - State the chosen approach, the alternative, and the reason for the decision.

## Output Rules

- Write the skill document to `.agents/orchestra/skills/orchestra-<name>/SKILL.md`.
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
- Use tables where they genuinely improve scanability.
- Do not include task lists, implementation steps, status tracking, exhaustive evidence logs, or line-level citations.
- Do not pad the skill with codebase-specific examples that are likely to become stale.
- The finished skill must function as a standalone source of information for a future agent.
- In the final response, confirm the path created and restate the one-sentence learning in plain English.
