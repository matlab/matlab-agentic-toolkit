function illustrateTransientLocalization()
%illustrateTransientLocalization Compare wavelet time localization.
%   illustrateTransientLocalization() creates an impulse signal and plots
%   finest-scale CWT coefficients for Morse (low TB), amor, and bump
%   wavelets to show the time localization trade-off.

Fs = 100;
N = 1000;
t = (0:N-1) / Fs;
signal = zeros(1, N);
signal(500) = 1;

[cfsMorse, ~] = cwt(signal, "Morse", Fs, TimeBandwidth=15);
finestMorse = abs(cfsMorse(1, :));

[cfsAmor, ~] = cwt(signal, "amor", Fs);
finestAmor = abs(cfsAmor(1, :));

[cfsBump, ~] = cwt(signal, "bump", Fs);
finestBump = abs(cfsBump(1, :));

finestMorse = finestMorse / max(finestMorse);
finestAmor = finestAmor / max(finestAmor);
finestBump = finestBump / max(finestBump);

figure
tiledlayout(3, 1, TileSpacing="compact", Padding="compact")

nexttile
plot(t, finestMorse, "b", LineWidth=1.2)
ylabel("|CWT|")
title("Morse, TimeBandwidth = 15 (Best Time Localization)")
xlim([3 7])
grid on

nexttile
plot(t, finestAmor, "r", LineWidth=1.2)
ylabel("|CWT|")
title("Analytic Morlet / amor (Good Time Localization)")
xlim([3 7])
grid on

nexttile
plot(t, finestBump, Color=[0.5 0 0.8], LineWidth=1.2)
xlabel("Time (s)")
ylabel("|CWT|")
title("Bump (Worst Time Localization - Compact in Frequency)")
xlim([3 7])
grid on
end

% Copyright 2026 The MathWorks, Inc.
