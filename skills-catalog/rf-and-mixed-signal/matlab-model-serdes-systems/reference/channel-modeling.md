# Channel Modeling

## Channel Source Selection

| Source | When to Use | Key Properties |
|--------|-------------|----------------|
| **Loss model** (`ChannelLossdB`) | Quick design-space exploration, sweeps, comparisons | `ChannelLossdB`, `ChannelLossFreq`, `ChannelDifferentialImpedance` |
| **S-parameter** (`SParameterChannel`) | Real measured or extracted channels, compliance testing | `FileName`, `PortOrder`, `SampleInterval`, `StopTime` |
| **Direct impulse** | Custom channel models, cascaded channels, imported data | `Impulse` (column vector), `dt` |

All three modes are mutually exclusive. Selection happens at `ChannelData` construction
time — see the gotcha about constructor vs post-hoc assignment.

**Loss model critical setup:** `ChannelLossFreq` defaults to **5 GHz** — almost always
wrong. Always set it to the Nyquist frequency (BaudRate/2 = `1/(2*SymbolTime)`).
Without this, the specified loss applies at 5 GHz and the actual loss at Nyquist is
dramatically higher, producing unexpectedly closed eyes.

```matlab
% Loss model — always set ChannelLossFreq to Nyquist
sys.ChannelData.ChannelLossdB = 15;
sys.ChannelData.ChannelLossFreq = 1 / (2 * sys.SymbolTime);  % Nyquist
sys.ChannelData.ChannelDifferentialImpedance = 100;
```

## S-Parameter Channel Workflow

### Step 1: Load and Configure

```matlab
spCh = SParameterChannel("FileName", "channel.s4p");
spCh.SampleInterval = symbolTime / samplesPerSymbol;  % must match SerdesSystem dt
spCh.StopTime = 60e-9;    % >= 60 ns for reliable metrics
spCh.PortOrder = [1 3 2 4];  % if file uses [in+ in- out+ out-] convention
spCh.TxR = 50;  spCh.RxR = 50;
```

### Step 2: Feed into SerdesSystem

```matlab
channel = ChannelData("Impulse", spCh.ImpulseResponse, "dt", spCh.SampleInterval);
sys = SerdesSystem("ChannelData", channel, ...
    'TxModel', Transmitter('Blocks', {serdes.FFE(...)}), ...
    'RxModel', Receiver('Blocks', {serdes.CTLE(...), serdes.DFECDR(...)}), ...
    'SymbolTime', symbolTime, 'SamplesPerSymbol', 16, 'Modulation', 4);
```

### Step 3: Analyze

```matlab
results = analysis(sys);
plotStatEye(sys);
analysisReport(sys);
```

### Multi-Port Files (Aggressors)

`SParameterChannel` handles multi-port files directly (`.s8p`, `.s12p`, `.s16p`).
The `ImpulseResponse` property returns an Nx(K) matrix where column 1 is the victim
thru and columns 2+ are aggressor coupling. Pass the full matrix to `ChannelData`
to include crosstalk automatically.

```matlab
spCh = SParameterChannel("FileName", "channel_20dB_2agg.s12p");
spCh.SampleInterval = symbolTime / samplesPerSymbol;
spCh.StopTime = 60e-9;

ir = spCh.ImpulseResponse;  % Nx3: thru + 2 aggressors
channel = ChannelData("Impulse", ir, "dt", spCh.SampleInterval);
% Aggressors automatically included — no EnableCrosstalk needed
```

To inspect S-parameter data at the frequency-domain level, use `sparameters()` + `rfparam()`:

```matlab
sp = sparameters("channel_20dB_2agg.s12p");
f = sp.Frequencies / 1e9;
s_thru = rfparam(sp, 3, 1);  % victim thru
s_fext = rfparam(sp, 3, 5);  % FEXT from 1st aggressor
```

## Crosstalk Modeling

Two mutually exclusive crosstalk modes in `ChannelData`:

### Mode 1: ICN Synthetic Crosstalk (Loss Model)

Add synthetic FEXT/NEXT noise to a loss-model channel. Set `EnableCrosstalk = true`
and choose a `CrosstalkSpecification`. Both named specs and `"Custom"` work.

```matlab
% Named specification — uses predefined ICN values
channel = ChannelData();
channel.ChannelLossdB = 20;
channel.EnableCrosstalk = true;
channel.CrosstalkSpecification = "CEI-28G-SR";  % -3.4 dB COM at 15 dB loss

% Custom specification — explicit ICN control
channel = ChannelData();
channel.ChannelLossdB = 20;
channel.EnableCrosstalk = true;
channel.CrosstalkSpecification = "Custom";
channel.FEXTICN = 0.015;    % 15 mV RMS (volts, not dB)
channel.NEXTICN = 0.010;    % 10 mV RMS
channel.fb = nyquistFreq;   % set to Nyquist for correct shaping
```

**Valid CrosstalkSpecification values:** `"CEI-28G-SR"`, `"CEI-25G-LR"`,
`"CEI-28G-VSR"`, `"100GBASE-CR4"`, `"Custom"`.

