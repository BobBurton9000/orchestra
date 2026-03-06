---
name: orchestra.ado-import
description: 'Fetch and parse Azure DevOps work items through the ADO MCP tools. Use when asked to import a PBI, bug, task, or work item from an Azure DevOps URL, extract the work item ID or project, map work item fields, convert HTML fields to plain text or markdown, or summarise related items from work item relations.'
---

# Orchestra ADO Import

Use this skill when you need to turn an Azure DevOps work item URL or ID into structured data that can be consumed in a document, summary, plan, or implementation workflow.

## When to Use This Skill

- Import an Azure DevOps work item from a URL
- Fetch a PBI, bug, task, feature, or other work item with MCP
- Parse title, description, acceptance criteria, priority, iteration, or ownership fields
- Extract parent, child, or related links from work item relations
- Convert Azure DevOps HTML fields into readable markdown or plain text

## Prerequisites

- An Azure DevOps work item URL or a known work item ID
- The Azure DevOps project name, either supplied directly or derivable from the URL
- Access to the `mcp_ado_wit_get_work_item` tool

## Step 1: Parse the Work Item Reference

Start by extracting the work item ID and, where possible, the project name.

### Supported URL Patterns

- Query parameter: `?workitem={id}`
- Edit path: `/_workitems/edit/{id}`

### Parsing Guidance

1. Read the incoming URL.
2. Look for a `workitem` query parameter first.
3. If that is not present, look for the numeric segment after `/_workitems/edit/`.
4. Extract the project name from the URL path if the URL structure includes it.
5. If the project cannot be determined reliably from the URL, ask for it explicitly rather than guessing.

## Step 2: Fetch the Work Item with MCP

Use the Azure DevOps MCP work item read tool to fetch the record.

### Recommended Call

- `id`: the parsed work item ID
- `project`: the parsed or user-supplied project name
- `expand`: `relations`

Using `expand: relations` ensures the response includes linked work items such as parents, children, and related items.

## Step 3: Extract the Core Fields

Work item data is returned as a field map. Read the values directly from the response and treat missing values as absent data, not as implicit defaults.

### Common Field Mapping

| ADO field | Meaning |
| --- | --- |
| `System.Title` | Human-readable title |
| `System.WorkItemType` | Work item type |
| `System.State` | Current workflow state |
| `System.AssignedTo` | Current assignee |
| `Microsoft.VSTS.Common.Priority` | Priority |
| `Microsoft.VSTS.Scheduling.StoryPoints` | Story points or estimate |
| `System.IterationPath` | Iteration or sprint |
| `System.AreaPath` | Area or functional ownership |
| `System.Description` | Main description body |
| `Microsoft.VSTS.Common.AcceptanceCriteria` | Acceptance criteria |

### Extraction Notes

- `System.AssignedTo` may be an object-like value rather than a plain string. Prefer the display name if available.
- Some teams do not use story points or priority consistently. Omit missing values rather than inventing placeholders.
- Preserve the original work item URL when generating summaries or documents.

## Step 4: Parse Relations

When relations are expanded, inspect the relation list and group linked items by relationship type.

### Common Relation Categories

- Parent
- Child
- Related
- Dependency or predecessor/successor links

### Relation Handling Guidance

1. Read each relation entry.
2. Inspect the relation type name.
3. Group relations into meaningful buckets for output.
4. If relation metadata includes a linked work item URL but not the title, present the link or ID unless a second fetch is explicitly required.

## Step 5: Convert HTML Fields

Azure DevOps rich-text fields commonly contain HTML. Normalise them into markdown or readable plain text before presenting them to users.

### Minimum Conversion Rules

- `<br>` becomes a newline
- `<b>` and `<strong>` become `**text**`
- `<i>` and `<em>` become `*text*`
- `<ul><li>` becomes `- item`
- `<ol><li>` becomes `1. item`
- Strip remaining HTML tags after converting supported formatting

### Practical Guidance

- Preserve paragraph breaks where possible so the content remains readable.
- Avoid retaining raw HTML unless the user explicitly wants the source markup.
- If a field is empty after stripping tags and whitespace, treat it as missing.

## Step 6: Produce Structured Output

Once the work item is parsed, present the result in a stable structure that downstream steps can consume.

### Recommended Output Shape

- Title
- Work item type
- State
- Assigned to
- Priority
- Estimate or story points
- Iteration
- Area
- Original Azure DevOps link
- Description
- Acceptance criteria
- Related items grouped by relation type

If a section has no data, omit it rather than rendering empty headings unless the caller explicitly requires a fixed template.

## Example Workflow

1. Receive an Azure DevOps work item URL.
2. Parse the project and work item ID.
3. Call `mcp_ado_wit_get_work_item` with `expand: relations`.
4. Read the response fields.
5. Convert description and acceptance criteria from HTML to markdown.
6. Group linked items from relations.
7. Return a clean structured summary or feed the data into the next automation step.

## Failure Handling

- If the URL does not contain a valid work item ID, stop and ask for a valid Azure DevOps work item URL or numeric ID.
- If the project name cannot be derived, ask for the project explicitly.
- If the MCP response omits a field, treat it as unavailable data.
- If relations are absent, return the work item without a related-items section.

## Output Principles

- Be explicit about what was parsed from the URL and what came from the MCP response.
- Do not guess missing fields.
- Keep the output concise, structured, and easy to reuse.
- Prefer markdown-safe text over raw HTML in summaries and generated documents.
