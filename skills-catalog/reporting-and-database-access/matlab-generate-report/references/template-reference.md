# Reporter Template Reference

Pre-computed introspection of common MATLAB Report Generator reporter templates.

> **Note:** This covers frequently customized built-in reporters only. For Simulink reporters, custom reporters, or any reporter not listed here, use the introspection technique described in [template-system.md](template-system.md).

---

## TitlePage Reporter

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| Title | — | Title text |
| Subtitle | — | Subtitle text |
| Image | — | Cover image |
| Author | — | Author name |
| Publisher | — | Publisher name |
| PubDate | — | Publication date |

### DOCX Template (.dotx)

#### Holes (6)

| Hole Alias | Placeholder | Maps to Property |
|------------|-------------|------------------|
| Title | TITLE | tp.Title |
| Subtitle | SUBTITLE | tp.Subtitle |
| Image | IMAGE | tp.Image |
| Author | AUTHOR | tp.Author |
| Publisher | PUBLISHER | tp.Publisher |
| PubDate | PUB_DATE | tp.PubDate |

#### Styles

| Style ID | Font Size | Bold | Alignment | Space Before |
|----------|-----------|------|-----------|--------------|
| TitlePageTitle | 24pt (48 half-pts) | Yes | Center | 380 twips |
| TitlePageSubtitle | 20pt (40 half-pts) | Yes | Center | 320 twips |
| TitlePageImage | 18pt (36 half-pts) | Yes | Center | 220 twips |
| TitlePageAuthor | 18pt (36 half-pts) | Yes | Center | 220 twips |
| TitlePagePublisher | 10pt (20 half-pts) | No | Center | 200 twips |
| TitlePagePubDate | 10pt (20 half-pts) | No | Center | 200 twips |

All styles: line=240 (single), after=0. Base: Calibri 11pt, after=160 twips, line=259 (1.08x).

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" (12240 x 15840 twips) |
| Margins (all) | 1" (1440 twips) |
| Header/Footer distance | 0.5" (720 twips) |
| Gutter | 0 |
| Section break | Next page |

#### Document Parts (Glossary)

7 entries: TitlePageTitle, TitlePageSubtitle, TitlePageImage, TitlePageAuthor, TitlePagePublisher, TitlePagePubDate, TitlePage.

Each part (except TitlePage) wraps content in a styled paragraph with an inner `Content` hole. TitlePage is the composite with all 6 top-level holes + section properties.

### PDF Template (.pdftx)

#### Holes (6)

| Hole ID | Placeholder | Maps to Property |
|---------|-------------|------------------|
| Title | TITLE | tp.Title |
| Subtitle | SUBTITLE | tp.Subtitle |
| Image | IMAGE | tp.Image |
| Author | AUTHOR | tp.Author |
| Publisher | PUBLISHER | tp.Publisher |
| PubDate | PUBLICATION_DATE | tp.PubDate |

#### Styles (CSS)

| Class | Font Size | Bold | Alignment | Margin Top | Margin Bottom |
|-------|-----------|------|-----------|------------|---------------|
| p.TitlePageTitle | 24pt | Yes | Center | 19pt | 10pt |
| p.TitlePageSubtitle | 20pt | Yes | Center | 16pt | — |
| p.TitlePageImage | — | — | Center | — | 10pt |
| p.TitlePageAuthor | 18pt | Yes | Center | 11pt | — |
| p.TitlePagePublisher | 10pt | No | Center | 10pt | — |
| p.TitlePagePubDate | 10pt | No | Center | 10pt | — |

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" portrait |
| Top/Bottom | 0.5" / 0.5" |
| Left/Right | 1" / 1" |
| Header/Footer | 0.5" / 0.5" |
| Gutter | 0 |

`page-margin: 0.5in 1in 0.5in 1in 0.5in 0.5in 0in`

#### Document Parts

Same 7 `<dptemplate>` entries as DOCX (in docpart_templates.html). Each wraps content in a styled `<p>` with a `Content` hole.

### HTML Multi-file Template (.htmtx)

Byte-for-byte identical to PDF template. Same root.html, docpart_templates.html, root.css.

### HTML Single-file Template (.htmt)

Same holes, styles, and document parts as PDF/HTML multi-file, with these differences:

| Aspect | Multi-file | Single-file |
|--------|-----------|-------------|
| Packaging | Zip archive | Single file |
| CSS | External stylesheets/root.css | Inline `<style>` in `<head>` |
| Document parts | Separate docpart_templates.html | Inline `<dplibrary>` in `<body>` |
| Top-level `<layout>` | Present in root.html | Absent (only inside TitlePage dptemplate) |
| CSS wrapping | Plain | `/*<![CDATA[*/.../*]]>*/` |

---

## Chapter Reporter

Uses TemplateName = "Section" (shared with Section reporter).

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| Title | — | Chapter title text |
| Numbered | [] (auto) | Whether to show autonumbers |
| Content | — | Child reporters/content |
| Layout | — | Page layout override |
| TemplateName | "Section" | Template name |

### DOCX Template (.dotx)

#### Holes

Section1 (used for Chapter/top-level):

| Hole Alias | Placeholder | Purpose |
|------------|-------------|---------|
| Title | TITLE1 | Chapter title |
| Content | CONTENT | Chapter body |

SectionNumberedTitle parts (1-6):

