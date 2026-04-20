# MATLAB&reg; Agentic Toolkit
The MATLAB Agentic Toolkit brings trusted MATLAB capabilities to AI agents, making engineering and scientific workflows agent-ready.

## What It Does
AI coding agents are increasingly capable with MATLAB — but capability isn't expertise. Without guidance, agents reinvent what toolbox functions already provide, miss features they don't know about, and burn through extra steps that an experienced MATLAB user would skip. The MATLAB Agentic Toolkit gives your agent the knowledge and context to work efficiently from the start.

The toolkit connects your AI agent to MATLAB and equips it with expert knowledge — the workflows, conventions, and best practices to make the best use of MATLAB while minimizing token burn. Your agent learns to write idiomatic code, generate and run tests, diagnose errors, build apps, and more.

The toolkit works with today's leading AI coding agents and is designed to evolve as the landscape changes.

> [!IMPORTANT]
> To use AI agents with Simulink, install the [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit).

## How It Works
The toolkit has two jobs. First, it gives your agent a live connection to MATLAB — so it can run code, execute tests, and analyze results, not just read and write files. Second, it provides curated expertise (called *skills*) that teach your agent how an experienced MATLAB engineer would approach a task. Your agent reads the relevant skill, then uses the MATLAB connection to do the work.

The toolkit ships automated setup for all supported platforms. Clone the repository, launch your agent, and ask it to set up the toolkit.


## Supported Platforms

| Platform | Setup | Notes |
|----------|-------|-------|
| [Claude Code](https://claude.ai/code) | Automated | Also supports [no-clone marketplace install](#claude-code-marketplace-install) (skills only) |
| [GitHub&reg; Copilot](https://github.com/features/copilot) | Automated | |
| [OpenAI&reg; Codex](https://openai.com/codex) | Automated | |
| [Gemini&trade; CLI](https://github.com/google-gemini/gemini-cli) | Automated | |
| [Sourcegraph Amp](https://ampcode.com/) | Automated | |
| [Cursor](https://www.cursor.com/) | Manual | Untested |

> Automated setup has been verified with basic workflows on each platform except Cursor. The toolkit is under active development — please [report issues](https://github.com/matlab/matlab-agentic-toolkit/issues) if you encounter problems.

## Quick Start

> **Full walkthrough:** See the [Getting Started guide](GETTING_STARTED.md) for detailed instructions, platform-specific notes, verification steps, and troubleshooting.

**Prerequisites:**
* MATLAB R2020b or later
* Supported AI coding agent
* Git&trade;

The MATLAB Agentic Toolkit helps you install and configure the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server), or can be configured to use your existing installation.

### Full Setup (recommended)

Clone the repository, launch your agent from the toolkit directory, and ask it to set up the toolkit.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
cd matlab-agentic-toolkit
```

Launch your agent (`claude`, `codex`, `gemini`, etc.) and ask:

```
Set up the MATLAB Agentic Toolkit
```

Setup looks for your MATLAB installation(s), downloads the MCP server, writes your agent's global configuration, and registers skills. Once complete, start a new session in any project directory — MATLAB tools and skills are available everywhere.

<a id="claude-code-marketplace-install"></a>
> **Claude Code — no clone required:** If you already have the [MCP server](https://github.com/matlab/matlab-mcp-core-server) configured, you can add skills directly without cloning:
> ```bash
> claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
> claude plugin install matlab-core@matlab-agentic-toolkit
> ```
> This installs skills only. Your existing MCP configuration is not modified. See the [Getting Started guide](GETTING_STARTED.md#adding-skills-only) for details.

### Already Have the MCP Server?

If you installed the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) yourself, you just need skills. See [Adding Skills Only](GETTING_STARTED.md#adding-skills-only) in the Getting Started guide.

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

<!-- BEGIN SKILLS -->
**MATLAB App Building** — MATLAB app building skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-build-app` | Build MATLAB apps programmatically using uifigure, uigridlayout, UI components, callbacks, and uihtml for web integration. |

**MATLAB Core** — foundational MATLAB skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-create-live-script` | Create plain-text MATLAB Live Scripts (.m files) with rich text formatting, LaTeX equations, section breaks, and inline figures. |
| `matlab-debugging` | Diagnose MATLAB errors and unexpected behavior. |
| `matlab-install-products` | Deterministic workflow to download MATLAB Package Manager (mpm) and install MathWorks products from the OS command line with consistent, repeatable behavior. |
| `matlab-list-products` | Show all installed MATLAB products and support packages for a given MATLAB installation folder. |
| `matlab-review-code` | Review MATLAB code for quality, performance, maintainability, and adherence to MathWorks coding standards. |
| `matlab-testing` | Generate and run MATLAB unit tests using matlab.unittest and matlab.uitest. |

**MATLAB Software Development** — MATLAB software development skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-modernize-code` | Modernize deprecated MATLAB functions and patterns. |

**Reporting and Database Access** — reporting and database access skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-map-database-objects` | Generates MATLAB Object Relational Mapping (ORM) code using Database Toolbox. |
| `matlab-read-database` | Reads data from relational databases using MATLAB Database Toolbox pushdown capabilities. |
| `matlab-use-duckdb` | Generates MATLAB code for DuckDB database operations using Database Toolbox. |
| `matlab-write-database` | Writes data from MATLAB to relational databases and performs database operations. |

**Toolkit** — setup and management for the MATLAB Agentic Toolkit.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-agentic-toolkit-setup` | Install and configure the MATLAB Agentic Toolkit — detect MATLAB, install the MCP server, register with your AI coding agent, and verify the environment. |

<!-- END SKILLS -->

## Trademarks
MATLAB and Simulink are registered trademarks of The MathWorks, Inc. See [mathworks.com/trademarks](https://www.mathworks.com/trademarks) for a list of additional trademarks. Other product or brand names may be trademarks or registered trademarks of their respective holders.

## Contributing
We welcome feedback through [GitHub Issues](https://github.com/matlab/matlab-agentic-toolkit/issues). Pull requests are reviewed for ideas and feedback but are not merged from external contributors. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Licensing and Usage 
The MATLAB Agentic Toolkit is licensed with [MathWorks BSD-3 Clause](LICENSE). It is solely for use in conjunction with MathWorks products and service offerings.

## Contact Support
MathWorks encourages you to use this repository and provide feedback. To request technical support or submit an enhancement request, [create a GitHub issue](https://github.com/matlab/matlab-agentic-toolkit/issues) or email [genai-support@mathworks.com](mailto:genai-support@mathworks.com). For MATLAB MCP Core Server issues and support, see the [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server) repository.

#
When using the MATLAB Agentic Toolkit and MATLAB MCP Core Server, you should thoroughly review and validate all tool calls before you run them. Always keep a human in the loop for important actions and only proceed once you are confident the call will do exactly what you expect. For more information, see [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#user-interaction-model) and [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#security-considerations).

The MATLAB MCP Core server may only be used with MATLAB installations that are used as a Personal Automation Server. Use with a central Automation Server is not allowed. Please contact MathWorks if Automation Server use is required. For more information see the [Program Offering Guide (MathWorks)](https://www.mathworks.com/help//pdf_doc/offering/offering.pdf).

----

Copyright 2026 The MathWorks, Inc.

----

