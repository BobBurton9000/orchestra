# Orchestra

Orchestra is a universal format and package manager for AI coding agents, prompts, and skills. Write definitions once in Orchestra's canonical format, then export to GitHub Copilot or OpenCode — the format translates, the model stays yours. Share definitions via GitHub sources like apt packages; each developer installs what they need and picks their own models.

Although Orchestra works for standalone agents, it's built around an orchestration workflow where an Orchestrator agent delegates to a team of specialised subagents — and automatically becomes aware of new agents as you install them.

Orchestra lives in `.orchestra/` within your project. Your installed definitions live in `.agents/orchestra/`. You own them.

## What Orchestra does

### 1. A universal format for agents and prompts

Every Orchestra definition is a markdown file with YAML frontmatter using a small set of canonical keys. The same definition file exports to any supported platform — Orchestra handles the dialect differences.

```yaml
---
name: architect
description: Plans software architecture and system design
mode: subagent                    # primary | subagent
model: ollama-cloud/glm-5.1
variant: max                      # optional — preserved for OpenCode
agents: [...]                     # orchestrator only — list of subagent names
permission:                       # optional — preserved for OpenCode, stripped for Copilot
  edit: deny
  bash: deny
---
```

`mode` is the universal visibility key:
- `primary` — visible to the user (maps to OpenCode `mode: primary`; Copilot: no `user-invocable` line)
- `subagent` — invoked only by the orchestrator (maps to OpenCode `mode: subagent`; Copilot: `user-invocable: false`)

When you run `export copilot` or `export opencode`, Orchestra compiles every definition (resolving `#include` directives, extracting sections) and transforms the frontmatter to the target platform's format:

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

