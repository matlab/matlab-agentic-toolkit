# Gemini CLI Setup Guidance

**Status: Automated — tested**

This reference file contains **executable automation steps** for Phase 3b of the setup skill. The setup skill implements these steps to configure Gemini CLI for MATLAB MCP.

---

## Overview

Gemini CLI uses a global JSON settings file (`~/.gemini/settings.json`) for MCP server configuration and discovers skills from `~/.agents/skills/` (the cross-platform convention shared with Copilot and Codex).

Setup automates configuring the MCP server so it is ready for the user on their next restart. Skills are registered via the shared step (3b-shared in SKILL.md) — no Gemini-specific skill configuration is needed.

---

## Phase 3b: Automation Steps

### Step 1: Read and merge Gemini settings

Read `~/.gemini/settings.json` as JSON:

```bash
if [ -f ~/.gemini/settings.json ]; then
  SETTINGS_JSON="$HOME/.gemini/settings.json"
else
  SETTINGS_JSON=""
fi
```

If the file exists, parse it. If it doesn't exist, start with an empty config:

```json
{
  "mcpServers": {}
}
```

### Step 2: Add or update MATLAB MCP entry

Merge the MATLAB entry into the `mcpServers` block. Use Python for safe JSON manipulation (avoids dependency on `jq`):

```python
import json
import os

settings_path = os.path.expanduser('~/.gemini/settings.json')
settings = {}
if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        settings = json.load(f)

if 'mcpServers' not in settings:
    settings['mcpServers'] = {}

settings['mcpServers']['matlab'] = {
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
- `<DISPLAY_MODE>` — `desktop` (default) or `nodesktop` (from Phase 2 plan)

**Important:** Preserve all other settings in `~/.gemini/settings.json` — only add or update the `mcpServers.matlab` entry.

### Step 3: Confirm what was done

Always echo back:
1. The file path that was written (`~/.gemini/settings.json`)
2. The exact `mcpServers.matlab` entry that was added or updated
3. Whether the file was created new or an existing entry was updated
4. That skills are available via `~/.agents/skills/` (created by the shared skills registration step)
5. A reminder to restart Gemini CLI to see the changes take effect

---

## Platform Details

| Setting | Value |
|---------|-------|
| Config file | `~/.gemini/settings.json` (global, user-level) |
| MCP key name | `"mcpServers"` |
| Skills paths | `~/.agents/skills/` |

**Quirks:**
- Do NOT use `gemini mcp add` from within a running Gemini session — it recursively invokes the CLI and can fail due to file locking on `settings.json`. Always use the direct Python file write above.
- The `mcpServers` key is at the top level of `settings.json`, alongside other keys like `general`, `security`, etc.
- Skills are discovered from `~/.agents/skills/`; global symlinks make them available across all projects

---

## Fallback (Manual Setup)

If automation encounters an error, provide these manual instructions to the user:

> 1. Open `~/.gemini/settings.json` in a text editor.
> 2. Add the following to the `mcpServers` block (creating it if it doesn't exist):
>    ```json
>    "mcpServers": {
>      "matlab": {
>        "command": "<MCP_SERVER_PATH>",
>        "args": ["--matlab-root", "<MATLAB_ROOT>", "--matlab-display-mode", "desktop"]
>      }
>    }
>    ```
> 3. Save the file and restart Gemini CLI.

---

## Verification

After the setup skill completes:

1. **Check config file:**
   ```bash
   cat ~/.gemini/settings.json | grep -A5 mcpServers
   ```
   Should contain the `matlab` entry with correct paths.

2. **Check skills symlinks:**
   ```bash
   ls -la ~/.agents/skills/
   ```
   Should show symlinks to skill directories.

3. **In Gemini CLI:**
   - Start a new Gemini CLI session
   - Ask: "What version of MATLAB is running?"
   - If Gemini can call `evaluate_matlab_code` or `detect_matlab_toolboxes`, setup was successful.

---

## Implementation Notes for Setup Skill

The setup skill (SKILL.md Phase 3b) should:

1. Call this reference and follow the steps above
2. Use Python `json` module for safe JSON merge (always available, no extra dependencies)
3. Always preserve existing settings (no wholesale replacement)
4. Echo back the paths written to `~/.gemini/settings.json` and skill symlinks created
5. If anything fails, provide the manual fallback instructions above

See SKILL.md Phase 3b for the implementation.

----

Copyright 2026 The MathWorks, Inc.

----

