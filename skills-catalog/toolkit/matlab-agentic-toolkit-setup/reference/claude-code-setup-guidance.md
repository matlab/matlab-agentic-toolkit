# Claude Code Setup Guidance

**Status: Tested**

This reference file contains Claude Code-specific instructions for Phase 3b of the setup skill.

## Overview

Claude Code uses a plugin system with a marketplace. The `matlab-core` plugin delivers MATLAB skills but does **not** ship MCP server configuration (MCP config is system-specific and can't be meaningfully defaulted). The setup skill registers the MCP server using the `claude mcp add` CLI command, which writes to the correct location automatically.

## Global Config Path

MCP server config is managed by the `claude mcp add -s user` command, which writes to `~/.claude/settings.json` under the `mcpServers` key. Do NOT write MCP config files manually — always use the CLI.

## Phase 3b: Register Plugin

### Step 1: Add the marketplace

Derive the marketplace URL from the toolkit repo's own origin remote, so the registered marketplace always matches where the user cloned from:

```bash
cd <toolkit-root>
MARKETPLACE_URL=$(git remote get-url origin)
claude plugin marketplace add "$MARKETPLACE_URL"
```

If the marketplace is already registered, this is a no-op. Continue to the next step.

### Step 2: Install plugins

Read `<TOOLKIT_ROOT>/.claude-plugin/marketplace.json`, extract the `name` field from each entry in the `plugins` array, and install every plugin:

```bash
claude plugin install <plugin-name>@matlab-agentic-toolkit
```

Claude's native prompt will ask the user to choose scope for each plugin. Do NOT implement your own scope selection — let Claude Code handle it.

### Step 3: Register MCP server

Use the `claude mcp add` CLI to register the MATLAB MCP server at user scope (available in all projects):

```bash
claude mcp add-json -s user matlab '{"command":"<MCP_SERVER_PATH>","args":["--matlab-root","<MATLAB_ROOT>","--matlab-display-mode","<DISPLAY_MODE>"]}'
```

Replace `<MCP_SERVER_PATH>`, `<MATLAB_ROOT>`, and `<DISPLAY_MODE>` with the values from the setup plan.

**Important:** This command must run at the system terminal (via the Bash tool), not as an inline Claude Code command. If a `matlab` entry already exists, the command will overwrite it.

**Windows path escaping:** The JSON string passed to `claude mcp add-json` must have backslashes doubled. For example, use `C:\\Users\\Name\\.local\\bin\\matlab-mcp-core-server.exe`, not `C:\Users\Name\.local\bin\matlab-mcp-core-server.exe`. Single backslashes produce invalid JSON escape sequences (`\U`, `\N`, etc.).

The MCP tools become available in the next session (or immediately if the session is restarted).

### Step 4: Verify plugin installation

```bash
claude plugin list 2>&1
```

Confirm that `matlab-core@matlab-agentic-toolkit`, `toolkit@matlab-agentic-toolkit` and the other installed plugins appear in the output.

## If Plugin Commands Fail

If `claude` CLI commands fail (e.g., not available in the user's Claude Code version):

1. Report the error clearly
2. Skip plugin installation — skills can be used by reading SKILL.md files directly from the repo
3. The MCP server registration (Step 3) still works independently of the plugin system — `claude mcp add` is a core CLI command available in all versions that support MCP

## Legacy Artifacts

Check for these artifacts from previous setup approaches. If found during Phase 1g, record them for the plan and clean them up during Phase 3b-migrate.

### `~/.claude/.mcp.json` with `matlab` entry

Earlier versions of the setup skill wrote MCP config directly to `~/.claude/.mcp.json`. This file is no longer used — MCP servers are now registered via `claude mcp add -s user`, which writes to `~/.claude/settings.json`.

**Detection (Phase 1g):**

```bash
cat ~/.claude/.mcp.json 2>/dev/null | grep -l matlab
```

If the file exists and contains a `matlab` entry, flag it as a legacy artifact.

**Cleanup (Phase 3b-migrate):**

1. Confirm that the new MCP config has been written successfully (Step 3 of Phase 3b completed).
2. Remove the `matlab` entry from `~/.claude/.mcp.json`. If `matlab` was the only entry, delete the file entirely. If other entries exist, remove only the `matlab` key and preserve the rest.

```bash
# Check if matlab is the only server entry
python3 -c "
import json, os, sys
p = os.path.expanduser('~/.claude/.mcp.json')
with open(p) as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
if 'matlab' in servers:
    del servers['matlab']
if not servers:
    os.remove(p)
    print('Removed ~/.claude/.mcp.json (matlab was the only entry)')
else:
    data['mcpServers'] = servers
    with open(p, 'w') as f:
        json.dump(data, f, indent=2)
    print('Removed matlab entry from ~/.claude/.mcp.json (preserved other entries)')
"
```

## Verification

Use MATLAB MCP tools (available after restarting the session):

```matlab
v = ver('MATLAB');
fprintf('MATLAB %s (%s) — ready.\n', v.Version, v.Release);
```

If MCP tools are not available in the current session:

> The plugin was just installed. Start a **new Claude Code session** to activate the MATLAB MCP tools, then verify with: "What version of MATLAB is running?"

----

Copyright 2026 The MathWorks, Inc.

----

