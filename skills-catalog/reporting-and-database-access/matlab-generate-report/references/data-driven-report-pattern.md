# Data-Driven Report Pattern

Generate reports where a collection of data items (companies, test specimens, sites, etc.) produces one chapter per item, each with custom reporters and per-item template hole content.

## When to Use

- Struct array or table input where each row/element becomes a chapter
- Custom reporters (TitlePage, Chapter) with per-item properties (logos, tickers, names)
- Sections that may be present or missing depending on available data
- Need graceful handling of incomplete input without crashing

## Architecture

```
+mypkg/
├── @TitlePage/TitlePage.m        % Custom: firm logo hole, report metadata
├── @Chapter/Chapter.m            % Custom: per-item page headers (logo, ticker, StyleRef)
├── +reporters/                   % Section-level content builders
│   ├── SummaryReporter.m
│   ├── FinancialReporter.m
│   └── GenericSection.m
└── +helpers/
    ├── buildChapter.m            % Orchestrates sections into a chapter
    └── dataNotAvailable.m        % Graceful missing-data placeholder
```

**Entry point:** A function or script that accepts the data array, creates the Report, and loops.

## Core Pattern

```matlab
function rpt = generateReport(items,options)
%generateReport Create a multi-item report from a struct array.
    arguments
        items (1,:) struct
        options.Format (1,1) string = "pdf"
        options.OutputPath (1,1) string = fullfile(pwd,"output","report")
        options.FirmLogo (1,1) string = ""
    end
    import mlreportgen.report.*
    import mlreportgen.dom.*

    rpt = Report(options.OutputPath,options.Format);
    open(rpt);

    % --- Title Page (custom reporter, NOT built-in) ---
    tp = mypkg.TitlePage();
    tp.Title = "Portfolio Report";
    tp.Author = "Research Team";
    if options.FirmLogo ~= "" && isfile(options.FirmLogo)
        tp.FirmLogo = options.FirmLogo;
    end
    append(rpt,tp);
    append(rpt,TableOfContents());

    % --- One chapter per item ---
    for i = 1:numel(items)
        ch = mypkg.Chapter(items(i).Name);

        % Per-chapter properties fill template holes (page headers, etc.)
        ch.Ticker = items(i).Ticker;
        if isfield(items(i),"LogoPath") && isfile(items(i).LogoPath)
            ch.CompanyLogo = items(i).LogoPath;
        end

        % Delegate section assembly to a helper
        mypkg.helpers.buildChapter(ch,items(i));
        append(rpt,ch);
    end

    close(rpt);
end
```

## Critical Rules

### 1. Always instantiate YOUR custom reporter — never the built-in parent

```matlab
% WRONG — uses built-in TitlePage, your template customizations are ignored
tp = mlreportgen.report.TitlePage();

% CORRECT — uses your custom TitlePage with FirmLogoContent hole
tp = mypkg.TitlePage();
```

Every custom reporter you scaffold via `customizeReporter` MUST be instantiated by its package-qualified name. If you instantiate the parent class, your custom templates (with their holes, page headers, borders) are never loaded.

### 2. Per-item properties fill template holes automatically

The custom Chapter reporter has properties like `Ticker`, `CompanyLogo` that match template holes in the page header. When `getImpl` runs, it fills these holes from the property values. No override needed — just set the property before appending:

```matlab
ch = mypkg.Chapter("TechVision Corp");
ch.Ticker = "TVCO";
ch.CompanyLogo = "data/tvco_logo.png";
% Template holes "Ticker" and "CompanyLogo" are filled automatically
```

### 3. Graceful missing-field handling

Never let a missing field crash the report. Use a helper that checks and provides a fallback:

```matlab
function content = safeField(item,fieldName,fallback)
%safeField Return field value or fallback if missing/empty.
    arguments
        item (1,1) struct
        fieldName (1,1) string
        fallback = []
    end
    if isfield(item,fieldName) && ~isempty(item.(fieldName))
        content = item.(fieldName);
    else
        content = fallback;
    end
end
```

For sections: skip the section entirely if data is missing, or insert a "Data not available" placeholder:

```matlab
function addSectionIfPresent(ch,item,fieldName,sectionTitle)
    import mlreportgen.dom.*
    data = safeField(item,fieldName);
    if isempty(data)
        return  % Omit section entirely
    end
    sec = mlreportgen.report.Section(sectionTitle);
    % ... build section content from data ...
    append(ch,sec);
end
```

