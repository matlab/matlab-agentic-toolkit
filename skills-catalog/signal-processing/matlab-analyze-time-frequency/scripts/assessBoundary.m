function assessBoundary(x, options)
%assessBoundary Visualize signal boundaries to guide CWT boundary choice.
%   assessBoundary(x) plots the full signal and zoomed views of the first
%   and last N samples to help determine the best Boundary property for
%   cwtfilterbank or cwt.
%
%   assessBoundary(x, NumSamples=100) specifies the number of samples to
%   inspect at each boundary.
%
%   The function prints a text recommendation based on endpoint analysis.

    arguments
        x (:, 1) double {mustBeNonempty, mustBeFinite}
        options.NumSamples (1, 1) double {mustBePositive, mustBeInteger} = 100
    end

    n = min(options.NumSamples, floor(length(x) / 4));
    sigLen = length(x);

    % Endpoint values and difference
    startVal = x(1);
    endVal = x(end);
    absRange = max(x) - min(x);
    endpointDiff = abs(endVal - startVal);
    relDiff = endpointDiff / absRange * 100;

    % Check if signal decays to zero at boundaries
    startNearZero = abs(startVal) < 0.05 * absRange;
    endNearZero = abs(endVal) < 0.05 * absRange;

    % Visualize
    figure
    tiledlayout(3, 1)

    nexttile
    plot(x)
    title("Full Signal")
    xlabel("Sample")
    ylabel("Amplitude")

    nexttile
    plot(1:n, x(1:n))
    title(sprintf("First %d Samples (start value = %.4g)", n, startVal))
    xlabel("Sample")
    ylabel("Amplitude")

    nexttile
    plot((sigLen - n + 1):sigLen, x(end - n + 1:end))
    title(sprintf("Last %d Samples (end value = %.4g)", n, endVal))
    xlabel("Sample")
    ylabel("Amplitude")

    % Print analysis
    fprintf("\n=== Boundary Assessment ===\n")
    fprintf("Signal length: %d samples\n", sigLen)
    fprintf("Start value: %.4g\n", startVal)
    fprintf("End value: %.4g\n", endVal)
    fprintf("Endpoint difference: %.4g (%.1f%% of signal range)\n", ...
        endpointDiff, relDiff)
    fprintf("Signal near zero at start: %s\n", string(startNearZero))
    fprintf("Signal near zero at end: %s\n", string(endNearZero))

    fprintf("\n--- Recommendation ---\n")
    if relDiff < 5
        fprintf("Endpoints are similar (%.1f%% difference).\n", relDiff)
        fprintf("PERIODIC boundary is suitable and offers best performance.\n")
        if sigLen > 100000
            fprintf("Signal is large (%d samples) — periodic avoids ~2x FFT cost.\n", sigLen)
        end
    elseif startNearZero && endNearZero
        fprintf("Signal decays to near-zero at both boundaries.\n")
        fprintf("ZEROPAD boundary is appropriate.\n")
    else
        fprintf("Endpoints differ significantly (%.1f%% of range).\n", relDiff)
        fprintf("REFLECTION boundary (default) is recommended.\n")
        fprintf("Inspect the zoomed plots for frequency discontinuities at edges.\n")
        fprintf("If you see abrupt frequency changes at boundaries, consider ZEROPAD.\n")
    end

    if sigLen > 100000
        fprintf("\nNote: Signal is large (%d samples). If periodic is valid,\n", sigLen)
        fprintf("it will be approximately 2x faster than reflection or zeropad.\n")
    end
    fprintf("===========================\n\n")

end
% Copyright 2026 The MathWorks, Inc.
