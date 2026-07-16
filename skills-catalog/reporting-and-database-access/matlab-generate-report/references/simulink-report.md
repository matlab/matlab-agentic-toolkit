# Simulink Report Generation

Generate structured reports from Simulink models using finders to extract model content and reporters to format it.

---

## Core Concepts

### Direct Reporters (known path)

When you know the system or block path, construct the reporter directly:

```matlab
append(ch,slreportgen.report.Diagram("model/Subsystem"));
append(ch,slreportgen.report.SystemIO("model/Subsystem"));
append(ch,slreportgen.report.ExecutionOrder(modelName));
append(ch,slreportgen.report.LookupTable(blockPath));
```

### Finder Pattern (discovery)

When you need to discover content (all subsystems, all blocks of a type), use finders:

```matlab
finder = slreportgen.finder.SystemDiagramFinder(modelName);
results = find(finder);
for i = 1:numel(results)
    append(chapter,results(i));
end
```

Use `getReporter(result)` instead of constructing reporters manually — returns a specialized reporter matched to the block type.

---

## Workflow

1. **Load the model** — `load_system(modelName)`
2. **Create the report** — always use `slreportgen.report.Report` (not `mlreportgen.report.Report`)
3. **Add structure** — TitlePage, TableOfContents, Chapter, Section from `mlreportgen.report.*`
4. **Use finders** — extract diagrams, blocks, or other content from the model
5. **Append results** — append finder results (or reporters) to chapters/sections
6. **Close** — `close(rpt)` generates the output file

```matlab
load_system(modelName);

rpt = slreportgen.report.Report(outputPath,"pdf");
append(rpt,mlreportgen.report.TitlePage("Title","Model Report"));
append(rpt,mlreportgen.report.TableOfContents());

ch = mlreportgen.report.Chapter("Title","Diagrams");
append(rpt,ch);
close(rpt);
```

**Why `slreportgen.report.Report`?** It extends `mlreportgen.report.Report` with model compilation support. Reporters like `SystemIO` and `ExecutionOrder` require compilation — they error with the base class.

---

## Patterns

### Root Diagram + All Subsystems

Use a **direct reporter** for the root (known path). Use `SystemDiagramFinder` for subsystems. **Always use the iterator pattern** (`hasNext`/`next`) — never `find()` + for loop. The iterator enables `AutoCloseModel` to close each model after processing and avoids holding all results in memory.

```matlab
% Root diagram — direct reporter
rootDiag = slreportgen.report.Diagram(modelName);
rootDiag.Snapshot.ScaleToFit = true;
append(rootChapter,rootDiag);

% All subsystems, sorted alphabetically — iterator pattern
subFinder = slreportgen.finder.SystemDiagramFinder(modelName);
subFinder.IncludeRoot = false;
subFinder.SortType = "alphabetical";

while subFinder.hasNext()
    subResult = subFinder.next();
    sec = mlreportgen.report.Section("Title",subResult.Name);
    append(sec,subResult);
    append(subsysChapter,sec);
end
```

### Single-Pass: All Diagrams via SystemDiagramFinder

When all diagrams receive uniform treatment, use a single finder with `IncludeRoot = true`:

```matlab
finder = slreportgen.finder.SystemDiagramFinder(modelName);
finder.IncludeRoot = true;
finder.SortType = "alphabetical";

while finder.hasNext()
    result = finder.next();
    sec = mlreportgen.report.Section("Title",result.Name);
    d = getReporter(result);
    d.Snapshot.ScaleToFit = true;
    append(sec,d);
    append(ch,sec);
end
```

### SystemDiagramFinder Filter Properties

Key defaults: `IncludeRoot=true`, `SearchDepth=Inf`, `IncludeReferencedModels=true`, `SortType="none"`, `IncludeCommented=false`, `IncludeVariants="Active"`.

Set `IncludeReferencedModels = false` when you only want subsystems of the top model (avoids returning `block_diagram` objects that lack `IsSubsystemVirtual`).

See [finders-and-reporters.md](finders-and-reporters.md) for the full property table.

---

## Per-Diagram Page Orientation

### Computing Orientation

