# Quick notes from Bob:

- There are provider-specific install/uninstall bash scripts now. I still recommend GPT-5.3 Codex for subagents because other models occasionally hang for me, but you can modify the provider-specific model lists if you want. GPT-5.4 is a good orchestrator model when it is available.
- Simply switch your agent to orchestrator to try out a more complex task being worked on by a large team of these designated agents. Be aware that it will take more time, but the experiment here is we're trying to trade this time for higher technical excellence and consisted standards.
- Try the learn prompt or document prompt it converts information to agent skills - i like the learn especially but i'm not sure the ouput formats for these are quite right yet
- You might ask how much of this markdown was LLM-generated. The answer is a good amount, but a lot of manual revision and hours has gone into writing certain prompts again from scratch and basically I slowly replace things with hand crafted markdown as I see the proof of concept from the LLM generated. Then I have the LLM make edits/improvements for me and eventually I need to do this pruning again. The product manager agent for example is a complete "vibe".

**LLM produced/maintained rest of README I need to update it**

# Orchestra

Orchestra is a multi-agent workflow kit for GitHub Copilot and OpenCode that supports planning, researching, implementing, refining, and validating software changes through coordinated specialist agents.

It is built for work that is too broad or too context-heavy for a single prompt. Instead of asking one agent to do everything, Orchestra gives you an orchestrator plus focused specialists for architecture, implementation, research, testing, review, UX, security, and product thinking.

## Current State

- Built around custom agents and command/prompt files installed into either `.github/agents` plus `.github/prompts` for GitHub Copilot, or `.opencode/agents` plus `.opencode/commands` for OpenCode
- Currently intended for VS Code Insiders
- Relies heavily on subagent delegation, so the orchestrator carries the tool access required by its team
- Uses model placeholders that are resolved during installation

The default model lists currently live in:

- `copilot.subagent-models.txt` for GitHub Copilot specialist agents
- `copilot.orchestrator-models.txt` for the GitHub Copilot orchestrator agent
- `opencode.subagent-models.txt` for OpenCode specialist agents
- `opencode.orchestrator-models.txt` for the OpenCode orchestrator agent

## What You Get

### Agents

The repository currently ships these agents:

- `orchestrator` - coordinates work and delegates to the rest of the team
- `architect` - plans architecture and implementation approach
- `backend.api-programmer` - handles backend endpoints, controllers, middleware, request validation, and boundary response handling without running tests
- `backend.domain-programmer` - handles backend business logic, workflows, and server-side rules without running tests
- `backend.data-programmer` - handles schema, persistence, repositories, queries, and migrations without running tests
- `backend.integration-programmer` - handles external service integrations, jobs, adapters, and infrastructure-facing server code without running tests
- `backend.auth-programmer` - handles authentication, authorization, identity, sessions, tokens, and access-control flows without running tests
- `backend.platform-programmer` - handles application bootstrap, runtime configuration, feature flags, and observability or infrastructure wiring without running tests
- `frontend.ui-programmer` - handles components, screens, view composition, and interactive UI behavior without running tests
- `frontend.state-programmer` - handles client-side state, caching, synchronization, and data flow without running tests
- `frontend.forms-programmer` - handles forms, validation, submission flows, and multi-step data entry without running tests
- `frontend.styling-programmer` - handles styling, responsive layout, design system application, and visual polish without running tests
- `frontend.routing-programmer` - handles routing, navigation, app shell composition, URL state, and route guards without running tests
- `frontend.platform-programmer` - handles frontend bootstrap, runtime configuration, provider wiring, and platform setup without running tests
- `debugger` - investigates failures and isolates root causes
- `information-gatherer` - collects repository and GitHub context
- `judge` - determines whether a claim is true, false, or not established from submitted evidence and independent research
- `quality-engineer` - focuses on automated test coverage and test strategy
- `tester.cli` - runs CLI-based validation and interprets failures
- `tester.browser` - performs browser-based validation with Playwright
- `product-manager` - sharpens scope, value, and prioritization
- `security-expert` - reviews security risks and abuse cases
- `ux-designer` - reviews user-facing changes for clarity and usability
- `plan-review` - reviews stage-1 plans for unresolved questions and architecture gaps, then returns APPROVED or CHANGES REQUESTED
- `scribe` - handles straightforward documentation work
- `code-review.bugs` - reviews correctness and runtime behavior
- `code-review.naming` - reviews naming consistency
- `code-review.self-documenting` - reviews readability and intent clarity
- `code-review.simplify` - reviews unnecessary complexity, duplication, missed reuse, abstraction opportunities, and YAGNI risks
- `code-review.solid` - reviews SOLID design risks

