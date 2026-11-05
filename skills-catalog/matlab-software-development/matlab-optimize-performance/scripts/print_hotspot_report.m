function print_hotspot_report(stacks, maxEntries)
%PRINT_HOTSPOT_REPORT Print sampling profiler results in perf-report style with call stacks.
%
%   print_hotspot_report(stacks)         — show all entries
%   print_hotspot_report(stacks, 15)     — show top 15 entries

if nargin < 2, maxEntries = Inf; end

snapshots = stacks.Snapshots;
totalSnapshots = double(numel(snapshots));
if totalSnapshots == 0
    fprintf('  No samples collected.\n');
    return;
end

% --- Pass 1: Count self (leaf) samples and collect call chains per leaf ---
leafMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
chainMaps = containers.Map('KeyType', 'char', 'ValueType', 'any');

for s = 1:numel(snapshots)
    snap = snapshots(s);
    nf = min(double(snap.Depth), numel(snap.Frames));   % honor Frames(1:Depth) contract
    if nf == 0, continue; end

    % Leaf location key (Frames(Depth), the innermost frame)
    fr = snap.Frames(nf);
    [~, fn, ~] = fileparts(fr.FileName);
    leafKey = sprintf('%s:%d', fn, fr.StartLine);
    if leafMap.isKey(leafKey), leafMap(leafKey) = leafMap(leafKey)+1; else, leafMap(leafKey) = 1; end

    % Build collapsed caller chain (fold consecutive duplicates for recursion)
    % Read frames bottom-to-top (root first, leaf last)
    parts = cell(1, nf);
    for f = 1:nf
        [~, cfn, ~] = fileparts(snap.Frames(f).FileName);
        parts{f} = sprintf('%s:%d', cfn, snap.Frames(f).StartLine);
    end
    % Collapse consecutive duplicates
    collapsed = {parts{end}}; % start with leaf
    for f = nf-1:-1:1
        if ~strcmp(parts{f}, collapsed{end})
            collapsed{end+1} = parts{f}; %#ok<AGROW>
        end
    end
    chainStr = strjoin(collapsed, ';');

    if chainMaps.isKey(leafKey)
        cmap = chainMaps(leafKey);
    else
        cmap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
    end
    if cmap.isKey(chainStr), cmap(chainStr) = cmap(chainStr)+1; else, cmap(chainStr) = 1; end
    chainMaps(leafKey) = cmap;
end

% Sort by count descending
keys = leafMap.keys;
counts = double(cellfun(@(k) leafMap(k), keys));
[counts, idx] = sort(counts, 'descend');
keys = keys(idx);
nShow = min(maxEntries, numel(keys));

% --- Print header ---
fprintf('\n');
fprintf('  Samples: %d  (Total timer ticks: %d)\n', totalSnapshots, stacks.TotalSamples);
fprintf('\n');
fprintf('  Children   Self     Samples  Source\n');
fprintf('  ........  ........  .......  ......\n');

% --- Print each hot spot with call chains ---
for i = 1:nShow
    leafKey = keys{i};
    selfCount = counts(i);
    selfPct = selfCount / totalSnapshots * 100;

    fprintf('            %6.2f%%  %7d   %s\n', selfPct, selfCount, leafKey);

    % Get caller chains for this leaf
    if chainMaps.isKey(leafKey)
        cmap = chainMaps(leafKey);
        ckeys = cmap.keys;
        ccounts = double(cellfun(@(k) cmap(k), ckeys));
        [ccounts, cidx] = sort(ccounts, 'descend');
        ckeys = ckeys(cidx);

        maxChains = min(3, numel(ckeys));
        fprintf('            |\n');
        for c = 1:maxChains
            chain = strsplit(ckeys{c}, ';');
            chainPct = ccounts(c) / selfCount * 100;
            if c > 1
                fprintf('            |\n');
            end
            % Print: leaf (with percentage)
            fprintf('             --- %s  (%.0f%%)\n', chain{1}, chainPct);
            % Callers
            maxDepth = min(numel(chain), 8);
            for d = 2:maxDepth
                fprintf('                   %s\n', chain{d});
            end
            if numel(chain) > maxDepth
                fprintf('                   ... (%d more frames)\n', numel(chain) - maxDepth);
            end
        end
        if numel(ckeys) > maxChains
            fprintf('            |\n');
            remaining = sum(ccounts(maxChains+1:end));
            fprintf('             ... %d more chains (%d samples)\n', ...
                numel(ckeys) - maxChains, remaining);
        end
    end
    fprintf('\n');
end

end

% Copyright 2026 The MathWorks, Inc.
