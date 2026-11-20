# Validation Diagnostics (Enhanced `validate()`)

The per-object diagnostics ship in **RoadRunner R2026b Update 2**; the calling contract below also works on earlier releases.

## The `validate()` Contract

`validate(rrs)` uses a **success-or-throw** pattern:

- Returns `true` when the scenario has **no Critical or Error** messages.
- **Throws** an exception when one or more blocking (Critical/Error) issues are present.
- Warning and Info messages are **non-blocking** — they never cause a throw.

RoadRunner's reporting infrastructure classifies every diagnostic into four severities: **Critical**, **Error**, **Warning**, **Info**. `validate()` treats Critical/Error as blocking and Warning/Info as non-blocking.

| Validation result | `ShowWarnings=false` (default) | `ShowWarnings=true` |
|---|---|---|
| No diagnostics | return `true` | return `true` |
| Warning/Info only | return `true` | issue MATLAB warnings, return `true` |
| Critical/Error only | throw | throw |
| Critical/Error + Warning | throw | issue MATLAB warnings, then throw |

### What changed in R2026b Update 2

- **Detailed diagnostics attached as causes.** Before, a failed `validate()` threw a generic *"Validation failed. The scenario has critical issues that must be corrected."* with nothing else. Now the thrown `MException` keeps that same generic top-level `message`, but **attaches one cause per blocking diagnostic** (`ME.cause{i}`), each a separate `MException` whose `message` names the offending object and issue. The `Critical:`/`Error:` prefix is **stripped** before the cause is stored. **Read `ME.cause`, not `ME.message`.**
- **New exception identifier.** The top-level identifier changed from `datamodelapi:datamodeltreeservice:callMethodError` to **`roadrunner:scenario:ValidationFailed`**. Each attached cause has the identifier **`roadrunner:scenario:ValidationError`**. Match on the new ID; fall back to message text on older releases.
- **`ShowWarnings` name-value argument** (default `false`). When `true`, non-blocking Warning/Info diagnostics are issued as MATLAB warnings with identifier **`roadrunner:scenario:ValidationWarning`** (backtrace suppressed). It does NOT change the return value or the throw behavior for blocking issues.

### Backward compatibility

Existing scripts keep working unchanged:

```matlab
isValid = validate(rrs);   % single output — still valid
validate(rrs);             % no output captured — still valid
```

Only the *content* of the thrown exception and its identifier are richer; the shape of the API is unchanged.

## Standard Calling Pattern

Always wrap `validate` in `try/catch` and iterate `ME.cause` — never call it bare, never assume success, and never parse `ME.message` (it is only the generic summary).

```matlab
try
    isValid = validate(rrs);          % true when no Critical/Error
catch ME
    % R2026b Update 2+: ValidationFailed with one cause per diagnostic; earlier releases: callMethodError, no causes
    if ~ismember(ME.identifier, ["roadrunner:scenario:ValidationFailed" "datamodelapi:datamodeltreeservice:callMethodError"])
        rethrow(ME);                  % genuine API/runtime failure, not a validation result
    end
    % Detailed diagnostics are the causes, not ME.message
    diagnostics = strings(1, numel(ME.cause));
    for i = 1:numel(ME.cause)
        diagnostics(i) = ME.cause{i}.message;   % e.g. "Longitudinal Distance To Actor Condition has no assigned Actor."
    end
    if isempty(diagnostics)
        diagnostics = string(ME.message);   % before R2026b Update 2: only the summary
    end
    % ... inspect/repair (see below), then re-run validate ...
end
```

`ObjectRoot` still works and now also surfaces detailed messages — use it to isolate one object and its descendants:

```matlab
validate(rrs, ObjectRoot=actor);   % validate only this actor's subtree
```

## Closed-Loop Consume-and-Repair Workflow

When `validate()` throws, do NOT rebuild the scenario blindly. Read the diagnostics, apply targeted fixes, and re-validate:

