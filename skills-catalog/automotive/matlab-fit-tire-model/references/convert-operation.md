# Adjacent Operation: Convert a Fitted Model to Another Type

Load this when the user already has a fitted model and wants it re-expressed as another type (for
example "I have an MF6.2, give me a Fiala version"). Convert is not a step in the linear fitting
schedule. It is an adjacent operation offered on that request.

```matlab
[newObj, errorStat, optimOutput, H] = convert(mdl, TargetType);
```

`TargetType` must be a member of `modelTypes()`. `convert` is non-mutating, so reassign it.

It is not free: except for MF51 to MF52 (a direct parameter copy), `convert` generates synthetic
data from the source model and re-fits the target through a full schedule, so it **requires
Optimization Toolbox** and is approximate and possibly lossy on downgrades (MF6.2 to Fiala drops
combined, relaxation, and pressure behavior; conversion to Dugoff clamps slip ranges). Disclose the
lossiness the same way Step 9 discloses unfit types; never present a downgraded conversion as
equivalent to the source.

Guardrails error on a builtin source, a same-type target, and unsupported type pairs. Deliver the
result via Step 8 and report it via Step 9.

----

Copyright 2026 The MathWorks, Inc.

----
