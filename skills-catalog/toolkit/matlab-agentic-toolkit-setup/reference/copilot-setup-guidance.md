# GitHub Copilot Setup Guidance

**Status: Automated — tested**

This reference file contains **executable automation steps** for Phase 3b of the setup skill. The setup skill implements these steps to configure GitHub Copilot for MATLAB MCP.

---

## Overview

GitHub Copilot accesses MCP servers via `~/.vscode/settings.json` (global, user-level config). Setup automates:

1. **Global MCP config** — write to `~/.vscode/settings.json` with absolute paths
2. **Global skills** — create symlinks in `~/.agents/skills/` or `~/.copilot/skills/` pointing to `skills-catalog/`

This matches the target workflow: **clone once, setup once, use everywhere**.

---

## Phase 3b: Automation Steps

### Step 1: Read and merge VS Code settings

Read `~/.vscode/settings.json` as **JSON** (not JSONC to avoid comment parsing complexity):

```bash
if [ -f ~/.vscode/settings.json ]; then
  SETTINGS_JSON="$HOME/.vscode/settings.json"
else
  SETTINGS_JSON=""
fi
```

If the file exists, parse it (use a JSON tool like `jq` if available, or a safe JSON reader). If it doesn't exist, start with an empty config:

```json
{
  "mcp.servers": {}
}
```

### Step 2: Add or update MATLAB MCP entry

Merge the MATLAB entry into the config. Use `jq` (if available) for safe JSON manipulation:

**With jq:**
```bash
jq '.["mcp.servers"].matlab = {
  "type": "stdio",
  "command": "<MCP_SERVER_PATH>",
  "args": [
    "--matlab-root", "<MATLAB_ROOT>",
    "--matlab-display-mode", "<DISPLAY_MODE>"
  ]
}' ~/.vscode/settings.json > ~/.vscode/settings.json.tmp && mv ~/.vscode/settings.json.tmp ~/.vscode/settings.json
```

**Without jq (Python fallback):**
```python
import json
import os

settings_path = os.path.expanduser('~/.vscode/settings.json')
settings = {}
if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        settings = json.load(f)

if 'mcp.servers' not in settings:
    settings['mcp.servers'] = {}

settings['mcp.servers']['matlab'] = {
    'type': 'stdio',
    'command': '<MCP_SERVER_PATH>',
    'args': [
        '--matlab-root', '<MATLAB_ROOT>',
        '--matlab-display-mode', '<DISPLAY_MODE>'
    ]
}

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
```

Replace placeholders:
- `<MCP_SERVER_PATH>` — absolute path to the binary (detected in Phase 1)
- `<MATLAB_ROOT>` — absolute path to the MATLAB installation (detected in Phase 1)
- `<DISPLAY_MODE>` — `nodesktop` (default) or `desktop` (from Phase 2 plan)

**Important:** Preserve all other settings in `~/.vscode/settings.json` — only add or update the `mcp.servers.matlab` entry.

### Step 3: Write settings back to file

Write the merged config to `~/.vscode/settings.json`. Use `mkdir -p ~/.vscode` first to ensure the directory exists.

```bash
mkdir -p ~/.vscode
# Write merged JSON to ~/.vscode/settings.json
# (implementation: use jq, Python json module, or equivalent)
```

### Step 4: Register global skills

Skills are registered via the shared step (3b-shared in SKILL.md) using the cross-platform helper scripts. These handle the `~/.agents/skills/` → `~/.copilot/skills/` fallback automatically.

**macOS / Linux:**
```bash
bash "<TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup/scripts/install-global-skills.sh" "<TOOLKIT_ROOT>"
```

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File "<TOOLKIT_ROOT>\skills-catalog\toolkit\matlab-agentic-toolkit-setup\scripts\install-global-skills.ps1" -ToolkitRoot "<TOOLKIT_ROOT>"
```

---

## Platform Details

| Setting | Value |
|---------|-------|
| Config file | `~/.vscode/settings.json` (global, user-level) |
| Server type | `"type": "stdio"` |
| MCP key name | `"mcp.servers"` (not `"mcpServers"`) |
| Skills paths | `~/.agents/skills/`, `~/.copilot/skills/`, `.github/skills/` |

**Quirks:**
- VS Code natively parses JSONC (JSON with comments), but setup must write valid JSON (no comments) to avoid merge conflicts
- Skills are discovered from any of the three paths; global symlinks make them available across all projects
- No per-project setup needed — global config works everywhere

---

## Fallback (Manual Setup)

If automation encounters an error, provide the user with manual instructions:

### Option A: Global setup via VS Code Settings UI

> 1. Open VS Code
> 2. Open Settings (Cmd/Ctrl + ,)
> 3. Search for "mcp.servers"
> 4. Click "Edit in settings.json"
> 5. Add:
>    ```json
>    "mcp.servers": {
>      "matlab": {
>        "type": "stdio",
>        "command": "/path/to/matlab-mcp-core-server",
>        "args": [
>          "--matlab-root", "/path/to/MATLAB/R2025b",
>          "--matlab-display-mode", "nodesktop"
>        ]
>      }
>    }
>    ```
> 6. Save and reload VS Code

### Option B: Project-level setup

> For a single project, create `.vscode/mcp.json`:
> ```json
> {
>   "servers": {
>     "matlab": {
>       "type": "stdio",
>       "command": "/path/to/matlab-mcp-core-server",
>       "args": [
>         "--matlab-root", "/path/to/MATLAB/R2025b",
>         "--matlab-display-mode", "nodesktop"
>       ]
>     }
>   }
> }
> ```

For skills, users can run the shared helper script manually:
```bash
bash /path/to/matlab-agentic-toolkit/skills-catalog/toolkit/matlab-agentic-toolkit-setup/scripts/install-global-skills.sh /path/to/matlab-agentic-toolkit
```

---

## Verification

After the setup skill completes:

1. **Check config file:**
   ```bash
   cat ~/.vscode/settings.json | grep -A5 mcp.servers
   ```
   Should contain the `matlab` entry with correct paths.

2. **Check skills symlinks:**
   ```bash
   ls -la ~/.agents/skills/ # or ~/.copilot/skills/
   ```
   Should show symlinks to `matlab-core` and `toolkit`.

3. **In VS Code/Copilot:**
   - Reload: Cmd/Ctrl + Shift + P → "Developer: Reload Window"
   - Ask: "What version of MATLAB is running?"
   - If MATLAB tools are available, setup was successful

---

## Implementation Notes for Setup Skill

The setup skill (SKILL.md Phase 3b) should:

1. Call this reference and follow the steps above
2. Use `jq`, Python, or another safe JSON parser to merge config
3. Always preserve existing settings (no wholesale replacement)
4. Use the shared `install-global-skills` scripts for skill registration (handles `~/.copilot/skills/` fallback automatically)
5. Echo back the paths written to `~/.vscode/settings.json` and skill symlinks created
6. If anything fails, provide the manual fallback instructions above

See SKILL.md Phase 3b for the implementation.
