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

The sharing model is simple: **authors publish markdown definitions without a model; each developer picks their own.** Source files never contain a `model:` line. When you install an agent, Orchestra reads `config.yml` for your default model choices and injects the model into the installed file's frontmatter. One developer runs `architect` on Claude; another runs it on GPT — same source definition, different models, no edits to the shared file. Upgrades preserve your model choice — the upgraded file inherits the model from your previously installed file, not from `config.yml`.

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
.orchestra/orchestra.sh fork <pkg>                     # detach a package for local edits
```

### Sources

```bash
.orchestra/orchestra.sh source add <owner/repo> [name] # add a source + fetch its manifest
.orchestra/orchestra.sh source subscribe <name>       # install future packages from a source on upgrade
.orchestra/orchestra.sh source unsubscribe <name>     # stop installing future packages
.orchestra/orchestra.sh source list                    # show configured sources
.orchestra/orchestra.sh source remove <name>           # remove a source (refuses if packages installed)
```

### Query

```bash
.orchestra/orchestra.sh list                           # installed packages
.orchestra/orchestra.sh list --available               # all packages across all sources
.orchestra/orchestra.sh search <term>                  # search by name/type/path
.orchestra/orchestra.sh info <pkg>                     # details for a package (installed or available)
.orchestra/orchestra.sh status                         # audit package paths and orphaned files
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

Source repositories do not need to contain Orchestra to maintain their
manifest. Download the standalone `orchestra-manifest.sh` tool from the
Orchestra `master` branch, commit it to the source repository, and run it after
adding or removing packages:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/BobBurton9000/orchestra/master/orchestra-manifest.sh \
  -o orchestra-manifest.sh
chmod +x orchestra-manifest.sh
./orchestra-manifest.sh --force .
```

The committed tool updates itself from `master` with
`./orchestra-manifest.sh --self-update --force .`. Use
`./orchestra-manifest.sh --check .` in CI to detect a stale manifest.

### Help

```bash
.orchestra/orchestra.sh                                 # usage
.orchestra/orchestra.sh help [command]                  # per-command help
.orchestra/orchestra.sh --version
```

## How it works

### Status

Use `status` to audit the local definition directory against the package
lockfile:

```bash
.orchestra/orchestra.sh status
```

The report shows each locked package, its source, type, SHA, and installed
paths. It also identifies locked paths that are missing from disk and files
under `.agents/orchestra/` that are not part of any locked package. This is a
local read-only check; it does not refresh source indexes or modify state.

### Install

```bash
.orchestra/orchestra.sh install orchestrator           # agents/orchestrator.agent.md
.orchestra/orchestra.sh install writing-gherkin        # skills/writing-gherkin/SKILL.md
.orchestra/orchestra.sh install gherkinify             # prompts/gherkinify.prompt.md
.orchestra/orchestra.sh install triage-agent@extras    # from a specific source
```

- Fetches the package at the source's current HEAD SHA via `gh api`
- For agents: source files have no `model:` line. Orchestra injects the model from `config.yml` into the installed file's frontmatter. If `config.yml` is missing, you are prompted once and the choice is saved.
- Records the package, source, type, SHA, and installed file paths in `pkg.lock.yaml`
- Asks before overwriting an existing file (set `ORCHESTRA_YES=1` to auto-confirm)

### Update + upgrade

```bash
.orchestra/orchestra.sh update        # refresh all source manifests + HEAD SHAs
.orchestra/orchestra.sh upgrade       # upgrade all installed packages
.orchestra/orchestra.sh upgrade orchestrator   # upgrade a single package
```

Upgrades preserve your model choice — the upgraded file inherits the model from your previously installed file, not from `config.yml`. If you change your mind about a model, re-install the package fresh (`remove` then `install`).

### Fork

```bash
.orchestra/orchestra.sh fork orchestrator
```

Forking keeps the installed files and their lockfile entry, but marks the
package as detached from future source upgrades. The original source and SHA
remain recorded for provenance, while both targeted and bulk `upgrade` leave
the fork unchanged. Edit the files under `.agents/orchestra/` directly, then
run the existing `export` command when platform output needs refreshing.

Forked packages remain managed by `status` and can still be removed. Running
`install` for the same package explicitly reattaches it to the source.

### Subscribing to a source

Adding a source makes its packages available for explicit installation. It does not automatically install the source's existing packages or future packages.

To receive assets added to a source in future bulk upgrades:

```bash
.orchestra/orchestra.sh source add alice/orchestra-extras extras
.orchestra/orchestra.sh source subscribe extras
.orchestra/orchestra.sh upgrade
```

`source subscribe` records the source manifest at that point as a baseline. A later `upgrade` refreshes subscribed sources and installs only package names added after that baseline. Existing packages are left under normal lockfile control, and `upgrade <pkg>` remains a targeted upgrade without subscription discovery. Use `install --all <source>` when you also want the source's current packages.

Unsubscribing stops future automatic installs but does not remove packages already installed:

```bash
.orchestra/orchestra.sh source unsubscribe extras
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
variant: max                      # optional - preserved for OpenCode
agents: [...]                     # orchestrator only — list of subagent names
permission:                       # optional — preserved for OpenCode, stripped for Copilot
  edit: deny
  bash: deny
---
```

Source files **do not** contain a `model:` line — the model is the installer's choice, not the author's. Orchestra injects `model:` into the installed file at install time, reading from `config.yml`. The `model:` line appears in installed files (and is preserved through export and upgrade), but never in source files.

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
├── orchestra-manifest.sh        # Standalone source manifest generator
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
│       ├── fork.sh              # detach an installed package from its source
│       ├── list.sh             # list/search/info query commands
│       ├── status.sh           # package lockfile/filesystem audit
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
├── sources.yaml                # Your configured sources and subscription baselines
├── pkg.lock.yaml               # Installed package ledger (package, source, SHA, paths, fork state)
├── pkg-cache/                  # Fetched manifests + HEAD SHAs
├── config.yml                  # Default model choices for agents
└── .manifest                   # Last export output list
```

These files are generated locally and should not be committed. The `.gitignore`
shipped with Orchestra contains rules relative to the `.orchestra/` directory,
where Orchestra is normally cloned.

## Tab completion

Source the completion file in your shell:

```bash
source .orchestra/completion/orchestra-completion.bash
```

Add it to your `~/.bashrc` or `~/.zshrc` for persistence.
