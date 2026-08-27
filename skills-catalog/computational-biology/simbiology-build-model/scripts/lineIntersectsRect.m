function hit = lineIntersectsRect(x1, y1, x2, y2, rect)
% Internal use only
% Used by the simbiology-build-model agent skill during diagram layout.
% NOT FOR EXTERNAL USE - Subject to change.
%
% LINEINTERSECTSRECT Check if a line segment intersects a rectangle.
%   hit = lineIntersectsRect(x1, y1, x2, y2, rect) returns true if the
%   line segment from (x1,y1) to (x2,y2) intersects the rectangle defined
%   by rect = [rx1 ry1 rx2 ry2] (top-left and bottom-right corners).
%
%   Uses the Liang-Barsky clipping algorithm.
    dx = x2 - x1;
    dy = y2 - y1;
    rx1 = rect(1); ry1 = rect(2); rx2 = rect(3); ry2 = rect(4);

    tmin = 0; tmax = 1;
    edges = [-dx, dx, -dy, dy];
    dists = [x1 - rx1, rx2 - x1, y1 - ry1, ry2 - y1];

    for e = 1:4
        if edges(e) == 0
            if dists(e) < 0
                hit = false;
                return
            end
        else
            t = dists(e) / edges(e);
            if edges(e) < 0
                tmin = max(tmin, t);
            else
                tmax = min(tmax, t);
            end
        end
    end
    hit = (tmin <= tmax);
end

% Copyright 2026 The MathWorks, Inc.
