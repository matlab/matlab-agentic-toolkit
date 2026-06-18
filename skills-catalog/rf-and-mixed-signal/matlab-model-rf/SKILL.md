---
name: matlab-model-rf
description: >
  RF Toolbox and RF Blockset in MATLAB -- S-parameter I/O, network conversions (S/Z/Y/ABCD/T/H/G,
  mixed-mode), cascade/de-embedding, rfbudget analysis, circuit composition, matching networks,
  amplifier stability, mixer spurs, rational fitting, SI channels, baseband processing, Circuit
  Envelope simulation. Trigger: sparameters, Touchstone, .s2p, .s4p, rfplot, smithplot, rfparam,
  rfwrite, zparameters, yparameters, abcdparameters, s2sdd, cascadesparams, deembedsparams,
  rfbudget, noise figure, OIP3, IIP3, amplifier, modulator, nport, rffilter, attenuator,
  seriesRLC, shuntRLC, lcladder, txline, circuit, setports, clone, matchingnetwork, stabilityk,
  stabilitymu, powergain, gammams, gammaml, mixerIMT, OpenIF, rational, rationalfit, stepresp,
  txlineWRLGC, rf.Amplifier, rf.Mixer, rf.Filter, rf.Sparameter, rfsystem, RF Blockset.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# RF Toolbox and RF Blockset

Design, analyze, and simulate RF systems in MATLAB -- from measured S-parameter data through
full time-domain Circuit Envelope simulation. One unified workflow covering passive networks,
active device characterization, system cascade budgets, and behavioral time-domain modeling.

## When to Use

**Measured data workflows**
- Loading Touchstone files (.s1p through .snp), validating quality (passivity, causality, IEEE P370)
- Plotting on Smith charts and rectangular plots, interpolating, re-referencing impedance
- Converting between S, Z, Y, ABCD, T, H, G parameters; computing mixed-mode differential
- Cascading and de-embedding S-parameter networks; fixture removal

**System design and analysis**
- Building RF signal chains from behavioral elements (amplifier, modulator, rffilter, nport, etc.)
- Computing cascaded gain, noise figure, IP3, SNR, output power with rfbudget
- Comparing Friis vs Harmonic Balance solver accuracy
- Exporting to RF Blockset Simulink models, Communications Toolbox, or MATLAB scripts

**Circuit-level design**
- Composing arbitrary RF circuits with node wiring (SPICE-like netlist)
- Designing impedance matching networks (L, Pi, Tee topologies, Richards stubs)
- Analyzing amplifier stability (K-factor, mu), power gain, and matching conditions
- Mixer intermodulation analysis and spur-free IF frequency planning

**Time-domain and signal integrity**
- Fitting S-parameters to rational models; computing TDR, impulse, step responses
- Exporting broadband circuit models to SPICE or Verilog-A
- Building SI channel models from nport blocks, lossy transmission lines, and parasitics
- Processing complex baseband signals through rf.Amplifier, rf.Mixer, rf.Filter System Objects
- Full Circuit Envelope time-domain simulation via rfsystem (no Simulink knowledge required)

## When NOT to Use

- Antenna design and radiation patterns -- use Antenna Toolbox
- RF propagation modeling (path loss, fading, ray tracing) -- use Communications Toolbox or Phased Array System Toolbox
- SerDes/high-speed serial link equalization (FFE, CTLE, DFE, IBIS-AMI) -- use SerDes Toolbox
- Radar waveform design or phased arrays -- use Phased Array System Toolbox

## Must-Follow Rules

These apply across ALL RF Toolbox workflows. Violating them produces silent errors or blocks execution.

### Universal

1. **`rfwrite` blocks on existing files** -- Always pass `'ForceOverwrite', true`. Without it, MATLAB opens an interactive overwrite dialog that halts unattended execution.
2. **Elements cannot be reused** -- The same element object cannot appear twice in an rfbudget or circuit. Use `clone(element)` for independent copies.
3. **Element Name must be a valid MATLAB identifier** -- No spaces, no special characters. Use `'IFAmp'` not `'IF Amp'`.
4. **Use `tiledlayout`/`nexttile`** -- Not `subplot`. For all multi-panel figures.
5. **`rfparam` returns complex, not dB** -- Always use `20*log10(abs(rfparam(...)))` for dB magnitude.

### S-Parameters and Network Parameters

6. **`sparameters(filename, Z0)` is invalid** -- Cannot pass reference impedance at load time. Load first, then `newref(s, Z0)`.
7. **`rfinterp1` interpolates real/imag independently** -- Not magnitude and angle. Can produce artifacts near sharp resonances.
8. **Frequency alignment required for cascade/de-embed** -- `cascadesparams` and `deembedsparams` require identical frequency vectors. Always `rfinterp1` to a common grid first.
9. **`deembedsparams` always requires 3 arguments** -- `(sMeasured, sFixture1, sFixture2)`. For one-sided, pass an ideal thru for the unused side.
10. **Mixed-mode port ordering is the #1 error source** -- `s2sdd` option 1 (default) treats ports 1,2 as positive and 3,4 as negative. Verify which option matches your VNA port numbering.
11. **`snp2smp` argument order: ports before impedance** -- `snp2smp(s, portList, Z0)`, not `snp2smp(s, Z0, portList)`.

### rfbudget and Elements

