# General-Purpose RF Circuit Composition

Build RF circuits from primitive R/L/C elements, active components (amplifier, modulator, mixerIMT), and `nport` S-parameter blocks -- all wired between nodes in a SPICE-like netlist. Extract S-parameters, embed subcircuits hierarchically, and convert lumped designs to distributed implementations.

## Workflow

1. **Create circuit** -- `circuit('Name')`
2. **Add elements** -- Wire to nodes with `add`
3. **Define ports** -- `setports` for S-parameter extraction or `setterminals` for subcircuit embedding
4. **Analyze** -- `sparameters(ckt, freq)`

## Primitive Elements (2-Terminal)

Each has terminals `p` (positive) and `n` (negative). Connect to any two circuit nodes.

```matlab
r = resistor(100, 'R1');          % positional: value, name
c = capacitor(1e-12, 'C1');
l = inductor(10e-9, 'L1');
```

**Gotcha:** Positional constructor ONLY. `resistor('Resistance', 100)` errors.

Properties: `Resistance`, `Capacitance`, `Inductance`, `Name`, `Terminals`.

**Handle semantics:** Changing a property (e.g., `r.Resistance = 200`) after adding to a circuit immediately affects the circuit -- no need to re-add.

### mutualInductor (4-Terminal, R2023a+)

```matlab
mi = mutualInductor('Name', 'Xfmr', 'Inductance1', 10e-9, ...
    'Inductance2', 10e-9, 'CouplingCoefficient', 0.95);
```

Terminals: `p1+`, `p2+`, `p1-`, `p2-`. Name-value only. Coupling parameter is `CouplingCoefficient`, NOT `MutualInductance`.

### rfdivider (6-Terminal / 3-Port, R2023a+)

Wilkinson power divider (built-in element):

```matlab
d = rfdivider('Name', 'Split1', 'Impedance', 50);
```

Terminals: `p1+`, `p2+`, `p3+`, `p1-`, `p2-`, `p3-`. Add to a circuit with 6 nodes.

Alternatively, build a Wilkinson from primitives -- use `resistor()` for the isolation resistor (not `seriesRLC` which is an rfbudget element):

```matlab
ckt = circuit('Wilkinson');
tl1 = txlineDelayLossless('Z0', 70.7, 'TimeDelay', 104e-12, 'Name', 'TL1');
add(ckt, [1 2 0 0], tl1);                        % input -> output1
add(ckt, [1 3 0 0], clone(tl1));                  % input -> output2
add(ckt, [2 3], resistor(100, 'Riso'));           % isolation resistor between outputs
setports(ckt, [1 0], [2 0], [3 0]);              % 3-port
```

## Active Elements in Circuit

`amplifier`, `modulator`, and `mixerIMT` are 2-port (4-terminal) elements that work in `circuit` via `add()`. This lets you build complete RF front-end topologies with active and passive elements in a single netlist.

### amplifier in Circuit

```matlab
lna = amplifier('Gain', 15, 'NF', 2, 'OIP3', 35, 'Name', 'LNA');

ckt = circuit('RxFrontEnd');
add(ckt, [1 2], capacitor(1e-12, 'DCBlk'));   % DC block
add(ckt, [2 3 0 0], lna);                      % LNA: 4-node mapping
add(ckt, [3 4], inductor(2.7e-9, 'Lmatch'));   % matching inductor
setports(ckt, [1 0], [4 0]);

freq = linspace(1e9, 6e9, 500);
s = sparameters(ckt, freq);
```

### modulator in Circuit

```matlab
mix = modulator('Gain', -6, 'NF', 10, 'OIP3', 20, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');

ckt = circuit('DownConv');
add(ckt, [1 2 0 0], mix);
add(ckt, [2 3], resistor(50, 'Rload'));
setports(ckt, [1 0], [3 0]);
```

### mixerIMT in Circuit

```matlab
m = mixerIMT('LO', 2.1e9, 'ConverterType', 'Down', 'NF', 10, ...
    'ReferenceInputPower', -10, 'NominalOutputPower', -16, 'Name', 'Mixer');

ckt = circuit('MixerStage');
add(ckt, [1 2 0 0], m);    % 4-terminal: p1+->1, p2+->2, p1-->0, p2-->0
setports(ckt, [1 0], [2 0]);
```

### Active Element Node Mapping

