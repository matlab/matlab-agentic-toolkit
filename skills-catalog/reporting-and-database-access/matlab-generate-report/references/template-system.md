# Template System

Comprehensive reference for editing MATLAB Report Generator templates using the DOM Template API — styles, page headers/footers, holes, TOC customization, and template creation across PDF, Word, and HTML formats.

## Template File Types

| Output Type | Extension | Template API Type Arg | Nature |
|-------------|-----------|----------------------|--------|
| PDF | `.pdftx` | `"pdf"` | OPC archive (HTML + CSS) |
| Word | `.dotx` | `"docx"` | OPC archive (Word XML) |
| HTML (multi-file) | `.htmtx` | `"html"` | OPC archive |
| HTML (single-file) | `.htmt` | `"html-file"` | Plain HTML file |

**Critical:** Match the type argument to the file extension. Using `"html"` with a `.htmt` file fails ("Could not open source package") because `.htmt` is plain text, not OPC. Use `"html-file"` for `.htmt`.

## The 3-Argument Template Constructor

The `Template` constructor has two forms:

| Form | Purpose | Stylesheet Returns |
|------|---------|-------------------|
| `Template(outPath,format)` | Create **new blank** template | 34 Report-level base styles |
| `Template(outPath,format,srcPath)` | Open **existing** template for editing/inspection | Reporter's own styles (e.g., 16 for Section PDF) |

**Always use the 3-argument form** to edit or inspect an existing template. The 2-argument form creates a blank template from DOM defaults — it does NOT load existing content.

**Critical:** OPC packages cannot be read and written simultaneously. The output path MUST differ from the source path:

```matlab
import mlreportgen.dom.*

srcPath = "path/to/default.pdftx";
tmpPath = strrep(srcPath,"default.pdftx","default_new.pdftx");

tpl = Template(tmpPath,"pdf",srcPath);
open(tpl);
% ... modify ...
close(tpl);
movefile(tmpPath,srcPath);
```

## Locating Templates

**Preferred: `getDefaultTemplatePath`** — works for any reporter, handles inheritance:

```matlab
rpt = mlreportgen.report.Report(fullfile(tempdir,"tmp"),"pdf");
reporter = mlreportgen.report.Chapter("X");
templatePath = reporter.getDefaultTemplatePath(rpt);
% Returns Section's PDF template path (Chapter inherits from Section)
delete(rpt);
```

**Alternative: Manual location** from class file:

```matlab
classDir = fileparts(which("mlreportgen.report.Section"));
templatePath = fullfile(classDir,"resources","templates","pdf","default.pdftx");
```

**Key facts:**
- Chapter and InlineContent have no template directory — they inherit from Section/Reporter
- `getDefaultTemplatePath` handles this transparently
- `reporter.TemplateName` tells you which document part is the entry point

## Inspecting Templates

Use this pattern to introspect any reporter's template — extracts document parts, holes, styles, and page layout:

```matlab
import mlreportgen.dom.*

% 1. Locate template
rpt = mlreportgen.report.Report(fullfile(tempdir,"tmp"),"pdf");
reporter = mlreportgen.report.Chapter("X");
templatePath = reporter.getDefaultTemplatePath(rpt);
delete(rpt);

% 2. Open with 3-arg constructor
tpl = Template(fullfile(tempdir,"introspect.pdftx"),"pdf",templatePath);
open(tpl);

% 3. Document parts and holes
parts = tpl.TemplateDocumentParts;
for i = 1:numel(parts)
    fprintf("Part: %s\n",parts(i).Name);
    for j = 1:numel(parts(i).Children)
        child = parts(i).Children(j);
        if isa(child,"mlreportgen.dom.TemplateHole")
            fprintf("  Hole: %s (defaultStyle: %s)\n",...
                child.HoleId,child.DefaultHoleStyleName);
        end
    end
end

% 4. Styles
ts = tpl.Stylesheet.TemplateStyles;
for i = 1:numel(ts)
    if isprop(ts(i),"Selector")
        fprintf("Style: %s [%s]\n",ts(i).Name,ts(i).Selector);
    else
        fprintf("Style: %s [%s]\n",ts(i).Name,ts(i).Type);
    end
end

% 5. Page layout (PDF/DOCX — first child of Section1)
for i = 1:numel(parts)
    if strcmp(parts(i).Name,"Section1") && numel(parts(i).Children) > 0
        layout = parts(i).Children(1);
        fprintf("Layout: %s\n",class(layout));
        if isa(layout,"mlreportgen.dom.PDFPageLayout")
            fprintf("  Headers: %d, Footers: %d\n",...
                numel(layout.PageHeaders),numel(layout.PageFooters));
        end
    end
end

close(tpl);
```

