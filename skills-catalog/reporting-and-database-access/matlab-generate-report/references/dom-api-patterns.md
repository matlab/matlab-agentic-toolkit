# DOM API Patterns

## When to Use the DOM API

Use `mlreportgen.dom.*` alongside the Report API when you need:
- Rich content inside table cells (images, styled text)
- HTML inclusion in non-HTML output formats
- Styled paragraphs, inline formatting, or custom tables
- Programmatic template creation

For report structure (chapters, auto-numbered figures/tables, TOC), use the Report API (`mlreportgen.report.*`).

## Multipage HTML Reports

For HTML reports split into multiple navigable pages, use `mlreportgen.dom.Document` with `'html-multipage'` type and `HTMLPage` objects. Introduced in R2024a.

### Core Pattern

```matlab
import mlreportgen.dom.*

doc = Document("ReportName","html-multipage");
open(doc);

% First page — always becomes root.html (the entry point)
homePage = HTMLPage();
append(homePage,Heading(1,"Report Title"));
append(homePage,Paragraph("Welcome to the report."));
append(doc,homePage);

% Subsequent pages — set FileName explicitly
dataPage = HTMLPage("data.html");
append(dataPage,Heading(1,"Data Analysis"));
append(dataPage,Paragraph("Analysis content here."));
append(doc,dataPage);

close(doc);
```

### Key Rules

| Rule | Details |
|------|---------|
| Document type | Must be `'html-multipage'` on `mlreportgen.dom.Document` |
| All content in HTMLPage | Cannot `append` directly to Document — errors with "Document append argument is invalid" |
| First page is root.html | Regardless of `FileName` property, the first `HTMLPage` always produces `root.html` |
| Built-in navigation | Template provides Home/Previous/Next/End navigation bars automatically — do NOT add manual navigation |
| Cross-page links | Use `ExternalLink(filename, text)` — e.g., `ExternalLink('data.html', 'Go to Data')` |
| Same-page anchors | Use `InternalLink(id, text)` — only works within one `HTMLPage` |
| Output format | `.htmx` package (OPC zip) containing all HTML files + shared stylesheets/scripts |
| Custom template | Set `HTMLPage.TemplatePath` (defaults to `"default_multipage.htmtx"`) |

### TOC with Cross-Page Links

```matlab
import mlreportgen.dom.*

doc = Document("MultipageWithTOC","html-multipage");
open(doc);

% TOC page (first page = root.html)
tocPage = HTMLPage();
append(tocPage,Heading(1,"Contents"));
append(tocPage,Paragraph(ExternalLink("chapter1.html","Chapter 1: Introduction")));
append(tocPage,Paragraph(ExternalLink("chapter2.html","Chapter 2: Methods")));
append(tocPage,Paragraph(ExternalLink("chapter3.html","Chapter 3: Results")));
append(doc,tocPage);

% Content pages
chapters = {"Introduction","Methods","Results"};
for i = 1:3
    pg = HTMLPage(sprintf("chapter%d.html",i));
    append(pg,Heading(1,sprintf("Chapter %d: %s",i,chapters{i})));
    append(pg,Paragraph(sprintf("Content for %s.",chapters{i})));
    append(doc,pg);
end

close(doc);
```

### HTMLPage Constructor Forms

```matlab
pg = HTMLPage();                          % Default (first = root.html)
pg = HTMLPage("results.html");            % Explicit filename
pg = HTMLPage("results.html",tplPath);   % Custom template
pg = HTMLPage("results.html",domObj);    % Initialize with DOM content
```

### What NOT to Do

- **Do NOT** use `mlreportgen.report.Report` with `'html'` or `'html-file'` — these always produce a single HTML file
- **Do NOT** create separate `Document` objects and manually unzip them together — use the proper `'html-multipage'` type
- **Do NOT** add `InternalLink` for cross-page navigation — `#id` anchors only work within one HTML file
- **Do NOT** add manual navigation links (Previous/Next) — the template handles this automatically

## Page Numbers

Use dedicated classes — not `AutoNumber`:

| Class | Output |
|-------|--------|
| `Page()` | Current page number |
| `NumPages()` | Total page count |

```matlab
p = Paragraph();
append(p,Text("Page "));
append(p,Page());
append(p,Text(" of "));
append(p,NumPages());
```

