# Skills Catalog

The skills catalog organizes agent skills into groups. Each group is a directory containing one or more skills (each with a `SKILL.md` and `manifest.yaml`).

## Skills

<!-- BEGIN SKILLS -->
**Image Processing and Computer Vision** — image processing and computer vision skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-display-image` | Display images and annotations for image processing, computer vision, and visual inspection. |

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

**RF and Mixed Signal** — RF and mixed-signal skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-model-serdes-systems` | Model, simulate, and optimize Serializer/Deserializer (SerDes) systems — serial and parallel links — using MATLAB SerDes Toolbox. |

**Signal Processing** — signal processing skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-design-digital-filter` | Design and validate digital filters in MATLAB. |

**Toolkit** — setup and management for the MATLAB Agentic Toolkit.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-agentic-toolkit-setup` | Install and configure the MATLAB Agentic Toolkit — detect MATLAB, install the MCP server, register with your AI coding agent, and verify the environment. |

**Wireless Communications** — wireless communications skills for AI coding agents.

| Skill | What it teaches your agent |
|-------|---------------------------|
| `matlab-add-awgn` | Add Additive White Gaussian Noise (AWGN) noise and convert between SNR, Eb/No, Es/No, and per-subcarrier SNR for communications simulations. |

<!-- END SKILLS -->

## How Skills Are Installed

Skills are not auto-discovered from this catalog. Each agent platform has a manifest file (in the repo root) that explicitly scopes which skill groups are included. See the [README](../README.md) for per-agent installation instructions.

----

Copyright 2026 The MathWorks, Inc.

----
