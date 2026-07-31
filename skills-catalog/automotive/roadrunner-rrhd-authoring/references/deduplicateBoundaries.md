# Boundary Deduplication (MANDATORY Post-Construction Step)

When building RRHD from any source that assigns separate boundary objects to opposing lanes (Lanelet2, HERE, NDS, etc.), duplicate boundaries are nearly guaranteed. Two ways in the source may contain **identical geometry in reverse order** — the per-way deduplication (`wayToBndID`) only catches same-ID reuse, NOT reversed-duplicate ways.

**This step is MANDATORY after all boundaries and lanes are built, before `write()`.**

## Why

Without deduplication, opposing lanes have separate boundary objects for the same physical line. RoadRunner renders them independently, causing:
- Visual doubling of lane markings
- Incorrect shared-boundary topology
- Rendering artifacts at lane edges

On a typical map with 184 lanes, expect ~30 reversed duplicates.

## Algorithm

After building all `LaneBoundary` objects and all `Lane` objects:

```matlab
%% --- BOUNDARY DEDUPLICATION (MANDATORY) ---
nBnd = numel(laneBoundaries);
duplicates = {};
for i = 1:nBnd
    for j = i+1:nBnd
        g1 = laneBoundaries(i).Geometry;
        g2 = laneBoundaries(j).Geometry;
        if size(g1,1) ~= size(g2,1), continue; end

        % Check reverse match (most common case for opposing lanes)
        maxDiffRev = max(vecnorm(g1 - flipud(g2), 2, 2));
        if maxDiffRev < 0.001
            duplicates{end+1} = struct('keep',i,'remove',j,'type','reversed');
            continue;
        end

        % Check forward match (rare but possible)
        maxDiffFwd = max(vecnorm(g1 - g2, 2, 2));
        if maxDiffFwd < 0.001
            duplicates{end+1} = struct('keep',i,'remove',j,'type','identical');
        end
    end
end

% Update lane references: point removed boundaries to kept ones
for d = 1:numel(duplicates)
    dup = duplicates{d};
    keepID = string(laneBoundaries(dup.keep).ID);
    removeID = string(laneBoundaries(dup.remove).ID);

    for i = 1:numel(lanes)
        % Update left boundary references
        if string(lanes(i).LeftLaneBoundary.Reference.ID) == removeID
            currAlign = lanes(i).LeftLaneBoundary.Alignment;
            if strcmp(dup.type, 'reversed')
                if currAlign == "Forward", newAlign = "Backward";
                else, newAlign = "Forward"; end
            else
                newAlign = currAlign;
            end
            ar = roadrunner.hdmap.AlignedReference;
            ref = roadrunner.hdmap.Reference; ref.ID = keepID;
            ar.Reference = ref; ar.Alignment = newAlign;
            lanes(i).LeftLaneBoundary = ar;
        end

        % Update right boundary references
        if string(lanes(i).RightLaneBoundary.Reference.ID) == removeID
            currAlign = lanes(i).RightLaneBoundary.Alignment;
            if strcmp(dup.type, 'reversed')
                if currAlign == "Forward", newAlign = "Backward";
                else, newAlign = "Forward"; end
            else
                newAlign = currAlign;
            end
            ar = roadrunner.hdmap.AlignedReference;
            ref = roadrunner.hdmap.Reference; ref.ID = keepID;
            ar.Reference = ref; ar.Alignment = newAlign;
            lanes(i).RightLaneBoundary = ar;
        end
    end
end

% Remove duplicate boundaries from the array
removeIDs = containers.Map('KeyType','char','ValueType','logical');
for d = 1:numel(duplicates)
    removeIDs(char(string(laneBoundaries(duplicates{d}.remove).ID))) = true;
end
newBoundaries = roadrunner.hdmap.LaneBoundary.empty;
for i = 1:numel(laneBoundaries)
    if ~removeIDs.isKey(char(string(laneBoundaries(i).ID)))
        newBoundaries(end+1) = laneBoundaries(i);
    end
end
laneBoundaries = newBoundaries;
fprintf('Boundary deduplication: removed %d duplicates (%d boundaries remain)\n', ...
    numel(duplicates), numel(laneBoundaries));
```

## Key Details

- **Tolerance:** 0.001m (1mm) — accounts for floating-point precision without false positives
- **Reversed duplicates:** When merging a reversed pair, FLIP the alignment for all lanes that referenced the removed boundary (`Forward` ↔ `Backward`)
- **Identical duplicates:** Keep alignment unchanged — geometry direction matches
- **Marking preservation:** The kept boundary retains its `ParametricAttributes`. If the removed boundary had markings that the kept one doesn't, merge them (rare in practice — usually one of the pair is unmarked)
- **Order:** Run AFTER endpoint snapping and height conflict resolution, BEFORE the enforcement gate

## When to Skip

- Synthetic scenes built from scratch (boundaries are created once, no duplication)
- Maps where the source format guarantees unique boundary geometry (uncommon)

## Integration with Pipeline

In the standard RRHD construction pipeline:

1. Build all boundaries and lanes
2. Endpoint snapping
3. Height conflict resolution
4. **Boundary deduplication** ← this step
5. Enforcement gate (alignment + spatial checks)
6. Assemble map and `write()`

----

Copyright 2026 The MathWorks, Inc.
