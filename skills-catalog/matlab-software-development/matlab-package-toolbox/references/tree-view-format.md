# Tree View and Summary Table Format

## Tree View

Show each **directly-called** external with its call chain and transitive cost. Externals only reached transitively are nested under their parent, not shown at the top level.

```
External Dependencies (2 decisions):

├── helperB.m (called from +pkg/functionA.m:23)
│   ├── utilC.m (called from helperB.m:10) -- no further deps
│   └── utilD.m (called from helperB.m:45)
│       └── [Statistics Toolbox] fitlm -- product dep, OK
│   Pull-in cost: 3 files, 4.2 KB
│
├── shared/logging.m (called from +pkg/functionB.m:8, +pkg/functionC.m:102)
│   └── shared/formatMsg.m (called from logging.m:15)
│       └── shared/config.m (called from formatMsg.m:3)
│           └── ... (7 more files in shared/)
│   SPRAWLING: 10 files across shared/ -- likely needs architectural decision
│   Belongs to MATLAB Project: "SharedUtils" (shared/.prj detected)
│
└── [IGNORE FILE CONFLICT] data/constants.mat
    In toolbox root but excluded by ignore file
    Required by +pkg/functionA.m:55

Note: utilC.m, utilD.m, formatMsg.m, config.m etc. are NOT shown as
top-level entries because no toolbox file calls them directly — they
are part of the pull-in cost of their respective parents.
```

## Summary Table

```
## Dependency Summary

| Category | Count | Status |
|----------|-------|--------|
| Included (ships in .mltbx) | 24 files | OK |
| MathWorks products | 2 toolboxes | Declared in metadata |
| Add-on dependencies | 1 add-on | Declared in metadata |
| External unresolved files | 4 files (+ 8 transitive) | Needs decision |
| Unresolved symbols | 3 symbols | Needs investigation |
| Ignore file conflicts | 1 file | Needs decision |
```

----

Copyright 2026 The MathWorks, Inc.

----
