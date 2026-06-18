# Circle Computations for Smith Chart Analysis

Stability circles, noise circles, and gain circles are constant-value contours plotted on the Smith chart (Gamma plane). RF Toolbox has no dedicated circle-plotting function — compute center and radius analytically, then plot parametrically.

## Stability Circles

Stability circles show the boundary between stable and unstable source/load impedances in the Gamma plane.

### Source Stability Circle (plotted in Gamma_S plane)

```matlab
% Extract S-parameters at the frequency of interest
sData = s.Parameters;  % 2x2xN
idx = find(s.Frequencies >= targetFreq, 1);
S11 = sData(1,1,idx); S12 = sData(1,2,idx);
S21 = sData(2,1,idx); S22 = sData(2,2,idx);
delta = S11*S22 - S12*S21;

% Source stability circle center and radius
C_S = conj(S11 - delta*conj(S22)) / (abs(S11)^2 - abs(delta)^2);
r_S = abs(S12*S21) / abs(abs(S11)^2 - abs(delta)^2);
```

### Load Stability Circle (plotted in Gamma_L plane)

```matlab
% Load stability circle center and radius
C_L = conj(S22 - delta*conj(S11)) / (abs(S22)^2 - abs(delta)^2);
r_L = abs(S12*S21) / abs(abs(S22)^2 - abs(delta)^2);
```

### Determining the Stable Region

The stable region is either inside or outside the circle. Test the origin (Gamma=0, i.e., Z0 termination):

```matlab
% If origin is in the stable region, determine inside/outside
[k, b1] = stabilityk(s);
% For source circle: if b1 > 0 at this frequency, origin is in stable region
% If |C_S| - r_S > 1, circle is entirely outside Smith chart (all passive terminations stable)
% If |C_S| + r_S < 1, circle is entirely inside Smith chart

originInCircle_S = abs(C_S) < r_S;  % Is origin inside the source circle?
% If K > 1 (unconditionally stable): stable region contains origin
% If K < 1: check if origin distance to center < radius
if k(idx) > 1
    stableIsOutside_S = originInCircle_S;  % If origin inside circle and device is stable, stable=inside
else
    % For conditionally stable: stable region is the side containing Gamma=0
    stableIsOutside_S = ~originInCircle_S;
end
```

### Plotting on Smith Chart

Call `smithplot()` with no arguments to create an empty Smith chart with grid lines, then `hold on` + `plot` to overlay circles:

```matlab
% Generate circle points
theta = linspace(0, 2*pi, 201);
circlePoints_S = C_S + r_S * exp(1j*theta);
circlePoints_L = C_L + r_L * exp(1j*theta);

figure;
tiledlayout(1, 2, 'Padding', 'compact');

% Source stability circle
nexttile;
smithplot();  % Empty Smith chart with grid
hold on;
plot(real(circlePoints_S), imag(circlePoints_S), 'r-', 'LineWidth', 2);
plot(real(C_S), imag(C_S), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
title('Source Stability Circle (\Gamma_S plane)');

% Load stability circle
nexttile;
smithplot();  % Empty Smith chart with grid
hold on;
plot(real(circlePoints_L), imag(circlePoints_L), 'b-', 'LineWidth', 2);
plot(real(C_L), imag(C_L), 'b+', 'MarkerSize', 12, 'LineWidth', 2);
title('Load Stability Circle (\Gamma_L plane)');
```

**Key pattern:** `smithplot()` creates the chart grid. Then `hold on` + `plot(real(pts), imag(pts))` draws any curve on the Gamma plane.

## Noise Circles

Constant noise figure contours in the source reflection coefficient (Gamma_S) plane.

### Noise Circle Center and Radius

```matlab
% Noise parameters (from noiseParameters object or datasheet)
% Fmin_linear: minimum noise figure (linear)
% GammaOpt: optimum source reflection coefficient (complex)
% Rn: equivalent noise resistance (normalized to Z0)
% F_target: desired noise figure contour (linear)

% Noise parameter N_i for the desired contour
N_i = (F_target - Fmin_linear) * abs(1 + GammaOpt)^2 / (4 * Rn);

% Noise circle center and radius
C_NF = GammaOpt / (1 + N_i);
r_NF = sqrt(N_i^2 + N_i*(1 - abs(GammaOpt)^2)) / (1 + N_i);
```

### Multiple Noise Circles Pattern

