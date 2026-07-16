# Report API Patterns

## Full Report Structure

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

rpt = Report("EngineeringReport","pdf");

% Front matter
tp = TitlePage();
tp.Title = "Engineering Report";
tp.Subtitle = "Q1 2026 Analysis";
tp.Author = "Engineering Team";
append(rpt,tp);

append(rpt,TableOfContents());
append(rpt,ListOfFigures());
append(rpt,ListOfTables());

% Chapter with sections
ch1 = Chapter("Introduction");
append(ch1,Paragraph("This report presents Q1 results."));

sec1 = Section("Background");
append(sec1,Paragraph("Context for the analysis."));
append(ch1,sec1);

append(rpt,ch1);

% Chapter with auto-numbered table
ch2 = Chapter("Data");
import mlreportgen.dom.*
header = {"Temp (°C)","Rate (mol/s)"};
body = {25,1.2; 30,1.8; 35,2.5};
bt = BaseTable(FormalTable(header,body));
bt.Title = "Reaction rates by temperature";
bt.LinkTarget = "tbl_rates";
append(ch2,bt);
append(rpt,ch2);

% Chapter with auto-numbered figure
ch3 = Chapter("Visualization");
fig = figure("Visible","off");
plot([25 30 35],[1.2 1.8 2.5],"-o","LineWidth",2);
xlabel("Temperature (°C)"); ylabel("Rate (mol/s)");
rptFig = Figure(fig);
rptFig.Snapshot.Caption = "Rate vs temperature";
rptFig.LinkTarget = "fig_rate";
append(ch3,rptFig);
close(fig);
append(rpt,ch3);

% Cross-reference example
ch4 = Chapter("Discussion");
p = Paragraph("As shown in ");
append(p,InternalLink("tbl_rates","Table 2-1"));
append(p," and ");
append(p,InternalLink("fig_rate","Figure 3-1"));
append(p,", rate increases with temperature.");
append(ch4,p);
append(rpt,ch4);

close(rpt);
```

## Custom Heading Styles with Numbering

To control the full heading style (number prefix + title text) without customizing the template, build `Heading1`/`Heading2` objects with `CounterInc` and `AutoNumber`. The style applies uniformly to the entire heading.

```matlab
import mlreportgen.report.*
import mlreportgen.dom.*

% Define reusable chapter heading template
chTitle = Heading1("Chapter ");
chTitle.Style = {CounterInc("sect1"),WhiteSpace("preserve"),...
    Color("#005f73"),Bold,FontSize("18pt")};
append(chTitle,AutoNumber("sect1"));
append(chTitle,". ");

% Define reusable section heading template
sectTitle = Heading2();
sectTitle.Style = {CounterInc("sect2"),WhiteSpace("preserve"),...
    Color("#005f73"),Bold,FontSize("14pt")};
append(sectTitle,AutoNumber("sect1"));
append(sectTitle,".");
append(sectTitle,AutoNumber("sect2"));
append(sectTitle,". ");

% Use via clone — append title text after cloning
title = clone(chTitle);
append(title,"Introduction");
ch = Chapter(Title=title);

