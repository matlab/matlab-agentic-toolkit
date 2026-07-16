# Multi-Reporter Report Package

Create a cohesive package of custom reporters that share a centralized style config and produce branded reports in PDF, Word, and HTML.

---

## Architecture Overview

```
+company/
├── styles.json                    ← Single source of truth
├── buildTemplates.m               ← Thin orchestrator
├── setOrAddCss.m                  ← CSS helper utility
├── demo.m                         ← Exercises all reporters, all formats
├── @Report/Report.m               ← Subclasses mlreportgen.report.Report
├── @TitlePage/TitlePage.m
├── @Chapter/Chapter.m
├── @Section/Section.m
├── @DataTable/DataTable.m         ← Table variant: teal header
├── @SpecTable/SpecTable.m         ← Table variant: gold header
├── @SummaryTable/SummaryTable.m   ← Table variant: navy header
└── @FormalImage/FormalImage.m
```

Each `@Reporter/` directory contains `resources/templates/{pdf,docx,html}/` with scaffolded template copies that `buildTemplates` edits in place.

**HTML has two templates:** `default.htmtx` (packaged multi-file, used for `"html"` output type) and `default.htmt` (single-file, used for `"html-file"` output type). Edit both.

---

## Workflow

### 1. Define the Style Config

Create a JSON file as the single source of truth for all visual constants:

```json
{
  "fonts": {"heading": "Segoe UI", "body": "Palatino Linotype"},
  "colors": {"navy": "#1B3A5C", "teal": "#2A7B88", "gold": "#C4952D"},
  "sizes": {"heading1": "20pt", "body": "11pt", "tableHeader": "10pt"},
  "tables": {
    "data": {"headerBackground": "#2A7B88", "headerColor": "#FFFFFF"},
    "spec": {"headerBackground": "#C4952D", "headerColor": "#FFFFFF"},
    "summary": {"headerBackground": "#1B3A5C", "headerColor": "#FFFFFF"},
    "borderColor": "#E2E8F0"
  }
}
```

### Full JSON Schema

```json
{
  "fonts": {
    "heading": "Font family for headings, titles, table titles",
    "body": "Font family for body text and table content",
    "code": "Font family for code blocks"
  },
  "colors": {
    "navy": "#hex — primary brand color (headings, title page)",
    "teal": "#hex — secondary brand color (H3, accent)",
    "gold": "#hex — tertiary brand color (spec tables)",
    "darkGray": "#hex — body text color",
    "lightGray": "#hex — borders, subtle backgrounds",
    "white": "#FFFFFF — table header text",
    "footerGray": "#hex — footer text color"
  },
  "sizes": {
    "heading1": "20pt",
    "heading2": "16pt",
    "heading3": "13pt",
    "body": "11pt",
    "tableHeader": "10pt",
    "tableBody": "10pt",
    "caption": "10pt"
  },
  "page": {
    "size": "letter | A4",
    "orientation": "portrait | landscape",
    "margins": {"top": "0.5in", "bottom": "0.5in", "left": "1in", "right": "1in"}
  },
  "tables": {
    "<variant>": {"headerBackground": "#hex", "headerColor": "#hex"},
    "borderColor": "#hex — shared border color for all variants"
  }
}
```

**Naming conventions:** camelCase keys, CSS-compatible values (`"11pt"`, `"#1B3A5C"`), table variants named by semantic purpose (data, spec, summary) not color.

### 2. Scaffold All Reporters (MUST Be Done First via MATLAB)

**CRITICAL: Run ALL scaffolding commands in MATLAB (via `mcp__matlab__evaluate_matlab_code`) BEFORE writing any classdef code.**

```matlab
% Run in MATLAB via MCP tool — scaffold ALL reporters before editing ANY
mlreportgen.report.Report.customizeReport("+company/@Report/Report.m");
mlreportgen.report.TitlePage.customizeReporter("+company/@TitlePage/TitlePage.m");
mlreportgen.report.Chapter.customizeReporter("+company/@Chapter/Chapter.m");
mlreportgen.report.Section.customizeReporter("+company/@Section/Section.m");
mlreportgen.report.BaseTable.customizeReporter("+company/@DataTable/DataTable.m");
mlreportgen.report.BaseTable.customizeReporter("+company/@SpecTable/SpecTable.m");
mlreportgen.report.BaseTable.customizeReporter("+company/@SummaryTable/SummaryTable.m");
mlreportgen.report.FormalImage.customizeReporter("+company/@FormalImage/FormalImage.m");
```

