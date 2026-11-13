# Orchestra

Orchestra is a universal format and package manager for AI coding agents, prompts, and skills. Write definitions once in Orchestra's canonical format, then export to GitHub Copilot, OpenCode, or Pi (Pi exports prompts and skills) — the format translates, the model stays yours. Share definitions via GitHub sources like apt packages; each developer installs what they need and picks their own models.

Although Orchestra works for standalone agents, it's built around an orchestration workflow where an Orchestrator agent delegates to a team of specialised subagents — and automatically becomes aware of new agents as you install them.

The Orchestra program can be cloned wherever you choose. Each project keeps installed definitions in `.agents/orchestra/` and manager state in `.agents/orchestra/.state/`. You control whether those project files are committed or ignored.

## What Orchestra does

### 1. A universal format for agents and prompts

Every Orchestra definition is a markdown file with YAML frontmatter using a small set of canonical keys. Orchestra handles platform dialect differences for the resource types each target supports.

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

When you run `export copilot`, `export opencode`, or `export pi`, Orchestra compiles the applicable definitions (resolving `#include` directives and extracting sections), transforms agent frontmatter, and emits the prompt metadata supported by each target. Add `agents`, `prompts`, or `skills` to export only that type. Copilot prompt frontmatter is copied verbatim:

| Canonical | OpenCode | Copilot | Pi |
|-----------|----------|---------|----|
| `mode: primary` (agent) | `mode: primary` | *(omitted — visible by default)* | Agent definitions not exported |
| `mode: subagent` (agent) | `mode: subagent` | `user-invocable: false` | Agent definitions not exported |
| `variant:` (agent) | Preserved | Stripped | Agent definitions not exported |
| `permission:` block (agent) | Preserved | Stripped | Agent definitions not exported |
| `model:` (agent) | Preserved | Preserved | Agent definitions not exported |
| `agents:` list (agent) | *(not output)* | Preserved | Agent definitions not exported |
| Filename `.agent.md` | Stripped → `name.md` | Kept as `name.agent.md` | Not exported |
| Filename `.prompt.md` | Stripped → `name.md` | Kept as `name.prompt.md` | Stripped → `.pi/prompts/name.md` |
| Prompt `handoffs:` | Stripped | Preserved | Stripped |
| Prompt `agent:` | Preserved (except `agent: agent`) | Preserved verbatim | Stripped |
| Prompt `argument-hint:` | Stripped | Preserved | Preserved |

Pi exports prompts as project slash commands under `.pi/prompts/` and skills under the shared `.agents/skills/` directory. It does not export Orchestra agent definitions. Pi loads project prompts after project trust is granted.

