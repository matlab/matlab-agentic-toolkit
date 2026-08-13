function assessSpectralEnergy(x, Fs, options)
%assessSpectralEnergy Compute PSD to suggest FrequencyLimits for CWT.
%   assessSpectralEnergy(x, Fs) analyzes the power spectral density of the
%   signal x sampled at Fs Hz and recommends FrequencyLimits to reduce CWT
%   computation by focusing on the energy-containing band.
%
%   assessSpectralEnergy(x, Fs, EnergyThreshold=0.99) specifies the
%   fraction of total energy to capture (default 99%).

    arguments
        x (:, 1) double {mustBeNonempty, mustBeFinite}
        Fs (1, 1) double {mustBePositive}
        options.EnergyThreshold (1, 1) double ...
            {mustBeGreaterThan(options.EnergyThreshold, 0), ...
            mustBeLessThan(options.EnergyThreshold, 1)} = 0.99
    end

    % Compute PSD using Welch's method
    [pxx, f] = pwelch(x, [], [], [], Fs);

    % Cumulative energy distribution
    totalEnergy = trapz(f, pxx);
    cumEnergy = cumtrapz(f, pxx) / totalEnergy;

    % Find band containing specified energy fraction
    threshold = options.EnergyThreshold;
    lowerIdx = find(cumEnergy >= (1 - threshold) / 2, 1, "first");
    upperIdx = find(cumEnergy >= (1 + threshold) / 2, 1, "first");

    fLow = f(lowerIdx);
    fHigh = f(upperIdx);
    fNyquist = Fs / 2;

    % Check energy near boundaries
    nearNyquist = cumEnergy(end) - cumEnergy(round(0.9 * length(f))) > 0.05;
    nearDC = cumEnergy(round(0.1 * length(f))) > 0.05;

    % Visualize
    figure
    tiledlayout(2, 1)

    nexttile
    plot(f, 10*log10(pxx))
    xlabel("Frequency (Hz)")
    ylabel("PSD (dB/Hz)")
    title("Power Spectral Density")
    xline(fLow, "r--", sprintf("%.2f Hz", fLow), LineWidth=1.2)
    xline(fHigh, "r--", sprintf("%.2f Hz", fHigh), LineWidth=1.2)

    nexttile
    plot(f, cumEnergy * 100)
    xlabel("Frequency (Hz)")
    ylabel("Cumulative Energy (%)")
    title(sprintf("Cumulative Energy (%.0f%% band shown)", threshold * 100))
    yline(threshold * 100, "k--")
    xline(fLow, "r--", LineWidth=1.2)
    xline(fHigh, "r--", LineWidth=1.2)

    % Print analysis
    fprintf("\n=== Spectral Energy Assessment ===\n")
    fprintf("Signal length: %d samples\n", length(x))
    fprintf("Sampling frequency: %.2f Hz\n", Fs)
    fprintf("Nyquist frequency: %.2f Hz\n", fNyquist)
    fprintf("\nEnergy band (%.0f%%): %.4f Hz to %.4f Hz\n", ...
        threshold * 100, fLow, fHigh)
    fprintf("Significant energy near Nyquist (>Fs*0.9): %s\n", string(nearNyquist))
    fprintf("Significant energy near DC (<Fs*0.1): %s\n", string(nearDC))

    fprintf("\n--- Recommendation ---\n")
    if fHigh < 0.8 * fNyquist && fLow > 0.01 * Fs
        fprintf("Energy is concentrated in [%.4f, %.4f] Hz.\n", fLow, fHigh)
        fprintf("Suggested FrequencyLimits: [%.4f %.4f]\n", fLow, fHigh)
        fprintf("This will significantly reduce CWT computation.\n")
    elseif nearNyquist
        fprintf("Significant energy near Nyquist.\n")
        fprintf("Consider setting upper FrequencyLimit to Fs/2 = %.2f Hz.\n", fNyquist)
        if fLow > 0.01 * Fs
            fprintf("Lower limit can be raised to %.4f Hz.\n", fLow)
            fprintf("Suggested FrequencyLimits: [%.4f %.4f]\n", fLow, fNyquist)
        end
    else
        fprintf("Energy is broadly distributed.\n")
        fprintf("Default FrequencyLimits are appropriate.\n")
        fprintf("Or use [0 %.2f] for maximum coverage.\n", fNyquist)
    end
    fprintf("==================================\n\n")

end
% Copyright 2026 The MathWorks, Inc.
