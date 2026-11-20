# Use Poses and Reference Frames

## Construct a Pose

A `pose` holds a position, an orientation, and optional motion, relative to a reference frame.

```matlab
p = pose([40.7 -74.0 100]);                         % position only, identity orientation
pEuler = pose([40.7 -74.0 100], [45 0 0]);          % Euler [yaw pitch roll], degrees
pDcm = pose([40.7 -74.0 100], eye(3));              % direction cosine matrix
pQuat = pose([40.7 -74.0 100], quaternion([1 0 0 0]));

pMoving = pose([40.7 -74.0 100], [45 0 0], Velocity=[10 0 0], AngularVelocity=[0 0 0.1]);
pFramed = pose([40.7 -74.0 100], [45 0 0], ReferenceFrame=geoframe);
pNed = pose([40.7 -74.0 100], [45 0 0], ReferenceFrame=geoframe(AxesConvention="ned"));  % "auto" uses "frd"
```

| Name-Value Argument | Values | Description |
|---|---|---|
| `ReferenceFrame` | empty (default) \| `ReferenceFrame` object | Frame of the position and orientation |
| `ObjectOrientationBasis` | `"auto"` (default) \| `"flu"` \| `"frd"` | Body axes of the orientation (see below) |
| `Velocity`, `Acceleration` | `[0 0 0]` (default) \| 1-by-3 or m-by-3 | m/s and m/s² |
| `AngularVelocity`, `AngularAcceleration` | `[0 0 0]` (default) \| 1-by-3 or m-by-3 | rad/s and rad/s² |

- Euler angle limits: yaw [−180, 180], pitch [−90, 90], roll [−180, 180].
- A pose without `ReferenceFrame` passed to `actor`, `car`, or `aircraft` uses the scene frame:
  `[lat lon h]` with `h` above terrain. A `geoframe` (no terrain) pose uses ellipsoid heights.
- Poses that place or set an actor must have zero motion; a pose with `Velocity` (like
  `pMoving`) is not supported.

### Multiple Poses

```matlab
pPair = pose([40.7 -74.0 100; 40.8 -74.1 200], [0 0 0; 45 10 0]);     % 2-by-1
pShared = pose([40.7 -74.0 100; 40.8 -74.1 200], [45 0 0]);         % orientation replicated
```

### ObjectOrientationBasis

| ObjectOrientationBasis | Description |
|---|---|
| `"auto"` (default) | From the frame: `"flu"` for ENU or no frame, `"frd"` for NED |
| `"flu"` | Forward-Left-Up body axes |
| `"frd"` | Forward-Right-Down body axes |

Leave it at `"auto"`. Forcing `"frd"` in an ENU frame or with no frame turns the object upside down.

## Pose Properties

Read-only: `Position`, `Forward`, `Backward`, `Left`, `Right`, `Up`, `Down`
(unit vectors in the frame), `Velocity`, `Acceleration`, `AngularVelocity`,
`AngularAcceleration`. `ReferenceFrame` can be assigned once to a pose created without one
(for example, `p.ReferenceFrame = scnro.Scene.ReferenceFrame` before `pose(actr, p)`); it does not
convert coordinates. To change frames, use `transform`.

## Extract Orientation

```matlab
eul = euler(p);                                 % m-by-3 [yaw pitch roll], degrees, "ZYX"
eulRad = euler(p, Units="radians");
eulFrd = euler(p, Sequence="ZYX", ObjectOrientationBasis="frd");
dc = dcm(p);                                    % 3-by-3-by-m, RotationType="frame" (default)
dcPoint = dcm(p, RotationType="point");         % transpose of the frame rotation
quat = quaternion(p);                           % RotationType="frame" (default) | "point"
```

## Actor Poses

Yaw follows the frame's `AxesConvention`. In an ENU frame (the scene's default), yaw is
counterclockwise from east: `0` faces east, `90` faces north. In an NED frame, yaw is clockwise
from north. When direction matters, place the actor with a `pose` instead of relying on its
default orientation, and read the orientation back with `euler(pose(actor))`.

