# Morphological Operations

Decision guidance and non-obvious patterns for shape-based image processing. Covers structuring elements, binary cleanup, grayscale morphology, and reconstruction.

> **Often loaded with:** `segmentation-automated.md` (creating masks to clean up), `analysis-measurement.md` (measuring objects after cleanup).

## Before You Start — Class and Polarity

Before choosing a function, inspect both class and foreground polarity:

- **Logical mask** → binary morphology (`imerode`, `imdilate`, `imopen`, `imclose`, `bwareaopen`, etc.)
- **Numeric image** (uint8, single, etc.) → grayscale morphology (`imtophat`, `imbothat`, `imopen`, `imclose`)
- Binary functions treat nonzero pixels as foreground, but skeletonization expects intended objects to be logical `true` — complement dark-on-light images first
- Do not pass an RGB or grayscale array to a "mask cleanup" recipe without deliberately creating and validating the mask
- A 2-D SE applied to a multi-channel image (e.g., RGB) operates on each channel independently

## Structuring Elements

| Shape | Constructor | Typical use |
|-------|------------|-------------|
| Disk | `strel("disk", radius)` | General-purpose, isotropic |
| Square | `strel("square", width)` | Fast, axis-aligned |
| Rectangle | `strel("rectangle", [h w])` | Directional (non-square) |
| Line | `strel("line", len, angle)` | Directional filtering (e.g., detecting scratches) |
| Diamond | `strel("diamond", radius)` | 4-connected equivalent of disk |

`imdilate` and `imerode` automatically exploit SE decomposition and binary packing — do not hand-implement packing to optimize ordinary morphology. Disk and ball SEs use an approximation that is faster but can change the exact discrete footprint; other documented geometric decompositions (line, rectangle, square, diamond) are exact. Inspect `se.Neighborhood` to see the pixel footprint, or `decompose(se)` to see the decomposed sequence.

### Choosing a Structuring Element — Decision Workflow

SE choice has three dimensions: **target feature**, **scale**, and **orientation**. A wrong choice can leave artifacts (square SE rounds corners; disk SE rounds right angles) or destroy structure (oversized SE erases foreground during opening, connects unrelated objects during closing).

1. **Name the feature** — protrusion, dark notch, gap, bridge, isolated object, line, or local peak
2. **Measure it in pixels** — zoom/crop in Image Viewer or use the distance measurement tool to count pixels across the target feature
3. **Choose geometry:**
   - Disk — approximately isotropic features (round objects, general cleanup)
   - Line — orientation-selective features (scratches, vessels, cracks at a known angle)
   - Rectangle/square — axis-aligned structure
   - Arbitrary neighborhood — only when geometry demands a custom shape
4. **Start slightly below the measured scale**, inspect the result, then increase gradually — an oversized SE is destructive
5. **Visualize the SE** before processing: `se.Neighborhood` shows the actual pixel neighborhood
6. **Recheck** object count, topology, and downstream measurements after applying

**Caveats:**
- `strel("line", len, angle)` has approximate length on the discrete pixel grid — the actual neighborhood may not match the requested length exactly
- Arbitrary neighborhoods use `floor((size(nhood)+1)/2)` as the origin — for even-sized neighborhoods, inspect the origin rather than assuming perfect symmetry

### Border Padding in Morphological Operations

Dilation and erosion use different virtual padding values for pixels beyond the image boundary:
- **Dilation** pads with the datatype minimum (0 for binary/uint8)
- **Erosion** pads with the datatype maximum (1 for binary, 255 for uint8)

This means `imclose(A, se)` and a manual `imerode(imdilate(A, se), se)` can differ near image borders — the compound operation has different intermediate boundary conditions than the fused function. If a result looks wrong only near edges, check the padding and output-shape (`"same"` vs `"full"`) assumptions before concluding the morphology is incorrect.

### Troubleshooting Morphological Results

| Symptom | Likely cause | Adjustment |
|---------|-------------|------------|
| Opening returns all zeros | SE cannot fit inside retained foreground | Reduce SE or choose a better-aligned shape |
| Closing merges separate objects | SE spans the inter-object gap | Reduce SE or use an oriented SE |
| Square corners/flat edges appear | SE geometry is imprinting on the mask | Try a disk/diamond or an oriented line |
| Result differs only near image edges | Dilation/erosion border padding asymmetry | Check padding values and output-shape option; use `imclearborder` if border objects are unreliable |
| Goal is only enclosed-hole filling | Closing is the wrong abstraction | Use `imfill`; route detailed recipes to `segmentation-automated.md` |

