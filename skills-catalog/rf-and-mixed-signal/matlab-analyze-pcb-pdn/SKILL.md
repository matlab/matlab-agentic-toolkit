---
name: matlab-analyze-pcb-pdn
description: "PDN DC voltage/current analysis, IR drop, design rule checking, and multi-net batch analysis on imported PCB layouts. TRIGGER: user asks about power integrity, PDN analysis, IR drop, voltage distribution, current density, power nets, or design rule checking on a PCB. Invoke BEFORE writing code — the PDN API chain is specialized and non-obvious. SKIP: importing a PCB file (use matlab-read-pcb-layout), EM field/S-parameter extraction (use matlab-analyze-em), material/stackup setup only (use matlab-manage-pcb-material), transmission line design (use matlab-design-pcb-transmission-line)."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Analyzing Power Distribution Networks (PDN)

## When to Use

- Analyzing DC voltage and current distribution on PCB power rails
- Checking design rules (max current density, voltage margins, via current limits)
- Discovering and listing power nets on an imported PCB layout
- Assigning source/load/sense topology for PDN analysis
- Running batch analysis across multiple power rails on a board
- Inferring nominal voltage from standard PCB net naming conventions

## When NOT to Use

- Importing PCB layouts (Gerber, ODB++, Allegro) — use `matlab-read-pcb-layout`
- Analyzing S-parameters, fields, or EM performance — use `matlab-analyze-em`
- Analyzing crosstalk between signal traces — use `matlab-design-pcb-transmission-line`
- Defining dielectric or conductor materials — use `matlab-manage-pcb-material`
- Modeling via structures — use `matlab-model-via`

## Typical Workflow

1. **Before:** `matlab-read-pcb-layout` — import the PCB layout from Gerber/ODB++/Allegro
2. **This skill:** Run DC analysis, check IR drop, evaluate design rules, batch-analyze nets
3. **After:** Iterate on the physical design in CAD and re-import, or use results to inform stackup changes via `matlab-manage-pcb-material`

## Quick Reference

| Task | Code |
|------|------|
| Import PCB layout | `pcb = pcbFileRead('board_native')` |
| List all nets | `netList = cadnetList(pcb)` |
| Find power nets | Filter `cadnetList(pcb)` with `regexpi` (see below) |
| Find specific rail | `idx = ~cellfun(@isempty, regexpi(netList.CadnetName, "P0V8"))` |
| Infer rail voltage | Parse net name with regex helper `parseNetVoltage` (see below) |
| Create cadnet | `cnet = cadnet(pcb, 'P0V8')` |
| Show cadnet layout | `show(cnet)` |
| Find components on net | `comps = findComponents(cnet)` |
| Filter by type | `inductors = findComponents(cnet, "ComponentType", "Inductor")` |
| Create PDN model | `PDN = powerDistributionNetwork(cnet)` |
| Assign topology | `setNetworkParameters(PDN, Source=src, Load=load, Sense=sense)` |
| Auto-assign topology | `setNetworkParameters(PDN, AutoAssignDefault='True')` |
| Set DC parameters | `setDCParameters(PDN, "NominalVoltage", 0.8, "LoadCurrent", 1)  % placeholder — ask user` |
| Set DC rules | `setDCRules(PDN, "MaxCurrentDensity", 0.5, "MinVoltage", 0.784)` |
| Voltage distribution | `voltage(PDN)` |
| Voltage with violations | `voltage(PDN, ShowViolation=true)` |
| Current distribution | `current(PDN)` |
| Current with arrows | `current(PDN, Direction='on')` |

## PCB Import and Net Discovery

### Importing a PCB Layout

`pcbFileRead` imports a PCB file and returns an object for hierarchical inspection. Supported formats: native directory (CSV files), ODB++ (zipped or unzipped), and Cadence Allegro `.brd` (requires one-time `extractaSetup()`).

```matlab
% Native format (directory containing CSV files)
pcb = pcbFileRead(fullfile(boardDir, 'pcie5_native'));

% ODB++ format
pcb = pcbFileRead(fullfile(boardDir, 'myboard.zip'));

% Allegro .brd (run extractaSetup() once first)
extractaSetup();  % one-time setup for Allegro support
pcb = pcbFileRead(fullfile(boardDir, 'myboard.brd'));
```

