# Phase 9: Iteration Algorithm and Phase Noise Calculation

Reference file for `modeling-pll-datasheet-validate.md` Phase 9.

---

## 9.2 Autonomous Iteration Algorithm (MANDATORY when targets specified)

When the user specifies phase noise or lock time targets, you MUST run this
iteration loop BEFORE simulation. Do NOT proceed with a design that fails
analytical checks.

```matlab
%% Phase 9 Iteration Loop
maxIter = 10;
converged = false;

for iter = 1:maxIter
    % 1. Compute analytical PN at all target offsets using ACTUAL filter TF
    %    (not 2nd-order approximation — use 3rd-order from filter design)
    if exist('C1','var') && exist('R2','var')
        % Actual 3rd-order loop filter impedance
        % Z(s) = (1 + s*R2*C2) / (s*(C1 + C2 + C3) * (1 + s*R2*C2*C1/(C1+C2+C3)) * ...)
        % Simplified: use pllOpenLoopPlot or numerical OL gain
    end

    % 2. Check ALL targets
    allPass = true;
    for k = 1:numel(targetOffsets)
        if pnAtOffset(k) > targetLimits(k)
            allPass = false;
            failOffset = targetOffsets(k);
            failMargin = pnAtOffset(k) - targetLimits(k);  % positive = how much we fail by
            break;
        end
    end

    if allPass
        converged = true;
        fprintf('  Iter %d: ALL TARGETS MET\n', iter);
        break;
    end

    % 3. Apply corrective action based on WHERE the failure is
    if failOffset <= Fc * 5  % In-band failure
        % Option A: Increase fRef (decrease N) — most effective
        if fRef < fVCO/20  % Can still increase
            fRef = fRef * 2;  N = fVCO/fRef;
            fprintf('  Iter %d: In-band fail by %.1fdB, increasing fRef to %dMHz (N=%d)\n', ...
                iter, failMargin, fRef/1e6, N);
        else
            % Option B: Increase Icp
            Icp = Icp * 1.5;
            fprintf('  Iter %d: Increasing Icp to %.1fmA\n', iter, Icp*1e3);
        end
    else  % Out-of-band failure (VCO noise dominated)
        % Option A: Narrow BW (more VCO filtering) — check lock time tradeoff
        Fc_new = Fc * 0.7;
        newLockEst = (4/Fc_new) * 3;
        if newLockEst <= lockTimeTarget
            Fc = Fc_new;
            fprintf('  Iter %d: VCO-dominated fail, narrowing BW to %.1fkHz\n', iter, Fc/1e3);
        else
            % Option B: Accept or flag — cannot narrow BW without breaking lock time
            fprintf('  Iter %d: Cannot narrow BW (lock time constraint). Need better VCO.\n', iter);
            break;
        end
    end

    % 4. Recompute filter and update model
    set_param(blk, 'Fc', num2str(Fc), 'Phi', num2str(Phi));
    if N ~= prevN
        set_param(blk, 'N', num2str(N), 'Nmin', num2str(Nmin));
        % Update testbench expected freq
    end
end

if ~converged
    fprintf('  WARNING: Could not meet all targets in %d iterations.\n', maxIter);
    fprintf('  Best achieved: @%s = %.1f dBc/Hz (target: %.1f)\n', ...);
end
```

---

## 9.3 Accurate Phase Noise Calculation (NOT 2nd-order approximation)

**IMPORTANT**: Do NOT use a simple 2nd-order H(s) approximation for phase noise.
Use the actual filter components from `thirdOrderPassiveFilterDesign` to compute
the real open-loop gain:

```matlab
function pn = accuratePhaseNoise(f, Icp, Kvco, N, C1, C2, C3, R2, R3, Foffset_vco, PN_vco)
    % Actual 3rd-order passive filter impedance
    s = 1j*2*pi*f;
    % Z(s) for 3rd order: series(R2,C2) || C1 || series(R3,C3)
    Z_R2C2 = R2 + 1./(s*C2);
    Z_C1 = 1./(s*C1);
    Z_R3C3 = R3 + 1./(s*C3);
    Z_LF = 1 ./ (1./Z_R2C2 + 1./Z_C1 + 1./Z_R3C3);

    % Open-loop gain: G(s) = (Icp/2pi) * Z_LF(s) * (2pi*Kvco/s) * (1/N)
    G = (Icp/(2*pi)) .* Z_LF .* (2*pi*Kvco./s) .* (1/N);

    % Closed-loop TFs
    H_cl = G ./ (1 + G);      % Reference noise TF
    H_err = 1 ./ (1 + G);     % VCO noise TF (error TF)

    % VCO contribution
    vcoPN = interp1(log10(Foffset_vco), PN_vco, log10(f), 'linear', 'extrap');

    % Reference/CP contribution
    PNSYNTH = -220;
    refFloor = PNSYNTH + 10*log10(fRef) + 20*log10(N);

    pn_vco = vcoPN + 20*log10(abs(H_err));
    pn_ref = refFloor + 20*log10(abs(H_cl));
    pn = 10*log10(10^(pn_vco/10) + 10^(pn_ref/10));
end
```

---

Copyright 2026 The MathWorks, Inc.
