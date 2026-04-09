# Claude Code Setup Guidance

**Status: Tested**

This reference file contains Claude Code-specific instructions for Phase 3b of the setup skill.

## Overview

Claude Code uses a plugin system with a marketplace. The `matlab-core` plugin delivers MATLAB skills but does **not** ship MCP server configuration (MCP config is system-specific and can't be meaningfully defaulted). The setup skill writes `~/.claude/.mcp.json` with absolute paths for the binary and MATLAB root.

## Global Config Path

MCP server config: `~/.claude/.mcp.json` (user-level, written by setup skill).

## Phase 3b: Register Plugin

### Step 1: Add the marketplace

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
```

If the marketplace is already registered, this is a no-op. Continue to the next step.

### Step 2: Install plugins

```bash
claude plugin install matlab-core@matlab-agentic-toolkit
claude plugin install toolkit@matlab-agentic-toolkit
```

Claude's native prompt will ask the user to choose scope for each plugin. Do NOT implement your own scope selection — let Claude Code handle it.

### Step 3: Write MCP server config

Write `~/.claude/.mcp.json` with the detected binary path and MATLAB root:

```json
{
  "mcpServers": {
    "matlab": {
      "command": "<MCP_SERVER_PATH>",
      "args": ["--matlab-root", "<MATLAB_ROOT>", "--matlab-display-mode", "<DISPLAY_MODE>"]
    }
  }
}
```

Replace `<MCP_SERVER_PATH>`, `<MATLAB_ROOT>`, and `<DISPLAY_MODE>` with the values from the setup plan. The MCP tools become available in the next session (or immediately if the session is restarted).

### Step 4: Verify plugin installation

```bash
claude plugin list 2>&1
```

Confirm that `matlab-core@matlab-agentic-toolkit` and `toolkit@matlab-agentic-toolkit` appear in the output.

## If Plugin Commands Fail

If `claude` CLI commands fail (e.g., not available in the user's Claude Code version):

1. Report the error clearly
2. Skip plugin installation — skills can be used by reading SKILL.md files directly from the repo
3. The MCP config (Step 3) still works independently of the plugin system

## Verification

Use MATLAB MCP tools (available after restarting the session):

```matlab
v = ver('MATLAB');
fprintf('MATLAB %s (%s) — ready.\n', v.Version, v.Release);
```

If MCP tools are not available in the current session:

> The plugin was just installed. Start a **new Claude Code session** to activate the MATLAB MCP tools, then verify with: "What version of MATLAB is running?"