## Binary Cleanup — Choosing the Right Tool

This is where agents most often pick verbose manual approaches when a one-liner exists:

| Goal | Function | Example |
|------|----------|---------|
| Remove objects < N pixels | `bwareaopen(bw, N)` | `bwareaopen(bw, 50)` |
| Keep objects in size range | `bwareafilt(bw, [lo hi])` | `bwareafilt(bw, [100 5000])` |
| Keep N largest objects | `bwareafilt(bw, N)` | `bwareafilt(bw, 3)` |
| Filter by any property | `bwpropfilt(bw, prop, range)` | `bwpropfilt(bw, "Eccentricity", [0 0.5])` |
| Fill enclosed holes | `imfill(bw, "holes")` | Only fills fully-enclosed regions |
| Remove border-touching objects | `imclearborder(bw)` | Removes objects touching any image edge |
| Remove objects touching specific borders | `imclearborder(bw, Borders=["top" "left"])` | R2023b: select which borders to clear |
| Keep only border-touching objects | `imkeepborder(bw)` | R2023b: opposite of `imclearborder` |
| Smooth object boundaries | `imopen(bw, se)` then `imclose` | Opening removes protrusions, closing fills notches |
| Fill only small holes | See pattern below | `imfill` fills ALL holes; use area filtering to keep large holes |
| Group nearby objects | `bwdist(bw) <= d` then label | Clusters objects within distance `d` of each other |

### Pattern: Fill Only Small Holes (Not All)

`imfill(bw, "holes")` fills every hole. To fill only holes below a size threshold:

```matlab
filled = imfill(bw, "holes");           % Fill all holes
holes = filled & ~bw;                    % Extract just the hole pixels
bigholes = bwareaopen(holes, 500);       % Keep only large holes (>= 500 px)
bw_clean = bw | (holes & ~bigholes);    % Fill small holes, preserve large ones
```

This is far cleaner than manually iterating over holes with `regionprops`.

### Pattern: Group Nearby Objects (Almost-Connected Components)

To label clusters of objects that are close together (within distance `d`) but not touching:

```matlab
bw_expanded = bwdist(bw) <= d/2;              % All pixels within d of any foreground
L = labelmatrix(bwconncomp(bw_expanded));   % Label the merged clusters
L(~bw) = 0;                                 % Mask back to original objects only
```

Each original object now carries the label of its cluster. Objects within `d` pixels of each other share a label. This uses the distance transform for true isotropic (circular) expansion — more accurate than `imdilate` with an approximate disk strel for large distances.

### `bwpropfilt` — Filter by Any Region Property

This is extremely useful and agents almost never use it:

```matlab
% Keep only round objects (low eccentricity)
round = bwpropfilt(bw, "Eccentricity", [0 0.5]);

% Keep objects with area > 500
large = bwpropfilt(bw, "Area", [500 Inf]);

% Keep objects with specific solidity
solid = bwpropfilt(bw, "Solidity", [0.8 1.0]);
```

Accepts a documented subset of `regionprops` properties — check the `bwpropfilt` reference page for the supported list.

## Grayscale Morphology — Background Correction

The classic pattern for correcting uneven illumination. **For smooth, gradual illumination gradients** (vignetting, microscopy shading), prefer `imflatfield(img, sigma)` — one function, one parameter. See `preprocessing.md`. Use morphological correction below when the background variation is shape-dependent or `imflatfield` does not model the background well.

### Pattern: Top-Hat for Background Removal

```matlab
se = strel("disk", 15);  % Radius > largest foreground object
corrected = imtophat(img, se);  % Removes slowly-varying background in one step
```

`imtophat(img, se)` = `img - imopen(img, se)`. It returns bright structures that do not survive the opening — i.e., regions where the SE cannot fit inside the foreground, based on shape and orientation, not merely size.

### Pattern: Bottom-Hat for Dark Feature Extraction

```matlab
se = strel("disk", 15);
dark_features = imbothat(img, se);  % Extracts dark structures smaller than the SE
```

