---
name: matlab-simulate-6g-system
description: >
  Build 6G and pre-6G simulations with the 6G Exploration Library for 5G Toolbox, starting from
  the closest shipped example and its helpers, and avoid silent pre6G API traps. Use for any 6G,
  pre-6G or pre6G* work, including waveforms and impairments, EVM, sub-THz, custom modulation,
  custom reference signals (RS overhead) and link-level throughput or BLER; for 5G or 6G ISAC
  (integrated sensing and communication, TR 38.901 ISAC channel); and for RIS, AI-native
  receivers (DeepRx, PyTorch), ray-traced 5G or 6G network digital twins and cell-free massive
  MIMO.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Simulate 6G Systems

Start from the closest shipped example and its helpers; building from scratch adds silent defects.

## When to Use

- 6G or pre-6G waveforms, EVM or impairments, or any code that calls `pre6G*`
- 6G link-level throughput or BLER, including batch or GPU runs
- 5G or 6G ISAC, RIS, AI-native receivers, ray-traced 5G or 6G digital twins, cell-free mMIMO

## When NOT to Use

- 5G NR waveforms, test models or FRCs (except ISAC): use `matlab-generate-5g-waveform`
- Generic OFDM with no 6G context: use `matlab-design-ofdm-system`
- Radar-only waveforms (LFM, FMCW, phase-coded) and their ambiguity functions, with no 5G or
  6G waveform: use `matlab-design-radar-waveform`
- General `wirelessNetworkSimulator` work (traffic, mobility, tracing, PCAP): use
  `matlab-simulate-wireless-network`. For a digital twin or cell-free network, open the
  example here first.

## Workflow

1. **Pick the example** by the whole task, not the first keyword. For ISAC, configure
   `h38901ISACChannel` from the ISAC channel row; add the end-to-end row for the sensing chain.
2. **No row fits?** Combine the nearest rows, or load [references/find-example-in-doc.md](references/find-example-in-doc.md)
   to get the id from the doc pages, including other products' examples such as OTFS.
3. **Get the files:** `folder = setupExample(id, folder)`, id exactly as listed (no guessed `5g/`
   prefix); unlike `openExample`, it works headless. Files aren't on disk until then: don't sweep.
   The main `.m` embeds its outputs (images, often over 1 MB) after `%[appendix]`: read only
   `extractBefore(fileread(f),"%[appendix]")`, then search it with `contains`/`regexp`/
   `splitlines` filtered to the parameters you need — never print the whole script.
4. **Copy the helpers and local functions verbatim**; adapt the main script. If combining needs a
   helper change, change your copy and say so in the answer. Helpers change between releases: set
   up again rather than reuse an old copy, and check `which -all <helper>`.
5. **Re-check dependent settings:** `LinkLevelSimulationfor6GExample` leaves CDL `CarrierFrequency` at 4 GHz.

## Examples

| Workflow | Example id | Purpose |
|---|---|---|
| Get started / numerology | `pre6g/GetStartedWith6GExplorationLibraryExample` | SCS above 960 kHz, grids over 275 RBs, extended modulation: carrier, grid and channel mapping |
| Link-level throughput | `pre6g/LinkLevelSimulationfor6GExample` | Throughput vs SNR: HARQ, CDL, MIMO precoding, perfect or practical channel estimation |
| Link-level, batch / GPU | `pre6g/Accelerate6GLinkLevelSimulationBatchGPUExample` | Same chain batched on CPU or GPU (GPU needs Parallel Computing Toolbox) |
| Waveform + impairments / EVM | `pre6g/MeasureSubTHzHardwareImpairmentsOn6GWaveformExample` | Waveform generation, PA, phase noise, EVM |
| Waveform over the air | `pre6g/Explore6GWaveformUsingSDRExample` | Same waveform/EVM helpers with an SDR |
| Custom modulation | `pre6g/ConfigureCustomModulationSchemesFor6GExample` | Configure a custom constellation, `pre6GPhysicalChannelConfig(Modulation="Custom",Constellation=c)`, for waveform generation, analysis or link-level simulation |
| Custom reference signals | `pre6g/CompareRSOverheadWithChannelEstimationAccuracyFor6GExample` | Configure custom RS patterns with `pre6GReferenceSignalConfig` and `pre6GReferenceSignalIndices`; overhead and channel estimation |
| ISAC channel | `pre6g/IntroductionToTR38901ISACChannelModelExample` | Reference for configuring `h38901ISACChannel` in any ISAC simulation: monostatic and bistatic modes, targets, RCS model |
| ISAC end-to-end | `pre6g_phased/ISACUsing5GWaveformExample` | OFDM sensing chain (TRP-UE bistatic): range-Doppler, CFAR, scatterers (needs Phased Array System Toolbox) |
| RIS | `pre6g/ModelReconfigurableIntelligentSurfacesWithCDLChannelsExample` | Two concatenated CDL channels with iterative RIS phase control |
| AI-native receiver | `pre6g/AINativeFullyConvolutionalReceiverExample` | DeepRx neural receiver vs conventional PUSCH receiver (needs Deep Learning Toolbox). PyTorch co-execution version: `pre6g/VerifyAINativeReceiverUsingMATLABPytorchCoexecutionExample` |
| Network digital twin | `pre6g/NR5GNetworkDigitalTwinInA3DUrbanScenarioExample` | System-level simulation with ray-traced channels in a 3-D urban scenario: throughput, spectral efficiency, BLER |
| Cell-free mMIMO | `pre6g/EvaluatePerformanceOfCellFreemMIMONetworksExample` | System-level: centralized vs distributed cell-free mMIMO with full PHY |

## Gotchas

- **Primitives only.** No `nrWaveformGenerator` equivalent exists; build from `pre6G*` primitives.
- **`OutputDataType` defaults to `"single"`.** Pass `"double"` for high-order QAM EVM and compute
  EVM directly: `hpre6GPDSCHEVM` returns single.
- **Before writing `pre6G*` code outside an example,** load
  [references/pre6g-api-gotchas.md](references/pre6g-api-gotchas.md) (RS layout, `ReservedRE`,
  argument order, names that don't exist).

----

Copyright 2026 The MathWorks, Inc.

----
