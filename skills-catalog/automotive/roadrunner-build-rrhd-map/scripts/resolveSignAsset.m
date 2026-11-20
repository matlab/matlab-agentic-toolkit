function [assetPath, objectType, code, isFallback] = resolveSignAsset(rawCode, region, options)
%resolveSignAsset Map a source sign code to a RoadRunner sign or signal asset path.
%   [assetPath, objectType, code, isFallback] = resolveSignAsset(rawCode, region)
%   normalizes a sign code from a Lanelet2 or HD map source and returns the
%   region-appropriate RoadRunner asset path. Accepts Lanelet2 way subtypes
%   ("stop_sign"), regulatory-element sign_type values ("de274-30",
%   "jp_323-40"), Autoware traffic_sign_id values ("jp_330-A"), prefixed
%   RoadSign:Type values ("DE-2017/274-70"), and US MUTCD codes ("us_r1_1").
%
%   [...] = resolveSignAsset(..., ProjectFolder=folder) also verifies the
%   asset exists under the RoadRunner project folder (trying both .svg and
%   .svg_rrx) and falls back to the blank sign when it does not.
%
%   Inputs:
%     rawCode        - Source sign code (string)
%     region         - "Japan", "Germany", or "US" (detect from GeoReference)
%     ProjectFolder  - Optional RoadRunner project folder for existence checks
%
%   Outputs:
%     assetPath      - Asset path starting with "Assets/" (string)
%     objectType     - "sign" or "signal"
%     code           - Normalized code, safe for SignType IDs (string)
%     isFallback     - true when the code was not recognized (or the asset is missing) and the blank sign was used
%
%   Example:
%     [p, t] = resolveSignAsset("jp_330-A", "Japan")
%     % p = "Assets/Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx", t = "sign"

