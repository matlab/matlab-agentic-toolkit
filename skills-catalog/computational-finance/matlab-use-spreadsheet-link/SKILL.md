---
name: matlab-use-spreadsheet-link
description: Exchange data between Excel and MATLAB using Spreadsheet Link VBA macros and worksheet functions. Use when writing Excel VBA macros that call MLPutMatrix, MLGetMatrix, MLPutVar, MLGetVar, MLPutRanges, MLEvalString, MLGetFigure, or MatlabRequest.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Spreadsheet Link

Spreadsheet Link connects Excel to MATLAB, enabling users to exchange data between Excel and MATLAB, run MATLAB commands, using MATLAB as the compute engine from Excel.

## When to Use

- User wants to export Excel data into MATLAB workspace variables
- User wants to import MATLAB variables back into Excel cells or VBA variables
- User wants to execute MATLAB commands from an Excel VBA macro or worksheet cell
- User wants to import MATLAB figures into Excel as images
- User is building a workflow that uses Excel as the data interface and MATLAB as the compute engine

## When NOT to Use

- MATLAB-only workflows with no Excel involvement
- Python or .NET integration with MATLAB (use MATLAB Engine API instead)
- Deploying MATLAB as a web service (use MATLAB Production Server instead)

## Architecture

Spreadsheet Link uses VBA macros or worksheet functions in Excel to communicate with a locally running MATLAB instance via COM.

```
┌─────────────────────┐         VBA / COM          ┌─────────────────────┐
│   Excel             │  ◄─────────────────────►   │  MATLAB             │
│   (VBA or cells)    │                            │  (workspace)        │
└─────────────────────┘                            └─────────────────────┘
```

- Windows only (requires MATLAB COM Server)
- MATLAB must be running locally
- Two usage modes: VBA macros or worksheet functions (cell formulas)
- Two data exchange styles: range-based (MLPutMatrix/MLGetMatrix) or VBA-variable-based (MLPutVar/MLGetVar)

## Key Functions

| Function | Mode | Purpose | Queued? |
|----------|------|---------|---------|
| `MLPutMatrix` | Both | Export worksheet range to MATLAB variable | No |
| `MLPutVar` | VBA only | Export VBA variable to MATLAB variable | No |
| `MLGetMatrix` | Both | Import MATLAB variable to worksheet cells | **Yes** |
| `MLGetVar` | VBA only | Import MATLAB variable into VBA variable | No |
| `MLPutRanges` | Both | Export ALL named ranges to MATLAB | No |
| `MLEvalString` | Both | Execute a MATLAB command | No |
| `MLGetFigure` | Both | Import current MATLAB figure as image | **Yes** |
| `MatlabRequest` | VBA only | Process all queued MLGetMatrix/MLGetFigure | — |
| `MLAppendMatrix` | Both | Append worksheet range to existing MATLAB variable | No |

## Function Reference

### MLPutMatrix

Export an Excel range into MATLAB as a workspace variable.

**VBA macro syntax:**
```vba
MLPutMatrix "varName", Range("A1:B10")
```

**Worksheet function syntax:**
```
=MLPutMatrix("varName", A1:B10)
```

- First argument: MATLAB variable name (string)
- Second argument: Excel range containing the data
- Dates in Excel are sent as Excel serial date numbers

### MLPutVar

Export a VBA variable to the MATLAB workspace. VBA only — not available as a worksheet function.

```vba
Dim myData As Variant
myData = Range("A1:B100").Value
MLPutVar "matlabVar", myData
```

- First argument: MATLAB variable name (string)
- Second argument: VBA variable (the variable itself, not a string name)
- Executes immediately (not queued)
- Use when data needs VBA manipulation before sending to MATLAB

### MLGetMatrix

Queue a MATLAB variable to be written into Excel starting at a cell location.

```vba
MLGetMatrix "varName", "A1"
```

- First argument: MATLAB variable name (string)
- Second argument: destination cell address (**string**, not a Range object)
- Does NOT execute immediately — queued until `MatlabRequest` is called
- Supports all MATLAB data types; `datetime` values are converted to strings in Excel
- As worksheet function: `=MLGetMatrix("varName", "E1")`

### MLGetVar

Import a MATLAB variable into a VBA variable. VBA only — not available as a worksheet function.

```vba
Dim result As Variant
MLGetVar "matlabVar", result
```

- First argument: MATLAB variable name (string)
- Second argument: VBA variable to receive the data
- Executes **immediately** — does NOT require `MatlabRequest`
- Supports all MATLAB data types; `datetime` values are converted to strings
- Use when results need VBA manipulation before writing to worksheet