`imbothat(img, se)` = `imclose(img, se) - img`. The dual of `imtophat` — extracts dark features on a bright background. Combine both for contrast enhancement: `enhanced = img + imtophat(img, se) - imbothat(img, se)`.

### Pattern: Opening-by-Reconstruction (Better Shape Preservation)

Standard `imopen` can truncate object peaks. Reconstruction preserves full object shape:

```matlab
se = strel("disk", 15);
marker = imerode(img, se);            % Create marker below the signal
background = imreconstruct(marker, img);  % Reconstruct: grows marker up to mask
corrected = img - background;
```

**Key rule for `imreconstruct`:** marker must be ≤ mask pointwise. If marker > mask at any pixel, `imreconstruct` **silently clips** the marker down to the mask level — no error or warning. Swapping the arguments (passing mask as marker and vice versa) produces meaningless results with no indication that anything is wrong. Always verify: `imreconstruct(marker, mask)` where marker ≤ mask.

### Pattern: Double Thresholding (Hysteresis)

When a single threshold either includes too many pixels (too low) or misses connected regions (too high), use two thresholds + reconstruction:

```matlab
mask_high = img > T_high;   % Conservative: only strong features (marker)
mask_low = img > T_low;     % Liberal: includes weak connected regions (mask)
result = imreconstruct(mask_high, mask_low);  % Keep low-threshold regions connected to high
```

This keeps all pixels above `T_low` that are connected to any pixel above `T_high`. Isolated weak pixels (noise) are excluded. This is the same logic Canny edge detection uses internally for edge linking.

### Pattern: Keep Whole Objects Touching a Region

To select complete objects that overlap with a mask (ROI, border, etc.) without truncating them:

```matlab
seeds = bw & roi_mask;                % Partial object pixels inside the ROI
whole_objects = imreconstruct(seeds, bw);  % Restore full objects from seeds
```

This is essential when you need to keep entire objects that partially overlap a polygon, border region, or distance buffer — logical AND alone truncates objects at the boundary.

### Morphological Minima/Maxima Transforms

For `imhmin`, `imhmax`, `imextendedmin`, `imextendedmax`, `imregionalmin`, `imregionalmax` — used for peak/valley detection and watershed preparation — see the Peak / Bright Spot Detection section in `analysis-measurement.md`.

## Skeletonization

### Workflow — In This Order

Unclean masks directly create loops and spurs in the skeleton. Follow this sequence:

1. **Establish foreground polarity** — objects must be logical `true`. Complement dark-on-light images (`~bw`)
2. **Clean the mask** — remove irrelevant components (`bwareaopen`, or `bwareafilt(bw, 1)` for the largest) and fill unintended holes (`imfill(bw, "holes")`). Holes become loops; fragments become branches. Detailed component filtering belongs in `segmentation-automated.md`, but these preconditions belong here
3. **Skeletonize** — choose a function (see below)
4. **Compare `bwskel` and `bwmorph`** when centerline placement matters (see below)
5. **Prune** — only after understanding branch-length units and connectivity (see below)
6. **Validate topology** — check endpoints (`bwmorph(skel, "endpoints")`), branchpoints (`bwmorph(skel, "branchpoints")`), and connectivity before measuring length

### Choosing a Skeletonization Function

```matlab
skel = bwmorph(bw, "skel", Inf);           % More accurate/symmetric skeletons for 2-D
skel = bwskel(bw);                         % Supports MinBranchLength pruning
skel = bwskel(bw, "MinBranchLength", 10);  % Prune short branches — not available with bwmorph
```

For 2-D images, `bwmorph(bw, "skel", Inf)` may produce more accurate and symmetric skeletons than `bwskel`. However, `bwskel` supports `MinBranchLength` for branch pruning — if pruning is needed, use `bwskel`; if skeleton accuracy matters more, compare both on representative data. `bwskel` 2-D behavior was improved in R2026a (no longer internally pads to 3-D), but `bwmorph` skeleton remains the recommended choice for 2-D accuracy.

### Branch Pruning

`MinBranchLength` is measured in **pixels using fixed connectivity** (pixel-to-pixel hops along the skeleton), not Euclidean path length. A diagonal branch of 10 pixels covers ~14 pixels of Euclidean distance but counts as 10 for pruning. Account for this when setting the threshold.