1. **Capture** the causes (`ME.cause`). Each `ME.cause{i}.message` is one blocking diagnostic (prefix already stripped) naming the offending object and the issue. `ME.message` is only the generic summary — do not parse it.
2. **Map** each cause to a concrete fix (see the table below). The object name in the diagnostic (e.g. `Sedan Route`, `Change Speed Action`, `Actor <name>`) tells you *which* object to repair.
3. **Apply** the fix in MATLAB against the named object.
4. **Re-validate** — call `validate(rrs)` again. Repeat until it returns `true`.
5. **Stop and ask** if a diagnostic is not safe to auto-fix (see "When to ask the user" below). Do not guess at user intent.

**Bound the loop.** Do not retry indefinitely. If the same diagnostic survives a fix attempt, or you exceed ~3 repair cycles without progress, stop and report the remaining diagnostics to the user verbatim.

```matlab
% TEMPLATE: add the repairs for your diagnostics (table below) where marked
maxAttempts = 3;
isValid = false;
for attempt = 1:maxAttempts
    try
        isValid = validate(rrs);
        break;   % no blocking diagnostics left
    catch ME
        if ~ismember(ME.identifier, ["roadrunner:scenario:ValidationFailed" "datamodelapi:datamodeltreeservice:callMethodError"])
            rethrow(ME);   % genuine API or runtime error
        end
        causes = cellfun(@(c) string(c.message), ME.cause);
        if isempty(causes)
            causes = string(ME.message);   % before R2026b Update 2: only the summary
        end
        fprintf("Attempt %d:\n", attempt);
        fprintf("  %s\n", causes);
        % Repair each named object here; if a fix is not safe, stop and ask the user.
    end
end
if ~isValid
    error("roadrunnerAuthorScenario:StillInvalid", ...
        "validate() still fails after %d attempts:\n%s", maxAttempts, strjoin("  " + causes, newline));
end
```

### Example

The engine echoes each actor's own name back in the diagnostic (e.g. `Actor <name>`), so the exact text varies with how your actors are named. Below, `<follower>`/`<leader>` stand in for those names.

```matlab
% validate() throws roadrunner:scenario:ValidationFailed; ME.cause{i}.message are (prefix stripped):
%   Actor <follower>: Actor has the same ID as Actor <leader>. Actor IDs must be unique.
%   Longitudinal Distance To Actor Condition has no assigned Actor.
%   Longitudinal Distance To Actor Condition has no assigned Reference Actor.

% Fix 1: Duplicate ActorID — give the second actor a unique ID
follower.ActorID = leader.ActorID + 1;

% Fix 2: Assign the condition's required actors
cond.Actor          = follower;   % the actor the condition governs
cond.ReferenceActor = leader;     % the actor it is measured against

% Re-validate — returns true when no Critical/Error remain
isValid = validate(rrs);
```

## Mapping Common Diagnostics to Fixes

The cause message text is authoritative — read it. This table covers frequently seen blocking diagnostics and the corresponding repair. Cross-references point to the constraints in `common-mistakes.md` and `SKILL.md`.

The strings below are the messages RoadRunner returns (verified in R2026b Update 2,
prefix already stripped). Object-scoped diagnostics are prefixed with the object descriptor
and a colon — e.g. `Actor <name>: ...`, `<name> Route: ...` (the engine echoes each object's
own name). Match on the stable substring, not the whole line, since the object name varies.

