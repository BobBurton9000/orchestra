A chunk is a bounded delivery increment within an implementation plan.

It groups together the task units needed to deliver one coherent slice of behaviour or technical capability.

A chunk must be measurable. It is only valid if completion can be proven through at least one of:

- a manual user journey, usually exercised through browser or end-to-end testing,
- an integration test or integration-level automated test,
- for a sufficiently small and narrow chunk, a unit test,
- or both.

A good chunk has these properties:

- It has a single clear goal.
- It has an explicit boundary and does not mix unrelated work.
- It can be completed and validated independently of later chunks.
- Its tasks all contribute directly to the same measurable outcome.
- Its validation proves business behaviour, integration behaviour, or, for very small chunks, tightly scoped unit-level behaviour.

A chunk is not just a bucket of implementation tasks. If the grouped work cannot be validated as one meaningful increment, it is not a good chunk and should be split or re-scoped.

Unit tests are the exception, not the default. They are appropriate when the chunk is small enough that unit-level behaviour is the most direct and sufficient proof of completion. If the chunk crosses component, service, API, persistence, or user-facing boundaries, prefer integration tests, manual user journeys, or both.

Examples:

- Good chunk: add the new form submission flow, including server handling, persistence, and the integration/manual checks that prove a user can complete the journey successfully.
- Good small chunk: add a pure validation helper and prove the intended edge cases with focused unit tests.
- Weak chunk: update backend models, rename frontend variables, and tidy unrelated tests. This is not one measurable increment and should be decomposed.

When planning, prefer chunks that represent the smallest safe releaseable or verifiable slice of progress.