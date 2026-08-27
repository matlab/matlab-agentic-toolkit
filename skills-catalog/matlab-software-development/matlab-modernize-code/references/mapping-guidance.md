# Mapping Toolbox Modernization

## Quick Reference: Function Mappings

For removed functions, `Since` is the removal release; for others it is the discouraged-since release.

| Topic | Recommendation | Since | Status |
|---|---|---|---|
| `webmap` | `geoaxes` + `geobasemap` | R2025a | Not Recommended, will be removed |
| `wmmarker` | `geoiconchart` | R2025a | Not Recommended, will be removed |
| `wmline` | `geoplot` | R2025a | Not Recommended, will be removed |
| `wmpolygon` | `geopolyshape` + `geoplot` | R2025a | Not Recommended, will be removed |
| `wmremove` | `delete` | R2025a | Not Recommended, will be removed |
| `wmcenter` | `MapCenter` property | R2025a | Not Recommended, will be removed |
| `wmzoom` | `ZoomLevel` property | R2025a | Not Recommended, will be removed |
| `wmlimits` | `geolimits` | R2025a | Not Recommended, will be removed |
| `wmclose` | `close` | R2025a | Not Recommended, will be removed |
| `wmprint` | `exportgraphics` | R2025a | Not Recommended, will be removed |
| `geotiffread` | `readgeoraster` | R2020a | Not Recommended |
| `arcgridread` | `readgeoraster` | R2020a | Not Recommended |
| `degtorad` | `deg2rad` | R2018a | Not Recommended |
| `radtodeg` | `rad2deg` | R2018a | Not Recommended |
| `roundn` | `round` | R2018a | Not Recommended |
| `almanac` | `earthRadius` / `referenceEllipsoid` / `referenceSphere` / `wgs84Ellipsoid` | R2012a | Not Recommended |
| `angledim` | `fromRadians` / `fromDegrees` / `toRadians` / `toDegrees` | R2007b | Not Recommended |
| `distdim` | conversion functions (e.g. `deg2km`, `nm2rad`) / `unitsratio` | R2007b | Not Recommended |
| `dted` | `readgeoraster` | R2020a | Not Recommended, will be removed |
| `mfwdtran` | `projfwd` + `projcrs` | R2026a | Removed |
| `minvtran` | `projinv` + `projcrs` | R2026a | Removed |
| `sdtsinfo` | `georasterinfo` | R2026a | Removed |
| `etopo` | `readgeoraster` | R2024b | Removed |
| `globedem` | `readgeoraster` | R2024b | Removed |
| `satbath` | `readgeoraster` | R2024b | Removed |
| `tbase` | `readgeoraster` | R2024b | Removed |
| `gtopo30` | `readgeoraster` | R2024b | Removed |
| `map2pix` | `worldToIntrinsic` | R2024b | Removed |
| `pix2map` | `intrinsicToWorld` | R2024b | Removed |
| `latlon2pix` | `geographicToIntrinsic` | R2024b | Removed |
| `pix2latlon` | `intrinsicToGeographic` | R2024b | Removed |
| `makerefmat` | `georefcells` / `georefpostings` / `maprefcells` / `maprefpostings` | R2023b | Removed |
| `limitm` | `R.LatitudeLimits` / `R.LongitudeLimits` | R2023b | Removed |
| `mapbbox` | `R.XWorldLimits` / `R.YWorldLimits` | R2023b | Removed |
| `sizem` | `R.RasterSize` | R2023b | Removed |
| `refmat2vec` | `refmatToGeoRasterReference` | R2023b | Removed |
| `refvec2mat` | `refvecToGeoRasterReference` | R2023b | Removed |
| `worldFileMatrixToRefmat` | `georasterref` / `maprasterref` | R2023b | Removed |
| `nanm` / `onem` / `zerom` / `spzerom` | `georefcells` + `NaN` / `ones` / `zeros` / `sparse` | R2023b | Removed |
| `ltln2val` | `geointerp` | R2023b | Removed |
| `resizem` | `georesize` / `imresize` | R2023b | Removed |
| `maptrims` | `geocrop` | R2023b | Removed |
| `extractm` | geospatial tables | R2023a | Removed |
| `meshgrat` | `geographicGrid` / `linspace` / `ndgrid` | R2024a | Removed |
| `pixcenters` | `geographicGrid` / `worldGrid` | R2024a | Removed |
| `setltln` | `intrinsicToGeographic` | R2024a | Removed |
| `setpostn` | `geographicToDiscrete` | R2024a | Removed |
| `ecef2lv` | `ecef2enu` (`angleUnit='radians'`) | R2023a | Removed |
| `lv2ecef` | `enu2ecef` (`angleUnit='radians'`) | R2023a | Removed |
| `geocentric2geodeticLat` | `geodeticLatitudeFromGeocentric` | R2023a | Removed |
| `geodetic2geocentricLat` | `geocentricLatitude` | R2023a | Removed |
| `npi2pi` | `wrapToPi` / `wrapTo180` | R2023a | Removed |
| `zero22pi` | `wrapTo2Pi` / `wrapTo360` | R2023a | Removed |
| `combntns` | `nchoosek` | R2022b | Removed |
| `surfdist` | `distance` | R2024b | Removed |
| `project` | `projfwd` | R2023a | Removed |
| `symbolm` | `scatterm` | R2022a | Removed |
| `maptrim` | `geocrop` / `geoclip` | R2024b | Removed |
| `epsm` | `1.0e-6` (literal value) | R2023a | Removed |
| `elevation` | `geodetic2aer` | R2023a | Removed |
| `usgsdem` / `usgs24kdem` | `readgeoraster` | R2023b | Removed |
| `sdtsdemread` | `readgeoraster` | R2023b | Removed |
| `readfields` | `readmatrix` / `readtable` | R2023a | Removed |
| `readmtx` | `readmatrix` / `readtable` | R2023a | Removed |
| `spcread` | `readmatrix` | R2023a | Removed |