`convert` maps supported agent fields from Copilot or OpenCode back into Orchestra definitions. It converts agents only (not prompts) and omits `model:` because models are user-specific, so it is not a lossless import of arbitrary platform metadata. See [How it works — Export](#export) and [Convert](#convert-existing-agents--definitions) for details.

### 2. A package manager for shareable definitions

Orchestra is inspired by `apt`. Sources are GitHub repositories with an `orchestra-source.yaml` manifest at their root. You add sources, install packages from them, and lock versions to a specific commit SHA.

The sharing model is simple: **authors publish markdown definitions without a model; each developer picks their own.** Source files never contain a `model:` line. When you install an agent, Orchestra reads `config.yml` for your default model choices and injects the model into the installed file's frontmatter. One developer runs `architect` on Claude; another runs it on GPT — same source definition, different models, no edits to the shared file. Upgrades preserve your model choice — the upgraded file inherits the model from your previously installed file, not from `config.yml`.

```yaml
# .agents/orchestra/.state/config.yml
orchestrator: ollama-cloud/qwen3.5:397b
subagent: ollama-cloud/glm-5.1
```

Packages are versioned by their source repo's HEAD commit SHA — there are no static version numbers to bump. `orchestra update` refreshes cached manifests and HEAD SHAs; `orchestra upgrade` compares installed lockfile SHAs with those cached SHAs and installs newer package revisions. Run `update` first to refresh all sources; bulk `upgrade` refreshes subscribed sources automatically.

### 3. An orchestration workflow

Orchestra is built around an orchestration model, though it's not mandatory. The centrepiece is the **Orchestrator** agent — a `mode: primary` agent that delegates every unit of work to the specialised subagent best suited to carry it out. The Orchestrator never does direct work itself; it coordinates, reviews, and iterates.

The default `core` source ([`orchestra-defaults`](https://github.com/BobBurton9000/orchestra-defaults)) provides the Orchestrator, a changing catalog of specialist agents, prompts, and skills. See its [source manifest](https://github.com/BobBurton9000/orchestra-defaults/blob/master/orchestra-source.yaml) for the current package list; install only what you want.

**Auto-discovery:** When you `export opencode`, every installed agent lands in `.opencode/agents/`. OpenCode discovers all agents in that directory. The Orchestrator can delegate to any `mode: subagent` agent it finds — no explicit allowlist needed. Install a new agent, re-export, and the Orchestrator is automatically aware of it. The same applies to Copilot (`.github/agents/*.agent.md`).

The workflow loop: **delegate → implement → review → iterate.** The Orchestrator delegates a task, the subagent implements it, code-review agents review the change, a scope-guard checks boundaries, and the cycle continues until the task is complete. See [The Orchestration Workflow](#the-orchestration-workflow) below for detail.

## Setup

Clone Orchestra into any stable directory you choose. For example:

```bash
git clone https://github.com/BobBurton9000/orchestra.git "$HOME/.local/share/orchestra"
```

Add a Bash function to `~/.bashrc`, using the path where you cloned the repository:

```bash
orchestra() {
  "$HOME/.local/share/orchestra/orchestra.sh" "$@"
}
```

Reload your shell configuration (or start a new shell). The function forwards every argument, so commands such as `orchestra update` and `orchestra install my-skill` work from your project directory.

The first state-managing command initializes project state under `.agents/orchestra/.state/`. `orchestra update` creates a default `sources.yaml` pointing at the [`orchestra-defaults`](https://github.com/BobBurton9000/orchestra-defaults) source and refreshes its catalog. You can then install packages:

```bash
cd /path/to/your/project
orchestra update && orchestra install orchestrator
```

Orchestra does not change your project's `.gitignore`. Add `.agents/orchestra/.state/` or `.agents/orchestra/` there if your team wants the state or definitions ignored; leave the relevant paths unignored and commit them if your team wants to share them.

To migrate an existing project, run `orchestra migrate v2` from that project using the new Orchestra command. It copies legacy state from `.orchestra/` without overwriting files. Conflicts must be resolved before cleanup; once migration completes, the command asks before deleting a recognized old Orchestra checkout in `.orchestra/`.

## Requirements

Orchestra depends on three things:

- **`gh`** — GitHub CLI, for fetching packages and manifests from source repos. Install from [cli.github.com](https://cli.github.com) and run `gh auth login`.
- **`yq`** — YAML processor, for reading and writing Orchestra's data files. Install [mikefarah/yq](https://github.com/mikefarah/yq) (Go) or [kislyuk/yq](https://github.com/kislyuk/yq) (Python).
- **Bash 4.3+** (required for nameref support)
- **Git** is also required if you use `push`.

## Quick start

Install the Orchestrator and a couple of subagents, then export to both agent platforms:

```bash
orchestra update
orchestra install orchestrator
orchestra install architect
orchestra install debugger

orchestra export opencode
orchestra export copilot
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
orchestra install <pkg>[@<source>]       # install a single package
orchestra install <pkg> --locked         # fetch at lockfile SHA (package metadata from cache)
orchestra install --all <source>         # install every package from one source
orchestra update                          # refresh all source manifests + HEAD SHAs
orchestra upgrade [pkg]                  # upgrade to cached source HEADs (run update to refresh)
orchestra remove <pkg>                   # remove a package (files + lockfile entry)
orchestra fork <pkg>                     # detach a package for local edits
orchestra push <pkg> [options]            # publish forked edits to the source repo
```

### Sources

```bash
orchestra source add <owner/repo> [name] # add a source + fetch its manifest
orchestra source subscribe <name>       # install future packages from a source on upgrade
orchestra source unsubscribe <name>     # stop installing future packages
orchestra source list                    # show configured sources
orchestra source remove <name>           # remove a source (refuses while non-forked packages use it)
```

### Migrate existing projects

```bash
orchestra migrate v2
```

Run this from a project that still has the old `.orchestra/` checkout, using the new Orchestra command installed elsewhere. It copies known project state into `.agents/orchestra/.state/` without overwriting. Identical destination files are treated as already migrated; differing files are reported and left untouched. Resolve conflicts and rerun the command. After a conflict-free migration, Orchestra asks before deleting a recognized old checkout (`ORCHESTRA_YES=1` auto-confirms). It leaves an unrecognized `.orchestra/` directory in place.

### Query

```bash
orchestra list                           # installed packages
orchestra list --available               # all packages across all sources
orchestra search <term>                  # search by name/type/path
orchestra info <pkg>                     # details for a package (installed or available)
orchestra status                         # audit package paths and orphaned files
```

### Platform compatibility

```bash
orchestra export copilot|opencode|pi [agents|prompts|skills] # compile selected definitions
orchestra convert copilot|opencode [name] # convert existing platform agents → Orchestra definitions
```

### Publishing (for source authors)

```bash
orchestra generate-manifest [dir]        # scan a directory, emit orchestra-source.yaml
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
orchestra                                 # usage
orchestra help [command]                  # per-command help
orchestra --version
```

## How it works

### Status

Use `status` to audit the local definition directory against the package
lockfile:

```bash
orchestra status
```

The report shows each locked package, its source, type, SHA, and installed
paths. It also identifies locked paths that are missing from disk and files
under `.agents/orchestra/` that are not part of any locked package. This is a
local read-only check; it does not refresh source indexes or modify state.

### Install

```bash
orchestra install orchestrator           # agents/orchestrator.agent.md
orchestra install writing-gherkin        # skills/writing-gherkin/SKILL.md
orchestra install commit                 # prompts/commit.prompt.md
orchestra install triage-agent@extras    # from a specific source
```

- Fetches the package at the source HEAD SHA recorded in the local cache via `gh api`. Run `update` first if you need to refresh that cache.
- For agents: source files have no `model:` line. Orchestra injects the model from `config.yml` into the installed file's frontmatter. If `config.yml` is missing, you are prompted once and the choice is saved.
- Records the package, source, source repository/path, type, SHA, and installed file paths in `pkg.lock.yaml`
- Asks before overwriting an existing file (set `ORCHESTRA_YES=1` to auto-confirm)

### Update + upgrade

```bash
orchestra update        # refresh all source manifests + HEAD SHAs
orchestra upgrade       # upgrade all installed packages to cached HEADs
orchestra upgrade orchestrator   # upgrade one package to its source's cached HEAD
```

Bulk `upgrade` refreshes subscribed sources, but other sources use their cached HEAD until you run `update`. Targeted `upgrade <pkg>` also uses the cached HEAD (refreshing only if no cache exists). Upgrades preserve your model choice — the upgraded file inherits the model from your previously installed file, not from `config.yml`. If you change your mind about a model, re-install the package fresh (`remove` then `install`).

If an updated multi-file package no longer contains files recorded in its lock entry, Orchestra asks what to do with each existing stale file: remove it, keep it as a local untracked file, or cancel that package's upgrade. Pressing Enter keeps the file. Kept files are omitted from the new lock entry. Orchestra does not distinguish locally edited files; review each path before choosing removal. `ORCHESTRA_YES=1` removes stale files automatically. Without a TTY or `ORCHESTRA_YES=1`, that package's upgrade is aborted rather than guessing (and counted as skipped during bulk upgrades). Canceling leaves the package files and lock entry unchanged; bulk upgrades continue with other packages. Upgrade changes are rolled back if applying a package upgrade fails. If a package disappears from the source manifest entirely, the same choices apply to all of its existing locked paths; after resolution, its lock entry is removed and any kept files are untracked. If none of its files exist locally, the lock entry is removed without prompting. Bulk upgrade reports these packages in a separate “removed from sources” count.

### Fork

```bash
orchestra fork orchestrator
```

Forking keeps the installed files and their lockfile entry, but marks the
package as detached from future source upgrades. The original source and SHA
remain recorded for provenance, while both targeted and bulk `upgrade` leave
the fork unchanged. Edit the files under `.agents/orchestra/` directly, then
run the existing `export` command when platform output needs refreshing.

Forked packages remain managed by `status` and can still be removed. Running `install` for the same package explicitly reattaches it to the source.

### Push

Publish edits from a forked package back to its original GitHub repository:

```bash
orchestra fork writing-gherkin
"$EDITOR" .agents/orchestra/skills/writing-gherkin/...
orchestra push writing-gherkin
```

`push` requires GitHub push permission for the recorded source repository. It
clones the repository into a temporary checkout, verifies that the source files
have not changed since installation, strips the user-specific `model:` field
from agents, and creates a branch and pull request. Use `--direct` to push to
the source repository's default branch, or `--dry-run` to inspect the staged
diff without committing or pushing. Existing package files must remain tracked;
new or deleted files are rejected for now. Pull-request pushes leave the package
forked after the pull request is created. Merging the pull request does not
update the local lockfile automatically; re-install the package after merge to
reattach it. Direct pushes update its lockfile SHA and reattach it to the source.

### Subscribing to a source


Adding a source makes its packages available for explicit installation. It does not automatically install the source's existing packages or future packages.

To receive assets added to a source in future bulk upgrades:

```bash
orchestra source add alice/orchestra-extras extras
orchestra source subscribe extras
orchestra upgrade
```

`source subscribe` records the source manifest at that point as a baseline. A later `upgrade` refreshes subscribed sources and installs only package names added after that baseline. Existing packages are left under normal lockfile control, and `upgrade <pkg>` remains a targeted upgrade without subscription discovery. Use `install --all <source>` when you also want the source's current packages.

Unsubscribing stops future automatic installs but does not remove packages already installed:

```bash
orchestra source unsubscribe extras
```

### Remove

```bash
orchestra remove writing-gherkin
```

Deletes every file recorded in the lockfile entry, then removes the lockfile entry. `remove` is the same as `purge` — there is no separate "keep config" step.

### Export

```bash
orchestra export copilot                # → .github/agents/ + .github/prompts/ + .agents/skills/
orchestra export copilot prompts        # only prompts → .github/prompts/
orchestra export copilot agents         # only agents → .github/agents/
orchestra export opencode skills        # only skills → .agents/skills/
orchestra export pi                     # → .pi/prompts/ + .agents/skills/ (no agents)
orchestra export pi prompts             # only prompts → .pi/prompts/
```

With no type selector, export processes every type supported by the platform. Add one selector—`agents`, `prompts`, or `skills`—to export only that type. For example, Pi supports prompts and skills, but not agents.

What happens:
1. Applicable definitions in `.agents/orchestra/` are compiled (`#include` directives resolved, headings extracted); a type selector limits this to that type
2. Compiled output lands in `.agents/orchestra/.state/.temp/`
3. Frontmatter is transformed to the target platform's format (see the [transformation table](#1-a-universal-format-for-agents-and-prompts) above)
4. Output files are staged
5. Skills are compiled and staged in `.agents/skills/` when exporting all types or selecting `skills`
6. The managed output directories for the export are replaced to match the selected definitions; stale and manually added files in those directories are removed. A type-filtered export leaves other types' output directories untouched, and other platform outputs are always untouched.
7. A `.agents/orchestra/.state/.manifest` file lists the outputs from the latest export only, and `.agents/orchestra/.state/.temp/` is removed

All outputs are staged before export changes existing files. A missing `.agents/orchestra/` directory is an error. An existing but empty directory clears the selected platform outputs on a full export, or only the selected type's output on a filtered export. The managed directories are then replaced one at a time, so the multi-directory update is not a single atomic transaction. Prompt-directory package files are not copied as standalone outputs on any platform; they are included when referenced by `#include` in an exported prompt.

### Convert (Existing Agents → Definitions)

If you already have agents installed for Copilot or OpenCode, convert them back into Orchestra definitions:

```bash
orchestra convert copilot              # all .github/agents/*.agent.md
orchestra convert copilot architect    # single agent
orchestra convert opencode             # all .opencode/agents/*.md
orchestra convert opencode architect   # single agent
```

Conversion handles supported agent metadata, but drops `model:` and does not preserve arbitrary platform-specific fields. Output lands in `.agents/orchestra/agents/`; it asks before overwriting.

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

- Paths are relative to the project root (the directory containing `.agents/orchestra/`). A leading `~` expands to the home directory.
- `:#Section Name` injects everything under that heading until the next same-or-higher-level heading
- `:##Sub Section` injects everything under that sub-heading
- Includes can nest — included files can include other files
- Every include is validated at export time; missing files or headings cause a hard error
- Exports compile into `.agents/orchestra/.state/.temp/` and stage outputs before replacing managed platform directories. A compile failure leaves existing outputs untouched; replacing multiple output directories is sequential, not one atomic transaction.
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
3. **Review** — applicable code-review agents (for example, `code-review.bugs`, `code-review.maintainability`, and `code-review.solid`) review each change batch. Reviewers are selected by remit; agents limited to another language or domain are not included.
4. **Scope-check** — a scope-guard agent checks whether proposed follow-up work is still in scope.
5. **Adjudicate** — when claims conflict or evidence is ambiguous, a judge agent provides an independent decision.
6. **Iterate** — the cycle repeats until the originally approved task is complete. The Orchestrator does not widen scope because an agent proposes adjacent improvements.

### Skills

Skills are best-practice reference files that agents load at the start of a task. The Orchestrator instructs each delegate to load the skills relevant to its remit before starting work. Skills live in `.agents/skills/` after export and are discovered by the platform.

### When you don't want orchestration

The orchestration workflow is not mandatory. You can install a single agent (e.g. `architect`) and use it directly as a standalone definition — export it to your platform and invoke it yourself. The Orchestrator is just another package; install it only if you want the delegation model. Prompts and skills work the same way — install what you need, export, and use.

## Collaboration

Orchestra is built for sharing. Anyone can publish a source — it's just a GitHub repo with an `orchestra-source.yaml` at the root. See [`PUBLISHING.md`](PUBLISHING.md) for the format and a step-by-step guide.

Package choice can be personal or shared, depending on your team. Orchestra does not modify `.gitignore`: ignore `.agents/orchestra/.state/` (or the whole `.agents/orchestra/` directory) for per-developer state, or leave it unignored to commit and sync shared choices.

## Repository Layout

Clone Orchestra into any stable location you choose. The program files stay together there:

```
<chosen-install-dir>/
├── orchestra-manifest.sh        # Standalone source manifest generator
├── orchestra.sh                # Single CLI entry point — all commands
├── scripts/
│   ├── common.sh               # Shared frontmatter/heading parsing utilities
│   ├── compile.sh              # Recursive #include resolver + section extraction
│   └── pkg/                    # Package manager implementation
│       ├── cli.sh              # Subcommand routing + usage
│       ├── pkg-common.sh       # Shared helpers, constants, lockfile paths
│       ├── yaml-helpers.sh     # YAML read/write helpers (yq-backed)
│       ├── ghutil.sh           # GitHub auth, repository, and manifest helpers
│       ├── sources.sh          # sources.yaml parsing + add/remove/list
│       ├── index.sh            # Manifest fetch + cache via gh api
│       ├── install.sh          # install + lockfile + model prompt logic
│       ├── upgrade.sh          # upgrade installed packages to cached source HEADs
│       ├── uninstall.sh        # remove (deletes files + lockfile entry)
│       ├── fork.sh              # detach an installed package from its source
│       ├── push.sh              # publish forked package edits to GitHub
│       ├── list.sh             # list/search/info query commands
│       ├── status.sh           # package lockfile/filesystem audit
│       ├── manifest.sh         # generate-manifest for source authors
│       ├── migrate.sh          # project-state migration from legacy layouts
│       ├── export.sh           # export subcommand (compile → platform output)
│       └── convert.sh          # convert subcommand (platform → Orchestra defs)
├── completion/
│   └── orchestra-completion.bash   # Bash tab completion (requires bash-completion)
└── tests/                      # Test suite
```

Project definitions and manager state remain separate from the program installation:

```
.agents/orchestra/
├── agents/                     # Agent definitions
├── prompts/                    # Prompt definitions
├── skills/                     # Skill definitions
└── .state/
    ├── sources.yaml            # Configured sources and subscription baselines
    ├── pkg.lock.yaml           # Installed package ledger (source provenance, SHA, paths, fork state)
    ├── pkg-cache/              # Fetched manifests + HEAD SHAs
    ├── config.yml              # Default model choices for agents
    └── .manifest               # Last export output list
```

Orchestra does not decide whether project data is committed. Ignore `.agents/orchestra/.state/` or the whole `.agents/orchestra/` directory for per-developer state; leave the relevant paths unignored and commit them if your team wants to sync shared choices.

## Tab completion

The completion script uses Bash's `_init_completion` helper, provided by the `bash-completion` package. After loading that package, source the completion file from your chosen Orchestra installation. For example, add this to `~/.bashrc`:

```bash
source "$HOME/.local/share/orchestra/completion/orchestra-completion.bash"
```

Replace the example path with your chosen install location.
