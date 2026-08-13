function illustrateBoundary()
%illustrateBoundary Show scalograms with three CWT boundary methods.
%   illustrateBoundary() loads boundaryExDisjointSine.mat and plots
%   periodic, reflection, and zeropad boundary scalograms side-by-side.

load("boundaryExDisjointSine.mat", "sig", "Fs", "tm");
[wtr,f] = cwt(sig,Fs,Boundary="reflection");
wtp = cwt(sig,Fs,Boundary="periodic");
wtz = cwt(sig,Fs,Boundary="zeropad");
tl = tiledlayout(3,1);
nexttile
pcolor(tm,f,abs(wtp),EdgeColor="none")
xticks([])
yscale("log")
ylabel("Frequency (Hz)")
title("Periodic")
nexttile
pcolor(tm,f,abs(wtr),EdgeColor="none")
xticks([])
yscale("log")
ylabel("Frequency (Hz)")
title("Reflection")
nexttile
pcolor(tm,f,abs(wtz),EdgeColor="none")
yscale("log")
title("Zero Padding")
xlabel("Time (s)")
ylabel("Frequency (Hz)")
title(tl,"Scalograms with Different Boundary Extensions")
end

% Copyright 2026 The MathWorks, Inc.
