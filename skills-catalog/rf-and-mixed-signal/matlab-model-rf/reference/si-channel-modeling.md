# Signal Integrity Channel Modeling

Build SI channel models by cascading measured S-parameter blocks (`nport`), lossy frequency-dependent transmission lines (`txlineWRLGC`, `txlineWtable`), and lumped parasitic elements (resistor, capacitor, inductor) in RF Toolbox `circuit` objects. Extract insertion loss, return loss, and crosstalk, then bridge to time-domain analysis via rational fitting.

## Lumped Parasitic Elements

Primitive R/L/C elements model vias, bond wires, pad capacitance, and termination resistors in SI channels. Each has terminals `p` (positive) and `n` (negative):

```matlab
r = resistor(50, 'Rterm');        % 50 Ohm termination
c = capacitor(0.1e-12, 'Cvia');   % via pad capacitance
l = inductor(0.5e-9, 'Lvia');     % via barrel inductance
```

**Gotcha:** Primitive constructors are positional only: `resistor(100, 'R1')`. Name-value syntax like `resistor('Resistance', 100)` is not supported.

**Handle semantics:** Changing a property after adding to a circuit immediately affects the circuit -- no need to re-add.

### Via Model (Lumped Subcircuit)

```matlab
via = circuit('Via');
add(via, [1 2], inductor(0.5e-9, 'Lvia'));
add(via, [2 0], capacitor(0.1e-12, 'Cvia'));
setports(via, [1 0], [2 0]);
```

### ESD/Decoupling Parasitic

```matlab
esd = circuit('ESD');
add(esd, [1 0], capacitor(0.3e-12, 'Cesd'));
add(esd, [1 0], resistor(1e6, 'Resd'));    % parallel RC to ground
setports(esd, [1 0]);                       % 1-port shunt element
```

## nport Elements in Circuit

Embed measured or simulated S-parameter data (Touchstone files) as circuit elements. This is the primary building block for SI channel models -- connectors, packages, PCB segments, and fixtures are all characterized as S-parameter data.

### 2-Port nport

```matlab
np = nport('connector.s2p');
np.Name = 'ConnIn';

ckt = circuit('Simple');
add(ckt, [1 2 0 0], np);               % 4 nodes: p1+->1, p2+->2, p1-->0, p2-->0
add(ckt, [2 3], inductor(0.5e-9, 'L1'));
setports(ckt, [1 0], [3 0]);
```

A 2-port nport has 4 terminals (`p1+`, `p2+`, `p1-`, `p2-`), so `add` takes a 4-element node vector.

### 4-Port nport

A 4-port nport has 8 terminals. Two node-mapping forms:

```matlab
np4 = nport('device.s4p');
np4.Name = 'Dev4P';

% Explicit 8-node form: [p1+ p2+ p3+ p4+ p1- p2- p3- p4-]
add(ckt, [1 2 3 4 0 0 0 0], np4);     % all negatives grounded

% Shorthand N-node form: negatives implicitly grounded
add(ckt, [1 2 3 4], np4);              % same result
```

### Port Selection and Termination

Use `setports` on the **circuit** to select which nport ports become external ports. Unexposed ports are left **open-circuited** -- add explicit resistors for proper termination:

```matlab
s4 = sparameters('device.s4p');
Z0 = s4.Impedance;
np4 = nport(s4);
np4.Name = 'Dev4P';

ckt = circuit('PortSelect');
add(ckt, [1 2 3 4 0 0 0 0], np4);

% Terminate unused ports 2 and 4 with matched loads
add(ckt, [2 0], resistor(Z0, 'Term2'));
add(ckt, [4 0], resistor(Z0, 'Term4'));

% Expose only ports 1 and 3 as a 2-port network
setports(ckt, [1 0], [3 0]);

freq = s4.Frequencies;
s = sparameters(ckt, freq);    % S21 here equals S31 of original 4-port
```

**Gotcha:** Without explicit termination on unused ports, extracted S-parameters will differ from the original -- open-circuit reflections alter the network response.

### Differential Port Mapping

For differential signaling, use the full 2N-node form with non-grounded negative terminals:

