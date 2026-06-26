---
agent: orchestrator
name: review-reuse
description: Review outstanding git changes for code that could be simplified by re-using existing code and architecture instead of introducing duplication, and write prioritised findings to a branch-specific markdown file under `.temp/<branch-name>/`.
argument-hint: "[optional: specific file paths or areas to focus on]"
---
# Goal
Review the outstanding git changes for code that could be simplified by re-using EXISTING code and architecture instead of introducing duplication, then write review findings only to `.temp/<branch-name>/reuse-review-<timestamp>.md`.

# Variables
- `<focus>`: Optional file paths or areas prioritised by the user. May be empty.
- `<branch-name>`: Resolve the current branch using [branch-name](snippets/branch-name.md), then normalise it by replacing `/` and whitespace with `-` so the result is safe to use as one directory name.
- `<timestamp>`: Current UTC datetime in `YYYYMMDD-HHMMSS` format.
- `<output-dir>`: `.temp/<branch-name>/`
- `<output-path>`: `.temp/<branch-name>/reuse-review-<timestamp>.md`

# Invocation Pattern
This prompt is executed with optional focus paths.

- Example: `/review-reuse` (review all outstanding changes)
- Example: `/review-reuse app/client/CategoryPicker.ts app/client/pages/ItemSupplierPicker.ts` (prioritise specific paths)

Inference rules:
1. If `<focus>` is provided, examine all outstanding changes but prioritise findings in the specified paths.
2. Resolve `<branch-name>` from the current git branch, then normalise it before using `<output-dir>` or `<output-path>`.
3. Generate `<timestamp>` at execution time.

# Required Outcomes
1. `<output-path>` exists after execution.
2. The only permitted workspace edits are creating `<output-dir>` if needed and creating `<output-path>`.
3. No code, test, configuration, or documentation files outside `<output-path>` are modified.
4. Every finding references concrete file paths, line numbers, and the existing code that could be re-used instead.
5. Findings are prioritised by re-use impact: High, Medium, Low.
6. If no re-use opportunities exist, the report states that explicitly rather than forcing weak findings.
7. The final chat response reports only completion status and the output file path.

# Re-use Detection Rules
1. Only suggest re-use of code that ALREADY EXISTS in the codebase. Do not propose creating new abstractions, base classes, or shared modules.
2. Look for these patterns:
   - Shared base classes, mixins, or utility modules that already encapsulate the duplicated pattern.
   - Identical or near-identical method bodies across files that could call an existing shared method.
   - Repeated structural patterns (event binding/teardown, option enumeration, create-row visibility logic, filter logic, position delegation) that already have a canonical home.
   - New types or interfaces that duplicate or overlap with existing ones.
   - Logic that was extracted to a shared helper but where one caller still carries the old inline copy.
3. Ignore trivial duplication such as importing the same symbol in two files or identical one-line property assignments.
4. Prefer the simplest change that eliminates duplication. Do not propose large-scale restructuring.
5. Consider the project's existing architecture

# Severity Rules
- High: the duplicated code is substantial, introduces real behavioural risk, and re-use is straightforward.
- Medium: the duplication is meaningful but the re-use would require moderate refactoring or the risk is lower.
- Low: the duplication is minor or the re-use would add complexity rather than remove it.

# Report Document Structure
Write `<output-path>` as markdown with these sections in this order:
1. `## Re-use Review: {branch-name}`
2. `**Scope**`
3. `### Findings by Impact`
4. `### Summary`

Additional report rules:
1. Under **Scope**, list the changed files examined and, if `<focus>` was provided, which paths were prioritised.
2. Under **Findings by Impact**, use subsections ordered High, Medium, Low.
3. For each finding include:
   - **Impact**: High / Medium / Low
   - **Title**: short descriptive title
   - **Changed code**: `file:line` — what was added or modified
   - **Existing code**: `file:line` — what already exists that could be re-used
   - **Simplification**: how to re-use instead, in one or two sentences
   - **Risk of change**: how invasive the refactoring would be
4. Under **Summary**, report a count: "N findings (H high, M medium, L low)" or "No re-use opportunities found."
5. Keep the report concise and actionable. Do not pad with generic advice.

# Steps
1. Resolve and normalise `<branch-name>`.
2. Generate `<timestamp>` and compute `<output-path>`.
3. Ensure `<output-dir>` exists.
4. Collect outstanding changes.
   - Run `git diff` and `git diff --cached` to capture unstaged and staged changes.
   - Run `git status --short` to identify untracked new files.
   - Read each changed or new file in full — not just the diff hunks — for complete context.
5. Identify re-use opportunities.
   - For each changed or new file, search the codebase for existing abstractions, shared methods, utility functions, interfaces, or structural patterns that already solve the same problem.
   - Compare method bodies, type definitions, and structural patterns across the changed files and the broader codebase.
   - Pay special attention to logic that was recently extracted to a shared helper but where callers still carry the old inline version.
   - Record concrete file paths and line numbers for both the duplicated code and the existing code that could replace it.
6. Classify findings by impact using the Severity Rules.
7. Write the report to `<output-path>` following the Report Document Structure.
8. Return only:
   - `Status: Completed` or `Status: ERROR`
   - `Output: <output-path>`

# Response To User
Status: <Completed|ERROR>
Output: <output-path>