secT = clone(sectTitle);
append(secT,"Background");
sec = Section(Title=secT);
append(sec,Paragraph("Content here."));
append(ch,sec);
```

**Key points:**
- `clone()` the heading template before each use — append modifies in place
- `CounterInc("sect1")` increments the chapter counter; `CounterInc("sect2")` increments the section counter (resets per chapter)
- `WhiteSpace("preserve")` keeps spacing between number and title
- Style applies to the entire heading including number prefix
- Works with `TableOfContents` — headings appear in the TOC automatically

## Auto-Numbering

The Report API auto-numbers figures and tables within chapters:
- Format: `Chapter-Sequence` (e.g., "Figure 2-1" = first figure in Chapter 2)
- `BaseTable.Title` produces "Table X-Y: [your title]"
- `Figure.Snapshot.Caption` produces "Figure X-Y: [your caption]"
- `FormalImage.Caption` produces "Figure X-Y: [your caption]"
- `ListOfFigures` and `ListOfTables` collect these automatically

## FormalImage (Image from File)

Use when you have a pre-existing image file (not a MATLAB figure handle):

```matlab
fi = FormalImage("screenshot.png");
fi.Caption = "Application screenshot";
fi.Width = "5in";
append(ch,fi);
```

`FormalImage` can only be appended to Report/Chapter/Section — not to DOM objects.

## Output Formats

```matlab
rpt = Report("MyReport","pdf");       % PDF
rpt = Report("MyReport","docx");      % Word
rpt = Report("MyReport","html");      % HTML package (.htmx OPC zip)
rpt = Report("MyReport","html-file"); % Single-file HTML (.html, browsable)
```

## Reporters Available

| Reporter | Purpose |
|----------|---------|
| `Report` | Container for the full document |
| `TitlePage` | Styled title page (Title, Subtitle, Author, Image) |
| `TableOfContents` | Auto-generated from Chapter/Section headings |
| `ListOfFigures` | Auto-generated from Figure/FormalImage captions |
| `ListOfTables` | Auto-generated from BaseTable titles |
| `Chapter` | Top-level numbered section (starts new page) |
| `Section` | Subsection within a Chapter |
| `Figure` | Snapshot of a MATLAB figure handle |
| `FormalImage` | Image from file with caption |
| `BaseTable` | Auto-numbered table wrapper (pass a `FormalTable`) |
| `Equation` | LaTeX equation |
| `InlineContent` | Fill an inline template hole |

## Custom Report Class

Use `mlreportgen.report.Report.customizeReport` to create a custom Report class with its own templates:

```matlab
% Scaffold a custom Report in a package (use @class folder for isolation)
mlreportgen.report.Report.customizeReport("+xyzco/@Report");
```

This creates:
```
+xyzco/
└── @Report/
    ├── Report.m
    └── resources/templates/
        ├── pdf/
        │   └── default.pdftx
        ├── docx/
        │   └── default.dotx
        └── html/
            ├── default.htmt
            └── default.htmtx
```

Using `@Report` keeps each custom Report class self-contained. Multiple custom Report classes can coexist in the same package (e.g., `+xyzco/@Report`, `+xyzco/@BriefReport`).

Customize one or more of the default templates in the `+xyzco/resources/templates/` directory (using an editor or a Template API script). The custom Report class automatically uses the templates in its resources directory — no need to specify a template path:

```matlab
% Instantiate without specifying a template
rpt = xyzco.Report("myrpt","pdf");
append(rpt,TitlePage(Title="Custom Report"));
append(rpt,TableOfContents());
ch = Chapter("Results");
append(ch,Paragraph("Content here."));
append(rpt,ch);
close(rpt);
```

## Page Headers and Footers

### R2026a+: UseReportLayout

Starting in R2026a, define headers/footers once in the custom Report template. Then set `UseReportLayout = true` on each reporter to inherit the report-level header/footer:

```matlab
import mlreportgen.report.*

% Custom report class with header/footer defined in its template
rpt = xyzco.Report("MyReport","pdf");

% Standard reporters inherit the report header/footer
toc = TableOfContents();
toc.Layout.UseReportLayout = true;
append(rpt,toc);

ch = Chapter("Introduction");
ch.Layout.UseReportLayout = true;
append(ch,Paragraph("Content here."));
append(rpt,ch);

close(rpt);
```

### Pre-R2026a: Per-Reporter Templates

Before R2026a, there is no `UseReportLayout`. To get custom headers/footers across reporters, you must create custom versions of **each reporter type** (e.g., custom `TableOfContents`, custom `Chapter`) with templates that define the desired headers/footers.

See [custom-reporters.md](custom-reporters.md) for scaffolding and customizing reporters (Chapter, TableOfContents, etc.).

----

Copyright 2026 The MathWorks, Inc.

----
