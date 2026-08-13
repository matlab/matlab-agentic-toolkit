# scenariobuilder.GPSData — Detailed API

Stores GPS data with timestamps for scenario generation.
**Requires:** Scenario Builder for Automated Driving Toolbox support package.

## Constructor Syntax

```matlab
gpsData = scenariobuilder.GPSData
gpsData = scenariobuilder.GPSData(timestamps, latitude, longitude, altitude)
gpsData = scenariobuilder.GPSData(rosbag, topic)
gpsData = scenariobuilder.GPSData(___, Name=Value)
```

## Input Arguments

| Argument | Description | Data Type |
|----------|-------------|-----------|
| `timestamps` | Time of collection. If numeric, units are seconds. | N-element numeric vector, `datetime` array, or `duration` array |
| `latitude` | Latitude coordinates (degrees). | N-element numeric column vector |
| `longitude` | Longitude coordinates (degrees). | N-element numeric column vector |
| `altitude` | Altitude coordinates (meters). | N-element numeric column vector |
| `rosbag` | Filename or reader object for ROS/ROS 2 bags. | String, char, `BagSelection`, or `ros2bagreader` |
| `topic` | Specific topic name within the rosbag. | String or char |

## Name-Value Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `Name` | Name of the GPS sensor. | `''` |
| `Attributes` | Optional GPS attributes (e.g., velocity, speed) recorded at each timestamp. | `[]` |

## Properties

| Property | Access | Description |
|----------|--------|-------------|
| `Name` | Read/Write | Name of the GPS sensor. |
| `NumSamples` | Read-only | Number of waypoint samples. |
| `Duration` | Read-only | Total time duration (seconds). |
| `SampleRate` | Read-only | Mean sample rate (Hz). |
| `SampleTime` | Read-only | Mean sample time (seconds). |
| `Timestamps` | Read-only* | Timestamps of the GPS data. |
| `Latitude` | Read-only* | Latitude coordinates (degrees). |
| `Longitude` | Read-only* | Longitude coordinates (degrees). |
| `Altitude` | Read-only* | Altitude coordinates (meters). |
| `Attributes` | Read/Write | N-by-1 array of additional GPS attributes. |

*Read-only after object creation.

## Object Functions

| Method | Description |
|--------|-------------|
| `convertTimestamps` | Converts the format of stored timestamps. Introduced R2025b. |

## Examples

```matlab
% Create from arrays
gpsData = scenariobuilder.GPSData(timestamps, lat, lon, alt);

% Create from ROS bag
gpsData = scenariobuilder.GPSData("myFile.bag", "/gps/fix");
```


----

Copyright 2026 The MathWorks, Inc.

----
