function Recipe = buildRecipe(Apply, Describe, Provider, FeatureTable, RawInput, Options)
%buildRecipe Assemble a domain recipe and prove it against its pool in one call.
%
%   Recipe = buildRecipe(Apply, Describe, Provider, FeatureTable, RawInput)
%   assembles a capture-time domain recipe struct (Kind == "domain") from the
%   pieces a domain extraction produced, and returns it ONLY if it faithfully
%   reproduces and describes the pool it was captured from. It is the single
%   choke point both routing paths pass through -- the subagent-dispatch path
%   (main) and the inline same-session path (fallback) call it with the same
%   arguments, so downstream receives an identical, already-verified recipe and
%   never knows which path produced it (see domain-routing.md, provider-protocol.md).
%
%   It replaces the earlier "assemble a struct by hand, then remember to call
%   validateRecipe" protocol with one function that:
%     1. assembles the struct  -- Kind = "domain", Apply, Describe, Provider;
%     2. checks its shape       -- Apply is a function handle, Describe has the
%        Feature|Type|Definition variables, Provider is non-empty text;
%     3. runs the round-trip gate inline -- validateRecipe replays Apply against
%        the pool and confirms Describe lists exactly the pool's features.
%   Anything missing or unfaithful is a hard error here, at construction, rather
%   than a silent failure downstream. A returned recipe is a proven one.
%
%   This is the CAPTURE-TIME constructor: it builds the four fields generation,
%   selection, and assessment need (Kind/Apply/Describe/Provider). ApplySelected
%   is the inference-only path and is requested separately at deliver time, once
%   selection has fixed the feature set, and validated then (see deliver.md);
%   buildRecipe neither builds nor requires it.
%
%   OPTIONAL Fit -- unlock generation-variance assessment. Apply replays a recipe
%   fit ONCE (frozen); it cannot regenerate the pool on new rows, so it alone
%   cannot answer "how much would the pool itself move if refit?". A domain path
%   that CAN re-run its extraction fitting may pass that as Options.Fit -- a
%   re-runnable producer with the same signature assessKFold/assessGenerationStability
%   consume:
%     [EngTrain, Apply, ExcludeFeatures] = Fit(RawRows, Response, ProblemType, TargetModel)
%   When supplied it is verified here (fitting on the captured rows must reproduce
%   the pool's feature names) and stored as Recipe.Fit, which the orchestrator
%   passes as the Producer to enable cross-validated performance and the
%   generation-stability read. Fit is DIAGNOSTIC-time only: inference always ships
%   the frozen Apply, never a refit (refitting at inference would drift). Absent
%   Fit, those reads degrade to N/A on the domain path (see assess.md).
%
%   Inputs:
%     Apply        - (1,1) function_handle mapping the RAW DATA (in whatever form
%                    the extraction consumes) to the FULL feature table (the
%                    replayed extraction). The only hard contract is that Apply
%                    RETURNS a table; its input type is the extractor's business.
%     Describe     - table with Feature|Type|Definition, one row per pool feature
%     Provider     - (1,1) string, free-text label for the source skill
%     FeatureTable - the materialized pool the recipe was captured from
%                    (predictors + response), one row per observation
%     RawInput     - the raw data Apply consumes, row-aligned with FeatureTable
%                    (one raw observation per pool row). Any row-indexable form:
%                    a table, a numeric/categorical matrix, a cell array, etc. --
%                    NOT constrained to a table, so a matrix-consuming extractor
%                    is passed its matrix unchanged rather than silently coerced.
%     Options.ResponseVar (1,1) string = ""  response column, excluded from the
%                                            checked feature set if present
%     Options.CheckIdx    (1,:) double = []  rows to verify against; pass the
%                                            HELD-OUT (test) indices so response-
%                                            based encodings do not false-alarm
%                                            (forwarded to validateRecipe)
%     Options.Fit         (1,1) function_handle  OPTIONAL re-runnable producer (see
%                                            above); when set, verified and stored
%                                            as Recipe.Fit
%     Options.ProblemType (1,1) string       "classification"/"regression"; required
%                                            when Fit is supplied (it drives Fit)
%     Options.TargetModel (1,1) string = "agnostic"  model family passed to Fit
%
%   Output:
%     Recipe - a scalar struct with fields Kind, Apply, Describe, Provider (and
%              Fit when supplied), verified to reproduce and describe FeatureTable
%
%   Errors (raised before returning a recipe):
%     - buildRecipe:invalidProvider          Provider is empty/blank
%     - buildRecipe:fitNotReproducible        supplied Fit does not regenerate the pool
%     - validateRecipe:missingArtifact        a required field is absent/malformed
%     - validateRecipe:poolMismatch           Apply reproduces wrong/missing values
%     - validateRecipe:describeMismatch       Describe lists the wrong features
%   (the validateRecipe:* ids are re-raised from the inline gate, so a caller
%   catches the same ids whether it validated by hand or built through here.)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Apply
        Describe
        Provider (1,1) string
        FeatureTable table
        RawInput
        Options.ResponseVar (1,1) string = ""
        Options.CheckIdx (1,:) double = []
        Options.Fit function_handle = function_handle.empty
        Options.ProblemType (1,1) string = ""
        Options.TargetModel (1,1) string = "agnostic"
    end

    if strlength(strtrim(Provider)) == 0
        error("buildRecipe:invalidProvider", ...
            "Provider must be a non-empty label for the source skill.");
    end

    Recipe = struct( ...
        Kind = "domain", ...
        Apply = Apply, ...
        Describe = Describe, ...
        Provider = Provider);

    % The round-trip gate is the proof: it re-checks presence/shape of Apply and
    % Describe against ground truth and replays Apply on a sample of rows. Capture
    % mode (no SelectedNames) is exactly the four-field contract assembled above.
    validateRecipe(Recipe, FeatureTable, RawInput, ...
        ResponseVar = Options.ResponseVar, CheckIdx = Options.CheckIdx);

    % A supplied Fit unlocks the generation-variance reads, so prove it here: run
    % it on the captured rows and confirm it regenerates the pool's feature names.
    % (Values may differ from the frozen Apply -- Fit REFITS -- so names, not
    % values, are the contract.) Stored only once proven.
    if ~isempty(Options.Fit)
        verifyFit(Options.Fit, FeatureTable, RawInput, ...
            Options.ResponseVar, Options.ProblemType, Options.TargetModel);
        Recipe.Fit = Options.Fit;
    end
end


function verifyFit(Fit, FeatureTable, RawInput, ResponseVar, ProblemType, TargetModel)
%verifyFit Confirm a re-runnable producer regenerates the pool's feature names.
    if ProblemType == ""
        error("buildRecipe:fitNotReproducible", ...
            "ProblemType is required when Fit is supplied (it drives Fit).");
    end
    try
        EngTrain = Fit(RawInput, ResponseVar, ProblemType, TargetModel);
    catch Err
        error("buildRecipe:fitNotReproducible", ...
            "Fit errored when re-run on the captured rows: %s", Err.message);
    end
    if ~istable(EngTrain)
        error("buildRecipe:fitNotReproducible", ...
            "Fit must return an engineered table as its first output.");
    end
    Regen = string(EngTrain.Properties.VariableNames);
    PoolFeatures = setdiff(string(FeatureTable.Properties.VariableNames), ...
        ResponseVar, "stable");
    Missing = setdiff(PoolFeatures, Regen, "stable");
    if ~isempty(Missing)
        error("buildRecipe:fitNotReproducible", ...
            ['Fit does not regenerate the captured pool -- missing feature(s): ' ...
            '%s. It must reproduce the same feature names Apply does.'], ...
            strjoin(Missing, ", "));
    end
end
