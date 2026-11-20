function report = helperCheckScenarioStructure(rrs, options)
%helperCheckScenarioStructure Check a built scenario for mistakes validate() does not report.
%
%   report = helperCheckScenarioStructure(rrs)
%   report = helperCheckScenarioStructure(rrs, MinSeparation=4)
%
%   Inspects the actors and phase logic of a roadrunner.api.Scenario and prints
%   one line per problem. Checks (all verified in RoadRunner R2026b):
%     - Actor still at the origin [0 0 0] (never placed)
%     - Two actors starting closer than MinSeparation (overlap; validate() misses it)
%     - Lane-change or lateral-offset actor that has route waypoints
%     - Character actor with no route waypoints
%     - ActorActionPhase with no .Actor
%     - Continuous speed or gap-keeping phase with a successor but no end condition
%       (the phase never ends, so the next phase never starts)
%     - Two same-axis actions in parallel on one actor (one is silently dropped)
%
%   Returns:
%       report - struct with .AllValid (logical), .Issues (string array) and .Actors (table)
%
% This is a helper function for example purposes and may be removed or
% modified in the future.

    arguments
        rrs (1,1) roadrunner.api.Scenario
        options.MinSeparation (1,1) double = 4.0
    end

    issues = strings(0, 1);
    acts = rrs.Actors;
    n = numel(acts);
    names = strings(n, 1); assetType = strings(n, 1); waypoints = zeros(n, 1); pos = zeros(n, 3);
    for i = 1:n
        names(i) = string(acts(i).Name);
        assetType(i) = extractAfter(string(class(acts(i).ActorAsset)), "api.");
        pos(i, :) = acts(i).InitialPoint.WorldPosition;
        waypoints(i) = max(numel(acts(i).InitialPoint.Route.Points) - 1, 0);   % Points includes the start
        if norm(pos(i, :)) < 1e-6
            issues(end+1) = sprintf("Actor %s is at the origin [0 0 0]: it was never placed.", names(i)); %#ok<AGROW>
        end
        if assetType(i) == "CharacterAsset" && waypoints(i) == 0
            issues(end+1) = sprintf("Character %s has no route waypoints (characters need a path).", names(i)); %#ok<AGROW>
        end
    end
    for i = 1:n
        for j = i+1:n
            d = norm(pos(i, 1:2) - pos(j, 1:2));
            if d < options.MinSeparation
                issues(end+1) = sprintf("Actors %s and %s start %.1f m apart (overlap; check autoAnchor shifts).", names(i), names(j), d); %#ok<AGROW>
            end
        end
    end

    lateral = ["ChangeLaneAction" "ChangeLateralOffsetAction"];
    longitudinal = ["ChangeSpeedAction" "ChangeLongitudinalDistanceAction" "SynchronizeAction"];
    issues = walkPhase(rrs.PhaseLogic.RootPhase, false, issues);

    report.AllValid = isempty(issues);
    report.Issues = issues;
    report.Actors = table(names, assetType, pos, waypoints, ...
        'VariableNames', ["Name" "AssetType" "Position" "RouteWaypoints"]);
    if report.AllValid
        fprintf("Structure check: %d actors, no issues.\n", n);
    else
        fprintf("Structure check: %d issue(s)\n", numel(issues));
        fprintf("  - %s\n", issues);
    end
    if nargout == 0
        clear report   % no auto-display when called without an output
    end

    function issues = walkPhase(p, hasSuccessor, issues)
    %walkPhase Recurse through the phase tree, tracking whether each phase is followed by another.
        if isa(p, "roadrunner.api.ActorActionPhase")
            issues = checkActorPhase(p, hasSuccessor, issues);
            return
        end
        if ~isprop(p, "ChildPhases")
            return
        end
        kids = p.ChildPhases;
        if isa(p, "roadrunner.api.ParallelPhase")
            issues = checkParallel(kids, issues);
        end
        for k = 1:numel(kids)
            if isa(p, "roadrunner.api.SerialPhase")
                next = k < numel(kids) || hasSuccessor;
            else
                next = hasSuccessor;
            end
            issues = walkPhase(kids(k), next, issues);
        end
    end

    function issues = checkActorPhase(p, hasSuccessor, issues)
    %checkActorPhase Per-phase checks: actor set, lane-change actors routeless, continuous phases end.
        if isempty(p.Actor)
            issues(end+1) = "An ActorActionPhase has no .Actor.";
            return
        end
        who = string(p.Actor.Name);
        for m = 1:numel(p.Actions)
            a = p.Actions(m); c = extractAfter(string(class(a)), "api.");
            if any(c == lateral) && waypoints(names == who) > 0
                issues(end+1) = sprintf("%s has %s but also route waypoints (needs lane-following, no route).", who, c); %#ok<AGROW>
            end
            continuous = isprop(a, "SamplingMode") && a.SamplingMode == "continuous";
            if continuous && hasSuccessor && isempty(p.EndCondition)
                issues(end+1) = sprintf("%s: continuous %s phase has a successor but no end condition (it never ends).", who, c); %#ok<AGROW>
            end
        end
    end

    function issues = checkParallel(kids, issues)
    %checkParallel Flag two same-axis actions for the same actor among parallel children.
        owners = strings(0); axisOf = strings(0);
        for k = 1:numel(kids)
            if ~isa(kids(k), "roadrunner.api.ActorActionPhase") || isempty(kids(k).Actor)
                continue
            end
            for m = 1:numel(kids(k).Actions)
                c = extractAfter(string(class(kids(k).Actions(m))), "api.");
                if any(c == lateral), ax = "lateral"; elseif any(c == longitudinal), ax = "longitudinal"; else, continue; end
                owners(end+1) = string(kids(k).Actor.Name); axisOf(end+1) = ax; %#ok<AGROW>
            end
        end
        key = owners + "|" + axisOf;
        [u, ~, idx] = unique(key);
        dup = u(accumarray(idx(:), 1) > 1);
        for k = 1:numel(dup)
            parts = split(dup(k), "|");
            issues(end+1) = sprintf("%s runs two %s actions in parallel; one is silently dropped (run them in serial).", parts(1), parts(2)); %#ok<AGROW>
        end
    end
end
% Copyright 2026 The MathWorks, Inc.
