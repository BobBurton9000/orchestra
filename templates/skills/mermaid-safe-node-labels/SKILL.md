---
name: mermaid-safe-node-labels
description: 'Use when writing or fixing Mermaid flowcharts whose node labels contain code-like or symbol-heavy text, to prevent parser failures by quoting labels and escaping special characters.'
---
# Quick Reference

| Pattern | Example | Purpose |
| --- | --- | --- |
| Corrected special-character flowchart | `A["Customer\\Entities"] --> B["OrderService::dependency(customer, itemList)"] --> C["Company\\Site"]` | Shows the safe form for parser-sensitive labels: quote the full label and escape backslashes. |
| Simple flowchart template | `Client --> API --> Database` | Shows the baseline case where plain labels usually work without extra escaping. |
| Plain decision-node flowchart | `Decision{"Ready?\nReview complete"}` | Shows that ordinary text and line breaks are not, by themselves, the problem this skill addresses. |

# Goals and Non-Goals

| Type | Scope |
| --- | --- |
| Goal | Make Mermaid flowchart node labels parse reliably when they contain code-like or symbol-heavy text such as backslashes, method-style separators, parentheses, or comma-heavy fragments. |
| Goal | Prefer a stable representation that works across Mermaid renderers by quoting the full label and escaping backslashes inside the label text. |
| Non-goal | Fixing unrelated Mermaid syntax problems such as bad arrows, missing subgraph terminators, malformed style directives, or broken fence markers. |
| Non-goal | Rewriting simple labels that are already plain text, such as `Client --> API --> Service --> Database`. |
| Non-goal | General Mermaid guidance for other diagram types such as sequence diagrams, class diagrams, or Gantt charts. |

# The Learning

When a Mermaid flowchart node label contains code-like or symbol-heavy text, treat the label as parser-sensitive rather than as free text. A corrected diagram works because each label is wrapped in quotes inside its node shape and the namespace-style backslashes are escaped as `\\`. The safe default is: preserve the node shape, quote the full label text inside that shape, and escape backslashes inside the quoted content.

| Label pattern | Risk if left raw | Safe form | Evidence |
| --- | --- | --- | --- |
| Backslashes inside a label | Mermaid may treat the label as invalid or parse it inconsistently | Use quoted labels and escape each backslash as `\\` | `A["Customer\\Entities"]` |
| Method-style or code-like fragments such as `::dependency(..., itemList)` | Punctuation-heavy text can become parser-fragile in unquoted labels | Put the entire label in quotes inside the existing node delimiter | `B["OrderService::dependency(customer, itemList)"]` |
| Simple text labels such as `Client`, `API`, `Service`, `Database` | Usually no extra handling needed | Leave them plain unless the renderer proves otherwise | `Client --> API --> Database` |

# Behaviour Examples

| Case | Evidence | Behaviour |
| --- | --- | --- |
| Positive: special-character labels quoted correctly | `A["Customer\\Entities"] --> B["OrderService::dependency(customer, itemList)"] --> C["Company\\Site"]` | The diagram wraps each label in quotes and escapes the backslashes, which makes the code-like labels valid Mermaid flowchart text. |
| Negative: same diagram left raw | `A[Customer\Entities] --> B[OrderService::dependency(customer, itemList)] --> C[Company\Site]` | The unquoted labels contain code-like fragments and raw backslashes, which makes the flowchart parser-fragile and likely to fail. |
| Boundary case: plain labels do not need the heavy-handed fix | `Client --> API --> Database` and `Decision{"Ready?\nReview complete"}` | Simple labels and ordinary decision text render cleanly without quoting every node, so this skill should be applied when the label content is parser-fragile rather than universally. |

# Anti-Patterns

| Anti-pattern | Why it is wrong |
| --- | --- |
| Pasting code-like identifiers straight into Mermaid node labels without quotes | This is the main failure mode this skill addresses: the label text looks readable to a human but remains parser-fragile. |
| Escaping only one visibly bad character while leaving the rest of a punctuation-heavy label raw | This creates brittle diagrams because the next Mermaid renderer or label edit can still break parsing. Quote the whole label instead. |
| Applying this rule to every label regardless of complexity | It adds noise without benefit for simple labels and makes diagrams harder to scan. Use it when the label contains parser-sensitive text, not as a universal formatting rule. |
| Treating a label-parsing failure as evidence that the underlying code or architecture description is wrong | The issue is often Mermaid syntax rather than the underlying technical content. Fix the diagram representation first. |

# Design Decisions

| Decision | Alternative | Why this choice was made |
| --- | --- | --- |
| Quote the full node label when it contains code-like or symbol-heavy text | Escape only the obviously problematic character, usually the backslash | Labels that combine backslashes, `::`, parentheses, commas, or similar punctuation are easier to reason about and less brittle when the full label is quoted rather than selectively escaped. |