The returned object exposes: `NumLayers`, `NumCadnets`, `NumPadStacks`, `NumComponents`, `NumParts`, `LayerHeight`.

### Listing All Nets

```matlab
NetList = cadnetList(pcb);
disp(NetList);
```

Returns a table with columns: `CadnetIdx`, `CadnetName`, `NumPins`, `Length`. A real board may have 3000+ nets.

### Finding Power Nets

There is no built-in `findPowerNets` function. Filter the `cadnetList` output using regex to identify power and ground nets by name:

```matlab
netList = cadnetList(pcb);

% Define naming patterns (case-insensitive)
powerPatterns = ["^P\d+V", "^VDD", "^VCC", "^AVDD", "^DVDD", "^VDDO"];
groundPatterns = ["^GND", "^AGND", "^DGND", "^PGND", "^VSS", "^AVSS", "^DVSS"];

% Match power nets
isPower = false(height(netList), 1);
for p = powerPatterns
    isPower = isPower | ~cellfun(@isempty, regexpi(netList.CadnetName, p));
end
powerNets = sortrows(netList(isPower, :), 'NumPins', 'descend');

% Match ground nets
isGround = false(height(netList), 1);
for g = groundPatterns
    isGround = isGround | ~cellfun(@isempty, regexpi(netList.CadnetName, g));
end
groundNets = sortrows(netList(isGround, :), 'NumPins', 'descend');

% Filter by minimum pin count
minPins = 5;
powerNets = powerNets(powerNets.NumPins >= minPins, :);

% Search for a specific pattern (e.g., 0.8V rails)
idx = ~cellfun(@isempty, regexpi(powerNets.CadnetName, "P0V8"));
rails_0v8 = powerNets(idx, :);
```

**Common power net naming conventions (case-insensitive):**
- Power rails: `P<digit>V<digit>` (P0V8, P3V3_AUX, P12V), `VDD*`, `VCC*`, `AVDD*`, `DVDD*`, `VDDO*`
- Ground nets: `GND*`, `AGND*`, `DGND*`, `PGND*`, `VSS*`, `AVSS*`, `DVSS*`

### Inferring Rail Voltage from Net Name

There is no built-in `inferRailVoltage` function. Parse voltage from net names using regex:

```matlab
function nomV = parseNetVoltage(netName)
    netName = string(netName);
    % Pattern: P<int>V<frac> (e.g., P0V8 → 0.8, P3V3 → 3.3, P12V → 12.0)
    tok = regexp(netName, '(?i)P(\d+)V(\d*)', 'tokens');
    if ~isempty(tok)
        intPart = str2double(tok{1}{1});
        fracStr = tok{1}{2};
        if isempty(fracStr)
            nomV = intPart;
        else
            nomV = intPart + str2double(fracStr) / 10^numel(fracStr);
        end
        return;
    end
    % Pattern: explicit decimal (e.g., 3.3V, 1.8V)
    tok = regexp(netName, '(\d+\.\d+)\s*V', 'tokens');
    if ~isempty(tok)
        nomV = str2double(tok{1}{1});
        return;
    end
    % Pattern: millivolt (e.g., 800MV → 0.8)
    tok = regexp(netName, '(\d+)\s*MV', 'tokens', 'ignorecase');
    if ~isempty(tok)
        nomV = str2double(tok{1}{1}) / 1000;
        return;
    end
    nomV = NaN;
end
```

Usage in a loop:

```matlab
for k = 1:height(powerNets)
    netName = powerNets.CadnetName{k};
    nomV = parseNetVoltage(netName);
    fprintf('%s → %.2f V\n', netName, nomV);
end
```

## cadnet Object

### Creating a Cadnet

```matlab
cnet = cadnet(pcb, 'P0V8');
```

**Properties:**

| Property | Description |
|----------|-------------|
| `NumPins` | Number of pins on the net |
| `NumSurfaces` | Number of copper surfaces |
| `NumVias` | Number of vias |
| `NumTraces` | Number of traces |
| `TotalLength` | Total trace length |
| `EntityList` | List of all entities |
| `Voltage` | Nominal voltage |
| `LayerRange` | Layers spanned by the net |

