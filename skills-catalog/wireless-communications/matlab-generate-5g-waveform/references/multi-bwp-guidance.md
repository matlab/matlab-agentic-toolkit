# Multi-BWP Waveform Generation

Generate waveforms with multiple bandwidth parts at different numerologies.
This is the most complex configuration pattern because of interdependencies
between SCS carriers, BWPs, and channel allocations.

## Key Constraints

1. **Each BWP needs its own SCS carrier** at the matching subcarrier spacing
2. **Each BWP must fit within its SCS carrier** (see BWP containment rule)
3. **Channels in different BWPs must not overlap** in time-frequency resources
4. **BWP IDs must be unique** across all bandwidth parts
5. **CORESET is only needed in the BWP that carries PDCCH**

## Separating the two BWPs: FDD (preferred), TDD, Hybrid

Two BWPs on co-located carriers share the same physical spectrum, so their
channels will conflict unless you separate them. There are three ways to do it.
**Prefer FDD** — it is the simplest to reason about and the most realistic.

| Strategy | How BWPs are separated | Channels can run… | When to use |
|----------|------------------------|-------------------|-------------|
| **FDD** *(preferred)* | In **frequency**: each BWP occupies a different sub-band (offset `NStartBWP`, reduced `NSizeBWP`). Carriers stay where the constructor put them. | in **every slot** — no time coordination | Default. Simplest and most realistic. |
| **TDD** | In **time**: both BWPs stay full-band (overlap in frequency) and are scheduled in disjoint slots. | only in disjoint slots | You specifically need each BWP to span the full channel. |
| **Hybrid** | In **both**: BWPs partially overlap in frequency; the overlap is resolved by scheduling in disjoint slots. | full-band only where they don't overlap in time | Wider BWPs than FDD allows, without full TDD time-sharing. |

**Why FDD is simplest:** the constructor already produced legal carrier
`NStartGrid`/`NSizeGrid` values, so subdividing the band into two BWPs is a
bounded adjustment within numbers that were already validated — you are not
solving the Point-A centering constraint yourself. And because the sub-bands
don't overlap, you never have to reason about slot durations across
numerologies.

**FDD sizing math.** A BWP's physical position runs from `NStartBWP` to
`NStartBWP + NSizeBWP`, measured in **that carrier's RBs**. A 15 kHz RB is
**half** the width of a 30 kHz RB, so `108` 15-kHz RBs cover the same bandwidth
as `54` 30-kHz RBs. To split a band at its midpoint: give the 15 kHz BWP the
lower half and the 30 kHz BWP the upper half starting at the matching offset.
Containment must still hold in each carrier's own SCS units:
`NStartGrid_carrier ≤ NStartBWP` and
`NStartBWP + NSizeBWP ≤ NStartGrid_carrier + NSizeGrid`.

> **Mind the 30 kHz carrier's `NStartGrid`.** On R2026b the constructor sets the
> 30 kHz carrier to `NStartGrid = 1`, not 0. That offset centers the narrower
> 30 kHz carrier (106 RB = 38.16 MHz) on the same Point A as the wider 15 kHz
> carrier (216 RB = 38.88 MHz): the 0.72 MHz (2 RB) width difference is split as
> one RB of guard on each side. Because BWP offsets are measured in the
> carrier's own grid, the 30 kHz BWP must satisfy `NStartBWP ≥ 1` and end at
> `≤ NStartGrid + NSizeGrid = 107`. Read the carrier's real values rather than
> assuming a zero origin.

**TDD/Hybrid time separation:** reckon overlap in **absolute time, not slot
indices**. A 30 kHz slot is half the duration of a 15 kHz slot, so
`SlotAllocation = 0:2` on a 15 kHz BWP (0–3 ms) and `6:9` on a 30 kHz BWP
(3–5 ms) are disjoint even though the raw index ranges look like they overlap.

## Choosing a build approach (by release)

Independently of the separation strategy, there are three ways to *build* a
dual-numerology layout. Prefer the highest one your release supports — each one
lower is more manual and more error-prone.

