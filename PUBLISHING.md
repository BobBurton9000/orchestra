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

### Comments and blank lines

Lines starting with `#` are comments. Blank lines are ignored. Use them to group packages visually (e.g. `  # --- Agents ---`).

## Generating the manifest automatically

Run Orchestra's generator in your source repo root:

```bash
orchestra generate-manifest /path/to/your/source/repo
```

This scans for `agents/*.agent.md`, `prompts/*.prompt.md`, `prompts/snippets/`, and `skills/*/SKILL.md`, then writes `orchestra-source.yaml`. Re-run it whenever you add or remove packages.

If Orchestra is installed in a project, you can invoke it via:

```bash
.orchestra/orchestra.sh generate-manifest /path/to/your/source/repo
```

## Publishing workflow

1. **Create a GitHub repository** (public or private — private works if users are authenticated via `gh auth login`).

2. **Add your content** using the conventional layout:
   ```
   my-source/
   ├── orchestra-source.yaml
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

3. **Generate the manifest** (or hand-write it):
   ```bash
   orchestra generate-manifest .
   ```

4. **Commit and push**:
   ```bash
   git add -A
   git commit -m "Initial Orchestra source"
   git push
   ```

5. **Tell others to add your source**:
   ```bash
   orchestra source add <your-github-username>/<your-repo>
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

## Reference example

The [`orchestra-defaults`](https://github.com/BobBurton9000/orchestra-defaults) repository is the default `core` source and the canonical example of a source layout. Browse it to see the manifest format and directory structure in practice.

## Tips

- **Keep package names stable.** Renaming a package in the manifest effectively creates a new package; users with the old name locked will need to `remove` and `install` the new one.
- **Don't break installed paths.** If you move a file within your repo, update the manifest path. Users who upgrade will get the file at the new path; the old file at the old path becomes orphaned (Orchestra's `remove` uses the lockfile, not the current manifest, so it will still clean up correctly).
- **Use `prompt-dir` for snippet collections.** If you have prompt helper files that aren't standalone prompts, bundle them as a `prompt-dir` package so they install into `.agents/orchestra/prompts/<name>/`.