```matlab
function orientation = getSystemOrientation(systemHandle)
    arguments
        systemHandle (1,1) double
    end
    orientation = "portrait";
    try
        finder = slreportgen.finder.BlockFinder(systemHandle);
        finder.SearchDepth = 1;
        results = find(finder);
        if isempty(results), return; end
        positions = cell2mat(arrayfun( ...
            @(r) get_param(r.Object,"Position"),results,"UniformOutput",false)');
        width = max(positions(:,3))-min(positions(:,1));
        height = max(positions(:,4))-min(positions(:,2));
        if width > height  % strictly wider → landscape; equal or taller → portrait
            orientation = "landscape";
        end
    catch
    end
end
```

### PDF Orientation

Clone the chapter's template `PDFPageLayout` (via `getImpl`) for each page break. Call `rotate(pl)` for landscape.

**Critical rules:**
- Never use a bare `PDFPageLayout` — it has NO headers/footers. Always clone from the chapter template.
- Never append `PDFPageLayout` as first item in a chapter (blank page) — put content first.
- Set `pl.FirstPageNumber = ''` to continue numbering; remove first-page header; inject `CustomElement("fo:marker")` to restore chapter title in headers.
- `ch.Layout.Landscape` controls the *first* page only.

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

ch = Chapter("Title",modelName);

% Extract the chapter's template layout (has headers/footers/rules)
tempRpt = Report(fullfile(tempdir,"tmp_layout"),"pdf");
tempCh = Chapter("Title","tmp");
open(tempRpt);
docPart = getImpl(tempCh,tempRpt);
chLayout = docPart.Children(1);  % PDFPageLayout with headers/footers
close(tempRpt);

% Root diagram — fills chapter's initial page
rootOrientation = getSystemOrientation(get_param(modelName,"Handle"));
ch.Layout.Landscape = (rootOrientation == "landscape");
rootDiag = slreportgen.report.Diagram(modelName);
rootDiag.Snapshot.ScaleToFit = true;
append(ch,rootDiag);

% Subsystems — clone layout for each page break
subFinder = slreportgen.finder.SystemDiagramFinder(modelName);
subFinder.IncludeRoot = false;
subFinder.SortType = "alphabetical";

chapterTitle = "Chapter 1. " + modelName;

while subFinder.hasNext()
    subResult = subFinder.next();

    pl = clone(chLayout);
    orientation = getSystemOrientation(subResult.Object);
    if orientation == "landscape"
        rotate(pl);
    end
    pl.FirstPageNumber = '';

    % Remove first-page header (empty — hides StyleRef)
    firstIdx = strcmp({pl.PageHeaders.PageType},"first");
    pl.PageHeaders = pl.PageHeaders(~firstIdx);
    append(ch,pl);

    % Re-inject chapter title marker for header StyleRef
    marker = CustomElement("fo:marker");
    marker.CustomAttributes = CustomAttribute("marker-class-name","SectionTitle1");
    append(marker,Text(chapterTitle));
    anchor = Paragraph();
    anchor.Style = {FontSize("1pt"),OuterMargin("0pt","0pt","0pt","0pt"),...
        LineSpacing(0.01),Color("white")};
    append(anchor,marker);
    append(ch,anchor);

    sec = Section("Title",subResult.Name);
    d = getReporter(subResult);
    d.Snapshot.ScaleToFit = true;
    append(sec,d);
    append(ch,sec);
end
```

#### Variant: Introductory Content Before Diagrams

When text appears before diagrams, keep chapter in portrait and give the root diagram its own `PDFPageLayout`:

```matlab
ch.Layout.Landscape = false;  % Portrait for intro text

introSec = Section("Title","Introduction");
append(introSec,Paragraph("This report documents the " + modelName + " model."));
append(ch,introSec);

% Root diagram gets its OWN PDFPageLayout
rootPl = clone(chLayout);
rootOrientation = getSystemOrientation(get_param(modelName,"Handle"));
if rootOrientation == "landscape"
    rotate(rootPl);
end
rootPl.FirstPageNumber = '';
firstIdx = strcmp({rootPl.PageHeaders.PageType},"first");
rootPl.PageHeaders = rootPl.PageHeaders(~firstIdx);
append(ch,rootPl);

