Use this document as the canonical decision policy for orchestrator prompts.

Apply it whenever source material is incomplete, sub-agents disagree, repository evidence conflicts with suggestions, or the workflow requires a forced decision to keep moving.

## Core Rules

1. Source evidence beats opinion.
2. Explicit user context beats inferred intent.
3. Repository conventions beat new, speculative patterns.
4. If evidence is still incomplete, choose the smallest safe default.
5. Record every forced decision in the document where downstream work will depend on it.
6. Do not invent product requirements, architecture, or scope beyond what the available evidence supports.

## Conservative Default

When a prompt says to use a conservative default, prefer:

- the smallest safe scope,
- strict permissions,
- explicit validation,
- non-destructive behaviour,
- minimal change to existing architecture,
- and release-safe operability.

## Stage-Specific Precedence

### Story Import

Use this precedence:

1. Source evidence
2. Explicit user context
3. Repository conventions
4. Conservative default

Every forced decision must be reflected in `Scope`, `Constraints and Dependencies`, or `Acceptance Criteria`.

### Research

Use this precedence:

1. Direct repository evidence (code/tests)
2. Plan scope and decisions
3. Established repository conventions
4. Conservative interpretation with explicit evidence note

Never invent architecture or behaviour that was not found in the repository.

### Plan

Use this precedence:

1. Story source and explicit user constraints
2. Repository conventions and existing architecture
3. Safety and reliability requirements
4. Conservative minimal-scope default

Every forced decision must be reflected in architecture, task steps, or testing.

### Refine

Use this precedence:

1. Direct evidence in plan and source story
2. Repository conventions and existing architecture
3. Release safety and operability constraints
4. Conservative minimal-scope default

Never add speculative redesigns or nice-to-have work.

### Execute

Use this precedence:

1. Plan requirements and scope
2. Repository conventions and existing architecture
3. Release safety and operability
4. Conservative minimal-change default

Never introduce speculative redesigns or out-of-scope enhancements during execution.
