---
name: matlab-agentic-toolkit-setup
description: Install and configure the MATLAB Agentic Toolkit — detect MATLAB, install the MCP server, register the Claude Code plugin, and verify the environment. Run this after cloning the toolkit or when troubleshooting setup issues.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Agentic Toolkit Setup

Automated onboarding for the MATLAB Agentic Toolkit. Detects MATLAB, downloads and installs the MCP server binary, registers the Claude Code plugin, and verifies everything works. The MCP server config is declared inline in the `matlab-core` plugin (`marketplace.json`), so installing the plugin activates the server automatically — no separate `.mcp.json` is needed.

This skill does NOT require the MATLAB MCP server — it uses shell commands for everything until the final verification step.

## When to Use

- User runs `/matlab-setup` or asks to set up the MATLAB Agentic Toolkit
- First time using the toolkit after cloning
- After moving the toolkit to a new location
- After installing a new MATLAB version
- To upgrade the MCP server to the latest version
- MCP connection issues that may indicate a broken installation

## When NOT to Use

- MATLAB environment is already set up and working — use environment validation directly instead
- User is asking about a specific MATLAB task (use the appropriate domain skill)
- User wants to configure agents other than Claude Code (not yet supported)

## Workflow Overview

The setup has two phases:

1. **Discovery** (silent) — detect platform, find MATLAB installations, check for existing MCP server, read existing config
2. **Plan** (interactive) — present everything found and all proposed actions in a single summary; let the user confirm or adjust before any changes are made
3. **Execute** (uninterrupted) — carry out the approved plan: install binary, register plugin
4. **Verify** — confirm the MCP server can reach MATLAB
5. **Report** — present a final summary of everything that was set up and where it lives

The goal is to ask the user **once** for all decisions, then execute without further interruption.

---

## Phase 1: Discovery

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

Search in this order and collect ALL results (do not stop at the first match):

1. **PATH:**
   ```bash
   which matlab 2>/dev/null
   # If found, resolve symlinks and go up to the MATLAB root
   ```

2. **Common locations** (platform-specific):
   - **macOS:**
     ```bash
     ls -d /Applications/MATLAB*/MATLAB_*.app 2>/dev/null
     ls -d /Applications/MATLAB_*.app 2>/dev/null
     ```
   - **Linux:**
     ```bash
     ls -d /usr/local/MATLAB/R20* 2>/dev/null
     ls -d /opt/MATLAB/R20* 2>/dev/null
     ```
   - **Windows:**
     ```bash
     ls -d /c/Program\ Files/MATLAB/R20* 2>/dev/null
     ```

3. **macOS Spotlight** (fallback):
   ```bash
   mdfind "kMDItemCFBundleIdentifier == 'com.mathworks.matlab'" 2>/dev/null
   ```

For each installation found, validate and read the version:

```bash
test -x "$MATLAB_ROOT/bin/matlab" && echo "Valid" || echo "Invalid"
cat "$MATLAB_ROOT/VersionInfo.xml" 2>/dev/null | grep -o 'R20[0-9][0-9][ab]'
```

### 1d. Check for existing MCP server

Search for an existing binary:

```bash
# Check the standard install location
~/.local/bin/matlab-mcp-core-server --version 2>/dev/null

# Check PATH
which matlab-mcp-core-server 2>/dev/null
```

If found, record its path and version. Also query the latest available version from GitHub:

```bash
curl -sL https://api.github.com/repos/matlab/matlab-mcp-core-server/releases/latest | grep '"tag_name"' | head -1 | sed 's/.*"\(v[^"]*\)".*/\1/'
```

### 1e. Check existing plugin registration

```bash
claude plugin list 2>&1
```

Note whether `matlab-core@matlab-agentic-toolkit` and `toolkit@matlab-agentic-toolkit` are already installed and at which version/scope.

---

## Phase 2: Plan

Present ALL discoveries and proposed actions in a **single message**. Use AskUserQuestion to let the user confirm or adjust. Format the plan like this:

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

Plugins:
  matlab-core:  not installed
  toolkit:      not installed

