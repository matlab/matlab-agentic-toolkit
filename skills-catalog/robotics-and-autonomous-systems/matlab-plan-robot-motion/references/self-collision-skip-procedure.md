# Self-Collision Skip List Procedure

Empirical procedure to determine the correct `SkippedSelfCollisions` cell array for any robot model. Use this when `SkippedSelfCollisions="parent"` does not eliminate all self-collisions at valid configurations.

## Prerequisites

- Robot model with `DataFormat="row"` and collision meshes present
- `checkCollision` confirms `isColliding=true` at home with `"parent"` skip

## How many samples do you need?

| Gripper type | DOF | Samples needed | Iterative pass? |
|--------------|-----|----------------|-----------------|
| Fixed geometry (vacuum grippers, 0 DOF) | 0 | 10 | No — all overlaps are constant across configs |
| Actuated parallel linkage (e.g., robotiq2F85) | 6 | 50 | Yes — linkage pairs collide ~70-90% but not 100% |

For 0-DOF grippers, the gripper geometry is rigidly fixed to the wrist. Any collision pair involving gripper bodies will be NaN in either ALL configs or NONE — there are no partial-frequency pairs. The only collisions that vary are arm-to-arm self-collisions at extreme joint angles, which are real and should NOT be skipped.

## Step 1: Sample configurations with no skipping

Use `{" "," "}` (single-space chars in a 1x2 cell) as the dummy skip pair. This satisfies the Mx2 cell validation without skipping any actual body pair, suppressing the default parent-skip warning.

Sample 50+ random configurations within joint limits plus the home configuration. More samples give a clearer separation between "always colliding" (geometry overlap) and "sometimes colliding" (configuration-dependent).

```matlab
rng(42);
numSamples = 50;
numJoints = numel(homeConfiguration(robot));

lowerLimits = zeros(1, numJoints);
upperLimits = zeros(1, numJoints);
jIdx = 1;
for i = 1:robot.NumBodies
    jnt = robot.Bodies{i}.Joint;
    if ~strcmp(jnt.Type, 'fixed')
        lowerLimits(jIdx) = jnt.PositionLimits(1);
        upperLimits(jIdx) = jnt.PositionLimits(2);
        jIdx = jIdx + 1;
    end
end

configs = zeros(numSamples + 1, numJoints);
configs(1,:) = homeConfiguration(robot);
for i = 2:numSamples+1
    configs(i,:) = lowerLimits + (upperLimits - lowerLimits) .* rand(1, numJoints);
end
```

## Step 2: Find always-NaN pairs (100% collision rate)

These are pairs with permanently overlapping collision geometry — typically parent-child joints.

```matlab
[~, sdTest] = checkCollision(robot, configs(1,:), {}, ...
    Exhaustive="on", SkippedSelfCollisions={" "," "});
matSize = size(sdTest, 1);
alwaysNaN = true(matSize);

for c = 1:size(configs, 1)
    [~, sd] = checkCollision(robot, configs(c,:), {}, ...
        Exhaustive="on", SkippedSelfCollisions={" "," "});
    alwaysNaN = alwaysNaN & isnan(sd);
end
```

## Step 3: Build body name index

The `separationDist` matrix ordering is: rows/cols 1:m = `robot.Bodies{1:m}` in order, row/col m+1 = `robot.BaseName`. The base is always the LAST index.

```matlab
bodyNames = cell(1, matSize);
for i = 1:robot.NumBodies
    bodyNames{i} = robot.Bodies{i}.Name;
end
bodyNames{matSize} = robot.BaseName;
```

## Step 4: Collect always-NaN pairs into skip list

```matlab
skipPairs = {};
for i = 1:matSize
    for j = i+1:matSize
        if alwaysNaN(i,j)
            skipPairs(end+1,:) = {bodyNames{i}, bodyNames{j}};
        end
    end
end
```

## Step 5: Iterative pass for high-frequency pairs

Parallel-linkage grippers (e.g., robotiq2F85) have body pairs that collide in ~70-90% of random configs but not 100%. These are still permanent overlaps due to the linkage mechanism — the configs where they don't collide are unreachable in practice because the URDF models coupled joints as independent.

After applying the always-NaN skip list, re-check at home. If still colliding, add the remaining NaN pairs:

```matlab
[isColl, sd] = checkCollision(robot, homeConfiguration(robot), {}, ...
    Exhaustive="on", SkippedSelfCollisions=skipPairs);

while isColl
    added = false;
    for i = 1:matSize
        for j = i+1:matSize
            if isnan(sd(i,j))
                skipPairs(end+1,:) = {bodyNames{i}, bodyNames{j}};
                added = true;
            end
        end
    end
    if ~added, break; end
    [isColl, sd] = checkCollision(robot, homeConfiguration(robot), {}, ...
        Exhaustive="on", SkippedSelfCollisions=skipPairs);
end
```

## Step 6: Verify

```matlab
[isColl, ~] = checkCollision(robot, homeConfiguration(robot), {}, ...
    SkippedSelfCollisions=skipPairs);
assert(~isColl, "Home config still in self-collision after skip list applied.");
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Skip pair still shows NaN (not Inf) | Name mismatch or char/string type mismatch | Ensure all entries in `skipPairs` are char vectors (single quotes), not strings (double quotes) |
| `isColliding=true` but no NaN pairs visible | Looking at wrong matrix region; base assumed at index 1 | Base is at index m+1 (last). Verify with `bodyNames{end}` |
| Random configs collide after skip list applied | Real configuration-dependent collisions (e.g., gripper fingers crossing) | Expected for independently-actuated parallel linkages at random configs. Verify home and realistic configs pass. |
| Error: "Expected SkippedSelfCollisions to be of size Mx2" | Passed `{}` (0x0) instead of a valid cell | Use `{" "," "}` as the no-skip placeholder |

----

Copyright 2026 The MathWorks, Inc.

----