## HTML Inclusion

Use `HTMLFile` or `HTML` to include HTML content in **any** output format (PDF, Word, HTML). These classes convert HTML to DOM elements automatically.

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

rpt = Report("HTMLReport","pdf");
ch = Chapter("Dashboard");

% From a file
htmlContent = HTMLFile("dashboard.html");
append(ch,htmlContent);

% From a string
htmlStr = HTML("<p style="color:blue;">Inline HTML content</p>");
append(ch,htmlStr);

append(rpt,ch);
close(rpt);
```

**Do NOT use `RawText`** — its `HTMLText` property only works for HTML output format. It will not render in PDF or Word.

## Layout Tables (Positioning)

Use a plain `Table` with `Border("none")` for side-by-side layout (columns, sidebars, split panels). This is NOT a data table — it's purely for positioning content.

```matlab
import mlreportgen.dom.*

% Two-column layout: 60% narrative (left), 40% KPI sidebar (right)
leftContent = Paragraph("Main narrative content goes here.");
rightContent = Paragraph("Sidebar: key metrics, charts, KPIs.");

layoutTable = Table({leftContent,rightContent});
layoutTable.Style = [layoutTable.Style,{Width("100%"),Border("none")}];
layoutTable.TableEntriesStyle = {VAlign("top"),InnerMargin("6pt","6pt","4pt","4pt")};

% Set column widths
grp = TableColSpecGroup();
cs1 = TableColSpec();
cs1.Style = {Width("60%")};
cs2 = TableColSpec();
cs2.Style = {Width("40%")};
grp.ColSpecs = [cs1,cs2];
layoutTable.ColSpecGroups = grp;

append(ch,layoutTable);
```

**Key points:**
- `Width("100%")` is fine for layout tables (the `"100%"` warning only applies to fixed-width data tables with `ResizeToFitContents(false)`)
- `Border("none")` hides all borders so the table is invisible
- `ColSpecGroups` works on plain `Table` the same as on `FormalTable`
- For multi-content cells (multiple paragraphs stacked vertically in one cell), use nested cell arrays: `Table({{para1,para2},rightContent})`

## Rich Table Cells

Report API reporters (`Figure`, `BaseTable`, `FormalImage`) cannot be appended to `TableEntry`. Use DOM objects directly inside table cells.

**Construct tables from cell arrays**, then use `entry(row, col)` to format individual cells:

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

rpt = Report("TableWithImages","pdf");
ch = Chapter("Component Gallery");

% Create table from cell array — one row with image cell + description cell
img = Image("component_a.png");
img.Width = "2in";
img.Height = "1.5in";

desc = Paragraph("High-performance variant with thermal protection.");
desc.Style = {FontSize("9pt")};

t = Table({img,desc});

% Use entry(row,col) to style individual cells
e = entry(t,1,1);
e.Style = {VAlign("middle")};

e2 = entry(t,1,2);
e2.Style = {VAlign("middle"),InnerMargin("6pt")};

append(ch,t);
append(rpt,ch);
close(rpt);
```

For multi-content cells (image + caption in one cell), use a **nested cell array** — the inner `{}` groups multiple items into a single table entry:

```matlab
% Nested cell array: {img,caption} become one cell,desc is another cell
img = Image("component_a.png");
img.Width = "2in";
caption = Paragraph("Component A");
caption.Style = {Bold(true),FontSize("10pt")};

desc = Paragraph("High-performance variant with thermal protection.");

t = Table({{img,caption},desc});
% Result: row 1 has two cells — cell 1 contains image + caption,cell 2 contains desc
```

**Do NOT use `Group` in table cell arrays** — `Group` cannot be converted to a table entry. `Group` is for bundling DOM elements as return values from `getImpl` or for sequential appends to Report/Chapter/Section containers.

## FormalTable (DOM)

Use `FormalTable(headerCells,bodyCells)` or `FormalTable(headerCells,bodyCells,footerCells)` for tables with a distinct header row (and optional footer). Do NOT manually build tables with `TableRow`/`TableEntry` loops when `FormalTable` handles it in one call.

