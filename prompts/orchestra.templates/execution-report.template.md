# Execution Report

## Plan Source
- Plan:
  - {{ link or path to the canonical plan document }}
- Story:
  - {{ link or path to the canonical story document }}

## Execution Summary
- {{ concise summary of what was implemented }}

## Completed Chunks

### Chunk {{ n }}: {{ Chunk name }}
- Result:
  - {{ what was completed in this chunk }}
- Completed task units:
  - {{ task or ad hoc unit id }}: {{ result }}
  - {{ task or ad hoc unit id }}: {{ result }}
- Files changed:
  - `{{ path/to/file.ext }}`: {{ why it changed }}
  - `{{ path/to/other-file.ext }}`: {{ why it changed }}
- Code review outcome:
  - {{ review agent or lens }}: {{ pass/fail and short result }}

## Quality Gate Evidence

### Chunk {{ n }}: {{ Chunk name }}
- Initial gate status:
  - Manual user journeys: {{ fail | not applicable | not practical and why }}
  - Integration tests: {{ fail | not applicable | not practical and why }}
  - Unit tests: {{ fail | not applicable | not practical and why }}
- Final gate status:
  - Manual user journeys: {{ pass | not applicable }}
  - Integration tests: {{ pass | not applicable }}
  - Unit tests: {{ pass | not applicable }}
- Independently verified by:
  - {{ validating sub agent }}
  - {{ validating sub agent }}

## Risk Reconciliation

| Risk | Planned mitigation | Execution outcome | Residual risk | Verified by |
| --- | --- | --- | --- | --- |
| {{ concrete risk entry }} | {{ planned safeguard or mitigation }} | {{ how execution addressed it }} | {{ none or concise residual concern }} | {{ applicable sub agents }} |

## Final Operations Evidence

### Integration Testing
- Command:
  - `{{ project-specific automated test command }}`
- Result:
  - {{ pass/fail and relevant evidence }}

### Manual Testing
- Scenario:
  - {{ browser or user-facing verification scenario }}
- Result:
  - {{ pass/fail and relevant evidence }}

## Deviations and Decisions
- {{ decision or deviation }}
- {{ reason }}

## Final Status
- {{ Go | No-Go }}