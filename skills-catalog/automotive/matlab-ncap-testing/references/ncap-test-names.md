# Euro NCAP Test Name Lookup

Complete list of valid test names by protocol year and calling convention.

## 2023 Standalone Names

Used with: `ncapScenario(testName)` (no euroAssessment object)

### SA AEB (Safety Assist — Autonomous Emergency Braking)

| Full Name | Short Code | Description |
|-----------|-----------|-------------|
| `"SA AEB CCRs"` | CCRs | Car-to-Car Rear stationary |
| `"SA AEB CCRm"` | CCRm | Car-to-Car Rear moving |
| `"SA AEB CCRb"` | CCRb | Car-to-Car Rear braking |
| `"SA AEB CCFtap"` | CCFtap | Car-to-Car Front turn-across-path |
| `"SA AEB CCCscp"` | CCCscp | Car-to-Car Crossing straight-crossing-path |
| `"SA AEB CCFhos"` | CCFhos | Car-to-Car Front head-on straight |
| `"SA AEB CCFhol"` | CCFhol | Car-to-Car Front head-on lane |

### SA LSS (Safety Assist — Lane Support Systems)

| Full Name | Short Code |
|-----------|-----------|
| `"SA LSS LKA Solid Line"` | LKA Solid |
| `"SA LSS LKA Dashed Line"` | LKA Dashed |
| `"SA LSS Lane Departure Warning"` | LDW |
| `"SA LSS ELK Solid Line"` | ELK Solid |
| `"SA LSS ELK Road Edge"` | ELK Edge |
| `"SA LSS ELK Oncoming vehicle"` | ELK Oncoming |
| `"SA LSS ELK Overtaking vehicle intentional"` | ELK Overtake Int |
| `"SA LSS ELK Overtaking vehicle unintentional"` | ELK Overtake Unint |
| `"SA LSS HMI Blind Spot Monitoring GVT"` | BSM GVT |
| `"SA LSS HMI Blind Spot Monitoring EMT"` | BSM EMT |

### VRU AEB (Vulnerable Road User — AEB)

| Full Name | Short Code |
|-----------|-----------|
| `"VRU AEB Crossing CPFA"` | CPFA |
| `"VRU AEB Crossing CPNA"` | CPNA |
| `"VRU AEB Crossing CPNCO"` | CPNCO |
| `"VRU AEB Longitudinal CPLA"` | CPLA |
| `"VRU AEB Turning CPTAfs"` | CPTAfs |
| `"VRU AEB Turning CPTAfo"` | CPTAfo |
| `"VRU AEB Turning CPTAno"` | CPTAno |
| `"VRU AEB Turning CPTAns"` | CPTAns |
| `"VRU AEB Crossing CBFA"` | CBFA |
| `"VRU AEB Crossing CBNA"` | CBNA |
| `"VRU AEB Crossing CBNAO"` | CBNAO |
| `"VRU AEB Longitudinal CBLA"` | CBLA |
| `"VRU AEB Turning CBTAn"` | CBTAn |
| `"VRU AEB Turning CBTAf"` | CBTAf |
| `"VRU AEB Longitudinal CMRs"` | CMRs |
| `"VRU AEB Longitudinal CMRb"` | CMRb |
| `"VRU AEB Turning CMFtap"` | CMFtap |
| `"VRU AEB Reverse CPRm"` | CPRm |
| `"VRU AEB Reverse CPRs"` | CPRs |

### VRU LSS (Vulnerable Road User — Lane Support)

| Full Name | Short Code |
|-----------|-----------|
| `"VRU LSS CM Overtaking vehicle intentional"` | CM Overtake Int |
| `"VRU LSS CM Overtaking vehicle unintentional"` | CM Overtake Unint |
| `"VRU LSS CM Oncoming vehicle"` | CM Oncoming |

## 2026 euroAssessment Names

Used with: `ncapScenario(ea, testName)` where `ea = euroAssessment(2026)`

All 2026 names use the `"CA FC"` prefix (Crash Avoidance — Forward Collision).

| Full Name | Short Code | 2023 Equivalent |
|-----------|-----------|-----------------|
| `"CA FC CPLA"` | CPLA | `"VRU AEB Longitudinal CPLA"` |
| `"CA FC CPNA"` | CPNA | `"VRU AEB Crossing CPNA"` |
| `"CA FC CPNCO"` | CPNCO | `"VRU AEB Crossing CPNCO"` |
| `"CA FC CPFA"` | CPFA | `"VRU AEB Crossing CPFA"` |
| `"CA FC CPTAfs"` | CPTAfs | `"VRU AEB Turning CPTAfs"` |
| `"CA FC CPTAns"` | CPTAns | `"VRU AEB Turning CPTAns"` |
| `"CA FC CPTAfo"` | CPTAfo | `"VRU AEB Turning CPTAfo"` |
| `"CA FC CPTAno"` | CPTAno | `"VRU AEB Turning CPTAno"` |
| `"CA FC CBLA"` | CBLA | `"VRU AEB Longitudinal CBLA"` |
| `"CA FC CBNA"` | CBNA | `"VRU AEB Crossing CBNA"` |
| `"CA FC CBNAO"` | CBNAO | `"VRU AEB Crossing CBNAO"` |
| `"CA FC CBFA"` | CBFA | `"VRU AEB Crossing CBFA"` |
| `"CA FC CBTAfs"` | CBTAfs | — |
| `"CA FC CBTAns"` | CBTAns | — |
| `"CA FC CBTAfo"` | CBTAfo | — |
| `"CA FC CBTAno"` | CBTAno | — |
| `"CA FC CMRs"` | CMRs | `"VRU AEB Longitudinal CMRs"` |
| `"CA FC CMRb"` | CMRb | `"VRU AEB Longitudinal CMRb"` |
| `"CA FC CMFtap"` | CMFtap | `"VRU AEB Turning CMFtap"` |
| `"CA FC CMCscp"` | CMCscp | — |
| `"CA FC CCRs"` | CCRs | `"SA AEB CCRs"` |
| `"CA FC CCRm"` | CCRm | `"SA AEB CCRm"` |
| `"CA FC CCRb"` | CCRb | `"SA AEB CCRb"` |
| `"CA FC CCFtap"` | CCFtap | `"SA AEB CCFtap"` |
| `"CA FC CCCscp"` | CCCscp | `"SA AEB CCCscp"` |
| `"CA FC CCFhos"` | CCFhos | `"SA AEB CCFhos"` |
| `"CA FC CCFhol"` | CCFhol | `"SA AEB CCFhol"` |

## Name Resolution Rules

1. User says "CCFtap" → resolve to `"SA AEB CCFtap"` (2023) or `"CA FC CCFtap"` (2026)
2. User says "Euro NCAP 2026 CCFtap" → use `euroAssessment(2026)` + `"CA FC CCFtap"`
3. User says just "CCFtap scenario" → default to 2023 standalone: `"SA AEB CCFtap"`
4. Prefixes `CP`, `CB`, `CM` = pedestrian/cyclist/motorcycle (VRU in 2023, CA FC in 2026)
5. Prefixes `CC` = car-to-car (SA AEB in 2023, CA FC in 2026)

----

Copyright 2026 The MathWorks, Inc.

----
