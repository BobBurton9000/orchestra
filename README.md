# Orchestra v2

Orchestra is a multi-agent workflow toolkit. You pick and choose agents, prompts, and skills from a prepackaged template library, customise them in portable definition files, then export to GitHub Copilot or OpenCode.

Orchestra lives in `.orchestra/` within your project. Your definitions live in `.agents/orchestra/`. You own them.

## Setup

```bash
git clone <repo-url> .orchestra
```

No install script. Import what you need:

```bash
./.orchestra/import.sh orchestrator
```

Or import everything at once, picking default models for orchestrator and subagents:

```bash
./.orchestra/import-defaults.sh
```

Either way, your definitions land in `.agents/orchestra/` — edit them directly.

## Repository Layout

```
.orchestra/
├── .gitattributes               # LF line endings for shell scripts
├── import.sh                    # Import a single agent, prompt, or skill
├── import-defaults.sh           # Bulk import everything + choose default models
├── export.sh                    # Compile includes + export to Copilot or OpenCode
├── convert.sh                   # Convert existing platform agents to definitions
├── scripts/
│   ├── common.sh                # Shared frontmatter/heading parsing utilities
│   └── compile.sh               # Recursive #include resolver + section extraction
└── templates/                   # Prepackaged library (never modified by user)
    ├── agents/                  # 29 agent templates (*.agent.md)
    ├── prompts/                 # 4 prompts + snippets (templates/config dirs reserved)
    └── skills/                  # 3 skills
```

Your definitions (after import):

```
.agents/orchestra/
├── agents/                      # Agent definitions you own
├── prompts/                     # Prompt definitions you own
└── skills/                      # Skill definitions you own
```

## Agent Definition Format

Every definition is a markdown file with YAML frontmatter. The canonical keys are the same regardless of target platform:

```yaml
---
name: architect
description: Plans software architecture and system design
mode: subagent                    # primary | subagent
model: ollama-cloud/kimi-k2.6
variant: max                      # optional - preserved for OpenCode
agents: [...]                     # orchestrator only — list of subagent names
permission:                       # optional — preserved for OpenCode, stripped for Copilot
  edit: deny
  bash: deny
---
```

`mode` is the universal visibility key:
- `primary` — visible to the user (maps to OpenCode `mode: primary`; Copilot: no `user-invocable` line)
- `subagent` — invoked only by the orchestrator (maps to OpenCode `mode: subagent`; Copilot: `user-invocable: false`)

No more `orchestra.` namespace prefix on names. No more `user-invocable: false` or `${SUBAGENT_MODEL}` placeholders. Concrete models go directly in the definition.

## Includes

Agent and prompt bodies can include external markdown files. The included content is inlined at export time, so agents never need to lazily load reference documents.

```
#include /docs/style-guide.md
#include /docs/architecture.md:#Data Flow
#include /docs/architecture.md:##Security Model
```

- Paths are relative to the project root (where `.orchestra/` lives). A leading `~` expands to the home directory.
- `:#Section Name` injects everything under that heading until the next same-or-higher-level heading
- `:##Sub Section` injects everything under that sub-heading
- Includes can nest — included files can include other files
- Every include is validated at export time; missing files or headings cause a hard error
- Exports compile into `.orchestra/.temp/` first, then atomically copy to platform directories
- `.temp/` is always cleaned up, success or failure

This stops agents from "lazy loading" reference documents. Everything the agent must read gets packed into the exported file.

## Import

```bash
./.orchestra/import.sh orchestrator            # agents/orchestrator.agent.md
./.orchestra/import.sh agents/architect         # agents/architect.agent.md
./.orchestra/import.sh prompts/gherkinify       # prompts/gherkinify.prompt.md
./.orchestra/import.sh skills/writing-gherkin   # skills/writing-gherkin/SKILL.md
```

- Copies the template from `templates/` into `.agents/orchestra/`
- Prompts for the model when importing an agent (uses saved defaults from `config.yml` if available)
- If the target already exists, asks before overwriting

### Import everything

```bash
./.orchestra/import-defaults.sh
```

Prompts for the default orchestrator model and subagent model, saves them to `.orchestra/config.yml`, then imports all 29 agents, 4 prompts (plus snippets), and 3 skills. Asks before overwriting each existing file.

## Export

```bash
./.orchestra/export.sh copilot    # → .github/agents/ + .github/prompts/
./.orchestra/export.sh opencode   # → .opencode/agents/ + .opencode/commands/
```