**Before customizing a built-in reporter template, first consult [template-reference.md](template-reference.md).** It contains pre-computed introspection of common reporters — no need to run introspection code for those.

## Template Inheritance Model

```
Level 1: Report Template
  - Defines base styles (TOC, Title, headings, table, link — 34 for PDF)
  - Created by Report() or 2-arg Template()

Level 2: Reporter Templates
  - Each reporter has its own template with reporter-specific styles
  - Loaded via 3-arg Template(out, fmt, src)

Level 3: Generated Output
  - Style propagation MERGES all styles from every reporter into output
  - ALL defined styles appear regardless of whether referenced
```

**Critical:** Do NOT inspect generated output to determine "used" styles — style propagation copies everything. Walk template doc parts to find actual references.

## Style Object Types by Format

**PDF** — `TemplatePDFStyle`:

| Property | Description |
|----------|-------------|
| `Name` | Style display name (e.g., `"SectionTitle1"`) |
| `Selector` | CSS selector (e.g., `"h1.SectionTitle1"`) |
| `RawFormats` | Raw CSS property string |

Multiple selectors can share a Name (e.g., `h1.SectionTitle1` and `p.SectionTitle1`).

**DOCX** — `TemplateDOCXStyle`:

| Property | Description |
|----------|-------------|
| `Name` | Style display name |
| `Type` | `"paragraph"`, `"text"`, `"linked"`, `"table"`, `"list"` |
| `Formats` | **Always empty** — cannot inspect or set formats |

To inspect DOCX style formats, parse `styles.xml` inside the `.dotx`.

## Modifying Styles — PDF and HTML

PDF styles (`TemplatePDFStyle`) and HTML styles (`TemplateHTMLStyle`) are handle objects. Modify `RawFormats` directly:

```matlab
import mlreportgen.dom.*

classDir = fileparts(which("mlreportgen.report.Section"));
srcPath = fullfile(classDir,"resources","templates","pdf","default.pdftx");
outPath = fullfile(tempdir,"modified_section.pdftx");

tpl = Template(outPath,"pdf",srcPath);
open(tpl);

% No type argument — returns all CSS rules with this name
styles = getStyle(tpl.Stylesheet,"SectionTitle1");

% Modify RawFormats directly (handle semantics — changes persist)
for i = 1:numel(styles)
    styles(i).RawFormats = regexprep(styles(i).RawFormats,...
        "color:\s*[^;]+","color: navy");
end

close(tpl);
movefile(outPath,srcPath);
```

**Common RawFormats changes:**

| Change | Pattern |
|--------|---------|
| Color | `regexprep(raw,"color:\s*[^;]+","color: red")` |
| Font size | `regexprep(raw,"font-size:\s*[^;]+","font-size: 16pt")` |
| Font family | `regexprep(raw,"font-family:\s*[^;]+","font-family: Arial")` |
| Add property | `raw = raw + " text-decoration: underline;"` |
| Remove bold | `regexprep(raw,"font-weight:\s*bold;?\s*","")` |

**Filtering by Selector:** When `getStyle` returns multiple entries, use `.Selector` to target the correct one:

```matlab
styles = getStyle(tpl.Stylesheet,"BaseTableContent");
for i = 1:numel(styles)
    if contains(styles(i).Selector,"th")
        % Modify header cells only
        styles(i).RawFormats = regexprep(styles(i).RawFormats,...
            "background-color:\s*[^;]+","background-color: navy");
    end
end
```

## Modifying Styles — DOCX

DOCX styles are **read-only**. Create a replacement and use `replaceStyle`:

```matlab
import mlreportgen.dom.*

tpl = Template(outPath,"docx",srcPath);
open(tpl);

% Get style (no type argument) and check its Type
style = getStyle(tpl.Stylesheet,"SectionTitle1");
fprintf("Type: %s\n",style.Type);  % "linked" → use TemplateLinkedStyle

% Create replacement with updated formats
newStyle = TemplateLinkedStyle("SectionTitle1");
newStyle.Formats = [Bold(true),FontSize("14pt"),FontFamily("Cambria"),...
    Color("green"),OutlineLevel(1)];  % OutlineLevel REQUIRED for headings
replaceStyle(tpl.Stylesheet,newStyle);

close(tpl);
```

### Style Class Selection

