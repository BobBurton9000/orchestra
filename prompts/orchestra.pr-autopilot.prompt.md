---
name: pr-autopilot
description: Review active PR feedback, make scoped reactive changes, validate them, and respond
argument-hint: "Optional focus: reviewer name, file, or topic"
agent: orchestrator
---

Review all active feedback on the current pull request, make reactive changes where needed, and then respond to the feedback.

Your job is to finish the feedback loop end-to-end, not just inspect comments.

Objectives:
- Identify every currently actionable PR feedback item.
- Decide whether each item needs a code change, a clarification reply, or no change.
- Implement only the smallest correct reactive changes needed.
- Validate changed areas with targeted checks where practical.
- Respond to each actionable item with a concise, reviewer-facing update.

Process:
1. Read the active pull request and gather all actionable feedback.
2. Include:
   - unresolved inline review comments
   - requested changes
   - open general review comments that still need a response
3. Group related feedback by file or concern.
4. For each item, classify it as one of:
   - change required
   - reply only
   - no change needed, with rationale
5. Before editing, read the relevant code and determine the minimum defensible fix.
6. Make only scoped reactive changes that directly address the feedback.
7. Do not introduce unrelated refactors, naming changes, or tidy-ups unless they are strictly necessary to satisfy the feedback.
8. If feedback is unclear, conflicting, or incorrect, do not guess. Prepare a clarification response instead.
9. Run targeted validation for the touched code where feasible.
10. After changes, ensure every actionable feedback item has either:
   - a corresponding code change and reply
   - a reply explaining why no code change was made
   - a reply asking for clarification
11. If direct PR thread posting is available, post the replies on the live threads before finishing.
12. Only fall back to drafted replies when direct posting is unavailable.

Reply style:
- Be concise, factual, and reviewer-facing.
- Mention what changed and why.
- If no change was made, explain the reasoning clearly.
- If validation was run, mention the relevant check briefly.
- If you cannot post directly to the PR, draft ready-to-send replies grouped by thread.

Output requirements:
- Start with a short triage summary:
  - addressed
  - replied without code change
  - blocked or needs clarification
- Then list the concrete changes made.
- Then provide the reply text for each feedback item if direct posting is not available.
- End with any remaining blockers or questions for reviewers.

Guardrails:
- Preserve user work already present in the branch.
- Avoid scope creep.
- Do not stop after making code changes; complete the response step as well.
- Do not treat drafted replies as sufficient when you can post directly to the active PR; the feedback loop is not complete until the live threads have been answered.
- Prefer correctness and traceability over speed.