| Hole Alias | Placeholder | Purpose |
|------------|-------------|---------|
| NumberPrefix | NUMBER_PREFIX | Text before autonumber |
| NumberSuffix | NUMBER_SUFFIX | Text after autonumber |
| Content | TITLE-CONTENT | Title text |

#### Styles

| Style ID | Font Size | Bold | Italic | Color | Outline Level | Space Before | Keep-Next |
|----------|-----------|------|--------|-------|---------------|--------------|-----------|
| SectionTitle1 | 14pt (28 half-pts) | Yes | — | #365F91 | 0 | 480 twips | Yes |
| SectionTitle2 | 13pt (26 half-pts) | Yes | — | #4F81BD | 1 | 200 twips | Yes |
| SectionTitle3 | 11pt (inherit) | Yes | — | #4F81BD | 2 | 200 twips | Yes |
| SectionTitle4 | 11pt (inherit) | Yes | Yes | #4F81BD | 3 | 200 twips | Yes |
| SectionTitle5 | 11pt (inherit) | — | — | #243F60 | 4 | 200 twips | Yes |
| SectionTitle6 | 11pt (inherit) | — | Yes | #243F60 | 5 | 200 twips | Yes |
| SectionTitleHeader | 12pt (24 half-pts) | — | — | — | — | 360 twips | — |
| SectionTitleFooter | — | — | — | — | — | — | — |
| SectionContent | — | — | — | — | — | — | — |

All title styles: line=276 (1.15x), after=0.

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" (12240 x 15840 twips) |
| Margins (all) | 1" (1440 twips) |
| Header/Footer distance | 0.5" (720 twips) |
| Gutter | 0 |
| First page different | Yes (`<w:titlePg/>`) |

#### Headers & Footers

| File | Content |
|------|---------|
| header1.xml | SectionTitleHeader paragraph + horizontal rule (6pt bottom border) |
| footer1.xml | Empty SectionTitleFooter paragraph |
| footer2.xml | SectionTitleFooter with PAGE field (page number) |

#### Autonumbering

SEQ fields: sect1-sect6, figure, table. SectionNumberedTitle1 resets all lower counters plus figure/table.

#### Document Parts

| docPart | Holes | Notes |
|---------|-------|-------|
| Section1-Section6 | Title, Content | Section1 includes sectPr for page layout |
| SectionTitle1-SectionTitle6 | Content | Styled paragraph |
| SectionNumberedTitle1-SectionNumberedTitle6 | NumberPrefix, NumberSuffix, Content | SEQ fields + styled paragraph |

### PDF Template (.pdftx)

#### Holes

Same structure: Section1-Section6 each have Title + Content holes.

Title holes specify `default-style-name`:

| dptemplate | Title style | Content style |
|------------|-------------|---------------|
| Section1 | SectionTitle1 | SectionContent |
| Section2 | SectionTitle2 | SectionContent |
| Section3-6 | SectionTitle3-6 | SectionContent |

#### Styles (CSS)

| Selector | Font | Size | Weight | Style | Color | Margin-Top |
|----------|------|------|--------|-------|-------|------------|
| h1.SectionTitle1 | Cambria + Noto | 14pt | bold | — | rgb(54,95,145) | 24pt |
| h2.SectionTitle2 | Cambria + Noto | 13pt | bold | — | rgb(79,129,189) | 10pt |
| h3.SectionTitle3 | Cambria + Noto | 11pt | bold | — | rgb(79,129,189) | 10pt |
| h4.SectionTitle4 | Cambria + Noto | 11pt | bold | italic | rgb(79,129,189) | 10pt |
| h5.SectionTitle5 | Cambria + Noto | 11pt | — | — | rgb(36,63,96) | 10pt |
| h6.SectionTitle6 | Cambria + Noto | 11pt | — | italic | rgb(36,63,96) | 10pt |
| p.SectionTitleHeader | — | 11pt | — | — | black | — |
| p.SectionTitleFooter | — | 11pt | — | — | black | — |
| p.SectionContent | — | 11pt | — | — | — | 10pt |

All titles: margin-bottom: 0pt, white-space: pre, -fo-keep-with-next.within-page: always.

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" portrait |
| Top/Bottom | 0.5" / 0.5" |
| Left/Right | 1" / 1" |
| Header/Footer | 0.5" / 0.5" |
| Gutter | 0 |
| Page numbering | Decimal (format="1") |

#### Headers & Footers (PDF)

| Template | Content |
|----------|---------|
| SectionFirstPageHeader | Empty SectionTitleHeader + `<hr/>` |
| SectionFirstPageFooter | `<hr/>` + page number |
| SectionDefaultPageHeader | `<StyleRef style-name="SectionTitle1"/>` + `<hr/>` |
| SectionDefaultPageFooter | `<hr/>` + page number |
| SectionEvenPageHeader | `<StyleRef style-name="SectionTitle1"/>` + `<hr/>` |
| SectionEvenPageFooter | `<hr/>` + page number |

#### Autonumbering (PDF)

`<autonumber stream-name="sectN">` with counter-increment/reset CSS:
- SectionNumberedTitle1: `counter-increment:sect1; counter-reset:sect2 sect3 sect4 sect5 sect6 figure table`
- SectionNumberedTitle2: `counter-increment:sect2; counter-reset:sect3 sect4 sect5 sect6`
- (continues to level 6)

### HTML Single-file Template (.htmt)