```matlab
import mlreportgen.dom.*

header = {"Element","Atomic Number","Mass (g/mol)"};
body = {"Hydrogen","1","1.008"; "Helium","2","4.003"; "Carbon","6","12.011"};
ft = FormalTable(header,body);

% Style the entire table
ft.Border = "solid";
ft.ColSep = "solid";
ft.RowSep = "solid";
ft.TableEntriesStyle = {HAlign("center"),InnerMargin("4pt")};

% Style the header
ft.Header.Style = {BackgroundColor("#003366"),Color("white"),Bold(true)};

% Style the footer
ft.Footer.Style = [ft.Footer.Style,{BackgroundColor("#e0e0e0"),Bold(true)}];

% Alternating row colors (zebra striping)
for r = 1:numel(ft.Body.Children)
    if mod(r,2) == 0
        ft.Body.Children(r).Style = [ft.Body.Children(r).Style,{BackgroundColor("#f0f4f4")}];
    end
end
```

**Constructor forms:**
- `FormalTable(headerCells,bodyCells)` — header + body
- `FormalTable(headerCells,bodyCells,footerCells)` — header + body + footer

**Cell access:** `FormalTable` itself does not have an `entry(row,col)` method, but its `Header`, `Body`, and `Footer` properties are `Table` objects that do. Use `entry(ft.Header,row,col)`, `entry(ft.Body,row,col)`, or `entry(ft.Footer,row,col)` for direct cell access and styling. The plain `Table` class also has `entry(row,col)` directly.

### Column Widths (ColSpecGroups)

Use `TableColSpecGroup` and `TableColSpec` to set column widths. Set `ResizeToFitContents(false)` on the table to enforce fixed widths (otherwise PDF uses `table-layout: auto` which may override them).

```matlab
import mlreportgen.dom.*

ft = FormalTable(header,body);
ft.Width = "6.5in";  % absolute width for PDF (letter page minus 1in margins)
ft.Style = [ft.Style {ResizeToFitContents(false)}];

% Define column widths (percentages or absolute: "1.5in", "3cm")
colWidths = ["25%","15%","15%","20%","10%","15%"];
colSpecs = TableColSpec.empty();
for i = 1:numel(colWidths)
    cs = TableColSpec();
    cs.Style = {Width(colWidths(i))};
    colSpecs(end+1) = cs;
end
grp = TableColSpecGroup();
grp.ColSpecs = colSpecs;
ft.ColSpecGroups = grp;
```

**Key points:**
- `TableColSpec` — one per column, holds `Style` with `Width` format object
- `TableColSpecGroup` — container; assign array of `TableColSpec` to its `ColSpecs` property
- `ft.ColSpecGroups` — assign the group to the table (works on both `FormalTable` and plain `Table`)
- `ResizeToFitContents(false)` — enforces specified widths (without it, PDF auto-sizes columns)
- **PDF table width:** Use an absolute value (`"6.5in"` for US Letter with 1in margins). `"100%"` does not resolve correctly with FOP's fixed table layout when `ResizeToFitContents(false)` is set — columns may render as equal width. (For auto-sized tables without `ResizeToFitContents(false)`, `"100%"` works fine.)
- `TableColSpec.Span` — apply one spec to multiple adjacent columns (default: 1)

### TableEntriesStyle (Bulk Styling)

**Always prefer `TableEntriesStyle` over per-cell loops.** It applies styles to all cells in one line:

```matlab
ft.TableEntriesStyle = {HAlign("left"),InnerMargin("8pt","8pt","3pt","3pt")};
```

For uniform padding only, use the shorthand property:

```matlab
ft.TableEntriesInnerMargin = "6pt";  % Uniform — single string value only
```

`TableEntriesInnerMargin` only accepts a single uniform value. For asymmetric padding, use `TableEntriesStyle` with an `InnerMargin` object.

### InnerMargin Argument Order

**`InnerMargin(left, right, top, bottom)`** — this is NOT CSS order.

| Constructor | Left | Right | Top | Bottom |
|------------|------|-------|-----|--------|
| `InnerMargin('6pt')` | 6pt | 6pt | 6pt | 6pt |
| `InnerMargin('8pt','8pt')` | 8pt | 8pt | — | — |
| `InnerMargin('8pt','8pt','3pt','3pt')` | 8pt | 8pt | 3pt | 3pt |