% Copyright 2026 The MathWorks, Inc.

    arguments
        rawCode (1,1) string
        region (1,1) string {mustBeMember(region, ["Japan", "Germany", "US"])}
        options.ProjectFolder (1,1) string = ""
    end

    code = lower(strtrim(rawCode));
    code = regexprep(code, "^traffic_sign/", "");
    code = regexprep(code, "^(de-?\d{4}/|de[_-]?|us[_-]|jp[_-])", "");
    num = regexp(code, "^\d+", "match", "once");
    valTok = regexp(code, "-(\d+)$", "tokens", "once");
    speedVal = "";
    if ~isempty(valTok), speedVal = valTok{1}; end

    % Paths verified against the RoadRunner_Asset_Library (R2026a). Note the mixed .svg / .svg_rrx extensions.
    stopPath = struct("Japan", "Signs/Japan/Regulatory Signs/Stop_JP_01.svg_rrx", ...
        "Germany", "Signs/Germany/Regulatory Signs/Stop_DE.svg_rrx", "US", "Signs/US/Regulatory Signs/Stop_US.svg");
    yieldPath = struct("Japan", "Signs/Japan/Auxiliary Signs/Yield_JP.svg_rrx", ...
        "Germany", "Signs/Germany/Regulatory Signs/Yield_DE.svg_rrx", "US", "Signs/US/Regulatory Signs/Yield_US.svg");
    speedPattern = struct("Japan", "Signs/Japan/Regulatory Signs/MaxSpeedLimit_%s_JP.svg_rrx", ...
        "Germany", "Signs/Germany/Regulatory Signs/MaxSpeed_%s_DE.svg_rrx", ...
        "US", "Signs/US/Regulatory Signs/SpeedLimit_%s_US.svg_rrx");
    blankPath = "Signs/US/White_Blank_US.svg";   % neutral fallback for unrecognized codes in every region
    japanKeyword = ["no_entry", "NoEntryForVehicles_JP"; "no_parking", "NoParking_JP"; ...
        "no_stopping", "NoStopping_JP"; "one_way", "OneWay_JP_01"; "no_overtaking", "NoOvertaking_JP"; ...
        "no_u_turn", "NoUTurns_JP"; "slow", "SlowDown_JP_01"];

    % German StVO numbers with an exact asset (folder/name, extension .svg_rrx)
    germanCode = ["267", "Regulatory Signs/DoNotEnter_DE"; "272", "Regulatory Signs/NoUTurns_DE"; ...
        "276", "Regulatory Signs/NoPassing_DE"; "277", "Regulatory Signs/NoPassing_HeavyVehicles_DE"; ...
        "278", "Regulatory Signs/MaxSpeed_End_DE"; "280", "Regulatory Signs/NoPassing_End_DE"; ...
        "281", "Regulatory Signs/NoPassing_HeavyVehicles_End_DE"; "282", "Regulatory Signs/AllRestrictions_DE"; ...
        "283", "Regulatory Signs/NoParkingOrStopping_DE"; "286", "Regulatory Signs/NoParking_DE"; ...
        "264", "Regulatory Signs/MaxWidth_DE"; "265", "Regulatory Signs/MaxHeight_DE"; "266", "Regulatory Signs/MaxLength_DE"; ...
        "215", "Regulatory Signs/Roundabout_DE"; "220", "Regulatory Signs/OneWayStreet_DE_01"; ...
        "237", "Regulatory Signs/BicycleLane_DE"; "239", "Regulatory Signs/PedWalkway_DE"; ...
        "301", "Directional Signs/PriorityRoad_Intersection_DE"; "306", "Directional Signs/PriorityRoad_DE"; ...
        "307", "Directional Signs/PriorityRoad_End_DE"; "308", "Directional Signs/PriorityOverOncomingTraffic_DE"];

    objectType = "sign";
    isFallback = false;
    path = "";
    isStop = (contains(code, "stop") && ~contains(code, ["no_stop", "nostop", "stopping"])) || ...
        startsWith(code, ["r1_1", "r1-1"]) || ...
        (region == "Japan" && num == "330") || (region == "Germany" && num == "206");
    isYield = contains(code, ["yield", "give_way"]) || startsWith(code, ["r1_2", "r1-2"]) || ...
        (region == "Germany" && num == "205");
    isSpeed = contains(code, ["speed", "maxspeed"]) || startsWith(code, ["r2_1", "r2-1"]) || ...
        (region == "Germany" && num == "274") || (region == "Japan" && num == "323");

    if contains(code, ["traffic_light", "signal"])
        objectType = "signal";
        path = "Props/Signals/Signal_3Light_Post01.fbx";
    elseif region == "Germany" && startsWith(code, "274.1")
        path = "Signs/Germany/Regulatory Signs/MaxSpeedZone_30_DE.svg_rrx";      % zone begin (Tempo-30-Zone)
    elseif region == "Germany" && startsWith(code, "274.2")
        path = "Signs/Germany/Regulatory Signs/MaxSpeedZone_End_30_DE.svg_rrx";  % zone end
    elseif isStop
        path = stopPath.(region);
    elseif isYield
        path = yieldPath.(region);
    elseif isSpeed
        if speedVal == "", speedVal = regexp(code, "(\d+)$", "match", "once"); end
        v = str2double(speedVal);
        if speedVal ~= "" && v >= 5 && v <= 160 && mod(v, 5) == 0
            path = sprintf(speedPattern.(region), speedVal);
        end
    elseif region == "Germany" && any(germanCode(:, 1) == num)
        path = "Signs/Germany/" + germanCode(germanCode(:, 1) == num, 2) + ".svg_rrx";
    elseif region == "Japan" && num == "329"
        path = "Signs/Japan/Regulatory Signs/SlowDown_JP_01.svg_rrx";
    elseif region == "Japan"
        hit = find(arrayfun(@(k) contains(code, k), japanKeyword(:, 1)), 1);
        if ~isempty(hit), path = "Signs/Japan/Regulatory Signs/" + japanKeyword(hit, 2) + ".svg_rrx"; end
    elseif contains(code, "no_u_turn") && region == "US"
        path = "Signs/US/Regulatory Signs/NoUTurns_US.svg";
    end

    if path == ""
        path = blankPath;
        isFallback = true;
    end
    assetPath = "Assets/" + string(path);

    if options.ProjectFolder ~= ""
        exists = @(a) isfile(fullfile(options.ProjectFolder, a)) || isfile(fullfile(options.ProjectFolder, a + ".rrmeta"));
        if ~exists(assetPath)
            alt = regexprep(assetPath, "\.svg_rrx$", ".svg");
            if alt == assetPath, alt = regexprep(assetPath, "\.svg$", ".svg_rrx"); end
            if exists(alt)
                assetPath = alt;
            else
                warning("resolveSignAsset:AssetMissing", "Asset not found in project: %s — using blank sign.", assetPath);
                assetPath = "Assets/" + blankPath;
                isFallback = true;
            end
        end
    end
    code = string(regexprep(code, "[^a-z0-9]+", "_"));

    if nargout == 0, clear assetPath objectType code isFallback; end
end