---

## Web Map Removal — webmap to Geographic Axes

**Status:** To be removed. `check_matlab_code` raises a warning. Code will break in a future release.

The entire `webmap` family migrates to geographic axes. All 10 functions map to a single modern workflow.

### Predefined Basemap Names

| Old Web Map Layer | New Basemap Name |
|-------------------|-----------------|
| `"World Street Map"` | `"streets"` |
| `"World Imagery"` | `"satellite"` |
| `"Light Gray Canvas Map"` | `"streets-light"` |

Other web map layers (`"Open Street Map"`, `"World Topographic Map"`, `"National Geographic Map"`, etc.) have no predefined equivalent — use `addCustomBasemap` below.

### Custom Basemap Setup

If your web map used a tile source not available as a predefined basemap, register it with `addCustomBasemap` before creating the geographic axes:

```matlab
basemapName = "openstreetmap";
url = "https://a.tile.openstreetmap.org/${z}/${x}/${y}.png";
attribution = char(uint8(169)) + " OpenStreetMap contributors";
addCustomBasemap(basemapName, url, Attribution=attribution)

figure
geobasemap(basemapName)
```

### Complete Migration Example

**Old Pattern (Avoid):**
```matlab
webmap("OpenStreetMap")
wmmarker(42.3557, -71.0662)
wmline([42.3536 42.3548 42.3561], [-71.0656 -71.0665 -71.0632])
polyLat = [42.3554 42.3560 42.3527 42.3520 42.3554];
polyLon = [-71.0722 -71.0695 -71.0678 -71.0707 -71.0722];
wmpolygon(polyLat, polyLon, FaceAlpha=0.35)
wmlimits([42.3518 42.3577], [-71.0735 -71.0609])
```

**Modern Pattern (Use This):**
```matlab
figure
geobasemap("openstreetmap")
hold on

geoiconchart(42.3557, -71.0662, SizeData=32)

geoplot([42.3536 42.3548 42.3561], [-71.0656 -71.0665 -71.0632], ...
    LineWidth=2, Color="k")

polyLat = [42.3554 42.3560 42.3527 42.3520 42.3554];
polyLon = [-71.0722 -71.0695 -71.0678 -71.0707 -71.0722];
shape = geopolyshape(polyLat, polyLon);
geoplot(shape, FaceAlpha=0.35, FaceColor="k")

geolimits([42.3518 42.3577], [-71.0735 -71.0609])
```

**Name-Value Argument Changes:**

| Old (`wmmarker`/`wmline`/`wmpolygon`) | New (`geoiconchart`/`geoplot`) |
|---------------------------------------|-------------------------------|
| `AutoFit=false` | `AffectAutoLimits=false` |
| `Icon=filename` | positional arg: `geoiconchart(lat,lon,filename)` |
| `IconScale=scale` | `SizeData=scale*32` |
| `Color=colorValue` (wmmarker) | `IconColorData=colorValue` |
| `Alpha=alphaValue` (wmmarker) | `IconAlphaData=alphaValue` |

