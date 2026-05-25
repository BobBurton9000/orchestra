# Manual Testing Instructions

## Goal
Use manual testing agents to independently verify that every Gherkin statement in `.orchestra/<branch-name>/gherkin.md` is true before stage 5 can finish.

## Required Rules

1. Treat every individual `Given`, `When`, `Then`, `And`, and `But` statement in `.orchestra/<branch-name>/gherkin.md` as a separate verification item.
2. Include statements from both `Changed Files` and `Related Gherkin`.
3. Delegate each verification item to an appropriate manual testing agent. Prefer `tester.browser` for UI and end-to-end workflow checks.
4. Record the exact statement, the scenario exercised, the validating agent, and the observed result.
5. A statement counts as complete only when the testing agent independently confirms it is true based on observed behaviour.
6. If a statement is false or blocked, return that evidence to the execute stage and keep working until it is true.
7. Stage 5 cannot finish with partial coverage. The required target is 100% of Gherkin statements verified.

## Minimum Evidence

- Source section in `gherkin.md`
- Repository-relative Gherkin file path
- Scenario name
- Exact statement text
- Manual testing agent used
- Result: `true`, `false`, or `blocked`
- Short evidence note describing what was observed