% Re-inject marker (same pattern as subsystems)...
```

### Word (.docx) Orientation

Much simpler than PDF — no cloning, markers, or `FirstPageNumber` needed:

```matlab
while finder.hasNext()
    result = finder.next();
    orientation = getSystemOrientation(result.Object);

    if orientation == "landscape"
        pl = DOCXPageLayout();
        pl.PageSize.Orientation = "landscape";
        pl.PageSize.Height = "8.5in";
        pl.PageSize.Width = "11in";
    else
        pl = DOCXPageLayout();
        pl.PageSize.Orientation = "portrait";
        pl.PageSize.Height = "11in";
        pl.PageSize.Width = "8.5in";
    end
    append(ch,pl);

    sec = Section("Title",result.Name);
    d = getReporter(result);
    d.Snapshot.ScaleToFit = true;
    append(sec,d);
    append(ch,sec);
end
```

Word section breaks preserve headers and numbering automatically. Always use `rptview(rpt)` to view Word output.

---

## Centering Diagram Output

Reporters cannot be wrapped in DOM elements for centering. Customize the `DiagramImage` style in the Diagram template. Create once at script start, set `TemplateSrc` on every Diagram reporter.

### PDF Centering

```matlab
import mlreportgen.dom.*

srcPath = fullfile(tempdir,"diagram_src.pdftx");
slreportgen.report.Diagram.createTemplate(srcPath,"pdf");
centeredTemplatePath = fullfile(tempdir,"centered_diagram.pdftx");
tpl = Template(centeredTemplatePath,"pdf",srcPath);
open(tpl);
diagStyle = getStyle(tpl.Stylesheet,"DiagramImage");
diagStyle.RawFormats = strtrim(diagStyle.RawFormats) + " text-align: center;";
replaceStyle(tpl.Stylesheet,diagStyle);
close(tpl);
```

### Word Centering

```matlab
import mlreportgen.dom.*

srcPath = fullfile(tempdir,"diagram_src.dotx");
slreportgen.report.Diagram.createTemplate(srcPath,"docx");
centeredTemplatePath = fullfile(tempdir,"centered_diagram.dotx");
tpl = Template(centeredTemplatePath,"docx",srcPath);
open(tpl);
% CRITICAL: Create fresh TemplateLinkedStyle — do NOT mutate TemplateDOCXStyle from getStyle
ss = tpl.Stylesheet;
for styleName = ["DiagramImage","DiagramCaption"]
    newStyle = TemplateLinkedStyle(styleName);
    newStyle.Formats = [HAlign("center")];
    replaceStyle(ss,newStyle);
end
close(tpl);
```

### Centering Summary

| Aspect | PDF | Word |
|--------|-----|------|
| Template extension | `.pdftx` | `.dotx` |
| Style type | `TemplatePDFStyle` | `TemplateLinkedStyle` (fresh) |
| How to center | `RawFormats` += `" text-align: center;"` | `Formats = [HAlign("center")]` |
| Style names | `DiagramImage` | `DiagramImage` AND `DiagramCaption` |

**Then apply:** `d.TemplateSrc = centeredTemplatePath;`

**Verifying Word centering:** Word applies centering via style reference, not inline. Check `styles.xml` (inside the unzipped DOCX) for `<w:jc w:val="center"/>` inside the `DiagramImage` style definition. In `document.xml`, paragraphs reference the style by name (`w:val="DiagramImage"`) — you won't find `w:jc` inline in the body.

---

## System I/O Documentation

`SystemIO` reports inputs and outputs. Requires model compilation. Guard against Simulink Functions:

```matlab
finder = slreportgen.finder.SystemDiagramFinder(modelName);
finder.IncludeRoot = false;
finder.IncludeReferencedModels = false;

while finder.hasNext()
    result = finder.next();
    if slreportgen.utils.isSimulinkFunction(result.Object), continue; end
    sec = mlreportgen.report.Section("Title",result.Name + " I/O");
    append(sec,slreportgen.report.SystemIO(result.Path));
    append(chapter,sec);
end
```

---

## Execution Order with Guards

`ExecutionOrder` only works on root model and nonvirtual subsystems. **Two guards required:**

```matlab
while finder.hasNext()
    result = finder.next();
    if slreportgen.utils.isSimulinkFunction(result.Object), continue; end
    if strcmp(get_param(result.Object,'IsSubsystemVirtual'),'on'), continue; end
    append(sec,slreportgen.report.ExecutionOrder(result.Path));
