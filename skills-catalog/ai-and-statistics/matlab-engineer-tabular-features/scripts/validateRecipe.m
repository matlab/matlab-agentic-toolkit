function validateRecipe(Recipe, FeatureTable, RawInput, Options)
%validateRecipe Confirm a captured domain recipe reproduces its own pool.
%
%   validateRecipe(Recipe, FeatureTable, RawInput) checks that a captured domain
%   recipe faithfully describes and reproduces the feature pool it was captured
%   from -- on a small sample of rows, value-for-value. It is the semantic gate
%   the structural checks in transformFeatures/describeFeatures cannot provide:
%   those confirm a recipe is well-shaped and name-consistent, but a hand-captured
%   handle that computes the WRONG values (a dropped step, a wrong parameter), or
%   a Describe that lists the wrong features, still passes them. Comparing against
%   the pool actually used for selection is the only check with ground truth.
%
%   The gate runs in TWO MODES, matching the two moments a domain recipe is
%   captured (see domain-routing.md / deliver.md):
%
%   1. Capture / execution mode -- validateRecipe(Recipe, FeatureTable, RawInput).
%      Called right after the pool is built, BEFORE selection. The recipe drives
%      generation, selection, and assessment, all of which need the full pool, so
%      it must carry Kind, Apply, Describe, Provider. Checked against ground truth:
%        - Apply     reproduces every pool feature's VALUES.
%        - Describe  lists exactly the pool's features -- no un-described real
%                    feature, no phantom described one.
%      ApplySelected is NOT expected yet: it is an inference-only path and cannot
%      be built well until the selected set is known (see mode 2).
%
%   2. Deliver mode -- validateRecipe(..., SelectedNames=Names). Called at deliver
%      time with the chosen features. The recipe must ALSO carry an ApplySelected
%      handle targeted at exactly those names, checked to return exactly the
%      SelectedNames columns with the same values Apply would -- the selected-only
%      inference path the emitted script uses.
%
%   Kind and Provider are presence-only (Kind is the type tag; Provider is free
%   text used in report prose, with nothing to verify against the pool).
%
%   Intended for the DOMAIN path only: an SMLT FeatureTransformer needs no check
%   (its transform/describe methods are tested code that reproduce columns by
%   construction), so this returns immediately for one.
%
%   On any problem it throws a hard error naming the offending artifact, because a
%   recipe that cannot reproduce or describe its own pool would ship a broken
%   deliverable. The caller is expected to re-request that artifact from the domain
%   skill and re-validate. Error ids:
%     - validateRecipe:missingArtifact       a required field is absent
%     - validateRecipe:poolMismatch          Apply reproduces wrong/missing values
%     - validateRecipe:describeMismatch       Describe lists the wrong features
%     - validateRecipe:applySelectedMismatch  ApplySelected (deliver mode) disagrees
%                                             with the pool or over-returns columns
%
%   RawInput must be row-aligned with FeatureTable (one raw row per pool row). It
%   is the raw data in whatever form Apply consumes -- a table, a numeric matrix,
%   a cell array, etc. -- and is NOT constrained to a table: the gate only
%   row-indexes it (height + RawInput(Rows,:)), which every row-indexable array
%   supports. Apply's one hard contract is that it RETURNS a table (checked by
%   callHandle); its input type is the extractor's business.
%   Pass Options.CheckIdx = the HELD-OUT (test) row indices: replaying Apply on
%   training rows can legitimately disagree with the pool when the extraction used
%   response-based out-of-fold encoding (train rows hold out-of-fold values, Apply
%   replays the full map), which would be a false mismatch. Held-out rows are
%   transformed the same way at capture and inference, so they compare cleanly.
%
%   Inputs:
%     Recipe       - a domain recipe struct (Kind=="domain" with an Apply handle);
%                    anything else needs no check and returns
%     FeatureTable - the materialized pool the recipe was captured from
%                    (predictors + response), one row per observation
%     RawInput     - the raw data Apply consumes (any row-indexable form: table,
%                    matrix, cell array, ...), row-aligned with FeatureTable
%     Options.SelectedNames (1,:) string = []  the chosen features; supplying them
%                                               switches on deliver mode (require +
%                                               validate ApplySelected against them)
%     Options.ResponseVar   (1,1) string = ""   response column, excluded from the
%                                               feature set if present
%     Options.CheckIdx      (1,:) double = []   rows to check; default is an
%                                               evenly-spaced sample across all rows
%     Options.NumSampleRows (1,1) double = 32   sample-size cap (kept small)
%     Options.RelTol        (1,1) double = 1e-9 relative tolerance for numeric cols

