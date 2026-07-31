function protocolSummary = checkCyclingProtocol(data, opts)
%checkCyclingProtocol Analyze cycling protocol consistency across cycles.
%   protocolSummary = checkCyclingProtocol(data, Name=Value) runs
%   batteryTestDataParser to segment the data, then summarizes the protocol
%   per step across all cycles. Reports whether each phase has a consistent
%   step sequence suitable for feature extraction.
%
%   Uses majority-based consistency: if >95% of cycles share the same step
%   sequence, the protocol is considered consistent. Anomalous cycles are
%   identified and reported for potential exclusion.
%
%   Required Input:
%       data - Table of battery cycling data
%
%   Name-Value Arguments:
%       CurrentVariable     - Name of current column (default: "Current")
%       VoltageVariable     - Name of voltage column (default: "Voltage")
%       TimeVariable        - Name of time column (default: "DateTime")
%       CycleIndexVariable  - Name of cycle index column (default: "Cycle_Index")
%       StepIndexVariable   - Name of step index column (default: "Step_Index")
%       TemperatureVariable - Name of temperature column (default: "", disabled)
%
%   Output:
%       protocolSummary - struct with fields:
%           .StepTable             - Table with per-step statistics (majority cycles only)
%           .ChargeConsistent      - true if charge steps are consistent
%           .DischargeConsistent   - true if discharge steps are consistent
%           .RecommendedPhase      - "Charge", "Discharge", or "Both"
%           .NumCycles             - Number of cycles in data
%           .AnomalousCycles       - Cycle indices with non-standard step sequences
%           .MajorityCycles        - Cycle indices matching the dominant protocol

arguments
    data table
    opts.CurrentVariable string = "Current"
    opts.VoltageVariable string = "Voltage"
    opts.TimeVariable string = "DateTime"
    opts.CycleIndexVariable string = "Cycle_Index"
    opts.StepIndexVariable string = "Step_Index"
    opts.TemperatureVariable string = ""
end

% Build parser
if opts.TemperatureVariable ~= ""
    parser = batteryTestDataParser(data, ...
        CurrentVariable=opts.CurrentVariable, ...
        VoltageVariable=opts.VoltageVariable, ...
        TimeVariable=opts.TimeVariable, ...
        CycleIndexVariable=opts.CycleIndexVariable, ...
        StepIndexVariable=opts.StepIndexVariable, ...
        TemperatureVariable=opts.TemperatureVariable);
else
    parser = batteryTestDataParser(data, ...
        CurrentVariable=opts.CurrentVariable, ...
        VoltageVariable=opts.VoltageVariable, ...
        TimeVariable=opts.TimeVariable, ...
        CycleIndexVariable=opts.CycleIndexVariable, ...
        StepIndexVariable=opts.StepIndexVariable);
end
segmented = segmentData(parser);

cycles = unique(segmented.(opts.CycleIndexVariable));
numCycles = numel(cycles);

% Identify majority step sequence
[majorityCycles, anomalousCycles] = ...
    findMajorityProtocol(segmented, cycles, opts.CycleIndexVariable, opts.StepIndexVariable);

% Build per-cycle-step summary using majority cycles only
rows = [];
for c = majorityCycles'
    cycleMask = segmented.(opts.CycleIndexVariable) == c;
    cycleData = segmented(cycleMask, :);
    steps = unique(cycleData.(opts.StepIndexVariable));

    for s = steps'
        stepMask = cycleData.(opts.StepIndexVariable) == s;
        stepData = cycleData(stepMask, :);

        numPoints = height(stepData);
        medianI = median(stepData.(opts.CurrentVariable));
        minV = min(stepData.(opts.VoltageVariable));
        maxV = max(stepData.(opts.VoltageVariable));

        % Duration
        timeVar = stepData.(opts.TimeVariable);
        if isdatetime(timeVar)
            dur = seconds(timeVar(end) - timeVar(1));
        else
            dur = timeVar(end) - timeVar(1);
        end

        % Phase from parser (dominant)
        phase = dominantCategory(stepData.CyclingPhases);

        % Mode fractions from parser
        modes = stepData.CyclingModes;
        ccPct = 100 * sum(modes == "CC") / numPoints;
        cvPct = 100 * sum(modes == "CV") / numPoints;
        restPct = 100 * sum(modes == "Rest") / numPoints;

        row.Cycle = c;
        row.Step = s;
        row.Phase = phase;
        row.CC_Pct = round(ccPct, 0);
        row.CV_Pct = round(cvPct, 0);
        row.Rest_Pct = round(restPct, 0);
        row.MedianCurrent_A = round(medianI, 3);
        row.MinVoltage_V = round(minV, 3);
        row.MaxVoltage_V = round(maxV, 3);
        row.Duration_s = round(dur, 1);
        row.NumPoints = numPoints;
        rows = [rows; row]; %#ok<AGROW>
    end
end

stepTable = struct2table(rows);

% Assess consistency per phase (using majority cycles only)
chargeConsistent = assessPhaseConsistency(stepTable, "Charge");
dischargeConsistent = assessPhaseConsistency(stepTable, "Discharge");

% Recommend phase
if chargeConsistent && dischargeConsistent
    recommendedPhase = "Both";
elseif chargeConsistent
    recommendedPhase = "Charge";
elseif dischargeConsistent
    recommendedPhase = "Discharge";
else
    recommendedPhase = "Both";
end

% Build output
protocolSummary.StepTable = stepTable;
protocolSummary.ChargeConsistent = chargeConsistent;
protocolSummary.DischargeConsistent = dischargeConsistent;
protocolSummary.RecommendedPhase = recommendedPhase;
protocolSummary.NumCycles = numCycles;
protocolSummary.AnomalousCycles = anomalousCycles;
protocolSummary.MajorityCycles = majorityCycles;

