# Configure the Scenario

## Create a Scenario

A scenario holds the scene (terrain and buildings), the actors, and the analyses.

```matlab
scnroDefault = scenario();
scnroGlobal = scenario(Terrain="gmted2010", StopTime=60);
scnro = scenario(Terrain="none", Buildings="none");
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `Terrain` | `"gmted2010"` (default) \| `"none"` \| registered terrain name | Global terrain, tiles downloaded on demand. `"none"` is a flat ellipsoid surface. It is fast and works offline |
| `Buildings` | `"none"` (default) \| registered buildings name | 3D buildings; register the data first (see Register Buildings) |
| `StopTime` | `seconds(Inf)` (default) \| positive number or `duration` | End time of the simulation (see `simulation-execution.md`) |

Read the assets back with `scnro.Scene.Terrain` and `scnro.Scene.Buildings`.

## Terrain and Buildings Names

- Terrain and buildings are selected by **registered name**, not by file path or placename.
  Passing a file name errors because it is not a valid MATLAB variable name.
- Registered names persist across MATLAB sessions.
- Passing an invalid name errors with the list of valid names. Use this to discover what
  is already registered before importing new data.

### Register Buildings

```matlab
buildings = readgeotable("manhattan.osm", Layer="buildings");
addCustomBuildings("manhattan", buildings, NameExistsRule="preserve");
scnro = scenario(Buildings="manhattan");
```

- `addCustomBuildings` takes a geospatial table of building footprints, for example the
  `"buildings"` layer of an OpenStreetMap file.
- `NameExistsRule`: `"overwrite"` (default) \| `"preserve"` \| `"error"`.
- Remove a registration with `removeCustomBuildings`.

### Register Terrain

```matlab
addCustomTerrain("myArea", "n39_w106_3arc_v2.dt1", NameExistsRule="preserve");
scnro = scenario(Terrain="myArea");
```

`addCustomTerrain` reads DTED files. Remove a registration with `removeCustomTerrain`.

### Read Other OpenStreetMap Layers

```matlab
pois = readgeotable("manhattan.osm", Layer="points");
```

OpenStreetMap layers: `"points"`, `"lines"`, `"multilinestrings"`, `"multipolygons"`, `"buildings"`
(one row per building), and `"buildingparts"` (one row per building part).

## Basemap and Camera

Basemaps, zooming to scenario content, and flying the camera to a placename are in
`camera-and-viewing.md` (Basemap; Zoom and Fly to a Place).

----

Copyright 2026 The MathWorks, Inc.

----
