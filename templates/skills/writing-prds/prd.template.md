# PRD: [Title]

<!--
Metadata block. Keep at the top of every PRD.
- Status: Proposed | Accepted | Implemented | Superseded
- Date: the date the PRD is first drafted (YYYY-MM-DD)
- Supersedes (optional): reference any prior PRD, ADR, or doc this replaces
- Related ADRs (optional): list any ADRs that this PRD depends on or informs
-->

- **Status:** Proposed
- **Date:** YYYY-MM-DD
- **Supersedes:** (none)
- **Related ADRs:** (none)

---

## Guidance for authors

This template is the single source of truth for PRD structure. Every PRD saved under `docs/product/requirements/` must follow it. The `writing-prds` skill (`.agents/skills/writing-prds/SKILL.md`) explains *how* to fill each section; this template defines *what* sections exist and in what order. Do not reorder, rename, or omit sections. If a section genuinely does not apply, write "Not applicable" with a one-line reason rather than deleting the heading — the consistent shape is what makes PRDs scannable across features.

Each section below is narrated with: what it is for, what belongs there, what does **not** belong there, a weak example to avoid, a strong example to follow, and common mistakes. Strip the per-section guidance comments before saving a real PRD — they are scaffolding, not part of the document.

The examples use a running scenario — a "notification channel preferences" feature where users independently enable Email, SMS, and Push — purely to illustrate the shape. Replace with your feature's domain terms.

---

## 1. Problem

**Purpose:** Explain the user-facing or business pain that this feature addresses, in terms a non-engineer could follow. This is the "why now, why us, why this" framing that justifies the whole document.

**What belongs here:** The concrete situation users face today, the friction or gap they hit, and the cost of doing nothing. Reference real workflows ("when a user adds a phone number, SMS silently switches on") rather than abstract capabilities. If the problem is a reversal of a prior decision, name the prior decision and what changed in practice.

**What does not belong here:** Implementation rationale ("we need a new boolean column"), solution sketches, or acceptance criteria. Save those for §5 and §10. Avoid restating the product vision — assume the reader has read `docs/product/vision.md`.

**Weak:**

> The system lacks explicit notification controls, which is a limitation.

**Strong:**

> Today a user's notification channels are inferred from their contact data: adding an email address silently enables Email notifications, adding a phone number silently enables SMS. There is no user-facing control to set these independently, so a user who added a phone number for account recovery cannot stop the system from sending them SMS alerts.

**Common mistakes:**

- Writing the solution here instead of the problem ("we will add three toggles…").
- Describing an internal architecture gap rather than a user-experienced pain.
- Omitting the cost of inaction, which is what makes the problem worth solving now.

## 2. Goals

**Purpose:** State the outcomes this feature must achieve to be considered successful. Goals are the contract between the PRD and the implementation.

**What belongs here:** Short, verifiable outcome statements written as "the system should …" or "users can …". Each goal should be something a tester or user could confirm by performing an action, not an internal quality attribute.

**What does not belong here:** Non-goals (those go in §3), implementation tasks, or vague aspirations ("improve UX"). Do not list every nice-to-have — three to six focused goals is healthier than fifteen diffuse ones.

**Weak:**

> Improve the notification preferences experience.

**Strong:**

> Users can choose Email, SMS, and/or Push when configuring notifications, and only the channels they enable are used for sending.

**Common mistakes:**

- Writing goals that are indistinguishable from the problem statement.
- Bundling multiple outcomes into one goal ("add toggles and a wizard and migrate data" — split these).
- Including engineering goals ("reduce query count") that belong in an ADR or implementation plan, not a PRD.

## 3. Non-Goals

**Purpose:** Explicitly name the things this feature will **not** do, to prevent scope creep and to set reviewer expectations.

**What belongs here:** Capabilities, edge cases, integrations, or follow-ups that a reasonable reader might *expect* this feature to include but which are deliberately deferred or rejected. Each non-goal should be specific enough that a reviewer could point to a request and say "that's a non-goal".

**What does not belong here:** Things that are obviously out of scope ("this will not fix the login page"). Trivial exclusions add noise. Also avoid using non-goals to list undiscovered work — only list things someone might plausibly ask for.

**Weak:**

> Out of scope: everything not listed above.

**Strong:**

> - Batch channel editing across multiple notification types on a single page.
> - Per-channel permissioning (e.g. some users can enable Push but not SMS).
> - Retirement of the legacy `?channel=` query-param branch in the notifications controller.

**Common mistakes:**

- Leaving this section empty — an empty non-goals list invites scope creep during review.
- Listing non-goals that no one would ever ask for, which reads as padding.

## 4. Users & Use Cases

**Purpose:** Identify who benefits and the concrete situations in which they benefit. This keeps the requirements grounded in real usage rather than abstract capability.

**What belongs here:** The primary actor(s) and one or two sentence use cases that describe the situation, the actor's intent, and the desired outcome. If different user types experience the feature differently, list each separately.

**What does not belong here:** Full user stories with acceptance criteria (those go in §10), or detailed screen-by-screen flows (those go in §6). Keep this at the "who and when" level.

**Weak:**