| Approach | Floor | Why |
|----------|-------|-----|
| **SCS-list constructor** `nrDLCarrierConfig("FR1", bw, [15 30])` | **R2026b+** | Builds both SCS carriers *and* both BWPs, sized to fill the channel. No manual sizing. |
| **Seeded scalar constructor** — scalar constructor seeded with the **highest** SCS, then add the lower-SCS carrier manually | R2026a | The generator centers Point A on the highest-SCS carrier; letting the constructor own that carrier means you never fight the centering constraint. (R2026b+ has the SCS-list form above.) |
| **Fully manual** — default-construct, then assign two `SCSCarriers` + two `BandwidthParts` | R2024b+ | The only route before R2026a. |

**The centering constraint that dictates this ordering:** `nrWaveformGenerator`
positions Point A so the **highest-SCS carrier is centered within the channel**,
then requires guardbands. Hand-sizing carriers that ignore this raises
*"ChannelBandwidth too small to fit all carriers."* The constructor forms solve
it for you; the seeded scalar form sidesteps it by letting the constructor place
the highest-SCS (hardest-to-place) carrier.

Each build approach below leads with the **FDD** separation, then shows the
**TDD** and **Hybrid** variants as short deltas.

### Sizing and placing carriers by hand (seeded / manual builds)

When you add a lower-SCS carrier yourself, don't invent RB counts or offsets.
Two rules make every value legal and reproducible:

**1. Look up `NSizeGrid` per numerology from the bandwidth table.** The maximum
RB count for each SCS at a given channel bandwidth is tabulated — read it
instead of guessing:

```matlab
T = nrDLCarrierConfig.FR1BandwidthTable;   % FR2BandwidthTable for FR2
n15 = T{"15kHz","40MHz"};   % 216
n30 = T{"30kHz","40MHz"};   % 106
```

A 30 kHz carrier at 40 MHz is 106 RB, not 108 — it must have an even RB count
and can't perfectly match the 15 kHz carrier's width. Reading the table makes
that fall out automatically.

**2. Center each lower-SCS carrier on the highest-SCS carrier's Point A.** The
generator fixes Point A on the highest-SCS carrier, so every other carrier's
`NStartGrid` follows from it. This four-step rule gives the exact offsets the
constructor would (and explains why the 30 kHz carrier lands at `NStartGrid = 1`
above):

1. **Point A → center**, in the highest carrier's RBs:
   `pointA = NSizeGrid_high/2 + NStartGrid_high`.
2. **Ideal start** of a lower carrier (`ratio = SCS_high / SCS_low`):
   `NStartGrid_low = pointA*ratio − NSizeGrid_low/2`.
3. **If that start is negative**, the low carrier can't fit around the current
   Point A — shift the *high* carrier right by `ceil(|NStartGrid_low|/ratio)`,
   recompute `pointA`, and redo step 2. (This is what nudges the 30 kHz carrier
   to `NStartGrid = 1`.)
4. **If the start is non-integer**, the carrier would straddle a guard band —
   round it up (`ceil`) and drop one RB (`NSizeGrid_low − 1`).

Set each BWP's `NStartBWP`/`NSizeBWP` to match its carrier (or a sub-range of
it, for an FDD split).

---

## Preferred build (R2026b+): SCS-list constructor

Pass a vector of subcarrier spacings and the constructor builds a legal,
channel-filling dual-numerology layout — both SCS carriers and both BWPs, each
sized to the standard maximum for the channel. On R2026b, a 40 MHz FR1 channel
yields:

```
C1: 15 kHz, NStartGrid=0, NSizeGrid=216   ([0.00, 38.88] MHz)
C2: 30 kHz, NStartGrid=1, NSizeGrid=106   ([0.36, 38.52] MHz, centered on Point A)
BWP1 / BWP2 initially fill their carriers (216 / 106 RB).
```

### FDD (preferred): separate the BWPs in frequency

Shrink each BWP and offset the 30 kHz BWP so the two occupy adjacent sub-bands.
The carriers stay exactly where the constructor placed them.

