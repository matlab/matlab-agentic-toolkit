# Resolution Options

## Option Matrix

| Situation | Options (in suggested order) | Tradeoffs |
|-----------|------------------------------|-----------|
| **From an installed add-on** | Declare as add-on dependency | Easiest; user must install both add-ons |
| **From a MATLAB Project** | A) Declare as add-on dependency if published, B) Copy in, C) Refactor inward | A) cleanest if it's already an add-on; B) quick but duplicates; C) proper integration |
| **Loose files, small set (1-5 files, self-contained)** | A) Copy in, B) Refactor inward, C) Refactor outward into new add-on | A) simplest/fastest; B) proper integration into +pkg structure; C) if the code is generic and reusable |
| **Loose files, sprawling set** | A) Refactor inward (absorb the library), B) Refactor outward (new add-on), C) Additional Software (3P zip from URL) | A) significant effort but self-contained result; B) cleaner separation, recommended if code is reusable; C) if externally hosted |
| **Ignore file conflict** | Remove from the ignore file | Check why it was excluded first — might have been intentional |
| **Unresolved symbol — typo** | Fix the function name | Show the likely correct name and where it lives |
| **Unresolved symbol — exists on disk, not on path** | A) Add file to toolbox (becomes an external file decision), B) Add its folder to the path | A) treats it like any other external; B) only works if the file will be available at runtime |
| **Unresolved symbol — from uninstalled product/add-on** | Install the product/add-on and declare as dependency | User may not have the license; confirm before recommending |
| **Unresolved symbol — truly missing** | A) Remove the call, B) Write the function, C) Accept it as a conditional/optional dependency | User must clarify intent — may be dead code, planned work, or environment-specific |

## Outward Refactor Handoff

When recommending outward refactor (creating a separate add-on), explicitly note:

```
## Recommended: Package these files as a separate add-on

The following files form a reusable set that could become their own toolbox:
  shared/logging.m
  shared/formatMsg.m
  shared/config.m
  (+ N transitive dependencies)

To package them, use the same pipeline on that code:
1. Run tbx-init on the folder to define its public API
2. Run tbx-deps to analyze its own dependencies
3. Continue through tbx-buildplan → tbx-build → tbx-publish

Once published as an add-on, re-run tbx-deps here — those files
will then resolve as an add-on dependency instead of unresolved externals.
```

## Resolution is Per-External

The user may choose different strategies for different externals:
- "Copy in `helperB.m` and its 2 dependencies, but package `shared/` as its own add-on"
- Process each decision independently

## Pattern Detection

When analyzing externals, detect:
- Do multiple externals originate from the same directory/project? Surface as a group.
- Does the external's parent folder contain a `.prj` or `resources/project/` folder? It belongs to a MATLAB Project — note this.
- Is the code generic/reusable in nature (utilities, formatters, common math)? Note that it may be a candidate for its own add-on.

----

Copyright 2026 The MathWorks, Inc.

----