All 2-port RF elements have 4 terminals (`p1+`, `p2+`, `p1-`, `p2-`). This includes: amplifier, modulator, mixerIMT, nport, rffilter, attenuator, phaseshift, and **all txline types** (txlineDelayLossless, txlineMicrostrip, txlineCoaxial, txlineCPW, txlineStripline, txlineParallelPlate, txlineTwoWire, txlineWRLGC, txlineRLCGLine, txlineElectricalLength). Use 4-node mapping in `add`:

```matlab
add(ckt, [nodeIn nodeOut nodeInRef nodeOutRef], element);
```

For grounded references, the shorthand `add(ckt, [nodeIn nodeOut 0 0], element)` is typical. Primitive 2-terminal elements (resistor, capacitor, inductor) use 2-node mapping: `add(ckt, [nodeA nodeB], element)`.

**Gotcha:** Active elements are handle objects -- modifying properties after `add` immediately affects the circuit. Use `clone()` for independent copies.

## nport Elements

2-port nport has 4 terminals; 4-port nport has 8 terminals:

```matlab
np = nport('measured.s2p'); np.Name = 'Filter';
add(ckt, [1 2 0 0], np);                      % 2-port: 4 nodes

np4 = nport('device.s4p');
add(ckt, [1 2 3 4 0 0 0 0], np4);            % 4-port: 8 nodes
```

### Identifying Through Paths

Before wiring a multi-port nport, determine which ports are inputs (near-end) and which are outputs (far-end). Look at the **lowest-frequency S-parameter data**: the off-diagonal elements with the largest magnitude identify the through connections.

```matlab
s4 = sparameters('device.s4p');
S = s4.Parameters(:,:,1);     % Lowest frequency
disp(abs(S));                  % Largest off-diagonal = through paths
% If S(2,1) and S(4,3) are the largest, then ports 1,3 are inputs and 2,4 are outputs
```

### nport in rfbudget (Port Selection)

For `rfbudget` use, set `Input` and `Output` properties on the nport directly:

```matlab
np = nport('device.s4p');
np.Input = 1;      % default
np.Output = 3;     % select port 3 as output (default is 2)
b = rfbudget(np, 5e9, 0, 1e6);
```

**Gotcha:** `nport.Input`/`Output` are for rfbudget only -- in `circuit`, use node mapping and `setports` instead.

### Cascading Two 4-Port Blocks

```matlab
n1 = nport('section.s4p'); n2 = clone(n1);
ckt = circuit('Cascade');
add(ckt, [1 5 2 6 0 0 0 0], n1);
add(ckt, [5 3 6 4 0 0 0 0], n2);
setports(ckt, [1 0], [3 0], [2 0], [4 0]);
```

### Adding Transmission Lines to Each Port

```matlab
tl = txlineDelayLossless('Z0', 50, 'TimeDelay', 33e-12, 'Name', 'TL');
add(ckt, [5 1 0 0], tl);
add(ckt, [6 2 0 0], clone(tl));    % Must clone each
```

## Building Circuits with `add`

The `add` method wires element terminals to circuit nodes -- like a SPICE netlist statement.

```matlab
ckt = circuit('PiFilter');
add(ckt, [1 0], capacitor(1e-12, 'C1'));
add(ckt, [1 2], inductor(10e-9, 'L1'));
add(ckt, [2 0], capacitor(1e-12, 'C2'));
```

### Node Mapping Rules

- 2-terminal: `add(ckt, [nodeA, nodeB], elem)` -- maps p->nodeA, n->nodeB
- 4-terminal: `add(ckt, [n1, n2, n3, n4], elem)` -- maps p1+->n1, p2+->n2, p1-->n3, p2-->n4
- 8-terminal (4-port nport): `add(ckt, [p1+ p2+ p3+ p4+ p1- p2- p3- p4-], elem)`
- Node 0 is conventionally ground but has no special meaning -- any node can be a reference
- Nodes are created on-the-fly when first referenced
- Optional terminal reordering: `add(ckt, [3 4], c1, {'n', 'p'})`

### Key Constraints

- **Elements cannot be shared** -- an element added to one circuit cannot be added to another. Use `clone()` first.
- **Duplicate names auto-suffix** -- adding a second `'R1'` creates `'R1_1'`
- **No remove method** -- elements cannot be removed once added. Rebuild the circuit to change topology.

## `setports` vs `setterminals`