### Prompts

- `orchestra.critique` - critique attached files using the available review agents
- `orchestra.document` - generate a code-grounded feature document and save it as an Orchestra skill draft
- `orchestra.experimental.resolve-conflicts` - resolve merge conflicts against the correct target branch and validate the result locally
- `orchestra.gherkinify` - convert source material into a focused `Feature:` plus supported Gherkin scenarios
- `orchestra.learn` - extract a reusable lesson from the current chat and compile it into an Orchestra skill
- `orchestra.plan.create` - create a simple branch implementation plan from inline text or a GitHub/Azure DevOps URL, then iterate with `plan-review` until APPROVED
- `orchestra.plan.chunk` - expand the branch plan into chunked implementation detail for execution
- `orchestra.plan.execute` - execute the current branch plan, enforce review and QA loops, and write an execution report
- `orchestra.refresh-skills` - refresh existing Orchestra-generated skills against the current codebase
- `orchestra.review-feedback` - address actionable reviewer feedback on the current pull request
- `orchestra.review.pr-to-file` - review a pull request diff and write findings to a new markdown file at project root

## Delivery Flow

The planning, chunking, and execution prompts build branch-scoped artifacts under `.agents/orchestra/<branch-name>/`.

Primary implementation flow:

1. `orchestra.plan.create` turns the request into a simple `.agents/orchestra/<branch-name>/plan.md` using `implementation-plan.template.md`
2. `orchestra.plan.chunk` expands that plan into `.agents/orchestra/<branch-name>/chunk-plan.md` with delivery chunks and task-level detail using `implement-chunk.template.md`
3. Optional: `orchestra.gherkinify` converts source material into Gherkin that you can save as `.agents/orchestra/<branch-name>/gherkin.feature` or use as planning input
4. `orchestra.plan.execute` implements `.agents/orchestra/<branch-name>/chunk-plan.md`, runs review and validation loops, and writes `.agents/orchestra/<branch-name>/execution-report.md`
5. `orchestra.review-feedback` addresses actionable reviewer feedback on the current pull request

Supporting prompt flows:

1. `orchestra.document` turns an existing feature into a reusable Orchestra skill document under `.agents/skills/`
2. `orchestra.learn` extracts a reusable lesson from the current session into `.agents/skills/`
3. `orchestra.refresh-skills` reviews existing Orchestra-generated skills and updates them against the current codebase
4. `orchestra.review.pr-to-file` performs an offline PR review and writes findings into a new root-level markdown file
5. `orchestra.experimental.resolve-conflicts` resolves merge conflicts locally without committing or pushing automatically

This keeps planning, execution, review follow-up, and generated documentation in a predictable per-branch workspace.

## Repository Layout

- `agents/` - shared source agent definitions transformed for either `.github/agents` or `.opencode/agents`
- `prompts/` - shared source prompt definitions copied into `.github/prompts` or transformed into `.opencode/commands`
- `prompts/orchestra.config/` - workflow configuration copied into `.github/prompts/orchestra.config` or `.opencode/commands/orchestra.config`
- `prompts/orchestra.templates/` - shared templates copied into `.github/prompts/orchestra.templates` or `.opencode/commands/orchestra.templates`
- `.agents/orchestra/` - generated per-branch output created by the installer for plan and execution artefacts
- `scripts/` - support scripts, including model placeholder substitution
- `copilot.install.sh` - installs Orchestra into the current repository's `.github` directory for GitHub Copilot
- `copilot.uninstall.sh` - removes the GitHub Copilot Orchestra installation
- `opencode.install.sh` - installs Orchestra into the current repository's `.opencode` directory for OpenCode
- `opencode.uninstall.sh` - removes the OpenCode Orchestra installation

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
2. Review the available models in the provider-specific model files.
3. Optionally add environment-specific notes to `prompts/orchestra.config/manual-testing-instructions.md`.
4. From the project root, run the installer for your platform:

```bash
./ai/orchestra/copilot.install.sh
```

or

```bash
./ai/orchestra/opencode.install.sh
```