| Aspect | PDF (.pdftx) | Single-file (.htmt) |
|--------|-------------|---------------------|
| `<layout>` | In Section1 | None (browser rendering) |
| Headers/footers | 6 templates | None |
| SectionContent style | Defined | Not defined |
| SectionTitleHeader/Footer | Defined | Not defined |
| Font fallbacks | Includes 'Noto Emoji' | Excludes 'Noto Emoji' |
| Autonumber stream names | sect1-sect6 | h1-h6 |
| Counter CSS | In `<h>` style attributes | `span.an_sectN:before` rules |
| SectionNumberedTitle1 resets | figure table | figure table |

### HTML Multi-file Template (.htmtx)

Identical to PDF template in structure and content.

---

## Cross-Format Summary

### Format Packaging

| Format | Extension | Structure |
|--------|-----------|-----------|
| Word | .dotx | Zip (OpenXML): word/document.xml, word/styles.xml, word/glossary/document.xml |
| PDF | .pdftx | Zip: root.html, stylesheets/root.css, docpart_templates.html |
| HTML multi-file | .htmtx | Zip: same as PDF |
| HTML single-file | .htmt | Single file: inline CSS + inline dplibrary |

### Hole Mechanism

| Format | Hole syntax | Inner holes |
|--------|-------------|-------------|
| DOCX | `<w:sdt>` with `<w:tag w:val="Hole"/>` and `<w:alias>` | Same |
| PDF/HTML | `<hole id="Name">placeholder</hole>` | Same |

### Document Part Library

| Format | Location | Entry syntax |
|--------|----------|--------------|
| DOCX | word/glossary/document.xml | `<w:docPart><w:docPartPr><w:name w:val="..."/>` |
| PDF/HTML multi-file | docpart_templates.html | `<dptemplate name="...">` inside `<dplibrary>` |
| HTML single-file | Inline in body | Same `<dptemplate>` inside inline `<dplibrary>` |

### Page Layout Differences (TitlePage)

| Property | DOCX | PDF/HTML |
|----------|------|----------|
| Top margin | 1" | 0.5" |
| Bottom margin | 1" | 0.5" |
| Left/Right | 1" | 1" |

### Naming Convention: PubDate Placeholder

| Format | Placeholder text |
|--------|-----------------|
| DOCX | PUB_DATE |
| PDF/HTML | PUBLICATION_DATE |

---

## TableOfContents Reporter

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| Title | [] (empty) | TOC heading text |
| NumberOfLevels | 3 | How many heading levels to include |
| TemplateName | "TableOfContents" | Template name |

### DOCX Template (.dotx)

#### Holes (2, in TableOfContents docpart)

| Hole Alias | Placeholder | Purpose |
|------------|-------------|---------|
| Title | TITLE | TOC heading (styled with TableOfContentsTitleChar) |
| TOCObj | TOC_OBJECT | The generated table of contents |

#### Styles

| Style ID | Font | Font Size | Bold | Spacing After | Line Spacing |
|----------|------|-----------|------|---------------|--------------|
| TableOfContentsTitle | Arial | 20pt (40 half-pts) | Yes | 200 twips | 240 (single) |

Base defaults: Calibri 11pt, after=160 twips, line=259 (1.08x).

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" (12240 x 15840 twips) |
| Margins (all) | 1" (1440 twips) |
| Header/Footer distance | 0.5" (720 twips) |
| Gutter | 0 |

#### Headers & Footers

| File | Content |
|------|---------|
| header1.xml | Empty (Header style) |
| footer1.xml | Centered PAGE field (page number) |

The glossary also defines header2.xml (empty with spaces) and footer2.xml (centered PAGE field) for use within the TableOfContents docpart's sectPr.

#### Document Parts (Glossary)

| docPart | Content |
|---------|---------|
| TableOfContentsTitle | Paragraph styled TableOfContentsTitle with inner `Content` hole |
| TableOfContents | Composite: Title hole + TOCObj hole + sectPr (page layout + header/footer refs) |

### PDF Template (.pdftx)

#### Holes

The root.html body contains:

| Element | Purpose |
|---------|---------|
| `<hole id="Title" default-style-name="TableOfContentsTitle">` | TOC heading |
| `<toc/>` | Native TOC element (not a hole — generated automatically) |

The TableOfContents dptemplate has:

| Hole ID | Placeholder | Purpose |
|---------|-------------|---------|
| Title | TITLE | TOC heading |
| TOCObj | TOC_OBJECT | Generated TOC content |

#### Styles (CSS)

| Selector | Font Size | Bold | Color | Margin Top | Margin Bottom | Alignment |
|----------|-----------|------|-------|------------|---------------|-----------|
| h1.TableOfContentsTitle, p.TableOfContentsTitle | 16pt | Yes | black | 16pt | 10pt | — |
| p.TableOfContentsTitleHeader | 10pt | No | black | — | — | Center |
| p.TableOfContentsTitleFooter | 10pt | No | black | — | — | Center |

All styles: white-space: pre.

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" portrait |
| Top/Bottom | 0.5" / 0.5" |
| Left/Right | 1" / 1" |
| Header/Footer | 0.5" / 0.5" |
| Gutter | 0 |
| **Page numbering** | **Lowercase Roman (format="i")** |

`page-margin: 0.5in 1in 0.5in 1in 0.5in 0.5in 0in`

#### Headers & Footers (PDF)

