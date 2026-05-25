---
agent: orchestrator
description: Refresh Orchestra-generated skills by reviewing each one for accuracy and updating its content
---
# Goal: Refresh Skills
Keep every skill document accurate and useful by reviewing each one against the current state of the codebase.

## Steps
1. List the contents of `.agents/orchestra/skills/` to find all Orchestra skill folders prefixed with `orchestra-`. Ignore `.gitkeep` and any non-directory entries.
2. For each skill folder discovered, launch a **separate subagent** with the following instruction:

   > Read the SKILL.md file at `.agents/orchestra/skills/orchestra-<name>/SKILL.md`.
   >
   > Review the skill for accuracy against the current codebase:
   > - Verify every file path, class name, method name, and namespace referenced in the document still exists.
   > - Check that described behaviour still matches the real implementation.
   > - Remove or correct any references that are outdated, renamed, moved, or deleted.
   > - Add any important new cases, classes, or patterns that belong under this skill's scope but are missing.
   > - Do not change the structure or sections of the document unless a section is factually wrong.
   > - Do not invent examples; only include things you have confirmed in the codebase.
   >
   > When the review is complete, overwrite `.agents/orchestra/skills/orchestra-<name>/SKILL.md` with the updated content.
   > Return a single summary line: `<name>: <what changed, or "no changes required">`.

3. After all subagents have completed, print a final summary table:

| Skill       | Outcome       |
| ----------- | ------------- |
| {{ skill }} | {{ outcome }} |
