---
name: orchestra.writing-gherkin
description: Guidance for authoring and reviewing clear Gherkin features, scenarios, Given/When/Then steps, Background sections, and Scenario Outlines. Use when converting source material into Gherkin, fixing weak step wording, or checking whether acceptance criteria are observable and testable.
---

# Writing Gherkin

## Purpose

Use this skill when writing or reviewing Gherkin so the scenarios stay behaviour-focused, observable, and strict about step semantics.

## Core rule

Each scenario describes one behaviour in this shape:

- `Given`: the starting context or precondition that is already true before the behaviour starts
- `When`: the action taken by an actor, or the event that occurs
- `Then`: the observable outcome

If a step reads like intent, policy, design rationale, or a hidden implementation detail, it is probably the wrong shape.

## What a `Given` means

A `Given` is not the business goal and not the capability being asserted. It is the state of the world before the action happens.

Strong `Given` steps usually describe one or more of these:

- existing records, entities, or configuration
- the actor's identity, role, or authentication state
- data already present in the system
- permissions, organisation scope, or other access context
- inventory, balances, quantities, or statuses that already exist

Ask this question: could a test set this up before the `When` step runs? If yes, it is usually a valid `Given`.

## What a `Given` should not be

Avoid using `Given` for:

- business motivation
- product intent
- the behaviour under test
- a conclusion that belongs in `Then`
- vague capability statements with no concrete setup

Weak:

```gherkin
Given a user needs a secure way to access their account
```

Stronger:

```gherkin
Given the user is on the sign-in page
```

Weak:

```gherkin
Given a user can sign in with an email address and password
```

Stronger:

```gherkin
Given the user has a registered account
And the user is on the sign-in page
```

Weak:

```gherkin
Given authentication supports valid credentials
```

Stronger:

```gherkin
Given the user has a registered account
```

## What a `When` means

`When` introduces the behaviour trigger.

Good `When` steps usually describe:

- a user action
- an API request
- a system event
- a scheduled or domain event

Examples:

```gherkin
When the user submits a valid email address and password
When the user submits an incorrect password
When the user requests a password reset link
```

## What a `Then` means

`Then` states the observable result.

Good `Then` steps should be verifiable from outside the implementation, for example through:

- persisted state
- returned data
- visible UI output
- emitted transaction records
- access allowed or denied

Avoid `Then` steps that merely restate internal code structure unless that structure is directly observable in behaviour.

## Scenario quality checklist

Each scenario should:

- cover one behaviour, not a whole feature area
- contain at least one explicit `Given`, `When`, and `Then`
- use concrete domain terms from the source material
- stay specific enough to test
- avoid mixing setup, action, and outcome into the same line
- avoid speculative behaviour not supported by the source

## `Background` guidance

Use `Background` only when several scenarios share the same setup and repeating it adds noise.

Use `Background` for stable shared context such as:

- the user being authenticated
- the organisation already existing
- common seed data used by every scenario

Do not move scenario-specific setup into `Background` just to reduce repetition. Each scenario should still read clearly on its own.

## `Scenario Outline` guidance

Use `Scenario Outline` only when the behaviour is the same and the examples vary by input or outcome.

Use it when:

- the same rule applies to several roles, statuses, or item types
- the step wording stays identical apart from placeholders

Do not use it when each example needs materially different setup or outcome wording. In that case, separate scenarios are clearer.

## Language guidance

Prefer steps that are:

- concrete
- observable
- domain-oriented
- concise

Avoid steps that are:

- abstract
- architectural
- implementation-heavy
- padded with rationale

Prefer:

```gherkin
Then the user is signed in and redirected to the dashboard
```

Over:

```gherkin
Then authentication works correctly
```

## Converting source material into Gherkin

When deriving Gherkin from an issue, specification, or design note:

1. Extract only supported behaviour.
2. Ignore rationale that does not change observable behaviour.
3. Convert acceptance criteria into scenarios.
4. Turn goals and motivation into feature naming, not step text.
5. Rewrite weak preconditions so `Given` describes setup rather than intent.

## Review guidance

When reviewing Gherkin, check these in order:

1. Is the behaviour supported by the source?
2. Does every scenario have a real precondition, trigger, and outcome?
3. Do the `Given` steps describe setup instead of requirements?
4. Are the `Then` steps observable and testable?
5. Would a tester know what to arrange, do, and verify?

## Example rewrite

Weak:

```gherkin
Scenario: Sign in with valid credentials
Given authentication supports valid credentials
When the user submits a valid email address and password
Then the user is signed in successfully
```

Stronger:

```gherkin
Scenario: Sign in with valid credentials
Given the user has a registered account
And the user is on the sign-in page
When the user submits a valid email address and password
Then the user is signed in
And the dashboard is displayed
```