% Display summary
displayProtocolSummary(protocolSummary);

end

%% Local functions

function [majorityCycles, anomalousCycles, majoritySteps] = findMajorityProtocol(segmented, cycles, cycleVar, stepVar)
    % Find the most common step sequence across cycles
    stepSequences = cell(numel(cycles), 1);
    for i = 1:numel(cycles)
        mask = segmented.(cycleVar) == cycles(i);
        stepSequences{i} = unique(segmented.(stepVar)(mask))';
    end

    % Convert to string keys for grouping
    keys = string(cellfun(@(x) strjoin(string(x), ","), stepSequences, UniformOutput=false));
    [~, ~, groupIdx] = unique(keys);

    % Find the majority group
    counts = accumarray(groupIdx, 1);
    [~, majorIdx] = max(counts);

    majorityMask = groupIdx == majorIdx;
    majorityCycles = cycles(majorityMask);
    anomalousCycles = cycles(~majorityMask);
    majoritySteps = stepSequences{find(majorityMask, 1)};
end

function cat = dominantCategory(catArray)
    cleaned = removecats(catArray);
    cats = categories(cleaned);
    counts = countcats(cleaned);
    [~, idx] = max(counts);
    cat = string(cats{idx});
end

function isConsistent = assessPhaseConsistency(stepTable, phase)
    phaseMask = stepTable.Phase == phase;
    if ~any(phaseMask)
        isConsistent = false;
        return;
    end

    phaseData = stepTable(phaseMask, :);
    cycles = unique(phaseData.Cycle);
    if numel(cycles) < 2
        isConsistent = true;
        return;
    end

    % Get step sequence per cycle
    stepSequences = cell(numel(cycles), 1);
    for i = 1:numel(cycles)
        cycleMask = phaseData.Cycle == cycles(i);
        stepSequences{i} = phaseData.Step(cycleMask)';
    end

    % Check if all majority cycles have the same step sequence
    refSequence = stepSequences{1};
    isConsistent = true;
    for i = 2:numel(stepSequences)
        if ~isequal(stepSequences{i}, refSequence)
            isConsistent = false;
            return;
        end
    end

    % Check per-step CC% and CV% are stable across cycles (IQR within 15pp)
    % Uses IQR instead of full range to tolerate gradual aging drift
    for s = refSequence
        stepMask = phaseMask & stepTable.Step == s;
        ccPcts = stepTable.CC_Pct(stepMask);
        cvPcts = stepTable.CV_Pct(stepMask);

        if iqr(ccPcts) > 15 || iqr(cvPcts) > 15
            isConsistent = false;
            return;
        end
    end
end

function displayProtocolSummary(summary)
    fprintf("\n=== Cycling Protocol Summary ===\n");
    fprintf("Cycles: %d\n\n", summary.NumCycles);

    % Report anomalous cycles
    nAnomalous = numel(summary.AnomalousCycles);
    if nAnomalous > 0
        fprintf("Anomalous cycles: %d/%d (%.1f%%) have non-standard step sequences\n", ...
            nAnomalous, summary.NumCycles, 100*nAnomalous/summary.NumCycles);
        if nAnomalous <= 20
            fprintf("  Indices: %s\n", strjoin(string(summary.AnomalousCycles'), ", "));
        else
            first10 = strjoin(string(summary.AnomalousCycles(1:10)'), ", ");
            fprintf("  First 10: %s, ...\n", first10);
        end
        fprintf("  Consider adding to ExcludedCycles: [%s]\n\n", ...
            strjoin(string(summary.AnomalousCycles'), ", "));
    else
        fprintf("All cycles have the same step sequence.\n\n");
    end

    % Display per-step table for first majority cycle as reference
    t = summary.StepTable;
    refCycle = t.Cycle(1);
    refMask = t.Cycle == refCycle;
    refTable = t(refMask, :);

    fprintf("Reference protocol (Cycle %d):\n", refCycle);
    fprintf("  %-6s %-12s %-6s %-6s %-6s %-12s %-20s %-10s\n", ...
        "Step", "Phase", "CC%", "CV%", "Rest%", "MedianI(A)", "V_range(V)", "Dur(s)");
    fprintf("  %-6s %-12s %-6s %-6s %-6s %-12s %-20s %-10s\n", ...
        "----", "-----", "---", "---", "----", "----------", "----------", "------");
    for i = 1:height(refTable)
        fprintf("  %-6d %-12s %-6d %-6d %-6d %-12.3f [%.3f, %.3f]    %.1f\n", ...
            refTable.Step(i), char(refTable.Phase(i)), ...
            refTable.CC_Pct(i), refTable.CV_Pct(i), refTable.Rest_Pct(i), ...
            refTable.MedianCurrent_A(i), refTable.MinVoltage_V(i), ...
            refTable.MaxVoltage_V(i), refTable.Duration_s(i));
    end

    fprintf("\nConsistency (based on %d majority cycles):\n", numel(summary.MajorityCycles));
    fprintf("  Charge phase:    %s\n", consistencyStr(summary.ChargeConsistent));
    fprintf("  Discharge phase: %s\n", consistencyStr(summary.DischargeConsistent));
    fprintf('\nRecommended CyclingPhase: "%s"\n', summary.RecommendedPhase);

    if ~summary.ChargeConsistent && ~summary.DischargeConsistent
        fprintf('  (Neither phase is fully consistent - using "Both" as fallback)\n');
    end
end

function s = consistencyStr(flag)
    if flag
        s = "CONSISTENT across all cycles";
    else
        s = "NOT consistent across cycles";
    end
end

% Copyright 2026 The MathWorks, Inc.