Proposed actions:
  MATLAB:        Use R2025b (/Applications/MATLAB_R2025b.app)
  MCP server:    Download v0.7.0 to ~/.local/bin/matlab-mcp-core-server
  Display mode:  nodesktop (MATLAB runs headless; windows still open for plots)
  Plugins:       Install matlab-core (includes MCP server) and toolkit

Proceed with this plan? You can adjust any choice:
  - Pick a different MATLAB: "use 2" or provide a path
  - Keep existing server: "use server at /path/to/binary"
  - Change display: "use desktop" (full MATLAB GUI visible)
```

### Decision points in the plan

| Decision | Default | How to override |
|----------|---------|-----------------|
| Which MATLAB | Newest release found | User picks by number or provides a path |
| MCP server | Download latest to `~/.local/bin/` | User says "use existing" or provides a path |
| Display mode | `nodesktop` | User says "use desktop" |

### If existing MCP server found

Adjust the plan accordingly:

- If **current version**: propose keeping it ("MCP server: keep v0.7.0 at ~/.local/bin/matlab-mcp-core-server")
- If **outdated**: propose upgrading ("MCP server: upgrade v0.5.0 -> v0.7.0 at ~/.local/bin/matlab-mcp-core-server")
- If **at a non-standard path**: use that path

### If no MATLAB found

```
MATLAB installations found: none

Cannot proceed without a MATLAB installation.
Please provide the path to your MATLAB root directory.
```

Wait for the user to provide a path, then validate it.

### User confirms

Once the user says "yes", "looks good", "proceed", or similar — move to Phase 3. If they adjust choices, update the plan and re-confirm only if the changes are significant.

---

## Phase 3: Execute

Carry out the approved plan. Do NOT prompt the user during this phase — all decisions were made in Phase 2.

### 3a. Install MCP server (if needed)

If downloading:

```bash
# Determine download tool
command -v curl >/dev/null 2>&1 && echo "curl" || (command -v wget >/dev/null 2>&1 && echo "wget" || echo "none")

# Create install directory
mkdir -p ~/.local/bin

# Download (curl)
curl -sL -o ~/.local/bin/matlab-mcp-core-server "https://github.com/matlab/matlab-mcp-core-server/releases/download/${LATEST_TAG}/${ASSET_NAME}"

# OR Download (wget)
wget -q -O ~/.local/bin/matlab-mcp-core-server "https://github.com/matlab/matlab-mcp-core-server/releases/download/${LATEST_TAG}/${ASSET_NAME}"
```

If the download fails, provide the direct URL and suggest the user download manually.

Post-download (platform-specific):

**macOS:**
```bash
chmod +x ~/.local/bin/matlab-mcp-core-server
xattr -d com.apple.quarantine ~/.local/bin/matlab-mcp-core-server 2>/dev/null
```

**Linux:**
```bash
chmod +x ~/.local/bin/matlab-mcp-core-server
```

**Windows:**
```powershell
Unblock-File -Path "$env:USERPROFILE\.local\bin\matlab-mcp-core-server.exe"
```

If macOS Gatekeeper blocks the binary:
> Open **System Settings > Privacy & Security**, scroll down, and click **"Allow Anyway"** next to the blocked binary. Then re-run `/matlab-setup`.

Verify the binary runs:

```bash
~/.local/bin/matlab-mcp-core-server --version
```

### 3b. Register plugin (Claude Code)

The `matlab-core` plugin declares the MATLAB MCP server inline in `marketplace.json`. When the plugin is installed, Claude Code automatically starts the server — no separate `.mcp.json` is needed.

```bash
claude plugin marketplace add "<TOOLKIT_ROOT>"
```

If the marketplace is already registered, continue.

```bash
claude plugin install matlab-core@matlab-agentic-toolkit
claude plugin install toolkit@matlab-agentic-toolkit
```

Claude's native prompt will ask the user to choose scope for each plugin. Do NOT implement your own scope selection.

After `matlab-core` is installed, the MATLAB MCP server starts automatically. The MCP tools become available in the next session (or immediately if the session is restarted).

If `claude` CLI commands fail (not available in the user's Claude Code version):
1. Report the error clearly
2. Provide manual fallback instructions from GETTING_STARTED.md

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
  "lastSetup": "<ISO_8601_TIMESTAMP>"
}
```