| `TemplateDOCXStyle.Type` | Replacement Class |
|--------------------------|-------------------|
| `"linked"` | `TemplateLinkedStyle` |
| `"paragraph"` | `TemplateParagraphStyle` |
| `"text"` (character) | `TemplateCharacterStyle` |
| `"table"` | `TemplateTableStyle` |

### CRITICAL: Heading Styles and TOC (OutlineLevel)

**When replacing any heading style (`SectionTitle1`–`SectionTitle6`), you MUST include `OutlineLevel(N)` in the `Formats` array.** Word's TOC uses outline levels to discover headings. Without it, TOC displays "No table of contents entries found."

| Style Name | Required OutlineLevel |
|------------|----------------------|
| `SectionTitle1` | `OutlineLevel(1)` |
| `SectionTitle2` | `OutlineLevel(2)` |
| `SectionTitle3` | `OutlineLevel(3)` |
| `SectionTitle4` | `OutlineLevel(4)` |
| `SectionTitle5` | `OutlineLevel(5)` |
| `SectionTitle6` | `OutlineLevel(6)` |

### DOCX Table Styles (TemplateTableStyle)

```matlab
ts = TemplateTableStyle("BaseTableContent");
ts.Formats = [Border("solid","#333333","0.5pt"),FontSize("10pt"),FontFamily("Arial")];
ts.HeaderFormats = [Bold(true),BackgroundColor("#1B3A5C"),Color("white"),FontSize("11pt")];
% Optional: ts.EvenRowFormats = [BackgroundColor("#F0F0F0")];
replaceStyle(tpl.Stylesheet,ts);
```

Key `TemplateTableStyle` properties:

| Property | Applied To |
|----------|-----------|
| `Formats` | All table body cells |
| `HeaderFormats` | Header row cells (overrides Formats) |
| `FooterFormats` | Footer row cells |
| `EvenRowFormats` | Even-numbered body rows (striping) |
| `OddRowFormats` | Odd-numbered body rows |
| `FirstColumnFormats` | First column cells |
| `LastColumnFormats` | Last column cells |

### Identifying Current DOCX Formats from styles.xml

```matlab
% Extract styles.xml to read current formatting
unzipDir = fullfile(tempdir,"dotx_inspect");
if isfolder(unzipDir),rmdir(unzipDir,"s"); end
unzip(srcPath,unzipDir);

stylesXml = fileread(fullfile(unzipDir,"word","styles.xml"));
% Look for: <w:name w:val="SectionTitle1"/>
% Then read: w:rPr (run properties), w:pPr (paragraph properties)
% Common elements:
%   <w:b/>            → Bold
%   <w:sz w:val="28"/> → FontSize (half-points: 28 = 14pt)
%   <w:color w:val="365F91"/> → Color("#365F91")
%   <w:rFonts w:ascii="Cambria"/> → FontFamily("Cambria")
%   <w:jc w:val="center"/> → HAlign("center")
```

## Multi-Level Headings

Section templates define 6 heading levels (`SectionTitle1`–`SectionTitle6`). Chapter uses level 1; Sections nested under Chapter use level 2+. **To change heading appearance uniformly, modify ALL levels:**

```matlab
% Modify all heading levels for uniform color
for level = 1:6
    styleName = sprintf("SectionTitle%d",level);
    styles = getStyle(tpl.Stylesheet,styleName);
    for i = 1:numel(styles)
        styles(i).RawFormats = regexprep(styles(i).RawFormats,...
            "color:\s*[^;]+","color: navy");
    end
end
```

## Modifying Page Headers and Footers

Page headers/footers live on the page layout object inside the `Section1` document part:

| Format | Layout Object | Header/Footer Class |
|--------|---------------|---------------------|
| PDF | `PDFPageLayout` (first child of Section1) | `PDFPageHeader` / `PDFPageFooter` |
| Word | `DOCXSection` (first child of Section1) | `DOCXPageHeader` / `DOCXPageFooter` |
| HTML | N/A (no page concept) | N/A |

### Access Pattern

```matlab
import mlreportgen.dom.*

tpl = Template(tmpPath,"pdf",srcPath);
open(tpl);

parts = tpl.TemplateDocumentParts;
section1 = [];
for i = 1:numel(parts)
    if strcmp(parts(i).Name,"Section1")
        section1 = parts(i);
        break
    end
end

layout = section1.Children(1);  % PDFPageLayout or DOCXSection

for k = 1:numel(layout.PageHeaders)
    fprintf("Header %d: PageType=%s\n",k,layout.PageHeaders(k).PageType);
end
```

