% printCoverageGaps — Print uncovered items from coverage results.
%
% Expects covResults from the Collect step (CoverageResult output).
% Include tiers up to the MetricLevel used:
%   default (no MetricLevel) → keep statement & function only
%   "decision"               → keep through decision
%   "condition"              → keep through condition
%   "mcdc"                   → keep all

% --- statement & function (always available) ---
for type = ["statement", "function"]
    [~, decs] = coverageSummary(covResults, type);
    items = decs.(type);
    uncov = items([items.ExecutionCount] == 0);
    for i = 1:numel(uncov)
        fprintf('Uncovered %s: %s:%d (%s)\n', type, uncov(i).Filename, ...
            uncov(i).SourceLocation.StartLine, uncov(i).FunctionName);
    end
end

% --- decision (MetricLevel "decision"+) ---
[~, decs] = coverageSummary(covResults, "decision");
for numFilesWithDecisions = 1:numel(decs)
    decisions = decs(numFilesWithDecisions).decision;
    for i = 1:numel(decisions)
        thisDecision = decisions(i);
        outcomes = [thisDecision.Outcome];
        for j = 1:numel(outcomes)
            if outcomes(j).ExecutionCount == 0
                fprintf('Uncovered decision: %s:%d — %s → %s\n', ...
                    thisDecision.Filename, thisDecision.SourceLocation.StartLine, ...
                    thisDecision.Text, outcomes(j).Text);
            end
        end
    end
end

% --- condition (MetricLevel "condition"+) ---
[~, decs] = coverageSummary(covResults, "condition");
for numFilesWithConditions = 1:numel(decs)
    conditions = decs(numFilesWithConditions).condition;
    for i = 1:numel(conditions)
        cond = conditions(i);
        if cond.TrueCount == 0
            fprintf('Uncovered condition (true): %s:%d — %s\n', ...
                cond.Filename, cond.SourceLocation.StartLine, cond.Text);
        end
        if cond.FalseCount == 0
            fprintf('Uncovered condition (false): %s:%d — %s\n', ...
                cond.Filename, cond.SourceLocation.StartLine, cond.Text);
        end
    end
end

% --- mcdc (MetricLevel "mcdc") ---
[~, decs] = coverageSummary(covResults, "mcdc");
for i = 1:numel(decs)
    d = decs(i).mcdc;
    for j = 1:numel(d)
        conditions = d(j).Condition;
        for k = 1:numel(conditions)
            if ~conditions(k).Achieved
                fprintf('Unachieved MC/DC: %s:%d — %s → %s\n', ...
                    d(j).Filename, d(j).SourceLocation.StartLine, ...
                    d(j).Text, conditions(k).Text);
            end
        end
    end
end
