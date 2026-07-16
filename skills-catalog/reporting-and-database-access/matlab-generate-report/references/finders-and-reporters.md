# Simulink Report Generator: Finders and Reporters Reference

## Finders

Finders discover model content. All finders support `find(finder)` (returns array) and iterator pattern (`hasNext`/`next`).

### Diagram Finders

| Finder | Searches For | Key Properties | Result Class |
|--------|-------------|----------------|--------------|
| `SystemDiagramFinder` | System/subsystem block diagrams | `IncludeRoot`, `SearchDepth`, `IncludeReferencedModels`, `IncludeReferencedSubsystems`, `IncludeMaskedSubsystems`, `IncludeSimulinkLibraryLinks`, `IncludeUserLibraryLinks`, `IncludeCommented`, `IncludeVariants`, `AutoCloseModel`, `SortType` | `DiagramResult` |
| `DiagramFinder` | All block diagrams and charts (broader than SystemDiagramFinder) | `SearchDepth`, `IncludeMaskedSubsystems`, `IncludeReferencedModels`, `IncludeReferencedSubsystems`, `IncludeSimulinkLibraryLinks`, `IncludeUserLibraryLinks`, `IncludeCommented`, `IncludeVariants`, `AutoCloseModel`, `SortType` | `DiagramResult` |
| `ChartDiagramFinder` | Stateflow charts only | (inherits from DiagramFinder) | `DiagramResult` |

**When to use which:**
- `SystemDiagramFinder` — most common; finds subsystem diagrams with filtering. Use for "all subsystems" reports.
- `DiagramFinder` — broader; includes Stateflow charts as diagrams. Use when you need both Simulink and Stateflow diagrams.
- `ChartDiagramFinder` — Stateflow charts only. Use when reporting exclusively on charts.

#### SystemDiagramFinder Filter Properties

All properties default to `true` unless noted:

| Property | Default | Purpose |
|----------|---------|---------|
| `IncludeRoot` | `true` | Include root-level diagram |
| `SearchDepth` | `Inf` | How deep to search (`0` = root only) |
| `IncludeReferencedModels` | `true` | Include diagrams from Model Reference blocks |
| `IncludeReferencedSubsystems` | `true` | Include subsystem reference blocks |
| `IncludeMaskedSubsystems` | `true` | Include masked subsystems |
| `IncludeSimulinkLibraryLinks` | `true` | Include Simulink library-linked blocks |
| `IncludeUserLibraryLinks` | `true` | Include user library-linked blocks |
| `IncludeCommented` | `false` | Include commented-out subsystems |
| `IncludeVariants` | `"Active"` | `"Active"`, `"All"`, or `"None"` |
| `AutoCloseModel` | `true` | Close referenced models after processing |
| `SortType` | `"none"` | `"none"` or `"alphabetical"` |

Set `IncludeReferencedModels = false` when you only want subsystems of the top model (avoids returning `block_diagram` objects that lack subsystem properties like `IsSubsystemVirtual`).

### Block and Element Finders

| Finder | Searches For | Key Properties | Result Class |
|--------|-------------|----------------|--------------|
| `BlockFinder` | Blocks by type/properties | `BlockTypes`, `SearchDepth` (default=1), `IncludeCommented`, `IncludeVariants`, `ConnectedSignal`, `SortType` | `BlockResult` |
| `DiagramElementFinder` | All elements in a diagram (blocks, annotations, lines) | `Types`, `SearchDepth`, `IncludeCommented`, `IncludeVariants`, `SortType` | `DiagramElementResult` |
| `AnnotationFinder` | Block diagram annotations | `SearchDepth`, `SortType` | `AnnotationResult` |

**When to use which:**
- `BlockFinder` — find specific block types or get block positions/properties. Default `SearchDepth=1` (immediate children only).
- `DiagramElementFinder` — everything in a diagram (blocks + annotations + lines). Use for comprehensive element reporting.
- `AnnotationFinder` — annotation text only. Use when documenting model notes.

### Stateflow Finders

| Finder | Searches For | Key Properties | Result Class |
|--------|-------------|----------------|--------------|
| `StateFinder` | States in a Stateflow chart | `SearchDepth`, `IncludeCommented`, `SortType` | (state results) |
| `StateflowDiagramElementFinder` | Graphical elements of a Stateflow chart | (similar to DiagramElementFinder) | (diagram element results) |
| `StateflowObjectFinder` | Any Stateflow objects (states, transitions, data, events) | `Types`, `SearchDepth`, `IncludeCommented`, `SortType`, `AdditionalFilterProperties` | `StateflowObjectResult` |