These define how the outside world connects to a circuit. **Each can only be called once per circuit.**

### `setports` -- For S-Parameter Extraction

Defines port pairs (signal + reference node). Required before `sparameters()`.

```matlab
setports(ckt, [1 0], [2 0]);           % 2-port: port 1 at node 1, port 2 at node 2
setports(ckt, [1 0], [2 0], [3 0]);    % 3-port
```

Creates terminals `p1+`, `p1-`, `p2+`, `p2-`, etc.

### `setterminals` -- For Subcircuit Embedding

Defines individual terminals mapped to nodes. Used when a circuit will be embedded inside another.

```matlab
setterminals(ckt, [1 2 0], {'in', 'out', 'gnd'});
```

**Gotcha:** `setterminals` takes a **single node vector**, not separate node arguments. Use `setterminals(ckt, [1 2])`, not `setterminals(ckt, 1, 2)`. The optional second argument is a cell array of terminal names.

Terminal count is arbitrary (not necessarily even). Nodes must already exist in the circuit.

| Goal | Use |
|------|-----|
| Extract S-parameters from a standalone circuit | `setports` |
| Embed a circuit as a subcircuit in a parent | `setterminals` |
| Both (embed AND extract S-params from parent) | `setterminals` on sub, `setports` on parent |

## Subcircuit Hierarchy

A circuit with terminals/ports defined can be embedded inside another circuit via `add()`.

```matlab
lMatch = circuit('LMatch');
add(lMatch, [1 2], inductor(10e-9, 'Ls'));
add(lMatch, [2 0], capacitor(5e-12, 'Cp'));
setterminals(lMatch, [1 2 0], {'in', 'out', 'gnd'});

top = circuit('Cascade');
add(top, [1 2 0], lMatch);
add(top, [2 3 0], clone(lMatch));    % Must clone for reuse
setports(top, [1 0], [3 0]);

freq = linspace(1e9, 6e9, 500);
s = sparameters(top, freq);
```

**Gotcha:** A circuit with `setports` can also be embedded -- its 2N terminals (`p1+`, `p1-`, ...) map to 2N parent nodes.

## Multi-Port Networks

Pass multiple `[signal ground]` pairs as **separate arguments** to `setports` for N-port extraction:

```matlab
setports(ckt, [1 0], [2 0], [3 0]);    % 3-port -> 3x3 S-parameter matrix
```

**Gotcha:** Each port is a separate `[signal ref]` pair argument -- do NOT concatenate into one vector. `setports(ckt, [1 0 2 0 3 0])` is **wrong**.

### 3-Port Extraction Example (Directional Coupler)

```matlab
ckt = circuit('Coupler');
add(ckt, [1 2], inductor(5e-9, 'L1'));        % input to through
add(ckt, [1 3], capacitor(2e-12, 'Ccoup'));   % input to coupled port
add(ckt, [2 0], resistor(50, 'Rthrough'));    % through port termination
add(ckt, [3 0], resistor(50, 'Rcoupled'));    % coupled port termination
setports(ckt, [1 0], [2 0], [3 0]);          % 3-port: input, through, coupled

freq = linspace(1e9, 6e9, 201);
s = sparameters(ckt, freq);                   % Returns 3x3 S-parameter matrix
rfplot(s, 2, 1); hold on; rfplot(s, 3, 1);   % S21 (through) and S31 (coupling)
```

## Complete RF Front-End Example

Combine passive and active elements in a single circuit:

```matlab
% Components
dcblk = capacitor(100e-12, 'DCBlock');
lna = amplifier('Gain', 15, 'NF', 2, 'OIP3', 35, 'Name', 'LNA');
bpf = nport('filter.s2p');  bpf.Name = 'BPF';
mix = modulator('Gain', -6, 'NF', 10, 'OIP3', 20, ...
    'LO', 2.1e9, 'ConverterType', 'Down', 'Name', 'Mixer');
ifMatch = circuit('IFMatch');
add(ifMatch, [1 2], inductor(10e-9, 'Ls'));
add(ifMatch, [2 0], capacitor(5e-12, 'Cp'));
setterminals(ifMatch, [1 2 0], {'in', 'out', 'gnd'});

% Assemble
rxCkt = circuit('Receiver');
add(rxCkt, [1 2], dcblk);
add(rxCkt, [2 3 0 0], lna);
add(rxCkt, [3 4 0 0], bpf);
add(rxCkt, [4 5 0 0], mix);
add(rxCkt, [5 6 0], ifMatch);
setports(rxCkt, [1 0], [6 0]);

freq = linspace(0.5e9, 4e9, 500);
s = sparameters(rxCkt, freq);

figure; tiledlayout(1, 2);
nexttile; rfplot(s, 2, 1); title('S21 -- Insertion/Gain');
nexttile; rfplot(s, 1, 1); title('S11 -- Return Loss');
```

