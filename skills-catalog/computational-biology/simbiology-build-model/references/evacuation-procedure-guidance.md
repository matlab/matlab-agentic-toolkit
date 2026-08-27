# Evacuation Procedure

> **This is a last-resort recovery procedure, NOT a standard build
> strategy.** For new models, always use `addAndPositionCompartment` to
> build one compartment at a time. Only use evacuation when rearranging
> an **existing** model where compartments must swap positions or change
> sizes.

The diagram API enforces constraints in real-time: species must remain
inside their parent compartment's bounds, and compartments cannot
overlap other blocks. When rearranging an existing layout, moving a
compartment will fail if its contained species would end up outside the
new bounds, or if the new position overlaps blocks that haven't been
moved yet.

**For rearrangements involving multiple compartments, follow this
5-phase procedure:**

## Phase 1: Move all reaction nodes to a staging area

Reaction nodes can block compartment movement. Evacuate them first:

```matlab
allRxns = model.Reactions;
for i = 1:numel(allRxns)
    try
        simbio.diagram.setBlock(allRxns(i), 'Position', [3000 + i*30, 3000, 15, 15]);
    catch
    end
end
```

## Phase 2: Move all species to a staging area

Move every species to a far-away coordinate so they don't constrain
compartment movement:

```matlab
allSpecies = model.Species;
for i = 1:numel(allSpecies)
    try
        simbio.diagram.setBlock(allSpecies(i), 'Position', [5000 + i*60, 5000, 32, 16]);
    catch
    end
end
```

## Phase 3: Move all compartments to a staging area

With species and reactions out of the way, spread compartments apart:

```matlab
allComps = model.Compartments;
for i = 1:numel(allComps)
    try
        simbio.diagram.setBlock(allComps(i), 'Position', [8000 + i*300, 8000, 250, 250]);
    catch e
        fprintf('Comp %s: %s\n', allComps(i).Name, e.message);
    end
end
```

## Phase 4: Position at final locations

Now place compartments at their final positions (no overlap conflicts),
then place species inside at planned coordinates, then reactions:

```matlab
% 1. Position compartments at final locations
comp = sbioselect(model, 'Type', 'compartment', 'Name', 'Central');
simbio.diagram.setBlock(comp, 'Position', [x y width height]);

% 2. Position species inside compartment at planned coordinates
simbio.diagram.setBlock(species(1), 'Position', [x+40, y+30, 50, 16]);
simbio.diagram.setBlock(species(2), 'Position', [x+140, y+30, 80, 16]);

% 3. Position reactions
repositionAllReactions(model);
```

If you don't have specific planned coordinates for species, distribute
them in a row inside the compartment with even spacing:

```matlab
species = comp.Species;
n = numel(species);
margin = 30;
spWidth = 50;  % scale per name length: <=5→50, 6-12→100, 13+→130
spacing = (width - 2*margin - spWidth) / max(n-1, 1);
for i = 1:n
    sx = x + margin + (i-1)*spacing;
    sy = y + height/2 - 8;
    simbio.diagram.setBlock(species(i), 'Position', [round(sx) round(sy) spWidth 16]);
end
```

## Phase 5: Verify no blocks are stranded

After placing all blocks at final positions, scan every block to ensure
none were left behind at staging coordinates (>= 2500 px from layout
center):

```matlab
threshold = 2500;
allComps = model.Compartments;
compPositions = zeros(numel(allComps), 2);
for i = 1:numel(allComps)
    p = simbio.diagram.getBlock(allComps(i), 'Position');
    compPositions(i,:) = [p(1) p(2)];
end
layoutCenter = mean(compPositions, 1);

% Check reactions
for i = 1:numel(model.Reactions)
    p = simbio.diagram.getBlock(model.Reactions(i), 'Position');
    dist = sqrt((p(1)-layoutCenter(1))^2 + (p(2)-layoutCenter(2))^2);
    if dist > threshold
        fprintf('STRANDED: Reaction %d at [%d %d]\n', i, p(1), p(2));
    end
end

% Check species
for i = 1:numel(model.Species)
    p = simbio.diagram.getBlock(model.Species(i), 'Position');
    dist = sqrt((p(1)-layoutCenter(1))^2 + (p(2)-layoutCenter(2))^2);
    if dist > threshold
        fprintf('STRANDED: Species %s at [%d %d]\n', model.Species(i).Name, p(1), p(2));
    end
end
```

**Fix stranded blocks immediately** — use `computeSafeReactionPosition`
for stranded reactions, and reposition stranded species inside their
parent compartment.

## When evacuation is needed vs not needed

- **Needed:** Rearranging an existing model where multiple compartments
  must swap positions or change sizes.
- **NOT needed — initial construction:** Use `addAndPositionCompartment`
  to build one compartment at a time with correct positions from the start.
- **Not needed:** Moving a single compartment, adding new blocks to an
  existing layout, small position adjustments.


----

Copyright 2026 The MathWorks, Inc.

----