### Replacing a Footer (Adding Page Numbers)

```matlab
for k = 1:numel(layout.PageFooters)
    if strcmp(layout.PageFooters(k).PageType,"default")
        newFooter = PDFPageFooter("default");

        footerPara = Paragraph("");
        footerPara.HAlign = "center";
        append(footerPara,"Page ");
        append(footerPara,Page());
        append(footerPara," of ");
        append(footerPara,NumPages());
        append(newFooter,footerPara);

        layout.PageFooters(k) = newFooter;
    end
end

tpl.TemplateDocumentParts(1) = section1;
close(tpl);
movefile(tmpPath,srcPath);
```

### Multi-Column Header Layout (3-Column Centering)

```matlab
newHeader = PDFPageHeader("default");

% Left: image or hole
imgPara = Paragraph("");
append(imgPara,TemplateHole("HeaderImage"));

% Center: running head (centered on page)
titlePara = Paragraph("");
titlePara.HAlign = "center";
titlePara.StyleName = "SectionTitleHeader";
append(titlePara,StyleRef("SectionTitle1"));

% Right: spacer (balances image column)
spacerPara = Paragraph(" ");

% 3-column table with explicit entry widths
e1 = TableEntry(imgPara);
e1.Style = {Width("1in")};
e2 = TableEntry(titlePara);
e2.Style = {Width("5in")};
e3 = TableEntry(spacerPara);
e3.Style = {Width("1in")};

row = TableRow();
append(row,e1);
append(row,e2);
append(row,e3);

headerTable = Table();
append(headerTable,row);
headerTable.Width = "100%";
headerTable.Style = {Border("none"),ResizeToFitContents(false)};
headerTable.TableEntriesVAlign = "bottom";
append(newHeader,headerTable);
```

**Preferred approach for column widths in headers:** Set widths on `TableEntry.Style` (more reliable than `TableColSpecGroup` in single-row header context).

If using `TableColSpecGroup` + `TableColSpec`, you **must set `Span = 1` explicitly** on each `TableColSpec`:

```matlab
grp = TableColSpecGroup();
cs1 = TableColSpec(); cs1.Span = 1; cs1.Style = {Width("1in")};
cs2 = TableColSpec(); cs2.Span = 1; cs2.Style = {Width("5in")};
cs3 = TableColSpec(); cs3.Span = 1; cs3.Style = {Width("1in")};
grp.ColSpecs = [cs1,cs2,cs3];
headerTable.ColSpecGroups = grp;
```

### Word-Specific Header Rules

- **Do NOT modify existing `TemplateText` objects** — their content is raw Word XML. Always create new `DOCXPageHeader` from DOM objects.
- **Preserve the first-page header** when replacing the default:
  ```matlab
  firstHeader = docxSection.PageHeaders(2);  % PageType="first"
  docxSection.PageHeaders = [newDefaultHeader,firstHeader];
  ```

### PDF Header/Footer Doc Parts (Section/Chapter Templates)

| Doc Part Name | When Used |
|---------------|-----------|
| `SectionFirstPageHeader` | First page of chapter only |
| `SectionDefaultPageHeader` | Odd pages (or all non-first if no even defined) |
| `SectionEvenPageHeader` | Even pages |
| `SectionFirstPageFooter` | First page footer |
| `SectionDefaultPageFooter` | Odd pages footer |
| `SectionEvenPageFooter` | Even pages footer |

### Special Elements in PDF Templates

| Element | DOM Equivalent | Purpose |
|---------|---------------|---------|
| `<hole id="Name">` | `TemplateHole("Name")` | Placeholder filled by reporter property |
| `<StyleRef style-name="X"/>` | `StyleRef("X")` | Running head — shows text with style X |
| `<page/>` | `Page()` | Current page number |
| `<numpages/>` | `NumPages()` | Total page count |

## Adding Holes to Templates

### To a Document Part Body

```matlab
% Rebuild the document part with a new hole inserted
newSection = TemplateDocumentPart("Section1");
append(newSection,section1.Children(1));  % Keep layout

% Add new hole before existing content
summaryHole = TemplateHole("Summary");
summaryHole.DefaultHoleStyleName = "SectionContent";
append(newSection,summaryHole);

% Clone remaining children
for k = 2:numel(section1.Children)
    append(newSection,clone(section1.Children(k)));
end

tpl.TemplateDocumentParts(1) = newSection;
```

### To a Page Header

