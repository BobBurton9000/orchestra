# Execution Report

## Source Artifacts
- Task:
  - {{ path to .agents/orchestra/<branch-name>/task.md }}
- Research:
  - {{ path to research document }}
  - {{ path to research document }}
- Plan:
  - {{ path to .agents/orchestra/<branch-name>/plan.md }}
- Branch Gherkin:
  - {{ path to .agents/orchestra/<branch-name>/gherkin.feature or None }}
- Living Gherkin targets:
  - {{ path under project-root .gherkin/ or None }}

## Operating Rules
- This report is append-only.
- Add a new journal entry before and after each meaningful delegation, review cycle, validation run, blocker-resolution attempt, and scope decision.
- Do not rewrite or delete earlier entries.

## Chronological Journal

### Entry {{ 001 }}: {{ short title }}
- Time:
  - {{ timestamp or relative sequence marker }}
- Type:
  - {{ kickoff | delegation-start | delegation-result | validation | blocker | decision | scope-guard | gherkin-sync | completion }}
- Related plan tasks:
  - {{ task id or task name }}
- Summary:
  - {{ what happened }}
- Evidence:
  - {{ command, file change, review finding, or observation }}
- Outcome:
  - {{ result of this step }}
- Next action:
  - {{ what happens next }}

### Entry {{ 002 }}: {{ short title }}
- Time:
  - {{ timestamp or relative sequence marker }}
- Type:
  - {{ kickoff | delegation-start | delegation-result | validation | blocker | decision | scope-guard | gherkin-sync | completion }}
- Related plan tasks:
  - {{ task id or task name }}
- Summary:
  - {{ what happened }}
- Evidence:
  - {{ command, file change, review finding, or observation }}
- Outcome:
  - {{ result of this step }}
- Next action:
  - {{ what happens next }}

## Validation Ledger

| Validation type | Scope | Command or scenario | Result | Evidence |
| --- | --- | --- | --- | --- |
| {{ unit test | integration test | manual QA | browser test | linter | build }} | {{ touched area }} | {{ exact command or scenario }} | {{ pass | fail | blocked | not applicable }} | {{ concise evidence }} |

## Review and Scope Outcomes

| Source | Finding or decision | In scope | Action taken | Evidence |
| --- | --- | --- | --- | --- |
| {{ code-review agent | scope-guard | reviewer }} | {{ finding or decision }} | {{ yes | no }} | {{ fix | undo | defer | no action }} | {{ concise evidence }} |

## Gherkin Integration
- Branch gherkin present:
  - {{ yes | no }}
- Living base updated:
  - {{ yes | no }}
- Files updated under `.gherkin/`:
  - {{ path }}
  - {{ path }}
- Notes:
  - {{ what changed or why no change was needed }}

## Blockers and Resolutions

| Blocker | Detection point | Resolution attempt | Current state | Evidence |
| --- | --- | --- | --- | --- |
| {{ concrete blocker }} | {{ where it surfaced }} | {{ what was tried }} | {{ resolved | unresolved hard-stop }} | {{ concise evidence }} |

## Changed Files
- `{{ path/to/file.ext }}`: {{ why it changed }}
- `{{ path/to/file.ext }}`: {{ why it changed }}

## Final Status
- Result:
  - {{ Go | Blocked }}
- Summary:
  - {{ concise outcome }}
- Residual follow-up:
  - {{ None or concise follow-up item }}