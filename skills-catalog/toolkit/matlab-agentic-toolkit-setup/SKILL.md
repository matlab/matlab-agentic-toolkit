---
name: matlab-agentic-toolkit-setup
description: Install and configure the MATLAB Agentic Toolkit — detect MATLAB, install the MCP server, register with your AI coding agent, and verify the environment. Supports Claude Code, Cursor, Codex, GitHub Copilot, Amp, and Gemini CLI.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Agentic Toolkit Setup

Automated onboarding for the MATLAB Agentic Toolkit. Detects MATLAB, downloads and installs the MCP server binary, configures your AI coding agent, and verifies everything works.

> **Tested platform:** Claude Code. 
> **Automated platforms:** GitHub Copilot, Gemini CLI (with manual fallback provided).
> **Experimental platforms:** Cursor, Codex, Amp are provided as-is; setup will guide you through each step and provide manual fallback instructions if anything fails.

This skill does NOT require the MATLAB MCP server — it uses shell commands for everything until the final verification step.

## Welcome Message

Before doing any work, print a welcome message to the user. This sets expectations for what's about to happen and why they may be asked to approve actions. Use a friendly, personal tone with "I" statements. The message should cover:

```
Welcome! My goal is to get you set up with the MATLAB Agentic Toolkit so you
can use MATLAB tools and skills with your agent for your projects.

Here's what I'll do:

1. Look around your computer to find your MATLAB installation(s) and check
   whether the MCP server is already installed. Depending on your permissions
   settings, you may be asked to approve some of these steps — I'm just
   reading system info, not changing anything yet.

2. Come back to you with a plan showing what I found and what I'd like to
   configure. You'll have a chance to adjust any choices before I make changes.

3. Once you approve, I'll install the MCP server (if needed), configure your
   agent to use it for your other projects, and verify the connection to MATLAB.

This setup configures everything globally — once it's done, MATLAB tools and
skills will be available in every session, regardless of which project you're
working in. This is the easiest way to get started. If you later want to scope
the configuration to specific projects, the Getting Started guide covers that.

If you'd rather set things up manually, the Getting Started guide has
step-by-step instructions: GETTING_STARTED.md
```

Adapt the wording naturally — don't recite it verbatim — but cover all three points. After printing the welcome message, proceed directly to Phase 1 without waiting for a response.

## When to Use

- User runs `/matlab-setup` or asks to set up the MATLAB Agentic Toolkit
- First time using the toolkit after cloning
- After moving the toolkit to a new location
- After installing a new MATLAB version
- To upgrade the MCP server to the latest version
- MCP connection issues that may indicate a broken installation
- User wants to configure MATLAB MCP for any supported agent platform

## When NOT to Use

- MATLAB environment is already set up and working — use environment validation directly instead
- User is asking about a specific MATLAB task (use the appropriate domain skill)

## Workflow Overview

1. **Discovery** (silent) — detect platform, find MATLAB installations, check for existing MCP server, detect agent platform
2. **Plan** (interactive) — present everything found and all proposed actions in a single summary; let the user confirm or adjust before any changes are made
3. **Execute** (uninterrupted) — carry out the approved plan: install binary, configure agent
4. **Verify** — confirm the MCP server can reach MATLAB
5. **Report** — present a final summary of everything that was set up and where it lives

The goal is to ask the user **once** for all decisions, then execute without further interruption.

---

## Phase 1: Discovery

Print a brief status message before starting: **"Scanning your system for MATLAB installations and checking the current setup. You may be asked to approve some read-only commands — I'm just gathering information, not making any changes yet."**

Run all of these checks silently — do not prompt the user during this phase. Collect all results for presentation in Phase 2.

### 1a. Detect platform

```bash
uname -s   # Darwin, Linux, or MINGW*/MSYS* for Windows
uname -m   # arm64, x86_64, aarch64
```

Map to binary asset names:

| OS | Architecture | Asset Name |
|----|-------------|------------|
| macOS | arm64 | `matlab-mcp-core-server-maca64` |
| macOS | x86_64 | `matlab-mcp-core-server-maci64` |
| Linux | x86_64 | `matlab-mcp-core-server-glnxa64` |
| Windows | x86_64 | `matlab-mcp-core-server-win64.exe` |

The local binary name is always `matlab-mcp-core-server` (or `matlab-mcp-core-server.exe` on Windows).

### 1b. Check for existing config

```bash
cat ~/.matlab-agentic-toolkit/config.json 2>/dev/null
```

If a config exists with valid paths, note the stored values as defaults for Phase 2.

### 1c. Find MATLAB installations

Search all of: PATH (`which matlab`), common locations, and macOS Spotlight. Collect ALL results.

| Platform | Search locations |
|----------|-----------------|
| macOS | `/Applications/*/MATLAB_*.app`, `/Applications/MATLAB_*.app`, Spotlight |
| Linux | `/usr/local/MATLAB/R20*`, `/opt/MATLAB/R20*` |
| Windows | `/c/Program Files/MATLAB/R20*` |

Validate each: `test -x "$MATLAB_ROOT/bin/matlab"` and read version from `VersionInfo.xml`.

### 1d. Check for existing MCP server

Check `~/.local/bin/matlab-mcp-core-server --version` and `which matlab-mcp-core-server`. If found, record path and version. Query latest from GitHub:

```bash
curl -sL https://api.github.com/repos/matlab/matlab-mcp-core-server/releases/latest | grep '"tag_name"' | head -1 | sed 's/.*"\(v[^"]*\)".*/\1/'
```

### 1e. Check existing agent configuration

For Claude Code:
```bash
claude plugin list 2>&1
```

For other platforms, check if their global config files already have a `matlab` MCP server entry (see platform-specific reference files for paths).

### 1f. Detect agent platform

Check environment and CLI tools: `claude --version` (Claude Code), `$CURSOR_TRACE` (Cursor), `codex --version` (Codex), `amp --version` (Amp), `gemini --version` (Gemini CLI), `$VSCODE_*` (Copilot). If ambiguous, ask the user.

### 1g. Check for legacy artifacts

Read the platform-specific reference file and check for any items listed in its **Legacy Artifacts** section (if present). Record what was found — these will be shown in the plan and cleaned up during Phase 3.

**Reference file resolution:** On re-runs (when `~/.matlab-agentic-toolkit/config.json` exists), resolve reference files from `toolkitRoot` in that config (e.g., `<toolkitRoot>/skills-catalog/toolkit/matlab-agentic-toolkit-setup/reference/<filename>`), not from the skill's base directory. This avoids reading stale cached versions when the skill is loaded from a plugin cache.

---

## Phase 2: Plan

Present ALL discoveries and proposed actions in a **single message**. If the agent has an interactive elicitation tool available, it may use it. Otherwise, print the plan and wait for a normal user reply. Format the plan like this:

```
MATLAB Agentic Toolkit — Setup Plan
====================================

Platform:  macOS arm64

MATLAB installations found:
  [1] R2025b  /Applications/MATLAB_R2025b.app
  [2] R2024b  /Applications/MATLAB_R2024b.app

MCP server:
  Installed:  not found
  Latest:     v0.7.0

Agent platform:  Claude Code (detected)
  Status:        Tested

Proposed actions:
  MATLAB:        Use R2025b (/Applications/MATLAB_R2025b.app)
  MCP server:    Download v0.7.0 to ~/.local/bin/matlab-mcp-core-server
  Display mode:  desktop (full MATLAB desktop visible)
  Agent config:  Configure MCP server globally (available in all sessions)
  Migration:     (none)

Proceed with this plan? You can adjust any choice:
  - Pick a different MATLAB: "use 2" or provide a path
  - Keep existing server: "use server at /path/to/binary"
  - Change display: "use nodesktop" (MATLAB runs headless; windows still open for plots)
  - Configure a different agent: "use Cursor" or "use Amp"
```