**Always use `isempty()` — never `== ""`** — to test for missing content. Struct fields may be strings, cell arrays, structs, or numeric arrays. The `==` operator fails on cell arrays with "Cell must be a cell array of character vectors."

### 4. Chapter builder orchestrates sections

Keep the main loop thin. A helper function knows the section order and delegates to section reporters:

```matlab
function buildChapter(ch,item)
%buildChapter Assemble all sections into a chapter from item data.
    import mlreportgen.report.*

    % Section order is defined here — easy to add/remove/reorder
    addExecutiveSummary(ch,item);
    addSectionIfPresent(ch,item,"CompanyUpdate","Company Update");
    addSectionIfPresent(ch,item,"InvestmentThesis","Investment Thesis");
    addSectionIfPresent(ch,item,"BusinessOverview","Business Overview");
    addFinancials(ch,item);
    addSectionIfPresent(ch,item,"Risks","Risks");
    addSectionIfPresent(ch,item,"Disclaimers","Disclaimers");
end
```

### 5. Section reporters encapsulate formatting logic

Each section reporter handles one content domain. It takes raw data (struct fields, tables, cell arrays) and produces formatted DOM content:

```matlab
function addFinancials(ch,item)
    import mlreportgen.report.*
    import mlreportgen.dom.*

    if ~isfield(item,"FinancialTable") || isempty(item.FinancialTable)
        return
    end

    sec = Section("Financial Summary");

    % Convert MATLAB table to FormalTable (never pass table() to BaseTable)
    t = item.FinancialTable;
    header = t.Properties.VariableNames;
    body = table2cell(t);
    ft = FormalTable(header,body);
    ft.Width = "6.5in";
    ft.Style = [ft.Style {ResizeToFitContents(false)}];
    ft.Header.Style = {Bold(true),BackgroundColor("#1B3A5C"),Color("white")};

    bt = BaseTable(ft);
    bt.Title = item.Name + " — Key Financials";
    append(sec,bt);
    append(ch,sec);
end
```

## Input Schema Pattern

Define expected fields clearly. Use a validation function that normalizes input:

```matlab
function items = validateInput(raw)
%validateInput Normalize input to struct array with expected fields.
    requiredFields = ["Name","Ticker"];
    optionalFields = ["Sector","LogoPath","Recommendation","CurrentPrice",...
        "TargetPrice","CompanyUpdate","InvestmentThesis","BusinessOverview",...
        "FinancialTable","Risks","Disclaimers"];

    if istable(raw)
        raw = table2struct(raw);
    end

    for i = 1:numel(raw)
        for f = requiredFields
            assert(isfield(raw(i),f) && ~isempty(raw(i).(f)),...
                "Item %d missing required field: %s",i,f);
        end
        for f = optionalFields
            if ~isfield(raw(i),f)
                raw(i).(f) = [];
            end
        end
    end
    items = raw;
end
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Instantiating `mlreportgen.report.TitlePage` instead of `mypkg.TitlePage` | Built-in template is loaded — custom holes, page borders, and layout are ignored | Always use the package-qualified custom class name |
| Checking `item.Field` without `isfield` guard | Errors on structs where the field doesn't exist | Use `isfield(item,fieldName)` before accessing |
| Putting all section logic in the main loop | Produces an unreadable 500-line function that's hard to extend | Delegate to `buildChapter` → per-section helpers |
| Passing `table()` to `BaseTable` | MATLABTable wrapper adds unwanted formatting (quotes, command-window style) | Convert to `FormalTable(headers,body)` first |
| Setting reporter properties AFTER `append(rpt,ch)` | `getImpl` runs during `append` — properties must be set before | Set all properties, THEN `append` |
| Assuming all items have the same fields | Real data has gaps — some companies lack forecasts, logos, or analyst notes | Guard every field access; skip or placeholder missing sections |

## Per-Chapter Page Header: Complete End-to-End Pattern

When each chapter needs distinct page header content (company logo, ticker, etc.), the full chain is:

1. **Reporter class** — typed properties matching template hole IDs
2. **Template** — holes in the page header (PDF and DOCX; HTML has no page headers)
3. **Generation loop** — construct Image objects from file paths, set properties BEFORE `append`

### Reporter Class (Properties)

```matlab
classdef Chapter < mlreportgen.report.Chapter
% File: +mypkg/@Chapter/Chapter.m

    properties
        % These property names MUST exactly match hole IDs in the template
        HeaderLogo {mustBeLogoValue} = []   % Fills "HeaderLogo" hole ([], Image, or path)
        HeaderTicker string = ""            % Fills "HeaderTicker" hole
    end

    methods
        function obj = Chapter(varargin)
            obj = obj@mlreportgen.report.Chapter(varargin{:});
        end

        function img = getHeaderLogo(obj)
        %getHeaderLogo Return Image object for the HeaderLogo hole.
            if isempty(obj.HeaderLogo)
                img = [];
            elseif isa(obj.HeaderLogo,"mlreportgen.dom.Image")
                img = obj.HeaderLogo;
            else
                img = mlreportgen.dom.Image(string(obj.HeaderLogo));
                img.Width = "0.4in";
                img.Height = "0.4in";
            end
        end
    end

    % ... template infrastructure methods (from customizeReporter) ...
