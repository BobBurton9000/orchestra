# Execution Report

## Plan Source
- Plan:
  - {{ link or path to the canonical plan document }}
- Gherkin:
  - {{ link or path to the canonical gherkin document }}

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

## Gherkin Verification Coverage

- Coverage target:
  - 100% of statements in `.agents/orchestra/<branch-name>/gherkin.md`, including `Related Gherkin`
- Verified statements:
  - {{ verified_count }}/{{ total_count }}
- Coverage status:
  - {{ pass | fail }}

| Source section | File path | Scenario | Statement | Manual testing agent | Verification result | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| {{ Changed Files or Related Gherkin }} | {{ .gherkin/path.feature }} | {{ scenario name }} | {{ exact Given/When/Then/And/But statement }} | {{ tester.browser or other manual testing agent }} | {{ true | false | blocked }} | {{ concise proof or observation }} |

## Gherkin Blocker Resolution

| Statement | Initial failure or block | Resolution work | Final evidence |
| --- | --- | --- | --- |
| {{ exact statement text }} | {{ why it initially failed or was blocked }} | {{ fix, environment change, or follow-up verification performed }} | {{ proof that it is now true }} |

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

### Gherkin Truth Status
- Result:
  - {{ all statements true }}
- Resolved blockers:
  - {{ none or exact statements that initially failed/blocked and were later resolved }}

## Deviations and Decisions
- {{ decision or deviation }}
- {{ reason }}

## Final Status
- {{ Go }}