**When to use which:**
- `StateFinder` — states only. Use for state documentation.
- `StateflowDiagramElementFinder` — graphical elements (states, transitions, junctions). Use for visual element reporting.
- `StateflowObjectFinder` — broadest; includes non-graphical objects (data, events). Use `Types` to filter. Use `AdditionalFilterProperties` for custom filtering.

### Data and Variable Finders

| Finder | Searches For | Key Properties | Result Class |
|--------|-------------|----------------|--------------|
| `ModelVariableFinder` | Variables used by a model | `Name`, `Regexp`, `SourceType`, `Users`, `SearchMethod`, `SearchReferencedModels`, `LookUnderMasks`, `FollowLibraryLinks` | `ModelVariableResult` |
| `DataDictionaryFinder` | Simulink data dictionaries | `Name` | `DataDictionaryResult` |
| `EnumerationTypeFinder` | Enumerated types used by a model | `Name`, `SourceType`, `Users`, `Regexp`, `SearchMethod`, `SearchReferencedModels` | `EnumerationTypeResult` |
| `SignalFinder` | Signals in a model/system | `IncludeInputSignals`, `IncludeOutputSignals`, `IncludeControlSignals`, `IncludeInternalSignals`, `IncludeVirtualBlockSignals`, `IncludeUnnamedSignals`, `SearchDepth`, `SortType` | `SignalResult` |
| `FunctionReferenceFinder` | Functions used to calculate block parameters | `FunctionType`, `SearchDepth`, `SearchReferencedModels`, `LookUnderMasks`, `FollowLibraryLinks` | `FunctionReferenceResult` |

**When to use which:**
- `ModelVariableFinder` — document workspace variables, base workspace, data dictionaries. Use `SourceType` to filter by source.
- `SignalFinder` — document signals with properties. Use for signal-level documentation. For I/O summary prefer `SystemIO` reporter.
- `DataDictionaryFinder` — find data dictionaries attached to a model.
- `EnumerationTypeFinder` — document enum types used in the model.
- `FunctionReferenceFinder` — find MATLAB functions referenced by block parameters.

## Result Classes

| Result Class | Key Properties | From Finder |
|-------------|----------------|-------------|
| `DiagramResult` | `Path`, `Object`, `Name`, `Type`, `Tag` | `SystemDiagramFinder`, `DiagramFinder`, `ChartDiagramFinder` |
| `BlockResult` | `BlockPath`, `Object`, `Name`, `Type`, `DiagramPath`, `Tag` | `BlockFinder` |
| `DiagramElementResult` | `Path`, `Object`, `Name`, `Type`, `Tag` | `DiagramElementFinder` |
| `AnnotationResult` | `Object`, `Name`, `Tag` | `AnnotationFinder` |
| `SignalResult` | `Object`, `Name`, `Tag` | `SignalFinder` |
| `ModelVariableResult` | `Variable`, `Name`, `Tag` | `ModelVariableFinder` |
| `DataDictionaryResult` | `Object`, `Name`, `Tag` | `DataDictionaryFinder` |
| `EnumerationTypeResult` | `Object`, `Name`, `Tag` | `EnumerationTypeFinder` |
| `FunctionReferenceResult` | `Object`, `Name`, `Tag` | `FunctionReferenceFinder` |
| `StateflowObjectResult` | `Object`, `Name`, `Tag` | `StateflowObjectFinder` |

All results support `getReporter(result)` to get a specialized reporter matched to the content type.

## Reporters

### Diagram Reporters

| Reporter | Reports | Input | Notes |
|----------|---------|-------|-------|
| `Diagram` | Snapshot of a block diagram or Stateflow chart | System path or handle | Use `Snapshot.ScaleToFit = true` for page-fitting. Set `TemplateSrc` for centering. |
| `ElementDiagram` | Snapshot of a single element (block, state) | Element path or handle | Highlights the element in context |
| `ScheduleDiagram` | Model schedule and legend | Model name | Shows task scheduling |
| `ScopeSnapshot` | Snapshot of scope blocks | Scope block path | Captures current scope display |
| `Notes` | Notes associated with a diagram | System path | Reports annotation-style notes |

### Block Content Reporters

| Reporter | Reports | Input | Requires Compilation |
|----------|---------|-------|---------------------|
| `LookupTable` | Breakpoints, output points, and plot | Lookup table block path | No |
| `MATLABFunction` | Script content of MATLAB Function block | Block path | No |
| `MATLABSystem` | System object used by MATLAB System block | Block path | No |
| `CCaller` | Function name, available functions, port properties | C Caller block path | No |
| `CFunction` | C code and symbols | C Function block path | No |
| `DocBlock` | Content or link to DocBlock content | DocBlock path | No |
| `TestSequence` | Symbols and steps | Test Sequence block path | No |
| `TruthTable` | Condition and action tables | Truth table path | No |
| `StateTransitionTable` | Symbols and state transitions | State Transition Table path | No |

