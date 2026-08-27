function [Mode, Reasoning] = chooseStandardization(RawTbl, Response, TargetModel)
%chooseStandardization Recommend a TransformedDataStandardization mode.
%
%   [Mode, Reasoning] = chooseStandardization(RawTbl, Response, TargetModel)
%   inspects the numeric predictors and the declared model family to recommend
%   how genc/genrfeatures should standardize their engineered features. The
%   returned Mode is one of "none", "zscore", "mad", "range" (never "auto" —
%   this utility resolves "auto" into a concrete choice) and is passed as the
%   TransformedDataStandardization name-value argument to the generator.
%
%   Decision logic (each auto-choice matches the generator's own default for the
%   family, so the only deliberate deviation is the data-driven mad case):
%     tree_ensemble                    -> "none"   (trees are scale-invariant;
%                                                    matches the bag default)
%     heavy-skew predictors dominate   -> "mad"    (robust center/scale resists
%       (fraction with |skew| >= 2 over            the outliers/heavy tails a
%        half of numeric predictors)               z-score would let dominate)
%     linear / kernel_distance /       -> "zscore" (the generator's own default
%       agnostic (low skew)                         for scale-sensitive learners;
%                                                    agnostic generates as linear)
%
%   "range" is never auto-selected: it is correct only for bounded/proportion or
%   non-negative data the skew read cannot detect, so reach it via the explicit
%   Standardization override rather than inferring it here.
%
%   Inputs:
%     RawTbl      - table of raw predictors + response
%     Response    - (1,1) string, response variable name (excluded from stats)
%     TargetModel - (1,1) string, "agnostic" | "tree_ensemble" | "linear" |
%                   "kernel_distance"
%
%   Outputs:
%     Mode      - (1,1) string, chosen standardization mode
%     Reasoning - (1,1) string, human-readable justification citing the measured
%                 skew fraction and family

% Copyright 2026 The MathWorks, Inc.

    arguments
        RawTbl table
        Response (1,1) string
        TargetModel (1,1) string {mustBeMember(TargetModel, ...
            ["agnostic","tree_ensemble","linear","kernel_distance"])}
    end

    if TargetModel == "tree_ensemble"
        Mode = "none";
        Reasoning = "tree_ensemble: trees are scale-invariant, no standardization needed";
        return;
    end

    [HeavySkewFrac, NumNumeric] = heavySkewFraction(RawTbl, Response);

    if NumNumeric == 0
        % No numeric predictors to profile (all categorical). Standardization
        % applies to the numeric engineered features the generator still emits;
        % default to z-score for the scale-sensitive families.
        Mode = "zscore";
        Reasoning = sprintf(...
            "%s: no numeric raw predictors to profile; default z-score for engineered numerics", ...
            TargetModel);
        return;
    end

    if HeavySkewFrac > 0.5
        Mode = "mad";
        Reasoning = sprintf(...
            "%.0f%% of %d numeric predictors are heavy-skewed (|skew| >= 2); MAD scaling resists outliers", ...
            100 * HeavySkewFrac, NumNumeric);
    else
        % linear / kernel_distance / agnostic, low skew: z-score matches the
        % generator's own default for these scale-sensitive learners.
        Mode = "zscore";
        Reasoning = sprintf(...
            "%s with low skew (%.0f%% heavy of %d); z-score is standard for symmetric data", ...
            TargetModel, 100 * HeavySkewFrac, NumNumeric);
    end
end


function [Frac, NumNumeric] = heavySkewFraction(RawTbl, Response)
%heavySkewFraction Fraction of numeric predictors with |skewness| >= 2.
%   Excludes the response column and any non-numeric predictors. Returns 0 for
%   the fraction when there are no numeric predictors.

    HeavyThreshold = 2;   % |skew| >= 2 flags a heavy-tailed / strongly skewed column
    Vars = string(RawTbl.Properties.VariableNames);
    Vars = Vars(Vars ~= Response);

    NumNumeric = 0;
    NumHeavy = 0;
    for v = Vars
        Col = RawTbl.(v);
        if ~isnumeric(Col)
            continue;
        end
        Col = double(Col(~isnan(Col)));
        if numel(Col) < 3
            continue;
        end
        NumNumeric = NumNumeric + 1;
        if abs(sampleSkewness(Col)) >= HeavyThreshold
            NumHeavy = NumHeavy + 1;
        end
    end

    if NumNumeric == 0
        Frac = 0;
    else
        Frac = NumHeavy / NumNumeric;
    end
end
