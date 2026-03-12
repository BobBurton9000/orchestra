---
agent: orchestrator
name: orchestra.review.pr-to-file
description: Review a pull request diff via GitHub MCP, do not modify code or post PR comments, and write severity-prioritised findings to a new markdown file at project root.
argument-hint: PR URL plus owner/repo plus output markdown filename
---

# Goal
Perform a repository-grounded code review of the target pull request using GitHub MCP diff data, then write review feedback only to a new markdown file at the project root.

# Variables
<pr-url> = {{PR_URL}}
<owner> = {{OWNER}}
<repo> = {{REPO}}
<output-file> = {{OUTPUT_FILENAME_MD}}

# Invocation Pattern
This prompt is executed with a PR URL and explicit repository coordinates.

Inference rules:
1. If <pr-url> is present, treat it as canonical review target.
2. If <pr-url> is missing, return ERROR: no pull request URL provided.
3. If owner or repo is missing, return ERROR: owner/repo not provided.
4. If <output-file> is missing, return ERROR: output filename not provided.
5. <output-file> must be a markdown filename at project root only. If it includes directory separators, return ERROR: output file must be at project root.

# Required Outcomes
1. The pull request and its diff were retrieved using GitHub MCP tooling.
2. No code files were edited.
3. No pull request comments, review comments, or review submissions were posted.
4. Exactly one new markdown file was created at project root with filename <output-file>.
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
5. Write feedback only into the new root-level markdown output file.

# Steps
1. Resolve PR context.
   1. Use GitHub MCP to resolve the PR from <pr-url> in <owner>/<repo>.
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
5. Create output file at project root.
   1. Create <output-file> as a new markdown file at project root.
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
      2. Output: <output-file>

# Response To User
Status: <Completed|ERROR>
Output: <output-file>
