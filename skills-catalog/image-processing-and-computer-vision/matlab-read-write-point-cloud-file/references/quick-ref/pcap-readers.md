# PCAP File Readers Quick Reference

## Velodyne — velodyneFileReader

```matlab
reader = velodyneFileReader(fileName, deviceModel);
reader = velodyneFileReader(fileName, deviceModel, CalibrationFile=xmlPath, OrganizePoints=true);
```

| Device Model | Channels | Notes |
|---|---|---|
| `"VLP16"` | 16 | Most common low-cost sensor |
| `"PuckLITE"` | 16 | Lighter variant of VLP16 |
| `"PuckHiRes"` | 16 | Higher vertical resolution |
| `"VLP32C"` | 32 | Mid-range |
| `"HDL32E"` | 32 | Classic mid-range |
| `"HDL64E"` | 64 | High-density |
| `"VLS128"` | 128 | Top-of-line |
| `"VelarrayH800"` | — | Solid-state |

**Key Properties:** FileName, DeviceModel, CalibrationFile, NumberOfFrames, Duration, StartTime, EndTime, CurrentTime, Timestamps, OrganizePoints, HasPositionData

**Methods:** hasFrame, readFrame, reset

### Reading Frames

```matlab
reader = velodyneFileReader("lidarData_ConstructionRoad.pcap", "HDL32E");
while hasFrame(reader)
    ptCloud = readFrame(reader);
end

% Read specific frame by timestamp
frameTime = reader.Timestamps(10);
ptCloud = readFrame(reader, frameTime);
```

## Ouster — ousterFileReader

```matlab
reader = ousterFileReader(fileName, calibrationFile);
reader = ousterFileReader(fileName, calibrationFile, SkipPartialFrames=true, CoordinateFrame="center");
```

| Device Models | Notes |
|---|---|
| OS0-32/64/128 | Short-range, wide FOV |
| OS1-16/32/64/128 | Mid-range |
| OS2-32/64/128 | Long-range |
| OS Dome-32/64/128 | Hemispherical (R2025a+) |

**Key Properties:** FileName, CalibrationFile, DeviceModel (read-only, auto-detected), LidarMode, ReturnMode, FirmwareVersion, LidarUDPProfile, HasIMUData, NumberOfFrames, Duration, Timestamps, SkipPartialFrames, CoordinateFrame

**Methods:** hasFrame, readFrame, readIMU, reset

### Dual-Return Mode

When `ReturnMode` contains two entries (e.g., `{"strongest","weakest"}`), `readFrame` returns an N-by-2 pointCloud array. Index into column 1 for strongest return.

```matlab
reader = ousterFileReader("data.pcap", "calibration.json");
while hasFrame(reader)
    ptCloud = readFrame(reader);
    if size(ptCloud, 2) > 1
        ptCloud = ptCloud(:,1);  % strongest return
    end
end
```

### IMU Data

```matlab
if reader.HasIMUData
    imuData = readIMU(reader);
end
```

## Hesai — hesaiFileReader

```matlab
reader = hesaiFileReader(fileName, deviceModel);
reader = hesaiFileReader(fileName, deviceModel, CalibrationFile=csvPath, SkipPartialFrames=true);
```

| Device Model | Channels | Notes |
|---|---|---|
| `"Pandar128E3X"` | 128 | High-density |
| `"Pandar64"` | 64 | Mid-range |
| `"PandarQT"` | — | Short-range |
| `"PandarXT32"` | 32 | Compact |

**Key Properties:** FileName, DeviceModel, CalibrationFile, SkipPartialFrames, ReturnMode, NumberOfFrames, Duration, StartTime, EndTime, CurrentTime, Timestamps

**Methods:** hasFrame, readFrame, reset

## Common Patterns

### Extract first N frames from any PCAP

```matlab
N = 10;
frames = cell(1, N);
count = 0;
while hasFrame(reader) && count < N
    count = count + 1;
    frames{count} = readFrame(reader);
end
```

### Reset reader to re-read from beginning

```matlab
reset(reader);
```

## Gotchas

- Wrong calibration file for Ouster = reader returns zero frames silently
- `readFrame` returns `pointCloud`, not raw XYZ arrays
- `NumberOfFrames` is available immediately (from PCAP header scan)
- `Timestamps` gives the start time of each frame — use it for random access via `readFrame(reader, time)`
- Velodyne `OrganizePoints` defaults to `true` (organized output); Ouster/Hesai always produce organized output

----
Copyright 2026 The MathWorks, Inc.
----