**Migration Notes:**
- Call `hold on` before adding multiple objects — unlike `webmap`, geographic axes do not hold automatically.
- Polygons require a two-step pattern: create a `geopolyshape`, then pass it to `geoplot`.
- Geographic axes do not include built-in interactive controls (basemap picker, zoom slider, coordinate display). Add these manually if needed.

**Why Modern is Better:**
- Full MATLAB graphics customization
- App Designer integration
- Additional plot types (density plots, bubble charts, scatter, raster display with `geoimage` and `geopcolor`)

---

## geotiffread Output Syntax Changes

The output argument order differs between `geotiffread` and `readgeoraster`:

| Old Syntax | New Syntax |
|------------|-----------|
| `[A,R] = geotiffread(f)` | `[A,R] = readgeoraster(f)` |
| `[X,cmap,R] = geotiffread(f)` | `[X,R,cmap] = readgeoraster(f)` — **order changes** |
| `[A,refmat,bbox] = geotiffread(f)` | `[A,R] = readgeoraster(f)` then use `R.XWorldLimits`, `R.YWorldLimits` |

---

## roundn → round — Sign Convention

`round` takes the negative of `roundn`'s exponent: `roundn(X, n)` becomes `round(X, -n)`. For example, `roundn(X, -2)` (round to 2 decimal places) becomes `round(X, 2)`.

---

## DEM Reader Migration — dted, etopo, globedem, gtopo30, satbath

These functions all had multi-argument forms with sample factors and geographic limits. The modern pattern is always: **read → crop → resize**.

**Old Pattern (Avoid):**
```matlab
[Z, refvec] = dted(filename, samplefactor, latlim, lonlim);
```

**Modern Pattern (Use This):**
```matlab
[Z, R] = readgeoraster(filename, OutputType="double");
[Z, R] = geocrop(Z, R, latlim, lonlim);
[Z, R] = georesize(Z, R, 1/samplefactor);
```

The order matters: crop first (reduces data size), then resize.

**With metadata (replaces UHL/DSI/ACC outputs from dted):**
```matlab
[Z, R] = readgeoraster(filename);
info = georasterinfo(filename);
meta = info.Metadata;
```

This same read → crop → resize pattern applies to `etopo`, `globedem`, `gtopo30`, `satbath`, `usgsdem`, and `usgs24kdem`.

---

## geointerp — Interpolation Method Changes

When replacing `ltln2val` with `geointerp`, note these differences:

| | `ltln2val` (old) | `geointerp` (new) |
|-|------------------|-------------------|
| **Default method** | `'nearest'` | `'linear'` |
| **Bilinear** | `'bilinear'` | `'linear'` |
| **Bicubic** | `'bicubic'` | `'cubic'` |
| **Nearest** | `'nearest'` (default) | `'nearest'` (must specify explicitly) |

---

## meshgrat — Multiple Replacement Patterns

The replacement for `meshgrat` depends on which syntax was used:

### With raster reference object (most common)
```matlab
% Old:
[lat, lon] = meshgrat(Z, R);

% New:
[lat, lon] = geographicGrid(R);
```

### With custom gratsize
```matlab
% Old:
[lat, lon] = meshgrat(Z, R, gratsize);

% New:
Rg = R;
Rg.RasterSize = gratsize;
[lat, lon] = geographicGrid(Rg);
```

### With lat/lon vectors — use ndgrid (NOT meshgrid)
```matlab
% Old:
[lat, lon] = meshgrat(latVec, lonVec);

% New:
[lat, lon] = ndgrid(latVec, lonVec);
```

### With limits and gratsize — use linspace + ndgrid
```matlab
% Old:
[lat, lon] = meshgrat(latlim, lonlim, gratsize);

% New:
latv = linspace(latlim(1), latlim(2), gratsize(1));
lonv = linspace(lonlim(1), lonlim(2), gratsize(2));
[lat, lon] = ndgrid(latv, lonv);
```

**Important:** Do NOT use `meshgrid` — it transposes the output layout relative to what `meshgrat` produced. Always use `ndgrid`.

---

## pixcenters — Projected vs Geographic

The replacement depends on the coordinate system:

### Projected (map) coordinates → worldGrid
```matlab
% Old:
[X, Y] = pixcenters(info);
[X, Y] = pixcenters(refmat, height, width);

% New:
R = refmatToMapRasterReference(refmat, [height width]);
[X, Y] = worldGrid(R, 'gridvectors');
```

### Geographic coordinates → geographicGrid
```matlab
% Old:
[lon, lat] = pixcenters(refmat, height, width);

% New:
R = refmatToGeoRasterReference(refmat, [height width]);
[lat, lon] = geographicGrid(R, 'gridvectors');
```

Note: `pixcenters` returned row vectors by default. `worldGrid`/`geographicGrid` return 2-D arrays. Pass `'gridvectors'` for row-vector output.

---

## Migrating Referencing Matrices and Vectors

Legacy Mapping Toolbox code used **referencing matrices** (3x2 `double`) and **referencing vectors** (1x3 `double`) to relate raster grids to geographic or map coordinates. These have been replaced by **raster reference objects** which are self-describing, CRS-aware, and used throughout the modern API.

Many deleted functions (`makerefmat`, `ltln2val`, `meshgrat`, `resizem`, `setltln`, `setpostn`, `pixcenters`, `limitm`, `mapbbox`, `sizem`) required referencing matrices or vectors as input. The modern equivalents all require raster reference objects instead.

### Choosing a Raster Reference Constructor

| Constructor | Coordinate Type | Raster Interpretation |
|-------------|----------------|----------------------|
| `georefcells` | Geographic (lat/lon) | Cells — each element represents an area |
| `georefpostings` | Geographic (lat/lon) | Postings — each element represents a point |
| `maprefcells` | Projected (x/y) | Cells — each element represents an area |
| `maprefpostings` | Projected (x/y) | Postings — each element represents a point |

**How to choose:**
- **Geographic vs Map:** Use `georef*` if coordinates are latitude/longitude. Use `mapref*` if coordinates are in a projected system (meters, feet).
- **Cells vs Postings:** Use cells for imagery and classified data (pixel covers an area). Use postings for elevation grids and sampled data (value at a point).

### Converting Existing Referencing Matrices

If you have a referencing matrix from old code or a loaded `.mat` file, convert it:

```matlab
R = refmatToGeoRasterReference(refmat, rasterSize);
R = refmatToMapRasterReference(refmat, rasterSize);
```

### Living Functions with Removed Syntax

These functions still exist but no longer accept referencing vectors or matrices as of R2024b. Pass a raster reference object instead:

`mapoutline`, `worldfilewrite`, `geotiffwrite`, `areamat`, `filterm`, `findm`, `imbedm`, `mapprofile`, `vec2mtx`, `gradientm`, `los2`, `viewshed`, `neworig`, `contourm`, `contourfm`, `contour3m`, `meshm`, `meshlsrm`, `grid2image`

**Migration pattern** (same for all — replace `someFunction` with any function above):
```matlab
% TEMPLATE — not executable; illustrates the shape common to all functions listed above.
% Old:  result = someFunction(Z, refvec);
% New:
R = refvecToGeoRasterReference(refvec, size(Z));
result = someFunction(Z, R);
```


---

## Migration Groups at a Glance

The full table above lists every function individually; this groups the common families with their key migration gotcha.

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `webmap` / `wm*` family | `geoaxes` + `geoplot` / `geoiconchart` | Not Recommended, will be removed |
| `geotiffread` / `arcgridread` | `readgeoraster` (output order differs; keep `geotiffread` for URLs or multi-image files) | Not Recommended |
| `mfwdtran` / `minvtran` | `projfwd` / `projinv` (or `geodetic2ecef` / `ecef2geodetic` for globe) | Removed |
| `makerefmat` | `georefcells` / `maprefcells` | Removed |
| `pixcenters` | `worldGrid` (projected) / `geographicGrid` (geographic) | Removed |
| `map2pix` / `pix2map` | `worldToIntrinsic` / `intrinsicToWorld` | Removed |
| `meshgrat` | `geographicGrid` / `ndgrid` (depending on syntax) | Removed |
| `dted` family | `readgeoraster` → `geocrop` → `georesize` | Removed / Not Recommended, will be removed |
| `distdim` | specific conversion functions (e.g., `deg2km`, `nm2rad`) / `unitsratio` | Not Recommended |
| `ltln2val` | `geointerp` (default method is `'linear'` not `'nearest'`) | Removed |


----

Copyright 2026 The MathWorks, Inc.

----