**Always use `@ClassName` directories.** Without them, reporters share a single `resources/templates/` and overwrite each other's templates.

### 3. Inspect Scaffolded Templates

**Do not assume style names.** Inspect the actual templates:

```matlab
import mlreportgen.dom.*
classDir = company.Chapter.getClassFolder();
tpl = Template(fullfile(tempdir,"inspect.pdftx"),"pdf", ...
    fullfile(classDir,"resources","templates","pdf","default.pdftx"));
open(tpl);
styles = tpl.Stylesheet.TemplateStyles;
for i = 1:numel(styles)
    fprintf("%s | %s\n",styles(i).Name,styles(i).Selector);
end
close(tpl);
```

Common findings:
- Chapter/Section: `SectionTitle1`–`SectionTitle6` and `SectionContent`
- BaseTable: `BaseTableContent` (with `th` and `td` compound selectors) and `BaseTableTitle`
- HTML templates may lack styles that PDF templates have
- Report templates have no named body style

### 4. Design Table Variant Subclasses

Create a separate reporter subclass for each table visual variant. Do NOT use a single class with a `Variant` property.

| Concern | Single class + Variant | Separate subclasses |
|---------|----------------------|---------------------|
| Template editing | Must branch in buildTemplates | Each owns its template tree |
| Independence | Variants can't diverge | Each can evolve separately |
| User code | `DataTable("Variant","data","Content",ft)` | `DataTable("Content",ft)` — simpler |
| New variant | Add case to switch statement | Scaffold new class |

### 5. Write `buildTemplates` Static Methods

Each reporter class owns a static `buildTemplates(styles)` method. Group formats by editing mechanism:
- **`editPdfHtml`** — PDF and HTML (both use CSS/RawFormats)
- **`editDocx`** — Word (uses TemplateLinkedStyle/TemplateTableStyle + replaceStyle)

```matlab
methods (Static)
    function buildTemplates(styles)
        classDir = company.Chapter.getClassFolder();
        company.Chapter.editPdfHtml(classDir,"pdf","default.pdftx",styles);
        company.Chapter.editPdfHtml(classDir,"html","default.htmtx",styles);
        company.Chapter.editPdfHtml(classDir,"html","default.htmt",styles);
        company.Chapter.editDocx(classDir,styles);
    end

    function editPdfHtml(classDir,fmt,filename,styles)
        import mlreportgen.dom.*
        srcPath = fullfile(classDir,"resources","templates",fmt,filename);
        tmpPath = fullfile(tempdir,"company_Chapter_" + filename);
        tpl = Template(tmpPath,fmt,srcPath);
        open(tpl);

        entries = getStyle(tpl.Stylesheet,"SectionTitle1");
        for i = 1:numel(entries)
            raw = entries(i).RawFormats;
            raw = company.setOrAddCss(raw,"font-family",styles.fonts.heading);
            raw = company.setOrAddCss(raw,"color",styles.colors.navy);
            raw = company.setOrAddCss(raw,"font-size",styles.sizes.heading1);
            raw = company.setOrAddCss(raw,"font-weight","bold");
            entries(i).RawFormats = raw;
        end

        close(tpl);
        movefile(tmpPath,srcPath);
    end

    function editDocx(classDir,styles)
        import mlreportgen.dom.*
        srcPath = fullfile(classDir,"resources","templates","docx","default.dotx");
        tmpPath = fullfile(tempdir,"company_Chapter.dotx");
        tpl = Template(tmpPath,"docx",srcPath);
        open(tpl);

        s1 = TemplateLinkedStyle("SectionTitle1");
        s1.Formats = [Bold(true),FontSize(styles.sizes.heading1), ...
            FontFamily(styles.fonts.heading),Color(styles.colors.navy), ...
            OutlineLevel(1)];  % REQUIRED — preserves TOC heading discovery
        replaceStyle(tpl.Stylesheet,s1);

        close(tpl);
        movefile(tmpPath,srcPath);
    end
end
```

**Critical rules for `editPdfHtml`:**
- Use `getStyle(stylesheet, name)` with NO type argument — type arg returns `[]` for PDF/HTML
- Filter by `Selector` property when multiple entries match
- Modify `RawFormats` directly — style objects are handles

