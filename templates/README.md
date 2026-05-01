# Template Configuration Files

Reference MCP server configurations for manual setup. Each file is a starting point for a specific agent platform.

**Prefer automated setup** — launch your agent in the toolkit repo and ask it to "set up the MATLAB Agentic Toolkit." These templates are for users who prefer or need to configure manually.

## Usage

1. Copy the template for your platform to the location your agent expects (see table below)
2. Replace `/path/to/matlab-mcp-core-server` with the absolute path to your installed binary
3. If MATLAB is not on PATH, add `--matlab-root /path/to/MATLAB/R20XXx` to the args

## Templates

| File | Platform | Copy to |
|------|----------|---------|
| `codex-mcp.json` | OpenAI Codex | Use `codex mcp add` instead, or edit `~/.codex/config.toml` |
| `gemini-extension.json` | Gemini CLI | Project root, then `gemini extensions link .` (local dev) or `gemini extensions install` (from GitHub) |
| `vscode-mcp.json` | GitHub Copilot / VS Code | `.vscode/mcp.json` in each project |
| `amp-settings.json` | Sourcegraph Amp | `~/.config/amp/settings.json` (global) or `.amp/settings.json` (project) |

For full instructions, see the [Getting Started guide](../GETTING_STARTED.md).

----

Copyright 2026 The MathWorks, Inc.

----