12. **`SignalBandwidth` is required** -- The 4th positional arg to `rfbudget`. Without it, NF/IP3/SNR remain empty.
13. **Passive NF equals loss** -- For `rfelement`, NF should equal `abs(Gain)`. Prefer `attenuator` which handles this automatically.
14. **`nport` Name is positional** -- `nport('file.s2p', 'MyName')`, not name-value syntax.
15. **rffilter: `ResponseType` is shape, `FilterType` is algorithm** -- `rffilter('FilterType', 'Bandpass')` errors. Use `rffilter('ResponseType', 'Bandpass')`.
16. **`show(b)` opens a GUI** -- Produces no command-window output. Use properties (`b.TransducerGain`, `b.NF`) for programmatic access.

### Circuit Composition

17. **`setports`/`setterminals` can only be called once** -- Plan topology before defining terminals.
18. **2-port RF elements use 4-node mapping** -- `add(ckt, [in out inRef outRef], elem)` for amplifier, modulator, nport, all txline types. Primitive 2-terminal elements (resistor, capacitor, inductor) use 2-node mapping.
19. **Primitive constructors are positional** -- `resistor(100, 'R1')`, not `resistor('Resistance', 100)`.
20. **`setterminals` takes a node vector** -- `setterminals(ckt, [1 2])`, not `setterminals(ckt, 1, 2)`.
21. **All txline constructors use name-value pairs only** -- No positional arguments.

### Amplifier Analysis

22. **`powergain` gain type string must be last** -- `powergain(s, 50, 50, 'Gt')`, not `powergain(s, 'Gt', 50, 50)`.
23. **`powergain` returns linear, not dB** -- Convert with `10*log10(g)` (power gain uses 10x, not 20x).
24. **`Gmag` returns NaN when conditionally stable** -- Use `Gmsg` at frequencies where K < 1.

### Rational Fitting

25. **`rational` vs `rationalfit`** -- Use `rational` for new code (AAA). Use `rationalfit` only for delay extraction.
26. **Single-param fit returns plain vectors; multi-port returns cell arrays** -- Always check with `iscell(result)`.
27. **`freqresp` takes Hz** -- Not rad/s. Pass `s.Frequencies` directly.

### System Objects (rf.*)

28. **rf.Amplifier/rf.Mixer use 1-ohm power** -- `Vin = sqrt(Pin_W)`. This differs from rfsystem which uses 50-ohm.
29. **rf.Filter frequencies are ABSOLUTE RF** -- `PassFreq_bp=[2.395e9 2.405e9]` means absolute GHz. Not baseband offsets.
30. **Properties locked during use** -- Call `release(obj)` before modifying Nontunable properties.

### rfsystem

31. **Requires rfbudget** -- `rfsystem` takes an rfbudget, not raw elements.
32. **`close_system` needs save flag** -- Use `close_system(rfs, 0)` to discard changes.
33. **IdealizedBaseband only supports amplifier/modulator/rffilter/nport** -- Other elements require CircuitEnvelope.

## Workflow Quick Reference

| Task | Entry Point | Details |
|------|-------------|---------|
| Load/plot S-parameters | `sparameters`, `rfplot`, `smithplot` | `reference/sparameters-io.md` |
| Convert S/Z/Y/ABCD, mixed-mode | `zparameters`, `s2sdd`, `snp2smp` | `reference/network-conversions.md` |
| Cascade or de-embed networks | `cascadesparams`, `deembedsparams` | `reference/cascade-deembed.md` |
| Create rfbudget elements | `amplifier`, `modulator`, `rffilter`, etc. | `reference/rfbudget-elements.md` |
| Run cascade budget analysis | `rfbudget`, `rfplot(b, 'Pout')` | `reference/rfbudget-analysis.md` |
| Compose RF circuits | `circuit`, `add`, `setports` | `reference/circuit-composition.md` |
| Design matching networks | `matchingnetwork`, `richards` | `reference/matching-networks.md` |
| Analyze amplifier stability/gain | `stabilityk`, `powergain`, `gammams` | `reference/amplifier-analysis.md` |
| Mixer spurs and IF planning | `mixerIMT`, `OpenIF` | `reference/mixer-analysis.md` |
| Fit rational models, TDR | `rational`, `stepresp`, `generateSPICE` | `reference/rational-fitting.md` |
| Build SI channel models | `nport` + `txlineWRLGC` + `circuit` | `reference/si-channel-modeling.md` |
| Process complex baseband | `rf.Amplifier`, `rf.Mixer`, `rf.Filter` | `reference/baseband-processing.md` |
| Time-domain system simulation | `rfsystem`, Circuit Envelope | `reference/system-simulation.md` |

## Conventions

### Code Style
- Use `tiledlayout`/`nexttile` for multi-panel figures (not `subplot`)
- Always label axes with units (GHz, dB, ns, dBm) and include figure titles
- Name elements descriptively for readable topology (`'LNA'`, `'DCBlock'`, `'PCBTrace'`)
- Use `clone()` liberally for element reuse

### Script-First Workflow
For design, analysis, or sweep tasks -- write code to `.m` files on disk, not inline snippets. For quick one-off checks, inline `evaluate_matlab_code` is fine.

### Modern APIs
- `tiledlayout`/`nexttile` instead of `subplot`
- `datetime` instead of `datenum`
- `rational` instead of `rationalfit` (unless delay extraction needed)
- `smithplot` instead of `smith`
- `rfplot` for S-parameter visualization (handles dB conversion automatically)

### References

Load the relevant reference file before writing code for a specific workflow. Each reference contains correct calling conventions, constructor arguments, property names, gotchas, and executable code patterns.

----

Copyright 2026 The MathWorks, Inc.

----