`OuterMargin` uses the same argument order: `OuterMargin(left, right, top, bottom)`.

### Number and NumberFormat

Use `mlreportgen.dom.Number` with `NumberFormat` for ALL numeric values in tables. **Do NOT put raw numeric values directly in `FormalTable` cell arrays** — they render with full floating-point precision (e.g., `0.33` becomes `0.33000000000000002`, `4.87` becomes `4.8700000000000001`).

**`NumberFormat` uses sprintf-style format specifiers. `%d` is NOT supported — use `"%.0f"` for integers.**

```matlab
import mlreportgen.dom.*

n = Number(pi);
n.Style = [n.Style {NumberFormat("%.4f")}];  % Renders as "3.1416"

% Integer — use %.0f,NOT %d
n2 = Number(42);
n2.Style = [n2.Style {NumberFormat("%.0f")}];  % Renders as "42"
```

#### Number in FormalTable Cell Arrays

`Number` objects can go directly into a `FormalTable` cell array:

```matlab
import mlreportgen.dom.*

n = Number(42);
n.Style = [n.Style {NumberFormat("%.0f")}];

t = FormalTable({"Count","Status"},{n,"PASS"});
```

#### Currency, Units, and Decorators

`Number` does NOT have `Prefix` or `Suffix` properties. To add currency symbols, units, or other decorators, wrap the `Number` in a `Paragraph` and prepend/append `Text`:

```matlab
import mlreportgen.dom.*

% Currency: "$42"
n = Number(42);
n.Style = [n.Style {NumberFormat("%.0f")}];
p = Paragraph("$");
append(p,n);

% With suffix: "$42M"
n2 = Number(42);
n2.Style = [n2.Style {NumberFormat("%.0f")}];
p2 = Paragraph("$");
append(p2,n2);
append(p2,"M");

% Percentage: "12.5%"
n3 = Number(12.5);
n3.Style = [n3.Style {NumberFormat("%.1f")}];
p3 = Paragraph(n3);
append(p3,"%");
```

**Do NOT embed currency symbols in the format string** — `NumberFormat("$%.0f")` does NOT work. The `$` character is not a valid sprintf specifier.

Use a `Paragraph` wrapper in table cells when you need decorators:

```matlab
n = Number(pi);
n.Style = [n.Style {NumberFormat("%.4f")}];

p = Paragraph(n);
append(p," Ohms");

t = FormalTable({"Value","Pass"},{p,"yes"});
```

### HTML Output Types

| Type | Output | Use case |
|------|--------|----------|
| `"html-file"` | Single `.html` file (self-contained) | Distributable single-file reports |
| `"html"` | `.htmx` package (OPC zip with multiple files) | Default; not single-file |
| `"html-multipage"` | `.htmx` package with separate pages | Multi-page navigable reports |

For single-file HTML reports, always use `"html-file"` — not `"html"`.

### Word Paragraph Spacing Fix

In Word (`.docx`) output, paragraphs inside table entries get 8pt default outer margins, causing excessive whitespace. Fix by setting `OuterMargin` to zero on table entry content:

```matlab
% Apply to all body entries
for r = 1:numel(ft.Body.Children)
    row = ft.Body.Children(r);
    for c = 1:numel(row.Children)
        entryNode = row.Children(c);
        for k = 1:numel(entryNode.Children)
            child = entryNode.Children(k);
            if isa(child,"mlreportgen.dom.Paragraph") || isa(child,"mlreportgen.dom.Text")
                child.Style = [child.Style,{OuterMargin("0pt","0pt","0pt","0pt")}];
            end
        end
    end
end
```

This fix is only needed for Word output — PDF and HTML render table entries without extra paragraph spacing.

## PDF Page Orientation (PDFPageLayout)

### Chapter-Level Orientation

Only `Chapter` has a `Layout` property with `Landscape`. `Section` does NOT have `Layout`.

```matlab
ch = mlreportgen.report.Chapter("Title","Wide Content");
ch.Layout.Landscape = true;  % Entire chapter is landscape
```

### Mid-Chapter Orientation Changes

Append a `PDFPageLayout` object to switch orientation within a chapter. Content after the layout object appears on a new page with the specified orientation.

