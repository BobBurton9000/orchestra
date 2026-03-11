---
agent: orchestrator
description: Verify attached or requested .feature files are true by inventorying scenarios with information-gatherer and batching them to tester agents for pass/fail reporting
name: orchestra.verify-features
argument-hint: "Optionally describe which .feature files, folders, or intent to verify; otherwise attach .feature files or omit arguments to verify all .feature files"
---
# Goal
Verify that one or more `.feature` files describe behaviour that is currently true in the running system or repository.

When the user attaches one or more `.feature` files, treat those attachments as the verification scope unless the invocation text narrows or expands that scope explicitly.

When the user provides no usable scope or intent, verify every `.feature` file in the repository.

This prompt is a verification workflow. It must gather scenario inventories first, create an internal scenario todo ledger, delegate scenario batches to tester agents, and finish with a report that identifies which scenarios passed and which scenarios failed.

# Invocation Pattern
This prompt may be executed with optional free-form scope text and optional attached `.feature` files.

- Example structure with attached files: `<this-command>`
- Example structure with an explicit file: `<this-command> ./.gherkin/auth/login.feature`
- Example structure with a directory: `<this-command> ./.gherkin/auth`
- Example structure with intent text: `<this-command> verify checkout related feature files`

Inference rules:
1. If one or more `.feature` files are attached, treat those attachments as the canonical verification scope unless the invocation text explicitly names a different scope.
2. If invocation text names one or more `.feature` files, directories, routes, workflows, or product areas, resolve the narrowest matching `.feature` files from repository context.
3. If invocation text provides no usable scope and there are no attached `.feature` files, verify every `.feature` file in the repository.
4. If no `.feature` files can be resolved from the requested scope, return `ERROR: no .feature files found for verification`.

# Required Outcomes
1. The verification scope was resolved to one or more concrete `.feature` files.
2. Every directory that owns scoped `.feature` files was investigated by batched `information-gatherer` sub agent calls before tester delegation.
3. Each `information-gatherer` call returned the list of `Scenario:` and `Scenario Outline:` names found in its assigned directory or file set.
4. Every resolved scenario name was added to the internal todo list using the `todo` tool before testing started.
5. Scenario verification work was dispatched to tester agents in batches rather than as one monolithic request.
6. Each scenario was assigned to the most appropriate tester agent available for its verification surface. Prefer `tester.browser` for UI and end-to-end flows, and `tester.cli` for CLI-visible or non-UI verification where that is sufficient.
7. The final report identifies, at minimum, which scenarios passed and which scenarios failed, grouped by `.feature` file.
8. If a scenario could not be verified because the environment is unavailable or evidence is insufficient, record it explicitly as blocked instead of claiming it passed.
9. Do not modify the `.feature` files during verification.

# Verification Rules
1. Treat each `Scenario:` or `Scenario Outline:` block as an independent verification item.
2. Use batched `information-gatherer` calls to inspect directories when verifying all `.feature` files. Split work across directories or other sensible file groups so the gatherer returns manageable scenario inventories.
3. Require each `information-gatherer` result to include, for every discovered scenario, the repository-relative `.feature` path and the exact scenario name without the `Scenario:` or `Scenario Outline:` prefix.
4. After inventorying scenarios, add every scenario to the internal todo list using the `todo` tool with a status that can be updated as testing progresses.
5. Batch scenarios for tester agents by verification surface and ownership. Do not mix obviously UI/browser workflows into the same batch as purely CLI-visible checks when separate tester agents would be more appropriate.
6. Tester agents must receive the `.feature` file path, scenario names, any relevant setup assumptions, and the requirement to report pass, fail, or blocked for each scenario with concise evidence.
7. If a scenario batch produces failures or blocked results, continue testing the remaining queued scenarios unless the entire environment is unusable.
8. Do not collapse multiple scenarios into one verdict. Every scenario needs its own result.
9. Do not claim a scenario passed based only on reading the Gherkin text. Require tester-agent evidence.

# Steps
1. Resolve the verification scope from attachments and invocation text. If the scope is empty after resolution, fall back to every `.feature` file in the repository. If none exist, return `ERROR: no .feature files found for verification`.
2. Partition the resolved `.feature` files into sensible directory or ownership batches for `information-gatherer`.
3. Batch call `information-gatherer` to inspect each batch and return a normalized scenario inventory containing:
   - repository-relative `.feature` file path
   - feature title when present
   - each `Scenario:` name
   - each `Scenario Outline:` name
4. Merge the gathered inventories into one canonical scenario ledger and de-duplicate exact file-plus-scenario pairs.
5. Add every scenario from that ledger to the internal todo list using the `todo` tool before any tester delegation begins.
6. Classify each scenario by likely verification surface:
   - `tester.browser` for UI, browser, navigation, form, workflow, or end-to-end behaviour
   - `tester.cli` for CLI-visible, service-visible, API-visible, or non-UI verification that can be established without a browser
   - if uncertain, prefer the tester agent most likely to observe the behaviour directly and note the assumption
7. Batch scenarios into tester work packets that stay small enough for clear evidence and retries.
8. Delegate each packet to the selected tester agent and require a per-scenario result of `passed`, `failed`, or `blocked` plus concise evidence.
9. Update the internal todo list as tester results arrive.
10. Compile the final verification report grouped by `.feature` file, with scenario-level outcomes and overall counts.
11. If any scenarios failed or were blocked, return the report with those scenarios called out explicitly. Do not rewrite the `.feature` files as part of this prompt.

# Response To User
```text
Verification scope: <attached files | requested scope | all .feature files>
Feature files checked: <number>
Scenarios discovered: <number>
Scenarios passed: <number>
Scenarios failed: <number>
Scenarios blocked: <number>

Passed
- <path> :: <scenario name>

Failed
- <path> :: <scenario name> :: <concise failure note>

Blocked
- <path> :: <scenario name> :: <concise blocker note>

Final status: <Passed|Failed|Blocked|ERROR>
```