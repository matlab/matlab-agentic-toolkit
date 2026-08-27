# Diagram Styling Guidance

Color palettes, font formatting, and cloning mechanics for SimBiology
Model Builder diagrams.

---

## Color Palette

| Subsystem     | RGB                  | Description  |
|---------------|----------------------|--------------|
| PK / Drug     | `[0.53 0.81 0.98]`  | Light blue   |
| PD / Response | `[0.56 0.93 0.56]`  | Light green  |
| Metabolite    | `[1.00 0.85 0.56]`  | Light orange |
| Immune / Cell | `[0.86 0.63 0.87]`  | Light purple |
| Neutral       | `[0.90 0.90 0.90]`  | Light grey   |

Apply with:
```matlab
simbio.diagram.setBlock(species, 'FaceColor', [0.53 0.81 0.98]);
```

For all species in a compartment:
```matlab
comp = sbioselect(model, 'Type', 'compartment', 'Name', 'Central');
simbio.diagram.setBlock(comp.Species, 'FaceColor', [0.53 0.81 0.98]);
```

---

## Text Formatting

- **`TextLocation = 'center'`** for all species (names inside blocks).
- **`FontWeight = 'bold'`** on all species and compartment blocks.
- **Size species blocks** to fit names (see width table in SKILL.md).

```matlab
simbio.diagram.setBlock(species, 'TextLocation', 'center', 'FontWeight', 'bold');
```

---

## Cloning Mechanics

Clone species when they participate in >= 3 reactions spanning different
regions, or for cofactors (ATP, ADP, NAD+, NADH). **Clones cannot be
placed outside their parent compartment.**

### Split (clone)

```matlab
expr = simbio.diagram.splitBlock(sp);
simbio.diagram.setBlock(sp, expr(1), 'Position', [x1 y1 50 16]);
simbio.diagram.setBlock(sp, expr(2), 'Position', [x2 y2 50 16]);
```

### Join (merge back)

```matlab
simbio.diagram.joinBlock(sp, expr(2));  % merge back, keep expr(2)
```

### When to clone

- Species participates in >= 3 reactions spanning different diagram regions
- Cofactors (ATP, ADP, NAD+, NADH) that appear in many reactions
- **Clone sparingly** — clones add visual noise

### When NOT to clone

- Species has 1-2 connections
- All connections are in the same diagram region
- Species can be reached without long crossing lines


----

Copyright 2026 The MathWorks, Inc.

----