**Critical:** `PDFPageLayout` defaults to portrait (8.5×11in). Call `rotate(pl)` to swap to landscape (11×8.5in). Setting `PageSize.Orientation` alone does NOT swap the physical dimensions — the page won't actually change.

```matlab
ch = mlreportgen.report.Chapter("Title","Mixed Orientation");
ch.Layout.Landscape = true;  % First page(s): landscape

% ... append landscape content ...

% Switch to portrait mid-chapter
pl = mlreportgen.dom.PDFPageLayout;  % default = portrait (8.5x11)
append(ch,pl);

% ... append portrait content ...

% Switch back to landscape
pl2 = mlreportgen.dom.PDFPageLayout;
rotate(pl2);  % now landscape (11x8.5)
append(ch,pl2);

% ... append landscape content ...
```

**Common pattern — per-diagram orientation:**

```matlab
% Determine orientation from content aspect ratio
if contentWidth >= contentHeight
    pl = mlreportgen.dom.PDFPageLayout;
    rotate(pl);  % landscape
else
    pl = mlreportgen.dom.PDFPageLayout;  % portrait (default)
end
append(ch,pl);
```

### Key Rules

| Rule | Details |
|------|---------|
| `Section` has no `Layout` | Only `Chapter` controls orientation via `Layout.Landscape` |
| `ch.Layout.Landscape` scope | Applies to all pages in the chapter **until the first `PDFPageLayout`** is encountered — subsequent pages use the orientation from their preceding `PDFPageLayout` |
| `PDFPageLayout` defaults to portrait | 8.5in × 11in — you MUST call `rotate()` for landscape |
| `rotate()` swaps dimensions | Changes both `Width`/`Height` AND `Orientation` property |
| Setting `Orientation` alone fails | `pl.PageSize.Orientation = "landscape"` does NOT swap physical dimensions |
| Creates a page break | `PDFPageLayout` always forces a page break — content before it fills the preceding page, content after starts on a new page |
| Blank first page pitfall | Appending `PDFPageLayout` as the **first** item in a chapter produces a blank page (no content precedes the break). Put content (text, root diagram) before the first `PDFPageLayout`, or use `ch.Layout.Landscape` for the initial orientation |
| Append before content | Content after the `PDFPageLayout` starts on a new page with that orientation |
| PDF only | `PDFPageLayout` is for PDF output. DOCX uses `DOCXSection` for similar layout breaks |

### Preserving Headers/Footers Across PDFPageLayout Breaks

When you append `PDFPageLayout` objects mid-chapter to change orientation, each creates a new XSL-FO `fo:page-sequence`. This has two consequences:

1. **StyleRef stops working.** The chapter header uses `fo:retrieve-marker` with `retrieve-boundary="page-sequence"` to display the chapter title. The chapter title's `fo:marker` lives in the first page-sequence — subsequent page-sequences cannot see it.
2. **First-page headers reset.** Each new page-sequence treats its first page as "first." The default chapter template's first-page header is empty (no StyleRef), so the header shows nothing.
3. **Page numbers reset.** A new `PDFPageLayout` defaults to `FirstPageNumber = '1'`, restarting the counter.

**Solution:** Clone the chapter's page layout (which has headers/footers/rules from the template), then fix the three issues on each clone.

#### Step 1: Extract the Chapter's Page Layout

Use `getImpl` on a temporary Chapter to access its `DOMDocumentPart`, then grab the `PDFPageLayout` (first child):

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

% Create a temporary report+chapter to extract the template layout
tempRpt = Report(fullfile(tempdir,"tmp_layout"),"pdf");
tempCh = Chapter("Title","tmp");
open(tempRpt);
docPart = getImpl(tempCh,tempRpt);
chLayout = docPart.Children(1);  % PDFPageLayout with headers/footers from template
close(tempRpt);
```

#### Step 2: Clone and Adapt for Each Page Break

```matlab
pl = clone(chLayout);

% Set orientation
if needsLandscape
    rotate(pl);
end

