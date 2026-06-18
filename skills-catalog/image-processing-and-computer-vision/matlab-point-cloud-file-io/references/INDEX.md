# Reference Index

**Quick-ref files contain critical gotchas. You MUST read the relevant quick-ref before writing code.**

## Function-Level Routing

| Function / Pattern | Quick-ref to read |
|--------------------|-------------------|
| `lasFileReader` | `quick-ref/las-io.md` |
| `lasFileWriter` | `quick-ref/las-io.md` |
| `readPointCloud` (on lasFileReader) | `quick-ref/las-io.md` |
| `writePointCloud` (on lasFileWriter) | `quick-ref/las-io.md` |
| `addVLR` | `quick-ref/las-io.md` |
| `velodyneFileReader` | `quick-ref/pcap-readers.md` |
| `ousterFileReader` | `quick-ref/pcap-readers.md` |
| `hesaiFileReader` | `quick-ref/pcap-readers.md` |
| `readFrame` / `hasFrame` | `quick-ref/pcap-readers.md` |
| `ibeoLidarReader` | Covered inline in SKILL.md |
| `readMessages` (on ibeoLidarReader) | Covered inline in SKILL.md |

## Task-Level Routing

| Trigger / task | Quick-ref to read |
|----------------|-------------------|
| Reading or writing LAS/LAZ files | `quick-ref/las-io.md` |
| Filtering by classification, ROI, or GPS time | `quick-ref/las-io.md` |
| Preserving lidar attributes through a read-write pipeline | `quick-ref/las-io.md` |
| Reading any PCAP file (Velodyne, Ouster, Hesai) | `quick-ref/pcap-readers.md` |
| Extracting specific frames from a PCAP recording | `quick-ref/pcap-readers.md` |
| Identifying the correct device model for a PCAP reader | `quick-ref/pcap-readers.md` |
| Reading Ibeo IDC files or using readMessages | Covered inline in SKILL.md |

----
Copyright 2026 The MathWorks, Inc.
----