If you already have agents installed for Copilot or OpenCode, `convert` inverts the same mapping — so the round-trip is structurally sound. See [How it works — Export](#export) and [Convert](#convert-existing-agents--definitions) below for the mechanics.

### 2. A package manager for shareable definitions

Orchestra is inspired by `apt`. Sources are GitHub repositories with an `orchestra-source.yaml` manifest at their root. You add sources, install packages from them, and lock versions to a specific commit SHA.

The sharing model is simple: **authors publish markdown definitions; each developer picks their own models.** When you install an agent, Orchestra reads `config.yml` for your default model choices and writes the model into the agent's frontmatter silently. One developer runs `architect` on Claude; another runs it on GPT — same definition, different models, no edits to the shared file.

```yaml
# .orchestra/config.yml
orchestrator: ollama-cloud/qwen3.5:397b
subagent: ollama-cloud/glm-5.1
```

Packages are versioned by their source repo's HEAD commit SHA — there are no static version numbers to bump. `orchestra update` compares your locked SHA to the current HEAD; if it has moved, `orchestra upgrade` pulls the new version.

### 3. An orchestration workflow

Orchestra is built around an orchestration model, though it's not mandatory. The centrepiece is the **Orchestrator** agent — a `mode: primary` agent that delegates every unit of work to the specialised subagent best suited to carry it out. The Orchestrator never does direct work itself; it coordinates, reviews, and iterates.

The `core` source ([`orchestra-defaults`](https://github.com/BobBurton9000/orchestra-defaults)) ships with the Orchestrator and 29 subagents covering architecture, frontend, backend, code review, debugging, testing, security, and more. You install the ones you want.

**Auto-discovery:** When you `export opencode`, every installed agent lands in `.opencode/agents/`. OpenCode discovers all agents in that directory. The Orchestrator can delegate to any `mode: subagent` agent it finds — no explicit allowlist needed. Install a new agent, re-export, and the Orchestrator is automatically aware of it. The same applies to Copilot (`.github/agents/*.agent.md`).

The workflow loop: **delegate → implement → review → iterate.** The Orchestrator delegates a task, the subagent implements it, code-review agents review the change, a scope-guard checks boundaries, and the cycle continues until the task is complete. See [The Orchestration Workflow](#the-orchestration-workflow) below for detail.

## Setup

```bash
git clone <repo-url> .orchestra
```

No install script. Orchestra is a single entry point:

```bash
.orchestra/orchestra.sh install orchestrator           # install a single agent
.orchestra/orchestra.sh install --all core             # install everything from the core source
```

A default `sources.yaml` is created on first run, pointing at the [`orchestra-defaults`](https://github.com/BobBurton9000/orchestra-defaults) source (30 agents, 12 prompts, 5 skills).

## Requirements

Orchestra depends on three things:

- **`gh`** — GitHub CLI, for fetching packages and manifests from source repos. Install from [cli.github.com](https://cli.github.com) and run `gh auth login`.
- **`yq`** — YAML processor, for reading and writing Orchestra's data files. Install [mikefarah/yq](https://github.com/mikefarah/yq) (Go) or [kislyuk/yq](https://github.com/kislyuk/yq) (Python).
- **Bash 4+**

## Quick start

Install the Orchestrator and a couple of subagents, then export to both platforms:

```bash
.orchestra/orchestra.sh install orchestrator
.orchestra/orchestra.sh install architect
.orchestra/orchestra.sh install debugger

.orchestra/orchestra.sh export opencode
.orchestra/orchestra.sh export copilot
```

The same three definitions produce different output trees:

```
.opencode/                          .github/
├── agents/                         ├── agents/
│   ├── orchestrator.md             │   ├── orchestrator.agent.md
│   ├── architect.md                │   ├── architect.agent.md
│   └── debugger.md                 │   └── debugger.agent.md
└── commands/                       └── prompts/
                                    (prompts if installed)
```

OpenCode discovers all `.opencode/agents/*.md` files; Copilot discovers all `.github/agents/*.agent.md` files. In both cases the Orchestrator can delegate to `architect` and `debugger` — they're `mode: subagent`, so the platform makes them available as delegates.

## Commands

### Package management

```bash
.orchestra/orchestra.sh install <pkg>[@<source>]       # install a single package
.orchestra/orchestra.sh install <pkg> --locked         # install exact SHA from pkg.lock.yaml
.orchestra/orchestra.sh install --all <source>         # install every package from one source
.orchestra/orchestra.sh update                          # refresh all source manifests + HEAD SHAs
.orchestra/orchestra.sh upgrade [pkg]                  # upgrade installed package(s) to current HEAD
.orchestra/orchestra.sh remove <pkg>                   # remove a package (files + lockfile entry)
```

### Sources

```bash
.orchestra/orchestra.sh source add <owner/repo> [name] # add a source + fetch its manifest
.orchestra/orchestra.sh source list                    # show configured sources
.orchestra/orchestra.sh source remove <name>           # remove a source (refuses if packages installed)
```

### Query

```bash
.orchestra/orchestra.sh list                           # installed packages
.orchestra/orchestra.sh list --available               # all packages across all sources
.orchestra/orchestra.sh search <term>                  # search by name/type/path
.orchestra/orchestra.sh info <pkg>                     # details for a package (installed or available)
```

### Platform compatibility

```bash
.orchestra/orchestra.sh export copilot|opencode        # compile .agents/orchestra/ → platform output
.orchestra/orchestra.sh convert copilot|opencode [name] # convert existing platform files → Orchestra definitions
```

### Publishing (for source authors)

```bash
.orchestra/orchestra.sh generate-manifest [dir]        # scan a directory, emit orchestra-source.yaml
```

### Help

```bash
.orchestra/orchestra.sh                                 # usage
.orchestra/orchestra.sh help [command]                  # per-command help
.orchestra/orchestra.sh --version
```

## How it works

### Install

```bash
.orchestra/orchestra.sh install orchestrator           # agents/orchestrator.agent.md
.orchestra/orchestra.sh install writing-gherkin        # skills/writing-gherkin/SKILL.md
.orchestra/orchestra.sh install gherkinify             # prompts/gherkinify.prompt.md
.orchestra/orchestra.sh install triage-agent@extras    # from a specific source
```

- Fetches the package at the source's current HEAD SHA via `gh api`
- For agents: reads `config.yml` for the default model and writes it into the frontmatter silently. If `config.yml` is missing, you are prompted once and the choice is saved.
- Records the package, source, type, SHA, and installed file paths in `pkg.lock.yaml`
- Asks before overwriting an existing file (set `ORCHESTRA_YES=1` to auto-confirm)

### Update + upgrade

```bash
.orchestra/orchestra.sh update        # refresh all source manifests + HEAD SHAs
.orchestra/orchestra.sh upgrade       # upgrade all installed packages
.orchestra/orchestra.sh upgrade orchestrator   # upgrade a single package
```

### Remove

```bash
.orchestra/orchestra.sh remove writing-gherkin
```

Deletes every file recorded in the lockfile entry, then removes the lockfile entry. `remove` is the same as `purge` — there is no separate "keep config" step.

### Export

```bash
.orchestra/orchestra.sh export copilot    # → .github/agents/ + .github/prompts/
.orchestra/orchestra.sh export opencode   # → .opencode/agents/ + .opencode/commands/
```

What happens:
1. Every definition in `.agents/orchestra/` is compiled (`#include` directives resolved, headings extracted)
2. Compiled output lands in `.orchestra/.temp/`
3. Frontmatter is transformed to the target platform's format (see the [transformation table](#1-a-universal-format-for-agents-and-prompts) above)
4. Platform output files are written
5. Skills are copied to `.agents/skills/`
6. A `.orchestra/.manifest` file tracks everything that was installed
7. `.orchestra/.temp/` is removed

### Convert (Existing Agents → Definitions)

If you already have agents installed for Copilot or OpenCode, convert them back into Orchestra definitions:

```bash
.orchestra/orchestra.sh convert copilot              # all .github/agents/*.agent.md
.orchestra/orchestra.sh convert copilot architect    # single agent
.orchestra/orchestra.sh convert opencode             # all .opencode/agents/*.md
.orchestra/orchestra.sh convert opencode architect   # single agent
```

The conversion inverts the same field mapping used by `export`, so the round-trip is structurally sound. Output lands in `.agents/orchestra/agents/`. Asks before overwriting.

## Agent Definition Format

Every definition is a markdown file with YAML frontmatter. The canonical keys are the same regardless of target platform:

```yaml
---
name: architect
description: Plans software architecture and system design
mode: subagent                    # primary | subagent
model: ollama-cloud/glm-5.1
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

## The Orchestration Workflow

Orchestra is built around an orchestration model, though using it is optional — Orchestra installs any agent or prompt as a standalone definition. The orchestration workflow is there if you want a delegation-based AI team.

### The Orchestrator

The centrepiece is the **Orchestrator** agent (`mode: primary`). Its role is to coordinate, not to execute. From its definition:

> You are the strategic orchestration agent. You coordinate all workflow by delegating every unit of work to the agent best suited to carry it out.

> Never do direct work yourself — you do not read files, search project files, edit code, run commands, or use browser tools; every unit of work is delegated.

The Orchestrator routes work by architectural or domain boundary, divides tasks into small scoped units, and instructs each delegate to load relevant skills before starting.

### How subagents are discovered

There is no explicit allowlist. When you `export opencode`, every installed agent lands in `.opencode/agents/`:

```
.opencode/agents/
├── orchestrator.md          # mode: primary — visible to you
├── architect.md             # mode: subagent — available to the orchestrator
├── debugger.md              # mode: subagent — available to the orchestrator
└── ...
```

OpenCode discovers all agents in that directory. The Orchestrator can delegate to any `mode: subagent` agent it finds. The same applies to Copilot — agents land in `.github/agents/*.agent.md`, subagents get `user-invocable: false`, and the platform makes them available as delegates.

**Install a new agent, re-export, and the Orchestrator is automatically aware of it.** This is how your AI team grows: pull in more agents from sources, export, and the Orchestrator's delegation options expand without any configuration.

### The workflow loop

The Orchestrator drives an iterative cycle:

1. **Delegate** — the Orchestrator assigns a scoped task to the best-matched subagent, providing all necessary context in the prompt (subagents have no shared context).
2. **Implement** — the subagent does the work.
3. **Review** — code-review agents (e.g. `code-review.bugs`, `code-review.readability`, `code-review.solid`) review the change. The Orchestrator sends every batch to all available reviewers — applying all perspectives to every change is the point.
4. **Scope-check** — a scope-guard agent checks whether proposed follow-up work is still in scope.
5. **Adjudicate** — when claims conflict or evidence is ambiguous, a judge agent provides an independent decision.
6. **Iterate** — the cycle repeats until the originally approved task is complete. The Orchestrator does not widen scope because an agent proposes adjacent improvements.

### Skills

Skills are best-practice reference files that agents load at the start of a task. The Orchestrator instructs each delegate to load the skills relevant to its remit before starting work. Skills live in `.agents/skills/` after export and are discovered by the platform.

### When you don't want orchestration

The orchestration workflow is not mandatory. You can install a single agent (e.g. `architect`) and use it directly as a standalone definition — export it to your platform and invoke it yourself. The Orchestrator is just another package; install it only if you want the delegation model. Prompts and skills work the same way — install what you need, export, and use.

## Collaboration

Orchestra is built for sharing. Anyone can publish a source — it's just a GitHub repo with an `orchestra-source.yaml` at the root. See [`PUBLISHING.md`](PUBLISHING.md) for the format and a step-by-step guide.

Package *choice* stays personal. Your `sources.yaml`, `pkg.lock.yaml`, and `config.yml` are gitignored — they represent your selections, not your team's. Teammates configure their own sources and install what they need.

## Repository Layout

```
.orchestra/
├── orchestra.sh                # Single CLI entry point — all commands
├── scripts/
│   ├── common.sh               # Shared frontmatter/heading parsing utilities
│   ├── compile.sh              # Recursive #include resolver + section extraction
│   └── pkg/                    # Package manager implementation
│       ├── cli.sh              # Subcommand routing + usage
│       ├── pkg-common.sh       # Shared helpers, constants, lockfile paths
│       ├── yaml-helpers.sh     # YAML read/write helpers (yq-backed)
│       ├── ghutil.sh           # gh api wrappers (file/dir/sha/manifest fetch)
│       ├── sources.sh          # sources.yaml parsing + add/remove/list
│       ├── index.sh            # Manifest fetch + cache via gh api
│       ├── install.sh          # install + lockfile + model prompt logic
│       ├── upgrade.sh          # upgrade installed packages to current HEAD
│       ├── uninstall.sh        # remove (deletes files + lockfile entry)
│       ├── list.sh             # list/search/info query commands
│       ├── manifest.sh         # generate-manifest for source authors
│       ├── export.sh           # export subcommand (compile → platform output)
│       └── convert.sh          # convert subcommand (platform → Orchestra defs)
├── completion/
│   └── orchestra-completion.bash   # bash/zsh tab completion
└── tests/                      # Test suite
```

Your installed definitions (after install):

```
.agents/orchestra/
├── agents/                     # Agent definitions you own
├── prompts/                    # Prompt definitions you own
└── skills/                     # Skill definitions you own
```

Personal Orchestra state (all gitignored — your choices, not your team's):

```
.orchestra/
├── sources.yaml                # Your configured sources
├── pkg.lock.yaml               # Installed package ledger (package, source, SHA, paths)
├── pkg-cache/                  # Fetched manifests + HEAD SHAs
├── config.yml                  # Default model choices for agents
└── .manifest                   # Last export output list
```

## Tab completion

Source the completion file in your shell:

```bash
source .orchestra/completion/orchestra-completion.bash
```

Add it to your `~/.bashrc` or `~/.zshrc` for persistence.