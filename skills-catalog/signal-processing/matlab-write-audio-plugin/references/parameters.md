# Parameters Reference

## Mapping Laws

| Law | Syntax | Property type |
|-----|--------|---------------|
| `'lin'` | `{'lin', min, max}` | double |
| `'log'` | `{'log', min, max}` | double (min > 0) |
| `'pow'` | `{'pow', exponent, min, max}` | double |
| `'int'` | `{'int', min, max}` | double (integer steps) |
| `'enum'` | `{'enum', 'val1', 'val2', ...}` | char/logical/enum class |

## Styles

| Style | Compatible mappings |
|-------|--------------------|
| `'hslider'`, `'vslider'`, `'rotaryknob'` | `lin`, `log`, `pow`, `int` |
| `'dropdown'` | `enum` (any count) |
| `'vrocker'`, `'vtoggle'` | `enum` (exactly 2 values) |
| `'checkbox'` | logical properties |

## Constraints

- `DisplayName`: max 31 characters
- `Label`: max 31 characters
- Property default must be within Mapping range
- Enum defaults: use char (`'Off'`) or enum class value — not string (`"Off"`)
- For enum values of different lengths, use an `int32` enum class (see SKILL.md)
- `DisplayNameLocation='above'` consumes one grid row above the widget's `Layout` row — account for it in `RowHeight`

## Multi-Bus I/O

Use vectors for `InputChannels`/`OutputChannels`:

```matlab
PluginInterface = audioPluginInterface( ...
    ..., ...
    InputChannels=[2 4], ...   % Bus 1: stereo, Bus 2: quad
    OutputChannels=[2 4])
```

Each bus becomes a separate argument: `function [y1, y2] = process(plugin, x1, x2)`

----

Copyright 2026 The MathWorks, Inc.
