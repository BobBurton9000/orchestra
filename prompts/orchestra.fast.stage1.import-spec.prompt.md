---
agent: orchestrator
description: Convert a source document to a normalised story with a lightweight stage 1 flow
argument-hint: "Paste a url, attach a document to the chat or add some text"
---
# Goal
Create one clear story for the current branch from the provided source, using the story template and whatever specialist help is useful, without prescribing a heavy workflow.

# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Invocation Pattern
This prompt is executed with a URL, free-form requirements text argument or an attached document.

- Example structure of URL import: `<this-command> <url>`
- Example structure of free-form argument: `<this-command> <freeform requirements text>`
- Example structure of attached document: `<this-command>`

Inference rules:
1. If invocation contains an `http://` or `https://` URL, treat the first URL as the canonical source.
2. If invocation contains an attached file, treat that file as the canonical source.
3. If invocation also contains extra text, treat that text as supplemental context.
4. If nothing usable is provided, return `ERROR: no source content provided`.

# Required Outcomes
1. A local raw copy of the source was created at `.agents/orchestra/<branch-name>/story.source.md`.
2. One normalised story file was produced at `.agents/orchestra/<branch-name>/story.md` using the [story.template](orchestra.templates/story.template.md).
3. The stage marker file at `.agents/orchestra/<branch-name>/current-stage.md` was created to identify stage 1 as the current branch stage.
4. The story was concrete, testable, and fully populated.
5. `Open Questions` or equivalent uncertainty was resolved into explicit decisions whenever repository or source evidence was sufficient.

# Steps
1. Resolve the provided source content. If nothing usable is provided, return `ERROR: no source content provided`.
2. Ensure `.agents/orchestra/<branch-name>/` exists and save the canonical source to `.agents/orchestra/<branch-name>/story.source.md`.
3. Create `.agents/orchestra/<branch-name>/current-stage.md` with exactly the following content:

	```md
	# Current Stage

	Stage: 1
	Prompt: orchestra.fast.stage1.import-spec
	Name: Import Spec
	```
4. Read [story.template](orchestra.templates/story.template.md) and use it as the required structure for `.agents/orchestra/<branch-name>/story.md`.
5. Produce one clear story with explicit acceptance criteria, failure modes, constraints, and decisions. Consult specialist agents when helpful.
6. Resolve ambiguity conservatively from the source and repository evidence rather than leaving vague language in the story.
7. Submit completion to the judge sub agent: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)

# Response To User
```
Branch: <branch-name>
Imported Source: .agents/orchestra/<branch-name>/story.source.md
Generated Story: .agents/orchestra/<branch-name>/story.md
Acceptance Criteria: <number>
```