# Orchestra

## Experimental

This is one of my repositories I am using to test and share new concepts for how we can use LLM's to help us write software. This uses (you could say abuses) (subagents)[https://code.visualstudio.com/docs/copilot/agents/subagents] to get really high value out of a single copilot request and isolate context and reasoning requirements to the most appropriate agent for each chunk of work. It's a bit rough around the edges but I have found it to be very effective for complex development workflows. I hope you find it useful or at least interesting as a concept!

## Important Note

As of the time of writing this (2026-03-04) **this only works as intended in VsCode Insiders**. Also keep in mind a limitation of VsCode is subagents inherit the tools of their parent (but do not consume additional requests) so this means the Orchestrator needs all the tools that any of the subagents need. This is not ideal but is a limitation of the current system. The limitations are enforced by prompts only.

A lightweight, "take it or leave it" (or fork it) git 'module' you can add to your project to help you plan and implement features with an LLM. It does benefit from certain skills, see below, but you can take this concept and customise it (and the agents) to your own needs.

Currently seems most stable with GPT-5.3-Codex* but in theory should work with any sufficiently capable LLM that can handle the context and reasoning requirements.

*I have a hunch this is because subagents cannot compact their context window yet, so they just crash if they are given too much to do and Codex has a generous 400k limit in VsCode.

## What This Is

A specialized team of AI agents designed to handle complex development workflows through strategic delegation and coordination. Each agent has a focused expertise area (backend, frontend, testing, debugging, architecture, etc.), allowing complex tasks to be broken down and distributed to the most appropriate specialist. The orchestrator agent coordinates the team, ensuring work flows efficiently between agents based on their strengths.

It's designed to tackle large, multi-faceted development tasks that would normally overwhelm a single agent's context window or exceed their specialized knowledge. By delegating to focused agents, Orchestra maintains high-quality outputs while efficiently managing complex workflows. It should manage the entire development lifecycle for a feature or bug fix, from understanding requirements to implementation, testing, and review.

By putting an LLM between you and the subagents you gain the aditional benefit of the Orchestrator providing each subagent with well defined (and written), focused tasks.

It's also very economic, a long running complex task can use a dozen agents each doing focused work without overwhelming any single agent's context window or consuming an excessive number of requests.

![Example flow](example.png)

## How It Works

When you invoke the `orchestrator` agent, it analyzes your request and breaks it into focused chunks that get delegated to specialized agents in the team. Each agent works within their constraints and expertise, then reports back to the orchestrator. The orchestrator coordinates the workflow, passing information between agents and adapting the plan based on feedback until the task is complete.

For example, implementing a new feature might involve:
1. **information-gatherer** researches existing patterns in the codebase
2. **architect** designs the solution architecture  
3. **backend-programmer** implements server-side changes
4. **frontend-programmer** implements UI changes
5. **quality-engineer** writes automated tests
6. **manual-tester** performs exploratory testing
7. **code-reviewer** reviews the final implementation


## Installation

- Add your `ai` folder or the `ai/orchestra` folder to your global or `.git/info/exclude` file to avoid committing it to your repository
- Clone or copy this directory to your `ai` folder
- Add the `agents` folder to your VSCode configuration (file -> preferences -> settings)
- Add the `prompts` folder to your VSCode configuration (file -> preferences -> settings)
- Configure `config/target-branch.md` with your main branch name (e.g., `master`, `main`)
- Optionally configure manual testing instructions in `config/manual-testing.md`
- Adjust the frontend and backend programmer agents' allowed directories if you want to use those agents in a different codebase (currently configured for intelligentcontract)
- Add `run-tests` and `playwright-mcp` skills to copilot (the contents of these skills will be unique to your setup)
- Make sure you have chat "custom agent in sub agent" enabled in VSCode: `vscode-insiders://settings/chat.customAgentInSubagent.enabled`

## Agents

Orchestra provides the following specialized agents:

- **orchestrator** - Strategic workflow coordinator that delegates tasks to specialized agents. Use this as your main entry point for complex multi-step tasks.
- **architect** - Plans software architecture and system design. Provides authority on programming principles and implementation patterns.
- **backend-programmer** - Implements complex backend features and server-side changes with minimal guidance.
- **frontend-programmer** - Implements complex frontend features and UI changes with minimal guidance.
- **debugger** - Investigates and diagnoses bugs, errors, and unexpected behavior, then recommends fixes.
- **scribe** - Handles straightforward documentation updates and low-effort writing tasks.
- **code-reviewer** - Reviews code for quality, standards compliance, and critical risks.
- **manual-tester** - Performs exploratory testing of user interfaces and workflows using Playwright.
- **ui-ux-designer** - Creates design mockups and UX recommendations without modifying production code.
- **information-gatherer** - Searches and collects information from codebase and GitHub to compile research reports.
- **quality-engineer** - Writes and maintains automated tests to ensure adequate test coverage.

## Prompts

### /orchestra.merge-check

Performs a comprehensive merge-readiness review focused on blockers, regressions, and high-risk release issues. This prompt orchestrates multiple agents to:

1. **Understand the changeset** - Analyze which files changed and what user-journeys are affected
2. **Review code for critical risks** - Security vulnerabilities, data loss risks, broken error handling
3. **Run automated tests** - Execute relevant test suites for changed areas
4. **E2E test user-journeys** - Browser-based testing of affected workflows

The review creates or updates `ai/planning/issues.md` with findings, tracking severity and status. Use this before merging to catch merge-blocking issues early.

## Configuration

Orchestra uses configuration files in the `config/` directory (gitignored by default):

- **target-branch.md** - Specifies the target branch for merge-readiness checks (e.g., `master`, `main`)
- **manual-testing.md** - Instructions for manual testing workflows (perhaps your current branch has particular setup steps or areas to focus on)

These files allow you to customize Orchestra's behavior for your needs at the specific time.

## External Dependencies

Orchestra relies on these skills being available:
- **playwright-mcp** - For browser automation and UI testing
- **run-tests** - For executing automated test suites

Ensure these skills are properly configured before using Orchestra agents that depend on them.

## Usage Tips

**For complex implementations:**
```
@orchestrator implement attached implementation plan
```

**For merge-readiness checks:**
```
/orchestra.merge-check
```
The orchestrator is patient and will iterate through multiple rounds of delegation until the task is complete. Don't worry about overwhelming it with complex requests - that's exactly what it's designed for.
