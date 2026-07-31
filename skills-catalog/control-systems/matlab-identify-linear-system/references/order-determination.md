# Order Determination

## 5.1 Estimate Input Delay (with caution)

```matlab
nk = delayest(ze);
fprintf('Estimated delay: %d samples (%.3f s)\n', nk, nk*ze.Ts);
```

**Warnings:**
* Delay estimation is fundamentally unreliable for noisy data
* `delayest` does not work well for MIMO datasets
* If physical knowledge of delay exists, prefer it
* Consider non-parametric impulse response estimation using `impulseest` and noting the delay as the number of samples for which the response is statistically zero
* When using `impulseest` for delay assessment, use `RegularizationKernel="none"`. Regularization kernels (TC, SE, etc.) smooth the impulse response and can shift or obscure the onset, giving a biased delay estimate. Regularization is appropriate for system bandwidth/order assessment but not for delay detection.
* Always include a model with zero or single-sample delay in the search to hedge against incorrect delay estimates
* `idpack.auto.arxstruc` often provides a better combined delay + order determination

## 5.2 Determine Model Order

### Method A — idpack.auto tools (try first)

The most effective order-determination tools are in `toolbox/ident/ident/+idpack/+auto`. In particular:

* `idpack.auto.ssmSelectBasis` — for state-space order selection
* `idpack.auto.arxstruc` — for combined ARX order and delay determination

### Method B — ARX structure search (polynomial models)

```matlab
maxNA = min(floor(size(ze.y,1)/20), 15);
maxNB = maxNA;
NN = struc(1:maxNA, 1:maxNB, max(nk-1,1):nk+2);
V = arxstruc(ze, zv, NN);
nn = selstruc(V, 'aic');  % [na nb nk]
fprintf('ARX orders: na=%d, nb=%d, nk=%d\n', nn(1), nn(2), nn(3));
```

### Method C — Subspace order (state-space)

```matlab
maxOrder = min(floor(size(ze.y,1)/20), 20);
opt = n4sidOptions('Display', 'off', InteractiveOrderSelection=false);
sysInit = n4sid(ze, 1:maxOrder, opt);
n = order(sysInit);
fprintf('State-space order: n=%d\n', n);
```

### Method D — Iterative complexity (transfer functions)

```matlab
fits = zeros(8,1);
for np = 1:8
    nz = max(0, np-1);
    sys = tfest(ze, np, nz, nk*ze.Ts);
    [~, f] = compare(zv, sys);
    fits(np) = f;
    fprintf('np=%d, nz=%d: fit=%.1f%%\n', np, nz, f);
end
[~, best_np] = max(fits);
```

### Method E — Process model ladder

```matlab
structs = {"P1D","P2D","P2UD","P2ZD"};
bestFit = -Inf;
for k = 1:numel(structs)
    sys = procest(ze, structs{k});
    [~, f] = compare(zv, sys);
    fprintf('%s: fit=%.1f%%\n', structs{k}, f);
    if f > bestFit, bestFit = f; bestStruct = structs{k}; end
end
```

### Method F — Frequency-domain path

```matlab
% Convert to frequency domain, then use AAA initialization
opt = ssestOptions('Display', 'off', 'InitializeMethod', 'AAA', InteractiveOrderSelection=false);
sysInit = ssest(fft(ze), 1:maxOrder, opt);
n = order(sysInit);
```

A closely related variant: use `etfe` or `spa` to compute empirical frequency response (idfrd), then use `ssest` with `InitializeMethod='lsrf'` or `'AAA'` on the idfrd for order determination.

## Order Rules of Thumb

* Max useful order: `n_max ~ min(N/20, 30)` where N = data length
* MIMO state-space: start with `n = max(ny, nu) * 2` up to `5`
* If ARX(10) and ssest(4) give similar fits, prefer ssest(4)
* Stop increasing order when improvement < 2% per additional parameter

----

Copyright 2026 The MathWorks, Inc.

----