The **Migration** row shows legacy artifacts found in Phase 1g. If none were found, show `(none)`. If artifacts were found, list what will be cleaned up, e.g., `Remove ~/.claude/.mcp.json (migrated to claude mcp add)`.

For non-Claude platforms, clearly note "EXPERIMENTAL — untested, provided as-is" and that manual fallback will be provided if automated setup fails.

For OpenAI Codex specifically, the plan must cover **both**:
- Global MCP configuration in `~/.codex/config.toml`
- Global skill references in `~/.agents/skills/` so the toolkit is available from any repo after setup

### Decision points

| Decision | Default | How to override |
|----------|---------|-----------------|
| Which MATLAB | Newest release found | User picks by number or provides a path |
| MCP server | Download latest to `~/.local/bin/` | User says "use existing" or provides a path |
| Display mode | `desktop` | User says "use nodesktop" |
| Agent platform | Auto-detected | User says "use [platform]" |

### If no MATLAB found

Report that no MATLAB was found and ask the user to provide the path to their MATLAB root directory. Validate before proceeding.

### User confirms

Once the user confirms — move to Phase 3. If they adjust choices, update the plan and re-confirm only if changes are significant.

---

## Phase 3: Execute

Print a brief status message before starting: **"Great — executing the plan now. I'll be downloading, writing config files, and registering skills. You may be asked to approve some of these actions depending on your permissions settings."**

Carry out the approved plan. Do NOT prompt the user during this phase — all decisions were made in Phase 2.

### 3a. Install MCP server (if needed)

Download using `curl` (preferred) or `wget` to `~/.local/bin/matlab-mcp-core-server`:

```bash
mkdir -p ~/.local/bin
curl -sL -o ~/.local/bin/matlab-mcp-core-server \
  "https://github.com/matlab/matlab-mcp-core-server/releases/download/${LATEST_TAG}/${ASSET_NAME}"
```

Post-download: `chmod +x` (macOS/Linux), `xattr -d com.apple.quarantine` (macOS), `Unblock-File` (Windows). If macOS Gatekeeper blocks: System Settings > Privacy & Security > Allow Anyway.

Verify: `~/.local/bin/matlab-mcp-core-server --version`

If download fails, provide the direct URL for manual download.

### 3b-migrate. Clean up legacy artifacts

If Phase 1g found any legacy artifacts, clean them up now according to the instructions in the platform reference file's **Legacy Artifacts** section. Only remove artifacts after the new configuration has been written successfully (i.e., run this after 3b-platform, not before).

### 3b-shared. Register global skills (Copilot, Codex, Gemini)

For platforms that discover skills from `~/.agents/skills/` — GitHub Copilot, OpenAI Codex, and Gemini CLI — create symlinks pointing back to the toolkit repo. This only needs to run once, even if multiple platforms are configured.

The toolkit includes cross-platform helper scripts:

**macOS / Linux:**
```bash
bash "<TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup/scripts/install-global-skills.sh" "<TOOLKIT_ROOT>"
```

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File "<TOOLKIT_ROOT>\skills-catalog\toolkit\matlab-agentic-toolkit-setup\scripts\install-global-skills.ps1" -ToolkitRoot "<TOOLKIT_ROOT>"
```

These scripts auto-discover all published skills (any directory under `skills-catalog/` that contains a `manifest.yaml`) and create symlinks such as:
```text
~/.agents/skills/matlab-testing        -> <TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-testing
~/.agents/skills/matlab-debugging      -> <TOOLKIT_ROOT>/skills-catalog/matlab-core/matlab-debugging
~/.agents/skills/matlab-agentic-toolkit-setup -> <TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup
```

Echo back the list of skill links created or updated.

> **Why `~/.agents/skills/`?** This is the cross-platform convention for global skill discovery. Copilot, Codex, and Gemini CLI all read from this directory natively. Using a single canonical location avoids duplicate skill warnings when multiple agents are installed.

### 3b-platform. Configure agent platform

**Automated setup for each platform:**

#### GitHub Copilot

Uses `~/.vscode/settings.json`. Automate using Python (jq may not be installed):

```python
import json, os
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