| Diagnostic (`ME.cause{i}.message`) | Severity | Likely cause | Fix |
|---|---|---|---|
| `Scenario must contain at least one Actor.` | Critical | Empty scenario — no actors placed | Add at least one actor (SKILL.md Step 4) |
| `Scenario must contain at least one action phase.` | Critical | No action phase in the phase logic | Add a phase with an action (SKILL.md Step 7) |
| `... has no assigned Actor` / `... has no assigned Reference Actor` (e.g. on `Longitudinal Distance To Actor Condition`) | Critical | `.Actor`/`.ReferenceActor` omitted on an action or condition | Set the required actor property (SKILL.md Hard Constraint #1) |
| `Actor <B>: Actor has the same ID as Actor <A>. Actor IDs must be unique.` | Critical | Duplicate `ActorID` | Assign a unique `ActorID` to one actor |
| `Phase (unnamed) has no assigned action.` | Critical | A phase was created with no action added | Add an action to the phase via `addAction`, or remove the empty phase |
| `Phase (unnamed) has no assigned Actor.` | Critical | `ActorActionPhase` created with `addPhaseInSerial`/`addPhaseInParallel` but `.Actor` never set | Set `phase.Actor = actor` right after creating the phase (constraint #1) |
| `Change Speed Action:  uses waypoint time data, but <name> Route has no assigned time data.` | Critical | `SpeedReference = "route-time-data"` on an actor whose route points have no `HasTime`/`Time` | Set `HasTime = true` and `Time` on the route points (`routes-and-points.md` §Time-Based Trajectory), or use an absolute speed |
| `<name> Route Segment: Unable to find road network route between segment endpoints. Either mark segment as freeform or move points to create a valid route on the road.` | Critical | With `Freeform = false`, two consecutive route points are not connected by the road network — e.g. a route from one junction arm to an unconnected arm (cross-arm) | Move the points onto connected lanes: approach lane → its junction connector → exit (constraint #29, `lane-connectivity.md` JunctionPaths). Do not set `Freeform = true` on a vehicle route to silence it — the car would cut straight across |
| `The character actor <name> must have a path.` | Critical | Character actor placed without a route/path | Add a route with waypoints — characters ALWAYS need paths (constraint #3) |
| `Change Lane Action is invalid for Actor <name>. Lane change action cannot be set when path is defined.` | Warning | `ChangeLaneAction` on a path-following (routed) actor | Remove the route — lane-change actions require lane-following mode (constraints #12, #14) |
| `<Route>: Route contains time data, but no speed actions use waypoint time data. Time data will be ignored.` | Warning | Waypoint `HasTime`/`Time` set but no action consumes it | Remove the stray time data, or add a speed action that uses it (`routes-and-points.md` §Time-Based Trajectory) |
| Waypoint not where it was computed (not reported by `validate()`) | — | `anchorToPoint` + `ForwardOffset` on a route point: `anchorToPoint` moves the waypoint onto the anchor, discarding its computed position, then the offset re-places it along the anchor's lane | Use `autoAnchor` on an HD-map position for route points (constraint #13) |
| Next phase never starts (not reported by `validate()`) | — | The phase before it holds a continuous action (`SamplingMode="continuous"`) and has no end condition, so it never ends | Add an end condition to that phase. Phases with finishing actions end on their own when the action completes |
| MATLAB error before `validate()`: `Unable to use a value of type roadrunner.api.ActorActionPhase as an index.` | — | Chained `setEndCondition(phase, "Type").Property = value` | Two-line pattern: `c = setEndCondition(phase, "Type"); c.Property = value;` (constraint #26) |

All messages above were reproduced in RoadRunner R2026b Update 2.

For anything not in this table, read the message, identify the named object, and apply the matching constraint from `common-mistakes.md`. If nothing matches, report the diagnostic to the user rather than guessing.

## When to Ask the User Instead of Auto-Fixing

Some diagnostics indicate missing *intent* or *resources*, not a mechanical mistake. Do NOT invent a fix — stop and ask:

- **Missing or unresolved asset** for an actor (e.g. the referenced vehicle/character asset does not exist). Ask which asset to use rather than substituting one.
- **Ambiguous corrective action** — when more than one repair is plausible and they change scenario behavior (e.g. which actor's ID to change, which of two actors should get a route).
- **Semantic conflicts** that imply the user's requirements are contradictory (e.g. a lane-change actor that the user also wants on a fixed route).

This mirrors the skill's core convention: never guess at ambiguous intent — clarify first.

## `ShowWarnings` — Surfacing Non-Blocking Diagnostics

By default `validate()` is silent about Warning/Info diagnostics. Pass `ShowWarnings=true` to surface them as MATLAB warnings while still returning `true` (assuming no Critical/Error). Useful for tightening a scenario that is technically valid but suboptimal.

```matlab
isValid = validate(rrs, ShowWarnings=true);   % non-blocking diagnostics printed as warnings
```

`ShowWarnings` does not change the throw behavior — blocking issues still throw regardless of its value.

----

Copyright 2026 The MathWorks, Inc.

----
