# Custom Measurement Models for Legacy Trackers

Use this reference when measurements don't fit built-in models (`cvmeas`, `cameas`, etc.) and a custom measurement function + filter init pair is needed.

## When You Need Custom Models

- TDOA (time difference of arrival)
- Custom geometry not covered by standard spherical/rectangular
- Camera bounding boxes used with a legacy tracker
- Any measurement that requires domain-specific math to relate state to observation

## Custom MeasurementParameters Design

The struct can contain ANY fields. Design principles:

1. **Must carry all info the measurement function needs** to compute expected measurement from state (sensor geometry, intrinsics, baseline distances, etc.)
2. **Must include a discriminator** if multi-sensor (so the shared measurement function can branch)
3. **All detections must use the same struct fields** regardless of sensor — leave unused fields empty or with defaults

```matlab
% Example: TDOA sensor pair
mp = struct( ...
    'SensorType', 'tdoa', ...           % discriminator
    'Receiver1Position', [0;0;0], ...   % first receiver position
    'Receiver2Position', [100;0;0], ... % second receiver position
    'SpeedOfSignal', 3e8);              % propagation speed
```

## Custom Measurement Function Template

Signature for additive noise: `z = measFcn(state, mp)`

```matlab
function z = myMeasFcn(state, mp)
    % state: [x; vx; y; vy; z; vz] or your custom state vector
    % mp: your MeasurementParameters struct
    
    switch mp.SensorType
        case 'tdoa'
            pos = state([1,3,5]);  % extract position from state
            r1 = norm(pos - mp.Receiver1Position);
            r2 = norm(pos - mp.Receiver2Position);
            z = (r1 - r2) / mp.SpeedOfSignal;  % time difference
            
        case 'bearing'
            pos = state([1,3,5]) - mp.SensorPosition;
            localPos = mp.SensorRotation * pos;
            z = [atan2d(localPos(2), localPos(1));   % azimuth
                 atan2d(localPos(3), norm(localPos(1:2)))]; % elevation
    end
end
```

For non-additive noise: `z = measFcn(state, noise, mp)` — noise vector is injected.

## Custom Measurement Jacobian (for EKF/CKF)

If using EKF or CKF, provide the Jacobian:

```matlab
function J = myMeasJacFcn(state, mp)
    % J: M×N matrix where M = measurement dim, N = state dim
    % Compute analytically or use numerical differentiation:
    N = numel(state);
    M = numel(myMeasFcn(state, mp));
    J = zeros(M, N);
    dx = 1e-6;
    z0 = myMeasFcn(state, mp);
    for i = 1:N
        sp = state; sp(i) = sp(i) + dx;
        J(:,i) = (myMeasFcn(sp, mp) - z0) / dx;
    end
end
```

For UKF or particle filter, no Jacobian is needed.

## Custom Filter Initialization Function Template

```matlab
function filter = myFilterInit(detection)
    % Extract measurement and parameters
    meas = detection.Measurement;
    mp = detection.MeasurementParameters;
    noise = detection.MeasurementNoise;
    
    %% 1. Inverse measurement model: derive initial state from measurement
    switch mp.SensorType
        case 'tdoa'
            % TDOA gives a hyperboloid — cannot fully initialize position
            % Use a prior or range-parameterized approach
            state0 = [0; 0; 0; 0; 0; 0];  % poor init — needs fusion
            
        case 'bearing'
            % Angle-only: assume range, project to Cartesian
            assumedRange = 10000;  % m
            az = deg2rad(meas(1)); el = deg2rad(meas(2));
            localPos = assumedRange * [cosd(meas(2))*cosd(meas(1)); 
                                       cosd(meas(2))*sind(meas(1)); 
                                       sind(meas(2))];
            pos = mp.SensorRotation' * localPos + mp.SensorPosition;
            state0 = [pos(1); 0; pos(2); 0; pos(3); 0];
    end
    
    %% 2. Create filter with matching models
    filter = trackingEKF( ...
        StateTransitionFcn=@constvel, ...
        StateTransitionJacobianFcn=@constveljac, ...
        MeasurementFcn=@myMeasFcn, ...
        MeasurementJacobianFcn=@myMeasJacFcn, ...
        State=state0, ...
        StateCovariance=diag([1e6, 100, 1e6, 100, 1e6, 100]), ...
        ProcessNoise=diag([10, 10, 10]), ...
        HasAdditiveProcessNoise=false, ...
        HasAdditiveMeasurementNoise=true);
    
    %% 3. Set measurement noise from detection
    filter.MeasurementNoise = noise;
end
```

## Key Constraints

1. **Measurement function signature is fixed on the filter** — all sensors share it
2. **State vector must be consistent** — the motion model and measurement model must agree on state layout
3. **MeasurementParameters is the ONLY way to differentiate sensors** in multi-sensor setups
4. **Filter init must handle all SensorIndex values** if branching initialization by sensor

## Multi-Sensor Custom Setup

```matlab
function filter = myMultiSensorInit(detection)
    mp = detection.MeasurementParameters;
    meas = detection.Measurement;
    
    % Branch inverse model by sensor type
    switch mp.SensorType
        case 'radar'
            state0 = invertRadarMeas(meas, mp);
            cov0 = radarInitCovariance(meas, mp);
        case 'tdoa'
            state0 = invertTDOA(meas, mp);
            cov0 = tdoaInitCovariance();
    end
    
    % Same filter structure regardless of initializing sensor
    filter = trackingUKF( ...
        StateTransitionFcn=@constvel, ...
        MeasurementFcn=@myMeasFcn, ...
        State=state0, ...
        StateCovariance=cov0, ...
        ProcessNoise=diag([10, 10, 10]), ...
        HasAdditiveProcessNoise=false, ...
        HasAdditiveMeasurementNoise=true);
    filter.MeasurementNoise = detection.MeasurementNoise;
end
```

## Delivering to the User

Always deliver the custom measurement function, Jacobian (if EKF/CKF), and filter init as a matched set. Verify they work together:

```matlab
% Quick validation
det = objectDetection(0, testMeas, 'MeasurementParameters', mp, 'MeasurementNoise', testNoise);
filter = myFilterInit(det);
expectedMeas = myMeasFcn(filter.State, mp);
% expectedMeas should be close to testMeas
```

----

Copyright 2026 The MathWorks, Inc.