% Copyright 2026 The MathWorks, Inc.

    arguments
        Recipe
        FeatureTable table
        RawInput
        Options.SelectedNames (1,:) string = string.empty
        Options.ResponseVar (1,1) string = ""
        Options.CheckIdx (1,:) double = []
        Options.NumSampleRows (1,1) double = 32
        Options.RelTol (1,1) double = 1e-9
    end

    DeliverMode = ~isempty(Options.SelectedNames);

    % Only a hand-captured domain recipe carries the faithfulness risk this gate
    % addresses; an SMLT transformer reproduces columns by construction.
    if ~isDomainRecipe(Recipe)
        return;
    end

    % Required fields depend on the mode (Kind is already assured by isDomainRecipe
    % above; Provider is presence-only free text). Capture/execution mode needs the
    % full-pool artifacts; deliver mode additionally needs ApplySelected, which is
    % only buildable once the selected set is known.
    Required = ["Apply", "Describe", "Provider"];
    if DeliverMode
        Required(end+1) = "ApplySelected";
    end
    AbsentFields = Required(arrayfun(@(F) ~isfield(Recipe, F), Required));
    if ~isempty(AbsentFields)
        error("validateRecipe:missingArtifact", ...
            "The domain recipe is missing required field(s): %s.", ...
            strjoin(AbsentFields, ", "));
    end
    if ~isa(Recipe.Apply, "function_handle")
        error("validateRecipe:missingArtifact", "Apply must be a function handle.");
    end
    if DeliverMode && ~isa(Recipe.ApplySelected, "function_handle")
        error("validateRecipe:missingArtifact", ...
            "ApplySelected must be a function handle.");
    end

    if height(RawInput) ~= height(FeatureTable)
        error("validateRecipe:rowMisalignment", ...
            ['RawInput has %d rows but the pool has %d; Apply maps raw rows to ' ...
            'pool rows one-for-one, so they must align.'], ...
            height(RawInput), height(FeatureTable));
    end

    % Ground truth: the pool's feature columns (everything bar the response).
    FeatureNames = string(FeatureTable.Properties.VariableNames);
    FeatureNames = FeatureNames(FeatureNames ~= Options.ResponseVar);

    Rows = sampleRows(height(FeatureTable), Options.CheckIdx, Options.NumSampleRows);
    RawSample = RawInput(Rows, :);
    PoolSample = FeatureTable(Rows, :);

    % 1. Apply -- reproduces every pool feature's values.
    Full = callHandle(Recipe.Apply, {RawSample}, "Apply");
    [Missing, Diverged] = compareColumns(Full, PoolSample, FeatureNames, Options.RelTol);
    if ~isempty(Missing) || ~isempty(Diverged)
        error("validateRecipe:poolMismatch", ...
            ['Apply does not reproduce the captured pool: %s. Re-capture Apply ' ...
            'from the domain skill.'], missDivMsg(Missing, Diverged));
    end

    % 2. Describe -- lists exactly the pool's features.
    Described = string(Recipe.Describe.Feature(:)).';
    Undescribed = setdiff(FeatureNames, Described, "stable");   % real, not listed
    Phantom = setdiff(Described, FeatureNames, "stable");       % listed, not real
    if ~isempty(Undescribed) || ~isempty(Phantom)
        error("validateRecipe:describeMismatch", ...
            ['Describe does not match the pool%s%s. Re-capture Describe from ' ...
            'the domain skill.'], ...
            listPart(" -- missing feature(s): ", Undescribed), ...
            listPart(" -- feature(s) not in pool: ", Phantom));
    end

    % Capture mode stops here -- ApplySelected is validated only in deliver mode.
    if ~DeliverMode
        return;
    end

    % 3. ApplySelected (deliver mode) -- the selected-only inference path. The set
    % is now known, so check it directly: asked for exactly SelectedNames, it must
    % return exactly those columns (no over-return -- a handle that ignores its
    % argument and dumps the whole pool defeats the point) with the same values
    % Apply gives. SelectedNames must be actual pool features.
    Selected = Options.SelectedNames;
    NotInPool = setdiff(Selected, FeatureNames, "stable");
    if ~isempty(NotInPool)
        error("validateRecipe:applySelectedMismatch", ...
            'SelectedNames contains non-pool feature(s): %s.', ...
            strjoin(NotInPool, ", "));
    end
    Sel = callHandle(Recipe.ApplySelected, {RawSample, Selected}, "ApplySelected");
    Returned = string(Sel.Properties.VariableNames);
    if ~isempty(setdiff(Returned, Selected, "stable"))
        error("validateRecipe:applySelectedMismatch", ...
            ['ApplySelected returned columns beyond the %d requested (%d back). ' ...
            'It must return only the selected columns; re-request it from the ' ...
            'domain skill.'], numel(Selected), numel(Returned));
    end
    [Missing, Diverged] = compareColumns(Sel, PoolSample, Selected, Options.RelTol);
    if ~isempty(Missing) || ~isempty(Diverged)
        error("validateRecipe:applySelectedMismatch", ...
            ['ApplySelected disagrees with the pool: %s. It must return the same ' ...
            'values Apply does for the selected columns; re-request it from the ' ...
            'domain skill.'], missDivMsg(Missing, Diverged));
    end
