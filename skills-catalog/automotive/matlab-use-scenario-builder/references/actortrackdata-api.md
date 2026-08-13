# scenariobuilder.ActorTrackData — Detailed API

Stores recorded actor track data with timestamps.
**Requires:** Scenario Builder for Automated Driving Toolbox support package. Introduced R2025a.

## Constructor Syntax

```matlab
trackData = scenariobuilder.ActorTrackData
trackData = scenariobuilder.ActorTrackData(timestamps, trackID, position)
trackData = scenariobuilder.ActorTrackData(timestamps, trackID, position, Name=Value)
```

## Input Arguments

| Argument | Description | Data Type |
|----------|-------------|-----------|
| `timestamps` | Timestamps of actor tracks. If numeric, units are seconds. | N-element numeric column vector, `datetime` array, or `duration` array |
| `trackID` | Track IDs of actors detected at each timestamp. | N-by-1 cell array; each cell is M-by-1 string array |
| `position` | Actor positions `[x, y, z]` relative to ego frame (meters). | N-by-1 cell array; each cell is M-by-3 numeric matrix |

## Name-Value Arguments

| Argument | Description | Data Type |
|----------|-------------|-----------|
| `Name` | Name of the recorded data. | String scalar (default: `''`) |
| `Category` | Actor types (e.g., `'car'`, `'truck'`). | N-by-1 cell array; cells contain M-by-1 string arrays |
| `Dimension` | Actor `[length, width, height]` in meters. | N-by-1 cell array; cells contain M-by-3 numeric matrices |
| `Orientation` | Actor `[yaw, pitch, roll]` in degrees. | N-by-1 cell array; cells contain M-by-3 numeric matrices |
| `Speed` | Actor speeds in m/s. | N-by-1 cell array; cells contain M-element numeric row vectors |
| `Age` | Number of times a track has been updated. | N-by-1 cell array; cells contain M-element row vectors of positive integers |
| `Velocity` | Actor `[vx, vy, vz]` in m/s. | N-by-1 cell array; cells contain M-by-3 numeric matrices |
| `Attributes` | Optional additional track attributes. | N-by-1 array |

## Properties

| Property | Access | Description |
|----------|--------|-------------|
| `Name` | Read/Write | Name of recorded actor track data. |
| `NumSamples` | Read-only | Number of actor track samples. |
| `Duration` | Read-only | Time duration of acquisition (seconds). |
| `SampleRate` | Read-only | Frequency of samples (Hz). |
| `SampleTime` | Read-only | Time interval between samples (seconds). |
| `Timestamps` | Read/Write | Timestamps of data samples. |
| `TrackID` | Read/Write | Cell array of track IDs per timestamp. |
| `Category` | Read/Write | Cell array of actor categories per timestamp. |
| `Position` | Read/Write | Cell array of actor positions per timestamp. |
| `Dimension` | Read/Write | Cell array of actor dimensions per timestamp. |
| `Orientation` | Read/Write | Cell array of actor orientations per timestamp. |
| `Velocity` | Read/Write | Cell array of actor velocities per timestamp. |
| `Speed` | Read/Write | Cell array of actor speeds per timestamp. |
| `Age` | Read/Write | Cell array of track ages per timestamp. |
| `Attributes` | Read/Write | Cell array of additional attributes per timestamp. |
| `UniqueTrackIDs` | Read-only | All unique track IDs in the object. |
| `UniqueCategories` | Read-only | All unique actor categories in the object. |

## Object Functions

| Method | Description |
|--------|-------------|
| `convertTimestamps` | Modify or sync timestamps within the object. |


----

Copyright 2026 The MathWorks, Inc.

----