| Template | Content |
|----------|---------|
| rgTableOfContentsFirstPageHeader | Empty TableOfContentsTitleHeader |
| rgTableOfContentsFirstPageFooter | `<page/>` (page number) |
| rgTableOfContentsDefaultPageHeader | Empty TableOfContentsTitleHeader |
| rgTableOfContentsDefaultPageFooter | `<hr/>` + `<page/>` |
| rgTableOfContentsEvenPageHeader | Empty TableOfContentsTitleHeader |
| rgTableOfContentsEvenPageFooter | `<hr/>` + `<page/>` |

### HTML Multi-file Template (.htmtx)

Significantly different from PDF — designed for interactive browser viewing.

#### Holes (2, in TableOfContents dptemplate)

| Hole ID | Placeholder | default-style-name |
|---------|-------------|--------------------|
| Title | TITLE | TableOfContentsTitle |
| TOCObj | TOC_OBJECT | TOC |

#### Styles (CSS)

| Selector | Properties |
|----------|------------|
| p.TableOfContentsTitle | 12pt, bold |
| TOC (element) | background: #f2f2f2 (light gray), display: none (hidden by default) |
| ul.TOCItems | no bullets, padding-left: 1em |
| ul.TOCItems ul | no bullets, padding-left: 1.2em |
| a.TOCItemTitle | Arial, 10pt, bold, blue, underlined |
| span.TOCHandle | 10x10px box, expand/collapse icon |

#### Document Parts

| dptemplate | Content |
|------------|---------|
| TableOfContents | `<div>` wrapping Title hole + TOCObj hole |
| TableOfContentsTitle | `<p class="TableOfContentsTitle">` with expand/collapse `<span>` handle + Content hole |

#### Interactive Behavior

The HTML template includes a collapsible TOC: a clickable `span.TOCHandle` with `onclick="util.toggleTOCVisibility(...)"` toggles the TOC element between visible/hidden. Plus/minus icons indicate state.

No `<layout>`, no headers/footers, no page numbering (browser rendering).

### HTML Single-file Template (.htmt)

Identical to multi-file HTML in structure and CSS. Same interactive expand/collapse behavior.

| Aspect | Multi-file (.htmtx) | Single-file (.htmt) |
|--------|---------------------|---------------------|
| CSS | External root.css | Inline `<style>` with CDATA wrapping |
| dplibrary | Separate docpart_templates.html | Inline in `<body>` |

### Key Differences Across Formats

| Aspect | DOCX | PDF | HTML |
|--------|------|-----|------|
| Title font | Arial 20pt | 16pt (default font) | 12pt (default font) |
| Page numbering | Arabic (PAGE field) | **Lowercase Roman (i, ii, iii)** | N/A |
| TOC mechanism | TOCObj hole (Word TOC field) | `<toc/>` element | Interactive collapsible div |
| Headers/Footers | Empty header, page# footer | Empty header, hr+page# footer | None |
| Page margins | 1" all sides | 0.5" top/bottom, 1" sides | N/A |

---

## Report Reporter

The Report template is a **container** — it provides global page layout, base styles, and interactive infrastructure but has **no holes**. Content comes from child reporters (TitlePage, Chapter, TableOfContents, etc.) added via `add()`.

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| OutputPath | — | Output file path |
| Type | "pdf" | Output format: "pdf", "docx", "html", "html-file" |
| PackageType | "" | Package type (single-file vs zipped) |
| TemplatePath | — | Path to custom template |
| Locale | "" | Locale for report |
| Debug | — | Debug mode |
| Layout | — | Page layout override |

### DOCX Template (.dotx)

#### Holes

**None.** The document body is empty — just a blank paragraph with section properties.

#### No Glossary / No Document Parts

Unlike TitlePage, Chapter, and TableOfContents, the Report DOCX template has no `word/glossary/` folder and no document parts.

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" (12240 x 15840 twips) |
| Margins (all) | 1" (1440 twips) |
| Header/Footer distance | 0.5" (720 twips) |
| Gutter | 0 |
| Doc grid | linePitch=360 |

#### No Headers/Footers

No header or footer XML files — child reporters (Chapter, TOC) supply their own via their docpart sectPr definitions.

#### Styles (93 paragraph + 3 table)

The Report template provides the **master style catalog** used by all child reporters:

**Heading styles (Heading1-Heading9):**

| Style | Size | Bold | Italic | Color | Space Before |
|-------|------|------|--------|-------|--------------|
| Heading1 | 14pt (28 half-pts) | Yes | — | #365F91 | 480 twips |
| Heading2 | 13pt (26 half-pts) | Yes | — | #4F81BD | 200 twips |
| Heading3 | 11pt (inherit) | Yes | — | #4F81BD | 200 twips |
| Heading4 | 11pt (inherit) | Yes | Yes | #4F81BD | 200 twips |
| Heading5 | 11pt (inherit) | — | — | #243F60 | 200 twips |
| Heading6 | 11pt (inherit) | — | Yes | #243F60 | 200 twips |
| Heading7 | 11pt (inherit) | — | Yes | #404040 | 200 twips |
| Heading8 | 10pt (20 half-pts) | — | — | #404040 | 200 twips |
| Heading9 | 10pt (20 half-pts) | — | Yes | #404040 | 200 twips |

All headings: keepNext, keepLines, line=276 (1.15x), after=0, major theme font (Cambria).

**TOC styles (TOC1-TOC9):** For Word's built-in table of contents field.

**List styles:** ListBullet (1-5), ListNumber (1-5), ListContinue (1-5), ListParagraph, List (1-5).

**Table styles:**