```matlab
cfg = nrDLCarrierConfig("FR1", 40, [15 30]);   % two numerologies in one call

% Split the band at its midpoint (19.44 MHz). 108 15-kHz RBs == 54 30-kHz RBs.
% BWP1 (15 kHz): lower half. NStartBWP stays at its default 0, so only resize.
cfg.BandwidthParts{1}.NSizeBWP = 108;                                          % -> [0.00, 19.44] MHz
% BWP2 (30 kHz): upper half. Its carrier starts at NStartGrid=1, so offsets are
% in that grid: index 54 == 19.44 MHz; fill to the carrier end (grid 107).
cfg.BandwidthParts{2}.NStartBWP = 54;   cfg.BandwidthParts{2}.NSizeBWP = 53;   % -> [19.44, 38.52] MHz

% One PDSCH per BWP, each full-BWP. The sub-bands don't overlap in frequency,
% so no time coordination is needed — SlotAllocation stays at its default
% (every slot, 0:9), which needn't be restated.
cfg.PDSCH{2} = cfg.PDSCH{1};
cfg.PDSCH{1}.PRBSet = 0:cfg.BandwidthParts{1}.NSizeBWP-1;
cfg.PDSCH{2}.BandwidthPartID = 2;
cfg.PDSCH{2}.PRBSet = 0:cfg.BandwidthParts{2}.NSizeBWP-1;

% The constructor enables PDCCH on BWP1 by default; left as-is, its CORESET
% sits in BWP1's sub-band and PDSCH{1} rate-matches around it.

[waveform, info] = nrWaveformGenerator(cfg);
```

### TDD variant: full-band BWPs, separate in time

Keep both BWPs at their full constructor size (they overlap in frequency) and
schedule the two PDSCHs in disjoint slots instead.

```matlab
cfg = nrDLCarrierConfig("FR1", 40, [15 30]);   % BWPs keep full size (216 / 106 RB)

% The default PDCCH repeats every slot (Period=1), so with full-band BWPs it
% would collide with BWP2's PDSCH. Confine it to BWP1's active window instead
% of disabling it.
cfg.PDCCH{1}.SlotAllocation = 0:2;
cfg.PDCCH{1}.Period = [];            % do not repeat into BWP2's slots

cfg.PDSCH{2} = cfg.PDSCH{1};
cfg.PDSCH{1}.PRBSet = 0:cfg.BandwidthParts{1}.NSizeBWP-1;
cfg.PDSCH{1}.SlotAllocation = 0:2;   % 15 kHz slots 0..2 = 0..3 ms
cfg.PDSCH{2}.BandwidthPartID = 2;
cfg.PDSCH{2}.PRBSet = 0:cfg.BandwidthParts{2}.NSizeBWP-1;
cfg.PDSCH{2}.SlotAllocation = 6:9;   % 30 kHz slots 6..9 = 3..5 ms

[waveform, info] = nrWaveformGenerator(cfg);
```

### Hybrid variant: partial frequency overlap, resolved in time

Give each BWP more bandwidth than a clean FDD split allows; where they overlap
in frequency, keep the PDSCHs in disjoint slots.

```matlab
cfg = nrDLCarrierConfig("FR1", 40, [15 30]);
cfg.BandwidthParts{1}.NSizeBWP = 140;                                          % 15 kHz -> [0.00, 25.20] MHz (NStartBWP stays 0)
cfg.BandwidthParts{2}.NStartBWP = 40;   cfg.BandwidthParts{2}.NSizeBWP = 66;   % 30 kHz -> [14.40, 38.16] MHz
% Bands overlap over 14.40–25.20 MHz, so the two PDSCHs must not share slots.

% Keep the default PDCCH out of BWP2's slots (see the TDD note on Period).
cfg.PDCCH{1}.SlotAllocation = 0:2;
cfg.PDCCH{1}.Period = [];

cfg.PDSCH{2} = cfg.PDSCH{1};
cfg.PDSCH{1}.PRBSet = 0:cfg.BandwidthParts{1}.NSizeBWP-1;
cfg.PDSCH{1}.SlotAllocation = 0:2;
cfg.PDSCH{2}.BandwidthPartID = 2;
cfg.PDSCH{2}.PRBSet = 0:cfg.BandwidthParts{2}.NSizeBWP-1;
cfg.PDSCH{2}.SlotAllocation = 6:9;

[waveform, info] = nrWaveformGenerator(cfg);
```

---

## Seeded scalar constructor (R2026a): highest SCS in the constructor

Below R2026b there is no SCS-list form, but you can still let the scalar
constructor place the hardest carrier. **Seed it with the highest SCS**, then
add the lower-SCS carrier and BWP manually around it. The example uses the
**preferred FDD** separation; for TDD/Hybrid, size the BWPs full/partial as
above and separate the PDSCHs in time instead.