| Property | Default | Units | Description |
|----------|---------|-------|-------------|
| `EnableCrosstalk` | `false` | logical | Enable crosstalk modeling |
| `CrosstalkSpecification` | `"CEI-28G-SR"` | string | Named spec or `"Custom"` for explicit ICN |
| `FEXTICN` | `0.015` | V RMS | Far-end integrated crosstalk noise (Custom only) |
| `NEXTICN` | `0.010` | V RMS | Near-end integrated crosstalk noise (Custom only) |
| `fb` | `14e9` | Hz | Baud rate for ICN shaping (set to Nyquist) |
| `Aft` / `Ant` | `1.2` | Vpp | Aggressor amplitude (FEXT/NEXT) |
| `Tft` / `Tnt` | `9.6e-12` | s | Aggressor rise time (FEXT/NEXT) |

### Mode 2: S-Parameter Aggressors (Multi-Port Files)

`SParameterChannel` handles multi-port Touchstone files directly (`.s8p`, `.s12p`,
`.s16p`). The `ImpulseResponse` matrix has one column per lane: column 1 = victim
thru, columns 2+ = aggressor crosstalk coupling.

```matlab
spCh = SParameterChannel("FileName", "channel_20dB_2agg.s12p");
spCh.SampleInterval = dt;
spCh.StopTime = 60e-9;

impulse = spCh.ImpulseResponse;  % Nx3 matrix (1 victim + 2 aggressors)
channel = ChannelData("Impulse", impulse, "dt", dt);
% Aggressors are automatically included in analysis — no EnableCrosstalk needed
```

To exclude aggressors from a multi-port file, pass only column 1:

```matlab
channel = ChannelData("Impulse", impulse(:, 1), "dt", dt);
```

Quantitative impact at 20 dB loss (56 Gbps PAM4):
- Thru only: COM = 2.65 dB
- +1 aggressor (.s8p): COM = 1.93 dB (-0.72)
- +2 aggressors (.s12p): COM = 1.49 dB (-1.20)
- +3 aggressors (.s16p): COM = 1.00 dB (-1.69)

### Key Gotchas

- **NEXTICN is ~2x more destructive than FEXTICN** at the same value. NEXT=0.005
  → COM drops ~6 dB; FEXT=0.005 → COM drops ~1.6 dB. NEXT corrupts the signal
  at the receiver before equalization can help.
- **FEXTICN/NEXTICN are in volts RMS**, not dB. Typical values: 5-50 mV.
- **Multi-column impulse auto-enables crosstalk.** Setting `EnableCrosstalk = false`
  does NOT disable it — the only way to exclude aggressors is passing column 1 only.
- **ICN parameters are ignored when aggressors are present.** The two modes are not
  additive — S-parameter aggressors take precedence.
- **SParameterChannel column mapping:** `.s8p` → 2 columns, `.s12p` → 3, `.s16p` → 4.
- **Set `fb` to Nyquist** when using Custom crosstalk. The default `fb = 14e9` may
  not match your baud rate.

### Design Insight: CTLE Amplifies Crosstalk at Low Loss

At low channel loss (≤ 10-15 dB), CTLE high-frequency boost amplifies crosstalk noise
along with the signal. This can *reduce* COM even though it improves the signal eye.

In a 56 Gbps PAM4 design with 10 dB loss and FEXT=15 mV / NEXT=10 mV:
- AC Gain = 0 dB → COM = 3.27 dB (best under crosstalk)
- AC Gain = 10 dB → COM < 3 dB (crosstalk amplified more than signal improved)

**Recommendation:** When crosstalk is significant and channel loss is low, sweep CTLE
AC gain starting from 0 dB. The optimal CTLE setting under crosstalk is often lower
than the optimal setting without crosstalk. At higher loss (≥ 20 dB), CTLE benefit
outweighs the noise penalty.

See `reference/equalization-tuning.md` for CTLE behavior under crosstalk at different loss levels.

## Pattern: S-Parameter Channel Setup

```matlab
% Load S-parameter file and feed into SerdesSystem
spCh = SParameterChannel("FileName", "channel.s4p");
spCh.SampleInterval = symbolTime / samplesPerSymbol;
spCh.StopTime = 60e-9;
spCh.PortOrder = [1 3 2 4];  % adjust for file's port convention

channel = ChannelData('Impulse', spCh.ImpulseResponse, 'dt', spCh.SampleInterval);
sys = SerdesSystem('ChannelData', channel, 'SymbolTime', 100e-12, 'SamplesPerSymbol', 16);

% Multi-port files (.s8p/.s12p/.s16p): ImpulseResponse is Nx(K) matrix
% Column 1 = victim thru, columns 2+ = aggressor coupling (auto-included)
% To exclude aggressors: ChannelData('Impulse', spCh.ImpulseResponse(:,1), ...)
```

----

Copyright 2026 The MathWorks, Inc.
----