### Visualizing a Cadnet

```matlab
show(cnet);
```

### Finding Connected Components

`findComponents` returns a table with columns: `Refdes`, `PinList`, `ComponentType`, `Part`.

```matlab
% All components on the net
allComps = findComponents(cnet);

% Filter by component type
inductors = findComponents(cnet, "ComponentType", "Inductor");
ics       = findComponents(cnet, "ComponentType", "IC");
resistors = findComponents(cnet, "ComponentType", "Resistor");
caps      = findComponents(cnet, "ComponentType", "Capacitor");
```

The `Refdes` values are strings -- use them directly for Source/Load/Sense assignment in `setNetworkParameters`.

### Getting Detailed Cadnet Data

```matlab
data = cadnetData(cnet);
s = shapes(cnet);
```

## powerDistributionNetwork Object

### Creating a PDN Model

```matlab
PDN = powerDistributionNetwork(cnet);
```

**Properties:**

| Property | Description |
|----------|-------------|
| `NetType` | Type of net |
| `Source` | Source component(s) |
| `Load` | Load component(s) |
| `Sense` | Sense component(s) |
| `PlatingThickness` | Via barrel plating thickness (inches) |
| `NominalVoltage` | Nominal voltage (V) |
| `LoadCurrent` | Load current (A) |
| `MaxCurrentDensity` | Max current density (mA/mil²) |
| `MinVoltage` | Minimum allowable voltage (V) |
| `MaxVoltage` | Maximum allowable voltage (V) |
| `MaxViaCurrent` | Max via current (mA) |

## PDN Configuration

### setNetworkParameters -- Assign Source, Load, Sense, Plating

Use `findComponents` output to assign topology:

```matlab
% Manual assignment using RefDes from findComponents
setNetworkParameters(PDN, ...
    Source=sourceRefDes, ...
    Load=sinkRefDes, ...
    Sense=senseRefDes, ...
    PlatingThickness=0.002);

% Auto-assign defaults (fallback when topology is unclear)
setNetworkParameters(PDN, AutoAssignDefault='True');
```

- **Source** -- RefDes of the power source (typically an inductor). Use all inductors for multiphase rails.
- **Load** -- RefDes of the load (typically an IC). Use all ICs on the net.
- **Sense** -- RefDes of the sense component (typically a resistor or test point).
- **PlatingThickness** -- Via barrel plating thickness in **inches** (e.g., `0.002` = 2 mil ≈ 1.4 oz copper).

#### Sense Component Resolution

The `Sense` parameter is required. When no test point is available on the net, use a resistor as the sense component:

```matlab
tp = findComponents(cnet, 'ComponentType', 'Test Point');
if ~isempty(tp)
    senseRef = tp.Refdes;
else
    res = findComponents(cnet, 'ComponentType', 'Resistor');
    senseRef = res.Refdes(1);  % use first resistor as sense fallback
end
setNetworkParameters(PDN, Source=src, Load=load, Sense=senseRef, ...
    PlatingThickness=0.002);
```

#### Multiphase Rails

For multiphase VRM designs, multiple inductors feed the same rail. Always use all inductors as Source, not just the first:

```matlab
inductors = findComponents(cnet, "ComponentType", "Inductor");
setNetworkParameters(PDN, Source=inductors.Refdes);  % handles multiphase
```

### setDCParameters -- Set Electrical Parameters

```matlab
setDCParameters(PDN, "NominalVoltage", 0.8, "LoadCurrent", 1);  % placeholder — ask user for actual value
```

### setDCRules -- Set DC Design Rules

```matlab
setDCRules(PDN, ...
    "MaxCurrentDensity", 0.5, ...
    "MaxVoltage", 0.816, ...
    "MinVoltage", 0.784, ...
    "MaxViaCurrent", 500);
```

**DC rules units (mixed — specific to this API):**

| Property | Units | Description |
|----------|-------|-------------|
| `PlatingThickness` | inches | Via barrel plating thickness (0.002 = 2 mil) |
| `NominalVoltage` | V | Nominal rail voltage |
| `LoadCurrent` | A | Expected load current per sink |
| `MaxCurrentDensity` | mA/mil² | Current density thermal limit |
| `MinVoltage` | V | Minimum allowable absolute voltage |
| `MaxVoltage` | V | Maximum allowable absolute voltage |
| `MaxViaCurrent` | mA | Max current through a single via |

