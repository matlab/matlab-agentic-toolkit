# .?ClassName Syntax — Worked Examples

For the basic `SensorConfig` constructor, see the ".?ClassName — Import
Properties as Name-Value Args" section of `SKILL.md`. The patterns below
extend that example.

## Overriding Specific Properties

Add constraints beyond what the property definition provides:

```matlab
function obj = PlotConfig(nvArgs)
    arguments
        nvArgs.?PlotConfig
        nvArgs.LineWidth (1,1) double {mustBeBetween(nvArgs.LineWidth, 0.5, 10, "closed")}
    end
    % Override lines can appear before or after the .? line
    % They add tighter validation than the property definition
end
```

## Static Factory with Forwarding

For the body of `fromPreset` and the `namedargs2cell` forwarding pattern,
see the "namedargs2cell — Forward Name-Value Args" section of `SKILL.md`.
The same body works as a `methods (Static)` block on the class itself —
just hoist it into a `methods (Static) ... end` block and call as
`SensorConfig.fromPreset("audio", FilterOrder=8)`. The arguments block,
preset switch, override loop, and `namedargs2cell` call are unchanged.

## Wrapper Function Pattern

Wrap another function and forward its name-value args:

```matlab
function myBar(x, y, barArgs)
    arguments
        x (:,:) double
        y (:,:) double
        barArgs.?matlab.graphics.chart.primitive.Bar
    end

    nvCell = namedargs2cell(barArgs);
    bar(x, y, nvCell{:});
end
```

Call: `myBar(x, y, FaceColor="magenta", BarLayout="grouped")`

This imports ALL public settable properties of the `Bar` class as valid name-value args — hundreds of properties, automatically validated.

## Key Rules

1. **Only one `.?ClassName` per arguments block**
2. **Override lines can appear before or after the `.?` line**
3. **Properties must be public and settable** — Dependent, Constant, and private properties are excluded
4. **Defaults come from property definitions** — no need to redeclare them
5. **The struct only contains fields the caller passed** — `fieldnames(nvArgs)` returns only what the user explicitly provided, not all properties. Unpassed properties retain their declared defaults on the object.
6. **Use `namedargs2cell`** to convert the struct back to a cell array for forwarding
7. **Tab completion works automatically** — users see all valid property names

## When NOT to Use .?ClassName

- The class has many properties but only a few should be constructor-settable → manually list the subset
- You need different defaults in the constructor vs the property definition → manually declare with custom defaults
- The class is not yours and you only want to expose a few of its properties → manually list what you want

----

Copyright 2026 The MathWorks, Inc.

----