end

% In a separate methods block or as a local function in the classdef file:
function mustBeLogoValue(v)
    if isempty(v), return; end
    if isa(v,"mlreportgen.dom.Image"), return; end
    if isstring(v) || ischar(v), return; end
    error("HeaderLogo must be [], an Image object, or a file path string.");
end
```

### Generation Loop (Constructing and Assigning)

```matlab
for i = 1:numel(items)
    ch = mypkg.Chapter(items(i).Name);  % Title = company name only (no ticker)

    % Ticker: simple string assignment
    ch.HeaderTicker = items(i).Ticker;

    % Logo: assign path string OR Image object — getHeaderLogo handles both
    if isfield(items(i),"LogoPath") && ~isempty(items(i).LogoPath) ...
            && isfile(items(i).LogoPath)
        ch.HeaderLogo = items(i).LogoPath;  % string path (getHeaderLogo wraps it)
    end
    % If no logo: property stays [], hole renders empty (graceful)

    % Build chapter content...
    mypkg.helpers.buildChapter(ch,items(i));

    % Properties MUST be set before append — getImpl runs during append
    append(rpt,ch);
end
```

### Critical Rules for Header Holes

| Rule | Why |
|------|-----|
| Property name = hole ID (exact match, case-sensitive) | Framework uses name matching to fill holes |
| Set properties BEFORE `append(rpt,ch)` | `getImpl` executes during `append` — later assignments are ignored |
| Image properties need explicit Width/Height | Without sizing, images render at natural size (often too large for headers) |
| Holes inside a Paragraph are inline | Property must be inline content (Image, Text) — NOT a Paragraph or Table |
| Block-level holes accept any content | If the hole is directly in the header (not inside a Paragraph), Paragraph/Table are fine |
| String properties fill as Text | A `string` property becomes a `Text` node in the hole — styled by the hole's `DefaultStyleName` |
| Empty properties leave holes unfilled | `[]` or `""` → hole renders nothing (graceful degradation) |
| Use untyped `= []` for optional Image properties | Typed `mlreportgen.dom.Image` fails with empty 0x0 array; use `{mustBeLogoValue} = []` with a `get<HoleId>()` accessor |

### Debugging Header Holes That Don't Render

If content doesn't appear in the page header:

1. **Verify property name matches hole ID exactly** — case-sensitive, no extra spaces
2. **Check the property is set before `append`** — add a breakpoint or `fprintf` before `append(rpt,ch)`
3. **Verify the hole exists in BOTH PDF and DOCX templates** — a hole in PDF but not DOCX means DOCX output has no content
4. **Check inline vs block context** — a hole inside a `<p>` in the template is inline; returning a `Paragraph` to an inline hole errors silently or shows nothing
5. **Re-scaffold if templates may be corrupted** — run `customizeReporter` again to get fresh templates, then re-apply your edits

## Extending the Pattern

**Adding a new section:** Create a helper function, add one line to `buildChapter`. No other code changes needed.

**Adding a new per-chapter header element:** Add a property to the custom Chapter class, add a matching template hole to the page header template (all formats), set the property in the main loop.

**Supporting a new output format:** Custom reporters with properly scaffolded templates (`customizeReporter` creates PDF, DOCX, and HTML templates) already support all formats. Just change `options.Format`.

----

Copyright 2026 The MathWorks, Inc.

----
