# MATLAB Agentic Toolkit

[![Latest Release](https://img.shields.io/github/v/release/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)
[![Release Date](https://img.shields.io/github/release-date/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)

The MATLAB&reg; Agentic Toolkit allows you to use AI agents with MATLAB by giving your AI agent the knowledge and context to work efficiently with MATLAB and its toolboxes. Use this toolkit to provide trusted MATLAB capabilities to your agent. This toolkit can prevent your AI coding agent from hallucinating toolbox functions, missing new features, and wasting time with extra steps that experienced MATLAB users would skip. 

Use this toolkit to: 

- Connect your AI agent to MATLAB. This toolkit does this by automatically installing the [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server). You can then use your agent to write idiomatic code, generate and run tests, diagnose errors, build apps, and more.

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
    - Amp

---
## Get Started with MATLAB Agentic Toolkit

These steps show you how to use the MATLAB Agentic Toolkit to install the MATLAB MCP Server and add skills to your agent.

> Note: For instructions on installation from local files, installation in an offline environment, configuration options for this toolkit, platform-specific notes, verification steps, troubleshooting, and manual setup without the installer, see [Configuration and Troubleshooting](Configuration_and_Troubleshooting.md). If you already have the MCP server installed and only need to add skills, see [Adding Skills Only](Configuration_and_Troubleshooting.md#adding-skills-only). 

### Install MATLAB Agentic Toolkit

Follow these steps to set up the MATLAB Agentic Toolkit.

1. To download the installer, click [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx).
2. Open the downloaded file with MATLAB to install the installer add-on.
3. In MATLAB, run this command.

```matlab
setupAgenticToolkit("install")
```

4. Install only the skill groups relevant to your work. This helps your agent reliably trigger the right skills. To add more skill groups later, re-run the installer.
5. By default, your agent creates a new MATLAB session when you call it. To connect your agent to the existing MATLAB session, run this command in the MATLAB command window.

```
shareMATLABSession()
```

If you are running multiple MATLAB sessions, the agent connects to the MATLAB session where you most recently ran this command.

Alternatively, you can also add this command to your MATLAB [Startup Script](https://www.mathworks.com/help/matlab/ref/startup.html).


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

The server also provides two MCP resources: `matlab_coding_guidelines` (coding standards) and `plain_text_live_code_guidelines` (Live Script format rules). These resources provide reference information that agents can read as needed. 

### Run MATLAB Workflows Using Agent Skills 
After you install the MATLAB Agentic Toolkit, your agent can use MathWorks&reg; curated skills. For best results, install only the skill groups relevant to your work — agents are more reliable at triggering skills when fewer are loaded. You can also manually trigger a specific skill by name (e.g., `/matlab-write-test` in Claude Code) to guarantee it loads. To read details about all the skills, see the [skills catalog](skills-catalog/). Skill groups include:

<!-- BEGIN SKILLS -->
#### MATLAB Skills

| Skill Group | Description |
|-------------|-------------|
| [**MATLAB Core**](skills-catalog/README.md#matlab-core-matlab-core) | Create, debug, test, review, and manage MATLAB code and installations |
| [**MATLAB App Building**](skills-catalog/README.md#matlab-app-building-matlab-app-building) | Build MATLAB apps programmatically using UI components, layouts, callbacks, and web integration |
| [**MATLAB Data Import and Analysis**](skills-catalog/README.md#matlab-data-import-and-analysis-matlab-data-import-and-analysis) | Import, export, and analyze data in MATLAB using tables, timetables, filtering, aggregation, and time-series operations |
| [**MATLAB Environment and Settings**](skills-catalog/README.md#matlab-environment-and-settings-matlab-environment-and-settings) | Diff MATLAB settings between releases and migrate startup scripts to correct setting paths |
| [**MATLAB External Language Interfaces**](skills-catalog/README.md#matlab-external-language-interfaces-matlab-external-language-interfaces) | Call Python&reg; libraries from MATLAB and upgrade MEX files to the interleaved complex API |
| [**MATLAB Programming**](skills-catalog/README.md#matlab-programming-matlab-programming) | Write robust MATLAB functions with validated inputs |
| [**MATLAB Software Development**](skills-catalog/README.md#matlab-software-development-matlab-software-development) | Modernize legacy code, optimize performance and memory, document and create toolboxes, create projects, and develop build plans |

#### Toolbox Skills

| Skill Group | Supported Products |
|-------------|--------------------|
| [**Aerospace**](skills-catalog/README.md#aerospace-aerospace) | Aerospace Toolbox&trade; |
| [**AI and Statistics**](skills-catalog/README.md#ai-and-statistics-ai-and-statistics) | Curve Fitting Toolbox&trade;, Deep Learning Toolbox&trade;, and Statistics and Machine Learning Toolbox&trade; |
| [**Automotive**](skills-catalog/README.md#automotive-automotive) | Automated Driving Toolbox&trade;, RoadRunner, and RoadRunner Scene Builder |
| [**Cloud Solutions**](skills-catalog/README.md#cloud-solutions-cloud-solutions) | MATLAB Drive&trade; |
| [**Code Generation**](skills-catalog/README.md#code-generation-code-generation) | Embedded Coder&trade;, Fixed-Point Designer&trade;, GPU Coder&trade;, and MATLAB Coder&trade; |
| [**Computational Biology**](skills-catalog/README.md#computational-biology-computational-biology) | SimBiology&trade; |
| [**Computational Finance**](skills-catalog/README.md#computational-finance-computational-finance) | Datafeed Toolbox&trade; and Spreadsheet Link&trade; |
| [**Control Systems**](skills-catalog/README.md#control-systems-control-systems) | Predictive Maintenance Toolbox&trade; |
| [**Image Processing and Computer Vision**](skills-catalog/README.md#image-processing-and-computer-vision-image-processing-and-computer-vision) | Image Processing Toolbox&trade;, Computer Vision Toolbox&trade;, Lidar Toolbox&trade;, and Medical Imaging Toolbox&trade; |
| [**Math and Optimization**](skills-catalog/README.md#math-and-optimization-math-and-optimization) | Optimization Toolbox&trade; and PDE Toolbox&trade; |
| [**Parallel Computing**](skills-catalog/README.md#parallel-computing-parallel-computing) | Parallel Computing Toolbox&trade; and MATLAB Parallel Server&trade; |
| [**Radar**](skills-catalog/README.md#radar-radar) | Phased Array System Toolbox&trade;, Sensor Fusion and Tracking Toolbox&trade;, and Mapping Toolbox&trade; |
| [**Reporting and Database Access**](skills-catalog/README.md#reporting-and-database-access-reporting-and-database-access) | Database Toolbox&trade;, MATLAB Report Generator&trade;, and Simulink Report Generator&trade; |
| [**RF and Mixed Signal**](skills-catalog/README.md#rf-and-mixed-signal-rf-and-mixed-signal) | Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Toolbox&trade;, RF PCB Toolbox&trade;, and SerDes Toolbox&trade; |
| [**Robotics and Autonomous Systems**](skills-catalog/README.md#robotics-and-autonomous-systems-robotics-and-autonomous-systems) | Navigation Toolbox&trade;, UAV Toolbox&trade;, and Robotics System Toolbox&trade; |
| [**Signal Processing**](skills-catalog/README.md#signal-processing-signal-processing) | Audio Toolbox&trade;, DSP HDL Toolbox&trade;, DSP System Toolbox&trade;, Signal Processing Toolbox&trade;, and Wavelet Toolbox&trade; |
| [**Test and Measurement**](skills-catalog/README.md#test-and-measurement-test-and-measurement) | Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Industrial Communication Toolbox&trade;, MATLAB Support Package for Arduino Hardware&trade;, and Vehicle Network Toolbox&trade; |
| [**Wireless Communications**](skills-catalog/README.md#wireless-communications-wireless-communications) | Communications Toolbox&trade;, 5G Toolbox&trade;, WLAN Toolbox&trade;, Bluetooth&reg; Toolbox&trade;, Satellite Communications Toolbox&trade;, Wireless Network Toolbox&trade;, and Wireless Testbench&trade; |
<!-- END SKILLS -->
---
## Update MATLAB Agentic Toolkit

To update the toolkit, download the latest installer add-on by clicking [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx). Open the downloaded file with MATLAB, and run this command in MATLAB.

```matlab
setupAgenticToolkit("update")
```

This updates the skills, configurations, and MCP server binary for both the MATLAB and Simulink Agentic Toolkits.

---
## Security Considerations
When using the MATLAB Agentic Toolkit and MATLAB MCP Server, you should thoroughly review and validate all tool calls before you run them. Always keep a human in the loop for important actions and only proceed once you are confident the call will do exactly what you expect. For more information, see [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#user-interaction-model) and [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#security-considerations).

---
## Data Collection

The MATLAB MCP Server collects anonymized usage data by default. For full details, see [Data Collection](https://github.com/matlab/matlab-mcp-server#data-collection) in the MCP server documentation. To opt out, see [Disable Data Collection](Configuration_and_Troubleshooting.md#disable-data-collection).

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

