# Configuration and Troubleshooting

This page shows you how to configure the MATLAB&reg; Agentic Toolkit. For an overview of the MATLAB Agentic Toolkit, see the [README](README.md).

## Requirements

- MATLAB R2021a or later 
- Git&trade;
- AI coding agent that supports MCP servers and skills. Supported agents are configured automatically. Otherwise, refer to your agent’s documentation to manually configure the MCP server and install skills. Supported agents include:
  - Claude Code  
  - GitHub&reg; Copilot  
  - OpenAI&reg; Codex  
  - Gemini&trade; CLI  
  - Amp

---

## Install from Local Files (Offline Computer)

To install MATLAB Agentic Toolkit in an offline or air-gapped environment, first download these artifacts on a computer with internet access and transfer them to the target machine or a shared location.

| Artifact | Where to Get It |
|----------|----------------|
| MCP server binary | [Latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — download the binary for your platform (e.g., `matlab-mcp-server-macos-arm64`, `matlab-mcp-server-windows-x64.exe`) |
| MCP server toolbox | [Latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — download `MATLABMCPServerToolbox.mltbx` |
| MATLAB Agentic Toolkit | Clone or download from [GitHub](https://github.com/matlab/matlab-agentic-toolkit) |
| Simulink Agentic Toolkit | Clone or download from [GitHub](https://github.com/matlab/simulink-agentic-toolkit). Required only when installing Simulink Agentic Toolkit|


After you download these artifacts, run the `setupAgenticToolkit` command in your MATLAB command window with these name-value arguments.

| Argument | Value |
|----------|-----------------|
| `MCPServerLocation` | Path to the MCP server binary download |
| `MCPToolboxLocation` | Path to the MATLAB toolbox (`.mltbx`) download |
| `MATLABAgenticToolkitLocation` | Path to the MATLAB Agentic Toolkit repository clone |
| `SimulinkAgenticToolkitLocation` | Path to the Simulink Agentic Toolkit repository clone |

The installer downloads any artifact you do not provide locally. To prevent internet access and report an error if an artifact is unavailable, set `Offline=true`. For example, use this command to install MATLAB Agentic Toolkit from local files.

```matlab
setupAgenticToolkit("install", Offline=true,  ...
    MCPServerLocation="/shared/agentic-toolkits/bin/matlab-mcp-server-linux-x64", ...
    MCPToolboxLocation="/shared/agentic-toolkits/toolboxes/MATLABMCPServerToolbox.mltbx", ...
    MATLABAgenticToolkitLocation="/shared/agentic-toolkits/matlab-agentic-toolkit")
```

---

## Install MATLAB Using Your Agent

If you do not have MATLAB installed, you can install MATLAB with your AI agent using these steps.
1) Install MATLAB Agentic Toolkit skills using the steps in [Adding Skills Only](#adding-skills-only).
2) Ask your agent to install MATLAB using the `matlab-install-products` skill. 

After you install MATLAB, you can complete the MATLAB Agentic Toolkit setup either by following the instructions in [Agentic Toolkit Installer](README.md#install-the-matlab-agentic-toolkit) to automatically install MATLAB MCP Server, or by manually installing and configuring MATLAB MCP Server.

---

## Install and Configure the MCP Server

To manually install and configure the MCP server rather than using the automated setup, see the instructions in the [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-core-server) GitHub repository. After you install the MCP server, point your agent's MCP configuration at the installed binary. See this table for configuration file locations, or refer to your agent's documentation.

| Platform | MCP Configuration | Platform-Specific Notes |
|----------|------------------|-------------------|
| Claude Code | `~/.claude.json` | Use `claude mcp add` to configure. |
| GitHub Copilot | VS Code user-profile `mcp.json` | Reload VS Code after setup completes. |
| OpenAI Codex | `~/.codex/config.toml` | After setup, you can tune two settings in the `[mcp_servers.matlab]` section of `~/.codex/config.toml`: 1) Set `tool_timeout_sec = 600` to increase the tool timeout for longer MATLAB operations like test suites and simulations. Increase further for very long-running tasks. 2) Set `env_vars = ['WINDIR']` on Windows for Simulink&reg; to work, since Codex strips environment variables from MCP server subprocesses by default. |
| Gemini CLI | `~/.gemini/settings.json` | Start a new Gemini session after setup. |
| Amp | `~/.config/amp/settings.json` | If you have `amp.mcpPermissions` rules that block MCP servers, add an allow rule for the MATLAB server. |

### Disable Data Collection

MATLAB MCP Server collects anonymized usage data by default. To opt out, add `--disable-telemetry=true` to the arguments in your agent's MCP configuration file. For the file locations, see the table above. Each time you update MATLAB Agentic Toolkit, you must reapply this setting.

```json
"matlab": {
  "command": "~/.matlab/agentic-toolkits/bin/matlab-mcp-server",
  "args": [
    "--disable-telemetry=true"
  ]
}
```


---

<a id="adding-skills-only"></a>
## Adding Skills Only

If you already have the MATLAB MCP Core Server, you only need skills. Skills are organized into folders under `skills-catalog/`, called skill groups. You must install the `matlab-core` skill group. For additional domain expertise, you can separately install other specific skill groups. Only install skills that you need to allow your agent to reliably trigger the skills. To ensure to load a specific skill in your workflow, you can also manually trigger the skill using its name.

For details about the skills groups and skills, see the [`skills-catalog/` README](skills-catalog/README.md). 

### Claude Code

Each skill group is provided as a Claude Code plugin. To add a skill group, first add the marketplace, and install the `matlab-core` skill group.

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
claude plugin install matlab-core@matlab-agentic-toolkit
```

After you install the `matlab-core` skill group, use the same pattern with the group's directory name to install a specific skill group.

```bash
claude plugin install <group-name>@matlab-agentic-toolkit
```

For example, to add signal processing and wireless communications skills:

```bash
claude plugin install signal-processing@matlab-agentic-toolkit
claude plugin install wireless-communications@matlab-agentic-toolkit
```

Choose your preferred scope (per-project, per-user, or global) when prompted. Your existing MCP configuration is not modified.


### GitHub Copilot, OpenAI Codex, Gemini CLI

Most other AI agents discover skills from `~/.agents/skills/`. To add skills to your agent, you must set up symbolic links from the `~/.agents/skills/` folder to the individual skill groups. First, clone the toolkit.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

After you clone the toolkit, create symlinks for each group you want. Replace `/path/to/matlab-agentic-toolkit` with the actual path to your toolkit clone, and list whichever groups you need. For example, to install `matlab-core` and `signal-processing`, use these commands.

```bash
mkdir -p ~/.agents/skills
for group in matlab-core signal-processing; do
  for skill in /path/to/matlab-agentic-toolkit/skills-catalog/$group/*/; do
    ln -s "$skill" ~/.agents/skills/$(basename "$skill")
  done
done
```

Alternatively, for Gemini, you can add the skills by installing the toolkit as a Gemini CLI extension. 
  ```bash
 gemini extensions install https://github.com/matlab/matlab-agentic-toolkit
  ```

### Amp

Amp reads skills from the paths listed in `~/.config/amp/settings.json`. First, clone the toolkit.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

After you clone the toolkit, add a `skills-catalog/<group>` path entry for each group you want.

```json
{
  "amp.skills.path": [
    "/path/to/matlab-agentic-toolkit/skills-catalog/matlab-core",
    "/path/to/matlab-agentic-toolkit/skills-catalog/signal-processing"
  ]
}
```

---

## Verification

### Check that skills are loaded

If your agent shows loaded skills or plugins in its UI (e.g., Claude Code's `/skills` command), confirm the MATLAB Agentic Toolkit skills are listed. 

### Try it out

Ask your agent:

```
What version of MATLAB is running? List the installed toolboxes.
```

The agent calls `detect_matlab_toolboxes` using MCP and reports the MATLAB version and available toolboxes.

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

## Per-Project Configuration

When you install the MATLAB Agentic toolkit using the automated setup on the top-level [README](README.md), the toolkit is configured globally. MATLAB tools and skills are available in every session regardless of which project you open. 

You can also configure the MCP server at the project level. This allows you to scope your tools and skills only to the projects that need them. When the config is committed to version control, it also helps your teams because anyone who clones the repo gets the MATLAB connection automatically (provided they have the MCP server binary installed).

### Template files

The [`templates/`](templates/) directory contains starter configurations for each platform. Copy the appropriate template into the root folder of your project, update the paths, and commit it to version control.

| Platform | Template | Project location |
|----------|----------|-----------------|
| GitHub Copilot | `templates/vscode-mcp.json` | `.vscode/mcp.json` |
| Amp | `templates/amp-settings.json` | `.amp/settings.json` |
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
| MCP server download fails | Network/proxy/firewall | Download manually from [GitHub releases](https://github.com/matlab/matlab-mcp-core-server/releases), place in `~/.matlab/agentic-toolkits/bin/`, re-run setup |
| macOS blocks the MCP server binary | Gatekeeper quarantine | Setup handles this automatically. If still blocked (MDM), go to System Settings > Privacy & Security > Allow Anyway |
| Agent doesn't list MATLAB skills | Plugin not installed or skills not linked | Re-run setup; for Claude Code, try `claude plugin install matlab-core@matlab-agentic-toolkit` |
| MCP tools fail to connect | MCP server binary missing or wrong path in configuration | Re-run setup to regenerate configuration. Verify binary exists: `~/.matlab/agentic-toolkits/bin/matlab-mcp-server --version` |
| `evaluate_matlab_code` returns errors | Wrong `--matlab-root` path, license issue, or MATLAB startup failure | Verify MATLAB can start: `<matlab-root>/bin/matlab -nodesktop -r "disp('ok'),quit"`. Check license status. Re-run setup to correct the MATLAB root path |
| Codex tool calls time out | Default tool timeout too short for MATLAB | Add `tool_timeout_sec = 600` (or higher) to `[mcp_servers.matlab]` in `~/.codex/config.toml` |
| Simulink fails in Codex on Windows | Missing `WINDIR` environment variable | Add `env_vars = ['WINDIR']` to `[mcp_servers.matlab]` in `~/.codex/config.toml` |
| Skills not auto-loading | Too many skills installed | See [Skills Not Auto-Loading](#skills-not-auto-loading) below |

---

<a id="skills-not-auto-loading"></a>
### Skills Not Auto-Loading

Agents have limited context. When you install many skill groups, some skills may be overlooked or trimmed from context and your agent may not automatically trigger the correct skill for a given task.

#### Recommended Solutions

1. Install only the skill groups you need: This is the recommended solution. Use the MATLAB-based installer (`setupAgenticToolkit("install")`) to select specific skill groups relevant to your work. Fewer installed skills means the agent can more reliably identify and trigger the right one.

2. Manually trigger skills by name: If you know which skill you need, trigger it directly.
   - In Claude Code, use the slash command (e.g., `/matlab-testing`).
   - In other agents, ask explicitly: "Use the matlab-testing skill to...".

3. Remove skill groups you don't use: If you installed all groups via the agent-based setup, remove the ones you don't need.
   - Claude Code: `claude plugin remove <group-name>@matlab-agentic-toolkit`.
   - Copilot, Codex, Gemini CLI: Remove the corresponding symlinks from `~/.agents/skills/`.
   - Amp: Remove the group path from `amp.skills.path` in `~/.config/amp/settings.json`.

We are actively exploring more robust solutions to improve skill discovery and auto-loading when many skills are installed.

---

## Support and Contributions
MathWorks&reg; encourages you to use this repository and provide feedback. Pull requests are not enabled on this repository. To request technical support or submit an enhancement request, [create a GitHub issue](https://github.com/matlab/matlab-agentic-toolkit/issues) or [contact technical support](https://www.mathworks.com/support/contact_us.html). 

----

Copyright 2026 The MathWorks, Inc.

----