```matlab
np4 = nport('diffpair.s4p');
np4.Name = 'DiffChan';

ckt = circuit('DiffAnalysis');
add(ckt, [1 2 3 4 5 6 7 8], np4);  % non-grounded negatives
setports(ckt, [1 5], [3 7]);        % differential: (p1+,p1-) -> (p3+,p3-)
```

**Critical: every negative terminal must have a current path.** Each nport port requires current to flow in through `pi+` and return through `pi-`. If a negative terminal is mapped to a node that is not connected to anything (not grounded, not used as a port reference, not connected to another element), the current path is broken and the nport produces zero transmission (~-260 dB). There are three valid approaches:

1. **Ground all negatives** (simplest): `add(ckt, [1 2 3 4 0 0 0 0], np)` — all returns share node 0
2. **Use negatives as port references**: `setports(ckt, [1 5], [3 7])` — the port definition itself closes the loop through `pi-`
3. **Connect negatives to other elements**: tie them to resistors, other nport terminals, etc.

Never leave negative terminals on isolated floating nodes.

### Circuit Differential Ports vs s2sdd

**Decision rule:** Use `s2sdd` to extract the true differential-mode response from a multi-port S-parameter measurement. Use `setports` with differential node pairs only when ports physically correspond to differential terminals (balanced amplifier with + and - pins).

The circuit approach (`setports` with differential node pairs) and the `s2sdd` function are **not equivalent**:

- **`setports(ckt, [1 3], [2 4])`** with grounded negatives creates a physical voltage measurement between two single-ended nodes that each have their own ground return. This is effectively a series combination — it gives results like 2× the single-ended loss.
- **`s2sdd`** performs a mathematical modal decomposition of the full S-matrix. It algebraically separates differential and common modes without requiring a physical current path.

For extracting the true differential-mode response from a 4-port file, **use `s2sdd` on the extracted S-parameters** rather than trying to replicate it with differential `setports`. The circuit `setports` differential form is appropriate when ports physically correspond to differential terminals (e.g., a balanced amplifier with explicit + and - pins).

After extracting `sparameters`, convert to mixed-mode for differential/common-mode analysis:

```matlab
s = sparameters(ckt, freq);
sdd = s2sdd(s.Parameters, 2);   % 2x2xK differential array
% Wrap in sparameters with doubled impedance (differential Z0 = 2x single-ended)
sDiff = sparameters(sdd, s.Frequencies, 2*s.Impedance);
```

### Reusing nport Data in Multiple Circuits

When building multiple circuits from the same S-parameter data (e.g., comparing broken vs. fixed topology, or using the same connector at input and output), **create a fresh `nport()` for each circuit** or use `clone()`:

```matlab
% WRONG: reusing the same nport object in two circuits
np = nport('device.s4p', 'Dev');
add(ckt1, [1 2 3 4 0 0 0 0], np);
add(ckt2, [1 2 3 4 0 0 0 0], np);   % ERROR: already belongs to ckt1

% CORRECT: clone or create fresh
add(ckt2, [1 2 3 4 0 0 0 0], clone(np));
% or
np2 = nport('device.s4p', 'Dev2');
add(ckt2, [1 2 3 4 0 0 0 0], np2);
```

### Multi-Port Channel Extraction

For a 4-port channel (e.g., near-end and far-end crosstalk):

```matlab
np4 = nport('coupled_traces.s4p');
np4.Name = 'Traces';

ckt = circuit('CoupledChannel');
add(ckt, [1 2 3 4 0 0 0 0], np4);
setports(ckt, [1 0], [2 0], [3 0], [4 0]);   % full 4-port extraction

s = sparameters(ckt, freq);
% S21 = through, S31 = NEXT, S41 = FEXT (depending on port assignment)
```

## Frequency-Dependent Transmission Lines

`txlineWRLGC` and `txlineWtable` model lossy transmission lines with frequency-dependent parameters. Both are 2-port/4-terminal elements that work in `circuit` and `rfbudget`.

### txlineWRLGC -- W-Element RLGC Model

Models frequency-dependent loss using an analytic formula (Djordjevic-Sarkar wideband model):

