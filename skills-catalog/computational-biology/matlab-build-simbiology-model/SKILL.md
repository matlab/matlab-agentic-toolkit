---
name: matlab-build-simbiology-model
description: "Build, modify, and diagram SimBiology models — API reference, helper functions, and layout patterns. Use when constructing or editing models programmatically or visually."
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.2"
---

# Build SimBiology Models

API reference, helper functions, and patterns for building, modifying, and
diagramming SimBiology models. Works in all MATLAB environments (desktop,
headless, batch, remote). Diagram/layout features require the Model Builder
app and are activated only when the user requests visual output.

## When to Use

- Building or modifying SimBiology models (compartments, species, reactions, parameters, rules, events, doses, observables, variants)
- Opening, saving, or loading models in the Model Builder / Analyzer apps
- Designing or adjusting diagram layouts
- Keywords: "build", "create", "modify", "add compartment/species/reaction", "diagram", "layout"

## When NOT to Use

- Simulation and analysis (use `matlab-simulate-simbiology-model`)
- Parameter fitting, population modeling, NCA (use `matlab-fit-simbiology-model`)

## Must-Follow Rules

### 1. Add helper scripts to the MATLAB path first

Run at the start of every session:
```matlab
addpath(fullfile('<WORKSPACE_ROOT>', '.claude', 'skills', 'matlab-build-simbiology-model', 'scripts'));
disp('Helper scripts added to path.')
```

### 2. Only open the Builder when needed

Do NOT open the Model Builder by default. Open it when:
- The user explicitly requests a diagram, layout, or visual
- The input is an `.sbproj` file — use `loadViaBuilder` to preserve
  diagram layout/styling (`sbioloadproject` loses this data)

A model is fully functional without a diagram — it can be simulated,
fitted, and analyzed using only the model object on `sbioroot`.

### 3. Model construction uses standard SimBiology API

Build models using `addcompartment`, `addspecies`, `addreaction`, etc.
directly. This works in all environments: desktop, headless, batch, remote.

```matlab
model = sbiomodel('MyModel'); disp(model.uuid)
comp = addcompartment(model, 'Central', 1);
addspecies(comp, 'Drug', 100);
addparameter(model, 'ke', 0.1);
rx = addreaction(model, 'Central.Drug -> null');
kl = addkineticlaw(rx, 'MassAction');
kl.ParameterVariableNames = {'ke'};
```

For **standard PK models** (1- or 2-compartment with standard dosing and
elimination), use `references/pk-library-guidance.md` as the reference for
correct parameterization, naming, and rules. When no diagram is needed,
call `PKModelDesign` directly. When the user requests a diagram, construct
the model manually following the same PK library conventions but use
`addAndPositionCompartment` for layout control (see Rule 8b).

### 4. Write reactions in the biological forward direction

The diagram renders **arrows on products** and **plain lines on reactants**
(based on the forward direction of the reaction string). Writing a reaction
backwards produces incorrect arrows even if the kinetics are equivalent.

```matlab
% CORRECT — L and R get plain lines, C gets an arrow
addreaction(model, 'cell.L + cell.R <-> cell.C');

% WRONG — same kinetics but L and R get arrows (they're "products" now)
addreaction(model, 'cell.C <-> cell.L + cell.R');
```

Guidelines:
- **Binding:** write `A + B -> C` (substrates on left, complex on right)
- **Degradation/elimination:** write `Drug -> null` (not `null -> Drug`)
- **Synthesis:** write `null -> mRNA` (not `mRNA -> null`)
- **Transport:** write `Source.Drug -> Dest.Drug` (source on left)

### 5. Always use qualified names for species and reaction-scoped parameters

Always reference species and reaction-scoped parameters by their **qualified name**. If any of the names are not valid MATLAB variable names, surround them with square brackets before building the qualified name.

- **Species:** `CompartmentName.SpeciesName` (e.g., `Central.Drug`, `Peripheral.[Drug-bound]`)
- **Reaction-scoped parameters:** `ReactionName.ParameterName` (e.g., `Elimination.ke`)

**Qualification is always exactly one level deep** — the immediate parent
compartment only. Multi-level paths like `Body.Central.Drug` are **invalid**
in reaction strings. This is never ambiguous because compartment names must
be globally unique across the entire model (SimBiology enforces this
regardless of nesting depth). So `Central.Drug` is always sufficient.

**Compartment naming rules:**
- Names must be unique across the entire model — no two compartments can
  share a name even at different nesting levels
