---
name: matlab-point-cloud-file-io
description: "Read and write 3-D point cloud data using Lidar Toolbox file I/O. Covers PLY, PCD, LAS/LAZ, PCAP (Velodyne/Ouster/Hesai), E57, and IDC (Ibeo) formats. Use when loading point clouds from disk, saving to disk, choosing the correct reader or writer for a file format, extracting or preserving lidar point attributes, reading Ibeo IDC sensor recordings, or converting between formats."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Point Cloud File I/O

Read and write 3-D point cloud data in MATLAB using Lidar Toolbox file I/O functions, covering PLY, PCD, LAS/LAZ, sensor PCAP, E57, and IDC (Ibeo) formats.

## When to Use

- Loading a point cloud file from disk into a `pointCloud` object
- Saving a `pointCloud` object to disk in any supported format
- Deciding which reader or writer function to use for a given file format
- Reading LAS/LAZ files with selective filtering (ROI, classification, GPS time)
- Extracting or preserving lidar point attributes (classification, GPS timestamps, scan angle)
- Reading Velodyne, Ouster, or Hesai PCAP sensor recordings frame-by-frame
- Reading multi-scan E57 files with indexed access
- Reading Ibeo IDC sensor recordings with message-based access
- Converting between point cloud formats (e.g., LAS to PLY, PCD to LAZ)

## When NOT to Use

- Streaming live sensor data in real time (use `velodynelidar`, `ousterlidar`, `sicklidar`)
- Processing or filtering point clouds after reading (use `pcdownsample`, `pcdenoise`)
- Reading or writing surface meshes (use `readSurfaceMesh`, `writeSurfaceMesh`)
- Saving point cloud variables to MAT-files (use `save`)
- Visualizing point clouds (use `pcshow`, `pcplayer`, `pcviewer`)

## Must-Follow Rules

1. **Route by file extension, not by habit** — `pcread` ONLY supports `.ply` and `.pcd` files. For `.las`/`.laz` use `lasFileReader` + `readPointCloud`. For `.pcap` use the sensor-specific file reader (`velodyneFileReader`, `ousterFileReader`, or `hesaiFileReader`). For `.e57` use `e57FileReader`. Calling `pcread` on a LAS or PCAP file produces an error, not a warning. Similarly, `pcwrite` ONLY writes PLY and PCD — for LAS/LAZ output use `lasFileWriter` + `writePointCloud`.

2. **PCAP file readers require a mandatory device identifier — never guess it** — `velodyneFileReader` requires a `DeviceModel` string (e.g., `"HDL32E"`). `hesaiFileReader` requires a `DeviceModel` string (e.g., `"PandarXT32"`). `ousterFileReader` requires a `CalibrationFile` path (JSON). If the user has not specified the device model or calibration file, ASK — do not assume a default. There is no default value; omitting it causes an error.

3. **Use two-output syntax to get point attributes from LAS/LAZ** — `[ptCloud, ptAttributes] = readPointCloud(reader)` returns a `lidarPointAttributes` object containing Classification, GPSTimeStamp, LaserReturn, NumReturns, ScanAngle, and more. The single-output form discards these attributes permanently. Intensity is on the `pointCloud` object (`.Intensity` property), NOT on `lidarPointAttributes`.

4. **Preserve attributes with three-argument writePointCloud** — `writePointCloud(writer, ptCloud, ptAttributes)` preserves Classification, GPSTimeStamp, and other lidar attributes in LAS/LAZ output. The two-argument form `writePointCloud(writer, ptCloud)` discards all attributes. If the user has attributes from `lasFileReader`/`readPointCloud`, always pass them through.

5. **PLY only supports ascii and binary encoding** — Calling `pcwrite(ptCloud, "file.ply", Encoding="compressed")` throws an error. Only `"ascii"` and `"binary"` are valid for PLY. The `"compressed"` encoding is exclusive to PCD format. Defaults (R2026a+): PLY=`"binary"`, PCD=`"compressed"`.