```matlab
tw = txlineWRLGC;
tw.Lo = 350e-9;       % inductance per unit length (H/m)
tw.Co = 130e-12;      % capacitance per unit length (F/m)
tw.Ro = 2.0;          % DC resistance (Ohm/m)
tw.Rs = 5e-4;         % skin-effect resistance coefficient (Ohm/m/sqrt(Hz))
tw.Go = 0;            % DC conductance (S/m)
tw.Gd = 1e-11;        % dielectric loss conductance (S/m/Hz)
tw.LineLength = 0.05;  tw.Name = 'PCBTrace';  % 50 mm
```

| Property | Default | Description |
|----------|---------|-------------|
| `Lo` | 1e-9 | Inductance per unit length (H/m) |
| `Co` | 4e-13 | Capacitance per unit length (F/m) |
| `Ro` | 0 | DC series resistance (Ohm/m) |
| `Rs` | 0 | Skin-effect resistance coefficient |
| `Go` | 0 | DC shunt conductance (S/m) |
| `Gd` | 0 | Dielectric loss conductance |
| `DielectricFrequency` | 1e9 | Reference frequency for Gd (Hz) |
| `Nline` | 1 | Number of signal conductors |
| `LineLength` | 1 | Physical length (m) |
| `StubMode` | `'NotAStub'` | `'NotAStub'`, `'Series'`, or `'Shunt'` |
| `Termination` | `'NotApplicable'` | `'NotApplicable'`, `'Short'`, or `'Open'` |

**Typical parameter ranges for common PCB technologies (50-Ohm single-ended):**

| Technology | Lo (nH/m) | Co (pF/m) | Ro (Ohm/m) | Rs | Gd (S/m/Hz) |
|------------|-----------|-----------|------------|-----|-------------|
| FR4 microstrip (outer layer) | 300-400 | 100-140 | 1-5 | 3e-4 to 8e-4 | 5e-12 to 2e-11 |
| FR4 stripline (inner layer) | 350-450 | 120-160 | 2-8 | 4e-4 to 1e-3 | 1e-11 to 5e-11 |
| Low-loss (Megtron6, Rogers) | 300-400 | 100-140 | 1-4 | 3e-4 to 6e-4 | 1e-12 to 5e-12 |

These are approximate starting points. For accurate models, extract RLGC parameters from a 2D field solver (e.g., Ansys Q2D, Cadence Sigrity) matched to your actual stackup geometry.

### txlineWtable -- Table-Based Frequency-Dependent Model

Specifies R, L, G, C at discrete frequency points with interpolation. Use when you have extracted or measured per-unit-length parameters at specific frequencies:

```matlab
wt = txlineWtable;
fpts = [1e8 1e9 10e9];
wt.R = [0.5 1.0 2.0];   wt.Rfreq = fpts;   % Ohm/m
wt.L = [260 250 248]*1e-9; wt.Lfreq = fpts; % H/m
wt.C = [100 100 99]*1e-12; wt.Cfreq = fpts; % F/m
wt.G = [0 1e-4 1e-3];   wt.Gfreq = fpts;   % S/m
wt.Lhf = 248e-9;  wt.Chf = 99e-12;         % HF asymptotes
wt.LineLength = 0.1;  wt.Name = 'MeasuredTrace';
```

### When to Use Each

| Model | Use Case | Properties |
|-------|----------|------------|
| `txlineRLCGLine` | Constant RLCG -- quick estimates, frequency-independent loss | `R`, `L`, `C`, `G` |
| `txlineWRLGC` | Analytic frequency-dependent loss -- PCB traces, cables with skin effect | `Lo`, `Co`, `Ro`, `Rs`, `Go`, `Gd` |
| `txlineWtable` | Measured/extracted RLCG data at discrete frequencies | `R`, `L`, `C`, `G` + `Rfreq`, `Lfreq`, `Cfreq`, `Gfreq` |

**Do NOT confuse property names across types:** `txlineRLCGLine` uses simple `R, L, C, G`; `txlineWRLGC` uses `Lo, Co, Ro, Rs, Go, Gd`. Setting `R` on a `txlineWRLGC` or `Lo` on a `txlineRLCGLine` errors.

### Using in Circuit

All transmission lines have 4 terminals (`p1+`, `p2+`, `p1-`, `p2-`):

```matlab
ckt = circuit('TraceLoss');
add(ckt, [1 2 0 0], tw);     % 4-node mapping
setports(ckt, [1 0], [2 0]);
s = sparameters(ckt, linspace(1e8, 20e9, 500));
```