Place a `TemplateHole` inside a `Paragraph` in the header (inline hole — can only accept inline content like Text, Image):

```matlab
imgPara = Paragraph("");
append(imgPara,TemplateHole("HeaderImage"));
```

**Key rules:**
- Holes inside Paragraphs are inline holes — they can only accept inline content (Text, Image)
- A `get<HoleId>` method must return inline content (not a Paragraph or Table) for header holes
- **Do not use `Table({...})` shorthand with `TemplateHole`** — build via `TableEntry` + `append(entry,hole)`

### DOCX Templates: TemplateText Spacers Between Holes

Word templates use `TemplateText` objects (containing Word XML paragraph spacing) between each `TemplateHole`. When adding new holes to a DOCX template, clone an existing spacer from the original template and insert it between holes to preserve correct formatting.

## Creating Templates from Scratch

```matlab
import mlreportgen.dom.*

tpl = Template("MyTemplate","pdf");
open(tpl);

% Add styles
ss = tpl.Stylesheet;
titleStyle = TemplateLinkedStyle("DocTitle");
titleStyle.Formats = [Bold(true),FontSize("24pt"),Color("navy"),HAlign("center")];
addStyle(ss,titleStyle);

bodyStyle = TemplateLinkedStyle("BodyText");
bodyStyle.Formats = [FontSize("11pt"),FontFamily("Calibri")];
addStyle(ss,bodyStyle);

% Add holes with default styles
titleHole = TemplateHole("Title");
titleHole.DefaultHoleStyleName = "DocTitle";
append(tpl,titleHole);

bodyHole = TemplateHole("Body");
bodyHole.DefaultHoleStyleName = "BodyText";
append(tpl,bodyHole);

close(tpl);
```

**Critical:** Style `.Formats` requires **array `[]`**, not cell array `{}`. Use `TemplateLinkedStyle` for hole styles — linked styles work in all output formats.

### Using a Created Template

```matlab
doc = Document("OutputReport","pdf","MyTemplate.pdftx");
open(doc);
moveToNextHole(doc);
append(doc,"My Report Title");
moveToNextHole(doc);
append(doc,"Content inherits BodyText style.");
close(doc);
```

## Applying Modified Templates

**Option A — `TemplateSrc` on a standard reporter (no custom class needed):**

```matlab
ch = Chapter("My Chapter");
ch.TemplateSrc = "path/to/modified.pdftx";
sec = Section("Sub-section");
sec.TemplateSrc = "path/to/modified.pdftx";  % Must also set on nested reporters
add(ch,sec);
append(rpt,ch);
```

**Scope:** `TemplateSrc` applies only to the reporter it is set on. Set on **both** Chapter and Section for style changes to appear at all heading levels.

**Option B — Custom Report class** (via `customizeReport`):

```matlab
mlreportgen.report.Report.customizeReport("+xyzco/@Report");
% Edit templates in +xyzco/@Report/resources/templates/
rpt = xyzco.Report("MyReport","pdf");  % Automatically uses custom templates
```

## TOC Customization

### Reporter Properties (Simple — No Template Edit)

```matlab
toc = TableOfContents();
toc.Title = "Contents";
toc.NumberOfLevels = 4;
toc.LeaderPattern = "dots";
append(rpt,toc);
```

### PDF: Template API with addStyle

TOC entry styles live in the **Report** template (not the TOC reporter template). Customize via `addStyle` with `TemplateParagraphStyle`:

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

% Scaffold custom Report class (once)
Report.customizeReport(fullfile(pwd,"+mypkg/@Report"));

% Open the Report's PDF template
pdfTemplatePath = fullfile(pwd,"+mypkg","@Report",...
    "resources","templates","pdf","default.pdftx");
tmpPath = fullfile(tempdir,"toc_pdf_edited.pdftx");

tpl = Template(tmpPath,"pdf",pdfTemplatePath);
open(tpl);
ss = tpl.Stylesheet;

% Add TOC styles (addStyle — these are new, not replacements)
tocStyle1 = TemplateParagraphStyle("TOC1");
tocStyle1.Formats = [FontFamily("Helvetica"),FontSize("12pt"),Bold(true),...
    OuterMargin("6pt","3pt","0in","0in")];
addStyle(ss,tocStyle1);

tocStyle2 = TemplateParagraphStyle("TOC2");
tocStyle2.Formats = [FontFamily("Helvetica"),FontSize("11pt"),Bold(false),...
    OuterMargin("2pt","2pt","0.3in","0in")];
addStyle(ss,tocStyle2);

