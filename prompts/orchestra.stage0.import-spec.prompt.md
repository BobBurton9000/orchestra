---
agent: orchestrator
description: Import a ticket, bug report, requirement, or document into the .gherkin workspace by creating and adjusting source-like Gherkin from external or inline source material
name: orchestra.stage0.import-spec
argument-hint: "Paste a url, attach a document to the chat, or add inline source text"
---

# Goal
Turn a raw feature source such as a ticket, bug report, requirement, user story, URL, or attached document into target-state Gherkin changes under `./.gherkin`.

This prompt is the source-import entry point for the gherkin-driven flow. Its job is to translate supplied source material into concrete `.gherkin` file changes that can later be captured by [orchestra.stage1.prep](orchestra.stage1.prep.prompt.md).

The `.gherkin` tree must follow [source-like-gherkin](orchestra.snippets/source-like-gherkin.md).

The created or updated `.feature` files must contain only plain Gherkin.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Invocation Pattern
This prompt is executed with a URL, free-form requirements text argument, or an attached document.

- Example structure of URL import: `<this-command> <url>`
- Example structure of free-form argument: `<this-command> <freeform requirements text>`
- Example structure of attached document: `<this-command>`

Inference rules:
1. If invocation contains an `http://` or `https://` URL, treat the first URL as the canonical source.
2. If invocation contains an attached file, treat that file as the canonical source.
3. If invocation also contains extra text, treat that text as supplemental context.
4. If nothing usable is provided, return `ERROR: no source content provided`.

## URL Source Resolution Policy
When the canonical source is a URL, prefer structured MCP-backed retrieval before generic page fetching.
1. If the URL is GitHub (`github.com`), try to use GitHub MCP or GitHub API tools first to fetch the issue, pull request, discussion, or other repository-backed details when those tools are available.
2. If the URL is Azure DevOps (`dev.azure.com` or `visualstudio.com`), try to use Azure DevOps MCP first to fetch the work item, ticket, backlog item, or other structured details when that MCP is available.
3. If structured retrieval is unavailable, unsupported for the specific URL, or fails to return usable source content, fall back to normal URL or web fetching.
4. When structured retrieval succeeds, prefer that result as the canonical source and treat fetched HTML only as supporting context.

# Required Outcomes
1. A local raw copy of the imported source was created at `.agents/orchestra/<branch-name>/gherkin-import.source.md`.
2. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was created or updated to identify stage 0 as the current branch stage.
3. The project-root `./.gherkin` tree exists after execution.
4. One or more `.feature` files under `./.gherkin` were created, updated, renamed, or deleted only when that change was directly supported by the supplied source and existing repository context.
5. Existing `.gherkin` files were inspected before writing so materially equivalent scenarios were merged or adjusted instead of duplicated.
6. Every created or updated `.feature` file follows [source-like-gherkin](orchestra.snippets/source-like-gherkin.md) and contains only plain Gherkin.
7. The resulting `.gherkin` diff represents the intended target state for the task, bug, or requirement without inventing unsupported behaviour.
8. Material ambiguities were resolved into explicit Gherkin decisions before finalising the target-state diff.
9. If the supplied source is too incomplete to justify a `.gherkin` change, the prompt returns a concrete error or no-op status instead of fabricating scenarios.

# Import Rules
1. Capture only behaviour that is explicit in the supplied source or already established by repository context needed to preserve consistency.
2. Prefer updating the narrowest existing owning `.feature` file when the source changes behaviour that is already documented.
3. Create a new `.feature` file only when no existing file cleanly owns the behaviour.
4. Remove or rewrite outdated scenarios only when the supplied source clearly supersedes them. Do not delete unrelated behaviour.
5. Keep each scenario atomic, specific, and testable.
6. Every `Scenario:` or `Scenario Outline:` block must include at least one `Given`, one `When`, and one `Then`.
7. `Background:` is optional and may reduce repeated setup, but it does not replace the need for each scenario to include its own `Given`, `When`, and `Then`.
8. Use `And` and `But` only in addition to `Given`, `When`, and `Then`, never instead of them.
9. Do not embed Markdown links, inline file references, or other non-Gherkin markup inside `.feature` files.
10. Do not write prose notes, TODOs, implementation commentary, or acceptance-criteria summaries inside `.feature` files.

# Steps
1. Resolve the canonical source from the invocation, attachments, and supplemental text. If no usable source is available, return `ERROR: no source content provided`.
2. Ensure `.agents/orchestra/<branch-name>/` exists.
3. Create or update `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content:

	```md
	# Current Stage

	Stage: 0
	Prompt: orchestra.stage0.import-spec
	Name: Import Spec
	```
4. Persist the imported source and any supplemental context into `.agents/orchestra/<branch-name>/gherkin-import.source.md` so downstream stages can inspect the original material.
5. Read [source-like-gherkin](orchestra.snippets/source-like-gherkin.md) and inventory the current `./.gherkin` tree before deciding what to change.
6. Consult all applicable specialist sub agents to understand the source, affected boundaries, and likely owning `.gherkin` files.
7. Identify the smallest set of `.gherkin` files that should own the requested behaviour, bug fix, regression coverage, or requirement change.
8. Compare the source against existing scenarios in those files and determine which scenarios should be created, updated, merged, renamed, or removed.
9. Merge specialist input into one target-state Gherkin edit plan.
10. Recursive gap-closure loop (required): return to step 6 repeatedly until ambiguities that matter to the `.gherkin` target state are resolved into explicit decisions. The maximum number of times you can, and must when required, loop is specified in [loop-count](orchestra.config/loop-count.md).
11. Apply the [decision policy](orchestra.snippets/orchestrator-decision-policy.md) whenever evidence is incomplete or specialist inputs still conflict after the required gap-closure work.
12. Translate the supported behaviour into concrete Gherkin under `./.gherkin`, preserving unaffected existing behaviour and avoiding materially duplicate scenarios.
13. If the source conflicts with existing `.gherkin`, reconcile the conflict into one target-state version that best reflects the supplied source and repository context.
14. Keep the resulting `.gherkin` edits limited to the behaviour justified by the source. Do not broaden scope into adjacent speculative work.
15. Leave the repository with an uncommitted `.gherkin` diff that `orchestra.stage1.prep` can summarise as the canonical target-state Gherkin for the branch.
16. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Imported Source: .agents/orchestra/<branch-name>/gherkin-import.source.md
Gherkin root: ./.gherkin
Files created: <number>
Files updated: <number>
Files deleted: <number>
Paths: <comma-separated repository-relative paths>
Next prompt: orchestra.stage1.prep
Final status: <Imported|No changes required|Blocked|ERROR>
```