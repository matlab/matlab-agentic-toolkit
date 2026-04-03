# MATLAB&reg; Agentic Toolkit
The MATLAB Agentic Toolkit brings trusted MATLAB capabilities to AI agents, making engineering and scientific workflows agent-ready.

## What It Does
AI coding agents are increasingly capable with MATLAB — but capability isn't expertise. Without guidance, agents reinvent what toolbox functions already provide, miss features they don't know about, and burn through extra steps that an experienced MATLAB user would skip. The MATLAB Agentic Toolkit gives your agent the knowledge and context to work efficiently from the start.

The toolkit connects your AI agent to MATLAB and equips it with expert knowledge — the workflows, conventions, and best practices to make the best use of MATLAB while minimizing token burn. Your agent learns to write idiomatic code, generate and run tests, diagnose errors, build apps, and more.

The toolkit works with today's leading AI coding agents and is designed to evolve as the landscape changes.


## How It Works
The toolkit has two jobs. First, it gives your agent a live connection to MATLAB — so it can run code, execute tests, and analyze results, not just read and write files. Second, it provides curated expertise (called *skills*) that teach your agent how an experienced MATLAB engineer would approach a task. Your agent reads the relevant skill, then uses the MATLAB connection to do the work.

The toolkit ships ready-made configurations for each supported platform. Configuration is automated for Claude Code; other platforms require manual configuration. 


## Supported Platforms

| Platform | Manifest | Status |
|----------|----------|--------|
| [Claude Code](https://claude.ai/code) | `.claude-plugin/marketplace.json` | Tested |
| [GitHub&reg; Copilot](https://github.com/features/copilot) | User-created `.vscode/mcp.json` | Untested |
| [Cursor](https://www.cursor.com/) | `.cursor-plugin/plugin.json` | Untested |
| [OpenAI&reg; Codex](https://openai.com/codex) | `.codex-plugin/plugin.json` | Untested |
| [Sourcegraph Amp](https://ampcode.com/) | `.amp/settings.json` | Untested |
| [Gemini&trade; CLI](https://github.com/google-gemini/gemini-cli) | `gemini-extension.json` | Untested |

## Quick Start

> **Full walkthrough:** See the [Getting Started guide](GETTING_STARTED.md) for detailed instructions, verification steps, and troubleshooting.

**Prerequisites:**
* MATLAB R2020b or later
* Supported AI coding agent
* Git&trade;

The MATLAB Agentic Toolkit helps you install and configure the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server), or can be configured to use your existing installation.

### Claude Code
Clone this repository. Launch Claude Code from the repository root folder.
```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
cd matlab-agentic-toolkit
claude
```

Ask Claude to `"set up the toolkit"`. It finds MATLAB, installs the MCP server, registers the plugin, and verifies the environment. Once complete, start a new Claude Code session in any project directory — MATLAB skills and MCP tools are available everywhere.

### Other Agents
Any agent that supports MCP can use the toolkit. Install the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) binary and point your agent's MCP configuration at it:

```json
{
  "command": "/path/to/matlab-mcp-core-server"
}
```

For skills, point your agent at `skills-catalog/matlab-core/` (domain skills). Each skill is a self-contained `SKILL.md`.

See the [Getting Started guide](GETTING_STARTED.md) for platform-specific instructions, manual MCP server installation, and how to add skills to an existing MCP setup.

### Verify
Ask your agent:

```
What version of MATLAB is running? List the installed toolboxes.
```

## MCP Tools
Provided by the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server):

| Tool | What your agent can do |
|------|------------------------|
| `evaluate_matlab_code` | Run MATLAB code and return command window output |
| `run_matlab_file` | Run a MATLAB program |
| `run_matlab_test_file` | Run tests via `runtests` with structured results |
| `check_matlab_code` | Static analysis with the Code Analyzer |
| `detect_matlab_toolboxes` | List installed MATLAB version and toolboxes |

The server also provides two MCP resources: `matlab_coding_guidelines` (coding standards) and `plain_text_live_code_guidelines` (Live Script format rules).

## Agent Skills
Skills are organized in the [skills catalog](skills-catalog/).

**Toolkit** — setup and configuration:

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-agentic-toolkit-setup` | Install and configure the toolkit — detect MATLAB, install MCP server, register plugin |

**matlab-core** — foundational MATLAB skills:

| Skill | What it teaches your agent |
|-------|---------------------------|
| `testing` | Generate and run unit tests with `matlab.unittest`. Parameterized tests, fixtures, coverage |
| `creating-live-scripts` | Create plain-text Live Scripts with rich text, equations, and inline figures (R2025a+) |
| `building-apps` | Build apps programmatically with `uifigure`, `uigridlayout`, components, and `uihtml` |
| `reviewing-code` | Review code for quality, performance, and adherence to MathWorks coding standards |
| `debugging` | Diagnose errors via MCP eval. Programmatic breakpoints, diagnostic instrumentation |
| `modernizing-code` | Replace deprecated MATLAB functions and anti-patterns with modern equivalents |

## Trademarks
MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See [mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list of additional trademarks. Other product or brand names may be trademarks or registered trademarks of their respective holders.

## Contributing
We welcome feedback through [GitHub Issues](https://github.com/matlab/matlab-agentic-toolkit/issues). Pull requests are reviewed for ideas and feedback but are not merged from external contributors. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Contact Support
MathWorks encourages you to use this repository and provide feedback. To request technical support or submit an enhancement request, [create a GitHub issue](https://github.com/matlab/matlab-agentic-toolkit/issues) or email [genai-support@mathworks.com](mailto:genai-support@mathworks.com). For MATLAB MCP Core Server issues and support, see the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) repository. 

#
When using the MATLAB Agentic Toolkit and MATLAB MCP Core Server, you should thoroughly review and validate all tool calls before you run them. Always keep a human in the loop for important actions and only proceed once you are confident the call will do exactly what you expect. For more information, see [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#user-interaction-model) and [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#security-considerations).

The MATLAB MCP Core server may only be used with MATLAB installations that are used as a Personal Automation Server. Use with a central Automation Server is not allowed. Please contact MathWorks if Automation Server use is required. For more information see the [Program Offering Guide (MathWorks)](https://www.mathworks.com/help//pdf_doc/offering/offering.pdf).

---

Copyright 2025-2026 The MathWorks, Inc.