### MLPutRanges

Export ALL Excel named ranges to MATLAB in a single call. Each named range becomes a MATLAB variable with the same name.

```vba
MLPutRanges
```

- No arguments — exports every named range in the workbook
- Range name becomes the MATLAB variable name (e.g., named range "prices" → MATLAB variable `prices`)
- As worksheet function: `=MLPutRanges()`

### MLEvalString

Execute a MATLAB command in the connected MATLAB session.

```vba
MLEvalString "x = magic(3);"
```

- Argument: MATLAB code as a string
- Executes synchronously — the next VBA line runs after MATLAB completes
- Can call any MATLAB function, script, or expression
- As worksheet function: `=MLEvalString("x = magic(3);")`

### MLAppendMatrix

Append an Excel range to an existing MATLAB variable. The new data is concatenated as additional rows.

**VBA macro syntax:**
```vba
MLAppendMatrix "varName", Range("A101:B200")
```

**Worksheet function syntax:**
```
=MLAppendMatrix("varName", A101:B200)
```

- First argument: MATLAB variable name (string) — must already exist in workspace
- Second argument: Excel range to append
- Appends rows to the bottom of the existing variable
- Use when building up a variable incrementally (e.g., streaming data)

### MLGetFigure

Import the current MATLAB figure into Excel as an image.

```vba
Range("I1").Select
MLGetFigure 1, 1
```

- **Select the destination cell first** with `Range(...).Select`
- First argument: horizontal size scaling factor (1 = full size, 0.5 = half width)
- Second argument: vertical size scaling factor (1 = full size, 0.5 = half height)
- Only two arguments — do NOT pass a cell address
- Retrieves whatever figure is currently active in MATLAB
- Queued until `MatlabRequest` is called (like `MLGetMatrix`)
- As worksheet function: `=MLGetFigure(1, 1)` — places figure at the formula cell

### MatlabRequest

Process all pending `MLGetMatrix` and `MLGetFigure` commands and write results to Excel.

```vba
MatlabRequest
```

- Must be the last command in any VBA macro that uses `MLGetMatrix` or `MLGetFigure`
- Triggers the actual data transfer from MATLAB to Excel cells/images
- Without this call in a VBA macro, queued results will not appear in the spreadsheet
- NOT needed for `MLGetVar` (which executes immediately)
- **Worksheet functions do NOT need explicit MatlabRequest** — Spreadsheet Link's auto-calc functionality calls MatlabRequest automatically as part of Excel's recalculation cycle

## Patterns

### Pattern 1: VBA with MLPutVar/MLGetVar (preferred for VBA workflows)

```vba
Sub DataRoundTrip()
    ' Read data from worksheet into VBA variables
    Dim prices As Variant
    Dim weights As Variant
    prices = Range("A1:A100").Value
    weights = Range("B1:B100").Value

    ' Export VBA variables to MATLAB
    MLPutVar "prices", prices
    MLPutVar "weights", weights

    ' Compute in MATLAB
    MLEvalString "portfolio = prices .* weights;"
    MLEvalString "totalValue = sum(portfolio);"

    ' Import results into VBA variables (immediate — no MatlabRequest needed)
    Dim portfolio As Variant
    Dim totalValue As Variant
    MLGetVar "portfolio", portfolio
    MLGetVar "totalValue", totalValue

    ' Write VBA variables to worksheet
    Range("D1").Resize(UBound(portfolio, 1), UBound(portfolio, 2)).Value = portfolio
    Range("E1").Value = totalValue
End Sub
```

### Pattern 2: VBA with MLPutMatrix/MLGetMatrix (range-based)

```vba
Sub ComputeInMatlab()
    MLPutMatrix "data", Range("A1:C100")
    MLEvalString "result = mean(data, 1);"
    MLGetMatrix "result", "E1"
    MatlabRequest
End Sub
```

### Pattern 3: Named ranges export

```vba
Sub AnalyzeAllData()
    ' Export all named ranges to MATLAB at once
    ' e.g., "prices", "weights", "benchmark" all become MATLAB variables
    MLPutRanges

    ' MATLAB code references variables by named range names
    MLEvalString "portReturn = prices .* weights;"
    MLEvalString "excessReturn = portReturn - benchmark;"
    MLEvalString "sharpe = mean(excessReturn) / std(excessReturn) * sqrt(252);"

    ' Import result
    Dim sharpe As Variant
    MLGetVar "sharpe", sharpe
    Range("H1").Value = sharpe
End Sub
```

