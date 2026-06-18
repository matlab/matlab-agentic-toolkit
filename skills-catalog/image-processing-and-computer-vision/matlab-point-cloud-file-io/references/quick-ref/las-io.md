# LAS/LAZ File I/O Quick Reference

## Reading — lasFileReader + readPointCloud

| Parameter | Purpose | Default |
|---|---|---|
| `Classification` | Filter by class values (vector) | All classes |
| `ROI` | Spatial bounding box [xmin xmax ymin ymax zmin zmax] | Full extent |
| `GpsTimeSpan` | Filter by GPS time range (2-element duration) | Full range |
| `Attributes` | Subset of attributes to read (string array) | All available |

### Key Properties (lasFileReader)

| Property | Description |
|---|---|
| `FileName` | Path to LAS/LAZ file |
| `Count` | Total number of points |
| `LasVersion` | File version (e.g., "1.4") |
| `XLimits`, `YLimits`, `ZLimits` | Spatial extent |
| `GPSTimeLimits` | Temporal extent (lazy — access triggers scan) |
| `Attributes` | Available attribute names (string array, R2025a+) |
| `ClassificationInfo` | Table of class labels and point counts (lazy) |
| `NumReturns` | Max laser return number in file |
| `Scale`, `Offset` | Coordinate transform factors (R2025a+) |

### Two-Output readPointCloud

```matlab
[ptCloud, ptAttributes] = readPointCloud(reader);
```

- `ptCloud`: `pointCloud` with Location, Color, Normal, Intensity
- `ptAttributes`: `lidarPointAttributes` with Classification, GPSTimeStamp, LaserReturn, NumReturns, ScanAngle, PointSourceID, ScannerChannel, UserData

### Filtering Examples

```matlab
% By classification (ground=2, buildings=6)
[ptCloud, ptAttr] = readPointCloud(reader, Classification=[2 6]);

% By spatial ROI
roi = [xmin xmax ymin ymax zmin zmax];
[ptCloud, ptAttr] = readPointCloud(reader, ROI=roi);

% By GPS time span
tStart = reader.GPSTimeLimits(1);
[ptCloud, ptAttr] = readPointCloud(reader, GpsTimeSpan=[tStart tStart+seconds(30)]);

% Combined
[ptCloud, ptAttr] = readPointCloud(reader, Classification=2, ROI=roi);
```

## Writing — lasFileWriter + writePointCloud

| Property | Purpose | Default |
|---|---|---|
| `FileName` | Output file path (extension determines LAS vs LAZ) | Required |
| `LasVersion` | Target LAS version | `"latest"` |
| `XYZScale` | Coordinate scale factors | `"auto"` |
| `XYZOffset` | Coordinate offsets | `"auto"` |

### Three-Argument writePointCloud (preserves attributes)

```matlab
writer = lasFileWriter("output.laz", LasVersion="1.4");
writePointCloud(writer, ptCloud, ptAttributes);
```

### Adding Variable-Length Records

```matlab
writer = lasFileWriter("output.las");
addVLR(writer, 1, "MyApp", uint8(crsWKT));
writePointCloud(writer, ptCloud, ptAttr);
```

## Gotchas

- `lasFileWriter` only writes **unorganized** pointCloud objects
- `GPSTimeLimits` and `ClassificationInfo` are lazy — first access triggers a file scan
- Intensity lives on `pointCloud.Intensity`, NOT on `lidarPointAttributes`
- `Attributes` property (R2025a+) replaced the removed `hasGPSData`/`hasWaveformData` methods
- Geographic CRS data requires conversion to Cartesian before use

----
Copyright 2026 The MathWorks, Inc.
----