6. **Always use string syntax** — Use double-quoted strings (`"text"`) for all literal text arguments (filenames, device models, encoding values, Name=Value values). Use `Name=Value` syntax for all name-value pairs. Never use character vectors (`'text'`) or legacy `'Name','Value'` pair syntax.

### Preflight Procedure

1. List MATLAB functions to call
2. Check `references/INDEX.md` for each (function-level + task-level tables)
3. Read required quick-ref files
4. State at response top: `Preflight: quick-ref/xxx.md, quick-ref/yyy.md` (or `Preflight: none required`)

## Key Functions

| Function | Purpose | Format | Key Constraint |
|---|---|---|---|
| `pcread` | Read point cloud from file | PLY, PCD | Single call, returns `pointCloud` |
| `pcwrite` | Write point cloud to file | PLY, PCD | Encoding varies by format |
| `lasFileReader` | Create LAS/LAZ reader object | LAS, LAZ | Two-step: create reader, then `readPointCloud` |
| `lasFileWriter` | Create LAS/LAZ writer object | LAS, LAZ | Two-step: create writer, then `writePointCloud` |
| `velodyneFileReader` | Create Velodyne PCAP reader | PCAP | Mandatory `DeviceModel` (2nd arg) |
| `ousterFileReader` | Create Ouster PCAP reader | PCAP | Mandatory `CalibrationFile` (2nd arg) |
| `hesaiFileReader` | Create Hesai PCAP reader | PCAP | Mandatory `DeviceModel` (2nd arg) |
| `e57FileReader` | Create E57 reader object | E57 | Use `readPointCloud(reader, idx)` for multi-scan |
| `ibeoLidarReader` | Create Ibeo IDC reader object | IDC | Use `readMessages` to read scan data |

## Decision Framework

```
READING — What is the file extension?
├── .ply / .pcd → pcread(filename)
├── .las / .laz → lasFileReader(filename) + readPointCloud(reader)
├── .pcap (Velodyne) → velodyneFileReader(filename, deviceModel)
├── .pcap (Ouster)  → ousterFileReader(filename, calibrationFile)
├── .pcap (Hesai)   → hesaiFileReader(filename, deviceModel)
├── .e57           → e57FileReader(filename) + readPointCloud(reader, idx)
└── .idc (Ibeo)    → ibeoLidarReader(filename) + readMessages(reader)

WRITING — What output format does the user need?
├── .ply → pcwrite(ptCloud, "file.ply")
│         Encoding: "ascii" or "binary" (default: binary)
├── .pcd → pcwrite(ptCloud, "file.pcd")
│         Encoding: "ascii", "binary", or "compressed" (default: compressed)
├── .las → lasFileWriter("file.las") + writePointCloud(writer, ptCloud)
└── .laz → lasFileWriter("file.laz") + writePointCloud(writer, ptCloud)
           Optional: pass ptAttributes as 3rd arg to preserve attributes
```

**PCAP sensor identification:** If the user says "Velodyne", "Ouster", or "Hesai" — use the matching reader. If they just say "PCAP file" without specifying the sensor, ASK which sensor produced it.

**Ibeo IDC files:** If the user has an `.idc` file, use `ibeoLidarReader`. Unlike other readers, it uses `readMessages` (not `readPointCloud` or `readFrame`) and returns message-based scan data.

**Velodyne device models:** VLP16, PuckLITE, PuckHiRes, VLP32C, HDL32E, HDL64E, VLS128, VelarrayH800

**Hesai device models:** Pandar128E3X, Pandar64, PandarQT, PandarXT32

## Gotchas

### `pcread` called on LAS/LAZ file

`pcread` only supports PLY and PCD formats. Attempting to use it on LAS, LAZ, PCAP, or E57 files throws an error.

