---
name: workflow-19-ego-lane-inference
description: Predict ego lane index and lane count from front-camera frames using agent vision (bisection sampling). Self-gating — text-only agents skip to plain ASK. Feeds startLaneIdx (4th positional arg) and numEgoLanes to localizeEgoUsingLanes. Runs before Workflow 8 localization when camera frames are available.
---

# Workflow 19 — Ego Lane Inference from Camera (Vision-Based)

> **Parent skill:** [`SKILL.md`](../SKILL.md) Rule 4 Step 7 (Localize ego).
>
> **Related references:**
> - [`workflow-08-lane-localization.md`](workflow-08-lane-localization.md) — consumes `egoLaneIdx` as 4th positional arg to `localizeEgoUsingLanes`
> - [`workflow-18-vehicle-classification.md`](workflow-18-vehicle-classification.md) — same self-gating pattern
> - [`visualization-patterns.md`](visualization-patterns.md) — camera frame conventions

## When to Run

This workflow fires **before** the `startLaneIdx` question in Step 7, when ALL of these are true:

1. Camera frames are accessible via `imread` (JPG/PNG files exist)
2. Frame count is known (from `CameraData.NumSamples` or directory listing)
3. The agent can view images (multimodal — self-gating)
4. Localization will run (REQUIRED or user opted in per the Step 7 decision matrix)

**Skip conditions (any one → skip to plain ASK):**
- No camera frames available
- Agent cannot view images (text-only model)
- Localization is being skipped entirely

## Self-Gating Pattern

Same as Workflow 18. The instruction self-gates:

> "View the sampled frame. Count dashed lane dividers between left and right carriageway edges. If you cannot view images, skip lane inference and ask the user directly."

A text-only agent reading that instruction will skip to the existing plain-ASK path. A multimodal agent will classify.

## Pipeline Overview

```
Camera frames → Sample 5 evenly → Agent classifies each (numLanes, egoLane)
    → If all agree → Single segment → Predict
    → If consecutive disagree → Bisect transitions → Segment table → Predict
→ Present to user: "I see ego in lane N of M — confirm or correct?"
→ User confirms/corrects → Feed as 4th positional arg to localizeEgoUsingLanes(..., N)
```

Total agent reads: 5 for stable roads, ~12 for one transition. ~91x cheaper than dense per-frame.

## Step 1: Sample Frames

Sample 5 frames evenly across the camera clip:

```matlab
numFrames = cameraData.NumSamples;
sampleIndices = round(linspace(1, numFrames, 5));
frames = cameraData.Frames;  % cell array of file paths
```

For each sampled frame, read it via `imread` and view it.

## Step 2: Per-Frame Classification Rules

For each sampled frame, determine `numEgoLanes` and `egoLaneIdx`.

### Rule 1 — egoLaneIdx from geometry, not saliency (CRITICAL)

**Procedure (every frame):**
1. Find the **vanishing point** where lane lines converge in the distance.
2. Count **dashed lane dividers strictly to the LEFT of the vanishing point**.
3. `egoLaneIdx = (count to left of VP) + 1`.
4. **Cross-check with lead vehicle:** a vehicle directly in front of ego shares ego's lane. If your `egoLaneIdx` places the lead vehicle in a different lane, your count is wrong.

**Anti-pattern (DO NOT DO):** "Ego looks closer to the left barrier → ego is in lane 1." Asymmetric scene framing (wider shoulder on one side, recessed wall) makes the closer barrier dominate visually even when ego is in a middle lane.

### Rule 2 — numEgoLanes excludes ramps, shoulders, turn pockets

