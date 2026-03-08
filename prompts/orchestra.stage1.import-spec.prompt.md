---
agent: orchestrator
description: Convert a source document to a normalised story
argument-hint: "Paste a url, attach a document to the chat or add some text"
---
# Variables
`<branch-name>` = [branch-name](orchestra.snippets/branch-name.md)

# Goal
Turn a raw feature source (URL, requirement text, PBI, user story, or bug report) into a high-clarity, testable story document by coordinating and consulting specialist agents, then producing one final merged story.

# Invocation Pattern
This prompt is executed with a URL, free-form requirements text argument or an attached document.

- Example structure of URL import: `<this-command> <url>`
- Example  structure of free-form argument: `<this-command> <freeform requirements text>`
- Example structure of attached document: `<this-command>`

Inference rules:
1. If invocation contains an `http://` or `https://` URL, treat first URL as canonical source.
2. If invocation contains an attached file, treat that file as the canonical source.
3. If invocation also contains extra text, treat that text as supplemental context.
4. If nothing usable is provided, return `ERROR: no source content provided`.

## URL Source Resolution Policy
When the canonical source is a URL, prefer structured MCP-backed retrieval before generic page fetching.

1. If the URL is GitHub (`github.com`), try to use GitHub MCP or GitHub API tools first to fetch the issue, pull request, discussion, or other repository-backed details when those tools are available.
2. If the URL is Azure DevOps (`dev.azure.com` or `visualstudio.com`), try to use Azure DevOps MCP first to fetch the work item, ticket, backlog item, or other structured details when that MCP is available.
3. If structured MCP retrieval is unavailable, unsupported for the specific URL, or fails to return usable source content, fall back to normal URL/web fetching.
4. When MCP retrieval succeeds, prefer the MCP result as the canonical source and treat any fetched HTML page only as supporting context.

# Required Outcomes
1. Create a local raw copy of the source at `ai/orchestra/documents/<branch-name/story.source.md`.
2. Produce one normalised story file at `ai/orchestra/documents/<branch-name>/story.md` using the [story.template](orchestra.templates/story.template.md).
3. Define at least 3 acceptance criteria that are explicit and testable.
4. Define at least 1 failure
5. Resolve all uncertainties into explicit decisions before finalising.
6. No vague terms (`fast`, `simple`, `robust`, `user-friendly`) are contained within the template without measurable meaning
7. All sections of the template have been populated

# Steps
1. **Read** the [story.template](orchestra.templates/story.template.md) and determine what information you need to acquire to create a comprehensive story document. 
2. **Import Source**: Ensure `ai/orchestra/documents/<branch-name>/` directory exists
3. **Consult specialist sub agents**: Use all available applicable sub agents to acquire information needed to complete the document
4. **Merge and resolve sub agents input**: Merge specialist outputs into one coherent story
5. **Recursive gap-closure loop (required)**: Return to step 3 in this step plan repeatedly until all ambiguities are resolved into explicit decisions. The maximum number of times you can (and must, if required) loop is specified in [loop-count](../config/loop-count.md).
6. **Apply decision policy**: Use the [decision policy](orchestra.snippets/orchestrator-decision-policy.md) whenever evidence is incomplete or specialist inputs still conflict
7. **Submit completion to judge sub agent**: Follow [submit-to-judge](orchestra.snippets/submit-to-judge.md)


# Response To User
```
Branch: <branch-name>
Imported Source: ai/orchestra/documents/<branch-name/story.source.md
Generated Story: ai/orchestra/documents/<branch-name>/story.md
Acceptance Criteria: <number of acceptance criteria>
```