> Users can manage notifications better.

**Strong:**

> **Power user who wants all channels:** wants to enable Email, SMS, and Push together so they receive alerts on every channel they care about, choosing all three up front so the configuration form shows all relevant fields at once.
> **Email-only user:** wants to disable SMS and Push so they only receive email digests, without removing their phone number or device token from the system.

**Common mistakes:**

- Describing only the happy path actor and ignoring edge-case users (e.g. users migrating existing data).
- Writing use cases that are really implementation tasks in disguise.

## 5. Requirements

**Purpose:** The detailed behavioural specification — the rules the system must enforce and the capabilities it must provide. This is the part an engineer reads to know what to build.

**What belongs here:** Split into two subsections. **Functional requirements** describe what the system does (capabilities, inputs, outputs, state changes). **Rules & edge cases** describe the constraints, invariants, and boundary behaviour that distinguish correct from incorrect implementations. Rules are where most ambiguity is resolved — be explicit about what happens when data conflicts with a channel toggle, when a channel is turned off, when a required field is missing, etc.

**What does not belong here:** Implementation choices ("use a boolean column") — those belong in §7. UI layout details belong in §6. Test scenarios belong in §10.

**Weak (functional):**

> The system supports notification channels.

**Strong (functional):**

> - The system persists `canEmail`, `canSms`, and `canPush` as independent boolean flags on each user's notification preference record.
> - The notification settings page presents Email, SMS, and Push as independent checkboxes; any combination (including none) is valid.

**Weak (rules):**

> Channels and contact data should stay consistent.

**Strong (rules):**

> - Toggling a channel off does **not** delete the underlying contact data (email address, phone number, device token). The data is retained and the channel toggle only gates whether the system sends to that channel.
> - `canPush = true` requires a registered device token; the server rejects any update that would leave Push enabled with no token on file.

**Common mistakes:**

- Mixing rules into the functional list, making it hard to scan.
- Leaving edge cases implicit ("obviously it should keep the data") — what is obvious to the author is rarely obvious to the implementer.
- Writing requirements that cannot be tested because they describe internal state rather than observable behaviour.

## 6. User Experience

**Purpose:** Describe how a user moves through the feature — the screens, flows, and affordances they encounter, in enough detail that a designer or engineer could build it without further questions.

**What belongs here:** Key user flows as ordered step lists ("User clicks X, sees Y, then Z"). A short text wireframe or control inventory for each significant screen. Call out where this feature touches existing screens and what changes on them. Reference the UI/UX principles in `docs/product/ui-ux.md` where they apply.

**What does not belong here:** Visual design specifications (colour, spacing, typography) — those live in `docs/product/style-guide.md`. Do not duplicate the style guide; link to it. Full Gherkin scenarios belong in §10.

**Weak:**

> A form guides the user through notification setup.

**Strong:**

> **Settings page (replaces the current single-field `GET /notifications/preferences/new` form):**
> 1. Step 1 — Channels: three independent checkboxes (Email / SMS / Push). None selected is valid and produces a "digest only" preference.
> 2. Step 2 — Details: digest frequency (required), quiet hours (optional).
> 3. Step 3 — Conditional sections: if Email, show email address (pre-filled, editable); if SMS, show phone number (required); if Push, show device token selector (optional at setup).
>
> **Preferences detail page:** three toggle chips in the header (Email / SMS / Push), each persisting on toggle. Email card renders only when `canEmail`; SMS card only when `canSms`; Push card only when `canPush`.

**Common mistakes:**

- Describing only the new screen and ignoring changes to existing screens the feature touches.
- Specifying layout down to pixel widths — that belongs in a mockup or the style guide, not the PRD.

## 7. Data Model & API Changes

**Purpose:** Specify the persisted and transmitted shape changes this feature requires, at the level of entities, fields, and endpoints. This is where the PRD meets the domain model.

**What belongs here:** New or modified entities and their fields (with types and defaults), new or modified API endpoints (method, path, request shape, response shape), and any DTO or validation changes. Reference the existing domain model (`docs/product/domain-model.md`) and call out exactly what changes there. If a schema migration is required, describe it here at the intent level — the actual SQL lives in a migration file.

**What does not belong here:** Full implementation code, repository method signatures, or internal class structure — those belong in an implementation plan. The PRD defines the contract; the implementation plan defines the code.

**Weak:**

> Add fields to the preference record for the channels.

**Strong:**

> Introduce stored boolean columns on `notification_preferences`: `canEmail BOOLEAN NOT NULL DEFAULT FALSE`, `canSms BOOLEAN NOT NULL DEFAULT FALSE`, `canPush BOOLEAN NOT NULL DEFAULT FALSE`. These three booleans are the single source of truth for channel state; the previous derived equations (`emailAddress IS NOT NULL`, `phoneNumber IS NOT NULL`, `deviceTokenCount > 0`) are removed from the preference read query.
>
> `NotificationPreferenceDto` gains optional `canEmail`, `canSms`, `canPush` boolean fields for create/update validation. The server enforces `canPush === true ⇒ deviceTokenCount > 0`.

**Common mistakes:**

