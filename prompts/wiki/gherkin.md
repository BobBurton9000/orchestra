Gherkin is a plain-language format for writing behavior in a structured, testable way.

It usually uses:

- `Given` for the starting context
- `When` for the action
- `Then` for the expected result

Example:

Scenario: User signs in with valid credentials
Given the user is on the sign-in page
When the user submits a valid email and password
Then the user is signed in successfully

Use Gherkin when acceptance criteria should describe observable behavior clearly enough for product, QA, and engineering to interpret the same way.
