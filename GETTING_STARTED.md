# Getting Started with the MATLAB&reg; Agentic Toolkit

This guide takes you from download to your first agent-driven MATLAB interaction. By the end, your agent will run MATLAB code, list installed toolboxes, and generate a unit test.

> For a project overview, tool/skill reference, and documentation links, see the [README](README.md).

---

## Prerequisites

Before you begin, make sure you have:

- [ ] **MATLAB R2020b or later** installed
- [ ] **An AI coding agent** that supports MCP. Turn-key configurations are included for [Claude Code](https://claude.ai/code), [Cursor](https://www.cursor.com/), [OpenAI&reg; Codex](https://openai.com/codex), [GitHub&reg; Copilot](https://github.com/features/copilot), [Sourcegraph Amp](https://ampcode.com/), and [Gemini&trade; CLI](https://github.com/google-gemini/gemini-cli). **Tested platform:** Claude Code. Other platforms are provided as-is.
- [ ] **Git&trade;** (to clone the toolkit)

---

## Quick Start (Claude Code)

Clone the repository, then launch Claude.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
cd matlab-agentic-toolkit
claude
```

Then inside Claude Code, ask Claude to set up the toolkit:

```
Set up the MATLAB Agentic Toolkit
```

That's it. Claude reads the repository's `CLAUDE.md`, finds the setup instructions, and walks you through the process (e.g., which MATLAB to use if you have several installed, and which scope to install the plugin at). Once setup completes, start a new Claude Code session in any project directory — MATLAB skills and MCP tools are available everywhere.

> **Tip:** After the first setup, `/matlab-setup` is available as a slash command for re-running setup (e.g., to upgrade the MCP server or switch MATLAB versions).

> **Tip:** Choose a location for the toolkit outside your project directories. The toolkit is shared across all your projects.

---

## What Setup Does

1. **Detects your platform** — OS and architecture
2. **Finds MATLAB** — searches PATH, common install locations, and macOS Spotlight
3. **Downloads the MCP server** — fetches the correct [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) binary from GitHub releases to `~/.local/bin/`
4. **Generates `.mcp.json`** — writes the MCP server configuration with your system-specific paths
5. **Registers the plugin** — adds the toolkit marketplace and installs the `matlab-core` plugin via `claude plugin install`
6. **Verifies** — confirms the MCP server can reach MATLAB and reports the environment summary

Setup is re-runnable. Run it again (via `/matlab-setup` or by asking Claude) to upgrade the MCP server, switch MATLAB versions, or fix a broken configuration.

---

## Already Have the MCP Server?

If you have already installed and configured the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server), you can skip server installation and just add the skills.

**Claude Code:** Install the plugin, which adds skills without changing your existing MCP configuration:

```bash
cd /path/to/matlab-agentic-toolkit
claude plugin marketplace add "$(pwd)"
claude plugin install matlab-core@matlab-agentic-toolkit
```

When prompted, choose your preferred scope (per-project, per-user, or global). Your existing `.mcp.json` or MCP server configuration is not modified.

**Other agents:** Point your agent's skill/prompt directory at `skills-catalog/matlab-core/` (domain skills). Each skill is a self-contained `SKILL.md` with a `manifest.yaml`. No changes to your MCP configuration are needed.

---

## Installing the MCP Server Manually

If you are not using Claude Code, or prefer to install the MCP server yourself, follow these steps.

### 1. Download the binary

Go to the [MATLAB MCP Core Server releases](https://github.com/matlab/matlab-mcp-core-server/releases/latest) page and download the binary for your platform:

| OS | Architecture | Asset Name |
|----|-------------|------------|
| macOS | Apple silicon (arm64) | `matlab-mcp-core-server-maca64` |
| macOS | Intel (x86_64) | `matlab-mcp-core-server-maci64` |
| Linux | x86_64 | `matlab-mcp-core-server-glnxa64` |
| Windows | x86_64 | `matlab-mcp-core-server-win64.exe` |

### 2. Install the binary

Place the downloaded binary in a directory on your PATH (e.g., `~/.local/bin/`), rename it to `matlab-mcp-core-server` (or `matlab-mcp-core-server.exe` on Windows), and make it executable:

**macOS:**
```bash
mkdir -p ~/.local/bin
mv ~/Downloads/matlab-mcp-core-server-maca64 ~/.local/bin/matlab-mcp-core-server
chmod +x ~/.local/bin/matlab-mcp-core-server
xattr -d com.apple.quarantine ~/.local/bin/matlab-mcp-core-server 2>/dev/null
```

**Linux:**
```bash
mkdir -p ~/.local/bin
mv ~/Downloads/matlab-mcp-core-server-glnxa64 ~/.local/bin/matlab-mcp-core-server
chmod +x ~/.local/bin/matlab-mcp-core-server
```

**Windows (PowerShell):**
```powershell
Move-Item ~\Downloads\matlab-mcp-core-server-win64.exe ~\.local\bin\matlab-mcp-core-server.exe
Unblock-File -Path "$env:USERPROFILE\.local\bin\matlab-mcp-core-server.exe"
```

### 3. Verify the binary runs

```bash
~/.local/bin/matlab-mcp-core-server --version
```

> **macOS note:** If macOS blocks the binary (Gatekeeper), go to **System Settings > Privacy & Security** and click **"Allow Anyway"** next to the blocked binary.

---

## Other Agent Platforms

Each platform below needs two things: an MCP server connection and (optionally) skills. If you haven't installed the MCP server binary yet, see [Installing the MCP Server Manually](#installing-the-mcp-server-manually) above.

In the configuration examples below, replace `/path/to/matlab-mcp-core-server` with the actual path to your installed binary (e.g., `~/.local/bin/matlab-mcp-core-server`).

### GitHub Copilot

Create `.vscode/mcp.json` in your workspace (this file is not included in the toolkit since it is workspace-specific):

```json
{
  "servers": {
    "matlab": {
      "type": "stdio",
      "command": "/path/to/matlab-mcp-core-server"
    }
  }
}
```

**Skills:** Copy or symlink skill directories from `skills-catalog/matlab-core/` (domain skills) into your project, or reference them in your Copilot instructions file.

### Cursor

The toolkit includes `.cursor-plugin/plugin.json` with skills and MCP configuration.

1. Open the toolkit directory in Cursor, or symlink `.cursor-plugin/` into your project root.
2. Edit `.cursor-plugin/plugin.json` and replace `"/path/to/matlab-mcp-core-server"` with the absolute path to your installed binary.

Cursor discovers plugins from the `.cursor-plugin/` directory at the project root.

### OpenAI Codex

The toolkit includes pre-configured files for Codex:

| File | Purpose |
|------|---------|
| `.agents/plugins/marketplace.json` | Plugin registry |
| `.codex-plugin/plugin.json` | Plugin definition with skills and MCP reference |
| `.codex-mcp.json` | MCP server configuration |

To use the toolkit with Codex:

1. Edit `.codex-mcp.json` and replace `"/path/to/matlab-mcp-core-server"` with the absolute path to your installed binary.
2. Open or symlink the toolkit directory so Codex can discover the plugin.

> **Note:** Codex uses `.codex-mcp.json` instead of `.mcp.json` to avoid conflicts with Claude Code, which auto-detects `.mcp.json` at the project root.

### Sourcegraph Amp

The toolkit includes `.amp/settings.json` which configures the MCP server. Amp will prompt you to approve the workspace MCP server on first open.

1. Edit `.amp/settings.json` and replace `"/path/to/matlab-mcp-core-server"` with the absolute path to your installed binary.

**Skills:** Install the toolkit skills:
```bash
amp skill add /path/to/matlab-agentic-toolkit/skills-catalog/matlab-core
```

### Gemini CLI

The toolkit includes `gemini-extension.json` for MCP server configuration.

1. Edit `gemini-extension.json` and replace `"/path/to/matlab-mcp-core-server"` with the absolute path to your installed binary.
2. Reference the extension from your Gemini CLI configuration (typically `~/.gemini/settings.json`) by adding it to the `extensions` array. See the [Gemini CLI documentation](https://github.com/google-gemini/gemini-cli) for details.

**Skills:** Copy skill directories from `skills-catalog/matlab-core/` (domain skills) into your project or reference them in your Gemini instructions.

### Other Agents

Any coding agent that supports MCP can use the toolkit. You need two things:

1. **MCP server** — point your agent's MCP configuration at the installed binary:
   ```json
   {
     "command": "/path/to/matlab-mcp-core-server"
   }
   ```
2. **Skills** *(optional)* — if your agent supports skill/prompt files, point it at `skills-catalog/matlab-core/` (domain skills). Each skill is a `SKILL.md` with a `manifest.yaml`.

---

## Step-by-Step Verification

After setup, confirm everything works.

### Check that skills are loaded

If your agent shows loaded skills or plugins in its UI (e.g., Claude Code's `/skills` command), confirm the MATLAB Agentic Toolkit skills are listed:

| Skill | Description |
|-------|-------------|
| **matlab-agentic-toolkit-setup** | Install and configure the toolkit, install MCP server |
| **testing** | Generate and run unit tests with `matlab.unittest` |
| **creating-live-scripts** | Create plain-text Live Scripts (R2025a+) |
| **building-apps** | Build apps programmatically with `uifigure` |
| **reviewing-code** | Review code for quality and MathWorks&reg; coding standards |
| **debugging** | Diagnose errors via MCP eval |
| **modernizing-code** | Replace deprecated functions with modern equivalents |

### Try it out

Ask your agent:

```
What version of MATLAB is running? List the installed toolboxes.
```

The agent calls `detect_matlab_toolboxes` via MCP and reports the MATLAB version and available toolboxes.

### More examples

```
Write a function that computes the moving average of a signal, then generate unit tests for it.
```

```
Review the file myScript.m for code quality issues and suggest improvements.
```

```
Create a plain-text Live Script that demonstrates curve fitting with sample data.
```

---

## Updating the Toolkit

The toolkit has two independently versioned components: the **toolkit itself** (skills, configurations, and documentation in this repository) and the **MCP server binary** ([MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server)). Update each one separately.

### Updating skills and configurations

Pull the latest changes from the repository:

```bash
cd /path/to/matlab-agentic-toolkit
git pull
```

This updates all skills, platform configurations, and documentation. No reinstallation is needed — your agent picks up the changes on its next session.

**Marketplace-aware platforms:** If your agent platform has a marketplace or plugin registry (e.g., Claude Code, Cursor, Codex, Gemini CLI), it may detect toolkit updates automatically through its native update mechanism. Check your platform's documentation for details.

**Claude Code:** The plugin marketplace tracks the toolkit repository. You can also re-run setup at any time (via `/matlab-setup` or by asking Claude) to pull the latest configuration and verify your environment.

### Updating the MCP server

The MCP server binary is released independently from the toolkit. To update it:

- **Claude Code:** Re-run setup (`/matlab-setup` or ask Claude to set up the toolkit). Setup detects the installed version, downloads a newer release if available, and updates the configuration.
- **Other platforms:** Download the latest binary from [MATLAB MCP Core Server releases](https://github.com/matlab/matlab-mcp-core-server/releases/latest) and replace the existing binary. See [Installing the MCP Server Manually](#installing-the-mcp-server-manually) for platform-specific instructions.

> **Tip:** Watch or star the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) repository on GitHub to get notified of new releases.

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Setup can't find MATLAB | Non-standard install location | Provide the path when prompted |
| MCP server download fails | Network/proxy/firewall | Download manually from [GitHub releases](https://github.com/matlab/matlab-mcp-core-server/releases), place in `~/.local/bin/`, re-run setup |
| macOS blocks the MCP server binary | Gatekeeper quarantine | Setup handles this automatically. If still blocked (MDM), go to System Settings > Privacy & Security > Allow Anyway |
| Agent doesn't list MATLAB skills | Plugin not installed | Re-run setup or manually run `claude plugin install matlab-core@matlab-agentic-toolkit` |
| MCP tools fail to connect | MCP server not running or wrong path | Re-run setup to regenerate config. Check that MATLAB is running |
| `evaluate_matlab_code` returns errors | MATLAB not running or not on PATH | Start MATLAB, or re-run setup to update the MATLAB root path |
| Config has `/path/to/matlab-mcp-core-server` | Placeholder not replaced | Edit the config file and replace with the actual path to your installed binary |

---

Copyright 2025-2026 The MathWorks, Inc.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See [mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list of additional trademarks. Other product or brand names may be trademarks or registered trademarks of their respective holders.
