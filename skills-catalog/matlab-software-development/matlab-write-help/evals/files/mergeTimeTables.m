function merged = mergeTimeTables(ttA, ttB, method)
    %mergeTimeTables - Merge two timetables by synchronizing timestamps
    %   MERGED = mergeTimeTables(ttA, ttB) synchronizes the two
    %   timetables using linear interpolation and returns the
    %   combined result.
    %
    %   Copyright 2024-2026 The MathWorks, Inc.
    %
    %   MERGED = mergeTimeTables(ttA, ttB, METHOD) uses the
    %   specified synchronization method.
    %
    %   METHOD values:
    %     "linear"  - (default) linear interpolation
    %     "nearest" - nearest-neighbor interpolation
    %
    % See also synchronize, retime, timetable

    arguments
        ttA timetable
        ttB timetable
        method (1,1) string = "linear"
    end
    merged = synchronize(ttA, ttB, "union", method);
end