tocStyle3 = TemplateParagraphStyle("TOC3");
tocStyle3.Formats = [FontFamily("Helvetica"),FontSize("10pt"),Italic(true),...
    OuterMargin("1pt","1pt","0.6in","0in")];
addStyle(ss,tocStyle3);

close(tpl);
copyfile(tmpPath,pdfTemplatePath);

% Generate with custom Report class
rpt = mypkg.Report("my_report","pdf");
toc = TableOfContents();
toc.NumberOfLevels = 4;
append(rpt,toc);
% ... add chapters ...
close(rpt);
```

**Key points:**
- Use `addStyle` (not `replaceStyle`) — TOC styles don't exist in default Report template
- Style names are `TOC1`–`TOC6` (no space)
- `OuterMargin(top,bottom,left,right)` — third arg controls indentation
- Do NOT edit the TOC reporter's own `.pdftx` — crashes MATLAB in R2026a

### DOCX: Word COM/ActiveX (Required)

For Word output, TOC styles are named `"TOC 1"` through `"TOC 9"` (with space). **Word COM/ActiveX is the only way to customize these.** The Template API cannot modify them because:
- `TemplateParagraphStyle` rejects spaces in names
- `addStyle`/`replaceStyle` with `"TOC1"` creates a separate custom style Word ignores
- `TemplateDOCXStyle.Formats` modifications don't persist

```matlab
function customizeDocxTocStyles(templatePath)
%customizeDocxTocStyles Customize DOCX TOC styles via Word COM/ActiveX

% Copy to temp to avoid path issues (+ and @ in folder names)
tmpTemplate = fullfile(tempdir,"toc_dotx_com_edit.dotx");
copyfile(templatePath,tmpTemplate);

wordApp = actxserver('Word.Application');
wordApp.Visible = false;

doc = wordApp.Documents.Open(tmpTemplate);
styles = doc.Styles;

% TOC 1: Bold, 12pt Calibri, no indent
toc1 = styles.Item('TOC 1');
toc1.Font.Name = 'Calibri';
toc1.Font.Size = 12;
toc1.Font.Bold = true;
toc1.ParagraphFormat.LeftIndent = 0;
toc1.ParagraphFormat.SpaceBefore = 6;
toc1.ParagraphFormat.SpaceAfter = 3;

% TOC 2: Regular, 11pt, 0.3in indent (21.6pt)
toc2 = styles.Item('TOC 2');
toc2.Font.Name = 'Calibri';
toc2.Font.Size = 11;
toc2.Font.Bold = false;
toc2.ParagraphFormat.LeftIndent = 21.6;
toc2.ParagraphFormat.SpaceBefore = 2;
toc2.ParagraphFormat.SpaceAfter = 2;

% TOC 3: Italic, 10pt, 0.6in indent (43.2pt)
toc3 = styles.Item('TOC 3');
toc3.Font.Name = 'Calibri';
toc3.Font.Size = 10;
toc3.Font.Italic = true;
toc3.ParagraphFormat.LeftIndent = 43.2;

doc.Save();
doc.Close();
wordApp.Quit();
delete(wordApp);

copyfile(tmpTemplate,templatePath);
delete(tmpTemplate);
end
```

**Key points — DOCX TOC:**
- Style names are `'TOC 1'`–`'TOC 9'` (with space) via `styles.Item('TOC 1')`
- `LeftIndent` in **points** (72pt = 1in): 0.3in = 21.6pt
- `Font.Size` in **points** (not half-points)
- Do NOT use `Font.Color` — throws "Ambiguous property" error
- Copy `.dotx` to `tempdir` first — Word COM has issues with `+`/`@` in paths

### Style Name Differences by Format

| TOC Level | PDF Style | DOCX Style (COM) |
|-----------|-----------|-----------------|
| 1 | `TOC1` | `'TOC 1'` |
| 2 | `TOC2` | `'TOC 2'` |
| 3 | `TOC3` | `'TOC 3'` |
| 4 | `TOC4` | `'TOC 4'` |

## Editing Children (Read-Only Property)

The `Children` property on DOM objects is **read-only**. To restructure, create a new object and clone:

```matlab
% WRONG: section1.Children = [newChild; section1.Children];  % Errors

% CORRECT: rebuild from fresh object
newSection = TemplateDocumentPart("Section1");
append(newSection,myNewParagraph);
for k = 1:numel(section1.Children)
    append(newSection,clone(section1.Children(k)));