| Style | Properties |
|-------|------------|
| TableNormal | Default (cell margins: 108 twips left/right) |
| TableGrid | Standard grid |
| rgMATLABTable | Centered text, Calibri font, bold first row, no spacing |

**Other notable styles:** Title (56 half-pts/28pt), Subtitle (colored text), Caption, BlockText, BodyText variants, HTMLPreformatted (Consolas 10pt).

#### Numbering Definitions

23 abstract numbering definitions + 25 instances for all list styles (ListBullet, ListNumber, etc.).

### PDF Template (.pdftx)

#### Holes

**None.** The body is empty (contains only a commented-out layout example).

#### No Document Parts

Empty `<dplibrary>`.

#### Page Layout

**Commented out** (not active by default):
```
<!-- <layout style="page-margin: 1in 1in 1in 1in 0.5in 0.5in 0in; page-size: 8.5in 11in portrait" /> -->
```

Child reporters provide their own `<layout>` elements.

#### Styles (CSS)

**TOC styles:**

| Selector | Size | Indent |
|----------|------|--------|
| p.TOC1 | 10pt | 0 |
| p.TOC2 | 10pt | 24pt |
| p.TOC3 | 10pt | 48pt |
| p.TOC4 | 10pt | 72pt |
| p.TOC5 | 10pt | 96pt |
| p.TOC6 | 10pt | 120pt |
| p.LOC | 10pt | 0 |

All TOC styles: margin-bottom 2pt.

**Heading styles (h1-h6):**

| Selector | Font | Size | Weight | Style | Color | Margin-Top |
|----------|------|------|--------|-------|-------|------------|
| h1 | Cambria + Noto + Noto Emoji | 14pt | bold | — | rgb(54,95,145) | 24pt |
| h2 | Cambria + Noto + Noto Emoji | 13pt | bold | — | rgb(79,129,189) | 10pt |
| h3 | Cambria + Noto + Noto Emoji | 11pt | bold | — | rgb(79,129,189) | 10pt |
| h4 | Cambria + Noto + Noto Emoji | 11pt | bold | italic | rgb(79,129,189) | 10pt |
| h5 | Cambria + Noto + Noto Emoji | 11pt | — | — | rgb(36,63,96) | 10pt |
| h6 | Cambria + Noto + Noto Emoji | 11pt | — | italic | rgb(36,63,96) | 10pt |

All headings: margin-bottom 0, white-space pre, -fo-keep-with-next.within-page: always.

**Other styles:**

| Selector | Purpose |
|----------|---------|
| p.LinkTargetWrapper | line-height: 0pt; keep-with-next (invisible anchor wrapper) |
| a | blue, underlined |
| hr | 0.5pt solid black |
| table.rgMATLABTable | centered, no border, bold th, tight padding |
| table/th/td/tr | default border-width: 1px (all sides) |

### HTML Multi-file Template (.htmtx)

#### Holes

**None.** Empty body with `onload="outline()"`.

#### No Document Parts

Empty `<dplibrary>`.

#### JavaScript Infrastructure

9 external script files:

| Script | Purpose |
|--------|---------|
| cssrule.js | CSS rule manipulation |
| toc.js | HTML outline algorithm for TOC generation |
| util.js | Autonumbering, TOC/LOF/LOT visibility toggles |
| moduletabs.js | Tabbed content panes |
| loc.js | List of Contents (figures/tables) |
| sidebar.js | Collapsible sidebar navigation |
| sort-table.js | Sortable table columns |
| collapsible.js | Collapsible table rows |
| chart.js | amCharts 4 integration |

Also loads amCharts 4 from CDN (`cdn.amcharts.com`).

#### Styles (CSS)

**Heading styles (h1-h6):** Same as PDF but **without** 'Noto Emoji' in font fallback and without `-fo-keep-with-next`.

**Body/table/list fonts:** Noto Sans + CJK variants.

**Table:** rgMATLABTable (centered, bold th, tight padding).

**Sidebar navigation CSS:** Fixed position, 200px wide, animated slide-in, overlay backdrop, hamburger button.

**Interactive styles:** `.collapsible` cursor pointer, hover highlight.

#### Image Assets

4 PNG files for expand/collapse TOC handles: plus.png, plus-hover.png, minus.png, minus-hover.png.

### HTML Single-file Template (.htmt)

Same as multi-file but **all JS inlined** in `<script>` blocks within `<head>`. Same empty dplibrary. Same interactive behavior.

### Key Differences Across Formats

