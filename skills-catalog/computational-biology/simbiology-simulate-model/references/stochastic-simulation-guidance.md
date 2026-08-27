# Stochastic Simulation Guidance

Detailed patterns for SSA ensemble simulation, distribution analysis,
and gene circuit modeling.

---

## Ensemble Plotting

```matlab
nRuns = 200;
allResults = cell(nRuns, 1);
cs = getconfigset(model, 'active');
cs.SolverType = 'ssa';
cs.StopTime = 100;

for i = 1:nRuns
    allResults{i} = sbiosimulate(model);
end

% Plot all trajectories with transparency
figure; hold on;
for i = 1:nRuns
    [t, x, names] = getdata(allResults{i});
    plot(t, x(:,1), 'Color', [0.7 0.7 0.7 0.3]);
end
hold off;
xlabel('Time'); ylabel('Amount');
title('SSA Ensemble (200 runs)');
```

---

## Distribution Analysis at Fixed Timepoint

```matlab
targetTime = 50;
proteinAtT = zeros(nRuns, 1);
for i = 1:nRuns
    [t, x, names] = getdata(allResults{i});
    idx = find(t >= targetTime, 1);
    proteinAtT(i) = x(idx, 3);  % adjust column for species of interest
end

figure;
histogram(proteinAtT, 20);
xlabel('Protein count at t=50');
ylabel('Frequency');
title(sprintf('Distribution (n=%d), mean=%.1f, CV=%.2f', ...
    nRuns, mean(proteinAtT), std(proteinAtT)/mean(proteinAtT)));
```

---

## Constraints for SSA

- **All reactions must use MassAction** — custom rate expressions are
  not supported by the SSA solver.
- **Species amounts should be non-negative integers** — SSA operates on
  discrete molecule counts.
- **Catalytic reactions:** Write `mRNA -> mRNA + Protein` (catalyst
  appears on both sides) rather than custom rate `k_tln * mRNA`.
- **No fractional stoichiometry** — all coefficients must be integers.

---

## Toggle Switch Example

A classic bistable gene circuit:

```matlab
model = sbiomodel('ToggleSwitch');
comp = addcompartment(model, 'cell');
addspecies(comp, 'ProteinA', 50);
addspecies(comp, 'ProteinB', 0);
addparameter(model, 'k_prodA', 0.5);
addparameter(model, 'k_prodB', 0.5);
addparameter(model, 'k_degA', 0.01);
addparameter(model, 'k_degB', 0.01);
addparameter(model, 'k_repA', 0.001);  % B represses A
addparameter(model, 'k_repB', 0.001);  % A represses B

% Production (constitutive)
rx1 = addreaction(model, 'null -> ProteinA');
kl1 = addkineticlaw(rx1, 'MassAction'); kl1.ParameterVariableNames = {'k_prodA'};
rx2 = addreaction(model, 'null -> ProteinB');
kl2 = addkineticlaw(rx2, 'MassAction'); kl2.ParameterVariableNames = {'k_prodB'};

% Degradation
rx3 = addreaction(model, 'ProteinA -> null');
kl3 = addkineticlaw(rx3, 'MassAction'); kl3.ParameterVariableNames = {'k_degA'};
rx4 = addreaction(model, 'ProteinB -> null');
kl4 = addkineticlaw(rx4, 'MassAction'); kl4.ParameterVariableNames = {'k_degB'};

% Mutual repression (A degrades B, B degrades A)
rx5 = addreaction(model, 'ProteinA + ProteinB -> ProteinA');
kl5 = addkineticlaw(rx5, 'MassAction'); kl5.ParameterVariableNames = {'k_repA'};
rx6 = addreaction(model, 'ProteinA + ProteinB -> ProteinB');
kl6 = addkineticlaw(rx6, 'MassAction'); kl6.ParameterVariableNames = {'k_repB'};
```

---

## When to Choose SSA vs ODE

| Factor | Use ODE | Use SSA |
|--------|---------|---------|
| Molecule counts | > 100 | < 100 |
| Noise matters | No | Yes |
| Speed required | Fast (1 run) | Slow (need many runs) |
| Kinetic laws | Any | MassAction only |
| Typical domain | PK/PD, systems bio | Gene circuits, single-cell |


----

Copyright 2026 The MathWorks, Inc.

----