- If you need hierarchical naming, use underscores: `Body_Central` (not
  nested compartments both named `Central`)
- Species names must be unique within a compartment but can repeat across
  different compartments (disambiguated by `Compartment.Species`)

### 6. Use modern property names (`Value`, `Units`, `Constant`)

SimBiology objects (species, compartments, parameters) share a unified
property interface. Always use the modern names:

| Modern | Deprecated (do NOT use) | Applies to |
|--------|------------------------|------------|
| `Value` | `InitialAmount`, `Capacity` | species, compartments, parameters |
| `Units` | `InitialAmountUnits`, `CapacityUnits`, `ValueUnits` | species, compartments, parameters |
| `Constant` | `ConstantAmount`, `ConstantCapacity`, `ConstantValue` | species, compartments, parameters |

```matlab
sp.Value = 100;       % NOT sp.InitialAmount
sp.Units = 'milligram';  % NOT sp.InitialAmountUnits
sp.Constant = false;  % NOT sp.ConstantAmount

comp.Value = 1;       % NOT comp.Capacity
comp.Units = 'liter'; % NOT comp.CapacityUnits
comp.Constant = true; % NOT comp.ConstantCapacity

p.Value = 0.1;        % NOT redundant, but never use p.ValueUnits or p.ConstantValue
p.Units = '1/hour';
p.Constant = true;
```
### 7. Close Builder and Analyzer before `sbioreset`

`sbioreset` does NOT close these apps, leaving orphaned windows:
```matlab
try mb = SimBiology.web.desktophandler.getModelBuilder();
    if ~isempty(mb) && isfield(mb,'webWindow') && isvalid(mb.webWindow), mb.webWindow.close(); end
catch, end
try ma = SimBiology.web.desktophandler.getModelAnalyzer();
    if ~isempty(ma) && isfield(ma,'webWindow') && isvalid(ma.webWindow), ma.webWindow.close(); end
catch, end
pause(1); sbioreset;
```
### 8. Diagram rules (only when user requests a diagram)

The following rules apply ONLY when the user asks for a diagram or layout.
Skip all of these for pure model construction.

**Model size limit (precondition):** Layout helpers bail out above
**400 total blocks** (species + reactions). For large models, skip
automated layout — use simple grid positioning instead (reactions at
midpoints of connected species).

**a. Use `addAndPositionCompartment` for diagram layout**

When building a diagram, use `addAndPositionCompartment` instead of raw
`addcompartment` + `setBlock` — it atomically creates, positions, and
validates each compartment.

```matlab
% speciesInfo: cell array of structs with .Name, .Value, .Position
speciesInfo = {
    struct('Name', 'Drug', 'Value', 100, 'Position', [40, 30, 50, 16]);
    struct('Name', 'DrugBound', 'Value', 0, 'Position', [140, 30, 100, 16])
};
[comp, sp] = addAndPositionCompartment(model, 'Central', 1, [20, 20, 280, 80], speciesInfo);
% sp is a SimBiology Species ARRAY — index with sp(1), sp(2), NOT sp{1}
```

**b. Diagram build order**

1. Open the Builder first — the diagram does not exist until the Builder
   creates it. All `simbio.diagram.*` calls and `addAndPositionCompartment`
   will fail without this step.
2. Plan `[x y w h]` positions for ALL compartments up front (leave 80 px gaps minimum)
3. Build ONE compartment at a time with `addAndPositionCompartment`
4. Add ALL parameters (including rule LHS targets), reactions, rules, doses, events
5. `repositionAllReactions(model)` then `checkDiagramLayout(model)` — fix until zero violations
6. `positionAncillaryBlocks(model)` — positions rule/parameter blocks in a grid to the right

**c. Leave 80 px gaps between connected compartments**

Inter-compartment reaction nodes (15×15) are placed in these gaps by
`repositionAllReactions`. Without adequate gaps, reaction lines cross
through compartment blocks. For compartments with many shared reactions
(3+), increase to 120 px.

**d. Post-placement validation is mandatory**

After placing all blocks:
```matlab
repositionAllReactions(model);
results = checkDiagramLayout(model);
if results.nTotal > 0
    for i = 1:numel(model.Reactions)
        pos = computeSafeReactionPosition(model, model.Reactions(i));
        simbio.diagram.setBlock(model.Reactions(i), 'Position', pos);
    end
    results = checkDiagramLayout(model);
end
positionAncillaryBlocks(model);  % must run LAST, after all objects exist
```

