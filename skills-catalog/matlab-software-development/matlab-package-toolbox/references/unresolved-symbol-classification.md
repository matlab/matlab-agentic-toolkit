# Unresolved Symbol Classification

## Classification Table

| Scenario | Detection | Resolution to suggest |
|----------|-----------|---------------------|
| **Typo** | Close edit-distance match to a known function | "Did you mean `fitlm`?" — suggest correction |
| **Exists on disk but not on path** | `dir('**/<name>.m')` finds it somewhere | Show where it lives — suggest adding to path or moving into toolbox |
| **From a product not installed** | Function name appears in MATLAB's product function database | "This requires [Toolbox Name] which is not installed" |
| **From an add-on not installed** | Function name matches known add-on content | Suggest installing the add-on and declaring it as a dependency |
| **Truly missing** | No match found anywhere | Flag for user — may be deleted code, a planned function, or a conditional dependency |

## Resolution Assistance

For each unresolved symbol:

1. **Fuzzy match**: Compute edit distance against all functions on the current path + known product functions. Suggest the top 1-3 closest matches.
2. **Disk search**: Search for `<symbolName>.m` in this order, stopping at the first hit:
   1. The toolbox root itself (may be a namespace-resolution issue rather than a missing file)
   2. Sibling directories of the toolbox root (e.g., `../shared-utils/`, `../helpers/`)
   3. The git repository root and its subdirectories (if the toolbox is inside a git repo)
   4. Directories currently on the MATLAB path (`path` output)
   
   Do NOT search the entire filesystem — if the file is not found in these scopes, classify as "truly missing."
3. **Product lookup**: Check if the function belongs to a MathWorks product not currently installed (MATLAB maintains an internal function-to-product mapping; `matlab.codetools.requiredFilesAndProducts` uses this with `Certain == 0` for guesses, but fully missing products may not appear at all).
4. **Context clues**: If the unresolved symbol is called alongside known toolbox functions (e.g., in the same file as `fitlm`), suggest the same toolbox.

## Presentation Format

```
Unresolved Symbols:

├── fltlm (called from +pkg/analysis.m:42)
│   Likely typo — did you mean fitlm (Statistics and Machine Learning Toolbox)?
│
├── customPlot (called from +pkg/visualize.m:15, +pkg/report.m:88)
│   Found on disk: C:\Projects\SharedViz\customPlot.m (not on MATLAB path)
│   → This is also an external file dependency if added to path
│
└── generateReport (called from +pkg/main.m:102)
    Not found anywhere — may be missing or not yet written.
```

## Connecting Symbols to File Decisions

If a symbol resolves to a file on disk, it becomes an external file dependency. Present it in both the unresolved symbols section (for diagnosis) and feed it into Phase 3 (for transitive closure if the user decides to include it).

----

Copyright 2026 The MathWorks, Inc.

----
