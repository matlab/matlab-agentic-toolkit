# Mixin Decision Tree

## Complete API Reference

| Class / Utility | Type | Purpose | Since |
|----------------|------|---------|-------|
| `matlab.io.Datastore` | Base class | Abstract base for all custom datastores | R2017b |
| `matlab.io.datastore.Partitionable` | Mixin | Add parallelization support (tall, parallel pools) | R2017b |
| `matlab.io.datastore.Subsettable` | Mixin | Add subset and fine-grained parallelization support (subsumes Partitionable + Shuffleable) | R2022b |
| `matlab.io.datastore.HadoopLocationBased` | Mixin | Add Hadoop/Spark support for HDFS data | R2017b |
| `matlab.io.datastore.Shuffleable` | Mixin | Add shuffling support for deep learning training | R2019b |
| `matlab.io.datastore.FileWritable` | Mixin | Add file writing support (`writeall`) | R2020a |
| `matlab.io.datastore.FoldersPropertyProvider` | Mixin | Add `Folders` property for folder-based access and writing | R2020a |
| `matlab.io.datastore.FileSet` | Utility | Whole-file collection management | R2020a |
| `matlab.io.datastore.BlockedFileSet` | Utility | Block-based file collection (fixed-size records within files) | R2020a |

## Required Methods Per Mixin

### matlab.io.Datastore (base)

**With `matlab.io.datastore.FileSet` (preferred):**

| Method | Access | Implementation | Required? |
|--------|--------|---------------|-----------|
| `hasdata` | public | `obj.CurrentFileIndex <= obj.FileSet.NumFiles` | Yes |
| `read` | public | Load from `obj.FileSet.FileInfo.Filename(CurrentFileIndex)`, advance index | Yes |
| `reset` | public | `obj.CurrentFileIndex = 1` | Yes |
| `progress` | Hidden | `(CurrentFileIndex-1) / obj.FileSet.NumFiles` | Yes |
| `copyElement` | protected | `copyElement@matlab.mixin.Copyable` + `copy(obj.FileSet)` | Yes — `readall` and `preview` always copy internally |

**With `matlab.io.datastore.BlockedFileSet` (fixed-size records):**

| Method | Access | Implementation | Required? |
|--------|--------|---------------|-----------|
| `hasdata` | public | `hasNextBlock(obj.BlockedFileSet)` | Yes |
| `read` | public | `nextblock` → custom read function (typically `fopen`/`fseek`/`fread` internally) | Yes |
| `reset` | public | `reset(obj.BlockedFileSet)` + reset block counter | Yes |
| `progress` | Hidden | `obj.CurrentBlockIndex / obj.TotalBlocks` (use own counter, not `NumBlocks`) | Yes |
| `copyElement` | protected | `copyElement@matlab.mixin.Copyable` + `copy(obj.BlockedFileSet)` | Yes — `readall` and `preview` always copy internally |

**Properties:**

| Property | Access | Description | Required? |
|----------|--------|-------------|-----------|
| `AlternateFileSystemRoots` | Dependent | Enables cross-platform portability of datastore across different file systems | Optional |
| `get.AlternateFileSystemRoots` | public | Getter — return `obj.FileSet.AlternateFileSystemRoots` | Only if `AlternateFileSystemRoots` is defined |
| `set.AlternateFileSystemRoots` | public | Setter — set on FileSet, then call `reset(obj)` | Only if `AlternateFileSystemRoots` is defined |

### matlab.io.datastore.Partitionable

| Method | Access | Implementation | Required? |
|--------|--------|---------------|-----------|
| `partition` | public | `copy(obj)` then `partition(obj.FileSet, n, idx)` then `reset` | Yes |
| `maxpartitions` | **protected** | `maxpartitions(obj.FileSet)` | Yes |

### matlab.io.datastore.HadoopLocationBased

| Method | Access | Implementation | Required? |
|--------|--------|---------------|-----------|
| `initializeDatastore` | Hidden | Rebuild FileSet from `info` struct (FileName, Offset, Size) | Yes |
| `getLocation` | Hidden | Return `obj.FileSet` | Yes |
| `isfullfile` | Hidden | `isequal(obj.FileSet.FileSplitSize, 'file')` | Optional |

### matlab.io.datastore.Shuffleable

| Method | Access | Implementation | Required? |
|--------|--------|---------------|-----------|
| `shuffle` | public | Copy self, randomize file order via permutation index | Yes |

With `FileSet`: create a new `FileSet` from the shuffled file list.
With `BlockedFileSet`: implement via a `BlockOrder` property holding a `randperm`
index vector for block indices.

### matlab.io.datastore.Subsettable

Use `Subsettable` on R2022b+ when you need to extract non-adjacent or specific
data slices by index, randomized shuffling, or parallel minibatch processing.
Requires that every data read can be accessed independently (i.e., you can jump
to any read by index without sequential iteration). If you only need basic
tall/parallel support, `Partitionable` is sufficient.

| Method | Access | Implementation | Required? |
|--------|--------|---------------|-----------|
| `maxpartitions` | **protected** | Return total number of independent reads (e.g., `obj.FileSet.NumFiles`) | Yes |
| `subsetByReadIndices` | **protected** | Copy self, keep only the reads at the given indices (e.g., rebuild FileSet from indexed file list) | Yes |

`Subsettable` provides `subset`, `partition`, and `shuffle` automatically based
on your `subsetByReadIndices` implementation — you do not implement those methods
yourself.

Note: `Subsettable` subsumes both `Partitionable` and `Shuffleable`. If using
`Subsettable`, do not also inherit from those two separately.

### matlab.io.datastore.FileWritable

| Property/Method | Access | Implementation | Required? |
|----------------|--------|---------------|-----------|
| `SupportedOutputFormats` | Constant | String array of format names | Yes |
| `DefaultOutputFormat` | Constant | Default format string | Yes |
| `write` | protected | Write data to custom format | Only if custom format (not built-in) |
| `getFiles` | public | Return file list | Only if no `Files` property |
| `getFolders` | protected | Return folder list | Only if no `Folders` property |
| `validateOutputLocation` | public | Custom validation of output path | Only if string validation is insufficient |
| `getCurrentFilename` | public | Return current file name during write | Only for multi-read-per-file datastores |
| `currentFileIndexComparator` | public | Compare file indices | Only for multi-read-per-file datastores |

**Parallel write support (`UseParallel` in `writeall`):**
Requires inheriting from both `matlab.io.datastore.FileWritable` AND
`matlab.io.datastore.Partitionable`, with a `partition` method that supports
the syntax `partition(ds, 'Files', index)`.

### matlab.io.datastore.FoldersPropertyProvider

Adds a `Folders` property for folder-based access and writing patterns. Useful when
data is organized hierarchically (e.g., class-per-folder for image classification)
or when the datastore needs write support via `writeall` with `FolderLayout`.

| Method/Property | Access | Implementation | Required? |
|----------------|--------|---------------|-----------|
| `Folders` | public (Dependent) | Return unique folder paths from file list | Provided by mixin |
| `set.Folders` | public | Filter files to only those in specified folders, then reset | Yes |

**Usage in constructor:**
```matlab
ds.Folders = populateFoldersFromLocation(ds, location);
```

Enables the `FolderLayout` name-value pair of `writeall` when combined with
`FileWritable`.

----

Copyright 2026 The MathWorks, Inc.

----