---

## Phase 4: Verify

Now that everything is installed, verify the MCP server can start and communicate with MATLAB.

Use the MATLAB MCP tools (now available via the plugin) to run a verification:

```matlab
v = ver('MATLAB');
fprintf('MATLAB %s (%s) — ready.\n', v.Version, v.Release);
```

If MCP tools are not available in the current session (common after first-time setup), tell the user:

> The plugin was just installed. Start a **new Claude Code session** to activate the MATLAB MCP tools, then verify with: "What version of MATLAB is running?"

If verification succeeds, proceed to the final report.

If verification fails:
1. Verify `matlab-mcp-core-server` is on PATH (`which matlab-mcp-core-server`)
2. Try running the server manually to diagnose:
   ```bash
   ~/.local/bin/matlab-mcp-core-server --matlab-root <path> --matlab-display-mode nodesktop 2>&1 | head -20
   ```
3. Look for "Application startup complete" in the output — if present, the server works but the session needs restarting

---

## Phase 5: Report

Present a final summary of everything that was set up. This is the last thing the user sees.

```
Setup Complete
==============

MATLAB
  Version:   R2025b
  Location:  /Applications/MATLAB_R2025b.app

MCP Server
  Version:   v0.7.0
  Binary:    /Users/jane/.local/bin/matlab-mcp-core-server
  Display:   nodesktop

Configuration
  State file:  ~/.matlab-agentic-toolkit/config.json

Plugins
  matlab-core@matlab-agentic-toolkit   0.1.0  (user)  [MCP server: matlab]
  toolkit@matlab-agentic-toolkit       0.1.0  (user)

Next steps:
  1. Start a new Claude Code session to activate MCP tools
  2. Try: "What version of MATLAB is running?"
  3. Available skills: /matlab-setup, /testing, /creating-live-scripts,
     /building-apps, /reviewing-code, /debugging, /modernizing-code

To change settings later, re-run /matlab-setup.
```

---

## Re-run Behavior

When `/matlab-setup` is run again:

1. **Read existing config** from `~/.matlab-agentic-toolkit/config.json`
2. **Run full discovery** (Phase 1) — stored config values become defaults
3. **Present plan** (Phase 2) — show current vs. proposed state, highlight what would change
4. **Execute only changes** (Phase 3) — skip steps that are already correct
5. **Verify and report** (Phases 4-5)

For re-runs, the plan summary should show the current state alongside proposed changes:

```
MCP server:
  Current:   v0.6.0 at ~/.local/bin/matlab-mcp-core-server
  Available: v0.7.0
  Action:    Upgrade

MATLAB:
  Current:   R2025a (/Applications/MATLAB_R2025a.app)
  Also found: R2025b (/Applications/MATLAB_R2025b.app)
  Action:    Keep R2025a (say "use R2025b" to switch)
```

---

## Conventions

- Use `bash` commands for all steps except verification (Phase 4), which uses MATLAB MCP tools
- Never modify files outside the toolkit directory and `~/.matlab-agentic-toolkit/` without the approved plan
- Collect all information silently in Phase 1; present all decisions together in Phase 2
- On failure at any point, provide an actionable message — never show raw errors without context

## Guardrails

### Always
- Check for existing installation before downloading
- Validate MATLAB root before proceeding
- Present the full plan before making any changes

### Ask First
- All decisions are presented together in Phase 2 — no mid-execution prompts
- If multiple MATLAB installations found, present the list and recommend the newest

### Never
- Run MATLAB via bash/terminal — use MCP tools only (and only in Phase 4)
- Install MATLAB itself
- Modify agent configurations other than Claude Code
- Skip the verification step
- Prompt the user during Phase 1 (discovery) or Phase 3 (execution)
