# NCA Analysis Guidance

Detailed patterns for non-compartmental analysis including IV infusion,
multi-subject grouping, metrics interpretation, and troubleshooting.

---

## Full NCA Workflow (Extravascular)

```matlab
% 1. Prepare concentration-time data
[t, x, names] = sbiosimulate(model);
drugIdx = find(strcmp(names, 'Drug'));
Vd = sbioselect(model, 'Type', 'parameter', 'Name', 'Vd');
conc = x(:, drugIdx) ./ Vd.Value;

% 2. Create EVDose column (NaN except at dose times)
evDose = NaN(size(t));
evDose(1) = 100;  % dose amount at t=0

% 3. Build data table
data = table(t, conc, evDose, 'VariableNames', {'Time','Concentration','EVDose'});

% 4. Configure options
opt = sbioncaoptions;
opt.concentrationColumnName = 'Concentration';
opt.timeColumnName = 'Time';
opt.EVDoseColumnName = 'EVDose';
opt.AdministrationRoute = 'ExtraVascular';

% 5. Run NCA
ncaResults = sbionca(data, opt);
```

---

## IV Bolus Administration

```matlab
ivDose = NaN(size(t));
ivDose(1) = 500;  % mg

data = table(t, conc, ivDose, 'VariableNames', {'Time','Concentration','IVDose'});

opt = sbioncaoptions;
opt.concentrationColumnName = 'Concentration';
opt.timeColumnName = 'Time';
opt.IVDoseColumnName = 'IVDose';
opt.AdministrationRoute = 'IVBolus';
ncaResults = sbionca(data, opt);
```

---

## IV Infusion Administration

IV infusion requires both dose and infusion rate columns:

```matlab
ivDose = NaN(size(t));
ivDose(1) = 500;  % total dose (mg)
infRate = NaN(size(t));
infRate(1) = 500;  % mg/hr (500mg over 1 hour)

data = table(t, conc, ivDose, infRate, ...
    'VariableNames', {'Time','Concentration','IVDose','InfusionRate'});

opt = sbioncaoptions;
opt.concentrationColumnName = 'Concentration';
opt.timeColumnName = 'Time';
opt.IVDoseColumnName = 'IVDose';
opt.infusionRateColumnName = 'InfusionRate';  % lowercase 'i'!
opt.AdministrationRoute = 'IVInfusion';
ncaResults = sbionca(data, opt);
```

> **Important:** `infusionRateColumnName` starts with lowercase 'i'.
> The property is case-sensitive.

---

## Multi-Subject NCA

```matlab
% Data with SubjectID column
data = groupedData(readtable('pk_data.csv'));
data.Properties.IndependentVariableName = 'Time';
data.Properties.GroupVariableName = 'SubjectID';

opt = sbioncaoptions;
opt.concentrationColumnName = 'Concentration';
opt.timeColumnName = 'Time';
opt.EVDoseColumnName = 'EVDose';
opt.AdministrationRoute = 'ExtraVascular';
opt.groupColumnName = 'SubjectID';

ncaResults = sbionca(data, opt);
% Returns one row per subject with all metrics
```

---

## NCA Metrics Reference

| Metric | Description | Formula |
|--------|-------------|---------|
| `AUC_0_last` | Area under curve, 0 to last observed time | Linear trapezoidal |
| `AUC_infinity` | AUC extrapolated to infinity | AUC_0_last + Clast/lambda_z |
| `C_max` | Maximum observed concentration | max(C) |
| `T_max` | Time of Cmax | t at max(C) |
| `T_half` | Terminal elimination half-life | ln(2) / lambda_z |
| `lambda_z` | Terminal rate constant | Slope of log-linear terminal phase |
| `CL` | Clearance | Dose / AUC_infinity |
| `CL_F` | Apparent clearance (extravascular) | Dose / AUC_infinity |
| `V_z` | Volume of distribution (terminal) | CL / lambda_z |
| `V_ss` | Volume at steady state | MRT * CL |
| `MRT` | Mean residence time | AUMC / AUC |
| `AUMC` | Area under first moment curve | integral(t * C dt) |

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| NaN for AUC_infinity | Cannot determine terminal slope | Ensure enough data points in terminal phase |
| Negative CL | Wrong AdministrationRoute | Match route to actual dosing |
| Error on column name | Case mismatch | Use exact camelCase: `concentrationColumnName` |
| EVDose ignored | Used 0 instead of NaN for non-dose rows | Only dose rows get numeric values; all others NaN |
| Wrong Vz for IV infusion | Missing infusionRateColumnName | Must specify rate for correct calculation |


----

Copyright 2026 The MathWorks, Inc.

----