- Duplicating the domain model instead of diffing against it.
- Describing repository internals (class names, method signatures) that belong in an implementation plan.
- Omitting the validation rules, which are part of the data contract.

## 8. Migration & Rollout

**Purpose:** Explain how existing data and users transition to the new behaviour without regression. This is the section that makes a feature shippable rather than just buildable.

**What belongs here:** The migration strategy for existing records (seed from derived state, default-off, etc.), any one-time data patches, rollout ordering (schema first, then code, then UI), and backward-compatibility notes. Reference the `immutable-migration-patches` skill's forward-only principle where it applies. If the feature reverts a prior ADR, name the ADR and state that a superseding ADR will be drafted.

**What does not belong here:** The actual SQL of the migration file (that lives in the migrations directory), or rollout runbooks (those live in `docs/dev/devops/`).

**Weak:**

> Existing preferences will be migrated.

**Strong:**

> 1. Schema: `ALTER TABLE notification_preferences ADD COLUMN canEmail BOOLEAN NOT NULL DEFAULT FALSE, ADD COLUMN canSms BOOLEAN NOT NULL DEFAULT FALSE, ADD COLUMN canPush BOOLEAN NOT NULL DEFAULT FALSE;`
> 2. Seed from current derived state (one-time data patch in the same or immediately-following migration): set each preference's booleans from the existing derived rules, so a user who today receives "Email + SMS" continues to receive "Email + SMS" after rollout — now as an explicit stored flag, with no user-visible regression.
> 3. No destructive changes to `user_contact_methods` or `device_tokens`.
>
> A new ADR (superseding ADR-0007) will document the reversal and rationale.

**Common mistakes:**

- Assuming a fresh database. Existing records always need a stated transition.
- Forgetting to call out that a prior decision is being reversed, which leaves reviewers confused about why the PRD contradicts an accepted ADR.

## 9. Open Questions

**Purpose:** Record the decisions still to be made, so reviewers can answer them and so the PRD does not silently guess. A PRD with no open questions is either finished or under-scrutinised.

**What belongs here:** Specific, answerable questions that block a section of the PRD. Each question should be scoped (which section it affects) and offer the options being considered if the answer is not free-form. Number them so reviewers can reference them in review ("answering Q2: …").

**What does not belong here:** Questions that have already been resolved (move the answer into the relevant section and remove the question), or rhetorical questions that are really just notes.

**Weak:**

> Should we have a settings page?

**Strong:**

> Q1. Should the settings page replace the current `GET /notifications/preferences/new` form, or be offered as an alternative path alongside it? (Affects §6.) Recommendation: replace.

**Common mistakes:**

- Leaving resolved questions in this section, creating ambiguity about what the PRD actually proposes.
- Asking questions that are really implementation details no one can answer at the PRD stage.

## 10. Acceptance Criteria

**Purpose:** The observable, testable conditions under which the feature is considered done. This is the contract between the PRD and the test suite.

**What belongs here:** Gherkin scenarios written per the `writing-gherkin` skill: one behaviour per scenario, concrete `Given`/`When`/`Then` steps, observable outcomes. Cover the happy path and the important edge cases named in §5. If a scenario is too large, it is probably two scenarios.

**What does not belong here:** Implementation assertions ("the `canEmail` column is set"), internal state checks, or prose acceptance criteria. Gherkin is the format; if prose is genuinely needed, keep it out of this section and in §5.

**Weak:**

> The feature works correctly.

**Strong:**

```gherkin
Scenario: Toggling SMS off retains the phone number
  Given a user with canSms set to true
  And the user has a registered phone number
  When the user toggles SMS off
  Then the SMS card is hidden on the preferences page
  And the phone number is retained
  And re-toggling SMS on restores the SMS card with the phone number listed
```

**Common mistakes:**

- Writing scenarios that bundle multiple behaviours ("configure preferences, edit them, toggle a channel, and check the list").
- `Given` steps that describe intent rather than setup ("Given the user wants to receive SMS").
- `Then` steps that assert internal state rather than observable output.

## 11. Out-of-Scope Follow-ups

**Purpose:** Capture the work this feature intentionally *does not* do but which it makes more likely, more obvious, or more necessary. This is the forward-looking sibling of §3 Non-Goals.

**What belongs here:** Specific follow-up tasks or features that a reviewer or implementer might identify once this feature ships. Each item should be concrete enough to become its own ticket, PRD, or ADR. Flag whether each is a candidate for a future PRD or a future ADR.

**What does not belong here:** Vague aspirations, or work that is simply "the rest of the feature". If a follow-up is genuinely just unfinished scope, it belongs in §3, not here.

**Weak:**

> More notification features in future.

**Strong:**

> - Bulk channel editing across multiple notification types (candidate for a future PRD).
> - Per-channel permissioning (candidate for a future PRD).
> - Retirement of the legacy `?channel=email|sms|push` query-param branch in `NotificationsController.preferencesNew`, which becomes dead code once the settings page ships (candidate for a cleanup task).

**Common mistakes:**

- Listing items that are really still in scope but unfinished.
- Omitting this section entirely, causing follow-ups to be lost during review.