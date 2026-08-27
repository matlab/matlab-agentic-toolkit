# Standard PK Models with PKModelDesign

Use `PKModelDesign` when the user asks for a standard PK model (1- or
2-compartment with common dosing and elimination). This produces models
consistent with SimBiology's PK library — correct parameterization,
naming conventions, and rules.

Use manual construction (`addcompartment`/`addspecies`/`addreaction`)
for custom mechanisms (receptor-ligand, QSP, gene circuits, PBPK, etc.).

---

## When to Use PKModelDesign

- "Create a one-compartment PK model"
- "Build a 2-compartment model with first-order absorption"
- "Make a PK model with bolus dosing and linear clearance"
- Any request that maps directly to a standard compartmental PK structure

## Basic Pattern

```matlab
pkmd = PKModelDesign;
pkmd.addCompartment('Central', ...
    'DosingType', 'Bolus', ...
    'EliminationType', 'Linear-Clearance', ...
    'HasResponseVariable', true);
[model, modelMap] = pkmd.construct;
```

## Options

### DosingType

| Value | Effect | Dosed species |
|-------|--------|---------------|
| `'Bolus'` | Direct dose into central | `Drug_Central` |
| `'FirstOrder'` | Absorption from depot (ka) | `Dose_Central` |
| `'ZeroOrder'` | Zero-order input (duration Tk0) | `Drug_Central` |
| `'Infusion'` | IV infusion | `Drug_Central` |
| `''` | No dosing in this compartment | — |

### EliminationType

| Value | Parameters | Kinetics |
|-------|-----------|----------|
| `'Linear-Clearance'` | `Cl_Central`, `ke_Central` | MassAction; rule: `ke_Central = Cl_Central / Central` |
| `'Linear'` | `ke_Central` | MassAction (micro-constant only) |
| `'Enzymatic'` | `Vm_Central`, `Km_Central` | Henri-Michaelis-Menten |
| `''` | — | No elimination in this compartment |

### Other options

| Option | Effect |
|--------|--------|
| `'HasResponseVariable', true` | Marks drug concentration as observed output |
| `'HasLag', true` | Adds `TLag_Central` lag-time parameter |

## Common Models

### 1-compartment, bolus, linear clearance

```matlab
pkmd = PKModelDesign;
pkmd.addCompartment('Central', 'DosingType', 'Bolus', ...
    'EliminationType', 'Linear-Clearance', 'HasResponseVariable', true);
[model, modelMap] = pkmd.construct;
```

Produces:
- Species: `Dose_Central`, `Drug_Central`
- Parameters: `ka_Central`, `Cl_Central`, `ke_Central`
- Reactions: `Dose_Central -> Drug_Central` (MassAction), `Drug_Central -> null` (MassAction)
- Rules: `ke_Central = Cl_Central / Central`
- Dose target: `Drug_Central`

### 1-compartment, first-order absorption, linear clearance

```matlab
pkmd = PKModelDesign;
pkmd.addCompartment('Central', 'DosingType', 'FirstOrder', ...
    'EliminationType', 'Linear-Clearance', 'HasResponseVariable', true);
[model, modelMap] = pkmd.construct;
```

Same as above but dose target is `Dose_Central` (absorption compartment).
Absorption rate `ka_Central` drives `Dose_Central -> Drug_Central`.

### 2-compartment, bolus, linear clearance

```matlab
pkmd = PKModelDesign;
pkmd.addCompartment('Central', 'DosingType', 'Bolus', ...
    'EliminationType', 'Linear-Clearance', 'HasResponseVariable', true);
pkmd.addCompartment('Peripheral');
[model, modelMap] = pkmd.construct;
```

Adds:
- Species: `Dose_Peripheral`, `Drug_Peripheral`
- Parameters: `Q12`, `k12`, `k21`
- Reactions: `Central.Drug_Central <-> Peripheral.Drug_Peripheral`
- Rules: `k12 = Q12 / Central`, `k21 = Q12 / Peripheral`

### 1-compartment, bolus, Michaelis-Menten elimination

```matlab
pkmd = PKModelDesign;
pkmd.addCompartment('Central', 'DosingType', 'Bolus', ...
    'EliminationType', 'Enzymatic', 'HasResponseVariable', true);
[model, modelMap] = pkmd.construct;
```

Produces:
- Parameters: `Vm_Central`, `Km_Central`
- Elimination reaction uses `Henri-Michaelis-Menten` kinetic law

## modelMap Output

`pkmd.construct` returns a `PKModelMap` with fitting-relevant info:

| Field | Content |
|-------|---------|
| `Dosed` | Cell array of species that receive doses |
| `DosingType` | Cell array of dosing mechanisms |
| `Estimated` | Cell array of parameters/compartments to estimate |
| `Observed` | Cell array of response species |
| `ZeroOrderDurationParameter` | Duration param for zero-order dosing |
| `LagParameter` | Lag-time parameter names |

## Naming Conventions

`PKModelDesign` uses consistent naming that differs from ad-hoc models:

| Element | PK Library Name | Common ad-hoc names (avoid) |
|---------|----------------|----------------------------|
| Drug species | `Drug_Central` | `Drug`, `Cp`, `C` |
| Absorption species | `Dose_Central` | `Depot`, `GI`, `Gut` |
| Clearance | `Cl_Central` | `CL`, `Cl` |
| Elimination rate | `ke_Central` | `ke`, `kel`, `k_el` |
| Absorption rate | `ka_Central` | `ka`, `k_abs` |
| Inter-compartmental clearance | `Q12` | `Q`, `CLD` |
| Transfer rates | `k12`, `k21` | `kcp`, `kpc` |
| Volume | Compartment `Value` (`Central`) | `Vd`, `V1`, `Vc` |

## Post-Construction Customization

After `construct`, modify the model as needed:

```matlab
[model, modelMap] = pkmd.construct;

% Rename model
model.Name = 'PK_1comp_BolusIV';

% Set parameter values
p = sbioselect(model, 'Type', 'parameter', 'Name', 'Cl_Central');
p.Value = 5;  % L/hr

% Set compartment volume
comp = model.Compartments(1);
comp.Value = 50;  % L

% Add units
p.Units = 'liter/hour';
comp.Units = 'liter';
```


----

Copyright 2026 The MathWorks, Inc.

----