```matlab
cfg = nrDLCarrierConfig('FR1', 40, 30);   % highest SCS -> stays Point-A centered

% Size the 15 kHz carrier from the bandwidth table and place it with the
% centering rule (see "Sizing and placing carriers by hand").
n15   = nrDLCarrierConfig.FR1BandwidthTable{"15kHz","40MHz"};   % 216 RB
c30   = cfg.SCSCarriers{1};                                     % 30 kHz, NStartGrid=0, 106 RB
ratio = 30/15;

% Center 15 kHz on the 30 kHz carrier's Point A.
pointA   = c30.NSizeGrid/2 + c30.NStartGrid;
nStart15 = pointA*ratio - n15/2;                 % ideal start: -2 (does not fit)

% Step 3: negative start -> shift the 30 kHz carrier right, then recompute.
NStartGrid30 = c30.NStartGrid;
if nStart15 < 0
    NStartGrid30 = max(NStartGrid30, ceil(abs(nStart15)/ratio));   % -> 1
    pointA   = c30.NSizeGrid/2 + NStartGrid30;
    nStart15 = pointA*ratio - n15/2;                               % -> 0
end
% Step 4: non-integer start -> round up and drop an RB (not needed here).
nSize15 = n15;
if floor(nStart15) ~= nStart15
    nStart15 = ceil(nStart15);
    nSize15  = nSize15 - 1;
end
cfg.SCSCarriers{1}.NStartGrid = NStartGrid30;    % apply the shift

scs15 = nrSCSCarrierConfig;   % SubcarrierSpacing defaults to 15
scs15.NStartGrid = nStart15;
scs15.NSizeGrid  = nSize15;
cfg.SCSCarriers{end+1} = scs15;

% Matching 15 kHz BWP, sized to the lower half of the band (FDD).
bwp15 = nrWavegenBWPConfig;   % SubcarrierSpacing defaults to 15
bwp15.BandwidthPartID   = 2;
bwp15.NStartBWP = scs15.NStartGrid;
bwp15.NSizeBWP  = floor(scs15.NSizeGrid/2);
cfg.BandwidthParts{end+1} = bwp15;

% Shrink the 30 kHz BWP to the upper half (FDD).
c30 = cfg.SCSCarriers{1};   % re-read: NStartGrid now reflects the shift
cfg.BandwidthParts{1}.NStartBWP = c30.NStartGrid + floor(c30.NSizeGrid/2);
cfg.BandwidthParts{1}.NSizeBWP  = (c30.NStartGrid + c30.NSizeGrid) - cfg.BandwidthParts{1}.NStartBWP;

% PDSCH per BWP. FDD sub-bands don't overlap, so both run every slot — the
% default SlotAllocation (0:9) already does this and needn't be restated.
cfg.PDSCH{2} = cfg.PDSCH{1};
cfg.PDSCH{1}.PRBSet = 0:cfg.BandwidthParts{1}.NSizeBWP-1;
cfg.PDSCH{2}.BandwidthPartID = 2;
cfg.PDSCH{2}.PRBSet = 0:bwp15.NSizeBWP-1;
% PDCCH stays enabled on BWP1 (its default); PDSCH{1} rate-matches around it.

[waveform, info] = nrWaveformGenerator(cfg);
```

---

## Fallback build (R2024b+): fully manual dual-carrier build

When calculating offsets, remember that `NStartGrid` for the 30 kHz carrier
is in units of 30 kHz RBs. Two 15 kHz RBs occupy the same bandwidth as one
30 kHz RB.

SCS carriers can overlap in frequency (both `NStartGrid = 0`) or be separated
with `NStartGrid` offsets. The example below uses an offset layout and sizes the
BWPs so they occupy different frequency bands — i.e. the **preferred FDD**
separation. For TDD/Hybrid, size the BWPs full/partial and separate the PDSCHs
in time.

### Example: 40 MHz, Two BWPs (15 kHz + 30 kHz), FDD

