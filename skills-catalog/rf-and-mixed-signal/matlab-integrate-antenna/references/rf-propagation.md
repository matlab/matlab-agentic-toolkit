# RF Propagation and Site Planning

## Key Objects

| Object | Purpose |
|--------|---------|
| `txsite` | Transmitter site (location, antenna, power, frequency) |
| `rxsite` | Receiver site (location, antenna, sensitivity) |
| `siteviewer` | Map visualization (geographic or cartesian) |
| `propagationModel` | Path loss model selection |
| `propagationData` | Import/visualize measurement data |

## Propagation Models

| Model | Use Case | Key Properties |
|-------|----------|----------------|
| `"freespace"` | Baseline, no terrain | (none) |
| `"close-in"` | Urban/suburban empirical | `PathLossExponent`, `Sigma` |
| `"longley-rice"` | Irregular terrain (outdoor) | `ClimateZone`, `GroundConductivity` |
| `"raytracing"` | Urban/indoor multipath | `Method`, `MaxNumReflections`, `UseGPU` |
| `"rain"` | Rain attenuation | `RainRate` (mm/hr) |
| `"gas"` | Atmospheric gas absorption | `Temperature`, `AirPressure` |
| `"fog"` | Fog/cloud attenuation | `WaterDensity` (g/m^3) |

### Composite Models

Combine atmospheric effects with `+`:

```matlab
pm = propagationModel("freespace") + propagationModel("rain") + propagationModel("gas");
```

### Model Selection Guide

| Environment | Recommended Model |
|-------------|-------------------|
| Open field, satellite | `"freespace"` |
| Suburban macro cell | `"close-in"` or `"longley-rice"` |
| Urban macro cell | `"longley-rice"` |
| Urban micro cell (5G) | `"raytracing"` |
| Indoor (Wi-Fi) | `"raytracing"` (cartesian) |
| Satellite/mmWave | `"freespace" + "rain" + "gas"` |
| Long-range rural | `"longley-rice"` |

## Basic Link Budget (sigstrength)

```matlab
freq = 2.4e9;
tx = txsite(Name="Base Station", Latitude=42.30, Longitude=-71.35, ...
    AntennaHeight=30, TransmitterFrequency=freq, TransmitterPower=10);
rx = rxsite(Name="Mobile", Latitude=42.31, Longitude=-71.36, ...
    AntennaHeight=1.5, ReceiverSensitivity=-90);

ss = sigstrength(rx, tx);
fprintf("Signal strength: %.1f dBm\n", ss);

% With propagation model
ss_lr = sigstrength(rx, tx, "longley-rice");
fprintf("Link margin: %.1f dB\n", ss_lr - rx.ReceiverSensitivity);
```

## Coverage Map

```matlab
freq = 1.9e9;
tx = txsite(Name="Cell Tower", Latitude=42.30, Longitude=-71.35, ...
    AntennaHeight=30, TransmitterFrequency=freq, TransmitterPower=20);

coverage(tx, SignalStrengths=[-60 -70 -80 -90], MaxRange=5000);

% Multiple transmitters
coverage([tx1 tx2], MaxRange=5000, SignalStrengths=[-60 -80 -100]);
```

## SINR Map (Multi-Cell Interference)

```matlab
freq = 1.9e9;
txs = [
    txsite(Name="Cell 1", Latitude=42.30, Longitude=-71.35, ...
        TransmitterFrequency=freq, TransmitterPower=20, AntennaHeight=30)
    txsite(Name="Cell 2", Latitude=42.32, Longitude=-71.33, ...
        TransmitterFrequency=freq, TransmitterPower=20, AntennaHeight=30)
];
sinr(txs, MaxRange=5000, Values=-5:2:20);
```

## Line-of-Sight Analysis

```matlab
vis = los(tx, rx);
fprintf("Line of sight: %s\n", string(vis));
```

## Ray Tracing

### Geographic (Outdoor Urban)

```matlab
freq = 28e9;
tx = txsite(Name="5G BS", Latitude=42.3601, Longitude=-71.0589, ...
    TransmitterFrequency=freq, TransmitterPower=1, AntennaHeight=10);
rx = rxsite(Name="UE", Latitude=42.3605, Longitude=-71.0580, AntennaHeight=1.5);

pm = propagationModel("raytracing");
pm.Method = "sbr";
pm.MaxNumReflections = 3;
pm.MaxNumDiffractions = 1;
pm.AngularSeparation = "high";

raytrace(tx, rx, pm);
ss = sigstrength(rx, tx, pm);
```

### Multi-TX with sigstrength and pathloss

```matlab
viewer = siteviewer(Buildings="chicago.osm");

txArray = [tx1 tx2 tx3];
ss = sigstrength(rx, txArray, pm);           % 1-by-3 vector (dBm)
pl = pathloss(pm, rx, txArray, Map=viewer);  % 1-by-3 cell array (per-ray losses)

% Aggregate multipath in linear domain
for i = 1:numel(txArray)
    pl_rays = pl{i};
    totalPL(i) = -10*log10(sum(10.^(-pl_rays/10)));
end

[bestSS, bestIdx] = max(ss);
fprintf("Strongest: %s at %.1f dBm\n", txArray(bestIdx).Name, bestSS);
```

**Note calling convention differences:** `sigstrength(rx, tx, pm)` vs `pathloss(pm, rx, tx, Map=viewer)` — different argument order, and `pathloss` requires `Map` keyword with ray tracing.

### Cartesian (Indoor)

