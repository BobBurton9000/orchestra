# Issues Ledger

This file tracks all issues found during merge readiness reviews and other investigations. 

## Format Guidelines

- Use markdown structure with clear headings and bullet points (not tables).
- Record findings with: Severity, Source Agent, Description, Steps to Reproduce, Expected vs Actual, and Minimal Fix.
- Severity values: `critical`, `high`, `medium`, `low`.
- Status values: `open`, `fixed`, `verified`.
- Do not create duplicate entries; update existing issues with new findings instead.
- Mark issues as `fixed` only after verification.

---

## Example Issue

### Issue #1: [Brief Title]

**Severity:** high  
**Source Agent:** code-reviewer  
**Status:** open  
**Branch:** main

**Description:**
A clear description of what the issue is and why it matters.

**Reproduction Steps:**
1. Step one
2. Step two
3. Step three

**Expected Behavior:**
What should happen?

**Actual Behavior:**
What actually happened instead?

**Minimal Fix:**
The smallest change required to resolve this issue.

**Notes:**
Any additional context or follow-up actions needed.

---

## Notes on Usage

- **Severity Levels:**
  - `critical`: Blocks merge; causes data loss, security breach, or broken core functionality.
  - `high`: Serious issue; likely to cause production problems or requires rework.
  - `medium`: Should be fixed before release but not blocking.
  - `low`: Nice-to-have improvements; can be addressed in follow-up PR.

- **Source Agents:**
  - `code-reviewer`: Code quality, security, or architectural issues.
  - `quality-engineer`: Test failures or coverage gaps.
  - `manual-tester`: E2E or UI issues caught during testing.
  - `information-gatherer`: Context or missing information that impacts review.

- **Status Progression:**
  - `open` → `fixed` (when developer marks as resolved) → `verified` (when reviewer confirms the fix).

---