**e. Always use the safe-open pattern for the Builder**

Never call `simBiologyModelBuilder(model)` without first checking
`isAppOpen('builder')`. If open, close it, wait 2s, then reopen.

```matlab
if isAppOpen('builder')
    try
        mb = SimBiology.web.desktophandler.getModelBuilder();
        if ~isempty(mb) && isfield(mb, 'webWindow') && isvalid(mb.webWindow)
            mb.webWindow.close();
        end
    catch, end
    pause(2);
end
% If Analyzer is open, it already has a model loaded — open Builder
% without an argument so it picks up the Analyzer's active model.
% Passing a model argument when Analyzer is open can cause conflicts.
if isAppOpen('analyzer')
    simBiologyModelBuilder();
else
    simBiologyModelBuilder(model);
end
```

**f. Never close the Builder to make modifications**

The model handle is on `sbioroot` — all code works on the live model and
updates the diagram in real time. Only close when the user explicitly asks.

## Helper Functions (`scripts/`)

### Model construction (always available)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `getModelByUUID` | `model = getModelByUUID(uuid)` | Look up model by UUID |

### Diagram & Builder (only when user requests diagram/layout)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `addAndPositionCompartment` | `[comp,sp] = addAndPositionCompartment(model,name,cap,compPos,speciesInfo,Name=Value)` | Create compartment + species and position atomically. **`sp` is a Species array — index with `sp(1)`, NOT `sp{1}`.** Options: `FontWeight` (`"bold"`), `TextLocation` (`"center"`), `Padding` (20), `AutoExpand` (true), `AutoFixPositions` (true) |
| `checkDiagramLayout` | `results = checkDiagramLayout(model)` | Containment + line-through-block + overlap checks |
| `computeSafeReactionPosition` | `pos = computeSafeReactionPosition(model,rxn)` | Crossing-free reaction node position |
| `repositionAllReactions` | `nFixed = repositionAllReactions(model)` | Batch-reposition all reactions (up to 3 passes) |
| `positionAncillaryBlocks` | `n = positionAncillaryBlocks(model)` | Grid-position rule/parameter blocks to the right of compartments |
| `openLiveBuilder` | `openLiveBuilder(model)` | Open Builder with safe-open pattern |
| `isAppOpen` | `tf = isAppOpen(appName)` | Check if Builder/Analyzer is open |
| `loadViaBuilder` | `model = loadViaBuilder(filePath)` | Load .sbproj preserving diagram |
| `saveViaBuilder` | `saveViaBuilder(filePath)` | Save from Builder preserving diagram |
| `lineIntersectsRect` | `hit = lineIntersectsRect(x1,y1,x2,y2,rect)` | Shared geometry helper (used internally by layout scripts) |

### `checkDiagramLayout` output

```matlab
results.nTotal        % total violations (must be 0 before presenting)
results.nContainment  % species outside parent compartment
results.nLineThrough  % connection lines through unrelated blocks
results.nOverlap      % blocks <10px apart
```

## API Quick Reference

### Model
- `sbiomodel(name)` — create model; `model.uuid` — unique ID
- `sbioloadproject('file.sbproj')` — returns a **struct** with the model name as field; extract dynamically:
  ```matlab
  proj = sbioloadproject('file.sbproj');
  fn = fieldnames(proj);
  model = proj.(fn{1});
  ```
- `copyobj(model)` — deep clone (does NOT copy diagram layout); `verify(model)` — check consistency
- `sbioreset` — clear all models (close apps first!)

### Compartments
- `addcompartment(model, name, value)`
- `comp.Value`, `comp.Constant`, `comp.Units`, `model.Compartments`
- **Units consistency:** If any component has units, ALL components must have units (compartments, species, parameters). Missing units cause `'Dimensional analysis failed'` errors at simulation/fit time.

### Species
- `addspecies(comp, name, value)`
- `sp.Value`, `sp.Units`, `sp.BoundaryCondition`, `sp.Constant`
- `sp.Parent.Name` — parent compartment; `model.Species`

### Parameters
- `addparameter(model, name, value)` — model-scoped
- `addparameter(kineticLaw, name, value)` — reaction-scoped
- `p.Value`, `p.Units`, `p.Constant`, `model.Parameters`