**Voltage tolerance guidelines:**

| Rail Voltage | Tolerance | MinVoltage | MaxVoltage |
|---|---|---|---|
| < 1 V | 1–2% | P0V8: 0.8 × 0.98 = **0.784 V** | 0.8 × 1.02 = **0.816 V** |
| 1–3.3 V | 2–3% | P1V8: 1.8 × 0.975 = **1.755 V** | 1.8 × 1.025 = **1.845 V** |
| 3.3–5 V | 3–5% | P3V3: 3.3 × 0.97 = **3.201 V** | 3.3 × 1.03 = **3.399 V** |

## DC Analysis

### Voltage Distribution

```matlab
voltage(PDN);

% Show design rule violations
voltage(PDN, ShowViolation=true);
```

### Current Distribution

```matlab
current(PDN);

% Show current direction arrows
current(PDN, Direction='on');
```

### Inspecting PDN Configuration Before Analysis

Check the PDN model properties after setup to verify assignments:

```matlab
PDN.Source
PDN.Load
PDN.Sense
PDN.NominalVoltage
PDN.LoadCurrent
```

## Workflow: Single-Net PDN Analysis

Interactive workflow for analyzing one power net end-to-end:

```matlab
%% Step 1: Import the board
pcb = pcbFileRead(fullfile(boardDir, 'pcie5_native'));

%% Step 2: Identify power nets
netList = cadnetList(pcb);
powerPatterns = ["^P\d+V", "^VDD", "^VCC", "^AVDD", "^DVDD"];
isPower = false(height(netList), 1);
for p = powerPatterns
    isPower = isPower | ~cellfun(@isempty, regexpi(netList.CadnetName, p));
end
powerNets = sortrows(netList(isPower, :), 'NumPins', 'descend');
disp(powerNets);

%% Step 3: Create cadnet and inspect
cnet = cadnet(pcb, 'P0V8');
show(cnet);

%% Step 4: Discover components for topology assignment
allComps = findComponents(cnet);
inductors = findComponents(cnet, "ComponentType", "Inductor");
ics       = findComponents(cnet, "ComponentType", "IC");
resistors = findComponents(cnet, "ComponentType", "Resistor");

%% Step 5: Resolve voltage from net name
nomV = parseNetVoltage('P0V8');  % 0.8 V (see helper function above)

%% Step 6: Create and configure PDN
PDN = powerDistributionNetwork(cnet);

setNetworkParameters(PDN, ...
    Source=inductors.Refdes, ...
    Load=ics.Refdes, ...
    Sense=resistors.Refdes(1), ...
    PlatingThickness=0.002);

setDCParameters(PDN, "NominalVoltage", nomV, "LoadCurrent", 1);  % placeholder — ask user for actual value

tolerancePct = 0.02;  % 2% for <1V rails
setDCRules(PDN, ...
    "MaxCurrentDensity", 0.5, ...
    "MaxVoltage", nomV * (1 + tolerancePct), ...
    "MinVoltage", nomV * (1 - tolerancePct), ...
    "MaxViaCurrent", 500);

%% Step 7: Run analysis
voltage(PDN, ShowViolation=true);
current(PDN, Direction='on');
```

## Workflow: Multi-Net Batch Analysis

For batch analysis of all power rails on a board (loop with skip logic, per-rail spec tables), see [references/batch-analysis.md](references/batch-analysis.md).

## Common Patterns

### Component Refdes Usage

`findComponents` returns `Refdes` as a string -- use directly in `setNetworkParameters`. Use all matching components, not just the first:

```matlab
inductors = findComponents(cnet, "ComponentType", "Inductor");
setNetworkParameters(PDN, Source=inductors.Refdes);  % all inductors
```

### When to Use AutoAssignDefault

Use `AutoAssignDefault='True'` only when:
- No inductors found on the net (LDO rails, connector-fed rails)
- User explicitly requests automatic topology assignment
- Quick screening mode where accuracy is secondary

