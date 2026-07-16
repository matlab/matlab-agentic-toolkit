---
name: matlab-generate-report
description: >
  Unified skill for all MATLAB and Simulink report generation tasks. Covers report generation,
  PDF report, document generation, mlreportgen, Report Generator, template, TitlePage, Chapter,
  multipage HTML, HTMLPage, html-multipage, custom reporter, customizeReporter, template hole,
  page header, page border, company style package, branded reporters, buildTemplates, Simulink
  report, model documentation, slreportgen, block diagram report, model report, subsystem
  documentation, SystemDiagramFinder, SystemIO, ExecutionOrder, LookupTable, template style,
  page footer, TemplateSrc, report package, table variants, multiple HTML pages, PDF report
  generation, Word report, DOM API, FormalTable, BaseTable, Figure, FormalImage, Section.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Report Generation

Generate structured, professional reports (PDF, Word, HTML) from MATLAB data and Simulink models.

## When to Use

- Creating PDF, Word, or HTML reports from MATLAB data
- Building reports with chapters, title pages, tables of contents
- Adding auto-numbered figures and tables to documents
- Creating multipage HTML reports (separate HTML files with navigation)
- Documenting Simulink models with block diagrams, I/O tables, execution order
- Customizing report templates (styles, colors, fonts, headers, footers)
- Creating custom reporter classes with template holes and dynamic content
- Building multi-reporter packages with shared company styles
- Creating table variant reporters with different header colors
- Including HTML content in reports

## When NOT to Use

- Simple file export (CSV, Excel) — use `writetable`, `writematrix`
- Live Scripts as reports — use MATLAB Live Editor export
- Interactive report building — use Report Explorer GUI
- Web views of Simulink models — use `slreportgen.webview.*` directly

## API Selection

**Always use the Report API** (`mlreportgen.report.*`) as the foundation. It provides the `Report` container and reporters (`Figure`, `BaseTable`, `FormalImage`, `Chapter`, `TitlePage`, etc.) that handle auto-numbering, captions, and document structure.

**Use both APIs together.** Use the Report API to create the report and add content for which reporters exist. Use the DOM API (`mlreportgen.dom.*`) for styled paragraphs, custom tables, inline formatting, HTML inclusion, and images without captions. DOM objects append directly to `Report`, `Chapter`, or `Section` alongside reporters.

**Critical rule:** Report API reporters (`Figure`, `BaseTable`, `FormalImage`) can ONLY be appended to `Report`, `Chapter`, or `Section` objects — never to DOM objects like `TableEntry`. Use DOM objects inside `TableEntry`.

**Simulink reports:** Use `slreportgen.report.Report` (not `mlreportgen.report.Report`) — it extends the base with model compilation support required by `SystemIO`, `ExecutionOrder`, and other Simulink reporters.

**Multipage HTML:** Use `mlreportgen.dom.Document` with `"html-multipage"` type + `HTMLPage` objects. This is the only case where you use the DOM `Document` instead of the Report API `Report`.

## Core Workflow: Standard Report

`TitlePage`, `TableOfContents`, `ListOfFigures`, and `ListOfTables` are optional — include only when the task requires them. The minimal report is just `Report` + content + `close`.

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

rpt = Report("MyReport","pdf");
append(rpt,TitlePage(Title="Report Title",Author="Team"));  % optional
append(rpt,TableOfContents());   % optional
append(rpt,ListOfFigures());     % optional
append(rpt,ListOfTables());      % optional

ch = Chapter("Results");
append(ch,Paragraph("Analysis complete."));

% Auto-numbered table
data = FormalTable(["ID","Value"],[1 10; 2 20]);
bt = BaseTable(data);
bt.Title = "Measured values";
append(ch,bt);

% Auto-numbered figure
fig = figure("Visible","off");
plot([1 2],[10 20]);
rptFig = Figure(fig);
rptFig.Snapshot.Caption = "Value trend";
append(ch,rptFig);
close(fig);

append(rpt,ch);
close(rpt);
rptview(rpt);
```

## Core Workflow: Simulink Report

```matlab
load_system(modelName);

% MUST use slreportgen.report.Report for Simulink content
rpt = slreportgen.report.Report(outputPath,"pdf");
append(rpt,mlreportgen.report.TitlePage("Title","Model Report"));
append(rpt,mlreportgen.report.TableOfContents());

ch = mlreportgen.report.Chapter("Diagrams");

