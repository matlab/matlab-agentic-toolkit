# OpenAI Codex Setup Guidance

**Status: validated against `codex-cli 0.118.0` on macOS; Linux and Windows commands included below**

This reference file contains OpenAI Codex-specific instructions for Phase 3b of the setup skill.

## Overview

Codex setup needs two global registrations:

1. Add the MATLAB MCP server to Codex's user config so the tools are available in every Codex session.
2. Add global skill references under `~/.agents/skills` so the toolkit skills are available in every repo and continue to update from this clone after `git pull`.

Do **not** copy skills into a Codex-private folder if a repo reference will work.

## Global Paths

```text
~/.codex/config.toml
~/.agents/skills/
```

Codex also honors `CODEX_HOME` for testing. If `CODEX_HOME` is set, the effective user config path is:

```text
$CODEX_HOME/config.toml
```

## MCP Configuration Path

**Always use** Codex's native MCP management command:

```bash
codex mcp add matlab -- "<MCP_SERVER_PATH>" --matlab-root "<MATLAB_ROOT>" --matlab-display-mode "<DISPLAY_MODE>"
```

This is the required approach because it handles path escaping correctly on all platforms (including Windows backslashes in TOML).

Observed behavior in `codex-cli 0.118.0`:

- This command writes a global `[mcp_servers.matlab]` entry to `~/.codex/config.toml`
- Re-running it updates the existing `matlab` entry instead of creating duplicates
- Existing unrelated `mcp_servers.*` entries are preserved

### Fallback TOML Block

If `codex mcp add` fails, write or update this section manually:

```toml
[mcp_servers.matlab]
command = "<MCP_SERVER_PATH>"
args = ["--matlab-root", "<MATLAB_ROOT>", "--matlab-display-mode", "<DISPLAY_MODE>"]
tool_timeout_sec = 600
```

**CRITICAL:** The TOML key must be `mcp_servers` with an underscore. `mcp-servers` is silently ignored.