```matlab
% WRONG: pcread does not support LAS
ptCloud = pcread("survey.las");

% CORRECT: Use lasFileReader for LAS/LAZ
reader = lasFileReader("survey.las");
ptCloud = readPointCloud(reader);
```

### Compressed encoding on PLY file

The `"compressed"` encoding is only valid for PCD format. PLY supports only `"ascii"` and `"binary"`.

```matlab
% WRONG: compressed not supported for PLY
pcwrite(ptCloud, "output.ply", Encoding="compressed");

% CORRECT: use binary for compact PLY
pcwrite(ptCloud, "output.ply", Encoding="binary");

% CORRECT: compressed is valid for PCD
pcwrite(ptCloud, "output.pcd", Encoding="compressed");
```

### Using pcwrite for LAS/LAZ output

`pcwrite` does not support LAS or LAZ format. It only handles PLY and PCD.

```matlab
% WRONG: pcwrite cannot write LAS
pcwrite(ptCloud, "output.las");

% CORRECT: use lasFileWriter for LAS/LAZ
writer = lasFileWriter("output.las");
writePointCloud(writer, ptCloud);
```

### Losing attributes with two-argument writePointCloud

When writing LAS/LAZ, the two-argument form discards lidar point attributes. Always pass the attributes object if available.

```matlab
% WRONG: attributes are discarded
reader = lasFileReader("input.laz");
[ptCloud, ptAttr] = readPointCloud(reader);
writer = lasFileWriter("output.laz");
writePointCloud(writer, ptCloud);  % ptAttr lost!

% CORRECT: preserve attributes with 3-argument form
reader = lasFileReader("input.laz");
[ptCloud, ptAttr] = readPointCloud(reader);
writer = lasFileWriter("output.laz");
writePointCloud(writer, ptCloud, ptAttr);
```

### Accessing classification from the wrong object

Classification, GPSTimeStamp, LaserReturn, and other lidar-specific attributes are on `lidarPointAttributes`, not on `pointCloud`. The `pointCloud` object holds Intensity (and Location, Color, Normal).

```matlab
% WRONG: pointCloud does not have Classification
reader = lasFileReader("data.laz");
ptCloud = readPointCloud(reader);
labels = ptCloud.Classification;  % Error

% CORRECT: Use two-output syntax
reader = lasFileReader("data.laz");
[ptCloud, ptAttributes] = readPointCloud(reader);
labels = ptAttributes.Classification;
intensity = ptCloud.Intensity;  % Intensity is on pointCloud
```

### Reading all PCAP frames without a loop

PCAP readers are frame-based iterators. There is no single function to load all frames at once.

```matlab
% WRONG: No readAll or similar function
reader = velodyneFileReader("lidarData_ConstructionRoad.pcap", "HDL32E");
allPoints = readPointCloud(reader);  % readPointCloud is not a method

% CORRECT: Loop with hasFrame/readFrame
reader = velodyneFileReader("lidarData_ConstructionRoad.pcap", "HDL32E");
while hasFrame(reader)
    ptCloud = readFrame(reader);
end
```

## Patterns

### Read a PLY or PCD file

```matlab
ptCloud = pcread("scene.ply");
fprintf("Points: %d\n", ptCloud.Count);
fprintf("X range: [%.2f, %.2f]\n", ptCloud.XLimits);
```

### Read LAS file with classification filtering

```matlab
reader = lasFileReader("aerial.laz");
[ptCloud, ptAttributes] = readPointCloud(reader, Classification=[2 6]);
labels = ptAttributes.Classification;
fprintf("Ground + building points: %d\n", ptCloud.Count);
```

### Read Velodyne PCAP frames

```matlab
reader = velodyneFileReader("lidarData_ConstructionRoad.pcap", "HDL32E");
fprintf("Total frames: %d\n", reader.NumberOfFrames);
while hasFrame(reader)
    ptCloud = readFrame(reader);
end
```

### Read E57 file with multiple scans

