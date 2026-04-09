# Skills Catalog

The skills catalog organizes agent skills into groups. Each group is a directory containing one or more skills (each with a `SKILL.md` and `manifest.yaml`).

## Skill Groups

| Group | Description | Skills | Status |
|-------|-------------|--------|--------|
| `toolkit` | Toolkit setup and configuration | 1 | Active |
| `matlab-core` | Foundational MATLAB skills for every workflow | 6 | Active |

## toolkit

Meta skills for installing and configuring the MATLAB Agentic Toolkit itself. These run before domain skills are available.

| Skill | Description |
|-------|-------------|
| `matlab-agentic-toolkit-setup` | Configure MATLAB paths, validate MCP connectivity, detect installed toolboxes |

## matlab-core

Foundational skills that underpin every MATLAB workflow — testing, debugging, code quality, app building, and more. These skills complement toolbox-specific domain skills.

| Skill | Description |
|-------|-------------|
| `matlab-testing` | Generate and run unit tests using `matlab.unittest`. Parameterized tests, fixtures, coverage |
| `matlab-creating-live-scripts` | Create plain-text Live Scripts with rich text, equations, and inline figures (R2025a+) |
| `matlab-building-apps` | Build apps programmatically with `uifigure`, `uigridlayout`, components, and `uihtml` |
| `matlab-reviewing-code` | Review MATLAB code for quality, performance, and adherence to MathWorks coding standards |
| `matlab-debugging` | Diagnose errors via MCP eval. Programmatic breakpoints, diagnostic instrumentation |
| `matlab-modernizing-code` | Replace deprecated MATLAB functions and anti-patterns with modern equivalents |

## How Skills Are Installed

Skills are not auto-discovered from this catalog. Each agent platform has a manifest file (in the repo root) that explicitly scopes which skill groups are included. See the [README](../README.md) for per-agent installation instructions.