## Mixed Topology Channel Models

Combine lumped elements, nport S-parameter blocks, and transmission lines in a single circuit -- the core pattern for SI channel modeling:

### Connector-Trace-Via-Connector Channel

```matlab
np_conn = nport('connector.s2p');
np_conn.Name = 'ConnIn';

trace = txlineWRLGC(Name='PCBTrace');
trace.Lo = 350e-9;  trace.Co = 130e-12;
trace.Ro = 2.0;     trace.Rs = 5e-4;
trace.Gd = 1e-11;   trace.LineLength = 0.05;

via = circuit('Via');
add(via, [1 2], inductor(0.5e-9, 'Lvia'));
add(via, [2 0], capacitor(0.1e-12, 'Cvia'));
setports(via, [1 0], [2 0]);

ckt = circuit('Channel');
add(ckt, [1 2 0 0], np_conn);          % input connector
add(ckt, [2 3 0 0], trace);            % PCB trace
add(ckt, [3 4 0 0], via);              % via transition
add(ckt, [4 5 0 0], clone(np_conn));   % output connector (cloned)
setports(ckt, [1 0], [5 0]);

freq = linspace(1e8, 10e9, 500);
s = sparameters(ckt, freq);

figure; tiledlayout(1, 2);
nexttile; rfplot(s, 2, 1); title('S21 -- Insertion Loss');
nexttile; rfplot(s, 1, 1); title('S11 -- Return Loss');
```

### Differential Channel with Package

```matlab
sPkg = sparameters('package.s4p');
Z0 = sPkg.Impedance;
pkg = nport(sPkg);   pkg.Name = 'Package';
chan = nport('diffpair.s4p'); chan.Name = 'DiffTrace';

ckt = circuit('DiffChannel');
add(ckt, [1 2 3 4 0 0 0 0], pkg);
add(ckt, [2 4 5 6 0 0 0 0], chan);     % ports 2,4 of pkg feed into channel

% Terminate unused package port 3 (near-end crosstalk victim)
add(ckt, [3 0], resistor(Z0, 'TermNEXT'));

% Expose: pkg port 1 -> channel port output
setports(ckt, [1 0], [5 0], [6 0]);    % 3-port: input, thru, FEXT

s = sparameters(ckt, sPkg.Frequencies);
```

## Multi-Path Analysis (Clone + Different Ports)

The `clone()` + different `setports()` pattern lets you analyze multiple signal paths through the same topology without rebuilding:

```matlab
% Build an RC interconnect with crosstalk coupling
base = circuit('Interconnect');
add(base, [1 2], resistor(50, 'R1'));
add(base, [2 0], capacitor(1e-12, 'C1'));
add(base, [2 3], resistor(50, 'R2'));
add(base, [3 0], capacitor(1e-12, 'C2'));
add(base, [2 4], resistor(100, 'Rxtalk'));
add(base, [4 0], capacitor(2e-12, 'Cxtalk'));

% Main signal path
cktMain = clone(base);
setports(cktMain, [1 0], [3 0]);

% Crosstalk path
cktXtalk = clone(base);
setports(cktXtalk, [1 0], [4 0]);

freq = linspace(1e6, 10e9, 500);
sMain = sparameters(cktMain, freq);
sXtalk = sparameters(cktXtalk, freq);
```

## Time-Domain Bridge

After extracting S-parameters, fit with `rational` for TDR/impulse:
```matlab
s21 = rfparam(s, 2, 1);
[fit, errdb] = rational(s.Frequencies, s21);
[yImp, tImp] = impulse(fit, 1e-12, 5000);
```

See `reference/rational-fitting.md` for complete TDR recipes and `reference/time-domain-analysis.md` for end-to-end SI time-domain examples.

## Result Extraction Patterns

After extracting S-parameters from a circuit, use these patterns to get numeric values for plotting or analysis:

