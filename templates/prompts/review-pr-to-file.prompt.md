---
agent: orchestrator
name: review-pr-to-file
description: Review a pull request diff using GitHub CLI, do not modify code or post PR comments, and write severity-prioritised findings to a branch-specific markdown file under `.temp/<branch-name>/`.
argument-hint: PR URL (e.g., https://github.com/owner/repo/pull/123)
---
# Goal
Perform a repository-grounded code review of the target pull request using GitHub CLI diff data, then write review feedback only to `.temp/<branch-name>/<output-file>`.

# Variables
<pr-url> = {{PR_URL}}
<owner> = Derived from parsing <pr-url> (e.g., https://github.com/rld-engineering/intelligentcontract-monorepo/pull/123 → owner = rld-engineering)
<repo> = Derived from parsing <pr-url> (e.g., https://github.com/rld-engineering/intelligentcontract-monorepo/pull/123 → repo = intelligentcontract-monorepo)
<pr-number> = Derived from parsing <pr-url> (e.g., https://github.com/owner/repo/pull/123 → pr-number = 123)
<branch-name> = Resolve the current branch using [branch-name](snippets/branch-name.md), then normalize it by replacing `/` and whitespace with `-` so the result is safe to use as one directory name.
<output-file> = {{OUTPUT_FILENAME_MD}} (optional - auto-generated as `pr-{pr-number}-{datetime}-review.md` if not provided)
<output-dir> = `.temp/<branch-name>/`
<output-path> = `.temp/<branch-name>/<output-file>`

# Invocation Pattern
This prompt is executed with just a PR URL.

Inference rules:
1. If <pr-url> is present, parse it to extract <owner>, <repo>, and <pr-number>.
   - URL format: `https://github.com/{owner}/{repo}/pull/{pr-number}`
   - Example: `https://github.com/rld-engineering/intelligentcontract-monorepo/pull/1235`
     → owner = rld-engineering
     → repo = intelligentcontract-monorepo
     → pr-number = 1235
2. If <pr-url> is missing, return ERROR: no pull request URL provided.
3. If <owner> or <repo> cannot be parsed from <pr-url>, return ERROR: invalid PR URL format.
4. Resolve <branch-name> from the current git branch, then normalize it before using <output-dir> or <output-path>.
5. If <output-file> is not provided, auto-generate it as `pr-{pr-number}-{datetime}-review.md` where datetime is UTC in format YYYYMMDD-HHMMSS.
6. <output-file> must be a markdown filename only. If it includes directory separators, return ERROR: output file must be a filename only.

# Required Outcomes
1. The pull request and its diff were retrieved using GitHub CLI.
2. No code files were edited.
3. No pull request comments, review comments, or review submissions were posted.
4. Exactly one new markdown file was created at <output-path>.
5. Review findings were prioritised by severity: Critical, High, Medium, Low.
6. Every finding included concrete file and line references.
7. Residual test gaps were captured explicitly.
8. If no actionable findings exist, the file states that explicitly and still documents residual risks and test gaps.
9. The final chat response only reports completion status and the output file path.

# Severity Rules
- Critical: release-blocking correctness, security, integrity, or data-loss risk.
- High: significant correctness, reliability, or integration risk.
- Medium: meaningful maintainability or behavioural risk that is not release-blocking.
- Low: minor risk, clarity issue, or non-blocking concern.

# Constraints
1. Do not post comments to GitHub.
2. Do not submit a PR review event.
3. Do not edit, create, delete, or rename any code or test files.
4. Do not run fix-up commits.
5. Write feedback only into <output-path>.

# Steps
1. Resolve PR context.
   1. Resolve <branch-name> using [branch-name](snippets/branch-name.md) and normalize it before using <output-dir> or <output-path>.
   1. Use GitHub CLI to resolve the PR from <pr-url> in <owner>/<repo>.
   2. Retrieve files changed, patch hunks, and relevant metadata required for review.
2. Build review evidence set.
   1. Inspect the diff and changed-file context.
   2. Identify defects, behavioural regressions, risk patterns, and missing validation.
   3. Record concrete file and line evidence for each claim.
3. Classify findings.
   1. Assign severity using the Severity Rules.
   2. Order findings from highest to lowest severity.
   3. Exclude style-only nits unless they represent a real risk.
4. Capture residual testing gaps.
   1. Identify missing or weak tests implied by the changed behaviour.
   2. Record what remains unverified after diff-only review.
5. Create output file in the branch-specific orchestra directory.
   1. Ensure <output-dir> exists.
   2. Create <output-path> as a new markdown file in <output-dir>.
   2. Write the following sections in order:
      1. Title
      2. Scope
      3. Findings by Severity
      4. Residual Test Gaps
      5. Overall Risk Summary
   3. Under Findings by Severity, use subsections in this order:
      1. Critical
      2. High
      3. Medium
      4. Low
   4. For each finding include:
      1. Severity
      2. Short title
      3. Why this is a risk
      4. Evidence with file and line references
      5. Suggested verification steps
6. Final response.
   1. Return only:
      1. Status: Completed or ERROR
   2. Output: <output-path>

# Response To User
Status: <Completed|ERROR>
Output: <output-path>
