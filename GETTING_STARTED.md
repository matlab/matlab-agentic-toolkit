# Getting Started with the MATLAB&reg; Agentic Toolkit

This guide walks you through setup of the MATLAB Agentic Toolkit. Once complete, the toolkit will be configured globally, for you to use on any project.  

> For a project overview, tool/skill reference, and documentation links, see the [README](README.md).

> Automated setup has been verified with basic workflows on each platform except Cursor. The toolkit is under active development — please [report issues](https://github.com/matlab/matlab-agentic-toolkit/issues) if you encounter problems.

---

## Prerequisites

Before you begin, make sure you have:

- [ ] **MATLAB R2020b or later** installed
- [ ] **An AI coding agent** that supports MCP — see [Supported Platforms](README.md#supported-platforms)
- [ ] **Git&trade;** (to clone the toolkit)

---

## Choose Your Path

| Path | When to use | What you get |
|------|-------------|--------------|
| [**Full Setup**](#full-setup) | First time; want everything automated | MCP server binary + skills + global configuration |
| [**Adding Skills Only**](#adding-skills-only) | Already have the [MCP server](https://github.com/matlab/matlab-mcp-core-server) configured | Skills/prompts only; no MCP changes |

---

## Full Setup

Full setup clones the toolkit repository, then uses your agent to automate the entire configuration. This is the recommended path for first-time users.

### What Setup Does

1. **Installs the MCP server** — downloads the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) binary to `~/.local/bin/`
2. **Configures your agent** — connects the MCP server to your agent via global config, defaulting to the most recent MATLAB found (you can change this during setup)
3. **Registers skills** — adds MATLAB skills via the platform's native plugin system or global skill links
4. **Verifies** — confirms the MCP server can reach MATLAB and reports an environment summary

Setup is re-runnable. Run it again to upgrade the MCP server, switch MATLAB versions, or fix a broken configuration.

### Step 1: Clone and Launch

Clone the toolkit to a permanent location outside your project directories (e.g., `~/tools/` or `~/repos/`). Most platforms reference this clone via symbolic links, so the toolkit needs to stay in place after setup.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
cd matlab-agentic-toolkit
```

Then launch your agent:

| Platform | Launch command |
|----------|---------------|
| Claude Code | `claude` |
| OpenAI Codex | `codex` |
| Gemini CLI | `gemini` |
| GitHub Copilot | Open folder in VS Code, then start Copilot chat |
| Sourcegraph Amp | `amp` |
| Cursor | Open folder in Cursor |

### Step 2: Run Setup

Ask your agent:

```
Set up the MATLAB Agentic Toolkit
```

The setup skill walks you through detection, planning, and execution. It presents all decisions (which MATLAB to use, display mode, etc.) before making any changes.

After setup completes, start a **new session in any project directory** — MATLAB tools and skills are available everywhere.

> **Tip:** After the first setup, you can re-run setup at any time to upgrade the MCP server, switch MATLAB versions, or fix a broken configuration. In Claude Code, use the `/matlab-setup` slash command. In other agents, ask "Set up the MATLAB Agentic Toolkit" from the toolkit directory.

### How Configuration Works per Platform

Setup writes two things: an MCP server configuration (so your agent can talk to MATLAB) and skill registrations (so your agent has MATLAB expertise). The details vary by platform. For more on how skills update, see [Updating](#updating).

| Platform | MCP Configuration | Skills Delivery | How To Update Toolkit |
|----------|------------------|-----------------|-------------------|
| Claude Code | `~/.claude/settings.json` | Plugin cache | Re-run setup or reinstall plugin |
| GitHub Copilot | `~/.vscode/settings.json` | `~/.agents/skills/` symlinks | `git pull` in toolkit repo, re-run setup |
| OpenAI Codex | `~/.codex/config.toml` | `~/.agents/skills/` symlinks | `git pull` in toolkit repo, re-run setup |
| Gemini CLI | `~/.gemini/settings.json` | `~/.agents/skills/` symlinks | `git pull` in toolkit repo, re-run setup |
| Sourcegraph Amp | `~/.config/amp/settings.json` | `amp.skills.path` direct ref | `git pull` in toolkit repo, re-run setup |
| Cursor | `~/.cursor/mcp.json` | `.cursor-plugin/` discovery | Manual |

**How skill symlinks work:** Most platforms discover skills from `~/.agents/skills/`. Setup creates symbolic links from that directory to the individual skill directories in your toolkit clone. When you run `git pull`, the linked skills update automatically. If new skills are added to the toolkit, re-run setup to create the additional symlinks.

> **Where we're headed:** As agent platforms mature their marketplace and plugin systems, the goal is to move toward a simple marketplace-based install for all platforms — add the MATLAB Agentic Toolkit marketplace, install the MATLAB Core plugin, and the plugin handles everything including MCP server installation and configuration. The current clone-and-setup workflow is expected to be a temporary work-around to help provide a good out-of-the-box experience in the meantime.


### Platform-Specific Notes

**Claude Code** — Setup registers the toolkit via the plugin marketplace and uses `claude mcp add -s user` to register the MCP server globally. Skills are cached by the plugin system. To re-run setup, use `/matlab-setup` or ask Claude to set up the toolkit.

**GitHub Copilot** — Setup writes global MCP config to `~/.vscode/settings.json` and creates skill symlinks in `~/.agents/skills/`. Reload VS Code after setup completes (Cmd/Ctrl + Shift + P, then "Developer: Reload Window").

**OpenAI Codex** — Setup uses `codex mcp add` if available, otherwise writes `~/.codex/config.toml` directly. Skills are installed as global symlinks in `~/.agents/skills/`. After setup, you may want to tune two settings in the `[mcp_servers.matlab]` section of `~/.codex/config.toml`:
- `tool_timeout_sec = 600` — increases the tool timeout from the default (which is too short for many MATLAB operations like test suites and simulations). Increase further for very long-running tasks.
- `env_vars = ['WINDIR']` — **Windows only.** Required for Simulink to work, since Codex strips environment variables from MCP server subprocesses by default.

**Gemini CLI** — Setup writes global config to `~/.gemini/settings.json` and creates skill symlinks in `~/.agents/skills/`. Start a new Gemini session after setup. Alternatively, you can install the toolkit as a Gemini extension (see [Installing as a Gemini Extension](#installing-as-a-gemini-extension) below).

**Sourcegraph Amp** — Setup writes to `~/.config/amp/settings.json` using the `amp.` prefix for all keys. Skills load directly from the toolkit via `amp.skills.path` (no symlinks needed). If you have `amp.mcpPermissions` rules that block MCP servers, setup will detect this and ask before making changes.

**Cursor** — Setup writes `~/.cursor/mcp.json`. If automation fails, copy `templates/mcp.json` to `~/.cursor/mcp.json` manually and update the paths. Cursor is the only platform without automated setup verification — this configuration is **untested and provided as-is**.

### Installing as a Gemini Extension

You can install the toolkit as a Gemini CLI extension. The extension does not include MCP server configuration (MCP config is system-specific — binary path, MATLAB root, display mode), so you configure MCP separately.

1. **Install and configure the MCP server** following the steps in [Installing the MCP Server Manually](#installing-the-mcp-server-manually), then add it to `~/.gemini/settings.json`:
   ```json
   {
     "mcpServers": {
       "matlab": {
         "command": "/absolute/path/to/matlab-mcp-core-server",
         "args": ["--matlab-root", "/absolute/path/to/MATLAB/R20XXx", "--matlab-display-mode", "nodesktop"]
       }
     }
   }
   ```

2. **Install the extension:**
   ```bash
   gemini extensions install https://github.com/matlab/matlab-agentic-toolkit
   ```

3. **Create skill symlinks** so Gemini discovers the toolkit skills:
   ```bash
   mkdir -p ~/.agents/skills
   for skill in ~/.gemini/extensions/matlab-agentic-toolkit/skills-catalog/matlab-core/*/; do
     ln -s "$skill" ~/.agents/skills/$(basename "$skill")
   done
   ```

4. **Start a new Gemini session** and verify: ask "What version of MATLAB is running?"

> **Tip:** For a fully automated setup that handles all of the above, use the [Full Setup](#full-setup) workflow instead.

---

<a id="adding-skills-only"></a>
## Adding Skills Only

If you already have the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) installed and configured, you only need skills.

### Claude Code (no clone required)

Add skills directly via the plugin marketplace:

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
claude plugin install matlab-core@matlab-agentic-toolkit
```

Choose your preferred scope (per-project, per-user, or global) when prompted. Your existing MCP configuration is not modified.

> To also get the setup skill (for managing the MCP server later), additionally run:
> `claude plugin install toolkit@matlab-agentic-toolkit`

### Other Platforms

Point your agent's skill or prompt directory at `skills-catalog/matlab-core/`. Each skill is a self-contained `SKILL.md` with a `manifest.yaml`.

For platforms that discover skills from `~/.agents/skills/`, create symlinks:

```bash
mkdir -p ~/.agents/skills
for skill in /path/to/matlab-agentic-toolkit/skills-catalog/matlab-core/*/; do
  ln -s "$skill" ~/.agents/skills/$(basename "$skill")
done
```

Replace `/path/to/matlab-agentic-toolkit` with the actual path to your toolkit clone.

---

## Installing the MCP Server Manually

If you prefer to install the MCP server yourself rather than using the automated setup, follow these steps.

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

### 4. Configure your agent

Point your agent's MCP configuration at the installed binary. See the [How Configuration Works per Platform](#how-configuration-works-per-platform) table for configuration file locations, or consult your agent's documentation.

---

## Verification

### Check that skills are loaded

If your agent shows loaded skills or plugins in its UI (e.g., Claude Code's `/skills` command), confirm the MATLAB Agentic Toolkit skills are listed:

| Skill | Description |
|-------|-------------|
| **matlab-agentic-toolkit-setup** | Install and configure the toolkit, install MCP server |
| **matlab-testing** | Generate and run unit tests with `matlab.unittest` |
| **matlab-creating-live-scripts** | Create plain-text Live Scripts (R2025a+) |
| **matlab-building-apps** | Build apps programmatically with `uifigure` |
| **matlab-reviewing-code** | Review code for quality and MathWorks&reg; coding standards |
| **matlab-debugging** | Diagnose errors via MCP eval |
| **matlab-modernizing-code** | Replace deprecated functions with modern equivalents |

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

## Updating

The toolkit has two independently versioned components: the **toolkit itself** (skills, configurations, and documentation in this repository) and the **MCP server binary** ([MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server)). Update each one separately.

### Updating skills and configurations

Pull the latest changes from the repository:

```bash
cd /path/to/matlab-agentic-toolkit
git pull
```

What happens after `git pull`:

| Platform | Effect |
|----------|--------|
| Copilot, Codex, Gemini CLI | Existing skills update immediately (symlinks point into the repo). If new skills were added, re-run setup to create the new symlinks. |
| Sourcegraph Amp | Skills update immediately (`amp.skills.path` reads the repo directly), including new skills. |
| Claude Code | Skills may be cached by the plugin system — re-run setup or reinstall the plugin to refresh. |
| Cursor | Skills update if the project is open; re-run setup for configuration changes. |

### Updating the MCP server

The MCP server binary is released independently from the toolkit. To update it:

- **Automated:** Re-run setup (e.g., `/matlab-setup` in Claude Code, or ask any agent to set up the toolkit). Setup detects the installed version and downloads a newer release if available.
- **Manual:** Download the latest binary from [MATLAB MCP Core Server releases](https://github.com/matlab/matlab-mcp-core-server/releases/latest) and replace the existing binary. See [Installing the MCP Server Manually](#installing-the-mcp-server-manually) for platform-specific instructions.

> **Tip:** Watch or star the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) repository on GitHub to get notified of new releases.

---

## Per-Project Configuration

Automated setup configures the toolkit **globally** — MATLAB tools and skills are available in every session regardless of which project you open. Global configuration is the easiest way to get started since it just works whenever you create or open a project.

You can also configure the MCP server at the project level. This keeps your tools and skills scoped to the projects that need them, and it helps teams — when the config is committed to version control, anyone who clones the repo gets the MATLAB connection automatically (provided they have the MCP server binary installed; see [Installing the MCP Server Manually](#installing-the-mcp-server-manually)).

### Template files

The [`templates/`](templates/) directory contains starter configurations for each platform. Copy the appropriate template into the root folder of your project, update the paths, and commit it to version control.

| Platform | Template | Project location |
|----------|----------|-----------------|
| GitHub Copilot | `templates/vscode-mcp.json` | `.vscode/mcp.json` |
| Cursor | `templates/mcp.json` | `.cursor/mcp.json` |
| Sourcegraph Amp | `templates/amp-settings.json` | `.amp/settings.json` |
| OpenAI Codex | `templates/codex-mcp.json` | `.codex/config.json` in project root |

> **Claude Code** uses `claude plugin install` with scope selection (per-project, per-user, or global) rather than a project config file. See [Adding Skills Only](#adding-skills-only).

### Example: GitHub Copilot

```bash
mkdir -p .vscode
cp /path/to/matlab-agentic-toolkit/templates/vscode-mcp.json .vscode/mcp.json
```

Then edit `.vscode/mcp.json` to replace the placeholder paths with your actual MCP server binary and MATLAB root paths.

> **Note:** Per-project configs contain absolute paths to the MCP server binary and MATLAB root, which vary across machines. If your team uses different OS platforms or install locations, consider documenting the expected paths in your project README.

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Setup can't find MATLAB | Non-standard install location | Provide the path when prompted |
| MCP server download fails | Network/proxy/firewall | Download manually from [GitHub releases](https://github.com/matlab/matlab-mcp-core-server/releases), place in `~/.local/bin/`, re-run setup |
| macOS blocks the MCP server binary | Gatekeeper quarantine | Setup handles this automatically. If still blocked (MDM), go to System Settings > Privacy & Security > Allow Anyway |
| Agent doesn't list MATLAB skills | Plugin not installed or skills not linked | Re-run setup; for Claude Code, try `claude plugin install matlab-core@matlab-agentic-toolkit` |
| MCP tools fail to connect | MCP server binary missing or wrong path in configuration | Re-run setup to regenerate configuration. Verify binary exists: `~/.local/bin/matlab-mcp-core-server --version` |
| `evaluate_matlab_code` returns errors | Wrong `--matlab-root` path, license issue, or MATLAB startup failure | Verify MATLAB can start: `<matlab-root>/bin/matlab -nodesktop -r "disp('ok'),quit"`. Check license status. Re-run setup to correct the MATLAB root path |
| Codex tool calls time out | Default tool timeout too short for MATLAB | Add `tool_timeout_sec = 600` (or higher) to `[mcp_servers.matlab]` in `~/.codex/config.toml` |
| Simulink fails in Codex on Windows | Missing `WINDIR` environment variable | Add `env_vars = ['WINDIR']` to `[mcp_servers.matlab]` in `~/.codex/config.toml` |

---

Copyright 2025-2026 The MathWorks, Inc.

---

MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See [mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list of additional trademarks. Other product or brand names may be trademarks or registered trademarks of their respective holders.
