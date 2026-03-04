---
agent: orchestrator
description: Perform a merge-readiness review focused on blockers, regressions, and high-risk release issues
---
I'm about to merge my current branch. Read the destination branch from [../config/target-branch.md](../config/target-branch.md), then run a merge-readiness review with one goal: merge safely and quickly.

Focus only on merge-blocking and high-risk findings:
1) Critical regressions in core functionality.
2) Failures in new functionality introduced by this branch.
3) High/critical code risks likely to cause production issues, data loss, security problems, or immediate rework.
4) Missing essentials required to safely release (build/test/release readiness).

Do not:
- Over-polish UX or suggest nice-to-have improvements.
- Report speculative edge cases without clear evidence.
- Spend time on medium/low issues unless they could become high/critical before release.

Before investigating, ensure `ai/planning/issues.md` exists. If it does not, copy from the template at [../templates/issues.template.md](../templates/issues.template.md), then read it and treat unresolved local issues as part of the current review context so we do not re-investigate the same problem repeatedly.

---

## Agent Workflow

Execute this review using the following subagents in sequence.

### Step 1 — information-gatherer: Understand the Changeset

Delegate to `information-gatherer` with this task:

> Run `git diff <target-branch>...HEAD --name-only` to list all changed files. Then run `git diff <target-branch>...HEAD --stat` for a summary. Read key changed files to understand the scope of the changes. Identify:
> - Which features, pages, or user-journeys are touched by these changes.
> - Which PHP classes, controllers, routes, or Twig templates were modified.
> - Any database schema changes or migrations.
> - Any JavaScript or SCSS changes that affect UI behaviour.
>
> Return a structured summary: changed files grouped by area (backend, frontend, DB, tests), a plain-English description of what the branch does, and a list of the **user-facing user-journeys** affected that must be e2e tested.

Use the returned summary as the input context for all subsequent agents.

### Step 2 — code-reviewer: Review Changed Files for Critical Risks

Delegate to `code-reviewer` with this task:

> Review only the files changed in this branch (as identified in Step 1). Focus exclusively on critical and high-severity issues:
> - Security vulnerabilities (OWASP Top 10: injection, broken access control, SSRF, etc.)
> - Data loss or data integrity risks.
> - Broken or missing error handling on critical paths.
> - Logic bugs likely to cause wrong results in production data.
> - Ensure all project coding rules and standards are followed, upholding the highest quality coding practices as defined in the project's coding style guides and preferences.
>

### Step 3 — quality-engineer: Run Automated Tests on Affected Areas

Delegate to `quality-engineer` with this task:

> Using the list of changed files and affected areas from Step 1, run the relevant automated test suites for those areas. Focus on:
> - Unit tests for any changed PHP classes or services.
> - Integration tests for changed controllers or database interactions.
> - Any existing tests that cover the user-facing user-journeys identified in Step 1.
> - DO NOT run unrelated test suites that are not impacted by the changes, to save time.
> - Only run focused tests that provide confidence on the changed areas, never run the entire test suite.
>
> Reference the `run-tests` skill for how to execute the project's Docker-based test runners. Report: which test suites were run, how many passed/failed, and any failures with their error messages. If failures exist, classify each as blocking (critical) or non-blocking.

### Step 4 — manual-tester: E2E Test the Changed User-Journeys

**Only proceed once Steps 2 and 3 are complete.**

Delegate to `manual-tester` with this task, passing the list of affected user-facing user-journeys from Step 1 and any failures from Steps 2–3:

> Using the affected user-journeys identified in Step 1, perform focused e2e browser testing against the local running application. For each user-journey:
> 1. Test the primary happy-path (the feature works as intended).
> 2. Test the most obvious failure path (invalid input, missing required data, unauthorised access where relevant).
> 3. Verify that any UI elements introduced or changed by this branch render correctly and function as expected.
> 4. Report which user-journeys were tested and why, the steps performed and the results (pass/fail).
>
> Reference the `playwright-mcp` skill for application URL and login credentials.
>
> Do **not** explore unrelated areas of the application. Stay strictly within the affected user-journeys.
>
> For each user-journey tested, report: user-journey name, steps performed, result (pass/fail), and any screenshot or console errors captured. Classify each failure as blocking (critical) or non-blocking.

---

## Recording Findings

During and after the agent workflow, record all findings in `ai/planning/issues.md`:
- Do not use a table format. Use a simple markdown structure with clear headings and bullet points.
- Add only new, meaningful issues not already listed.
- If an existing issue is reproduced, update its status/details instead of creating duplicates.
- Keep severity values strictly: `critical`, `high`, `medium`, `low`.
- Mark issues as `fixed` only after verification.

For each issue found, provide:
- Severity: critical / high / medium / low
- Source agent: code-reviewer / quality-engineer / manual-tester
- Reproduction steps
- Expected vs actual behaviour
- Minimal recommended fix

---

## Final Output

Compile results from all agents and return output in this exact structure:

1) Go/No-Go
- One sentence: "Go", "Go with conditions", or "No-Go", with reason.

2) Critical Blockers (if any)
- Only critical items.
- For each: source agent, issue, impact, minimal fix.

3) High-Priority Risks (if any)
- Only high items.
- For each: source agent, issue, release risk, minimal fix.

4) Verified Checks
- Concise checklist of what was actually validated, grouped by agent (code-reviewer, quality-engineer, manual-tester).

5) Local Issue Ledger Updates
- What was added / updated / fixed in `ai/planning/issues.md`.

6) Fastest Path to Merge
- Ordered checklist of the minimum actions required before merge.

If no critical/high issues are found across all agents, respond:
- "No blockers found; safe to merge."
- Include only Verified Checks and a minimal pre-merge checklist.