### Reactions
- `addreaction(model, 'A -> B')` — forward; `'A <-> B'` — reversible
- `kl = addkineticlaw(rx, 'MassAction'); kl.ParameterVariableNames = {'k1'}` (or `{'kf','kr'}` for reversible)
- Multi-compartment: `'Central.Drug -> Peripheral.Drug'`

### Rules, Events, Doses
- `addrule(model, 'x = expr', ruleType)` — `'initialAssignment'`, `'repeatedAssignment'`, `'rate'`
- **Rule/reaction exclusivity:** A species that is the LHS of a rate rule or repeated assignment rule cannot also appear as a reactant or product in a reaction. Use one or the other to govern its dynamics.
- **Rule LHS requirement:** The LHS must be an existing species, parameter,
  or compartment with `Constant = false`. Create the parameter *before* the
  rule (not after as a fix — this ensures diagram blocks exist for layout):
  ```matlab
  p = addparameter(model, 'RO', 0); p.Constant = false;
  addrule(model, 'RO = Complex / (Target + Complex)', 'repeatedAssignment');
  ```
- `addevent(model, 'trigger', {'action1', 'action2'})`
- **Event action requirement:** Any parameter modified in an event action
  must have `Constant = false` (parameters default to `true`):
  ```matlab
  p = sbioselect(model, 'Type', 'parameter', 'Name', 'kgrow');
  p.Constant = false;
  addevent(model, 'Tumor.Cancer < 1e6', {'kgrow = kgrow * 0.5'});
  ```
- `sbiodose(name, 'schedule')` / `sbiodose(name, 'repeat')`
- Schedule: `.TargetName`, `.Amount`, `.Time`, `.Rate`
- Repeat: `.TargetName`, `.Amount`, `.StartTime`, `.Interval`, `.RepeatCount`
- `adddose(model, d)` / `removedose(model, d)`

### Observables & Variants
- `addobservable(model, name, expression)` — use `./` and `.*` for element-wise ops
- **StatesToLog caveat:** If the observable references a constant parameter (e.g., `'Drug ./ Vd'`), add that *parameter* to `StatesToLog` — otherwise it logs as NaN. Observables themselves are auto-logged when their dependencies are present (do NOT add observables to StatesToLog — it only accepts species, parameters, and compartments).
- `v = addvariant(model, name)` then `addcontent(v, {'type','name','prop',val})`
- `v.Content`, `getvariant(model, name)`

### Simulation Config
- `cs = getconfigset(model, 'active')`
- `cs.StopTime`, `cs.SolverType` (`'ode15s'`, `'ode45'`, `'sundials'`)
- `cs.RuntimeOptions.StatesToLog` — `'all'` or handle array

### Selection
- `sbioselect(model, 'Type', type, 'Name', name)`
- For reactions: use `'Reaction'` property (not `'Name'`)

## Core Patterns

### Model creation (standard — no diagram)

```matlab
model = sbiomodel('MyModel');
disp(model.uuid)
comp = addcompartment(model, 'Central', 1);
addspecies(comp, 'Drug', 100);
addparameter(model, 'ke', 0.1);
```

### Reactions

```matlab
% MassAction (always use qualified species names)
rx = addreaction(model, 'Central.Drug -> null');
kl = addkineticlaw(rx, 'MassAction');
kl.ParameterVariableNames = {'ke'};

% Custom rate
rx = addreaction(model, 'Central.E + Central.S <-> Central.ES');
rx.ReactionRate = 'kf*Central.E*Central.S - kr*Central.ES';

% Multi-compartment transfer
rx = addreaction(model, 'Central.Drug -> Peripheral.Drug');

% Species with invalid MATLAB variable names
rx = addreaction(model, 'Central.[Drug-bound] -> Central.[Drug-free]');
```

### Removing components

```matlab
delete(sbioselect(model, 'Type', 'species', 'Name', 'Drug'));
delete(sbioselect(model, 'Type', 'reaction', 'Reaction', 'Drug -> null'));
removedose(model, model.Doses(1));  % doses use removedose, not delete
```

### Doses

```matlab
% Bolus
d = sbiodose('Dose', 'schedule');
d.TargetName = 'Drug'; d.Amount = 100; d.Time = 0;
adddose(model, d);

% Repeat dose
d = sbiodose('RepeatDose', 'repeat');
d.TargetName = 'Drug'; d.Amount = 50;
d.StartTime = 0; d.Interval = 8; d.RepeatCount = 3;
adddose(model, d);
```

### Events, variants, observables