The installer will:

- copy or transform `agents/` into `.github/agents/` for GitHub Copilot or `.opencode/agents/` for OpenCode
- copy or transform `prompts/` into `.github/prompts/` for GitHub Copilot or `.opencode/commands/` for OpenCode
- copy `prompts/orchestra.templates/` into the matching platform prompt or command directory
- copy `prompts/orchestra.config/` into the matching platform prompt or command directory
- create `.agents/orchestra/` when it does not already exist
- remove any previously installed Orchestra agent and prompt files first
- prompt you to choose provider-specific models for subagents and the orchestrator
- replace `${SUBAGENT_MODEL}` and `${ORCHESTRATOR_MODEL}` placeholders in the installed agent files

### Uninstall

From the project root, run:

```bash
./ai/orchestra/copilot.uninstall.sh
```

or

```bash
./ai/orchestra/opencode.uninstall.sh
```

This removes installed Orchestra files from the matching platform directories and any Orchestra-prefixed skill directories under `.agents/skills` if that folder exists.

## Usage

### Orchestrator

Use the orchestrator agent as the main entry point for multi-step work:

```text
@orchestrator implement the attached plan
```

Use it when the work needs delegation, multiple specialist passes, or iterative review and validation.

For implementation routing, the orchestrator should pick the narrowest matching programmer by default and split cross-cutting work into explicit specialist-owned tasks. The dotted-family fan-out rule remains appropriate for review and tester families such as `code-review.*` and `tester.*`, but implementation specialists are intentionally shipped as singleton hyphenated agents so backend and frontend coding work stays segregated by lane rather than collapsing into a generalist path.

### Prompt Workflows

Plan-driven example progression:

```text
/orchestra.plan.create https://example.com/ticket/123
/orchestra.plan.chunk
/orchestra.plan.execute
/orchestra.review-feedback
```

`/orchestra.review-feedback` is the concise deterministic command for the common request "address all reviewer feedback on the current PR". It resolves the active pull request first, falls back to the currently open pull request if needed, then builds a normalised feedback backlog from review comments, review submissions, and actionable PR discussion comments.

Optional Gherkin-first variant:

```text
/orchestra.gherkinify auth session timeout rules
/orchestra.plan.create implement the attached gherkin feature
/orchestra.plan.chunk
/orchestra.plan.execute
/orchestra.review-feedback
```

Documentation and review utilities:

```text
/orchestra.document describe the existing auth flow
/orchestra.review.pr-to-file https://github.com/example/repo/pull/123 example repo review-notes.md
/orchestra.experimental.resolve-conflicts
```

### Utility Prompts

Useful one-off prompts outside the main plan/execute flow:

```text
/orchestra.critique
/orchestra.gherkinify password reset behaviour
/orchestra.refresh-skills
/orchestra.document describe the existing auth flow
/orchestra.learn capture the pattern we discovered in this session
/orchestra.review.pr-to-file https://github.com/example/repo/pull/123 example repo review-notes.md
/orchestra.experimental.resolve-conflicts
```

## Configuration

### Model Selection

Subagents and the orchestrator use separate model pools during installation, and the model files differ by platform:

- `copilot.subagent-models.txt` and `copilot.orchestrator-models.txt` feed GitHub Copilot installs
- `opencode.subagent-models.txt` and `opencode.orchestrator-models.txt` feed OpenCode installs

The selected values are written into the installed copies in `.github/agents/` or `.opencode/agents/`.

### Manual Testing Instructions

`prompts/orchestra.config/manual-testing-instructions.md` is an optional note file for browser and manual validation guidance. It is copied to `.github/prompts/orchestra.config/manual-testing-instructions.md` for GitHub Copilot installs and `.opencode/commands/orchestra.config/manual-testing-instructions.md` for OpenCode installs.

### Documents

Generated outputs belong under `.agents/orchestra/<branch-name>/`. The installer creates `.agents/orchestra/` when needed, and generated artefacts should remain out of version control.

## Notes

- The orchestrator is intentionally strict about delegation. Its prompt explicitly forbids doing implementation or exploration work directly.
- The prompt workflows are opinionated. They are meant to force explicit planning, bounded scope, repeated review, and evidence-backed execution rather than one-shot implementation.
- The repository is a working framework, not a polished product. Expect to tune agents, prompt wording, model lists, and supporting skills for your environment.