end
tpl.TemplateDocumentParts(1) = newSection;
```

Always use `clone()` when copying children — DOM objects cannot belong to two parents.

## Discovering Which Style Controls a Hole

Use `TemplateHole.DefaultHoleStyleName`:

```matlab
dps = tpl.TemplateDocumentParts;
for i = 1:numel(dps)
    queue = {dps(i)};
    while ~isempty(queue)
        node = queue{1}; queue(1) = [];
        if isa(node,"mlreportgen.dom.TemplateHole")
            fprintf("Hole: %-12s  Style: %s\n",node.Id,node.DefaultHoleStyleName);
        end
        if isprop(node,"Children")
            for j = 1:numel(node.Children)
                queue{end+1} = node.Children(j); %#ok
            end
        end
    end
end
```

## Determining Which Styles Are Referenced

Walk `TemplateDocumentParts` to find style references (via `StyleName`, `DefaultHoleStyleName`, and DOCX `DOCXText`):

```matlab
import mlreportgen.dom.*

tpl = Template(fullfile(tempdir,"inspect.pdftx"),"pdf",srcPath);
open(tpl);

dps = tpl.TemplateDocumentParts;
referencedStyles = string.empty;

for i = 1:numel(dps)
    queue = {dps(i)};
    while ~isempty(queue)
        node = queue{1}; queue(1) = [];
        if isprop(node,"StyleName") && ~isempty(node.StyleName)
            referencedStyles(end+1) = string(node.StyleName); %#ok
        end
        if isprop(node,"DefaultHoleStyleName") && ~isempty(node.DefaultHoleStyleName)
            referencedStyles(end+1) = string(node.DefaultHoleStyleName); %#ok
        end
        if isa(node,"mlreportgen.dom.TemplateText") && isprop(node,"DOCXText") ...
                && ~isempty(node.DOCXText)
            txt = string(node.DOCXText);
            for pat = ["<w:pStyle w:val=""([^""]*)""",...
                       "<w:rStyle w:val=""([^""]*)""",...
                       "<w:tblStyle w:val=""([^""]*)"""]
                toks = regexp(txt,pat,"tokens");
                for j = 1:numel(toks)
                    referencedStyles(end+1) = string(toks{j}{1}); %#ok
                end
            end
        end
        if isa(node,"mlreportgen.dom.DOCXSection")
            for h = 1:numel(node.PageHeaders)
                queue{end+1} = node.PageHeaders(h); %#ok
            end
            for f = 1:numel(node.PageFooters)
                queue{end+1} = node.PageFooters(f); %#ok
            end
        end
        if isprop(node,"Children")
            for j = 1:numel(node.Children)
                queue{end+1} = node.Children(j); %#ok
            end
        end
    end
end

close(tpl);
referencedStyles = unique(referencedStyles);
```

## DOCX Style Property Extraction (XPath)

For a readable summary of DOCX style properties, use XPath:

```matlab
function propsTable = extractDOCXStyleProperties(templatePath)
%extractDOCXStyleProperties Extract formatting properties from a DOTX template.
    arguments
        templatePath (1,1) string {mustBeFile}
    end

    import mlreportgen.dom.*
    import matlab.io.xml.dom.*
    import matlab.io.xml.xpath.*

    unzipDir = fullfile(tempdir,"dotx_style_extract");
    if isfolder(unzipDir), rmdir(unzipDir,"s"); end
    unzip(templatePath,unzipDir);

    stylesFile = fullfile(unzipDir,"word","styles.xml");
    if ~isfile(stylesFile)
        propsTable = table.empty;
        return
    end

    parser = Parser;
    stylesDoc = parseFile(parser,stylesFile);

    outPath = fullfile(tempdir,"inspect_props.dotx");
    tpl = mlreportgen.dom.Template(outPath,"docx",templatePath);
    open(tpl);
    ts = tpl.Stylesheet.TemplateStyles;
    close(tpl);

    evaluator = Evaluator;
    NodeSet = EvalResultType.NodeSet;

    numStyles = numel(ts);
    names = strings(numStyles,1);
    types = strings(numStyles,1);
    properties = strings(numStyles,1);

    for i = 1:numStyles
        names(i) = string(ts(i).Name);
        types(i) = string(ts(i).Type);

        xpath = sprintf( ...
            "//*[local-name()=""style""][*[local-name()=""name""][@*[local-name()=""val""]=""%s""]]",...
            ts(i).Name);
        result = evaluate(evaluator,xpath,stylesDoc,NodeSet);
        if isempty(result), continue; end
        styleNode = result(1);

        propParts = string.empty;

        % Font
        fontResult = evaluate(evaluator,...
            ".//*[local-name()=""rFonts""]/@*[local-name()=""ascii""]",styleNode,NodeSet);
        if ~isempty(fontResult)
            propParts(end+1) = "font:" + string(fontResult(1).Value);
        end

        % Size (half-points → points)
        sizeResult = evaluate(evaluator,...
            ".//*[local-name()=""sz""]/@*[local-name()=""val""]",styleNode,NodeSet);
        if ~isempty(sizeResult)
            halfPts = str2double(string(sizeResult(1).Value));
            propParts(end+1) = "size:" + num2str(halfPts/2) + "pt";
        end

        % Bold
        boldResult = evaluate(evaluator,...
            ".//*[local-name()=""rPr""]/*[local-name()=""b""]",styleNode,NodeSet);
        if ~isempty(boldResult)
            propParts(end+1) = "bold";
        end

        % Color
        colorResult = evaluate(evaluator,...
            ".//*[local-name()=""color""]/@*[local-name()=""val""]",styleNode,NodeSet);
        if ~isempty(colorResult)
            colorVal = string(colorResult(1).Value);
            if colorVal ~= "auto"
                propParts(end+1) = "color:#" + colorVal;
            end
        end

        if ~isempty(propParts)
            properties(i) = join(propParts,"; ");
        end
    end

    propsTable = table(names,types,properties,...
        "VariableNames",{"Name","Type","Properties"});