```matlab
% Set only the properties this layout requires; FrequencyRange (FR1),
% NCellID (1), NumSubframes (10), NStartGrid/NStartBWP (0), and CORESET
% Duration (2) are left at their defaults rather than restated.
cfg = nrDLCarrierConfig;
cfg.ChannelBandwidth = 40;

% SCS Carrier 1: 15 kHz, lower half (SubcarrierSpacing defaults to 15,
% NStartGrid to 0 — neither is restated)
scsC1 = nrSCSCarrierConfig;
scsC1.NSizeGrid = 52;     % ~half of 40 MHz at 15 kHz (max 216)

% SCS Carrier 2: 30 kHz, upper half
scsC2 = nrSCSCarrierConfig;
scsC2.SubcarrierSpacing = 30;
scsC2.NStartGrid = 28;    % Offset so carriers occupy different frequency bands
scsC2.NSizeGrid = 38;

cfg.SCSCarriers = {scsC1, scsC2};

% BWP 1: uses 15 kHz SCS carrier (BandwidthPartID defaults to 1,
% SubcarrierSpacing to 15, NStartBWP to 0 — none is restated)
bwp1 = nrWavegenBWPConfig;
bwp1.NSizeBWP = 48;       % Fits within 52-RB carrier

% BWP 2: uses 30 kHz SCS carrier
bwp2 = nrWavegenBWPConfig;
bwp2.BandwidthPartID = 2;
bwp2.SubcarrierSpacing = 30;
bwp2.NStartBWP = 28;      % Matches carrier NStartGrid
bwp2.NSizeBWP = 34;       % Fits within 38-RB carrier

cfg.BandwidthParts = {bwp1, bwp2};

% CORESET on BWP 1 only — sized to fit (Duration left at its default of 2)
cfg.CORESET{1}.FrequencyResources = ones(1,4);  % 24 RBs
% PDCCH{1}.BandwidthPartID defaults to 1 (BWP 1) — no need to set it

% PDSCH 1: BWP 1, starts after CORESET symbols. The two BWPs occupy different
% frequency bands, so no time separation is needed — SlotAllocation stays at
% its every-slot default on both.
pdsch1 = nrWavegenPDSCHConfig;   % BandwidthPartID defaults to 1 (BWP 1)
pdsch1.SymbolAllocation = [2 12];  % After 2-symbol CORESET
pdsch1.PRBSet = 0:47;

% PDSCH 2: BWP 2, full slot
pdsch2 = nrWavegenPDSCHConfig;
pdsch2.BandwidthPartID = 2;
pdsch2.SymbolAllocation = [0 14];
pdsch2.PRBSet = 0:33;

cfg.PDSCH = {pdsch1, pdsch2};

% SSBurst on BWP 1 (15 kHz carrier has 52 RBs >= 20). Case A is the 15 kHz
% SSB pattern and is already the BlockPattern default — no need to set it.

[waveform, info] = nrWaveformGenerator(cfg);
```

## Plotting Multiple BWP Resource Grids

```matlab
figure;
tiledlayout(2, 1);

nexttile;
imagesc(abs(info.ResourceGrids(1).ResourceGridBWP(:,:,1)));
axis xy;
xlabel('OFDM Symbols');
ylabel('Subcarriers');
title('BWP 1 — 15 kHz SCS');
colorbar;

nexttile;
imagesc(abs(info.ResourceGrids(2).ResourceGridBWP(:,:,1)));
axis xy;
xlabel('OFDM Symbols');
ylabel('Subcarriers');
title('BWP 2 — 30 kHz SCS');
colorbar;
```

## Avoiding Channel Conflicts

If `nrWaveformGenerator` reports conflicting channels (e.g., "PDCCH{1} and
PDSCH{2} are in conflict"), separate them. **Prefer frequency separation** — it
lets every channel run in every slot:

- **Frequency (preferred):** Use `PRBSet`, or size BWPs into non-overlapping
  sub-bands (FDD), so channels never share physical spectrum.
- **Time:** Use `SlotAllocation` to schedule channels in different slots (TDD).
- **Both (Hybrid):** Where bands must partially overlap, resolve just the
  overlap in time.
- **BWP:** Assign channels to different BWPs (which use different SCS carriers) —
  but see the caveat below.

Remember: channels in different BWPs at different numerologies can still
conflict if their physical frequency ranges overlap. Two full-band PDSCHs on
co-located carriers **will** conflict unless separated in time or frequency.

**When separating in time, reckon in absolute time, not slot indices.** A 30 kHz
slot is half the duration of a 15 kHz slot, so `SlotAllocation = 0:2` on a
15 kHz BWP (0–3 ms) and `SlotAllocation = 6:9` on a 30 kHz BWP (3–5 ms) are
disjoint, even though the raw index ranges look like they might not be.

Copyright 2026 The MathWorks, Inc.