```matlab
s = sparameters(ckt, freq);

% Pattern 1a: rfplot (simplest) -- plots S-parameter directly
rfplot(s, 2, 1);                  % magnitude in dB vs frequency

% Pattern 1b: rfparam -- returns Kx1 vector, ready for custom plotting
s21 = rfparam(s, 2, 1);          % Kx1 complex vector
plot(freq/1e9, 20*log10(abs(s21)));

% Pattern 2: s.Parameters -- returns 1x1xK, MUST squeeze before plotting
s21_raw = s.Parameters(2,1,:);   % 1x1xK -- CANNOT plot directly
s21 = squeeze(s.Parameters(2,1,:));  % Kx1 after squeeze

% Get value at a specific frequency index
idx = 250;
val_dB = 20*log10(abs(s21(idx)));

% rfparam does NOT accept a frequency index argument:
%   rfparam(s, 2, 1, idx)  -- ERROR: "Too many input arguments"
%   rfparam(s, 2, 1)       -- CORRECT: returns full vector, then index it
```

**Key rule:** `rfparam(s, i, j)` takes exactly 3 arguments (object, row, col). Never pass a 4th argument for frequency index — index the result vector instead.

## Gotchas

1. **nport node count: min N, max 2N** -- an N-port nport needs at least N nodes (negatives implicitly grounded) and at most 2N nodes. Fewer than N errors. For clarity, prefer the explicit 2N form with `0` for grounded negatives.
2. **Unexposed nport ports are open-circuited** -- when using `setports` to expose only some ports of a multi-port nport, unused ports are left open. Add explicit `resistor(Z0)` terminations (where Z0 matches the S-parameter reference impedance, e.g., `s.Impedance`) for correct S-parameter extraction.
3. **`nport.Input`/`Output` are for rfbudget only** -- these numeric port indices select the through-path for `rfbudget`. In `circuit`, use node mapping and `setports` instead.
4. **`LineLength` not `Length`** -- all transmission line objects use `LineLength` for physical length. Using `Length` errors.
5. **txlineWtable needs multi-point RLCG data in circuit** -- scalar R/L/G/C values (single frequency point) error with "number of data points should be equal to the number of frequency points" when extracting `sparameters` from a circuit. Provide at least 2 frequency points in each RLCG table.
6. **txlineWRLGC/txlineWtable constructors don't accept `StubMode`/`Termination`** -- set these as properties after construction. Only RLGC, length, and name parameters are accepted in the constructor.
7. **txlineWRLGC `Nline>1` with matrix Lo/Co** -- multi-line coupled extraction has a sparameters bug in R2026a. Workaround: extract each line individually.
8. **Elements cannot be reused without cloning** -- an element can only belong to one circuit or rfbudget at a time. Use `clone()` to create independent copies. Without cloning, adding the same element a second time errors or silently produces incorrect results.
9. **`setports`/`setterminals` can only be called once** -- plan your topology before defining terminals.
10. **Primitive constructors are positional** -- `resistor(100, 'R1')`, not `resistor('Resistance', 100)`.
11. **Element Name must be a valid MATLAB identifier** -- no spaces, no leading digits.
12. **Floating negative terminals produce ~-260 dB transmission** -- if any nport negative terminal is mapped to a node with no current path (not grounded, not a port reference, not connected to another element), the nport produces effectively zero transmission. Always use one of the three valid approaches: ground all negatives, use them as port references in `setports`, or connect them to other elements.
13. **Do not include DC (0 Hz) in frequency vectors for transmission line models** -- `linspace(0, fmax, N)` causes singularities in txlineWRLGC and txlineWtable at f=0 (division by zero in RLGC calculations). Start from a small positive frequency: `linspace(fmax/N, fmax, N)` or use `logspace`.
14. **`rfwrite` blocks on existing files** -- Always pass `'ForceOverwrite', true` to `rfwrite`. Without it, MATLAB opens an interactive "Overwrite?" dialog that blocks unattended execution.

## Conventions

- Use `tiledlayout`/`nexttile` for multi-panel channel analysis plots
- Always label axes with units (dB, GHz, ns) and include figure titles
- Name elements descriptively for readable topology: `'ConnIn'`, `'PCBTrace'`, `'Lvia'`, `'Cpad'`
- Use `clone()` liberally -- it deep-copies all nested elements and subcircuits
- Plot both S21 (insertion loss) and S11 (return loss) for channel characterization
- For differential channels, convert to mixed-mode S-parameters with `s2sdd` after extraction

----

Copyright 2026 The MathWorks, Inc.

----