```matlab
viewer = siteviewer(CoordinateSystem="cartesian", SceneModel="office.stl");

tx = txsite(CoordinateSystem="cartesian", ...
    AntennaPosition=[5; 3; 2.5], ...
    TransmitterFrequency=5.8e9, TransmitterPower=0.1);
rx = rxsite(CoordinateSystem="cartesian", AntennaPosition=[15; 8; 1]);

pm = propagationModel("raytracing", CoordinateSystem="cartesian");
pm.Method = "image";
pm.MaxNumReflections = 3;
pm.SurfaceMaterial = "plasterboard";

raytrace(tx, rx, pm, Map=viewer);
```

### Ray Tracing Properties

| Property | Options | Description |
|----------|---------|-------------|
| `Method` | `"sbr"`, `"image"` | SBR (geographic) or image (cartesian) |
| `MaxNumReflections` | 0-10 | Max reflection order (default 2) |
| `MaxNumDiffractions` | 0-2 | Max diffraction order (default 0) |
| `AngularSeparation` | `"low"`, `"medium"`, `"high"` | Ray density |
| `MaxAbsolutePathLoss` | scalar (dB) | Stop tracing beyond this loss |
| `MaxRelativePathLoss` | scalar (dB) | Stop relative to strongest (default 40) |
| `UseGPU` | `"on"`, `"off"` | GPU acceleration |
| `BuildingsMaterial` | `"auto"`, material name | Geographic scenes |
| `TerrainMaterial` | material name | Ground reflection |
| `SurfaceMaterial` | material name | Cartesian scenes (all surfaces) |

### Per-Ray Path Loss

With ray tracing, `pathloss` returns a **cell array** (one cell per receiver, each containing per-ray losses):

```matlab
pl = pathloss(pm, rxArray, tx, Map=viewer);
txPwr_dBm = 30;
for i = 1:numel(rxArray)
    pl_rays = pl{i};
    prx(i) = 10*log10(sum(10.^((txPwr_dBm - pl_rays)/10)));
end
```

## Antenna Downtilt and Orientation

`AntennaAngle` = [azimuth; mechanical_downtilt] in degrees:

```matlab
tx1 = txsite(Antenna=ant, AntennaAngle=[0; 5], ...);   % sector 1
tx2 = txsite(Antenna=ant, AntennaAngle=[120; 5], ...);  % sector 2
tx3 = txsite(Antenna=ant, AntennaAngle=[240; 5], ...);  % sector 3
```

## Directional Antennas with Sites

`txsite`/`rxsite` require `measuredAntenna` with `E = []` and `Directivity` set. See `reference/measured-antennas.md` Workflow 2 for the full conversion pattern.

## Path Loss Computation

```matlab
pm = propagationModel("freespace");
pl = pathloss(pm, rx, tx);
fprintf("Free-space path loss: %.1f dB\n", pl);
```

## Standalone Path Loss Functions

Quick calculations without creating sites:

```matlab
freq = 28e9;
d = 500;  % meters
c = physconst("LightSpeed");

L_fs = fspl(d, c/freq);          % Free-space
L_rain = rainpl(d, freq, 25);     % Rain (25 mm/hr)
L_gas = gaspl(d, freq, 15, 101325, 7.5);  % Gas
L_fog = fogpl(d, freq, 15, 0.05); % Fog (temp=15°C, density=0.05 g/m^3)
```

## Communication Link Status

```matlab
% Returns logical pass/fail (received > sensitivity?)
status = link(rx, tx, "longley-rice");
fprintf("Link closed: %s\n", string(status));
```

## Range from Path Loss Budget

```matlab
pm = propagationModel("freespace");
tx = txsite(TransmitterFrequency=900e6, TransmitterPower=5, AntennaHeight=30);
r = range(pm, tx, 120);  % max range for 120 dB loss
```

## propagationData (Measurements)

```matlab
pd = propagationData([42.30 42.31 42.32], [-71.35 -71.35 -71.35], "Power", [-65 -72 -81]);
plot(pd); contour(pd);

% From CSV file
pd = propagationData("measurements.csv");
vals = interp(pd, newLat, newLon);
```

## Custom Terrain

```matlab
addCustomTerrain("myRegion", "terrain_data.dt2");
viewer = siteviewer(Terrain="myRegion");
coverage(tx, MaxRange=10000, Map=viewer);
removeCustomTerrain("myRegion");
```

## Buildings and Materials

```matlab
viewer = siteviewer(Buildings="boston.osm");
pm = propagationModel("raytracing");
pm.BuildingsMaterial = "concrete";
pm.TerrainMaterial = "concrete";
```

Available: `"concrete"`, `"brick"`, `"wood"`, `"glass"`, `"metal"`, `"vegetation"`.

## Key Rules

- `sigstrength(rxArray, txArray, pm)` returns numTX-by-numRX matrix
- `SurfaceMaterial` is for cartesian; `BuildingsMaterial`/`TerrainMaterial` for geographic
- `SceneModel` accepts `triangulation` objects (not just file paths)
- `coverage`/`sinr` return `propagationData` when called with output argument
- Ray tracing requires buildings or scene data -- no value without geometry
- Do not call `show(tx)` in headless environments -- use analysis functions directly
- `siteviewer` does not support custom shape overlays; use `geoaxes` + `contour(pd)` for custom annotations
- GPU acceleration (`UseGPU="on"`) significantly speeds ray tracing with large scenes

----

Copyright 2026 The MathWorks, Inc.
