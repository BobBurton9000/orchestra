# Publishing an Orchestra Source

An Orchestra source is a GitHub repository with an `orchestra-source.yaml` file at its root. Anyone can publish one. This guide walks through the format and the publishing workflow.

## The source manifest: `orchestra-source.yaml`

This file lives at the root of your source repo and lists every package you offer. Format:

```yaml
packages:
  - name: triage-agent
    type: agent
    path: agents/triage-agent.agent.md
  - name: my-skill
    type: skill
    path: skills/my-skill/
  - name: my-prompt
    type: prompt
    path: prompts/my-prompt.prompt.md
  - name: snippets
    type: prompt-dir
    path: prompts/snippets/
```

- **`name`** — the name users type in `orchestra install <name>`. Must be unique within your source.
- **`type`** — one of `agent`, `prompt`, `prompt-dir`, `skill`.
- **`path`** — relative to the repo root. For `agent` and `prompt`, this is a single file. For `skill` and `prompt-dir`, this is a directory — every file in it is installed.

### Package types

| Type | What it installs | Path points to |
|------|------------------|----------------|
| `agent` | A single `*.agent.md` file → `.agents/orchestra/agents/` | A file |
| `prompt` | A single `*.prompt.md` file → `.agents/orchestra/prompts/` | A file |
| `prompt-dir` | All files in the directory → `.agents/orchestra/prompts/<name>/` | A directory |
| `skill` | All files in the directory → `.agents/orchestra/skills/<name>/` | A directory (must contain `SKILL.md`) |

### Agent frontmatter: no `model:` line

Agent source files should **not** contain a `model:` line in their frontmatter. The model is the installer's choice, not the author's. Orchestra injects `model:` into the installed file at install time, reading from the user's `config.yml`. This means the same agent definition can be run on different models by different developers without any edits to the shared source file.

### Comments and blank lines

Lines starting with `#` are comments. Blank lines are ignored. Use them to group packages visually (e.g. `  # --- Agents ---`).

## Generating the manifest automatically

A source repository does not need to contain a full Orchestra installation.
Download the standalone manifest tool once in the source repo root:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/BobBurton9000/orchestra/master/orchestra-manifest.sh \
  -o orchestra-manifest.sh
chmod +x orchestra-manifest.sh
```

Generate the manifest after adding or removing packages:

```bash
./orchestra-manifest.sh --force .
```

The tool scans for `agents/*.agent.md`, `prompts/*.prompt.md`,
`prompts/snippets/`, and `skills/*/SKILL.md`, then writes
`orchestra-source.yaml`. It needs only Bash and standard command-line
utilities; `gh` and `yq` are not required for source authoring.

The committed tool can update itself from the latest Orchestra `master` copy:

```bash
./orchestra-manifest.sh --self-update --force .
```

Use `--check` in CI to reject a stale manifest without changing it:

```bash
./orchestra-manifest.sh --check .
```

If Orchestra is installed in a project, the equivalent command is:

```bash
.orchestra/orchestra.sh generate-manifest --force /path/to/your/source/repo
```

## Publishing workflow

1. **Create a GitHub repository** (public or private — private works if users are authenticated via `gh auth login`).

2. **Add your content** using the conventional layout:
   ```
   my-source/
   ├── orchestra-source.yaml
   ├── orchestra-manifest.sh
   ├── agents/
   │   └── triage-agent.agent.md
   ├── prompts/
   │   ├── my-prompt.prompt.md
   │   └── snippets/
   │       └── helper.md
   └── skills/
       └── my-skill/
           ├── SKILL.md
           └── helper.md
   ```

3. **Generate the manifest**:
    ```bash
    ./orchestra-manifest.sh --force .
    ```

4. **Commit and push**:
   ```bash
   git add -A
   git commit -m "Initial Orchestra source"
   git push
   ```

   If you installed one of your source packages into another project and edited
   it there, use Orchestra to publish the tracked package files back instead of
   copying them manually:
   ```bash
   orchestra fork <package>
   "$EDITOR" .agents/orchestra/...
   orchestra push <package>
   ```
   This requires push permission for the original GitHub repository. The
   default mode creates a branch and pull request; use `--direct` only when you
   want to update the repository's default branch immediately.

5. **Tell others to add your source**:
   ```bash
   orchestra source add <your-github-username>/<your-repo>
   ```

   Users who want newly published packages installed automatically can opt in
   after adding the source:
   ```bash
   orchestra source subscribe <source-name>
   ```

   They can give it a custom name if they prefer:
   ```bash
   orchestra source add alice/my-source alices-extras
   orchestra install triage-agent@alices-extras
   ```

## Versioning

There are no static version numbers. A package's "version" is the commit SHA of your source repo's HEAD at install time. When you push new commits, users who run `orchestra update` will see their locked SHA differ from your new HEAD, and `orchestra upgrade` will pull the latest.

This means:
- **No version bumping** — just push commits.
- **No releases or tags required** — though you can use them if you want.
- **Users control when to upgrade** — `orchestra upgrade` is opt-in.
- **Subscriptions are opt-in** — subscribing installs only packages added to
  the source after the subscription baseline. Existing packages still require
  an explicit install or `orchestra install --all <source>`.

## Reference example

The [`orchestra-defaults`](https://github.com/BobBurton9000/orchestra-defaults) repository is the default `core` source and the canonical example of a source layout. Browse it to see the manifest format and directory structure in practice.

## Tips

- **Keep package names stable.** Renaming a package in the manifest effectively creates a new package; users with the old name locked will need to `remove` and `install` the new one.
- **Don't break installed paths.** If you move a file within your repo, update the manifest path. Users who upgrade will get the file at the new path; the old file at the old path becomes orphaned (Orchestra's `remove` uses the lockfile, not the current manifest, so it will still clean up correctly).
- **Use `prompt-dir` for snippet collections.** If you have prompt helper files that aren't standalone prompts, bundle them as a `prompt-dir` package so they install into `.agents/orchestra/prompts/<name>/`. They are not exported as separate platform files; reference them with `#include` in a prompt definition to inline their content at export time.