end
```

**Note:** Unzipping `.dotx` for read-only `styles.xml` inspection is acceptable. The prohibition on unzipping applies to structural editing.

## PDF Template File Structure

```
default/
├── root.html                  # Main template
├── docpart_templates.html     # Doc part library (headers, footers, sections)
├── stylesheets/
│   └── root.css               # Styles for all template content
└── images/
    └── (static images)
```

## Style Types for Template Creation

| Class | Purpose |
|-------|---------|
| `TemplateLinkedStyle` | Paragraph + text combined (preferred for hole styles) |
| `TemplateParagraphStyle` | Paragraph-level only |
| `TemplateTextStyle` | Inline text only |
| `TemplateTableStyle` | Table formatting |
| `TemplateOrderedListStyle` | Numbered lists |
| `TemplateUnorderedListStyle` | Bulleted lists |

All use `.Formats = [...]` (array syntax, not cell array).

## Filling Holes with Multiple Items (Cell Arrays)

A single hole can receive multiple DOM objects via a cell array:

**Reporter property assignment:**
```matlab
ch.SummaryContent = {Heading1("Key Findings"),resultsTable,Paragraph("See appendix.")};
```

**`get<HoleId>()` method return:**
```matlab
function content = getSummary(obj,~)
    import mlreportgen.dom.*
    content = {Heading1("Results"),obj.ResultsTable,Paragraph(obj.Notes)};
end
```

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| `Template(path,"pdf")` to modify existing | Use 3-arg: `Template(out,"pdf",src)` |
| `getStyle(ss,name,type)` with type arg | Type returns `[]` in R2026a. Use `getStyle(ss,name)` |
| Setting `TemplateDOCXStyle.Formats` | Read-only. Create `TemplateLinkedStyle` + `replaceStyle` |
| `addStyle` for PDF/HTML style that exists | Modify `RawFormats` directly (handle object) |
| Unzipping template to edit structure | Use DOM Template API for all edits |
| `TemplateParagraphStyle.Formats = {Bold(true)}` | Use array: `Formats = [Bold(true)]` |
| Same source and output path | OPC can't read/write simultaneously. Different paths + `movefile` |
| `DOCXPageHeader` for PDF output | Use `PDFPageHeader`/`PDFPageFooter` for PDF |
| Modifying existing DOCX `TemplateText` | Create new `DOCXPageHeader` from DOM objects |
| Only modifying `SectionTitle1` | Modify all levels (1–6) for uniform appearance |
| Setting `TemplateSrc` on Chapter only | Set on both Chapter AND Section |
| Inspecting output to find "used" styles | Walk template doc parts for actual references |
| Editing TOC reporter's `.pdftx` template | Crashes MATLAB R2026a. Edit Report template instead |
| `TemplateParagraphStyle("TOC 1")` for DOCX | Rejects spaces. Use Word COM: `styles.Item('TOC 1')` |
| Replacing heading style without `OutlineLevel` | TOC breaks. Always include `OutlineLevel(N)` |

----

Copyright 2026 The MathWorks, Inc.

----
