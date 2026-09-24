---
name: matlab-use-experiment-manager
description: >
  Create, modify, or delete experiments in Experiment Manager with live UI sync.
  TRIGGER when: user asks to create an experiment from code/script, wants to sweep parameters,
  asks to add/delete/edit experiments, or wants parameter changes reflected in the UI.
  Combines experiment creation (from code analysis) with frontend UI synchronization.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Experiment Manager Assistant

Create experiments from user code or problem descriptions AND keep the Experiment Manager (EM) UI
in sync — adding/deleting/editing experiments updates the browser tree and editor live,
without restarting EM.

## When to Use

Use this skill when the user wants to manage an experiment in MATLAB Experiment Manager:
create an experiment from a script or description, sweep parameters, add/delete/edit
experiments, rename or duplicate an experiment, or ask about an experiment's strategy,
parameters, or values — and have any change reflected live in the EM UI.

## When NOT to Use

Do not use this skill for requests that are not about managing an Experiment Manager
experiment. Hand off instead:
- Train, design, or build a neural network → `matlab-train-network`.
- Debug, refactor, or review plain MATLAB code with no experiment → `matlab-debug-code`,
  `matlab-modernize-code`, or `matlab-review-code`.
- Build an app, dashboard, or GUI from scratch → `matlab-build-app`.
- Make a live script or report → `matlab-create-live-script`.
- Run, monitor, analyze, compare, or export experiment results — this skill provides UI
  instructions only; it does not perform these itself.

## Setup

When this skill is invoked, add the skill's scripts folder to the MATLAB path so that
`manageExperimentHelpers` is available. Run this via the MATLAB MCP `evaluate_matlab_code` tool:

```matlab
addpath('<skill-base-directory>/scripts');
```

This skill manages experiments *inside the existing MATLAB Experiment Manager app*. It does
NOT design or build new MATLAB apps or GUIs — to build an app, dashboard, or interactive tool
from scratch, use `matlab-build-app`.

## How to use this skill

1. **Always read [common.md](references/common.md) first.** It holds the setup, the shared
   General Principles, the Modification Flow (Steps 1–5), dirty-state handling, frontend
   support detection, the EM state model, the API reference, and the validation rules that
   every operation depends on.
2. Then open the reference for the specific task the user is asking for.

## Tasks

Pick the one operation that matches the request:

| # | Task | Reference |
|---|------|-----------|
| 1 | **Create** — from code or description, generate function, open in EM | [create.md](references/create.md) |
| 2 | **Load Project** — open project in EM, list experiments, offer actions | [load-project.md](references/load-project.md) |
| 3 | **Update** — modify parameters, strategy, functions, supporting files | [update.md](references/update.md) |
| 4 | **Delete** — remove experiment tab, results, tree entry, and file | [delete.md](references/delete.md) |
| 5 | **Rename** — update name, tree label, and tab title | [rename.md](references/rename.md) |
| 6 | **Duplicate** — copy with a custom name | [duplicate.md](references/duplicate.md) |

**Two buckets:**
- **Project Management** — Load Project, Create
- **Experiment Management** — Update, Rename, Duplicate, Delete

For querying Experiment Manager UI state (answering questions about strategy, parameters, or values),
see the Query Experiment State section in [common.md](references/common.md#operation-query-experiment-state).

----

Copyright 2026 The MathWorks, Inc.

----