```matlab
% Plot noise circles for several NF values
NF_targets_dB = [1.0, 1.5, 2.0, 3.0];  % dB values for contours
NF_targets_lin = 10.^(NF_targets_dB/10);  % Convert to linear

% Get noise parameters at design frequency
Fmin_lin = 10^(Fmin_dB/10);  % Convert Fmin from dB to linear

figure;
theta = linspace(0, 2*pi, 201);
smithplot();  % Empty Smith chart with grid
hold on;

colors = {'r', 'g', 'b', 'm'};
for k = 1:numel(NF_targets_dB)
    F_t = NF_targets_lin(k);
    N_i = (F_t - Fmin_lin) * abs(1 + GammaOpt)^2 / (4 * Rn_norm);
    C_nf = GammaOpt / (1 + N_i);
    r_nf = sqrt(N_i^2 + N_i*(1 - abs(GammaOpt)^2)) / (1 + N_i);

    circPts = C_nf + r_nf * exp(1j*theta);
    plot(real(circPts), imag(circPts), colors{k}, 'LineWidth', 1.5, ...
         'DisplayName', sprintf('NF = %.1f dB', NF_targets_dB(k)));
end

% Mark optimum point
plot(real(GammaOpt), imag(GammaOpt), 'k*', 'MarkerSize', 12, ...
     'LineWidth', 2, 'DisplayName', '\Gamma_{opt}');
legend('Location', 'best');
title('Constant Noise Figure Circles');
xlabel('Re(\Gamma_S)'); ylabel('Im(\Gamma_S)');
```

## Available Gain Circles

Constant available gain contours in the source (Gamma_S) plane.

### Available Gain Circle Center and Radius

```matlab
% ga_target: desired available gain (linear, not dB)
% Compute normalized gain parameter
[k_val, ~, ~, delta_val] = stabilityk(sInterp);  % at single frequency
S11 = sData(1,1,1); S12 = sData(1,2,1);
S21 = sData(2,1,1); S22 = sData(2,2,1);
delta = S11*S22 - S12*S21;

% Normalized gain
ga_norm = ga_target / abs(S21)^2;

% Available gain circle center and radius
C_Ga = ga_norm * conj(S11 - delta*conj(S22)) / ...
       (1 + ga_norm*(abs(S11)^2 - abs(delta)^2));
r_Ga = sqrt(1 - 2*k_val*abs(S12*S21)*ga_norm + (abs(S12*S21)*ga_norm)^2) / ...
       abs(1 + ga_norm*(abs(S11)^2 - abs(delta)^2));
```

### Combined Gain + Noise Circle Pattern

```matlab
% Plot both gain and noise circles on same chart for LNA tradeoff
figure;
theta = linspace(0, 2*pi, 201);
smithplot();  % Empty Smith chart with grid
hold on;

% Noise circles (dashed red)
for k = 1:numel(NF_targets_dB)
    % ... compute C_nf, r_nf as above ...
    circPts = C_nf + r_nf * exp(1j*theta);
    plot(real(circPts), imag(circPts), 'r--', 'LineWidth', 1.2);
end

% Gain circles (solid blue)
Ga_targets_dB = [8, 10, 12];  % dB
Ga_targets_lin = 10.^(Ga_targets_dB/10);
for k = 1:numel(Ga_targets_dB)
    % ... compute C_Ga, r_Ga as above ...
    circPts = C_Ga + r_Ga * exp(1j*theta);
    plot(real(circPts), imag(circPts), 'b-', 'LineWidth', 1.2);
end

% Mark key points
plot(real(GammaOpt), imag(GammaOpt), 'r*', 'MarkerSize', 12, ...
     'DisplayName', '\Gamma_{opt} (min NF)');
gms_val = gammams(sInterp);
plot(real(gms_val), imag(gms_val), 'b*', 'MarkerSize', 12, ...
     'DisplayName', '\Gamma_{ms} (max gain)');
legend('Location', 'best');
title('LNA Design Tradeoff: Gain vs Noise Circles');
xlabel('Re(\Gamma_S)'); ylabel('Im(\Gamma_S)');
```

## Key Points

- All circles are in the **Gamma plane** (complex reflection coefficient, |Gamma| <= 1 for passive)
- **Smith chart background:** call `smithplot()` with no arguments to create an empty chart with grid, then `hold on` + `plot(real(pts), imag(pts))` to overlay circles
- Circle points: `C + r*exp(1j*linspace(0, 2*pi, 201))` where `C` is complex center and `r` is radius
- For noise circles, `Rn` must be **normalized to Z0** (divide by Z0 if in ohms): `Rn_norm = Rn_ohms / Z0`
- The `GammaOpt` point (minimum NF) and `gammams` point (maximum gain) are typically different — the gap between them represents the fundamental noise-gain tradeoff

----

Copyright 2026 The MathWorks, Inc.

----