For `bwmorph`-based skeletons (which lack `MinBranchLength`), prune with iterated spur removal:

```matlab
skel = bwmorph(skel, "spur", n);  % Remove n pixels from branch endpoints
```

### Display Caveat

A one-pixel-wide skeleton may appear discontinuous when the image is downsampled for display — zoom to 100% to verify continuity.

## Hit-Miss Transform — `bwhitmiss`

Exact local binary-pattern matching. Use when you need to find pixels whose neighborhood matches a specific foreground/background configuration — replaces verbose combinations of indexing, convolution, and logical tests:

```matlab
% Find top-left corner pixels: foreground pixel with background above and to the left
interval = [ -1 -1 -1;
             -1  1  0;
             -1  0  0];
% 1 = required foreground, -1 = required background, 0 = don't care
corners = bwhitmiss(bw, interval);
```

Equivalent to erosion of the foreground by the `1` positions combined with erosion of the complement by the `-1` positions. The two sets of positions must not overlap.

Other uses: finding endpoints, isolated pixels, T-junctions, or any specific local topology without writing custom neighborhood logic.

## `bwmorph` Operations Reference

| Operation | Effect |
|-----------|--------|
| `"thin"` | Thin to 1-pixel width (use `Inf` iterations) |
| `"skel"` | Skeletonize (see above section for nuance) |
| `"remove"` | Extract perimeter (interior pixels removed) |
| `"endpoints"` | Find endpoints of skeleton branches |
| `"branchpoints"` | Find branch junction points |
| `"spur"` | Remove spur pixels (short branches) |
| `"bridge"` | Connect broken segments (fills gaps) |
| `"fill"` | Fill isolated interior pixels |
| `"clean"` | Remove isolated pixels (salt noise) |
| `"majority"` | Set pixel to 1 if ≥5 of 9 pixels in 3×3 neighborhood are 1; otherwise set to 0 |

## Connectivity Matters

Many binary functions default to 8-connectivity in 2-D. This affects object counting:

```matlab
cc4 = bwconncomp(bw, 4);  % 4-connected: stricter (more objects)
cc8 = bwconncomp(bw, 8);  % 8-connected: diagonal touching counts (fewer objects)
```

`bwareaopen` also accepts a connectivity argument (default 8 for 2-D, 26 for 3-D). `bwareafilt` and `bwpropfilt` are 2-D only and accept 4 or 8 connectivity. Match connectivity across pipeline steps — using 4-connectivity in `bwconncomp` but 8-connectivity in `bwareaopen` gives inconsistent object definitions.

**Rule of thumb:** Use 4-connectivity for foreground objects, 8-connectivity for holes/background. This follows the Jordan curve convention (ensures objects don't leak through diagonal gaps).

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Manual loop to remove small objects | Verbose, slow | `bwareaopen(bw, minSize)` — one line |
| `bwskel` without comparing to `bwmorph` skeleton | `bwmorph(bw, "skel", Inf)` may be more accurate for 2-D | Compare both; use `bwskel` when `MinBranchLength` pruning is needed |
| Opening then closing for smoothing | Order matters — results differ | Opening first (removes noise), then closing (fills gaps) |
| Ignoring border objects | `imfill` and `regionprops` include them | `imclearborder(bw)` to remove before analysis |
| Manual extraction of border objects | Verbose: `bw & ~imclearborder(bw)` | `imkeepborder(bw)` (R2023b) — direct one-liner |
| `imclearborder` removes all borders unwanted | Sometimes only specific edges matter | `imclearborder(bw, Borders=["top" "bottom"])` (R2023b) |
| Large `strel("disk")` for grayscale morphology | Can be slow | Consider `imtophat` (shortcut); decomposition is automatic — do not hand-pack |
| Skeleton has loops or many spurs | Holes and small components in the input mask | Fill holes and remove fragments before skeletonizing |
| Passing a grayscale/RGB image to binary cleanup | Numeric input triggers grayscale morphology, not binary | Create and validate a logical mask first |
| Expecting `imclose` to only fill holes | Closing alters boundaries and can merge objects | Use `imfill(bw, "holes")` for enclosed-hole filling |
| Using `parfor` with `bwskel` | Internal multithreading can interact poorly with worker configuration | Test with single-threaded workers or run outside `parfor` |

----

Copyright 2026 The MathWorks, Inc.

----
