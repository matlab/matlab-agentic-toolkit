% sweepAntennaLength.m — Sweep dipole antenna length and measure bandwidth
% Located at: /projects/antenna/scripts/sweepAntennaLength.m

freq = 2.4e9;
lengths = [0.04, 0.05, 0.06];
bw = zeros(size(lengths));

for i = 1:numel(lengths)
    d = design(dipole, freq);
    d.Length = lengths(i);
    d.Width = lengths(i) / 50;
    imp = impedance(d, linspace(2e9, 3e9, 101));
    vswr = (1 + abs((imp - 50)./(imp + 50))) ./ (1 - abs((imp - 50)./(imp + 50)));
    bwIdx = vswr <= 2;
    bw(i) = sum(bwIdx) / 101 * 1e9;
end

fprintf('Best bandwidth: %.2f MHz\n', max(bw)/1e6);

% Copyright 2026 The MathWorks, Inc.