What happens:
1. Every definition in `.agents/orchestra/` is compiled (includes resolved, headings extracted)
2. Compiled output lands in `.orchestra/.temp/`
3. Frontmatter is transformed to the target platform's format
4. Platform output files are written
5. Skills are copied to `.agents/skills/`
6. A `.orchestra/.manifest` file tracks everything that was installed
7. `.orchestra/.temp/` is removed

Transformations per platform:

| Canonical | OpenCode | Copilot |
|-----------|----------|---------|
| `mode: primary` | `mode: primary` | *(omitted — visible by default)* |
| `mode: subagent` | `mode: subagent` | `user-invocable: false` |
| `variant:` | Preserved | Stripped |
| `permission:` block | Preserved | Stripped |
| `agents:` list | *(not output)* | Preserved |
| Filename `.agent.md` | Stripped → `name.md` | Kept as `name.agent.md` |
| Filename `.prompt.md` | Stripped → `name.md` | Kept as `name.prompt.md` |
| Prompt `handoffs:` | Stripped | Preserved |
| Prompt `agent:` | Preserved | Stripped |

## Convert (Existing Agents → Definitions)

If you already have agents installed for Copilot or OpenCode, convert them back into Orchestra definitions:

```bash
./.orchestra/convert.sh copilot              # all .github/agents/*.agent.md
./.orchestra/convert.sh copilot architect    # single agent
./.orchestra/convert.sh opencode             # all .opencode/agents/*.md
./.orchestra/convert.sh opencode architect   # single agent
```

The conversion inverts the same field mapping used by `export.sh`, so the round-trip is structurally sound. Output lands in `.agents/orchestra/agents/`. Asks before overwriting.

## Agent Catalog

All 29 agents available in `templates/agents/`:

| Agent | Role |
|-------|------|
| `orchestrator` | Strategic workflow orchestrator — delegates, reviews, and validates |
| `architect` | Architecture and system design planning |
| `backend.api-programmer` | API endpoints, controllers, middleware, request validation |
| `backend.auth-programmer` | Authentication and access control |
| `backend.data-programmer` | Schema, persistence, migrations |
| `backend.domain-programmer` | Business logic and domain services |
| `backend.integration-programmer` | External service integrations |
| `backend.platform-programmer` | Server bootstrap, configuration, observability |
| `code-review.bugs` | Logic error and unintended-consequence review |
| `code-review.maintainability` | Structural maintainability review |
| `code-review.readability` | Naming and readability review |
| `code-review.simplify` | Complexity and duplication review |
| `code-review.solid` | SOLID principle review |
| `debugger` | Bug investigation and diagnosis |
| `frontend.forms-programmer` | Form validation and submission flows |
| `frontend.platform-programmer` | Client bootstrap and configuration |
| `frontend.routing-programmer` | Routing and navigation |
| `frontend.state-programmer` | State management and data flow |
| `frontend.styling-programmer` | CSS, design system, and responsive layout |
| `frontend.ui-programmer` | Components, screens, and view composition |
| `information-gatherer` | Codebase and GitHub research |
| `judge` | Evidence-based truth determination |
| `quality-engineer` | Automated test writing |
| `scope-guard` | Scope creep protection |
| `scribe` | Documentation and PR descriptions |
| `security-expert` | Security review |
| `tester.browser` | Playwright-based browser testing |
| `tester.cli` | CLI test runner |
| `ux-designer` | UX review |

## Prompt Catalog

All 4 prompts available in `templates/prompts/`:

| Prompt | Description |
|--------|-------------|
| `gherkinify` | Convert source material into structured Gherkin scenarios |
| `investigate-bug-claim` | Investigate a bug-analyser claim and write a verdict report |
| `learn` | Extract a durable learning from the session into a reusable skill |
| `review-pr-to-file` | Review a PR diff and write findings to a branch-scoped file |

Supporting prompt assets (snippets) are copied alongside the prompts during import. Directories for `templates/` and `config/` are reserved for future use.

## Skill Catalog

All 3 skills available in `templates/skills/`:

| Skill | Description |
|-------|-------------|
| `ado-import` | Fetch and parse Azure DevOps work items via MCP tools |
| `mermaid-safe-node-labels` | Escape code-like text in Mermaid flowchart node labels |
| `writing-gherkin` | Author and review clear, observable Gherkin scenarios |
