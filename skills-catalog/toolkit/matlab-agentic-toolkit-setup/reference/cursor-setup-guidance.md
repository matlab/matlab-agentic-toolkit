# Cursor Setup Guidance

**Status: EXPERIMENTAL — untested, provided as-is**

This reference file contains Cursor-specific instructions for Phase 3b of the setup skill.

## Overview

Cursor stores MCP server configuration in JSON files. The global config at `~/.cursor/mcp.json` makes the MCP server available across all projects.

## Global Config Path

```
~/.cursor/mcp.json
```

## Config Format

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

Replace:
- `<MCP_SERVER_PATH>` — absolute path to the binary (e.g., `/Users/jane/.local/bin/matlab-mcp-core-server`)
- `<MATLAB_ROOT>` — absolute path to the MATLAB installation (e.g., `/Applications/MATLAB_R2025b.app`)
- `<DISPLAY_MODE>` — `nodesktop` (default) or `desktop`

## Phase 3b: Write Config

### Step 1: Read existing config (if any)

```bash
cat ~/.cursor/mcp.json 2>/dev/null
```

### Step 2: Write or merge the config

- If the file **does not exist**: create it with the full JSON above.
- If the file **exists**: parse the JSON, add or update the `matlab` key under `mcpServers`, and preserve all other server entries. Do NOT overwrite other MCP servers.

```bash
mkdir -p ~/.cursor
```

Then write the file. After writing, echo back the full file content to the user.

### Step 3: Confirm what was written

Tell the user:

> Wrote MATLAB MCP server configuration to `~/.cursor/mcp.json`:
> ```json
> [show the exact content written]
> ```
> This makes the MATLAB MCP server available in all Cursor projects.

## Platform Quirks

- **Variable interpolation:** Cursor supports `${userHome}` in config values, but using absolute paths is more reliable.
- **Tool limit:** Cursor has a maximum of 40 active tools across ALL MCP servers combined. The MATLAB MCP Core Server provides 5 tools, well within this budget.
- **Transport:** Only stdio transport is needed (the default for local servers).

## Manual Fallback

If automated config writing fails, tell the user:

> I was unable to write the config file automatically. Please create or edit `~/.cursor/mcp.json` manually:
>
> 1. Open `~/.cursor/mcp.json` in a text editor (create the file if it doesn't exist)
> 2. Add the following under `mcpServers`:
>    ```json
>    "matlab": {
>      "command": "<MCP_SERVER_PATH>",
>      "args": ["--matlab-root", "<MATLAB_ROOT>", "--matlab-display-mode", "nodesktop"]
>    }
>    ```
> 3. Save the file and restart Cursor
>
> Replace `<MCP_SERVER_PATH>` and `<MATLAB_ROOT>` with the actual paths shown in the setup plan above.

## Verification

After the user restarts Cursor:

> Open any project in Cursor and ask: "What version of MATLAB is running?"
> If Cursor can call `detect_matlab_toolboxes` or `evaluate_matlab_code`, setup was successful.
>
> If it doesn't work:
> - Check `~/.cursor/mcp.json` exists and contains the `matlab` entry
> - Verify the binary runs: `~/.local/bin/matlab-mcp-core-server --version`
> - Check Cursor's MCP server status in the Cursor settings UI