```matlab
reader = e57FileReader("building.e57");
fprintf("Scans in file: %d\n", reader.NumPointClouds);
for idx = 1:reader.NumPointClouds
    ptCloud = readPointCloud(reader, idx);
    fprintf("Scan %d: %d points\n", idx, ptCloud.Count);
end
```

### Write point cloud to PLY (binary)

```matlab
ptCloud = pointCloud(rand(1000,3), Color=uint8(rand(1000,3)*255));
pcwrite(ptCloud, fullfile(tempdir, "output.ply"), Encoding="binary");
```

### Write point cloud to PCD (compressed)

```matlab
ptCloud = pcread(fullfile(toolboxdir("lidar"), "lidardata", "highwayScene.pcd"));
pcwrite(ptCloud, fullfile(tempdir, "scene_compressed.pcd"), Encoding="compressed");
```

### Read LAS and write to LAZ preserving attributes

```matlab
reader = lasFileReader("input.las");
[ptCloud, ptAttr] = readPointCloud(reader);
writer = lasFileWriter(fullfile(tempdir, "output.laz"));
writePointCloud(writer, ptCloud, ptAttr);
```

### Convert PCD to PLY

```matlab
ptCloud = pcread("scene.pcd");
pcwrite(ptCloud, fullfile(tempdir, "scene.ply"), Encoding="binary");
```

### Convert LAS to PCD

```matlab
reader = lasFileReader("survey.las");
ptCloud = readPointCloud(reader);
pcwrite(ptCloud, fullfile(tempdir, "survey.pcd"), Encoding="compressed");
```

### Read Ibeo IDC file

```matlab
reader = ibeoLidarReader("sensor_data.idc");
fprintf("Message types: %s\n", strjoin(reader.MessageTypes, ", "));
fprintf("Total messages: %d\n", reader.NumMessages);

% Read all messages — returns array of pointCloud objects
ptClouds = readMessages(reader);

% Two-output form: get message metadata (timestamps, labels, plane info)
[ptClouds, messageData] = readMessages(reader);

% Filter by message type: "Scan" or "PointCloudPlane"
ptClouds = readMessages(reader, Messages="Scan");

% Filter by time range
tStart = reader.FileInfo.TimeStamps{1}(1);
tEnd = tStart + seconds(10);
ptClouds = readMessages(reader, Time=[tStart tEnd]);
```

**ibeoLidarReader key details:**
- Supports IDC files from Ibeo FUSION SYSTEM/ECU sensors
- Two message types: `"Scan"` (data type 0x2205) and `"PointCloudPlane"` (data type 0x7510)
- `readMessages` returns an array of `pointCloud` objects (one per message)
- Second output `messageData` is a cell array of structs with `MessageType`, `TimeStamp`, and (for PointCloudPlane) `Label`, `ReferencePoint`, `PlaneOrientation`
- `FileInfo` property is a table with columns: MessageType, DataType, Description, NumMessages, TimeStamps
- All properties are read-only

## Conventions

- Use `tempdir` for output paths in examples and tests to avoid permission issues
- Default to `Encoding="binary"` for PLY and omit encoding for PCD (default compressed is best)
- Always use double-quoted strings (`"text"`) and `Name=Value` syntax — never character vectors or `'Name','Value'` pairs
- Include file extension explicitly in filename — format is determined from extension
- PLY flattens organized M-by-N-by-3 to unorganized M-by-3; use PCD to preserve organized structure
- NaN/Inf values are skipped when writing to PLY
- `lasFileWriter` only supports unorganized `pointCloud` objects

## References

| Load when... | Reference |
|---|---|
| Reading or writing LAS/LAZ files, need filtering NV-pairs, attribute details, or writer properties | [references/quick-ref/las-io.md](references/quick-ref/las-io.md) |
| Reading PCAP files from Velodyne, Ouster, or Hesai sensors | [references/quick-ref/pcap-readers.md](references/quick-ref/pcap-readers.md) |

----
Copyright 2026 The MathWorks, Inc.
----