end


function Out = callHandle(Handle, ArgList, Name)
%callHandle Invoke a recipe handle and require a table result.
    Out = Handle(ArgList{:});
    if ~istable(Out)
        error("validateRecipe:domainNotTable", ...
            "The domain recipe's %s function must return a table.", Name);
    end
end


function [Missing, Diverged] = compareColumns(Actual, PoolSample, Names, RelTol)
%compareColumns Which requested names are absent from / diverge from the pool.
    Have = string(Actual.Properties.VariableNames);
    Missing = setdiff(Names, Have, "stable");
    Diverged = string.empty;
    for Name = setdiff(Names, Missing, "stable")
        if ~columnsMatch(PoolSample.(Name), Actual.(Name), RelTol)
            Diverged(end+1) = Name; %#ok<AGROW>
        end
    end
end


function Rows = sampleRows(N, CheckIdx, Cap)
%sampleRows Up to Cap rows to check: the caller's set (capped), or an evenly-
%   spaced sweep across all N rows when none is given.
    if ~isempty(CheckIdx)
        Pool = unique(CheckIdx(:).', "stable");
    else
        Pool = 1:N;
    end
    if numel(Pool) > Cap
        Pick = round(linspace(1, numel(Pool), Cap));
        Pool = Pool(unique(Pick, "stable"));
    end
    Rows = Pool;
end


function Tf = columnsMatch(Expected, Actual, RelTol)
%columnsMatch Compare one pool column against its reproduction: tolerant on
%   floats, exact otherwise.
    if numel(Expected) ~= numel(Actual)
        Tf = false;
        return;
    end
    if isnumeric(Expected) && isnumeric(Actual)
        E = double(Expected(:));
        A = double(Actual(:));
        Scale = max(1, abs(E));
        Both = ~isnan(E) & ~isnan(A);
        Tf = all(isnan(E) == isnan(A)) ...
            && all(abs(E(Both) - A(Both)) <= RelTol .* Scale(Both));
    else
        Tf = isequal(Expected, Actual);
    end
end


function Msg = missDivMsg(Missing, Diverged)
%missDivMsg One-line account of missing and value-diverged columns.
    Msg = strtrim(listPart("missing ", Missing) + listPart(" wrong-valued ", Diverged));
    if Msg == ""
        Msg = "no columns";
    end
end


function Part = listPart(Label, Names)
%listPart "<Label>a, b" for a non-empty name list, else "".
    if isempty(Names)
        Part = "";
    else
        Part = Label + strjoin(Names, ", ");
    end
end