| Aspect | DOCX | PDF | HTML |
|--------|------|-----|------|
| Holes | None | None | None |
| Document parts | None | None (empty dplibrary) | None (empty dplibrary) |
| Page layout | Active (1" margins) | Commented out | N/A (browser) |
| Heading font | Major theme (Cambria) | Cambria + Noto Emoji | Cambria + Noto Sans |
| TOC styles | Built-in Word TOC1-9 | p.TOC1-6 (indented) | JS-generated outline |
| Table style | rgMATLABTable (Word table style) | rgMATLABTable (CSS) | rgMATLABTable (CSS) |
| Numbering | numbering.xml (23 defs) | N/A (handled by DOM) | JS autonumber |
| Interactive | No | No | Yes (sidebar, sortable, collapsible, tabs) |

### Architecture Note

The Report template is the **root container**. It:
1. Defines the **global style catalog** (headings, tables, lists, TOC) that child reporters inherit
2. Provides **page layout defaults** (though PDF leaves this commented out, letting child reporters define their own)
3. In HTML, supplies all **JavaScript infrastructure** for interactive features
4. Has **no holes** — child reporters are appended directly to the document body

---

## BaseTable Reporter

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| Title | — | Table caption/title |
| Content | — | Table data (array, table, DOM table) |
| TableStyleName | "" | CSS/Word table style name |
| TableWidth | — | Table width |
| MaxCols | — | Max columns before slicing |
| RepeatCols | — | Columns repeated on each slice |
| TableSliceTitleStyleName | — | Style for slice continuation titles |
| TableEntryUpdateFcn | — | Callback for custom cell formatting |
| TemplateName | "BaseTable" | Template name |

### DOCX Template (.dotx)

#### Holes (2, in BaseTable docpart)

| Hole Alias | Placeholder | Purpose |
|------------|-------------|---------|
| Title | TITLE | Table caption |
| Content | CONTENT | Table body |

#### Styles

| Style ID | Font | Size | Bold | Space Before | Space After | Line | Keep-Next | Widow Control |
|----------|------|------|------|--------------|-------------|------|-----------|---------------|
| BaseTableTitle | Times New Roman | 12pt (24 half-pts) | Yes | 200 twips | 100 twips | 260 atLeast | Yes | Off |
| BaseTableSlicedTableContentTitle | Times New Roman | 11pt (inherit) | Yes | 200 twips | 100 twips | 260 atLeast | Yes | Off |

BaseTableSlicedTableContentTitle is used in the main document body (for sliced table continuation titles).

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" (12240 x 15840 twips) |
| Margins (all) | 1" (1440 twips) |
| Header/Footer distance | 0.5" (720 twips) |
| Gutter | 0 |
| Headers/Footers | Even, default, and first (all referenced) |

#### Document Parts (Glossary)

| docPart | Style | Holes | Purpose |
|---------|-------|-------|---------|
| BaseTable | Normal | Title, Content | Main composite template |
| BaseTableContent | Normal | Content | Wraps the table content |
| BaseTableNumberedTitle | BaseTableTitle | NumberPrefix, NumberSuffix, Content | Caption with flat numbering: `SEQ table` |
| BaseTableHierNumberedTitle | BaseTableTitle | NumberPrefix, NumberSuffix, Content | Caption with hierarchical numbering: `SEQ sect1 \c`.`SEQ table` |

#### Autonumbering (DOCX)

- **BaseTableNumberedTitle:** `SEQ table \* ARABIC` — flat table counter
- **BaseTableHierNumberedTitle:** `SEQ sect1 \c \* ARABIC` (current chapter, no increment) + `.` + `SEQ table \* ARABIC` — gives "1.1", "1.2", etc.

### PDF Template (.pdftx)

#### Holes (2, in BaseTable dptemplate)

| Hole ID | Placeholder | Purpose |
|---------|-------------|---------|
| Title | TITLE | Table caption |
| Content | CONTENT | Table body |

#### Styles (CSS)

| Selector | Size | Bold | Spacing | Other |
|----------|------|------|---------|-------|
| p.BaseTableTitle | 12pt | Yes | padding-top: 12pt, margin-bottom: 7.3pt | black, white-space: pre, keep-with-next |
| table.BaseTableContent td/th | 10pt | — | padding: 2pt all | border: solid 1px |
| p.BaseTableSlicedTableContentTitle | 10pt | Yes | padding-top: 10pt, margin-bottom: 7.3pt | black, white-space: pre, keep-with-next |

#### Document Parts

| dptemplate | Holes | Purpose |
|------------|-------|---------|
| BaseTable | Title, Content | Main composite |
| BaseTableContent | Content (default-style-name="BaseTableContent") | Table content wrapper |
| BaseTableNumberedTitle | NumberPrefix, NumberSuffix, Content | Flat: `<autonumber stream-name="table"/>` |
| BaseTableHierNumberedTitle | NumberPrefix, NumberSuffix, Content | Hierarchical: `<autonumber stream-name="sect1"/>.<autonumber stream-name="table"/>` |

Both numbered title templates use `style="counter-increment:table"` on the `<p>`.

#### No Page Layout

Empty `<body>` in root.html — inherits from parent (Report/Chapter).

### HTML Multi-file Template (.htmtx)

Same document parts as PDF. Styles differ slightly:

| Selector | Size | Bold | Spacing | Other |
|----------|------|------|---------|-------|
| p.BaseTableTitle | 12pt | Yes | margin-top: 12pt, margin-bottom: 7.3pt | black, white-space: pre |
| table.BaseTableContent td/th | 16px | — | — | border: solid 1px, border-collapse, normal weight/style |
| table.BaseTableContent | — | — | — | border-collapse: collapse |
| p.BaseTableSlicedTableContentTitle | 10pt | Yes | margin-top: 10pt, margin-bottom: 7.3pt | black, white-space: pre |

Autonumber CSS counters:
```css
span.an_sect1:before {content: counter(sect1);}
span.an_table:before {content: counter(table);}
```

### HTML Single-file Template (.htmt)

Identical to multi-file HTML in structure, styles, and document parts. CSS is inline.

### Key Differences Across Formats

| Aspect | DOCX | PDF | HTML |
|--------|------|-----|------|
| Title font | Times New Roman 12pt | 12pt (default) | 12pt (default) |
| Title spacing | before 200tw, after 100tw | padding-top 12pt, margin-bottom 7.3pt | margin-top 12pt, margin-bottom 7.3pt |
| Table cells | Styled by table style (rgMATLABTable or custom) | 10pt, 1px border, 2pt padding | 16px, 1px border, border-collapse |
| Numbering | SEQ fields (table, sect1\c) | `<autonumber>` elements | CSS counter spans |
| Sliced title style | Times New Roman 11pt bold | 10pt bold | 10pt bold |

### Localization

The `BaseTableTitleNumberPrefixSuffix.xml` file provides locale-aware prefix/suffix for table captions:

| Locale | Prefix | Suffix |
|--------|--------|--------|
| en | "Table " | ". " |
| de | "Tabelle " | ". " |
| fr | "Tableau " | ". " |
| ja | "表 " | ". " |
| zh | "表 " | ". " |

(30+ locales defined)

---

## Figure Reporter

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| Source | — | Figure handle or file path |
| Snapshot | — | Image object of the figure |
| SnapshotFormat | "svg" | Image format (svg, png, jpg, etc.) |
| Scaling | — | Image scaling mode |
| Height | — | Custom height |
| Width | — | Custom width |
| PreserveBackgroundColor | — | Keep figure background |
| Theme | — | Graphics theme for printing |
| TemplateName | "Figure" | Template name |

### DOCX Template (.dotx)

#### Holes (1, in Figure docpart)

| Hole Alias | Placeholder | Purpose |
|------------|-------------|---------|
| Content | CONTENT | The assembled figure (image + caption) |

The Figure docpart is a simple wrapper with a single Content hole. The image and caption are filled via separate document parts.

#### Styles

| Style ID | Font | Size | Bold | Space Before | Space After | Line | Other |
|----------|------|------|------|--------------|-------------|------|-------|
| FigureImage | (inherit) | (inherit) | — | 200 twips | 0 | (inherit) | Paragraph style for image placement |
| FigureCaption | Arial | 10pt (20 half-pts) | — | 120 twips | 200 twips | 240 (single) | Caption text below image |

Also defines `rgTableTitle` (Times New Roman 10pt, keepNext, before 200tw, after 100tw) — likely inherited from a shared base.

#### Page Layout

| Property | Value |
|----------|-------|
| Page size | 8.5" x 11" (12240 x 15840 twips) |
| Margins (all) | 1" (1440 twips) |
| Header/Footer distance | 0.5" (720 twips) |
| Gutter | 0 |

Main body contains a paragraph styled `FigureImage` (used as the image area).

#### Document Parts (Glossary)

| docPart | Style | Holes | Purpose |
|---------|-------|-------|---------|
| Figure | Normal | Content | Main composite — wraps everything |
| FigureImage | FigureImage | Content (placeholder: IMAGE_CONTENT) | Image paragraph |
| FigureNumberedCaption | FigureCaption | NumberPrefix, NumberSuffix, Content | Flat: `SEQ figure` |
| FigureHierNumberedCaption | FigureCaption | NumberPrefix, NumberSuffix, Content | Hierarchical: `SEQ sect1 \c`.`SEQ figure` |

#### Autonumbering (DOCX)

- **FigureNumberedCaption:** `SEQ figure \* ARABIC` — flat figure counter
- **FigureHierNumberedCaption:** `SEQ sect1 \c \* ARABIC` (current chapter) + `.` + `SEQ figure \* ARABIC` — gives "1.1", "1.2", etc.

### PDF Template (.pdftx)

#### Holes (1, in root.html body)

| Hole ID | Placeholder | Purpose |
|---------|-------------|---------|
| Content | CONTENT | The assembled figure |

#### Styles (CSS)

| Selector | Size | Properties |
|----------|------|------------|
| p.FigureCaption | 10pt | black, white-space: pre, -fo-keep-with-previous.within-page: always |
| p.FigureImage | — | margin-bottom: 10pt |

#### Document Parts

| dptemplate | Holes | Purpose |
|------------|-------|---------|
| Figure | Content | Main composite |
| FigureImage | Content (in `<p class="FigureImage">`) | Image paragraph |
| FigureHierNumberedCaption | NumberPrefix, NumberSuffix, Content | Hierarchical: `<autonumber stream-name="sect1"/>.<autonumber stream-name="figure"/>` |
| FigureNumberedCaption | NumberPrefix, NumberSuffix, Content | Flat: `<autonumber stream-name="figure"/>` |

Both caption templates use `style="counter-increment:figure"` on the `<p>`.

#### No Page Layout

Empty `<body>` in root.html (only a Content hole) — inherits from parent.

### HTML Multi-file Template (.htmtx)

Same structure as PDF template (separate docpart_templates.html + root.css). Same document parts.

### HTML Single-file Template (.htmt)

Same document parts as PDF/multi-file HTML, with:
- Inline CSS (same styles)
- Autonumber via CSS counters: `span.an_sect1:before`, `span.an_figure:before`

### Key Differences Across Formats

| Aspect | DOCX | PDF | HTML |
|--------|------|-----|------|
| Caption font | Arial 10pt | 10pt (default) | 10pt (default) |
| Caption position | Below image (keep-with via next:Normal) | Below image (keep-with-previous) | Below image |
| Image spacing | before 200tw, after 0 | margin-bottom 10pt | margin-bottom 10pt |
| Caption spacing | before 120tw, after 200tw | (none specified beyond font) | (none specified) |
| Numbering | SEQ fields (figure, sect1\c) | `<autonumber>` elements | CSS counter spans |

### Comparison with BaseTable

The Figure reporter mirrors BaseTable's numbering pattern:

| Aspect | Figure | BaseTable |
|--------|--------|-----------|
| Counter name | `figure` | `table` |
| Flat template | FigureNumberedCaption | BaseTableNumberedTitle |
| Hier template | FigureHierNumberedCaption | BaseTableHierNumberedTitle |
| Caption style | FigureCaption (Arial 10pt) | BaseTableTitle (Times New Roman 12pt bold) |
| Caption position | Below image | Above table |
| Keep-with | keep-with-previous (stays with image above) | keep-with-next (stays with table below) |
| Localization file | None (hardcoded in reporter) | BaseTableTitleNumberPrefixSuffix.xml |

---

## FormalImage Reporter

### Properties

| Property | Default | Purpose |
|----------|---------|---------|
| Image | — | Image path or DOM Image object |
| Caption | — | Caption text |
| Width | — | Image width |
| Height | — | Image height |
| Map | — | Image map (clickable regions) |
| ScaleToFit | — | Scale image to fit page |
| TemplateName | "FormalImage" | Template name |

### DOCX Template (.dotx)

#### Holes (2, in FormalImage docpart)

| Hole Alias | Placeholder | Purpose |
|------------|-------------|---------|
| Image | IMAGE | The image content |
| Caption | CAPTION | The caption content |

#### Styles

| Style ID | Font | Size | Space Before | Space After | Line |
|----------|------|------|--------------|-------------|------|
| FormalImageImage | (inherit) | (inherit) | 200 twips | 0 | 240 (single) |
| FormalImageCaption | Arial | 10pt (20 half-pts) | 120 twips | 200 twips | 240 (single) |

#### Page Layout

Same as other reporters: 8.5" x 11", 1" margins, 720 twips header/footer.

#### Document Parts (Glossary)

| docPart | Style | Holes | Purpose |
|---------|-------|-------|---------|
| FormalImage | Normal | Image, Caption | Main composite — two separate holes |
| FormalImageImage | FormalImageImage | Content (placeholder: IMAGE) | Image paragraph |
| FormalImageNumberedCaption | FormalImageCaption | NumberPrefix, NumberSuffix, Content | Flat: `SEQ figure` |
| FormalImageHierNumberedCaption | FormalImageCaption | NumberPrefix, NumberSuffix, Content | Hierarchical: `SEQ sect1 \c`.`SEQ figure` |

#### Autonumbering (DOCX)

Same as Figure reporter:
- **FormalImageNumberedCaption:** `SEQ figure \* ARABIC`
- **FormalImageHierNumberedCaption:** `SEQ sect1 \c \* ARABIC` + `.` + `SEQ figure \* ARABIC`

### PDF Template (.pdftx)

#### Holes (2, in FormalImage dptemplate)

| Hole ID | Placeholder | Purpose |
|---------|-------------|---------|
| Image | IMAGE | Image content |
| Caption | CAPTION | Caption content |

#### Styles (CSS)

| Selector | Size | Properties |
|----------|------|------------|
| p.FormalImageImage | — | margin-bottom: 10pt |
| p.FormalImageCaption | 10pt | black, white-space: pre, -fo-keep-with-previous.within-page: always |

#### Document Parts

| dptemplate | Holes | Purpose |
|------------|-------|---------|
| FormalImage | Image, Caption | Main composite |
| FormalImageImage | Content (in `<p class="FormalImageImage">`) | Image paragraph |
| FormalImageHierNumberedCaption | NumberPrefix, NumberSuffix, Content | Hierarchical: `<autonumber stream-name="sect1"/>.<autonumber stream-name="figure"/>` |
| FormalImageNumberedCaption | NumberPrefix, NumberSuffix, Content | Flat: `<autonumber stream-name="figure"/>` |

Both caption templates use `style="counter-increment:figure"` on the `<p>`.

#### No Page Layout

Empty `<body>` in root.html — inherits from parent.

### HTML Single-file Template (.htmt)

Same document parts as PDF. Inline CSS. Autonumber via:
```css
span.an_sect1:before {content: counter(sect1);}
span.an_figure:before {content: counter(figure);}
```

### HTML Multi-file Template (.htmtx)

Same as single-file but with external CSS and separate docpart_templates.html.

### Key Differences from Figure Reporter

| Aspect | FormalImage | Figure |
|--------|------------|--------|
| Main holes | **Image + Caption** (separate) | **Content** (single composite) |
| Style prefix | `FormalImage*` | `Figure*` |
| Image property | `Image` (path or DOM object) | `Source` (figure handle or path) |
| Snapshot support | No (static images only) | Yes (captures MATLAB figures) |
| Localization | FormalImageCaptionNumberPrefixSuffix.xml (30+ locales) | None |
| Use case | Static images with captions | MATLAB figure snapshots |

The FormalImage template has **two top-level holes** (Image + Caption) whereas Figure has just one (Content). This means FormalImage gives more template-level control over image/caption layout.

### Localization

| Locale | Prefix | Suffix |
|--------|--------|--------|
| en | "Figure " | ". " |
| de | "Abbildung " | ". " |
| fr | "Figure " | ". " |
| ja | "図 " | ". " |
| zh | "图 " | ". " |

(30+ locales defined via TitleNumberPrefix / TitleNumberSuffix)

----

Copyright 2026 The MathWorks, Inc.

----