**Critical rules for `editDocx`:**
- Use `TemplateLinkedStyle` for linked styles (titles, headings)
- Use `TemplateTableStyle` with `HeaderFormats` for table header row styling
- Always `replaceStyle(tpl.Stylesheet, newStyle)` — DOCX styles are read-only objects
- Always include `OutlineLevel(N)` for heading styles to preserve TOC

### 6. CSS Helper Utility

Safe CSS property replacement using negative lookbehind (prevents matching `border-color` when editing `color`):

```matlab
function raw = setOrAddCss(raw,prop,value)
%setOrAddCss Replace a CSS property in a style string, or append it.
    arguments
        raw string
        prop string
        value string
    end
    pattern = "(?<![a-zA-Z-])" + regexptranslate("escape",prop) + ":\s*[^;]+";
    replacement = prop + ": " + value;
    if ~isempty(regexp(raw,pattern,"once"))
        raw = regexprep(raw,pattern,replacement);
    else
        raw = raw + " " + prop + ": " + value + ";";
    end
end
```

### 7. Thin Orchestrator

```matlab
function buildTemplates()
    pkgDir = fileparts(mfilename("fullpath"));
    styles = jsondecode(fileread(fullfile(pkgDir,"styles.json")));

    company.Chapter.buildTemplates(styles);
    company.Section.buildTemplates(styles);
    company.TitlePage.buildTemplates(styles);
    company.DataTable.buildTemplates(styles);
    company.SpecTable.buildTemplates(styles);
    company.SummaryTable.buildTemplates(styles);

    fprintf("buildTemplates: All templates updated.\n");
end
```

### 8. Table Variant Template Editing

Each table subclass implements the same pattern with its variant-specific config:

```matlab
function buildTemplates(styles)
    classDir = company.DataTable.getClassFolder();
    variant = styles.tables.data;  % ← variant-specific config
    company.DataTable.editTablePdfHtml(classDir,"pdf","default.pdftx",variant,styles);
    company.DataTable.editTablePdfHtml(classDir,"html","default.htmtx",variant,styles);
    company.DataTable.editTableDocx(classDir,variant,styles);
end

function editTablePdfHtml(classDir,fmt,filename,variant,styles)
    import mlreportgen.dom.*
    srcPath = fullfile(classDir,"resources","templates",fmt,filename);
    tmpPath = fullfile(tempdir,"company_DataTable_" + filename);
    tpl = Template(tmpPath,fmt,srcPath);
    open(tpl);

    entries = getStyle(tpl.Stylesheet,"BaseTableContent");
    for i = 1:numel(entries)
        if contains(entries(i).Selector,"th")
            raw = entries(i).RawFormats;
            raw = company.setOrAddCss(raw,"background-color",variant.headerBackground);
            raw = company.setOrAddCss(raw,"color",variant.headerColor);
            raw = company.setOrAddCss(raw,"font-size",styles.sizes.tableHeader);
            entries(i).RawFormats = raw;
        elseif contains(entries(i).Selector,"td")
            raw = entries(i).RawFormats;
            raw = company.setOrAddCss(raw,"font-size",styles.sizes.tableBody);
            raw = company.setOrAddCss(raw,"border-color",styles.tables.borderColor);
            entries(i).RawFormats = raw;
        end
    end

    close(tpl);
    movefile(tmpPath,srcPath);
end

function editTableDocx(classDir,variant,styles)
    import mlreportgen.dom.*
    srcPath = fullfile(classDir,"resources","templates","docx","default.dotx");
    tmpPath = fullfile(tempdir,"company_DataTable.dotx");
    tpl = Template(tmpPath,"docx",srcPath);
    open(tpl);

    ts = TemplateTableStyle("BaseTableContent");
    ts.Formats = [Border("solid",styles.tables.borderColor,"0.5pt"), ...
        FontSize(styles.sizes.tableBody),FontFamily(styles.fonts.body)];
    ts.HeaderFormats = [Bold(true), ...
        BackgroundColor(variant.headerBackground), ...
        Color(variant.headerColor), ...
        FontSize(styles.sizes.tableHeader)];
    replaceStyle(tpl.Stylesheet,ts);

    close(tpl);
    movefile(tmpPath,srcPath);
end
```

`SpecTable` and `SummaryTable` are identical except they reference `styles.tables.spec` and `styles.tables.summary`.

### Adding a New Table Variant