% Root diagram — direct reporter
rootDiag = slreportgen.report.Diagram(modelName);
rootDiag.Snapshot.ScaleToFit = true;
append(ch,rootDiag);

% Subsystems — finder pattern (iterator for memory efficiency)
finder = slreportgen.finder.SystemDiagramFinder(modelName);
finder.IncludeRoot = false;
finder.SortType = "alphabetical";

while finder.hasNext()
    result = finder.next();
    sec = mlreportgen.report.Section("Title",result.Name);
    append(sec,result);
    append(ch,sec);
end

append(rpt,ch);
close(rpt);
rptview(rpt);
```

## Choosing Built-In vs Custom Reporters

Before writing code, analyze requirements against built-in reporter capabilities:

1. **List all content/format requirements** — title page fields, page borders, headers/footers, branded styling
2. **Check built-in reporters.** Built-in `TitlePage` has: Title, Subtitle, Author, Publisher, PubDate, Image. Built-in `Chapter`/`Section` provide headings, auto-numbering, and a Content hole.
3. **If built-in reporters meet all requirements**, use them directly
4. **If any requirement is unmet**, create custom reporters:
   - Single custom reporter — see [references/custom-reporters.md](references/custom-reporters.md)
   - Multiple reporters sharing a visual identity — see [references/report-package.md](references/report-package.md)

**Common triggers for custom reporters:**
- Title page needs fields beyond the standard set (project name, facility, contract number)
- Page borders, watermarks, or custom page layout
- Page headers/footers with dynamic content (per-chapter images, tickers)
- Branded table variants with different header colors
- MATLAB-generated logos (geometric shapes drawn with plot/patch + exportgraphics)

**Do NOT force-fit requirements** into built-in properties (e.g., concatenating fields into Subtitle). Create a custom reporter instead.

**Do NOT build custom title pages with raw DOM elements** (Paragraphs, Images appended to a Chapter). Always use `customizeReporter` for template-based layout and format portability.

## Decision Tree: What Reference Do I Need?

| I need to... | Reference |
|--------------|-----------|
| Build a standard report with chapters, figures, tables, verification | [references/report-api-patterns.md](references/report-api-patterns.md) |
| Work with DOM tables, HTML inclusion, multipage HTML, Number/NumberFormat | [references/dom-api-patterns.md](references/dom-api-patterns.md) |
| Understand template file types, locate/inspect templates | [references/template-system.md](references/template-system.md) |
| Look up built-in template holes, styles, page layout (pre-computed) | [references/template-reference.md](references/template-reference.md) |
| Create a custom reporter class (customizeReporter, holes, headers) | [references/custom-reporters.md](references/custom-reporters.md) |
| Build a multi-reporter package with shared styles and buildTemplates | [references/report-package.md](references/report-package.md) |
| Generate Simulink model reports (finders, orientation, centering) | [references/simulink-report.md](references/simulink-report.md) |
| Look up all Simulink finders and reporters | [references/finders-and-reporters.md](references/finders-and-reporters.md) |
| Iterate struct arrays into chapters with custom reporters | [references/data-driven-report-pattern.md](references/data-driven-report-pattern.md) |
| Edit template styles (colors, fonts, headers, footers, TOC) | [references/template-system.md](references/template-system.md) |

## Key Functions

| Class | Purpose | Package |
|-------|---------|---------|
| `Report` | Top-level report container | `mlreportgen.report` |
| `TitlePage` | Title page with title, subtitle, author | `mlreportgen.report` |
| `TableOfContents` | Auto-generated TOC | `mlreportgen.report` |
| `Chapter` / `Section` | Document structure | `mlreportgen.report` |
| `Figure` | Auto-numbered figure from MATLAB figure | `mlreportgen.report` |
| `FormalImage` | Auto-numbered image from file with caption | `mlreportgen.report` |
| `BaseTable` | Auto-numbered table wrapper (pass `FormalTable`) | `mlreportgen.report` |
| `FormalTable` | Table with header/body/footer from cell arrays | `mlreportgen.dom` |
| `Template` (3-arg) | Edit templates: `Template(out,fmt,src)` | `mlreportgen.dom` |
| `HTMLFile` / `HTML` | Include HTML content in any output format | `mlreportgen.dom` |
| `HTMLPage` | Page in multipage HTML document (R2024a+) | `mlreportgen.dom` |
| `Number` | Numeric DOM object (use with `NumberFormat`) | `mlreportgen.dom` |
| `TemplateHole` | Placeholder filled at report time | `mlreportgen.dom` |
| `Page` / `NumPages` | Page number / total pages | `mlreportgen.dom` |
| `*.customizeReporter` | Scaffold custom reporter + templates | `mlreportgen.report` |
| `getStyle` / `replaceStyle` | Modify template styles | `mlreportgen.dom` |
| `slreportgen.report.Report` | Report container for Simulink content | `slreportgen.report` |
| `slreportgen.report.Diagram` | Diagram snapshot of a system | `slreportgen.report` |
| `slreportgen.finder.SystemDiagramFinder` | Find system/subsystem diagrams | `slreportgen.finder` |
| `slreportgen.report.SystemIO` | Report inputs/outputs (requires compilation) | `slreportgen.report` |
| `slreportgen.report.ExecutionOrder` | Report block execution order | `slreportgen.report` |
| `slreportgen.report.LookupTable` | Report lookup table data + plot | `slreportgen.report` |
| `rptview` | Display report (updates DOCX fields) | function |
| `docview` | Process Word documents (update fields, convert) | function |

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Using `mlreportgen.dom.Document` as report container | Use `mlreportgen.report.Report`. Exception: multipage HTML requires `Document` with `"html-multipage"` |
| Using `mlreportgen.report.Report` for Simulink content | Use `slreportgen.report.Report` — needed for model compilation |
| Using `Report` with `"html"` for multipage output | Use `mlreportgen.dom.Document` with `"html-multipage"` + `HTMLPage` objects |
| Appending reporters to DOM objects (Paragraph, TableEntry) | Reporters can ONLY go in Report, Chapter, or Section. Use DOM objects inside TableEntry |
| Putting raw doubles in `FormalTable` cells | Use `Number` with `NumberFormat` in Style: `n = Number(42); n.Style = {NumberFormat("%.0f")}`. Put `n` directly in cell arrays. See [references/dom-api-patterns.md](references/dom-api-patterns.md) § Number and NumberFormat |
| `NumberFormat("$%.0f")` or `NumberFormat("%,.0f")` | Only standard `sprintf` specifiers work (no `$`, no `%,`, no `%d`). For currency/units, wrap `Number` in `Paragraph` and prepend/append `Text` |
| Customizing only "default"/"even" page headers | Customize ALL page types: "first", "default", "even" — but differentiate content (see below) |
| Putting StyleRef (chapter title) in the first-page header | First page already displays the chapter heading — omit StyleRef from "first" header. Use it only in "default"/"even" for wayfinding |
| Opening DOCX with `winopen`/`open`/`start` | Use `rptview(rpt)` or `docview(file,"updatefields")` — triggers field update |
| Using `ColSpec`/`ColSpecGroup` for widths | Use `TableColSpecGroup` + `TableColSpec` with `Width` in `Style` |
| Setting widths without `ResizeToFitContents(false)` | Add `ResizeToFitContents(false)` to table `Style`; set absolute `ft.Width` (not `"100%"`) |
| `TemplateParagraphStyle.Formats = {Bold(true)}` | Use array: `Formats = [Bold(true),FontSize("12pt")]` |
| `Template(path,"pdf")` to edit existing template | 2-arg creates blank. Use 3-arg: `Template(out,"pdf",src)` |
| Same path for source and output in Template constructor | OPC cannot read/write simultaneously. Use different paths, then `movefile` |
| Setting `PDFPageLayout.PageSize.Orientation` without `rotate()` | Call `rotate(pl)` — swaps Width/Height AND sets Orientation |
| Using `DOCXPageLayout` without explicit Height and Width | DOCX does not auto-swap — set both explicitly |
| Page numbers resetting after `PDFPageLayout` | Set `pl.FirstPageNumber = ''` (empty string) to continue numbering |
| Wrapping reporter in Paragraph to center it | Customize the reporter's template style via Template API |
| Using `RawText(html)` for HTML in PDF | Use `HTMLFile(path)` or `HTML(string)` — works for any format |
| Using `Group` in a `Table` cell array | Use nested cell arrays: `Table({{img,caption},desc})` |
| Passing MATLAB `table()` to `BaseTable` | Pass `FormalTable(headers,body)` — avoids `MATLABTable` wrapper |
| `e.Style = {BackgroundColor("yellow")}` (overwrites existing styles) | Append: `e.Style = [e.Style, {BackgroundColor("yellow")}]` — preserves inherited styles |
| Force-fitting fields into `TitlePage.Subtitle` | Create a custom title page reporter via `customizeReporter` |
| Writing custom reporter class from scratch | Use `customizeReporter` to scaffold — creates required binary templates |
| Writing classdef before running `customizeReporter` | Scaffolding overwrites classdef files. Scaffold first, then edit |
| Unqualified `TitlePage.getClassFolder()` in package | Use fully-qualified: `mypkg.TitlePage.getClassFolder()` |
| `getStyle(ss,name,type)` for PDF/HTML | Type arg returns `[]`. Use `getStyle(ss,name)` without type |
| `OuterMargin("12pt","6pt","0","0")` for vertical spacing | Args are `(left,right,top,bottom)` — NOT CSS order. Use `OuterMargin("0","0","12pt","6pt")` for top/bottom spacing |
| Using `TemplateCharacterStyle` | Does not exist. Use `TemplateTextStyle` for character/inline styles in PDF/HTML |
| Unzipping `.pdftx`/`.htmtx`/`.dotx` to edit with fileread/regexprep | **ALWAYS** use DOM Template API — `Template(out,fmt,src)` + `open` + modify objects + `close`. Raw edits bypass framework validation |
| `find_system` + `DiagramFinder` for discovery | Use `SystemDiagramFinder` with filter properties |
| `Diagram(result.Path)` on `ChartDiagramFinder` results | Use `getReporter(result)` — chart paths are invalid for `Diagram` constructor |
| `find()` + for loop on finders | Always use iterator: `while finder.hasNext()` / `result = finder.next()` |
| `BlockFinder` with `SearchDepth=inf` expecting referenced models | `BlockFinder` does NOT traverse Model References. Use `SystemDiagramFinder` (IncludeReferencedModels=true) + per-system `BlockFinder` (SearchDepth=1) |
| `ExecutionOrder` on virtual subsystem | Check `get_param(obj,'IsSubsystemVirtual')` first |
| `ExecutionOrder`/`SystemIO` on Simulink Functions | Guard with `slreportgen.utils.isSimulinkFunction(result.Object)` |

## Conventions

- **Always `close(rpt)`** after appending all content — generates the output file
- **Always `rptview` or `docview`** to open DOCX — never `winopen` or `open`
- **Use `figure("Visible","off")`** for plots destined for reports
- **Use `exportgraphics`** (not `print`) when saving figures to files
- **One Chapter = one numbering scope** — figures/tables numbered Chapter-Sequence (e.g., "Figure 2-1")
- **`BaseTable` wraps `FormalTable`** — pass `FormalTable(headers,body)`, not a MATLAB `table()`
- **Cell-level styling:** Use `entry(t,row,col)` after construction, not during
- **Template styles use `[]` arrays**; inline `.Style` properties use `{}`
- **Reporters in `@ClassName` directories** — each needs its own `resources/templates/`
- **Scaffold ALL reporters before editing ANY** — `customizeReporter` creates binary templates + overwrites classdef
- **Fix unqualified class names** after scaffolding — use package-qualified names
- **Customize all output formats** — PDF/Word/HTML templates are independent
- **Simulink:** Always `slreportgen.report.Report`; always `Diagram.Snapshot.ScaleToFit = true`
- **Simulink finders:** Use `.Object` handle (not path string) for `get_param`; use `result.Name` for titles
- **JSON is single source of truth** for multi-reporter packages — never hardcode style values

## Viewing and Processing Reports

```matlab
rptview(rpt);                           % Open in system viewer (updates DOCX fields)
rptview("MyReport.docx","pdf");         % Convert DOCX to PDF via Word
docview("Report.docx","updatefields","closedoc","closeapp");  % Update without display
```

**Verification:** Running without error does NOT confirm correctness. After `close(rpt)`:
- Check `isfile(rpt.OutputPath)` and `dir(rpt.OutputPath).bytes > 1000`
- For PDF: call `open(rpt)`, then set `rpt.Document.RetainFO = true` before appending content, search `*_FO/*.fo` files
- For DOCX: unzip and search `word/document.xml`
- Assert expected titles, headings, captions appear in output

See [references/report-api-patterns.md](references/report-api-patterns.md) for full verification patterns.

## Required Toolbox

MATLAB Report Generator (verify with `mcp__matlab__detect_matlab_toolboxes`). Simulink Report Generator additionally required for Simulink model reports.

----

Copyright 2026 The MathWorks, Inc.

----