Always prefer explicit `findComponents`-based assignment.

### Z-Axis Visualization

Use `daspect` to see Z-axis detail in 3D views:

```matlab
ax = gca;
daspect(ax, [1, 1, 0.05]);
```

## Pitfalls

1. **`inferRailVoltage` returns `NaN` for unrecognized nets.** Guard with `isnan()` before using the result in calculations or display (e.g., `string(NaN)` produces `"NaN"`, not `missing`).

2. **`Sense` parameter is required in `setNetworkParameters`.** When no test point exists on the net, use a resistor as the sense component. Omitting `Sense` will cause errors during analysis.

3. **`AutoAssignDefault` is a fallback, not a first choice.** It may produce incorrect topology assignments on complex rails (LDO, connector-fed). Prefer explicit assignment via `findComponents` output.

4. **`LoadCurrent` cannot be inferred from board data — STOP and ask.** Unlike `NominalVoltage` (which can be parsed from net names), load current must come from IC datasheets or system power budgets. Before calling `setDCParameters`, ask the user for the actual load current and **STOP execution — do not proceed until the user responds.** Do NOT assume 1 A or any default without explicit user confirmation. Once the user responds that they don't have it or asks you to proceed, present these estimation options and let them choose:
   - **Per-pin heuristic:** 0.5 A × number of load pins (e.g., 130 pins → 65 A)
   - **TDP-based:** total power budget ÷ rail voltage (e.g., 40 W ÷ 0.8 V = 50 A)
   - **Fixed conservative:** 10 A per load IC (quick screening)
   - **1 A token:** minimal value to verify the workflow runs end-to-end

   Only after the user selects an option or provides a value, proceed with `setDCParameters`.

5. **`LoadCurrent` must be a vector, not a scalar total.** When multiple load ICs exist on a rail, `setDCParameters` requires one current value per load. For example, with loads U1 (4.8 A) and U9 (0.2 A): `setDCParameters(PDN, LoadCurrent=[4.8, 0.2])`. Passing a scalar (e.g., `LoadCurrent=5`) errors when the topology has more than one load.

6. **PDN units are mixed — not all SI.** `PlatingThickness` is in **inches** (not meters): `0.002` = 2 mil ≈ 1.4 oz copper. `MaxCurrentDensity` is **mA/mil²** (not A/mm²). `MaxViaCurrent` is **mA** (not A). `MinVoltage`/`MaxVoltage` are absolute **volts**. Using meters for plating (e.g., `35e-6`) or amps for via current (e.g., `1`) produces wildly incorrect results.

7. **Batch mode: skip rather than block.** When a rail is missing voltage, source, or load information, skip it and report which rails were skipped and why. Do not halt the entire batch for one incomplete rail.

8. **Large boards have 3000+ nets.** `cadnetList` returns all nets. Filter with regex on `CadnetName` to narrow to power/ground nets, then further filter by `NumPins` or specific patterns.

9. **`cnet.Voltage` is unreliable.** The `Voltage` property on the cadnet object is populated heuristically from the PCB file and often returns `'0.000'` even for valid power rails. Always parse the voltage from the net name using regex instead of relying on this property.

10. **No built-in `findPowerNets` or `inferRailVoltage`.** These do not exist as MATLAB functions. Use `cadnetList(pcb)` + `regexpi` filtering for net discovery, and the `parseNetVoltage` helper (defined in this skill) for voltage inference from net names.

11. **`.brd` files require extracta — STOP if unavailable.** If the user only has a `.brd` file and `extractaSetup()` returns `[]` or errors, STOP and inform the user: extracta (from a Cadence install) is required. Offer alternatives: (a) provide the path to `extracta.exe`, (b) export from Allegro as ODB++ or native CSV format, (c) use a colleague's Cadence install to convert. Do not attempt workarounds.

## Related Skills

- `matlab-read-pcb-layout` -- Importing PCB/package layouts for PDN analysis
- `matlab-manage-pcb-material` -- Substrate and conductor material setup
- `matlab-model-via` -- Via modeling for power delivery paths
- `matlab-analyze-em` -- EM analysis fundamentals

----

Copyright 2026 The MathWorks, Inc.