### Pattern 4: Figure generation and import

```vba
Sub PlotAndImport()
    MLPutVar "data", Range("A1:B100").Value

    ' Generate MATLAB figure
    MLEvalString "figure;"
    MLEvalString "plot(data(:,1), data(:,2), 'LineWidth', 1.5);"
    MLEvalString "title('Analysis'); xlabel('X'); ylabel('Y'); grid on;"

    ' Import figure to Excel
    Range("D1").Select
    MLGetFigure 1, 1
    MatlabRequest
End Sub
```

### Pattern 5: Multiple figures

```vba
Sub MultipleFigures()
    MLPutVar "data", Range("A1:C100").Value

    ' Create multiple figures
    MLEvalString "figure(1); plot(data(:,1)); title('Series 1');"
    MLEvalString "figure(2); histogram(data(:,2)); title('Distribution');"
    MLEvalString "figure(3); scatter(data(:,1), data(:,2)); title('Scatter');"

    ' Import each — must make figure current before each MLGetFigure
    MLEvalString "figure(1);"
    Range("E1").Select
    MLGetFigure 0.5, 0.5

    MLEvalString "figure(2);"
    Range("E20").Select
    MLGetFigure 0.5, 0.5

    MLEvalString "figure(3);"
    Range("E40").Select
    MLGetFigure 0.5, 0.5

    MatlabRequest
End Sub
```

### Pattern 6: Complete workflow (MLPutVar + compute + MLGetVar + figure)

```vba
Sub TotalReturnWithFigure()
    ' Read data into VBA
    Dim prices As Variant
    Dim divs As Variant
    prices = Range("A1:B253").Value
    divs = Range("D1:E20").Value

    ' Export to MATLAB
    MLPutVar "prices", prices
    MLPutVar "divs", divs

    ' Compute total return
    MLEvalString "dates = datetime(prices(:,1), 'ConvertFrom', 'excel');"
    MLEvalString "px = prices(:,2);"
    MLEvalString "exDates = datetime(divs(:,1), 'ConvertFrom', 'excel');"
    MLEvalString "divAmounts = divs(:,2);"
    MLEvalString "adjFactor = ones(size(px));"
    MLEvalString "for i = 1:numel(exDates), idx = find(dates >= exDates(i), 1); if ~isempty(idx) && idx > 1, adjFactor(1:idx-1) = adjFactor(1:idx-1) * (1 - divAmounts(i)/px(idx)); end, end"
    MLEvalString "totalReturn = px ./ adjFactor;"
    MLEvalString "totalReturn = 100 * totalReturn / totalReturn(1);"

    ' Generate figure
    MLEvalString "figure;"
    MLEvalString "plot(dates, totalReturn, 'LineWidth', 1.5);"
    MLEvalString "title('Total Return Index');"
    MLEvalString "xlabel('Date'); ylabel('Index (Base = 100)'); grid on;"

    ' Import numeric result into VBA variable
    Dim trResult As Variant
    MLGetVar "totalReturn", trResult
    Range("G1").Resize(UBound(trResult, 1), 1).Value = trResult

    ' Import figure
    Range("I1").Select
    MLGetFigure 1, 1
    MatlabRequest
End Sub
```

### Pattern 7: Worksheet functions (cell formulas)

Enter these in separate Excel cells, in order from top to bottom:

```
Cell F1: =MLPutRanges()
Cell F2: =MLEvalString("result = mean(prices, 1);")
Cell F3: =MLEvalString("figure; plot(prices); title('Prices'); grid on;")
Cell F4: =MLGetMatrix("result", "H1")
Cell F5: =MLGetFigure(1, 1)
```

### Working with dates

Excel dates are sent as serial date numbers. Convert in MATLAB:

```vba
Dim rawData As Variant
rawData = Range("A1:B253").Value
MLPutVar "rawData", rawData
MLEvalString "dates = datetime(rawData(:,1), 'ConvertFrom', 'excel');"
MLEvalString "values = rawData(:,2);"
```

## When to Use MLPutVar/MLGetVar vs MLPutMatrix/MLGetMatrix

Two parallel APIs exist for exchanging data between Excel and MATLAB:

