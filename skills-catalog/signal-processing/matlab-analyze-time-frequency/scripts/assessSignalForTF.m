function report = assessSignalForTF(x, fs)
%assessSignalForTF Analyze signal properties relevant to time-frequency method selection.
%   report = assessSignalForTF(x, fs) returns a struct with signal characteristics
%   that inform choice of TF analysis method. The agent uses these properties
%   alongside user-stated goals to recommend an approach.
%
%   Inputs:
%       x  - Signal vector (real or complex)
%       fs - Sampling frequency (Hz)
%
%   Output:
%       report - Struct with fields described below

arguments
    x (:,1) {mustBeNumeric, mustBeNonempty}
    fs (1,1) {mustBePositive}
end

N = length(x);

% Basic properties
report.signalLength = N;
report.samplingFrequency = fs;
report.durationSeconds = N / fs;
report.isComplex = ~isreal(x);
report.isDoublePrecision = isa(x, 'double');
report.nyquistHz = fs / 2;

% Spectral profile via periodogram
[pxx, f] = periodogram(x, [], [], fs);
pxxNorm = pxx / sum(pxx);
cumEnergy = cumsum(pxxNorm);

% Occupied bandwidth (5% to 95% energy)
fLow = f(find(cumEnergy >= 0.05, 1, 'first'));
fHigh = f(find(cumEnergy >= 0.95, 1, 'first'));
report.occupiedBandHz = [fLow, fHigh];
report.bandwidthHz = fHigh - fLow;
report.fractionalBandwidth = report.bandwidthHz / ((fLow + fHigh) / 2);

% Dominant frequency (spectral peak)
[~, iPeak] = max(pxx);
report.dominantFreqHz = f(iPeak);

% Number of spectral peaks (potential components)
% Use Welch's method for smoother spectral estimate before peak detection
segLen = min(N, 256);
[pxxSmooth, fSmooth] = pwelch(x, segLen, round(segLen*0.75), segLen, fs);
[~, locs] = findpeaks(10*log10(pxxSmooth + eps), fSmooth, ...
    MinPeakProminence=10, MinPeakDistance=fs/segLen*2);
report.numSpectralPeaks = numel(locs);
report.peakFrequenciesHz = locs(:)';

% Stationarity indicator: split into 8 segments, compare total RMS
nSeg = 8;
segLen = floor(N / nSeg);
segRMS = zeros(1, nSeg);
for k = 1:nSeg
    idx = (k-1)*segLen + (1:segLen);
    segRMS(k) = rms(x(idx));
end
report.powerVariationDb = 20*log10(max(segRMS) / (min(segRMS) + eps));
report.likelyNonstationary = report.powerVariationDb > 4;

% DC content
report.signalMean = mean(x);
report.hasDC = abs(mean(x)) > 0.01 * std(x);

% Length suitability for various methods
report.cwtMinFreqHz = fs / N * 2;
report.stftBinsAt256 = 129;
report.stftFreqResolutionAt256 = fs / 256;
report.modwtMaxLevel = floor(log2(N));

% Practical recommendations based on signal properties
report.recommendations = generateRecommendations(report);

end

function recs = generateRecommendations(r)
    recs = {};

    % Length-based
    if r.signalLength < 128
        recs{end+1} = "Signal is very short — CWT and STFT will have poor resolution. Consider zero-padding or using instfreq with Hilbert method.";
    end

    % Bandwidth-based
    if r.fractionalBandwidth < 0.5
        recs{end+1} = "Narrowband signal — CWT (constant-Q) will give good frequency resolution. STFT also adequate.";
    elseif r.fractionalBandwidth > 2
        recs{end+1} = "Wideband signal spanning multiple octaves — CWT's multi-resolution property is advantageous.";
    end

    % Component count
    if r.numSpectralPeaks > 4
        recs{end+1} = sprintf("Detected %d spectral peaks — consider mode decomposition (emd/vmd) or synchrosqueezing for component separation.", r.numSpectralPeaks);
    elseif r.numSpectralPeaks >= 2
        recs{end+1} = sprintf("Detected %d spectral peaks — synchrosqueezing (fsst/wsst) with ridge extraction can isolate each.", r.numSpectralPeaks);
    end

    % Closely-spaced peaks
    if r.numSpectralPeaks >= 2
        peakSpacings = diff(r.peakFrequenciesHz);
        minSpacing = min(peakSpacings);
        if minSpacing < r.dominantFreqHz * 0.1
            recs{end+1} = sprintf("Closely-spaced peaks (min spacing %.1f Hz) — STFT or modwptdetails preferred over CWT for separation.", minSpacing);
        end
    end

    % Nonstationarity
    if r.likelyNonstationary
        recs{end+1} = sprintf("Signal appears nonstationary (%.1f dB power variation across segments) — time-frequency analysis is appropriate.", r.powerVariationDb);
    else
        recs{end+1} = "Signal appears relatively stationary — a global spectrum (periodogram/pwelch) may suffice unless time-localization is needed.";
    end

    % DC
    if r.hasDC
        recs{end+1} = "Signal has significant DC offset — note that wsst subtracts the mean (iwsst won't restore it). Add mean(x) back after iwsst if needed.";
    end

    % Complex
    if r.isComplex
        recs{end+1} = "Complex-valued signal — cwt supports this (3D output: analytic + anti-analytic). wcoherence, wsst, and emd require real input.";
    end

    % Precision
    if ~r.isDoublePrecision
        recs{end+1} = "Signal is single-precision — synchrosqueezing (fsst/wsst) may have off-by-one bin reassignment issues. Cast to double for reproducible results.";
    end

    recs = string(recs(:));
end

% Copyright 2026 The MathWorks, Inc.
