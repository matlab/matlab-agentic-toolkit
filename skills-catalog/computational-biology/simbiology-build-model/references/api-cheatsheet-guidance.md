# SimBiology Diagram API Cheatsheet

Quick reference for the `simbio.diagram.*` functions used to manipulate
Model Builder diagrams programmatically. All functions require the Model
Builder app to be open with the model loaded.

---

## Block Functions

### `simbio.diagram.getBlock(sObj)` — Query block properties

```matlab
sv = simbio.diagram.getBlock(species);         % all properties as struct
pos = simbio.diagram.getBlock(species, 'Position');  % single property
```

For cloned species, specify the connected expression:
```matlab
pos = simbio.diagram.getBlock(species, reaction, 'Position');
```

### `simbio.diagram.setBlock(sObj, ...)` — Set block properties

```matlab
simbio.diagram.setBlock(species, 'Position', [x y w h]);
simbio.diagram.setBlock(species, 'FaceColor', 'yellow', 'FontSize', 14);
simbio.diagram.setBlock(species, reaction, 'Position', [x y w h]);  % cloned
```

### Block Properties

| Property         | Type / Values                                       | Notes                                      |
|------------------|-----------------------------------------------------|--------------------------------------------|
| `Position`       | `[x y width height]`                                | Origin is top-left of diagram (0,0)        |
| `FaceColor`      | RGB triplet or color name                           | Block fill color                           |
| `EdgeColor`      | RGB triplet or color name                           | Block border color                         |
| `TextColor`      | RGB triplet or color name                           | Label text color                           |
| `FontName`       | String (e.g. `'Arial'`, `'Helvetica'`)              |                                            |
| `FontSize`       | Positive scalar                                     |                                            |
| `FontWeight`     | `'plain'`, `'bold'`, `'italic'`, `'bold italic'`    |                                            |
| `TextLocation`   | `'top'`, `'left'`, `'bottom'`, `'right'`, `'center'`, `'none'` |                              |
| `Shape`          | `'rounded rectangle'`, `'rectangle'`, `'oval'`, `'triangle'`, `'hexagon'`, `'chevron'`, `'parallelogram'`, `'diamond'` | Compartments: only `'rounded rectangle'` or `'rectangle'` |
| `Rotate`         | 0-360                                               | Cannot rotate compartments                 |
| `Pin`            | `true` / `false`                                    | Prevents block from being moved in the UI  |
| `Visible`        | `true` / `false`                                    | Compartments are always visible (R2022a+)  |
| `ExpressionLines`| `'show'` / `'hide'`                                 | Reactions and rules only                   |
| `Connections`    | (read-only) Array of connected objects               |                                            |
| `Cloned`         | (read-only) `true` / `false`                        | Species only                               |
| `Object`         | (read-only) The SimBiology object                    |                                            |

---

## Line Functions

### `simbio.diagram.getLine(sObj)` — Query line properties

```matlab
sv = simbio.diagram.getLine(species);             % all lines from species
sv = simbio.diagram.getLine(species, reaction);    % specific line
```

### `simbio.diagram.setLine(sObj, ...)` — Set line properties

```matlab
simbio.diagram.setLine(reaction, 'Color', 'red', 'Width', 2);
simbio.diagram.setLine(species, reaction, 'Color', [0.6 0.2 0.6], 'Width', 3);
```

### Line Properties

| Property      | Type / Values              | Notes                          |
|---------------|----------------------------|--------------------------------|
| `Color`       | RGB triplet or color name  | Line color                     |
| `Width`       | Positive scalar            | Line thickness                 |
| `Connections` | (read-only) `[obj1 obj2]`  | The two connected objects      |

---

## Clone Functions

### `simbio.diagram.splitBlock(speciesObj)` — Clone a species block

Creates one copy of the species block per connected expression (reaction
or rule). Returns the list of expressions.

```matlab
expr = simbio.diagram.splitBlock(sp);
% Position each clone near its reaction:
simbio.diagram.setBlock(sp, expr(1), 'Position', [x1 y1 30 15]);
simbio.diagram.setBlock(sp, expr(2), 'Position', [x2 y2 30 15]);
```

### `simbio.diagram.joinBlock(speciesObj, exprObj)` — Merge clones

Joins all clones back into a single block, keeping the one connected to
`exprObj`.

```matlab
simbio.diagram.joinBlock(sp, expr(2));  % keep clone at expr(2)
```

---

## Common Patterns

### Read all positions in a model

```matlab
model = getModelByUUID(modelId);
allSpecies = model.Species;
for i = 1:numel(allSpecies)
    pos = simbio.diagram.getBlock(allSpecies(i), 'Position');
    fprintf('%s: [%d %d %d %d]\n', allSpecies(i).Name, pos);
end
```

### Batch-set face color for all species in a compartment

```matlab
comp = sbioselect(model, 'Type', 'compartment', 'Name', 'Central');
species = comp.Species;
simbio.diagram.setBlock(species, 'FaceColor', [0.53 0.81 0.98]);
```


----

Copyright 2026 The MathWorks, Inc.

----
