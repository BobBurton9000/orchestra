---
agent: orchestrator
name: investigate-bug-claim
description: Investigate a bug-analyser claim against the current repository, decide whether the claim is approved, refuted, or inconclusive, and write the report to a branch-specific markdown file under `.temp/<branch-name>/`.
argument-hint: paste the analyser claim, including title, severity, and rationale
---
# Goal
Investigate a bug-analyser claim against the current repository, determine whether the claim is approved, refuted, or inconclusive based on repository evidence, and write the investigation report only to `.temp/<branch-name>/bug-claim-<claim-slug>.md`.

# Variables
- `{{ claim }}`: The full bug-analyser claim text supplied by the user. This may include a title, severity, rationale, affected paths, and behavioural explanation.
- `<branch-name>`: Resolve the current branch using `git branch --show-current`, then normalize it by replacing `/` and whitespace with `-` so the result is safe to use as one directory name.
- `<claim-slug>`: Derive a concise deterministic slug from the claim title or, if no clear title exists, from the first meaningful line of `{{ claim }}`. Lowercase it, replace whitespace and path separators with `-`, remove characters that are unsafe for filenames, collapse repeated `-`, trim leading and trailing `-`, and keep it short but recognizable.
- `<output-dir>`: `.temp/<branch-name>/`
- `<output-path>`: `.temp/<branch-name>/bug-claim-<claim-slug>.md`

# Invocation Pattern
This prompt is executed with a required analyser claim.

- Example: `/investigate-bug-claim The settings modal loses unsaved form state when closing via Escape...`
- Example: `<this-command> <paste bug analyser claim here>`

Inference rules:
1. Treat the full invocation text as `{{ claim }}`.
2. If `{{ claim }}` is empty, return `ERROR: no bug claim provided`.
3. Resolve `<branch-name>` from the current git branch, then normalize it before using `<output-dir>` or `<output-path>`.
4. Derive `<claim-slug>` from `{{ claim }}` before using `<output-path>`.
5. If slug generation would be empty after normalization, use `claim` as the fallback slug.
6. If `<output-path>` already exists, read it first and update it in place so earlier investigation notes remain aligned with the latest evidence.

# Required Outcomes
1. `<output-path>` exists after execution.
2. The only permitted workspace edits are creating `<output-dir>` if needed and creating or updating `<output-path>`.
3. No code, test, configuration, or documentation files outside `<output-path>` are modified.
4. The investigation is repository-grounded and cites concrete evidence such as code paths, symbols, control flow, tests, commands, or observed outputs.
5. Runtime behaviour is observed with a testing agent when the claim depends on user-visible flow, integration behaviour, or other execution-time effects.
6. A browser-testing agent is preferred for browser-reachable UI claims so the investigation can observe live behaviour and gather console, network, or interaction evidence when feasible.
7. When browser runtime validation is not applicable, use the most relevant testing agent available to reproduce the behaviour or gather logs.
8. The claim receives exactly one verdict: `Approved`, `Refuted`, or `Inconclusive`.
9. `Approved` means the repository evidence supports the reported bug as a real issue.
10. `Refuted` means the repository evidence shows the reported bug does not hold as stated.
11. `Inconclusive` means the available repository evidence is insufficient to decide with confidence, and the missing evidence is stated explicitly.
12. The report distinguishes confirmed facts from assumptions and calls out any missing runtime validation.
13. The final chat response reports only completion status, verdict, and the output file path.

# Investigation Rules
1. Do not implement a fix.
2. Do not edit product code.
3. Do not open or submit a pull request review.
4. Prefer the smallest set of repository reads and checks that can prove or disprove the claim.
5. If the claim depends on runtime behaviour that cannot be validated from code alone, use a testing agent to reproduce or observe it before relying on static analysis alone.
6. Prefer a browser-testing agent when the claim is about browser-visible behaviour, user interaction flow, tab state, rendering, loading, console errors, or network activity and the application can be exercised in a browser.
7. When a browser-testing agent is not applicable, use the most relevant testing agent available to run the narrowest feasible command, test, or scenario and capture the result.
8. Gather logs when feasible, including browser console output, network failures, terminal output, or test logs, and include them as evidence.
9. If no feasible validation exists, explain precisely what evidence is missing and use `Inconclusive` rather than guessing.
10. If the analyser claim overstates the issue, record the narrower true statement instead of accepting the broader claim.

