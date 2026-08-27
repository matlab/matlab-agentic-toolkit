# PBPK Layout Guidance

Detailed layout recipes for PBPK models, including whole-body circulation
layouts and ACAT GI absorption chains. Load this reference when building
or modifying PBPK models with diagram layouts.

---

## Recipe F: PBPK Model (Circulation-Based Layout)

PBPK models have a distinctive physiological structure: blood circulates
through a closed loop of organ compartments, drug is absorbed from the
GI tract, distributed to organs, metabolized, and eliminated. The layout
uses a **left-to-right column orientation** following the drug's path
through the body.

### Structural subsystems in a PBPK model

| Subsystem            | Typical compartments                     | Role                      |
|----------------------|------------------------------------------|---------------------------|
| **Blood vessels**    | Venous, Arterial                         | Circulation boundaries    |
| **Pulmonary**        | Lung                                     | Venous -> Arterial bridge |
| **Hepatic / portal** | Liver, Portal Vein, Spleen               | First-pass metabolism     |
| **GI / ACAT**        | Stomach, Duodenum, Jejunum, Ileum, Colon | Drug absorption           |
| **Peripheral organs**| Heart, Brain, Muscle, Kidney, Skin, etc. | Tissue distribution       |
| **Elimination**      | Urine/Bladder, Bile                      | Drug removal              |
| **Observables**      | Calculations, Plasma, Dose               | Derived quantities        |

### Column Layout (left to right)

```
Col 1         Col 2        Col 3     Col 4      Col 5      Col 6
ACAT        -> PV/Spleen -> Liver  -> |Venous|   Organs    |Arterial|
(stacked)                             | bar  |  (stacked)  |  bar   |
                                      |      |             |        |
                                           [Lung] (top, bridging bars)
```

| Column | Contents            | x offset | Width   | Notes                         |
|--------|---------------------|----------|---------|-------------------------------|
| 1      | ACAT segments       | 20       | 360     | Vertical stack, 80 px gaps    |
| 2      | PortalVein, Spleen  | +100 gap | 130     | Stacked vertically            |
| 3      | Liver               | +100 gap | 120     | Single compartment            |
| 4      | Venous              | +100 gap | 70      | **Tall vertical bar**         |
| 5      | Peripheral organs   | +100 gap | 120     | Vertical stack, 60 px gaps    |
| 6      | Arterial            | +100 gap | 70      | **Tall vertical bar**         |
| top    | Lung                | centered | 120     | Bridges Venous <-> Arterial   |

> **Critical rule: Organs sit BETWEEN the blood vessel bars.** Venous
> is on the left of the organ stack, Arterial on the right. This
> ensures Organ->Venous outflow lines go left (short) and Arterial->Organ
> inflow lines come from the right (short). Placing organs outside the
> bars forces return lines to cross through a blood vessel — always wrong.

### Blood vessel bars

Venous and Arterial are drawn as **tall narrow vertical bars** (`70 px
wide`) that span the full height of the organ stack. This makes them
visually distinct as circulation boundaries and provides a clear bus
that all organ connections attach to.

- Bar height = organ stack total height (n organs x 100 + (n-1) x 60)
- Bar top y = first organ top y
- Species block centered vertically within the bar, `50 x 16`

### Organ stack

Peripheral organs are stacked vertically **between** the blood vessel
bars. Each organ is `160 x 100` with a single centered Drug species
(`50 x 16`). Stack with `60 px` vertical gaps.

- Organ->Venous reaction: in the gap between organ left edge and Venous
  right edge, y-aligned with the organ species
- Arterial->Organ reaction: in the gap between Arterial left edge and
  organ right edge, y-aligned with the organ species
- Stagger inflow/outflow reaction y by +/-12 px to prevent line crossings

### Hepatic sub-loop

Liver, PortalVein, and Spleen form a compact group in columns 2-3:

- PortalVein and Spleen stack vertically in column 2
- Liver sits in column 3, horizontally aligned with PortalVein
- PV->Liver reaction in the gap between them
- Liver->Venous reaction in the gap between Liver and Venous bar
- Arterial->Liver reaction in the same gap, vertically offset
- Liver is NOT a peripheral organ — never place it in the organ stack

### Lung

Lung sits at the top of the diagram, horizontally centered between the
Venous and Arterial bars. It bridges the circulation loop:
Venous -> Lung -> Arterial. Place reaction nodes between Lung and their
respective bars.

### ACAT GI chain

ACAT segments stack vertically in column 1. Each segment contains
Drug_unreleased and Drug_dissolved **side by side horizontally** (not
stacked vertically). Absorption reactions go right from dissolved
species into PortalVein. See Recipe G below for full details.

### PBPK color assignments

| Subsystem           | Color        | Compartments                      |
|---------------------|--------------|-----------------------------------|
| Blood / Circulation | Light purple | Venous, Arterial, Lung            |
| Peripheral organs   | Light blue   | Heart, Brain, Muscle, Kidney, etc.|
| Hepatic sub-loop    | Light green  | Liver, PortalVein, Spleen         |
| GI / ACAT chain     | Light orange | Stomach, Duodenum, Jejunum, etc.  |