end
```

Set `IncludeReferencedModels = false` to avoid `block_diagram` objects that lack `IsSubsystemVirtual`.

---

## LookupTable with Page-Fitting Plot

```matlab
lutReporter = slreportgen.report.LookupTable(blockPath);
lutReporter.PlotReporter.Snapshot.ScaleToFit = true;
append(chapter,lutReporter);
```

---

## Property Table Customization

Use `getReporter(result)` to get a `SimulinkObjectProperties` reporter. Use a **nested function** (not local) for `TableEntryUpdateFcn`:

```matlab
function generateCompactReport(modelName,outputPath)
    arguments
        modelName (1,1) string
        outputPath (1,1) string
    end

    load_system(modelName);
    rpt = slreportgen.report.Report(outputPath,"html");
    ch = mlreportgen.report.Chapter("Title","Block Properties");

    finder = slreportgen.finder.BlockFinder(modelName);
    finder.SearchDepth = 1;
    results = find(finder);

    for i = 1:numel(results)
        sec = mlreportgen.report.Section("Title",results(i).Name);
        reporter = getReporter(results(i));
        if isa(reporter,"slreportgen.report.SimulinkObjectProperties")
            reporter.PropertyTable.TableEntryUpdateFcn = @compactEntry;
        end
        append(sec,reporter);
        append(ch,sec);
    end

    append(rpt,ch);
    close(rpt);

    % Nested function — executes in getImpl scope reliably
    function entry = compactEntry(entry)
        for k = 1:numel(entry.Children)
            child = entry.Children(k);
            if isa(child,"mlreportgen.dom.Paragraph")
                child.Style = [child.Style, ...
                    {mlreportgen.dom.OuterMargin("0pt","0pt","0pt","0pt")}];
            end
        end
    end
end
```

**Why nested functions?** Local functions can silently fail during `getImpl`. For scripts, save the callback as a standalone `.m` file on the path.

---

## Stateflow Chart Reporting

Use `ChartDiagramFinder` to discover Stateflow charts. **Always use `getReporter(result)`** — never construct `Diagram(result.Path)` directly, as chart finder results may contain paths that are invalid for the `Diagram` constructor.

```matlab
chartFinder = slreportgen.finder.ChartDiagramFinder(modelName);

while chartFinder.hasNext()
    result = chartFinder.next();
    sec = mlreportgen.report.Section("Title",result.Name);
    chartReporter = getReporter(result);
    chartReporter.Snapshot.ScaleToFit = true;
    append(sec,chartReporter);
    append(ch,sec);
end
```

### Stateflow Chart Elements (States, Transitions)

For detailed chart element reporting, use `DiagramElementFinder` on a known chart path:

```matlab
sfFinder = slreportgen.finder.DiagramElementFinder(chartPath);
sfResults = find(sfFinder);
for i = 1:numel(sfResults)
    append(sec,getReporter(sfResults(i)));
end
```

---

## Finding Blocks Across Referenced Models

`BlockFinder` does **not** have `IncludeReferencedModels` — it only searches within its container system. To find specific block types across the entire model hierarchy (including referenced models), combine `SystemDiagramFinder` with per-system `BlockFinder`:

```matlab
% Find all Lookup_n-D blocks including those in referenced models
allSysFinder = slreportgen.finder.SystemDiagramFinder(modelName);
allSysFinder.IncludeRoot = true;
allSysFinder.IncludeReferencedModels = true;

while allSysFinder.hasNext()
    sysResult = allSysFinder.next();
    bf = slreportgen.finder.BlockFinder(sysResult.Object);
    bf.BlockTypes = "Lookup_n-D";
    bf.SearchDepth = 1;
    while bf.hasNext()
        result = bf.next();
        lutReporter = slreportgen.report.LookupTable(result.BlockPath);
        lutReporter.PlotReporter.Snapshot.ScaleToFit = true;
        append(ch,lutReporter);
    end
end
```

### Finding MATLAB Function Blocks

MATLAB Function blocks are internally `SubSystem` blocks — `BlockFinder` cannot search for them by type. Use `BlockFinder` for `SubSystem` + `slreportgen.utils.isMATLABFunction` to identify them:

```matlab
allSysFinder = slreportgen.finder.SystemDiagramFinder(modelName);
allSysFinder.IncludeRoot = true;
allSysFinder.IncludeReferencedModels = true;

while allSysFinder.hasNext()
    sysResult = allSysFinder.next();
    bf = slreportgen.finder.BlockFinder(sysResult.Object);
    bf.BlockTypes = "SubSystem";
    bf.SearchDepth = 1;
    while bf.hasNext()
        result = bf.next();
        if slreportgen.utils.isMATLABFunction(result.Object)
            append(ch,slreportgen.report.MATLABFunction(result.BlockPath));
        end
    end