# Agent Capability Resolution
This prompt delegates work by capability, not by agent name. When resolving which agent to use for a capability, pick the narrowest available agent that fits the work.

| Capability needed | Must be able to | Typical agent examples |
|---|---|---|
| Research | Search codebase, read files, compile findings into a report without writing code or making judgements | `information-gatherer` |
| Browser testing | Navigate a running application, reproduce UI flows, capture console and network evidence | `tester.browser` |
| CLI testing | Run commands, execute tests, capture terminal output | `tester.cli` |

Dispatch to whichever available agent best fulfils the capability. The agent landscape varies across projects; adapt accordingly.

# Report Document Structure
Write `<output-path>` as markdown with these sections in this order:
1. `## Bug Claim Investigation: {Title}`
2. `**Verdict**` with exactly one of: `Approved`, `Refuted`, `Inconclusive`
3. `**Claim Summary**`
4. `**Severity**`
5. `**Investigation Scope**`
6. `**Evidence**`
7. `**Reasoning**`
8. `**Gaps / Follow-up Checks**`
9. `**Conclusion**`

Additional report rules:
1. Under `Evidence`, use short bullet points with concrete file paths, symbols, line references, commands, observed outputs, or gathered logs.
2. Under `Reasoning`, explain why the evidence proves or disproves the claim.
3. Under `Gaps / Follow-up Checks`, state what remains unverified and what would close the gap.
4. Under `Conclusion`, state the verdict in one short paragraph and note the practical impact.
5. Keep the report concise, but specific enough that another engineer can audit the verdict without redoing the full investigation.

# Steps
1. Validate input. If `{{ claim }}` is empty, return `ERROR: no bug claim provided`.
2. Resolve and normalize `<branch-name>`.
3. Derive `<claim-slug>` from `{{ claim }}`.
4. Ensure `<output-dir>` exists.
5. If `<output-path>` already exists, read it in full before investigating so refinements preserve prior evidence unless the user changes the claim.
6. Extract the working claim details from `{{ claim }}`:
   - suspected bug title
   - stated severity
   - affected files, functions, or components when provided
   - claimed failure mechanism
   - claimed user or system impact
7. Start repository-grounded investigation.
   - Identify the narrowest owning code path for the claimed behaviour.
   - Use a research agent for read-only discovery of the controlling implementation, any nearby tests, and likely runtime entry points.
   - If the claim spans separate areas such as UI trigger flow, data loading, and tests, launch 2 or 3 research agents in parallel, one per area.
   - Decide whether runtime observation is required to reach a defensible verdict.
   - If the claim is browser-reachable, use a browser-testing agent to reproduce the scenario, observe behaviour, and gather logs when feasible.
   - If the claim is not browser-reachable, use the most relevant testing agent to run a narrow reproduction or gather execution logs.
8. Evaluate the claim against the evidence.
   - Confirm whether the reported control flow, state transition, guard, or missing condition actually exists.
   - Check for contradictory code paths, compensating behaviour, or tests that invalidate the claim.
   - Use runtime observations and gathered logs to confirm, refute, or narrow the claim when static inspection alone is insufficient.
9. Assign the verdict.
   - Use `Approved` only when the evidence supports the reported bug.
   - Use `Refuted` when the evidence contradicts the claim or shows the behaviour is already handled.
   - Use `Inconclusive` when the remaining uncertainty is real and explicitly described.
10. Draft the report using the required structure, including concrete evidence, reasoning, missing checks, and practical impact.
11. Write or update `<output-path>`.
12. Return only:
    - `Status: Completed` or `Status: ERROR`
    - `Verdict: <Approved|Refuted|Inconclusive>`
    - `Output: <output-path>`

# Response To User
Status: <Completed|ERROR>
Verdict: <Approved|Refuted|Inconclusive>
Output: <output-path>