% Fix 1: Continue page numbering (don't reset to 1)
pl.FirstPageNumber = '';

% Fix 2: Remove first-page header (it's empty — hides StyleRef)
% This forces the page to use the "default" header which has StyleRef
firstIdx = strcmp({pl.PageHeaders.PageType},"first");
pl.PageHeaders = pl.PageHeaders(~firstIdx);

append(ch,pl);
```

#### Step 3: Re-inject the Chapter Title Marker

The header's `fo:retrieve-marker` needs a `fo:marker` in the current page-sequence's flow. Inject one using `CustomElement`:

```matlab
% Build the chapter title string (must match what the template renders)
chapterTitle = "Chapter 1. " + modelName;  % adjust numbering as needed

% Create fo:marker that the header can find
marker = CustomElement("fo:marker");
marker.CustomAttributes = CustomAttribute("marker-class-name","SectionTitle1");
append(marker,Text(chapterTitle));

% Wrap in a near-invisible paragraph (present in flow but not visible)
% NOTE: Paragraph() constructor does not accept CustomElement — create then append
anchor = Paragraph();
anchor.Style = {FontSize("1pt"),OuterMargin("0pt","0pt","0pt","0pt"),...
    LineSpacing(0.01),Color("white")};
append(anchor,marker);
append(ch,anchor);
```

#### Complete Pattern: Per-Section Orientation with Headers

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

rpt = Report(outputPath,"pdf");
ch = Chapter("Title",chapterName);

% Extract chapter template layout
tempRpt = Report(fullfile(tempdir,"tmp_layout"),"pdf");
tempCh = Chapter("Title","tmp");
open(tempRpt);
docPart = getImpl(tempCh,tempRpt);
chLayout = docPart.Children(1);
close(tempRpt);

% First page uses Chapter.Layout (no PDFPageLayout needed)
ch.Layout.Landscape = (firstPageOrientation == "landscape");
% ... append first page content ...

% Each subsequent page
chapterTitle = "Chapter 1. " + chapterName;
for i = 1:numSections
    % Clone and configure layout
    pl = clone(chLayout);
    if sectionOrientations(i) == "landscape"
        rotate(pl);
    end
    pl.FirstPageNumber = '';
    pl.PageHeaders = pl.PageHeaders(~strcmp({pl.PageHeaders.PageType},"first"));
    append(ch,pl);

    % Re-inject chapter title marker for header StyleRef
    marker = CustomElement("fo:marker");
    marker.CustomAttributes = CustomAttribute("marker-class-name","SectionTitle1");
    append(marker,Text(chapterTitle));
    % NOTE: Paragraph() constructor does not accept CustomElement — create then append
    anchor = Paragraph();
    anchor.Style = {FontSize("1pt"),OuterMargin("0pt","0pt","0pt","0pt"),...
        LineSpacing(0.01),Color("white")};
    append(anchor,marker);
    append(ch,anchor);

    % ... append section content ...
end

append(rpt,ch);
close(rpt);
```

#### Key Rules

| Rule | Details |
|------|---------|
| `FirstPageNumber = ''` | Empty string continues numbering from previous section; `'1'` (default) resets |
| Remove first-page headers | Clone has first/default/even headers; first-page is empty — remove it so the default (with StyleRef) is used on all pages |
| `CustomElement("fo:marker")` | Injects raw FO element; `CustomAttribute("marker-class-name","SectionTitle1")` sets the marker class that `fo:retrieve-marker` looks for |
| Marker text must match chapter title | Include prefix + number + title (e.g., "Chapter 1. Results") |
| Near-invisible anchor paragraph | `FontSize("1pt")` + `Color("white")` + `LineSpacing(0.01)` hides the marker from the page body |
| Extract layout once, clone per break | `getImpl` finalizes the chapter — use a throwaway chapter for extraction |

## DOCX Page Orientation (DOCXPageLayout)

For Word (`.docx`) output, use `mlreportgen.dom.DOCXPageLayout` to change page orientation mid-chapter. This creates a Word section break (`<w:sectPr>`).

### Chapter-Level Orientation

```matlab
ch = mlreportgen.report.Chapter("Title","Wide Content");
ch.Layout.Landscape = true;  % Entire chapter is landscape
```

### Mid-Chapter Orientation Changes

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

ch = Chapter("Title","Mixed Orientation");
ch.Layout.Landscape = false;  % First page(s): portrait

% ... append portrait content ...

% Switch to landscape mid-chapter
pl = DOCXPageLayout();
pl.PageSize.Orientation = "landscape";
pl.PageSize.Height = "8.5in";
pl.PageSize.Width = "11in";
append(ch,pl);

% ... append landscape content ...
```

### Per-Diagram Orientation Pattern

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

ch = Chapter("Title",chapterName);
ch.Layout.Landscape = false;  % Start portrait for intro text

% Introduction section (uses chapter default — portrait)
introSec = Section("Title","Introduction");
append(introSec,Paragraph("Introductory content here."));
append(ch,introSec);

% Each diagram gets its own orientation
for i = 1:numDiagrams
    if diagramWidths(i) >= diagramHeights(i)
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

    sec = Section("Title",diagramNames(i));
    % ... append diagram content ...
    append(ch,sec);
end

append(rpt,ch);
close(rpt);
rptview(rpt);  % REQUIRED — updates fields (TOC, heading numbers)
```

### Key Rules

| Rule | Details |
|------|---------|
| `ch.Layout.Landscape` scope | Controls orientation of pages before the first `DOCXPageLayout` |
| Must set both dimensions | Set `PageSize.Height` AND `PageSize.Width` explicitly — unlike PDF `rotate()`, DOCX does not auto-swap |
| Creates a section break | Each `DOCXPageLayout` produces a Word section break — content after starts on a new page |
| Heading numbering is preserved | Word section breaks do NOT reset heading counters (unlike PDF page-sequences) |
| TOC and fields require update | Word field codes (TOC, heading numbers, StyleRef) display placeholder text until updated — always use `rptview` or `docview("updatefields")` to view |
| Blank first page pitfall | Same as PDF: appending `DOCXPageLayout` as the first item in a chapter produces a blank page |
| DOCX only | For PDF output use `PDFPageLayout` + `rotate()` — see PDF section above |

### Why Heading Numbers Appear Wrong Without rptview

Word headings use `SEQ` fields for auto-numbering. These fields are **not evaluated** until Word processes the document. Opening a `.docx` file with `start`, `winopen`, or double-click may not trigger field update (depends on Word settings). The headings will all display "1.1" (the raw field placeholder).

**Always use `rptview(rpt)` or `docview(file,"updatefields")`.** These invoke Word's field-update mechanism, producing correct numbering and a populated TOC.

## CustomElement (FO-Level Injection)

Use `mlreportgen.dom.CustomElement` and `mlreportgen.dom.CustomAttribute` to inject XSL-FO elements that the DOM API does not expose directly. This is an escape hatch for advanced PDF scenarios.

```matlab
import mlreportgen.dom.*

% Create a custom FO element
elem = CustomElement("fo:leader");
elem.CustomAttributes = [
    CustomAttribute("leader-pattern","rule")
    CustomAttribute("rule-thickness","0.5pt")
    CustomAttribute("leader-length","100%")
];
```

**Primary use case:** Inserting `fo:marker` elements for StyleRef resolution across PDFPageLayout breaks (see "Preserving Headers/Footers Across PDFPageLayout Breaks" above).

**Key points:**
- `CustomElement(tagName)` creates an element with the given FO tag
- `CustomAttributes` accepts an array of `CustomAttribute(name,value)` objects
- Append text or DOM children normally with `append(elem,Text("content"))`
- Wrap in a Paragraph to include in the document flow

## Centering Reporter Output (Custom Templates)

Report API reporters (`Figure`, `FormalImage`) produce DOM output from **templates** at render time. You cannot wrap a reporter in a DOM element (e.g., centered `Paragraph`) — reporters can only be appended to `Report`, `Chapter`, or `Section`.

**To center reporter output, customize the reporter's template CSS via the Template API.**

For centering `slreportgen.report.Diagram`, see [simulink-report.md](simulink-report.md).

### Pattern: Center a Figure Reporter

```matlab
import mlreportgen.dom.*

% 1. Create a copy of the default Figure template
srcPath = fullfile(tempdir,"figure_src.pdftx");
mlreportgen.report.Figure.createTemplate(srcPath,"pdf");

% 2. Open with Template API (3-arg form copies source to output)
centeredTemplatePath = fullfile(tempdir,"centered_figure.pdftx");
tpl = Template(centeredTemplatePath,"pdf",srcPath);
open(tpl);

% 3. Modify FigureImage style — append text-align: center to CSS
ss = tpl.Stylesheet;
figStyle = getStyle(ss,"FigureImage");
figStyle.RawFormats = strtrim(figStyle.RawFormats) + " text-align: center;";
replaceStyle(ss,figStyle);

close(tpl);

% 4. Use the custom template on each Figure reporter
fig = mlreportgen.report.Figure();
fig.TemplateSrc = centeredTemplatePath;
append(ch,fig);
```

### Word (.docx) Centering Variant

For Word output, the same Template API workflow applies but with `"docx"` format and `HAlign("center")` instead of CSS:

```matlab
import mlreportgen.dom.*

% 1. Create a copy of the default Figure template for Word
srcPath = fullfile(tempdir,"figure_src.dotx");
mlreportgen.report.Figure.createTemplate(srcPath,"docx");

% 2. Open with Template API (3-arg form copies source to output)
centeredTemplatePath = fullfile(tempdir,"centered_figure.dotx");
tpl = Template(centeredTemplatePath,"docx",srcPath);
open(tpl);

% 3. Modify FigureImage style — add center alignment
ss = tpl.Stylesheet;
figStyle = getStyle(ss,"FigureImage");
figStyle.Formats = [figStyle.Formats,HAlign("center")];
replaceStyle(ss,figStyle);

close(tpl);

% 4. Use the custom template on each Figure reporter
fig = mlreportgen.report.Figure();
fig.TemplateSrc = centeredTemplatePath;
append(ch,fig);
```

**Word vs. PDF centering differences:**
- PDF: modify `RawFormats` CSS string (`+ " text-align: center;"`)
- Word: append `HAlign("center")` to the style `Formats` array
- Template file extension: `.pdftx` for PDF, `.dotx` for Word
- The same `getStyle`/`replaceStyle` API works for both formats

### Key Rules

| Rule | Details |
|------|---------|
| Reporters cannot nest in DOM elements | `append(paragraph,reporter)` errors — reporters only go in Report/Chapter/Section |
| Each reporter has its own template | `Figure` uses `FigureImage`, `FormalImage` uses `FormalImageImage` |
| Use `<Class>.createTemplate` | Creates an editable copy of the default template for that reporter |
| Set `reporter.TemplateSrc` | Points the reporter at your custom template |
| PDF: `TemplatePDFStyle.RawFormats` is a CSS string | Append CSS declarations directly (e.g., `+ " text-align: center;"`) |
| Word: `Formats` array with DOM format objects | Append `HAlign("center")` to the style's `Formats` array |
| Use Template API, not unzip/zip | `Template(outPath,fmt,srcPath)` + `getStyle`/`replaceStyle` — see [template-system.md](template-system.md) |
| Create template once, reuse | Generate the custom template once (e.g., at script start), then set `TemplateSrc` on every reporter instance |

## Inline Styling

Inline `.Style` properties use **cell arrays `{}`**. Append to existing styles to avoid overwriting inherited or previously set properties:

```matlab
p = Paragraph("Important note");
p.Style = [p.Style,{Bold(true),FontSize("12pt"),Color("red")}];

t = Text("highlighted");
t.Style = [t.Style,{BackgroundColor("yellow"),Italic(true)}];
```

**Never overwrite with `=`** when the object may already have styles (e.g., from a template or constructor). Use `[obj.Style, {newFormats}]` to append safely.

This is different from template styles which use **arrays `[]`** for `Formats`.

## Horizontal Rules

```matlab
append(grp,HorizontalRule());
```

## Groups

Use `Group` to bundle multiple DOM elements into a single returnable unit — primarily for `getImpl` return values in custom reporters, or for sequential appends to Report/Chapter/Section containers:

```matlab
grp = Group();
append(grp,Paragraph("First paragraph"));
append(grp,HorizontalRule());
append(grp,Paragraph("Second paragraph"));
```

**Limitation:** `Group` cannot be placed inside `Table` cell arrays or appended to `TableEntry`. For multi-content table cells, use nested cell arrays instead (see Rich Table Cells above).

----

Copyright 2026 The MathWorks, Inc.

----