### System-Level Reporters

| Reporter | Reports | Input | Requires Compilation |
|----------|---------|-------|---------------------|
| `SystemIO` | Input/output signal summary tables | System path | Yes |
| `ExecutionOrder` | Block execution order by task | Model or nonvirtual subsystem path | Yes |
| `SystemHierarchy` | Descendant/ancestor/peer list | Model or system path | No |
| `Bus` | Bus details (signals, hierarchy, connected blocks) | Bus creator/selector block path | No |
| `BusObject` | Properties of a `Simulink.Bus` object | Bus object name | No |
| `ModelConfiguration` | Active configuration set | Model name | No |

### Property/Object Reporters

| Reporter | Reports | Input | Notes |
|----------|---------|-------|-------|
| `SimulinkObjectProperties` | Property table for any Simulink object | Block/model path or handle | Default reporter for most blocks via `getReporter` |
| `StateflowObjectProperties` | Property table for Stateflow objects | Stateflow object | Returned by `getReporter` on Stateflow finder results |
| `Annotation` | Annotation content and properties | Annotation object | From `AnnotationFinder` results |

### Data Reporters

| Reporter | Reports | Input | Notes |
|----------|---------|-------|-------|
| `Signal` | Signal properties | Signal object or path | From `SignalFinder` results |
| `ModelVariable` | Variable properties and usage | Variable result | From `ModelVariableFinder` results. Use `ShowUsedBy` to include blocks that use it. |
| `DataDictionary` | Dictionary entries | Dictionary path | From `DataDictionaryFinder` results |
| `EnumerationType` | Enum type properties | Enum type result | From `EnumerationTypeFinder` results |
| `FunctionReference` | How a function is used in the model | Function reference result | From `FunctionReferenceFinder` results |

### Aggregation Reporter

| Reporter | Reports | Input | Notes |
|----------|---------|-------|-------|
| `SummaryTable` | Table summarizing finder results | Finder result array | Use `Properties` to select columns. `SeparateTablesByType` groups by block type. Works with any finder results. |

## Finder-to-Reporter Mapping via `getReporter`

When you call `getReporter(result)` on a finder result, it returns a **specialized** reporter:

| Block/Element Type | Reporter Returned |
|--------------------|------------------|
| Lookup Table (1-D, 2-D, n-D) | `LookupTable` |
| MATLAB Function | `MATLABFunction` |
| MATLAB System | `MATLABSystem` |
| C Caller | `CCaller` |
| C Function | `CFunction` |
| DocBlock | `DocBlock` |
| Truth Table | `TruthTable` |
| Test Sequence | `TestSequence` |
| State Transition Table | `StateTransitionTable` |
| Stateflow elements | `StateflowObjectProperties` |
| All other blocks | `SimulinkObjectProperties` |

**Always use `getReporter(result)` on finder results** instead of constructing reporters manually — you get the specialized reporter automatically.

## Utility Functions

| Function | Purpose |
|----------|---------|
| `slreportgen.utils.isSimulinkFunction(handle)` | Returns `true` if the block is a Simulink Function — guard `SystemIO`/`ExecutionOrder` |
| `slreportgen.utils.isMATLABFunction(handle)` | Returns `true` if the block is a MATLAB Function block (internally a SubSystem with Stateflow content) |

**Finding MATLAB Function blocks:** `BlockFinder` cannot search for them by type (they are `SubSystem` internally). Use `BlockFinder` with `BlockTypes = "SubSystem"` + filter with `isMATLABFunction`:

```matlab
bf = slreportgen.finder.BlockFinder(systemHandle);
bf.BlockTypes = "SubSystem";
bf.SearchDepth = 1;
while bf.hasNext()
    result = bf.next();
    if slreportgen.utils.isMATLABFunction(result.Object)
        append(sec,slreportgen.report.MATLABFunction(result.BlockPath));
    end
end
```

## Key Conventions

- **Do NOT use `find_system`** for content that finders provide — finders handle referenced models, Stateflow, masked subsystems, and variants correctly
- **`BlockFinder.SearchDepth` defaults to 1** — set to `inf` for full-depth traversal within one system
- **`BlockFinder` does NOT traverse referenced models** — combine with `SystemDiagramFinder` (`IncludeReferencedModels=true`) for full hierarchy (see [simulink-report.md](simulink-report.md))
- **Use `.Object` handle** from results for `get_param` calls (not path strings)
- **`SummaryTable`** works with results from any finder — use it for overview tables
- **`SystemIO` and `ExecutionOrder` require compilation** — the `slreportgen.report.Report` container handles this automatically, but they will error with `mlreportgen.report.Report`

----

Copyright 2026 The MathWorks, Inc.

----