Skills are registered via the shared step (3b-shared) — no additional symlinks needed here.

Echo back:
- File path: `~/.vscode/settings.json`
- MATLAB entry was added/updated

#### Claude Code

Uses `claude mcp add` CLI to register the MCP server globally. Do NOT write `~/.claude/.mcp.json` manually — that file is not read by Claude Code.

**Step 1: Add the marketplace**

Derive the marketplace URL from the toolkit repo's own origin remote, so the registered marketplace always matches where the user cloned from:

```bash
MARKETPLACE_URL=$(git -C "<TOOLKIT_ROOT>" remote get-url origin)
claude plugin marketplace add "$MARKETPLACE_URL"
```

If already registered, this is a no-op.

**Step 2: Install all plugins**

Read `<TOOLKIT_ROOT>/.claude-plugin/marketplace.json`, extract the `name` field from each entry in the `plugins` array, and install every plugin:

```bash
claude plugin install <plugin-name>@matlab-agentic-toolkit
```

Run one `claude plugin install` command per plugin. Claude's native prompt will ask the user to choose scope. Do NOT implement your own scope selection.

**Step 3: Register MCP server**

```bash
claude mcp add-json -s user matlab '{"command":"<MCP_SERVER_PATH>","args":["--matlab-root","<MATLAB_ROOT>","--matlab-display-mode","<DISPLAY_MODE>"]}'
```

This registers the server at user scope (available in all projects). If a `matlab` entry already exists, it is overwritten. MCP tools become available in the next session.

**Step 4: Verify plugin installation**

```bash
claude plugin list 2>&1
```

If `claude` CLI plugin commands fail, skip plugin installation — skills can be used by reading SKILL.md files directly. The MCP registration (Step 3) works independently via `claude mcp add`, which is a core CLI command.

Echo back the `claude mcp add-json` command that was run and confirm it succeeded.

See `reference/claude-code-setup-guidance.md` for legacy artifact cleanup and additional troubleshooting details.

#### Other platforms

**Read** the platform-specific reference file (located in the `reference/` directory next to this skill file) and follow its instructions exactly. Use the toolkit root to resolve the path: `<TOOLKIT_ROOT>/skills-catalog/toolkit/matlab-agentic-toolkit-setup/reference/<filename>`.

| Platform | Reference file |
|----------|---------------|
| Cursor | `reference/cursor-setup-guidance.md` |
| OpenAI Codex | `reference/codex-setup-guidance.md` |
| Sourcegraph Amp | `reference/amp-setup-guidance.md` |
| Gemini CLI | `reference/gemini-cli-setup-guidance.md` |

Each reference file contains the exact config format, **global config path**, merge instructions, and manual fallback steps. The MCP server should be configured **globally** (not per-project) so it is available in every session regardless of which workspace the user opens.

**After writing any config file**, always echo back to the user:
1. The file path that was written
2. The exact content that was written
3. Whether the file was created new or an existing entry was updated

### 3c. Save state

Write configuration to `~/.matlab-agentic-toolkit/config.json`:

```bash
mkdir -p ~/.matlab-agentic-toolkit
```

```json
{
  "matlabRoot": "<MATLAB_ROOT>",
  "toolkitRoot": "<TOOLKIT_ROOT>",
  "mcpServerPath": "<FULL_PATH_TO_BINARY>",
  "mcpServerVersion": "<VERSION>",
  "displayMode": "<DISPLAY_MODE>",
  "configuredPlatforms": ["<PLATFORM>"],
  "setupSkillVersion": "<SKILL_VERSION>",
  "lastSetup": "<ISO_8601_TIMESTAMP>"
}
```

The `setupSkillVersion` field records the skill `metadata.version` from the YAML front matter of this file. This allows future runs to detect when the skill has been updated and whether migration steps may apply.

