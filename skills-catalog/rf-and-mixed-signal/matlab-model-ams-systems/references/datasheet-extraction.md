# Reference: Datasheet Parameter Extraction (Phase 1 Detail)

Loaded by the core skill when performing Phase 1 on a real PLL IC datasheet.

## 1.2 Core PLL Parameters

Extract from the Specifications table and Circuit Description:

```
Reference Input:
  - f_REFIN range (min, max)           [MHz]
  - Input sensitivity / coupling       [V p-p, AC/DC]

PFD:
  - f_PFD max (fractional mode)        [MHz]
  - f_PFD max (integer mode)           [MHz]
  - Antibacklash pulse width           [ns]

Test Conditions:
  - Characterization temperature        [C] (typically 25C)

Charge Pump:
  - ICP range (min, max)               [mA]
  - Number of programmable levels
  - ICP vs RSET relationship           (e.g., ICP = 25.5/RSET)
  - Sink/source matching               [%]
  - ICP vs VCP variation               [%]
  - ICP vs temperature variation        [%]

N Divider:
  - INT range (min, max)
  - FRAC range                          (0 to MOD-1)
  - MOD range                           (e.g., 2 to 4095)
  - Prescaler values                    (e.g., 4/5 or 8/9)
  - INT_min per prescaler setting

R Counter:
  - Division range                      (e.g., 1 to 1023)
  - Reference doubler                   (x2, on/off)
  - Reference divider                   (div2, on/off)

VCO:
  - Frequency range (fundamental)       [MHz]
  - KV (VCO sensitivity)                [MHz/V]
  - VTUNE range                         [V]
  - Number of bands / band select mechanism

Output Stage:
  - Output divider ratios               (e.g., div1/2/4/8/16/32/64)
  - Output power levels                 [dBm]
  - Feedback select                     (fundamental vs divided)
```

## 1.3 Noise Parameters

Extract from the Noise Characteristics section:

```
VCO Phase Noise (open-loop):
  - Tabulate: carrier frequency vs offset frequency vs L(f) [dBc/Hz]
  - Example:
    | Carrier  | 10 kHz | 100 kHz | 1 MHz  | 5 MHz  |
    |----------|--------|---------|--------|--------|
    | 2.2 GHz  | -89    | -114    | -134   | -148   |
    | 4.4 GHz  | -83    | -110    | -131   | -145   |

Synthesizer Noise Floor:
  - PNSYNTH (normalized)                [dBc/Hz]
  - Formula: PN_inband = PNSYNTH + 10*log10(f_PFD) + 20*log10(N)

1/f Flicker Noise:
  - PN1_f (normalized at 10 kHz, 1 GHz) [dBc/Hz]
  - Formula: PN = PN1_f + 10*log10(10kHz/f) + 20*log10(f_RF/1GHz)

Integrated Jitter:
  - RMS jitter                          [ps]
  - Integration bandwidth

Spurious:
  - PFD spur level                      [dBc]
  - Fractional spur mechanisms (if applicable)
```

## 1.4 Frequency Plan (Worked Example)

If the datasheet provides a worked example, extract it:

```
f_REFIN  = ?    [MHz]
D        = ?    (doubler: 0 or 1)
R        = ?    (R counter value)
T        = ?    (RDIV2: 0 or 1)
f_PFD    = REFIN * (1+D) / (R * (1+T))
INT      = ?
FRAC     = ?
MOD      = ?
RF_DIV   = ?    (output divider)
f_VCO    = f_PFD * (INT + FRAC/MOD)
f_RFOUT  = f_VCO / RF_DIV
```

---

Copyright 2026 The MathWorks, Inc.
