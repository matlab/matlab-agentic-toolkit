# MATLAB Agentic Toolkit

[![Latest Release](https://img.shields.io/github/v/release/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)
[![Release Date](https://img.shields.io/github/release-date/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)

The MATLAB&reg; Agentic Toolkit allows you to use AI agents with MATLAB by giving your AI agent the knowledge and context to work efficiently with MATLAB and its toolboxes. Use this toolkit to provide trusted MATLAB capabilities to your agent. This toolkit can prevent your AI coding agent from hallucinating toolbox functions, missing new features, and wasting time with extra steps that experienced MATLAB users would skip. 

Use this toolkit to: 

- Connect your AI agent to MATLAB. This toolkit does this by automatically installing the [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-core-server). You can then use your agent to write idiomatic code, generate and run tests, diagnose errors, build apps, and more.

- Provide curated expertise, called skills, to your agent. These skills equip your agent with knowledge of MATLAB workflows, conventions, and best practices while minimizing token burn. 

> [!Note]
> To use AI agents with Simulink&reg; only, install the [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit). To install both the toolkits, use the [Agentic Toolkit Installer](#install-the-MATLAB-Agentic-Toolkit).


## Requirements

* MATLAB R2021a or later
* Git&trade;
* AI coding agent that supports MCP servers and skills. Supported agents are configured automatically. Otherwise, refer to your agent’s documentation to manually configure the MCP server and install skills. Supported agents include:
    - Claude Code
    - GitHub&reg; Copilot
    - OpenAI&reg; Codex
    - Gemini&trade; CLI
    - Sourcegraph Amp

---
## Get Started with the MATLAB Agentic Toolkit

These steps show you how to use the MATLAB Agentic Toolkit to install the MATLAB MCP Server and add skills to your agent.

> Note: For detailed instructions on configuration options for this toolkit, platform-specific notes, verification steps, and troubleshooting, see [Configuration and Troubleshooting](Configuration_and_Troubleshooting.md). If you already have the MCP server installed and only need to add skills, see [Adding Skills Only](Configuration_and_Troubleshooting.md#adding-skills-only). 

### Install the MATLAB Agentic Toolkit

You can use the Agentic Toolkit installer to set up the MATLAB Agentic Toolkit. The installer: 
* Supports both the MATLAB and [Simulink](https://github.com/matlab/simulink-agentic-toolkit) Agentic Toolkits.
* Supports connecting to an existing MATLAB session (`--matlab-session-mode="auto" or "existing"`).
* Provides the option to configure your agent for individual projects or globally.

Follow these steps to set up the MATLAB Agentic Toolkit.

1. To download the installer, click [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx).
2. Open the downloaded file to install the installer add-on.
3. In MATLAB, run this command.

```matlab
setupAgenticToolkit("install")
```

Install only the skill groups relevant to your work — this helps your agent reliably trigger the right skills. To add more skill groups later, re-run the installer. 



### Alternative Install Workflow Using Agent

You can also use your agent to set up the MATLAB Agentic Toolkit. Note that this approach installs all skill groups. To use specific skill groups only, you must manually remove other skill groups after setup (see [Adding Skills Only](Configuration_and_Troubleshooting.md#adding-skills-only)). The MATLAB-based installer above is recommended for most users.

Clone the repository:

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
cd matlab-agentic-toolkit
```

Deploy your agent (`claude`, `codex`, `gemini`, etc.) and ask the agent to set up the MATLAB Agentic Toolkit.

```
Set up the MATLAB Agentic Toolkit
```

The setup looks for your most recent MATLAB installation, downloads the MCP server binary to `~/.matlab/agentic-toolkits/bin/`, writes your agent's global configuration, and registers skills through the agent's native plugin system or global skill links. After your setup is complete, start a new session in any project directory to use the MATLAB tools and skills.

### Verify
Ask your agent:

```
What version of MATLAB is running? List the installed toolboxes.
```

### Run and Test MATLAB Code Using MCP Tools 
After you install the MATLAB Agentic Toolkit, your agent can use these tools provided by the MATLAB MCP Server. 

| Tasks you can ask your agent to do | Tool used by agent |
|------|------------------------|
| Run MATLAB code and return command window output | `evaluate_matlab_code` |
| Run a MATLAB program | `run_matlab_file` | 
| Run tests via `runtests` with structured results | `run_matlab_test_file`| 
| Static analysis with the Code Analyzer | `check_matlab_code` |
| List installed MATLAB version and toolboxes | `detect_matlab_toolboxes` |

The server also provides two MCP resources: `matlab_coding_guidelines` (coding standards) and `plain_text_live_code_guidelines` (Live Script format rules).

### Run MATLAB Workflows Using Agent Skills 
After you install the MATLAB Agentic Toolkit, your agent can use skills. For best results, install only the skill groups relevant to your work — agents are more reliable at triggering skills when fewer are loaded. You can also manually trigger a specific skill by name (e.g., `/matlab-testing` in Claude Code) to guarantee it loads. To read details about all the skills, see the [skills catalog](skills-catalog/). Skill groups include:

<!-- BEGIN SKILLS -->
#### MATLAB Skills

| Skill Group | Description |
|-------------|-------------|
| [**MATLAB Core**](skills-catalog/README.md#matlab-core-matlab-core) | Create, debug, test, review, and manage MATLAB code and installations |
| [**MATLAB App Building**](skills-catalog/README.md#matlab-app-building-matlab-app-building) | Build MATLAB apps programmatically using UI components, layouts, callbacks, and web integration |
| [**MATLAB Data Import and Analysis**](skills-catalog/README.md#matlab-data-import-and-analysis-matlab-data-import-and-analysis) | Analyze tabular data in MATLAB using tables, timetables, filtering, aggregation, and time-series operations |
| [**MATLAB External Language Interfaces**](skills-catalog/README.md#matlab-external-language-interfaces-matlab-external-language-interfaces) | Call Python&trade; libraries from MATLAB and upgrade MEX files to the interleaved complex API |
| [**MATLAB Programming**](skills-catalog/README.md#matlab-programming-matlab-programming) | Write robust MATLAB functions with validated inputs |
| [**MATLAB Software Development**](skills-catalog/README.md#matlab-software-development-matlab-software-development) | Modernize legacy code, optimize performance and memory, document and create toolboxes, create projects, and develop build plans |

#### Toolbox Skills

| Skill Group | Supported Products |
|-------------|--------------------|
| [**Aerospace**](skills-catalog/README.md#aerospace-aerospace) | Aerospace Toolbox |
| [**AI and Statistics**](skills-catalog/README.md#ai-and-statistics-ai-and-statistics) | Deep Learning Toolbox |
| [**Automotive**](skills-catalog/README.md#automotive-automotive) | Automated Driving Toolbox, RoadRunner, and RoadRunner Scene Builder |
| [**Cloud Solutions**](skills-catalog/README.md#cloud-solutions-cloud-solutions) | MATLAB Drive |
| [**Computational Biology**](skills-catalog/README.md#computational-biology-computational-biology) | SimBiology |
| [**Image Processing and Computer Vision**](skills-catalog/README.md#image-processing-and-computer-vision-image-processing-and-computer-vision) | Image Processing Toolbox and Computer Vision Toolbox |
| [**Parallel Computing**](skills-catalog/README.md#parallel-computing-parallel-computing) | Parallel Computing Toolbox and MATLAB Parallel Server |
| [**Radar**](skills-catalog/README.md#radar-radar) | Phased Array System Toolbox, Sensor Fusion and Tracking Toolbox, and Mapping Toolbox |
| [**Reporting and Database Access**](skills-catalog/README.md#reporting-and-database-access-reporting-and-database-access) | Database Toolbox |
| [**RF and Mixed Signal**](skills-catalog/README.md#rf-and-mixed-signal-rf-and-mixed-signal) | Antenna Toolbox, Mixed-Signal Blockset, RF Toolbox, RF PCB Toolbox, and SerDes Toolbox |
| [**Robotics and Autonomous Systems**](skills-catalog/README.md#robotics-and-autonomous-systems-robotics-and-autonomous-systems) | Navigation Toolbox and UAV Toolbox |
| [**Signal Processing**](skills-catalog/README.md#signal-processing-signal-processing) | Audio Toolbox, DSP HDL Toolbox, DSP System Toolbox, Signal Processing Toolbox, and Wavelet Toolbox |
| [**Test and Measurement**](skills-catalog/README.md#test-and-measurement-test-and-measurement) | Data Acquisition Toolbox, Image Acquisition Toolbox, Industrial Communication Toolbox, MATLAB Support Package for Arduino Hardware, and Vehicle Network Toolbox |
| [**Wireless Communications**](skills-catalog/README.md#wireless-communications-wireless-communications) | Communications Toolbox, 5G Toolbox, WLAN Toolbox, Bluetooth Toolbox, Satellite Communications Toolbox, Wireless Network Toolbox, and Wireless Testbench |
<!-- END SKILLS -->
---
## Update the MATLAB Agentic Toolkit

To update the toolkit, run this command in MATLAB.

```matlab
setupAgenticToolkit("update")
```

This updates the skills, configurations, and MCP server binary for both the MATLAB and Simulink Agentic Toolkits.

> **Note:** The installer add-on is updated separately. To get the latest installer, re-download [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx) and open it in MATLAB.

---
## Security Considerations
When using the MATLAB Agentic Toolkit and MATLAB MCP Server, you should thoroughly review and validate all tool calls before you run them. Always keep a human in the loop for important actions and only proceed once you are confident the call will do exactly what you expect. For more information, see [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#user-interaction-model) and [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#security-considerations).

---
## Licensing and Usage
The license is available in the [LICENSE.md](LICENSE.md) file in this GitHub repository.

MCP servers are only permitted to be used with MATLAB in accordance with the MathWorks Software License Agreement, and must not be shared by multiple users. Contact MathWorks if you need to support shared or centralized server use.

---
## Support and Contributions
MathWorks encourages you to use this repository and provide feedback. Pull requests are not enabled on this repository. To request technical support or submit an enhancement request, [create a GitHub issue](https://github.com/matlab/matlab-agentic-toolkit/issues) or [contact technical support](https://www.mathworks.com/support/contact_us.html). 


----

Copyright 2026 The MathWorks, Inc.

----

