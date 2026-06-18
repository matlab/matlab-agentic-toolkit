# Probe Simulink Model (SLX)

> Inspect, analyze, debug, or investigate a Simulink model (.slx/.mdl) by extracting model structure, block parameters, mask info, and signal connectivity as JSON via a MATLAB probe script. Never read SLX files directly.

When you need to analyze, investigate, debug, or bash any MATLAB/Simulink artifact (`.slx`, `.mdl`), you MUST NOT attempt to read or parse the SLX file directly. SLX files are binary ZIP archives — they are not human-readable. Instead, follow the procedure below to extract everything you need via a MATLAB probe script.

---

## When to use this skill

- Analyzing block parameters, solver settings, or model configuration
- Bashing or QA-testing a Simulink model
- Investigating simulation failures, mask callbacks, or block wiring
- Understanding model hierarchy before writing test scripts
- Comparing expected vs actual block parameter values
- Any task where you need to "look inside" an SLX file

---

## Step 1: Copy the probe script to your working directory

A ready-to-use probe script is provided at `../scripts/probeSlxModel.m` (in the `scripts/` folder at the skill root). Copy it to the directory containing the model you want to probe:

```matlab
% Copy the probe script to the current working directory
copyfile(fullfile(fileparts(mfilename('fullpath')), 'scripts', 'probeSlxModel.m'), pwd);
```

Alternatively, use the MCP tool to run it directly:
```matlab
run('path/to/scripts/probeSlxModel.m');
probeSlxModel('modelName.slx');
```

The script recursively walks every subsystem and block, captures all dialog parameters with their current values, mask info, signal connectivity, and writes the result to a JSON file. You may trim sections that are irrelevant to the task at hand for faster execution.

---

## Step 2: Run the probe script

Launch MATLAB and execute the probe. Choose the right invocation for the environment:

```bash
# Standard (from the directory containing the .slx and probe script)
mw matlab -nodesktop -batch "probeSlxModel('modelName.slx')"

# If the model needs Simulink GUI (e.g. masked blocks with icon callbacks)
mw matlab -nodesktop -batch "probeSlxModel('modelName.slx')"

# If you only need model config (no block hierarchy), generate a trimmed probe
```

The script produces `<modelName>_probe.json` in the working directory.

---

## Step 3: Read and use the JSON

Read the generated `_probe.json` file. It gives you:

| Section | What it contains | Use it for |
|---------|-----------------|------------|
| `configuration` | Solver, start/stop time, logging, tolerances | Understanding sim settings, diagnosing solver issues |
| `hierarchy.blocks[]` | Recursive tree of every block | Navigating model structure, finding specific blocks |
| `blocks[].blockType` | Simulink block type (SubSystem, Gain, Sum...) | Filtering blocks by type |
| `blocks[].parameters` | Every dialog parameter with current value, type, and enum options | Verifying parameter values, writing `set_param` calls |
| `blocks[].maskParameters` | Mask-level params with prompts, types, evaluate flags | Understanding masked subsystem interfaces |
| `blocks[].maskCallbacks` | Mask init code, icon drawing code | Understanding callback behavior |
| `blocks[].children` | Nested subsystem contents (recursive) | Drilling into subsystem hierarchy |
| `topLevelLines` | Signal connectivity at top level | Understanding data flow |

---

## Rules

1. **Never read an SLX file directly** with the Read tool. It is a binary ZIP and will produce garbage. Always probe via MATLAB.
2. **Generate the probe script fresh each time.** Adapt it to the task -- strip sections you don't need (e.g., skip line connectivity if you only need parameter values). A smaller probe runs faster.
3. **Run with `-nodesktop`** (not `-nojvm`) if the model uses masked blocks, since mask evaluation may require Java.
4. **For very large models**, limit `SearchDepth` or probe only specific subsystems:
   ```matlab
   % Probe only one subsystem
   info.hierarchy = probeSubsystem([mdlName '/MySubsystem']);
   ```
5. **After probing**, use the JSON to construct precise `set_param`/`get_param` calls in your test scripts. Never guess parameter names -- they are in the probe output.
6. **If a probe reveals mask callbacks**, read the referenced `.m` files (paths are in the JSON) to understand the mask's init/update logic before writing tests.
7. **Re-probe after making changes** (via `set_param`) to verify the model state matches your expectations.
8. **Always close popup dialogs after simulation or model operations.** Simulink and toolbox blocks (e.g., PLL Testbench) may spawn warning/error dialog windows during simulation. After any `sim()` call or model operation, immediately find and close any popup dialogs using:
   ```matlab
   % Close warning/error dialogs that may have appeared
   dlgs = findall(0, 'Type', 'figure', 'Tag', 'Msgbox_Warning');
   if ~isempty(dlgs), delete(dlgs); end
   dlgs = findall(0, 'Type', 'figure', 'Tag', 'Msgbox_Error');
   if ~isempty(dlgs), delete(dlgs); end
   % Fallback: close any remaining message box figures by name
   allFigs = findall(0, 'Type', 'figure');
   for ii = 1:length(allFigs)
       nm = get(allFigs(ii), 'Name');
       if contains(nm, 'Warning') || contains(nm, 'Error')
           delete(allFigs(ii));
       end
   end
   ```
   Read the dialog message text before closing so you can report it to the user as part of your analysis.

---

## Quick-probe variant

When you only need one block's parameters (not the full model tree), use the lightweight `../scripts/quickProbe.m` script:

```matlab
quickProbe('model.slx', 'model/BlockName')
```

This writes all dialog parameters for the specified block to `quickprobe.json`.

---

## Example workflow

```
User: "Bash the ELD feature in model mctDSMCheckDefaults.slx"

1. Copy probeSlxModel.m from scripts/ to the working directory
2. Run:  mw matlab -nodesktop -batch "probeSlxModel('mctDSMCheckDefaults.slx')"
3. Read:  mctDSMCheckDefaults_probe.json
4. From JSON, learn:
   - Block 'CT DSM' is a masked SubSystem with parameters: dsmArchitecture, dsmOrder, feedbackDelay, ...
   - feedbackDelay mask param has Type='edit', Evaluate='on'
   - Solver is ode45, StopTime='1/(2*1000)'
5. Use this knowledge to write targeted set_param() calls and test scripts
6. After testing, re-probe to verify parameter state
```

Copyright 2026 The MathWorks, Inc.