- **MLPutMatrix / MLGetMatrix** — operate directly on worksheet ranges. MLPutMatrix reads cells and sends to MATLAB. MLGetMatrix is **queued** and writes MATLAB data back to cells only after `MatlabRequest` is called. Available in both VBA and worksheet functions.
- **MLPutVar / MLGetVar** — operate on VBA variables. MLPutVar exports a VBA variable to MATLAB. MLGetVar imports a MATLAB variable into a VBA variable **immediately** (no MatlabRequest needed). VBA only — not available as worksheet functions.

| Scenario | Use |
|----------|-----|
| Data needs VBA manipulation before/after MATLAB | MLPutVar / MLGetVar |
| Direct range-to-MATLAB without VBA intermediary | MLPutMatrix |
| Result writes directly to cells without VBA processing | MLGetMatrix |
| Working within a larger VBA application | MLPutVar / MLGetVar |
| Simple cell formula workflow | MLPutMatrix / MLGetMatrix |
| Need result immediately (no MatlabRequest) | MLGetVar |

## Code Generation Rules

When generating VBA code that uses Spreadsheet Link:

1. **Do NOT create new `.m` files** — Spreadsheet Link is an orchestration/data-exchange layer. Express MATLAB logic inline via `MLEvalString` calls. Calling pre-existing MATLAB functions or scripts is fine (e.g., `MLEvalString "results = myAnalysis(data);"`), but do NOT generate new `.m` files as part of the solution.
2. **Always end with `MatlabRequest`** if the macro contains any `MLGetMatrix` or `MLGetFigure` calls. NOT needed if using only `MLGetVar`.
3. **`MLGetMatrix` takes a string for the cell address**, not a Range object — use `"G1"` not `Range("G1")`
4. **`MLGetFigure` requires selecting the cell first** — use `Range("I1").Select` then `MLGetFigure 1, 1`. Only two arguments (width, height scaling). Do NOT pass a cell address.
5. **`MLPutMatrix` takes a Range object** for the data source — use `Range("A1:B10")`
6. **`MLPutVar` takes a VBA variable** — use `MLPutVar "name", myVar` (not a string name of the variable)
7. **`MLGetVar` executes immediately** — no MatlabRequest needed. Assign to a Variant.
8. **Use multiple `MLEvalString` calls** for multi-line MATLAB logic rather than packing into one string
9. **Do NOT write JSON serialization or data conversion code** — Spreadsheet Link handles all data type conversion internally
10. **Convert dates after exporting** — export raw data, then convert in MATLAB with `datetime(..., 'ConvertFrom', 'excel')`
11. **Variable names must be valid MATLAB identifiers** — no spaces, no special characters, must start with a letter
12. **For multiple figures**, make each figure current with `figure(N)` before each `MLGetFigure` call
13. **Do NOT use `exportgraphics` + `Shapes.AddPicture`** — use `MLGetFigure` instead

## Notes

- Spreadsheet Link requires Windows (uses MATLAB COM Server)
- MATLAB must be running before executing macros
- **VBA Reference required:** In the Excel Visual Basic Editor, go to Tools → References and check "SpreadsheetLink" from the list. Without this reference enabled, Spreadsheet Link functions will not be recognized.
- Data types: Excel numeric values become MATLAB doubles; text becomes char arrays
- Large datasets may be slow over COM — consider exporting/importing only what's needed
- `MLPutRanges` exports ALL named ranges — it is not selective
- Worksheet functions execute in cell evaluation order (top to bottom, left to right)
- Spreadsheet Link auto-calc automatically calls `MatlabRequest` during Excel recalculation — this is why worksheet functions do not need an explicit `MatlabRequest` call, while VBA macros do
- **Customization functions** — configure Spreadsheet Link behavior (all execute immediately):
  - `MLShowMatlabErrors "yes"` — return MATLAB errors back to Excel (default is no; #COMMAND! is returned)
  - `MLOpen` — verify or establish connection to MATLAB session
  - `MLClose` — disconnect from MATLAB session
  - `MLAutoStart "yes"` — auto-start MATLAB when the Spreadsheet Link add-in loads
  - `MLUseFullDesktop "yes"` — launch full MATLAB desktop vs Command Window only
  - `MLStartDir "C:\myproject"` — set MATLAB working folder on connection
  - `MLUseCellArray "yes"` — toggle cell array mode for MLPutMatrix (sends each cell as a separate cell array element rather than combining into a matrix)
  - `MLProgramId "26.1"` — set which MATLAB version to connect to when multiple versions are installed
  - `MLMissingDataAsNaN "yes"` — send empty Excel cells as NaN to MATLAB (default sends as 0)

----

Copyright 2026 The MathWorks, Inc.
