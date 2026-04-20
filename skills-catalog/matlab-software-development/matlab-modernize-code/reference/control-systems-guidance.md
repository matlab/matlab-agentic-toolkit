
# Control Systems Modernization

## Quick Reference: Function Mappings

| Deprecated/Legacy | Recommended Replacement | Since | Status |
|-------------------|------------------------|-------|--------|
| stepDataOptions | Chart object properties | R2019a | Not recommended |
| setoptions (plot) | Dot notation property access | R2019a | Not recommended |
| Old option syntax | Name-value arguments | Various | Not recommended |

## Plot Options Configuration

### setoptions → Dot Notation Property Access

**Status:** Not recommended. Use dot notation to set chart object properties directly.

**Old Pattern (Not Recommended):**
```matlab
% Legacy approach using setoptions
h = bodeplot(sys);
opts = getoptions(h);
opts.PhaseUnits = 'rad';
setoptions(h, opts);

% Or the combined form
setoptions(h, 'PhaseUnits', 'rad', 'Grid', 'on');
```

**Modern Pattern (Use This):**
```matlab
% Modern approach using dot notation
h = bodeplot(sys);
h.PhaseUnits = 'rad';
h.Grid = 'on';

% Or set properties at creation
h = bodeplot(sys);
h.Responses.LineStyle = '--';
h.AxesGridLayout.Grid = 'on';
```

**Why Modern is Better:**
- Cleaner, more intuitive syntax
- Consistent with MATLAB graphics conventions
- Better IDE autocomplete support
- More discoverable properties

---

### stepDataOptions → Chart Object Properties

**Status:** Not recommended. Access step response chart properties directly.

**Old Pattern (Not Recommended):**
```matlab
% Legacy approach
opts = stepDataOptions;
opts.StepAmplitude = 2;
step(sys, opts);
```

**Modern Pattern (Use This):**
```matlab
% Modern approach - use step plot object
h = stepplot(sys);
h.Input.Amplitude = 2;

% Or use step with direct output handling
[y, t] = step(sys);
y_scaled = 2 * y;  % Scale as needed
plot(t, y_scaled);
```

---

## Linear Analysis Plot Modernization

### Creating and Customizing Plots

**Modern Approach for All Linear Analysis Plots:**

```matlab
% Bode plot with modern customization
sys = tf([1 2], [1 3 2]);
h = bodeplot(sys);
h.PhaseUnits = 'deg';
h.FrequencyUnits = 'Hz';
h.Grid = 'on';

% Step response with customization
h = stepplot(sys);
h.SettlingTimeThreshold = 0.02;  % 2% settling time
h.Characteristics.SettlingTime.Visible = 'on';
h.Characteristics.PeakResponse.Visible = 'on';

% Nyquist plot
h = nyquistplot(sys);
h.Responses.LineWidth = 2;

% Root locus
h = rlocusplot(sys);
h.DesignPointMarkerColor = 'red';
```

---

## LTI System Creation Best Practices

### Modern System Creation

**Recommended Patterns:**

```matlab
% Transfer function - use standard tf
sys = tf([1 2], [1 3 2]);
sys = tf(num, den, Ts);  % Discrete-time

% State-space - use standard ss
sys = ss(A, B, C, D);
sys = ss(A, B, C, D, Ts);  % Discrete-time

% Zero-pole-gain
sys = zpk(z, p, k);

% Named systems for clarity
sys = tf([1 2], [1 3 2], 'InputName', 'voltage', 'OutputName', 'position');

% Continuous to discrete conversion
sys_d = c2d(sys_c, Ts, 'zoh');  % Zero-order hold
sys_d = c2d(sys_c, Ts, 'tustin');  % Bilinear transform
```

---

## Analysis Functions

### Modern Analysis Patterns

```matlab
% Stability analysis
poles = pole(sys);
zeros = zero(sys);
[Gm, Pm, Wcg, Wcp] = margin(sys);

% Time response - get data for custom plotting
[y, t] = step(sys);
[y, t] = impulse(sys);
[y, t, x] = lsim(sys, u, t);

% Frequency response data
[mag, phase, w] = bode(sys);
[re, im, w] = nyquist(sys);

% Modern stepinfo with options
S = stepinfo(sys, 'SettlingTimeThreshold', 0.02);
```

---

## Controller Design

### Modern PID Tuning

**Recommended Approach:**

```matlab
% Automatic PID tuning (R2010a+)
[C, info] = pidtune(sys, 'PID');
[C, info] = pidtune(sys, 'PIDF');  % With derivative filter

% PID with specific characteristics
opts = pidtuneOptions('CrossoverFrequency', 10, 'PhaseMargin', 60);
[C, info] = pidtune(sys, 'PID', opts);

% Modern PID object
C = pid(Kp, Ki, Kd, Tf);  % Continuous
C = pid(Kp, Ki, Kd, Tf, Ts);  % Discrete
```

### Control System Designer (Replaces sisotool)

**Note:** While `sisotool` is still available, Control System Designer provides a more modern interface.

```matlab
% Open Control System Designer
controlSystemDesigner(sys)

% Or with initial compensator
controlSystemDesigner('bode', sys, C)
```

---

## Model Interconnection

### Modern Interconnection Patterns

```matlab
% Series connection
sys_series = sys1 * sys2;
sys_series = series(sys1, sys2);

% Parallel connection
sys_parallel = sys1 + sys2;
sys_parallel = parallel(sys1, sys2);

% Feedback connection
sys_cl = feedback(sys, H);
sys_cl = feedback(G*C, H);  % Forward path G*C, feedback H

% Named signal connections (modern approach)
sys_cl = connect(sys1, sys2, sys3, 'input_name', 'output_name');
```

---

## System Identification Integration

### Working with Identified Models

```matlab
% Convert identified model to standard LTI
sys_tf = tf(identified_model);
sys_ss = ss(identified_model);

% Get uncertainty information
[sys_nom, sys_unc] = getSystemConfidenceRegion(identified_model);
```

---

## Robust Control (Modern Patterns)

```matlab
% Uncertain systems (Robust Control Toolbox)
p = ureal('p', 10, 'Percentage', 20);
sys = tf(1, [1 p]);

% H-infinity synthesis
[K, CL, gamma] = hinfsyn(P, nmeas, ncont);

% Mu-synthesis
[K, CL, bnd, dkinfo] = dksyn(P, nmeas, ncont);
```

---

## Version Compatibility Notes

- **R2019a+:** Dot notation preferred for plot object properties
- **R2016a+:** `pidtune` significantly enhanced
- **R2010a:** Modern PID tuning functions introduced

---

## Summary: Patterns to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `setoptions(h, ...)` | `h.Property = value` | More intuitive, modern syntax |
| `stepDataOptions` | Direct chart properties | Deprecated interface |
| `getoptions`/`setoptions` pair | Dot notation | Simpler, cleaner code |


----

Copyright 2026 The MathWorks, Inc.

----