end
```

---

## Signal Documentation

Use `SignalFinder` to document named signals. Filter with `IncludeUnnamedSignals = false` to focus on intentionally named signals:

```matlab
sigFinder = slreportgen.finder.SignalFinder(modelName);
sigFinder.IncludeUnnamedSignals = false;
sigResults = find(sigFinder);

for i = 1:numel(sigResults)
    sigName = string(sigResults(i).Name);
    % Use getReporter for detailed signal documentation
    append(sec,getReporter(sigResults(i)));
end
```

`SignalFinder` key properties: `IncludeInputSignals`, `IncludeOutputSignals`, `IncludeControlSignals`, `IncludeInternalSignals`, `IncludeVirtualBlockSignals`, `IncludeUnnamedSignals`, `SearchDepth`, `SortType`.

---

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Using `mlreportgen.report.Report` | `slreportgen.report.Report` — needed for compilation |
| `find_system` for diagram discovery | `SystemDiagramFinder` with filter properties |
| `find_system` for block positions | `BlockFinder(systemHandle)` with `SearchDepth=1` |
| Constructing reporters manually from results | `getReporter(result)` — returns specialized reporter |
| Local function for `TableEntryUpdateFcn` | Nested function (or standalone `.m` file for scripts) |
| Path string with `get_param` on finder results | Use `.Object` handle — path strings fail for Stateflow |
| `ExecutionOrder` on virtual subsystem | Check `IsSubsystemVirtual` first |
| `ExecutionOrder`/`SystemIO` on Simulink Functions | `slreportgen.utils.isSimulinkFunction(result.Object)` |
| Not setting `Diagram.Snapshot.ScaleToFit` | Always set `true` unless native resolution needed |
| Wrapping reporter in Paragraph to center | Customize template style via Template API |
| `PDFPageLayout` as first item in chapter | Blank page — put content first |
| Bare `PDFPageLayout` without cloning | No headers — clone via `getImpl` |
| `Paragraph(marker)` with CustomElement | Create `Paragraph()` first, then `append(anchor,marker)` |
| PDF centering approach for Word | Word uses `HAlign("center")` in `Formats`, not CSS |
| Mutating `getStyle` result for Word | Create fresh `TemplateLinkedStyle` + `replaceStyle` |
| Centering only `DiagramImage` in Word | Also center `DiagramCaption` |
| `DOCXPageLayout` without explicit dimensions | Set both `Height` and `Width` explicitly |
| `BlockFinder` with `SearchDepth=inf` to find blocks in referenced models | `BlockFinder` does not traverse Model Reference blocks. Use `SystemDiagramFinder` (with `IncludeReferencedModels=true`) + per-system `BlockFinder` (`SearchDepth=1`) |
| `Diagram(chartResult.Path)` on ChartDiagramFinder results | Use `getReporter(result)` — chart paths may be invalid for `Diagram` constructor |
| No way to find MATLAB Function blocks via BlockFinder | They are SubSystem blocks internally. Use `BlockFinder` for SubSystem + `slreportgen.utils.isMATLABFunction(result.Object)` |
| `find(finder)` + for loop to iterate results | Use `while finder.hasNext()` / `finder.next()` — enables memory-efficient processing and `AutoCloseModel` |

---

## Conventions

- **Always** `slreportgen.report.Report` for Simulink content
- **Always** iterate finders with `while finder.hasNext()` / `finder.next()` — never `find()` + for loop
- **Direct reporters** when path known; **finders + `getReporter`** for discovery
- **Always** `SystemDiagramFinder` for diagram discovery
- **Always** `.Object` handle (not path string) for `get_param`
- **Always** guard `SystemIO`/`ExecutionOrder` with `isSimulinkFunction`
- **Always** `Diagram.Snapshot.ScaleToFit = true`
- **Use** `result.Name` for display titles
- **Never** unzip/zip templates — use Template API
- **Never** local functions for `TableEntryUpdateFcn`
- **Always** `rptview(rpt)` to open DOCX — never `winopen`
- **Never** `close_system` before `close(rpt)` — `slreportgen.report.Report` keeps the model compiled during generation
- **BlockFinder** cannot traverse referenced models — combine with `SystemDiagramFinder` for full hierarchy search

----

Copyright 2026 The MathWorks, Inc.

----
