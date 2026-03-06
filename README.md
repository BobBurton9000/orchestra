# Orchestra

Orchestra is a VS Code Copilot multi-agent workflow kit for planning, researching, implementing, refining, and validating software changes through coordinated specialist agents.

It is built for work that is too broad or too context-heavy for a single prompt. Instead of asking one agent to do everything, Orchestra gives you an orchestrator plus focused specialists for architecture, implementation, research, testing, review, UX, security, and product thinking.

![Example flow](example.png)

## Current State

- Built around custom agents and prompt files installed into `.github/agents` and `.github/prompts`
- Currently intended for VS Code Insiders
- Relies heavily on subagent delegation, so the orchestrator carries the tool access required by its team
- Uses model placeholders that are resolved during installation

The default model lists currently live in:

- `config/code-models.txt` for technical agents
- `config/generic-models.txt` for coordination and strategy agents

## What You Get

### Agents

The repository currently ships these agents:

- `orchestrator` - coordinates work and delegates to the rest of the team
- `architect` - plans architecture and implementation approach
- `backend-programmer` - handles backend implementation work without running tests
- `frontend-programmer` - handles frontend implementation work without running tests
- `debugger` - investigates failures and isolates root causes
- `information-gatherer` - collects repository and GitHub context
- `quality-engineer` - focuses on automated test coverage and test strategy
- `tester.cli` - runs CLI-based validation and interprets failures
- `tester.browser` - performs browser-based validation with Playwright
- `product-manager` - sharpens scope, value, and prioritization
- `security-expert` - reviews security risks and abuse cases
- `ux-designer` - reviews user-facing changes for clarity and usability
- `scribe` - handles straightforward documentation work
- `code-review.bugs` - reviews correctness and runtime behavior
- `code-review.dry` - reviews duplication and reuse
- `code-review.recycle` - reviews whether existing code, tooling, and infrastructure should have been reused
- `code-review.naming` - reviews naming consistency
- `code-review.self-documenting` - reviews readability and intent clarity
- `code-review.simplify` - reviews unnecessary complexity
- `code-review.solid` - reviews SOLID design risks
- `code-review.yagni` - reviews speculative or premature abstractions

### Prompts

The prompt set is built around both one-off utilities and a staged delivery pipeline:

- `orchestra.critique` - critique an attached file using the available review agents
- `orchestra.document` - generate a feature document grounded in real code
- `orchestra.learn` - extract a reusable lesson from the current chat into a skill
- `orchestra.stage0.refresh` - refresh existing Orchestra-generated skills
- `orchestra.stage1.import-spec` - turn a URL or freeform requirements into a normalized story
- `orchestra.stage2.research` - produce repository-grounded research documents for the story
- `orchestra.stage3.plan` - convert the story into an implementation plan
- `orchestra.stage4.refine` - refine the plan until critical and high issues are removed
- `orchestra.stage5.execute` - implement the refined plan and validate it
- `orchestra.stage6.merge-check` - run a recursive merge-readiness gate until the branch reaches `Go`

## Delivery Flow

The staged prompts are intended to build documents under `documents/<branch-name>/`.

Typical flow:

1. `orchestra.stage1.import-spec` writes `story.source.md` and `story.md`
2. `orchestra.stage2.research` writes one or more files under `research/`
3. `orchestra.stage3.plan` writes `plan.md`
4. `orchestra.stage4.refine` updates `plan.md` in place
5. `orchestra.stage5.execute` writes `execution-report.md`
6. `orchestra.stage6.merge-check` creates or updates `issues.md`

This keeps planning, research, execution, and release validation in a predictable per-branch workspace.

## Repository Layout

- `agents/` - custom agent definitions copied into `.github/agents`
- `prompts/` - reusable prompt files copied into `.github/prompts`
- `documents/` - generated per-branch output, with `.gitkeep` committed and generated contents gitignored
- `config/` - local configuration such as model lists and optional manual testing notes
- `scripts/` - support scripts, including model placeholder substitution
- `templates/` - templates used by the staged prompts
- `install.sh` - installs Orchestra into the current repository's `.github` directory
- `uninstall.sh` - removes installed Orchestra agents and prompts

## Installation

### Prerequisites

- A repository root that contains both `.github/` and `ai/orchestra/`
- VS Code Insiders
- Custom agents enabled in your VS Code environment
- Chat subagents enabled: `chat.customAgentInSubagent.enabled`

You also need the supporting skills expected by the agents and prompts. At minimum, the current orchestrator expects:

- `run-tests`
- `playwright`

### Install Steps

1. Place this repository at `ai/orchestra` inside your project.
2. Review the available models in `config/code-models.txt` and `config/generic-models.txt`.
3. Optionally add environment-specific notes to `config/manual-testing-instructions.md`.
4. From the project root, run:

```bash
./ai/orchestra/install.sh
```

The installer will:

- copy `agents/` into `.github/agents/`
- copy `prompts/` into `.github/prompts/`
- remove any previously installed Orchestra agent and prompt files first
- prompt you to choose models for technical and coordination agents
- replace `${CODE_MODEL}` and `${GENERIC_MODEL}` placeholders in the installed agent files

### Uninstall

From the project root, run:

```bash
./ai/orchestra/uninstall.sh
```

This removes installed Orchestra files from `.github/agents`, `.github/prompts`, and any Orchestra-prefixed skill directories under `.agents/skills` if that folder exists.

## Usage

### Orchestrator

Use the orchestrator agent as the main entry point for multi-step work:

```text
@orchestrator implement the attached plan
```

Use it when the work needs delegation, multiple specialist passes, or iterative review and validation.

### Staged Factory Workflow

Example progression for a new piece of work:

```text
/orchestra.stage1.import-spec https://example.com/ticket/123
/orchestra.stage2.research
/orchestra.stage3.plan
/orchestra.stage4.refine
/orchestra.stage5.execute
/orchestra.stage6.merge-check
```

### Utility Prompts

Useful one-off prompts outside the full staged flow:

```text
/orchestra.critique
/orchestra.document describe the existing auth flow
/orchestra.learn capture the pattern we discovered in this session
```

## Configuration

### Model Selection

Technical and coordination agents use separate model pools during installation:

- `config/code-models.txt` feeds agents such as programmers, debugger, testers, and reviewers
- `config/generic-models.txt` feeds agents such as orchestrator and product-manager

The selected values are written into the installed copies in `.github/agents/`.

### Manual Testing Instructions

`config/manual-testing-instructions.md` is an optional local note file for browser and manual validation guidance. The tester agents reference it when present.

### Documents

Generated outputs belong under `documents/<branch-name>/`. The repository currently gitignores generated document contents while keeping the directory itself tracked.

## Notes

- The orchestrator is intentionally strict about delegation. Its prompt explicitly forbids doing implementation or exploration work directly.
- The staged prompts are opinionated. They are meant to force explicit documents, bounded scope, and recursive refinement rather than one-shot execution.
- The repository is a working framework, not a polished product. Expect to tune agents, prompt wording, model lists, and supporting skills for your environment.
