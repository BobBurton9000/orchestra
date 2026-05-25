---
agent: agent
description: Convert a source document or other supplied information into a feature name and a structured set of Gherkin statements for the requested topic
name: gherkinify
argument-hint: "describe the topic and attach or reference the source material"
---
# Convert Source Material into Gherkin
Read the supplied document or source information and extract only the behaviour relevant to the requested topic.

Do not invent behaviour that is not supported by the source.
Do not explain your reasoning.
Do not include summaries, assumptions, gaps, notes, or commentary.

## Rules

1. Output only two things:
   - the feature being discussed
   - a structured set of Gherkin statements derived from the source
2. Write one `Feature:` for the requested topic.
3. Write as many `Scenario:` or `Scenario Outline:` blocks as needed to cover the supported behaviour.
4. Every `Scenario:` or `Scenario Outline:` block must include at least one `Given`, one `When`, and one `Then`. Do not omit any of these steps.
5. `Background:` is optional and may only be used when multiple scenarios share the same setup, but it does not replace the requirement for each scenario to include its own `Given`, `When`, and `Then` steps.
6. `And` and `But` may be used only in addition to `Given`, `When`, and `Then`, never instead of them.
7. Keep the statements observable, specific, and testable.
8. Ignore source content that is outside the requested topic.
9. If the source is incomplete, use only the behaviour that is clearly supported.

## Output format

Feature: <feature being discussed>

Background: <only when needed>

Scenario: <first behaviour>
Given ...
When ...
Then ...

Scenario: <next behaviour>
Given ...
When ...
Then ...
