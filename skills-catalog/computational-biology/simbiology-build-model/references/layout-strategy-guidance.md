# Layout Strategy Guidance

Detailed layout strategy selection, pre-build analysis, and layout recipes
for SimBiology diagram design. Load this reference when designing or
rearranging multi-compartment model diagrams.

---

## Pre-Build Analysis Checklist

Run **before placing any blocks**. Skipping this is the root cause of
most layout failures.

### Step 1: Compute species block widths

```
For each species:
    n = length(species.Name)
    if n <= 5:   width = 50
    if 6 <= n <= 12: width = 100
    if n >= 13:  width = 130
    height = 16  (always)
```

### Step 2: Identify hubs

Count reactions per compartment. Mark as HUB if degree >= 6.

- **Hubs go near the center** of their connected group.
- **Multiple compartments connecting to one hub** — place the hub
  directly adjacent to the group.
- **Two hubs forming boundaries** (e.g., Venous/Arterial) — draw as
  tall spanning bars, place connected compartments between them.

### Step 3: Detect sequential chains

Look for 3+ compartments in series where multiple species transit in
parallel. Place species **side by side horizontally** (not stacked) so
each gets its own vertical transit column. Stack segments vertically.

### Step 4: Size compartments from content

| Content                              | Size formula                           |
|--------------------------------------|----------------------------------------|
| 1 species                            | `max(species_w + 60, 160) x 100`      |
| 2 species, isolated (vertical stack) | `max(species_w + 60, 240) x 170`      |
| 2 species, in chain (side by side)   | `sp1_w + sp2_w + 80 + 40` x `100`     |
| 3+ species                           | `sum(species_w) + (n+1)*40` x `100`   |

Add 30 px minimum padding on all sides.

### Step 5: Plan positions and verify non-overlap

Assign compartments to columns/zones using the strategy and recipes.
Compute `[x y w h]` at **final size** (not initial). Verify no two
bounding boxes overlap.

### Step 6: Pre-compute cross-subsystem reaction positions

For reactions connecting different layout zones, identify intervening
blocks and find clear node positions. Fall back to
`computeSafeReactionPosition` at post-placement time if needed.

### Step 7: Verify before building

- [ ] Species widths account for name length
- [ ] Hubs centered relative to connections
- [ ] No sequential chain uses vertical species stacking
- [ ] Compartment sizes fit content with 30 px padding
- [ ] Connected compartments in adjacent columns/rows
- [ ] All positions non-overlapping at final dimensions

---

## Layout Strategy Selection

- **PKPD:** PD upper-left, PK lower-right. Species in rows within each
  compartment. Inter-system connections flow diagonally.
- **Metabolic:** Top-to-bottom within nested compartments.
- **Signal cascade:** Single compartment, species in a row ordered by pathway.
- **Physiological:** Side-by-side or single large compartment.
- **PBPK:** Circulation columns (see `pbpk-layout-guidance.md`).
- **Simple PK:** Left-to-right compartments.

---

## Layout Recipes

### Recipe A: One-Compartment PK

```
 +-----------------------------------+
 |  Central                          |
 |  [Drug] --(elim)--> null          |
 +-----------------------------------+
```

### Recipe B: Two-Compartment PK

Central upper-left, Peripheral lower-right, diagonal gap >= 80 px.
Distribution reaction at midpoint.

### Recipe C: PKPD Model

PD compartments upper-left, PK lower-right. Species in rows within
compartments. Inter-system reactions flow diagonally.

### Recipe D: Metabolic Pathway (Nested)

Nest compartments for biological containment. Outer first, >= 40 px
padding between nested compartment edge and parent edge. Top-to-bottom
flow within each compartment.

### Recipe E: Physiological System

Single large compartment. Species in a row, ordered by pathway
sequence so reaction edges trace smooth arcs.

### Recipes F-G: PBPK and ACAT

See `pbpk-layout-guidance.md` for the full PBPK circulation layout
and ACAT GI chain recipes.

---

## Aesthetic Objectives (priority order)

1. **Minimize edge crossings** — the most important aesthetic criterion.
2. **Minimize edge length** — keep connected species close together.
3. **Maximize angle between edges** — spread outgoing edges at shared
   nodes to avoid visual ambiguity.
4. **Minimize edge bends** — prefer straight-line connections.
5. **Emphasize structure** — reveal clusters, cycles, and pathways.
6. **Preserve the mental map** — keep relative positions stable during
   updates.

---

## Readability Principles

1. **Proximity implies relationship** — place compartments close to
   their most-connected neighbors. Short edges are the biggest win.
2. **Straight rows/columns for sequential groups** — avoid arcs or
   curves. Place transit reactions at midpoints in gaps.
3. **Compact over spacious** — related compartments should be visible
   without scrolling.

---

## Domain Conventions

- **Signaling:** membrane at top, nucleus at bottom, flows downward.
- **Metabolic:** substrates top, products bottom (or left-to-right).
- **PBPK:** circulation loop (see `pbpk-layout-guidance.md`).
- **PKPD:** PD upper-left, PK lower-right.

---

## Inter-Compartment Spacing

| Total Compartments | Side-by-side gap | Stacked/diagonal gap |
|--------------------|------------------|----------------------|
| <= 6               | >= 200 px        | >= 80 px             |
| 7-15               | >= 120 px        | >= 80 px             |
| 16+                | >= 80 px         | >= 60 px             |

---

## Reaction Node Positioning

**Two-species (A -> B):** Place at midpoint between species centers.

```matlab
midX = (posA(1) + posB(1)) / 2;
midY = (posA(2) + posB(2)) / 2;
simbio.diagram.setBlock(rxn, 'Position', [round(midX)-7 round(midY)-7 15 15]);
```

**Null reactions (A -> null):** Place inside the parent compartment,
adjacent to the species, >= 40 px center-to-center distance. Place on
the side away from inter-compartment connections.

**Multi-species (3+):** Place at geometric centroid of all participants.

---

## Rule and Parameter Block Placement

Place rule blocks in an external grid to the right of compartments:

| Property            | Value       |
|---------------------|-------------|
| Gap from comp edge  | 60 px       |
| Column spacing      | 132 px      |
| Row spacing         | 51 px       |
| Block size          | `[20, 20]`  |

Rules tightly coupled to a species may be placed adjacent inside the
compartment instead.

---

## Evaluation Checklist

- [ ] No block overlaps
- [ ] All labels visible
- [ ] Blocks aligned horizontally/vertically where appropriate
- [ ] Same-tier compartments share exact coordinate
- [ ] Edge crossings minimized
- [ ] Connected species close together (short edges)
- [ ] Flow direction matches model type convention
- [ ] Compartment sizes fitted to content
- [ ] 30 px minimum padding maintained
- [ ] Color coding applied for multi-subsystem models
- [ ] `checkDiagramLayout(model).nTotal == 0`


----

Copyright 2026 The MathWorks, Inc.

----