---

## Phase 4: Verify

Print a brief status message: **"Setup is done — verifying the connection to MATLAB."**

Verification depends on the agent platform.

### Claude Code

Use the MATLAB MCP tools (now available via the plugin) to run:

```matlab
v = ver('MATLAB');
fprintf('MATLAB %s (%s) — ready.\n', v.Version, v.Release);
```

If MCP tools are not available in the current session (common after first-time setup), tell the user:

> The plugin was just installed. Start a **new Claude Code session** to activate the MATLAB MCP tools, then verify with: "What version of MATLAB is running?"

### Other platforms

For non-Claude platforms, verify what we can:

1. **Binary runs:**
   ```bash
   ~/.local/bin/matlab-mcp-core-server --version
   ```

2. **Config file exists and contains the matlab entry:**
   ```bash
   cat <GLOBAL_CONFIG_PATH> 2>/dev/null | grep -l matlab
   ```

3. **Tell the user how to verify in their agent:**
   > Restart [platform name], then ask: "What version of MATLAB is running?"
   > If the agent can call `detect_matlab_toolboxes` or `evaluate_matlab_code`, setup was successful.

If verification fails:
1. Verify `matlab-mcp-core-server` is accessible (`which matlab-mcp-core-server`)
2. Try running the server manually to diagnose:
   ```bash
   ~/.local/bin/matlab-mcp-core-server --matlab-root <path> --matlab-display-mode desktop 2>&1 | head -20
   ```
3. Look for "Application startup complete" in the output

---

## Phase 5: Report

Present a final summary including: MATLAB version and location, MCP server version and binary path, display mode, agent platform and config file path, and state file location.

**For Claude Code:** List installed plugins and their scope. Next steps: start new session, try "What version of MATLAB is running?", list available skills.

**For other platforms:** Mark as "EXPERIMENTAL". Next steps: restart the agent, try "What version of MATLAB is running?". Include troubleshooting: check config file, test binary, link to GETTING_STARTED.md and issue tracker (https://github.com/matlab/matlab-agentic-toolkit/issues).

---

## Re-run Behavior

When setup is run again: read existing config as defaults, run full discovery, present plan showing current vs. proposed state (e.g., "Upgrade v0.6.0 → v0.7.0"), execute only what changed, verify and report.

---

## Conventions

- Use `bash` commands for all steps except verification (Phase 4 for Claude Code), which uses MATLAB MCP tools
- Never modify files outside the toolkit directory, `~/.matlab-agentic-toolkit/`, and the platform's global config path
- Collect all information silently in Phase 1; present all decisions together in Phase 2
- On failure, provide an actionable message — never show raw errors without context
- For non-Claude platforms, always provide manual fallback instructions
- **Windows path escaping:** JSON and TOML both treat `\` as an escape character. When writing Windows paths to config files or passing them in CLI commands (like `claude mcp add-json`), you must either use forward slashes (`C:/Users/Name/...`) or double every backslash (`C:\\Users\\Name\\...`). Raw backslashes produce invalid escape sequences that silently corrupt config files. Python's `json.dump()` handles this automatically when paths are passed as string values — prefer programmatic writes over string interpolation.

## Guardrails

### Always
- Check for existing installation before downloading
- Validate MATLAB root before proceeding
- Present the full plan before making any changes
- Echo back exactly what was written to config files
- Clearly label experimental/untested platform support

### Ask First
- All decisions are presented together in Phase 2 — no mid-execution prompts
- If multiple MATLAB installations found, present the list and recommend the newest

### Never
- Run MATLAB via bash/terminal — use MCP tools only (and only in Phase 4 for Claude Code)
- Install MATLAB itself
- Overwrite existing config entries for other MCP servers (only add/update the `matlab` entry)
- Skip the verification step
- Prompt the user during Phase 1 (discovery) or Phase 3 (execution)
- Claim untested platforms are fully supported

----

Copyright 2026 The MathWorks, Inc.

----

