function annotate_source_lines(stacks)
%ANNOTATE_SOURCE_LINES Print source files with per-line sample counts from profiler stacks.

if isempty(stacks.Snapshots)
    fprintf('No samples collected (no snapshots to annotate).\n');
    return;
end

% Count samples per file:line (leaf frame = self time). The leaf is Frames(Depth),
% not Frames(end) — Frames may carry entries beyond the reported Depth.
lineMap = containers.Map('KeyType', 'char', 'ValueType', 'int32');
fileSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for s = 1:numel(stacks.Snapshots)
    snap = stacks.Snapshots(s);
    d = min(double(snap.Depth), numel(snap.Frames));
    if d > 0
        fr = snap.Frames(d);
        key = sprintf('%s:%d', fr.FileName, fr.StartLine);
        if lineMap.isKey(key)
            lineMap(key) = lineMap(key) + 1;
        else
            lineMap(key) = 1;
        end
        fileSet(fr.FileName) = true;
    end
end

% Percentages are of captured snapshots (numel(Snapshots)), NOT TotalSamples.
% TotalSamples includes idle timer ticks (wall-clock time with no MATLAB frame on
% the stack); dividing by it would understate every line and disagree with
% find_hotspots / print_hotspot_report, which use the snapshot count.
totalSnapshots = numel(stacks.Snapshots);
files = fileSet.keys;

% Sort files by total samples descending
fileSamples = zeros(1, numel(files));
for f = 1:numel(files)
    fileSamples(f) = 0;
    allKeys = lineMap.keys;
    for k = 1:numel(allKeys)
        if startsWith(allKeys{k}, [files{f} ':'])
            fileSamples(f) = fileSamples(f) + lineMap(allKeys{k});
        end
    end
end
[fileSamples, sortIdx] = sort(fileSamples, 'descend');
files = files(sortIdx);

for f = 1:numel(files)
    fname = files{f};
    if fileSamples(f) == 0
        continue;
    end

    % Build line->count map for this file
    lineCounts = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
    allKeys = lineMap.keys;
    for k = 1:numel(allKeys)
        if startsWith(allKeys{k}, [fname ':'])
            parts = strsplit(allKeys{k}, ':');
            lineNum = str2double(parts{end});
            lineCounts(lineNum) = lineMap(allKeys{k});
        end
    end

    % Read source file
    [~, shortName, ext] = fileparts(fname);
    fprintf('\n========== %s%s (%d samples, %.1f%% of total) ==========\n', ...
        shortName, ext, fileSamples(f), fileSamples(f)/totalSnapshots*100);
    if strcmpi(ext, '.p') || startsWith(ext, '.mex', 'IgnoreCase', true)
        fprintf('  (P-coded or MEX; source not available)\n');
        continue;
    end

    try
        fid = fopen(fname, 'r');
        if fid == -1
            fprintf('  (could not read file)\n');
            continue;
        end
        src = {};
        while true
            line = fgetl(fid);
            if ~ischar(line), break; end
            src{end+1} = line; %#ok<AGROW>
        end
        fclose(fid);
        % Print sampled lines with 2 lines of context; elide the rest so a big file stays short
        show = false(1, numel(src));
        hotLines = double(cell2mat(lineCounts.keys));
        for h = hotLines(hotLines >= 1 & hotLines <= numel(src))
            show(max(1, h-2):min(numel(src), h+2)) = true;
        end
        for lineNum = 1:numel(src)
            if ~show(lineNum)
                if lineNum == 1 || show(lineNum-1), fprintf('            |  ... |\n'); end
                continue;
            end
            if lineCounts.isKey(lineNum)
                cnt = lineCounts(lineNum);
                pct = double(cnt) / totalSnapshots * 100;   % cnt is int32: divide in double
                fprintf('%5d  %5.1f%% | %4d | %s\n', cnt, pct, lineNum, src{lineNum});
            else
                fprintf('            | %4d | %s\n', lineNum, src{lineNum});
            end
        end
    catch
        fprintf('  (error reading file)\n');
    end
end

fprintf('\n');
end

% Copyright 2026 The MathWorks, Inc.
