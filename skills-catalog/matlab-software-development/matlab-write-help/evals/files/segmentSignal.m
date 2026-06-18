% Copyright 2026 The MathWorks, Inc.
function [segments, boundaries, labels] = segmentSignal(data, threshold, opts)
    arguments
        data (:,1) double
        threshold (1,1) double
        opts.MinLength (1,1) double = 10
        opts.LabelPrefix (1,1) string = "seg"
    end
    diffs = abs(diff(data));
    boundaries = find(diffs > threshold);
    boundaries = boundaries(diff([0; boundaries]) >= opts.MinLength);
    starts = [1; boundaries + 1];
    ends = [boundaries; numel(data)];
    segments = cell(numel(starts), 1);
    labels = strings(numel(starts), 1);
    for k = 1:numel(starts)
        segments{k} = data(starts(k):ends(k));
        labels(k) = opts.LabelPrefix + string(k);
    end
end