```matlab
% Event modifying a parameter — mark non-constant first
p = sbioselect(model, 'Type', 'parameter', 'Name', 'ke');
p.Constant = false;
ev = addevent(model, 'time >= 10', {'ke = ke * 2'}); ev.Name = 'EnzymeInduction';

% Event modifying a species (species default Constant=false — no extra step)
ev = addevent(model, 'time >= 10', {'Drug = 50'}); ev.Name = 'RescueDose';

v = addvariant(model, 'HighDose'); addcontent(v, {'parameter','ke','Value',0.5});
obs = addobservable(model, 'DrugConc', 'Drug ./ Central');
```

## Saving Models

- **Standard:** `save('mymodel.mat', 'model')` / `loaded = load('mymodel.mat'); model = loaded.model;`
  Do NOT use `sbiosaveproject` (deprecated, requires base workspace hacks).
- **With diagram (`.sbproj`):** `saveViaBuilder('name.sbproj')` / `loadViaBuilder(path)` (requires Builder open)
- **Switching models:** ask user to save first → close Builder → `pause(2)` → `simBiologyModelBuilder(newModel)`
- See `references/app-lifecycle-guidance.md` for full switching/coordination patterns.

## Diagram Basics (only when user requests diagram/layout)

### Coordinate system

`Position` = `[x y width height]` where `(x, y)` is **top-left corner**.

### Standard block sizes

| Block Type | Default Size | Notes |
|------------|--------------|-------|
| Species | `[50, 16]` | Scale width: <=5 chars → 50, 6-12 → 100, 13+ → 130 |
| Reaction | `[15, 15]` | |
| Rule | `[20, 20]` | |

### Compartment sizing from content

| Species Count | Size | Notes |
|---------------|------|-------|
| 1 | `160 x 100` | Single species, centered |
| 2 (isolated) | `240 x 170` | Vertically stacked |
| 2 (in chain) | `400 x 100` | Side by side |
| 3-5 | `160+n*50 x 100+n*35` | Scale to content |
| 6+ | `240+n*50 x 220+n*35` | Row layout, multiple rows if needed |

Internal padding: 30 px minimum on all sides.

### Row-based species placement (3+ species)

Distribute species evenly in a horizontal row at `y + height/2 - 8`, with
40 px margin from compartment edges. Scale species width by name length:
`<=5 chars → 50`, `6-12 → 100`, `13+ → 130`.

### Species ordering by connection direction

When a compartment has 2+ species that connect to *different* external
compartments, order them so each species faces its connections. This
prevents connection lines from crossing through sibling species.

- **Horizontal neighbors:** place the species connecting LEFT on the left
  edge, species connecting RIGHT on the right edge.
- **Vertical stacking:** place the species connecting UP/LEFT on top, the
  species connecting DOWN/RIGHT on bottom.
- **Example:** Blood has Neutrophil (connects left to Transit3) and
  Lymphocyte (connects upper-left to Spleen). Put Lymphocyte on top and
  Neutrophil on bottom so lines don't cross.

### Layout rules

**Hard requirements:**
1. No block overlap (except species inside compartments)
2. Labels visible — not overlapping other blocks
3. Horizontal/vertical alignment for same-tier compartments
4. Inter-compartment reactions outside both compartments (in the gap)
5. No connection lines through unrelated blocks
6. 50 px minimum reaction-to-species distance

**Preferred placement:**
7. Elimination/degradation reactions inside their parent compartment (communicates the process occurs locally, not across a boundary)

### Flow direction by model type

| Model Type | Flow Direction |
|------------|----------------|
| PKPD | PD upper-left, PK lower-right |
| Metabolic | Top-to-bottom |
| PBPK | Circulation-based columns |
| Simple PK | Left-to-right or diagonal |

## References
Load on demand for detailed guidance:
- `references/layout-strategy-guidance.md` — strategy selection, pre-build checklist, 7 recipes
- `references/pbpk-layout-guidance.md` — PBPK circulation and ACAT chain layouts
- `references/evacuation-procedure-guidance.md` — 5-phase rearrangement for existing models
- `references/api-cheatsheet-guidance.md` — full simbio.diagram API (getBlock, setBlock, lines, clones)
- `references/app-lifecycle-guidance.md` — switching models, Analyzer coordination
- `references/diagram-styling-guidance.md` — colors, fonts, cloning mechanics
- `references/pk-library-guidance.md` — PKModelDesign for standard PK models

----

Copyright 2026 The MathWorks, Inc.

----