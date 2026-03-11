---
agent: orchestrator
description: Index a requested uncovered application area into the Playwright-grounded Gherkin tree without duplicating existing feature coverage
name: orchestra.index
argument-hint: "The application area, route, or workflow to investigate and index"
---

# Goal
Use Playwright to inspect the current application behaviour for the requested area and extend the structured Gherkin tree under `./.gherkin`.

The Gherkin tree must follow [source-like-gherkin](orchestra.snippets/source-like-gherkin.md).

The generated feature content must contain only plain Gherkin. Do not write prose, notes, summaries, commentary, or Markdown markup inside the created feature files.

This prompt is not a one-time bootstrap. It should be used whenever a specific application area has not been indexed yet.

# Invocation Pattern
This prompt is executed with a required application area, route, feature name, or workflow description.

- Example structure with a named area: `/orchestra.index login page`
- Example structure with a feature area: `<this-command> checkout`
- Example structure with a route: `<this-command> /settings/profile`
- Example structure with a workflow: `<this-command> user sign-in and password reset`

Inference rules:
1. Treat the full invocation text as the requested investigation scope.
2. If the invocation includes a route or URL path, prioritise that entry point during browser exploration.
3. If the invocation names a business workflow, follow the smallest realistic browser path that exercises that workflow.
4. If no scope is provided, return `ERROR: no application area provided`.

# Required Outcomes
1. The requested scope was investigated using Playwright against the current application.
2. The target directory `./.gherkin` exists after execution.
3. One or more `.feature` files were created or updated under `./.gherkin` using a code-source-like folder layout derived from the investigated topic.
4. Every created or updated feature file contains only valid Gherkin constructs such as `Feature:`, `Background:`, `Scenario:`, `Scenario Outline:`, `Given`, `When`, `Then`, `And`, and `But`.
5. No created or updated file duplicates an existing scenario when the behaviour is already documented with materially equivalent steps and outcome.
6. Newly captured behaviour for the requested area is grouped into the narrowest sensible topic folder rather than appended into a broad catch-all file.
7. The created or updated `.feature` files remain plain Gherkin without Markdown links or other non-Gherkin markup.
8. If the application cannot be reached, authenticated, or exercised far enough to observe behaviour, the prompt returns a concrete error instead of inventing scenarios.

# Indexing Rules
Follow [source-like-gherkin](orchestra.snippets/source-like-gherkin.md).

Additional indexing rules:
1. Capture only observable behaviour that was seen directly in the browser session.
2. Do not infer server-side rules, edge cases, or validation paths that were not demonstrated.
3. If an existing file already covers the same behaviour, merge only the missing scenarios into that file and preserve existing wording where possible.
4. Keep each scenario atomic and testable.
5. Use `Background:` only when it removes repeated setup shared across multiple scenarios in the same file.
6. Avoid prose headings, bullet lists, implementation notes, TODOs, or metadata inside feature files.
7. Do not embed Markdown links, inline file references, HTML, or other non-Gherkin markup inside feature files.
8. Keep steps readable and self-contained without relying on cross-file links for meaning.

# Steps
1. Resolve the requested scope from the invocation text. If no scope is provided, return `ERROR: no application area provided`.
2. Inspect `./.gherkin` if it already exists and inventory existing topic folders and feature files to avoid duplication.
3. Launch Playwright and navigate the current application starting from the most direct route or workflow entry point implied by the scope.
4. Interact with the application only as needed to observe the current behaviour for the requested scope.
5. Record the observable flows, decisions, validations, and outcomes that were directly demonstrated.
6. Apply [source-like-gherkin](orchestra.snippets/source-like-gherkin.md) to group the observed behaviour into topic folders under `./.gherkin`.
7. For each topic, create or update a `.feature` file containing only Gherkin.
8. Before writing any scenario, compare it against existing indexed scenarios and skip or merge materially duplicate behaviour.
9. Keep scenario steps in plain language even when related behaviour is documented in another `.feature` file.
10. If multiple related scenarios share setup, factor that setup into a `Background:` block within that file.
11. Save the created or updated files and ensure each file remains plain Gherkin only.

# Response To User
```
Scope: <requested scope>
Index root: ./.gherkin
Files created: <number>
Files updated: <number>
Paths: <comma-separated paths>
Final status: <Indexed|No new behaviour found|Blocked|ERROR>
```