---

## Recipe G: ACAT GI Absorption Chain (Detailed)

This recipe provides **concrete sizing and positioning rules** for
ACAT GI absorption segments.

### Why side-by-side species (not vertical stacking)

ACAT segments connect sequentially: each segment's Drug_unreleased
and Drug_dissolved transit to the next segment's corresponding species.
If species are stacked vertically, the inter-segment transit lines
**must cross the other species** in the compartment — this is
unavoidable and creates line-through-block violations in every gap.

Placing species **side by side horizontally** gives each species its
own vertical column. Transit lines stay within their column and never
cross the other species.

```
WRONG (vertical stacking):        CORRECT (side by side):

+-----------------+                +-------------------------------+
| Drug_unreleased |                | Drug_unreleased Drug_dissolved |
| Drug_dissolved  |                +-------------------------------+
+-----------------+                       |              |
       | X lines cross                    |              |
+-----------------+                +-------------------------------+
| Drug_unreleased |                | Drug_unreleased Drug_dissolved |
| Drug_dissolved  |                +-------------------------------+
+-----------------+
```

### Compartment sizing

| Property          | Value     | Notes                                    |
|-------------------|-----------|------------------------------------------|
| Width             | `400`     | Fits two 130 px species + padding + gap  |
| Height            | `100`    | Single row of species with breathing room |
| Vertical gap      | `80`     | Between adjacent segments                |
| Species width     | `130`    | Both names are 14-15 chars (>= 13 rule)  |
| Species height    | `16`     | Standard                                 |

### Species placement within each segment

```
+---------------------------------------------------+
| <-15px-> [Drug_unreleased 130x16] <-30px-> [Drug_dissolved 130x16] <-15px-> |
|        x=comp_x+15                       x=comp_x+215                       |
|        y=comp_y+comp_h/2-8               y=comp_y+comp_h/2-8                |
+---------------------------------------------------+
          comp_w = 360, comp_h = 80
```

Both species share the same y-coordinate (vertically centered in the
compartment). The 40 px horizontal gap between them leaves room for the
dissolution reaction node.

### Reaction placement

| Reaction type          | Position                                          |
|------------------------|---------------------------------------------------|
| **Dissolution** (intra-comp) | Between the two species: `x=comp_x+193-7, y=comp_y+33` |
| **Unreleased transit** (inter-comp) | In vertical gap, aligned with unreleased column: `x=unreleased_cx-7` |
| **Dissolved transit** (inter-comp) | In vertical gap, aligned with dissolved column: `x=dissolved_cx-7` |
| **Absorption** (dissolved->PV) | In horizontal gap between ACAT right edge and PV left edge, y-aligned with dissolved species |
| **Fecal elimination** (Colon->null) | Below Colon, one per column (unreleased column and dissolved column) |

> **Key rule:** Transit reaction nodes must be **x-aligned with their
> species column** so that connection lines run vertically and never
> cross the other species.

### Positioning formula (5 standard ACAT segments)

```matlab
acatX = 20;  acatW = 400;  acatH = 100;  acatGap = 80;
segNames = {'Stomach','Duodenum','Jejunum','Ileum','Colon'};

for i = 1:5
    y = 50 + (i-1)*(acatH + acatGap);  % segment top y

    % Compartment
    simbio.diagram.setBlock(comp, 'Position', [acatX y acatW acatH]);

    % Drug_unreleased: left side, 130x16
    simbio.diagram.setBlock(sp_unr, 'Position', [acatX+15, y+acatH/2-8, 130, 16]);

    % Drug_dissolved: right side, 130x16
    simbio.diagram.setBlock(sp_dis, 'Position', [acatX+215, y+acatH/2-8, 130, 16]);
end
```

### Complete ACAT example positions (for `acatX=20`)

| Segment   | Comp position      | Drug_unreleased    | Drug_dissolved     |
|-----------|--------------------|--------------------|---------------------|
| Stomach   | `[20 50 360 80]`   | `[35 82 130 16]`   | `[235 82 130 16]`   |
| Duodenum  | `[20 180 360 80]`  | `[35 212 130 16]`  | `[235 212 130 16]`  |
| Jejunum   | `[20 310 360 80]`  | `[35 342 130 16]`  | `[235 342 130 16]`  |
| Ileum     | `[20 440 360 80]`  | `[35 472 130 16]`  | `[235 472 130 16]`  |
| Colon     | `[20 570 360 80]`  | `[35 602 130 16]`  | `[235 602 130 16]`  |

### Two-species compartments (side-by-side arrangement)

For compartments in sequential chains where both species transit:

- Compartment size: `360 x 80`
- Species width: `130 x 16` (both names typically 13+ chars)
- Drug_unreleased: `[comp_x+15, comp_y+comp_h/2-8, 130, 16]` (left)
- Drug_dissolved: `[comp_x+215, comp_y+comp_h/2-8, 130, 16]` (right)
- Dissolution reaction node between them: `[comp_x+186, comp_y+33, 15, 15]`
- Transit reactions in vertical gaps must be **x-aligned with their
  species column** to prevent line crossings


----

Copyright 2026 The MathWorks, Inc.

----