**CRITICAL (Windows only):** TOML treats backslash (`\`) as an escape character. When writing Windows paths into TOML strings, you **must** double every backslash. For example, write `C:\\Users\\Name\\.local\\bin\\matlab-mcp-core-server.exe`, NOT `C:\Users\Name\.local\bin\matlab-mcp-core-server.exe`. Single backslashes produce invalid escape sequences (`\U`, `\N`, etc.) that silently corrupt the config file.

### Required Extra Fields

`codex mcp add` writes only `command` and `args`. The following fields must be added manually by editing `~/.codex/config.toml` after running `codex mcp add`, or included when writing the TOML block directly:

**`tool_timeout_sec` (all platforms):** The default Codex tool timeout is too short for many MATLAB operations (test suites, simulations, code generation). Set this to at least 600 seconds (10 minutes):

```toml
tool_timeout_sec = 600   # increase for long-running tasks
```

**`env_vars` (Windows only):** On Windows, Codex strips environment variables from MCP server subprocesses by default. Simulink requires the `WINDIR` environment variable. Add this to the `[mcp_servers.matlab]` block:

```toml
env_vars = ['WINDIR']   # required for Simulink on Windows
```

The complete Windows TOML block should look like (note doubled backslashes):

```toml
[mcp_servers.matlab]
command = "C:\\Users\\Name\\.local\\bin\\matlab-mcp-core-server.exe"
args = ["--matlab-root", "C:\\Program Files\\MATLAB\\R2025b", "--matlab-display-mode", "nodesktop"]
tool_timeout_sec = 600
env_vars = ['WINDIR']
```

## Global Skills Registration

Install repo-referenced skill directories into `~/.agents/skills`.

The toolkit includes shared helper scripts (used by Copilot, Codex, and Gemini CLI):

### macOS and Linux

```bash
bash "<TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup/scripts/install-global-skills.sh" "<TOOLKIT_ROOT>"
```

This creates or updates symlinks such as:

```text
~/.agents/skills/matlab-testing -> <TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-testing
~/.agents/skills/matlab-debugging -> <TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-debugging
~/.agents/skills/matlab-agentic-toolkit-setup -> <TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup
```

The script prefers `~/.agents/skills/` and falls back to `~/.copilot/skills/` if the primary directory cannot be created.

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File "<TOOLKIT_ROOT>\skills-catalog\toolkit\matlab-agentic-toolkit-setup\scripts\install-global-skills.ps1" -ToolkitRoot "<TOOLKIT_ROOT>"
```

The script first tries symbolic links and falls back to directory junctions.

### Windows CMD fallback

Run PowerShell from `cmd.exe`:

```cmd
powershell -ExecutionPolicy Bypass -File "<TOOLKIT_ROOT>\skills-catalog\toolkit\matlab-agentic-toolkit-setup\scripts\install-global-skills.ps1" -ToolkitRoot "<TOOLKIT_ROOT>"
```

## Phase 3b: Execute Codex Setup

### Step 1: Read existing Codex config

```bash
cat ~/.codex/config.toml 2>/dev/null
```

### Step 2: Register global skills

Run the platform-appropriate helper script from the toolkit repo.

After it completes, report:

1. The global skills directory used
2. The skill links created or updated
3. That the links point back to this repo clone for updateability

### Step 3: Add or update the MATLAB MCP server

```bash
codex mcp add matlab -- "<MCP_SERVER_PATH>" --matlab-root "<MATLAB_ROOT>" --matlab-display-mode "<DISPLAY_MODE>"
```

This handles path escaping correctly on all platforms. If the command fails, fall back to editing `~/.codex/config.toml` manually using the fallback TOML block above (paying careful attention to the Windows backslash escaping warning).

### Step 3b: Add required extra fields

`codex mcp add` does not support `tool_timeout_sec` or `env_vars`. After running `codex mcp add` (or when writing the TOML block directly), edit `~/.codex/config.toml` to add these fields to the `[mcp_servers.matlab]` section:

- **All platforms:** Add `tool_timeout_sec = 600`
- **Windows only:** Add `env_vars = ['WINDIR']`

See [Required Extra Fields](#required-extra-fields) above for the complete block.

### Step 4: Confirm what was written

Always echo back:

1. The config file path that was written
2. The exact `[mcp_servers.matlab]` section now present
3. Whether the `matlab` entry was created new or updated
4. The global skills path used
5. The list of skill links created or updated

## Verification

### Before restarting Codex

Verify the MCP registration locally:

```bash
codex mcp list
codex mcp get matlab --json
```

Expected result: a `matlab` stdio server whose command is the installed `matlab-mcp-core-server` binary and whose args include `--matlab-root` and `--matlab-display-mode`.

### After restarting Codex in another repo

Start a new Codex session in a different repository and ask:

```text
What version of MATLAB is running?
```

Then ask a MATLAB-domain question that should trigger one of the globally linked skills, for example:

```text
Write tests for this MATLAB function.
```

Setup is successful when:

- Codex can call `detect_matlab_toolboxes` or `evaluate_matlab_code`
- MATLAB-domain skills are available outside the toolkit repo

## Manual Fallback

If automated setup fails:

1. Edit `~/.codex/config.toml` manually and add the `[mcp_servers.matlab]` section shown above
2. Create `~/.agents/skills`
3. Add directory symlinks or junctions from `~/.agents/skills/<skill-name>` to the corresponding directories in this repo:
   - `<TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup`
   - `<TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-testing`
   - `<TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-debugging`
   - `<TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-review-code`
   - `<TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-modernize-code`
   - `<TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-build-app`
   - `<TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-create-live-script`
4. Restart Codex

## Plugin Visibility (`/plugins`)

The toolkit will **not** appear when you run `/plugins` in Codex. This is expected.

Codex setup registers two things globally:

1. A global MCP server entry (via `codex mcp add` or `~/.codex/config.toml`)
2. Global skill symlinks (via `~/.agents/skills`)

It does **not** install the toolkit through a Codex plugin-install flow because Codex does not currently expose a stable public plugin-install command. The `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` files in this repo are forward-looking metadata for when Codex adds plugin discovery support.

**How to verify setup is working:**

- `codex mcp list` shows the `matlab` server
- `codex mcp get matlab --json` shows the correct binary path and args
- MATLAB tools and skills are available in any Codex session

If all three are true, your setup is complete — regardless of what `/plugins` shows.

## Platform Quirks

- Codex uses TOML for config, not JSON
- `mcp_servers` must use an underscore
- Current Codex CLI exposes `codex mcp ...` commands but does **not** expose a stable public plugin-install command
- Global skills come from `~/.agents/skills`, not from `.codex-plugin/`
- User config can be overridden by project config (`.codex/config.toml`) or CLI flags

----

Copyright 2026 The MathWorks, Inc.

----