```matlab
actr = actor(scnro, pose([40.7 -74.0 100], [45 0 0]), Name="Antenna");
p = pose(actr);                                 % in the scene frame
eul = euler(p);
heading = p.Forward;                            % unit vector, ENU
pRoof = pose(c, ReferencePoint="roof");         % pose of a reference point
pLocal = pose(actr, ReferenceFrame=localframe(40.7, -74.0));
xyz = pLocal.Position;                          % meters from the local origin

pose(actr, pose([40.7 -74.0 120], [30 0 0], ReferenceFrame=scnro.Scene.ReferenceFrame));
```

- Setting a pose with `pose(actr, p)` requires `p` to have a `ReferenceFrame` tied to the
  Earth (`geoframe`, `ecefframe`, or `localframe`, not `bodyframe`). `transform` also needs a
  `ReferenceFrame`; without one, both fail with a misleading argument-count error.
- `pose(actr, p)` works only on static actors before the simulation starts (see
  `actor-placement.md`, Modify Actors).

### Trajectory Poses vs Actor Poses

| Call | Frame | Height |
|---|---|---|
| `interp(airTraj, t)` | Plain WGS84 `geoframe`, `Terrain="none"` | Above the ellipsoid |
| `interp(groundTraj, t)` | Same frame label | The trajectory's `Height` offset (not ellipsoid) |
| `pose(actr)` | Scene frame (`scnro.Scene.ReferenceFrame`) | Above terrain |

To compare like with like, request the actor pose in the trajectory's frame:

```matlab
pTraj = interp(traj, 0);                            % geoframe, Terrain="none": h above ellipsoid
pScene = pose(a);                                   % scene frame: h above terrain
pSame = pose(a, ReferenceFrame=pTraj.ReferenceFrame);   % compare like with like
```

`pose(actr)` returns the `"centroid"` reference point. For an aircraft it lies on the
path; for a car it sits about 0.76 m above the path (use `ReferencePoint="asset-origin"`).

## Reference Frames

| Function | Frame | Positions |
|---|---|---|
| `geoframe` | Geographic, `"enu"` (default) or `"ned"`. Name-value arguments: `Name`, `Terrain`, `AxesConvention` | `[lat lon h]` |
| `ecefframe` | Earth-centered Earth-fixed, `"xyz"`. Name-value argument: `Name` | meters from Earth center |
| `localframe(lat, lon, ht)` | Local Cartesian, `"enu"` (default) or `"ned"`. Name-value arguments: `Name`, `Terrain`, `AxesConvention` | meters from origin |
| `bodyframe(actr)` | Attached to an actor, `"frd"` (default) or `"flu"`. Name-value arguments: `ReferencePoint`, `Name`, `AxesConvention` | meters from the reference point |

`Terrain` is `"none"` (default: heights above the ellipsoid) or a terrain name such as
`"gmted2010"` (heights above terrain). `localframe` takes scalar `lat, lon[, ht]`, not an array.
`scnro.Scene.ReferenceFrame` is the scene's geographic frame (uses the scenario's terrain).

```matlab
geoFrame = geoframe(AxesConvention="ned");
ecefFrame = ecefframe;
localFrame = localframe(40.7, -74.0, 0, AxesConvention="ned");
bodyFrame = bodyframe(c, ReferencePoint="roof");
```

ReferenceFrame properties: `Name`, `ReferenceBody` (`"Earth"` or the actor), `Datum`,
`CoordinateSystem` (`"geographic"` | `"cartesian"`), `AxesConvention`. `Datum` fields vary by
frame type; on geographic and local frames, `Datum.Terrain` shows whether heights are above
terrain or the ellipsoid.

## Transform Between Frames

`transform` needs an input pose with a `ReferenceFrame`.

```matlab
pIn = pose([40.7 -74.0 50], [0 0 0], ReferenceFrame=geoframe(Terrain="gmted2010"));
pOut = transform(pIn, localframe(40.7, -74.0, 0, Terrain="gmted2010"));
xyz = pOut.Position;                            % [x y z] meters
```

----

Copyright 2026 The MathWorks, Inc.

----
