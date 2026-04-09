## MATLAB Agentic Toolkit

Use the toolkit's setup skill when the user asks to install, configure, update, or validate this repository for an AI coding agent.

- Primary setup skill: `skills-catalog/toolkit/matlab-agentic-toolkit-setup/SKILL.md`
- Codex-specific setup details: `skills-catalog/toolkit/matlab-agentic-toolkit-setup/reference/codex-setup-guidance.md`

For MATLAB implementation tasks, prefer the domain skills in `skills-catalog/matlab-core/`.

- `skills-catalog/matlab-core/matlab-testing/SKILL.md`
- `skills-catalog/matlab-core/matlab-debugging/SKILL.md`
- `skills-catalog/matlab-core/matlab-reviewing-code/SKILL.md`
- `skills-catalog/matlab-core/matlab-modernizing-code/SKILL.md`
- `skills-catalog/matlab-core/matlab-building-apps/SKILL.md`
- `skills-catalog/matlab-core/matlab-creating-live-scripts/SKILL.md`

When setting up Codex:

- Configure the MATLAB MCP server globally so it is available in every repo.
- Install global skill references from this repo into `~/.agents/skills` so updates continue to come from this clone after `git pull`.
- Prefer Codex's native `codex mcp add` command when it is available.
