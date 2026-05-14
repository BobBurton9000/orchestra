# Orchestra

Orchestra is a set of agents, prompts, skills, and install scripts for running a multi-agent workflow in either GitHub Copilot or OpenCode.

## Current State

- This repo installs into an existing project at `ai/orchestra`.
- It supports two installation targets:
  - GitHub Copilot: `.github/agents` and `.github/prompts`
  - OpenCode: `.opencode/agents` and `.opencode/commands`
- Model selection happens during install from provider-specific model lists.
- The repo currently includes source definitions for agents, prompts, templates, and a small set of reusable skills.

## Repository Layout

- `agents/` - source agent definitions
- `prompts/` - source prompt definitions plus config, snippets, and templates
- `skills/` - reusable skills copied into `.agents/skills/` during install
- `scripts/configure.sh` - installs prompts and agents for the selected platform and replaces model placeholders
- `copilot.install.sh` / `copilot.uninstall.sh` - install or remove the GitHub Copilot version
- `opencode.install.sh` / `opencode.uninstall.sh` - install or remove the OpenCode version
- `*.subagent-models.txt` and `*.orchestrator-models.txt` - selectable model lists used by the installer

## Agents

Current source agents in `agents/`:

- `orchestrator`
- `architect`
- `backend.api-programmer`
- `backend.auth-programmer`
- `backend.data-programmer`
- `backend.domain-programmer`
- `backend.integration-programmer`
- `backend.platform-programmer`
- `frontend.forms-programmer`
- `frontend.platform-programmer`
- `frontend.routing-programmer`
- `frontend.state-programmer`
- `frontend.styling-programmer`
- `frontend.ui-programmer`
- `debugger`
- `information-gatherer`
- `judge`
- `plan-review`
- `product-manager`
- `quality-engineer`
- `scope-guard`
- `scribe`
- `security-expert`
- `tester.browser`
- `tester.cli`
- `ux-designer`
- `code-review.bugs`
- `code-review.maintainability`
- `code-review.readability`
- `code-review.simplify`
- `code-review.solid`

## Prompts

Current prompt files in `prompts/`:

- `orchestra.create-playbook`
- `orchestra.gherkinify`
- `orchestra.investigate-bug-claim`
- `orchestra.learn`
- `orchestra.plan-file`
- `orchestra.refresh-skills`
- `orchestra.resolve-conflicts`
- `orchestra.review.pr-to-file`

Supporting prompt assets:

- `prompts/orchestra.config/`
- `prompts/orchestra.snippets/`
- `prompts/orchestra.templates/`

## Skills

Current built-in skills in `skills/`:

- `orchestra.ado-import`
- `orchestra.mermaid-safe-node-labels`
- `orchestra.writing-gherkin`

The installers also create `.agents/skills/` in the target project and copy these built-in skills there when present.

## Installation

Run installers from the project root that contains `ai/orchestra`.

GitHub Copilot:

```bash
./ai/orchestra/copilot.install.sh
```

OpenCode:

```bash
./ai/orchestra/opencode.install.sh
```

What the installers do:

- validate that you are running from a project root containing `ai/orchestra`
- clear previously installed Orchestra files for the selected platform
- create the target agent and prompt or command directories if needed
- create `.agents/skills/` and `.orchestra/`
- copy built-in skills from `skills/` into `.agents/skills/`
- prompt for a subagent model and an orchestrator model
- install platform-specific copies of agents and prompts

Platform-specific behavior:

- GitHub Copilot keeps the source agent files in `.github/agents/` and strips `permission` blocks from frontmatter during install.
- OpenCode transforms `*.agent.md` files into `.opencode/agents/*.md` with `description`, `mode`, `model`, and optional `permission` frontmatter.
- OpenCode transforms `*.prompt.md` files into `.opencode/commands/*.md` and prefixes agent references with `orchestra.` when needed.

## Uninstall

GitHub Copilot:

```bash
./ai/orchestra/copilot.uninstall.sh
```

OpenCode:

```bash
./ai/orchestra/opencode.uninstall.sh
```

Both uninstallers remove installed Orchestra agents, prompts or commands, Orchestra skill folders under `.agents/skills/`, and `.orchestra/`.

## Models

The installer reads from these files:

- `copilot.subagent-models.txt`
- `copilot.orchestrator-models.txt`
- `opencode.subagent-models.txt`
- `opencode.orchestrator-models.txt`

The selected values replace `${SUBAGENT_MODEL}` and `${ORCHESTRATOR_MODEL}` in installed agent files.

## Notes

- `prompts/orchestra.config/manual-testing-instructions.md` exists and is copied during install.
- `prompts/orchestra.templates/` contains the current markdown templates used by the prompt set.
- Branch-scoped Orchestra artifacts use `.orchestra/<branch-name>/`.