1. Add entry in JSON: `"alert": {"headerBackground": "#DC2626", "headerColor": "#FFFFFF"}`
2. Scaffold: `mlreportgen.report.BaseTable.customizeReporter("+company/@AlertTable/AlertTable.m")`
3. Add `buildTemplates(styles)` reading `styles.tables.alert`
4. Add `company.AlertTable.buildTemplates(styles)` to orchestrator

### 9. Demo Script

```matlab
function demo(fmt)
    arguments
        fmt (1,1) string {mustBeMember(fmt,["pdf","docx","html"])} = "pdf"
    end
    import mlreportgen.report.*
    import mlreportgen.dom.*

    company.buildTemplates;
    rpt = company.Report(fullfile(tempdir,"CompanyDemo"),fmt);

    tp = company.TitlePage();
    tp.Title = "Q3 2026 Engineering Report";
    tp.Author = "J. Smith";
    add(rpt,tp);

    ch = company.Chapter("Title","Test Results");
    sec = company.Section("Title","Tensile Data");
    add(sec,Paragraph("Specimens tested per ASTM E8."));

    header = ["Specimen","UTS (MPa)","Elongation"];
    body = {num(1,"%.0f"),num(250,"%.0f"),num(0.12,"%.2f"); ...
            num(2,"%.0f"),num(275,"%.0f"),num(0.15,"%.2f")};
    ft = FormalTable(header,body);
    dt = company.DataTable("Content",ft,"Title","Tensile Results");
    add(sec,dt);
    add(ch,sec);
    add(rpt,ch);

    close(rpt);
    rptview(rpt);
end

function n = num(value,fmt)
    import mlreportgen.dom.*
    n = Number(value);
    n.Style = [n.Style {NumberFormat(fmt)}];
end
```

### 10. Build and Verify

```matlab
company.buildTemplates;
for fmt = ["pdf","docx","html"]
    company.demo(fmt);
end
```

Verify:
- All three formats produce output without errors
- Styles are applied symmetrically (same elements styled in PDF, DOCX, and HTML)
- Table headers show correct variant colors
- Numbers display with specified precision

---

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Using `table()` objects for report tables | Use `FormalTable(headerCells, bodyCells)` |
| Raw numeric literals in cell arrays | Use `Number` + `NumberFormat` style |
| `Number(value, NumberFormat(...))` constructor | `n = Number(value); n.Style = [n.Style {NumberFormat(fmt)}];` |
| `getStyle(ss, name, type)` for PDF/HTML | Use `getStyle(ss, name)` without type; filter by `Selector` |
| Unqualified `Chapter.getClassFolder()` in package | Use `company.Chapter.getClassFolder()` (package-qualified) |
| Single table class with `Variant` property | Separate subclass per variant, each with own template tree |
| Monolithic `buildTemplates.m` with all logic | Each reporter owns a static `buildTemplates(styles)` method |
| Runtime style class (`AcmeStyle.HeadingFont`) | Use template stylesheets edited by `buildTemplates` |
| tmpPath without file extension | Include extension: `fullfile(tempdir,"prefix_" + filename)` |
| Assuming style names without inspecting | Always inspect scaffolded templates first |
| Styling in DOCX but not PDF/HTML | Use `editPdfHtml` + `editDocx` symmetrically |
| `DataTable(data,"Title","name")` positional+NV | Use all name-value: `("Content",ft,"Title","name")` |
| Only editing `default.htmtx` for HTML | Edit both `.htmtx` and `.htmt` |
| `regexprep(raw,"color:","navy")` without lookbehind | Use `setOrAddCss` with negative lookbehind |
| Replacing heading styles without `OutlineLevel(N)` | Always include `OutlineLevel(N)` in `TemplateLinkedStyle.Formats` |

---

## Conventions

- **Package-qualified static calls** — always `pkg.Class.method()` inside the package
- **Format symmetry** — if you style in DOCX, style in PDF and HTML too
- **Inspect before editing** — `getStyle` on scaffolded templates to discover real style names
- **tmpPath includes extension** — preserve template file extension
- **JSON is the single source of truth** — never hardcode style values in reporter methods
- **One table subclass per visual variant** — not one class with runtime switching
- **`editPdfHtml` + `editDocx`** — group by editing mechanism, not by format count
- **Handle missing styles gracefully** — `getStyle` returns empty if style doesn't exist

----

Copyright 2026 The MathWorks, Inc.

----