## Lumped-to-Distributed (Richards/Kuroda)

```matlab
richards(ckt, opFreq)                    % L/C -> distributed stubs
kuroda(ckt, el1, el2)                    % Kuroda identity
insertUnitElement(ckt, el, port, freq, Z0)
realize(ckt, txTemplate)                 % Electrical-length -> physical
```

## Circuit Methods

| Method | Purpose |
|--------|---------|
| `add(ckt, nodes, elem)` | Wire element to nodes |
| `setports(ckt, ...)` | Define ports for S-param extraction |
| `setterminals(ckt, nodes, names)` | Define terminals for embedding |
| `sparameters(ckt, freq)` | Compute S-parameters |
| `sparameters(ckt, freq, Z0)` | Compute with custom reference impedance |
| `groupdelay(ckt, freq)` | Compute group delay |
| `clone(ckt)` | Deep copy circuit and all elements |
| `richards(ckt, opFreq)` | Convert lumped L/C to distributed stubs |
| `kuroda(ckt, el1, el2)` | Apply Kuroda identity on txline pairs |
| `insertUnitElement(ckt, el, port, freq, Z0)` | Insert quarter-wave unit element |
| `realize(ckt, txTemplate)` | Convert electrical-length lines to physical |

## Circuit Properties (Read-Only Except Name)

| Property | Description |
|----------|-------------|
| `Elements` | Array of all elements |
| `ElementNames` | Cell array of element names |
| `Nodes` | Integer vector of all nodes |
| `Terminals` | Terminal names (empty until set) |
| `Ports` | Port names (empty until `setports`) |
| `ParentPath` | Path when embedded as subcircuit |
| `ParentNodes` | Parent nodes when embedded |

## Gotchas

1. **`setports`/`setterminals` once only** -- calling either a second time errors with "The terminals for this circuit are already set." Plan topology first.
2. **Elements cannot be shared** -- always `clone()` before reuse in a second circuit.
3. **No element removal** -- rebuild circuit to change topology.
4. **Node 0 is not special** -- it is conventionally used as ground but has no built-in ground behavior. Any node can serve as a port reference.
5. **`setterminals` requires existing nodes** -- all nodes in the node vector must already exist in the circuit (created by prior `add` calls). `setports` creates nodes on the fly.
6. **Element Name must be a valid MATLAB identifier** -- no spaces, no leading digits. `amplifier('Name', 'My LNA')` errors.
7. **Active elements use 4-node mapping** -- `add(ckt, [in out inRef outRef], elem)` for amplifier, modulator, mixerIMT, nport. Using only 2 nodes errors for these elements.
8. **`nport.Input`/`Output` are for rfbudget only** -- in circuit, use node mapping and `setports`.
9. **All txline constructors are name-value only** -- `txlineDelayLossless('TL1', 50, 5e-9)` errors. Use `txlineDelayLossless('Name', 'TL1', 'Z0', 50, 'TimeDelay', 5e-9)`. Same applies to all txline types.
10. **`txlineWRLGC` uses `Ro`, `Lo`, `Co`, `Go`, `Gd`** -- short forms error (e.g., `'L'` matches both `'Lo'` and `'LineLength'`). Always use full property names.
11. **`rfwrite` blocks on existing files** -- Always `'ForceOverwrite', true`.
12. **mutualInductor uses name-value pairs only** -- no positional constructor arguments. `mutualInductor(10e-9, 10e-9, 0.8)` errors.
13. **Primitive constructors are positional** -- `resistor(100)`, `capacitor(1e-12)`, `inductor(10e-9)` take a value and optional name string. Name-value syntax errors.
14. **`setterminals` takes a node vector** -- `setterminals(ckt, [1 2])`, not `setterminals(ckt, 1, 2)`. Separate scalar arguments error.

----

Copyright 2026 The MathWorks, Inc.

----
