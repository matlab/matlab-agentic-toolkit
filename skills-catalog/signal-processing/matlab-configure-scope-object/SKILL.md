---
name: matlab-configure-scope-object
description: Prevents crashes due to problematic scope-related API misuse caused by agent escalation into internal scope framework objects. Use when configuring properties of scope-related Simulink blocks or MATLAB objects — constrains the agent to documented APIs and directs users to the scope UI when a property is not programmatically accessible.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Scope Configuration — Safe API Skill

## When To Use

This skill is active whenever you interact with properties of any scope-related block or object:

**Simulink blocks:**
- Scope, Floating Scope (Simulink)
- Time Scope, Spectrum Analyzer, Array Plot (DSP System Toolbox)
- Constellation Diagram, Eye Diagram (Communications Toolbox)
- Video Viewer (Computer Vision Toolbox)
- Point Cloud Viewer (Point Cloud Toolbox)
- Scope Viewer (signal-level viewer)
- Range-Time Intensity Scope, Angle-Time Intensity Scope, Doppler-Time Intensity Scope (Phased Array System Toolbox)

**MATLAB objects:**
- `timescope(...)` 
- `spectrumAnalyzer(...)` (formerly `dsp.SpectrumAnalyzer`)
- `dsp.ArrayPlot(...)`
- `comm.ConstellationDiagram(...)`
- `comm.EyeDiagram(...)`
- `phased.IntensityScope(...)`
- `phased.RTIScope(...)`
- `phased.DTIScope(...)`
- `phased.ATIScope(...)`
- `phased.RangeDopplerScope(...)`
- `phased.RangeAngleScope(...)`
- `phased.AngleDopplerScope(...)`

## When NOT to Use

- Configuring non-scope Simulink blocks — standard `get_param`/`set_param` on blocks like Gain, Sum, or Transfer Function does not carry escalation risk
- Interacting with scopes without modifying properties — opening, closing, or viewing scopes during simulation
- Using other visualization tools such as Simulation Data Inspector

## Workflow

1. **Identify scope type** — Simulink block or MATLAB object (see "When This Skill Applies").
2. **Get the configuration interface:**
   - Simulink block: `scopeConfig = get_param('model/Block', 'ScopeConfiguration');`
   - MATLAB object: use the object directly.
3. **List public properties:** `properties(scopeConfig)` or `properties(scopeObj)`.
4. **Check the target property exists** in the list. If not → Error Handling (property not found).
5. **Set the property** via direct assignment.
6. **Handle errors:**
   - Locked object → `release(obj)`, then set.
   - Format mismatch → one retry with corrected type; for Simulink blocks, try the other access method (`get_param`/`set_param` vs `ScopeConfiguration`).
   - Still fails → report limitation to user and stop.

## Key Functions

| Function / API | Purpose |
|---|---|
| `get_param(block, 'ScopeConfiguration')` | Obtain the documented configuration object for a Simulink scope block |
| `set_param(block, param, value)` | Set a block-level parameter (fallback access method) |
| `properties(obj)` | List public properties — the only way to confirm a property is accessible |
| `release(obj)` | Unlock a locked MATLAB System object before setting non-tunable properties |

## CRITICAL SAFETY RULES

### Boundary: Only use the documented public API

The ALLOWED actions section below is a complete whitelist. Any approach not listed there is forbidden, including but not limited to:

1. **Do not access internal framework objects.** The `Simulink.scopes.*` namespace and any classes within it are internal implementation details — never instantiate, reference, or interact with them.

2. **Do not use introspection to discover undocumented interfaces.** Do not inspect metaclass information, hidden properties, or internal methods on scope objects or their block handles.

3. **Do not bypass the public API via the block object.** Scope block handles must only be used with `get_param`/`set_param` and `'ScopeConfiguration'` — never retrieve or manipulate the underlying object directly.

4. **Do not escalate after failure.** If a permitted API call fails and the error is not a simple format or access-method issue, stop. Do not attempt deeper access or introspection. Report the limitation to the user. (Permitted retries are defined in the Error Handling Procedure.)

### ALLOWED workflow (complete whitelist):

Follow these steps in order. Do not skip steps or invent alternatives.

**For Simulink scope blocks:**

1. Get the documented configuration object:
   `scopeConfig = get_param('model/Scope', 'ScopeConfiguration');`

2. List available public properties:
   `properties(scopeConfig)`

3. Confirm the target property appears in the list. If it does not, go to the Error Handling Procedure — do not attempt to set it.

4. Read or write the confirmed public property:
   `value = scopeConfig.PropertyName;`
   `scopeConfig.PropertyName = newValue;`

5. Use `get_param`/`set_param` with documented parameter names:
   `value = get_param('model/Scope', 'ParameterName');`
   `set_param('model/Scope', 'ParameterName', value);`

   A property may be accessible through one method but not the other. If one fails, try the other before reporting a limitation.

**For MATLAB scope objects:**

1. List available public properties:
   `properties(scopeObj)`

2. Confirm the target property appears in the list. If it does not, go to the Error Handling Procedure — do not attempt to set it.

3. Read or write the confirmed public property:
   `scopeObj.PropertyName = newValue;`

That is the complete set of permitted operations. Nothing else.

### Mapping user requests to property names

When the user's description does not exactly match a property name, map it to the closest matching public property from the `properties(...)` output. If multiple properties could plausibly match, or the mapping is unclear, show the user the property list and ask them to confirm before proceeding.

## Error Handling Procedure

**Property not found:** When the target property is not listed by `properties(...)`:

1. **Report to the user:**
   > "Programmatic access to [property] is not supported for [scope]. The property might not exist for this scope, or it might be configurable only through the scope UI. To change a supported property programmatically, specify a property listed by `properties(...)`. To change a visual or UI-only setting, open the scope window and use the configuration panels."
2. **Stop.** Do not attempt further programmatic solutions for this specific property.

**Locked object error:** When setting a property fails because the object is locked (error mentions "non-tunable" or "release"):

1. Call `release(scopeObj)` to unlock the object.
2. Set the property.
3. The next call to `step` or `obj(data)` will re-lock the object.

**Format or access-method error:** When a confirmed property fails due to a type mismatch, incorrect value format, or method-specific limitation:

1. **One retry is permitted** for each of the following:
   - Correct the value format (e.g., numeric to string) and retry the same method.
   - For Simulink scope blocks, try the other access method with the same value.
2. If all retries fail, report the limitation and stop. Do not attempt deeper access or introspection.

**MATLAB may expose internal class names** in error messages or `class()` output. Do not use any class names from the `Simulink.scopes.*` namespace to access scope internals.

## Why These Rules Exist

Simulink scope blocks and MATLAB scope objects use web-based viewers backed by internal framework objects that manage graphics pipelines, web sockets, and shared state. Accessing these internals outside their intended lifecycle — or interacting with their properties without proper initialization — crashes MATLAB with no recovery.

The documented APIs (`ScopeConfiguration` via `get_param` for Simulink blocks; public properties on MATLAB scope objects) are safe, sandboxed interfaces. Everything outside them is unsafe for programmatic access.

----

Copyright 2026 The MathWorks, Inc.
