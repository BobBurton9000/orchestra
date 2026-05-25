Source-like Gherkin is Gherkin organised like source code rather than a single flat acceptance-criteria document.

Use it when behaviour should be indexed across many files and revisited incrementally over time.

Rules:

1. Group files by stable product or route boundaries, such as `auth/`, `settings/profile/`, or `checkout/payment/`.
2. Prefer narrow topic-focused files over broad mixed-purpose files.
3. Use behaviour-oriented file names in kebab-case with a `.feature` suffix.
4. Keep each file Gherkin-first: `Feature:`, optional `Background:`, and one or more `Scenario:` or `Scenario Outline:` blocks.
5. Capture only observable, verifiable behaviour.
6. Keep steps plain Gherkin only. Do not embed Markdown links, file paths, HTML, or other non-Gherkin markup.
7. If related behaviour is documented in another `.feature` file, keep the current step readable as standalone plain language rather than linking across files.
8. Avoid duplicating full scenarios across files unless the behaviour truly belongs in both places with different local assertions.
9. Prefer narrow file ownership so related behaviour stays discoverable from the folder structure and file names.
10. Let cross-file relationships be handled by repository layout and downstream summary documents rather than inline markup inside feature files.

Example:

```gherkin
Feature: Profile access

Scenario: Signed-in user opens profile settings
Given the user is signed in
When the user navigates to the profile settings page
Then the profile settings page is displayed
```