**Procedure:**
1. Identify the **left edge of ego carriageway**: solid yellow line (US), continuous white line, raised median, jersey barrier, grass divider.
2. Identify the **right edge of ego carriageway**: curb, solid white line, shoulder boundary, jersey barrier, sound wall.
3. Count **dashed dividers between left and right edges**. Add 1. That's `numEgoLanes`.
4. **Exclude:**
   - Turn pockets (verify: if rightmost lane disappears 50–100m past intersection, it's a pocket)
   - On-ramp / off-ramp lanes (gore stripes mark these)
   - Shoulders (narrower than a real lane, often rumble-stripped)

**Lesson from testing:** Intersection frames are unreliable (turn pockets inflate count). Rely on mid-segment frames for ground truth.

## Step 3: Detect Transitions via Bisection

If consecutive samples **disagree** on `numEgoLanes`, the road structure changed somewhere between them (ramp merge, highway exit, arterial→highway, etc.).

**Bisect** to localize the transition:

```
Given frameLow (lanes=A), frameHigh (lanes=B), A ≠ B:
1. mid = round((frameLow + frameHigh) / 2)
2. Agent views frame at mid, classifies → lanesMid
3. If lanesMid == A: frameLow = mid
   Else: frameHigh = mid
4. Repeat until (frameHigh - frameLow) <= 10
5. Transition is at frameHigh (±5 frames intrinsic uncertainty)
```

**Worst case:** `log2(initial_gap)` ≈ 7–8 reads to pin a transition in a 273-frame gap.

**Stop early:** When range ≤ 10 frames, stop. Road transitions (gore stripes fading, merge completing) span multiple frames — frame-exact precision is over-precision.

## Step 4: Build Segment Table

Output a segment table describing lane structure across the clip:

```matlab
% Example: ramp merging onto highway
segments = struct(...
    'segment',    {1, 2}, ...
    'frameStart', {282, 742}, ...
    'frameEnd',   {741, 1375}, ...
    'roadType',   {"on_ramp", "highway"}, ...
    'numLanes',   {1, 3}, ...
    'egoLaneIdx', {1, 3}, ...
    'confidence', {"medium", "medium"});
```

If all 5 initial samples agree → single segment covering the whole clip.

## Step 5: Present Prediction to User (Option B — confirm or correct)

**Do NOT silently use the prediction.** Always present it for user confirmation:

For a single-segment clip:
> *"From the dashcam frames, I see **3 lanes** on the ego carriageway with ego in **lane 2** (counting from leftmost = 1, excluding shoulders/ramps). Does that look right, or should I use a different lane index?"*

For a multi-segment clip:
> *"The road structure changes during this clip:*
> *- Frames 282–741: on-ramp, 1 lane, ego in lane 1*
> *- Frames 742–1375: highway, 3 lanes, ego in lane 3*
>
> *I'll use the highway segment (lane 3 of 3) for localization since that's where the ego spends most of its time on the imported road network. Confirm or correct?"*

**User response handling:**
- User confirms → use predicted values
- User corrects (e.g., "it's lane 2 not 3") → use user's value
- User says "I don't know" / unclear → fall back to plain ASK with dashcam reference

## Step 6: Feed to localizeEgoUsingLanes

Pass the confirmed/corrected values:

```matlab
% Single segment — 4 positional args (R2026a verified): trajectory, map, laneData, startLaneIdx
localizedTrajectory = localizeEgoUsingLanes(egoTrajectory, rrMap, laneData, egoLaneIdx);

% Multi-segment: use the segment that matches the imported road network.
% Typically the longest segment on the main road (highway > ramp).
mainSegment = segments(longestMainRoadIdx);
localizedTrajectory = localizeEgoUsingLanes(egoTrajectory, rrMap, laneData, mainSegment.egoLaneIdx);
```

**numEgoLanes usage:** When the segment table shows a lane-count change, the `laneData` from the lane detector may also reflect this — `localizeEgoUsingLanes` handles variable lane counts internally by interpolating through frames with fewer detected boundaries. The `numEgoLanes` from the dominant segment confirms the expected map structure and helps diagnose localization failures (e.g., if `localizeEgoUsingLanes` errors with "lane count mismatch", compare agent-predicted `numEgoLanes` against the rrhd lane count).

## Confidence Levels

| Condition | Confidence |
|-----------|-----------|
| All 5 samples agree, clear markings, daytime | high |
| 4/5 agree, or one ambiguous frame | medium |
| Dusk/night, low-res (640×480), markings barely visible | low |
| Fewer than 3/5 agree with no clear transition pattern | low → fall back to plain ASK |

When confidence is `low` and no clear segment pattern emerges, skip the prediction entirely and use the plain ASK path.

## Integration with SKILL.md Step 7

This workflow modifies the `startLaneIdx` acquisition in Step 7:

**Before (current — plain ASK):**
```
Step 7 gate reached → show dashcam video popup → ask user cold:
"Which lane is ego in? Count from leftmost = 1."
```

**After (Workflow 19 integrated):**
```
Step 7 gate reached → show dashcam video popup →
  IF agent can view images:
    Run Workflow 19 (sample + bisect + classify)
    Present prediction: "I see lane N of M — confirm or correct?"
  ELSE:
    Ask user cold (existing behavior)
```

The dashcam video popup still fires BEFORE the question — the user needs to see the video regardless of whether the agent has a prediction.

## Known Limitations

| Limitation | Mitigation |
|-----------|-----------|
| Single-frame at intersections inflates lane count (turn pockets) | Rely on mid-segment frames; 5-sample spread catches this |
| Saliency bias ("close barrier = lane 1") | Vanishing-point + lead-vehicle cross-check (Rule 1) |
| Low resolution (640×480) makes distant lane structure ambiguous | Report `confidence=low`; fall back to plain ASK |
| Gore stripes fade over ~5 frames at merges | ±5 frame boundary uncertainty is acceptable; don't over-bisect |
| Night/dusk: lane markings invisible | If markings not visible, report `confidence=low` → plain ASK |
| Curves distort distant lane count | Trust near-camera dividers, not distant ones |

## Efficiency

| Clip type | Agent reads | vs. dense per-frame |
|-----------|-------------|---------------------|
| No transitions (typical) | 5 | ~200× cheaper on 1000-frame clip |
| 1 transition | ~12 | ~91× cheaper |
| 2 transitions | ~19 | ~58× cheaper |

## Validated Datasets

| Dataset | Frames | Result | Reads |
|---------|--------|--------|-------|
| Pandaset_Seq90 | 80 | 3 lanes, ego lane 2, stable | 5 |
| VSILabs_Seq001 | 1303 | 3 lanes, ego lane 2, stable | 5 |
| VSILabs_Seq072 | 1094 | Ramp(1 lane)→Highway(3 lanes, ego lane 3) | 12 |
| Polysync_Seq_05_hm | 467 | 4 lanes, ego lane 4, stable | 5 |

---

Copyright 2026 The MathWorks, Inc.
