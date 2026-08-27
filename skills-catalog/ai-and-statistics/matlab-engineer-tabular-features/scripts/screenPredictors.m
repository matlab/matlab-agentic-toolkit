function [ScreenedTbl, ScreenInfo] = screenPredictors(Predictors, Response, Options)
%screenPredictors Assemble the table and drop degenerate predictors (intake).
%
%   [ScreenedTbl, ScreenInfo] = screenPredictors(RawTbl, Response) returns RawTbl
%   with two kinds of useless predictor removed, so the generator and the
%   consensus selector never waste effort on columns that carry no signal:
%     - CONSTANT predictors: at most one distinct non-missing value (zero
%       variance -- nothing to learn from, and a source of degenerate transforms).
%     - MOSTLY-MISSING predictors: more than MissingThreshold (default 0.95) of
%       the rows missing -- effectively empty, nothing to engineer or impute. The
%       cutoff is deliberately high: many learners (and the generator's own
%       imputation) handle moderately-missing columns natively, so intake only
%       drops the near-empty ones and leaves the missingness call to the producer.
%
%   Response is polymorphic. When it is a scalar string or char (a NAME), it
%   identifies the response column already in Predictors (current behavior above;
%   a Wilkinson formula is accepted). When it is anything else -- a column vector
%   of values (numeric / categorical / logical / string labels / ...) or a
%   single-variable table -- it is treated as the response DATA supplied
%   separately, and is CONCATENATED to Predictors before screening. This handles
%   the common intake shape of an X table plus a y vector: a nameless vector is
%   appended under Options.ResponseName (default "Response"), while a
%   single-variable table keeps its own variable name. Downstream sees one
%   assembled predictors + response table either way.
%
%   This is a light-weight, structural screen run at INTAKE, on the raw input
%   predictors, before problem profiling / splitting / generation. It is NOT
%   response-dependent (it never inspects the response values), so running it on
%   the whole table before the train/test split introduces no leakage. The
%   response column is always kept, whatever its contents.
%
%   Screening is deliberately minimal: everything else (imputation, encoding,
%   scaling, richer feature construction) is delegated to the generator
%   (gencfeatures) or a domain skill. This step only removes columns that would
%   be dead weight for any producer.
%
%   Inputs:
%     Predictors - table of raw predictors. When Response is a NAME it must also
%                  contain that response column; when Response is DATA it holds
%                  predictors only.
%     Response   - either a response variable NAME (scalar string/char; a
%                  Wilkinson formula is accepted, its left-hand side naming the
%                  column to protect) already in Predictors, OR the response DATA
%                  supplied separately (a column vector or single-variable table,
%                  height matching Predictors) to concatenate before screening. A
%                  single-variable table is SELF-NAMING: its variable name becomes
%                  the response column name.
%     Options.ResponseName - (1,1) string, the column name under which a NAMELESS
%                  response vector is appended. Default "Response". Ignored when
%                  Response is a name, or a single-variable table (which names
%                  itself).
%     Options.MissingThreshold - (1,1) double in [0,1], the missing-fraction above
%                  which a predictor is dropped. Default 0.95 (drop when strictly
%                  more than 95% of rows are missing). Kept high on purpose:
%                  models with native missing handling and the generator's
%                  imputation can use moderately-missing columns, so only the
%                  near-empty ones are pruned here.
%     Options.ConstantTolerance - (1,1) nonnegative double, the tolerance for the
%                  constant check on NUMERIC columns. A numeric column is constant
%                  when its spread (max - min of present values) is at most
%                  ConstantTolerance * max(scale, 1), where scale is the largest
%                  absolute present value. Default 1e-9 (catches floating-point
%                  noise around a genuinely single value without pruning columns
%                  that carry real, if small, variation). Non-numeric columns
%                  ignore this and use an exact distinct-value count.
%
%   Outputs:
%     ScreenedTbl - the assembled predictors + response with dropped predictors
%                   removed (survivor column order, and the response, preserved)
%     ScreenInfo  - struct with fields:
%                     .Kept            - string array of kept predictor names
%                     .Dropped         - string array of dropped predictor names
%                     .DroppedReasons  - string array parallel to .Dropped
%                                        ("constant" | "missing>NN%")
%                     .NumDropped      - number of predictors dropped
%                     .MissingThreshold- the missing-fraction threshold applied
%                     .ConstantTolerance- the numeric constant tolerance applied
%                     .CombinedResponse- true if ResponseData was appended here
%                     .ResponseVar     - the resolved response column name
%                     .Reasoning       - human-readable summary
%
%   Errors with id screenPredictors:tooFewObservations if the assembled table has
%   fewer than 2 rows, and with id screenPredictors:noPredictorsRemain if every
%   predictor is dropped (neither can proceed to generation/selection).

% Copyright 2026 The MathWorks, Inc.

    arguments
        Predictors table
        Response
        Options.ResponseName (1,1) string = "Response"
        Options.MissingThreshold (1,1) double {mustBeGreaterThanOrEqual(Options.MissingThreshold, 0), ...
            mustBeLessThanOrEqual(Options.MissingThreshold, 1)} = 0.95
        Options.ConstantTolerance (1,1) double {mustBeNonnegative} = 1e-9
    end

    % Response is a NAME (scalar string/char) -> already a column of Predictors;
    % otherwise it is response DATA supplied separately -> concatenate it.
    CombinedResponse = ~isResponseName(Response);
    if CombinedResponse
        [RawTbl, ResponseVar] = combineResponse(Predictors, Options.ResponseName, Response);
    else
        RawTbl = Predictors;
        ResponseVar = resolveResponseName(string(Response), RawTbl);
    end

    % Too few observations to do anything meaningful (generate, split, rank).
    % Guard the assembled table BEFORE screening...
    checkEnoughRows(RawTbl);

    AllVars = string(RawTbl.Properties.VariableNames);
    PredictorVars = AllVars(AllVars ~= ResponseVar);

    Dropped = string.empty(1, 0);
    DroppedReasons = string.empty(1, 0);
    MissingPct = round(100 * Options.MissingThreshold);

    for Name = PredictorVars
        Col = RawTbl.(Name);
        MissingFraction = mean(ismissing(Col));
        if MissingFraction > Options.MissingThreshold
            Dropped(end+1) = Name; %#ok<AGROW>
            DroppedReasons(end+1) = sprintf("missing>%d%%", MissingPct); %#ok<AGROW>
        elseif isConstantColumn(Col, Options.ConstantTolerance)
            Dropped(end+1) = Name; %#ok<AGROW>
            DroppedReasons(end+1) = "constant"; %#ok<AGROW>
        end
    end

    Kept = setdiff(PredictorVars, Dropped, "stable");
    if isempty(Kept)
        error("screenPredictors:noPredictorsRemain", ...
            ['All %d predictor(s) were dropped as constant or mostly-missing; ' ...
            'no usable predictor remains to engineer features from.'], ...
            numel(PredictorVars));
    end

    % Keep the survivors in their original order, response included.
    ScreenedTbl = RawTbl(:, [Kept, ResponseVar]);

    % ...and again AFTER screening. Screening never removes rows, so this is a
    % defensive invariant on the delivered table rather than a second filter.
    checkEnoughRows(ScreenedTbl);

    ScreenInfo = struct( ...
        Kept = Kept, ...
        Dropped = Dropped, ...
        DroppedReasons = DroppedReasons, ...
        NumDropped = numel(Dropped), ...
        MissingThreshold = Options.MissingThreshold, ...
        ConstantTolerance = Options.ConstantTolerance, ...
        CombinedResponse = CombinedResponse, ...
        ResponseVar = ResponseVar, ...
        Reasoning = buildReasoning(Kept, Dropped, DroppedReasons, MissingPct));

    fprintf('Intake screen: kept %d predictor(s), dropped %d (constant / >%d%% missing).\n', ...
        numel(Kept), numel(Dropped), MissingPct);
end


function Tf = isConstantColumn(Col, Tolerance)
%isConstantColumn True when a column has at most one distinct non-missing value.
%   Works for numeric, categorical, string, and other scalar-valued columns; an
%   all-missing column reads as constant, but the missing screen catches those
%   first, so this only fires on genuinely single-valued columns.
%
%   NUMERIC columns use a scale-relative TOLERANCE rather than exact equality: a
%   column is constant when the spread (max - min) of its present values is at
%   most Tolerance * max(scale, 1), where scale is the largest absolute present
%   value. This treats floating-point noise around one value as constant without
%   demanding bit-exact repeats, and the scaling keeps the test meaningful for
%   both tiny- and large-magnitude columns. Non-numeric columns (categorical,
%   string, logical, ...) have no meaningful tolerance and use an exact
%   distinct-value count.
    Present = Col(~ismissing(Col));
    if isnumeric(Present)
        if numel(Present) <= 1
            Tf = true;
            return;
        end
        Spread = max(Present) - min(Present);
        Scale = max(abs(Present), [], "omitnan");
        Tf = Spread <= Tolerance * max(Scale, 1);
    else
        Tf = numel(unique(Present)) <= 1;
    end
end


function ResponseVar = resolveResponseName(Response, RawTbl)
%resolveResponseName Extract the response variable name from a name or formula.
    Response = string(Response);
    if contains(Response, "~")
        Parts = split(Response, "~");
        ResponseVar = strtrim(Parts(1));
    else
        ResponseVar = strtrim(Response);
    end
    if ~ismember(ResponseVar, string(RawTbl.Properties.VariableNames))
        error("screenPredictors:responseNotFound", ...
            'Response variable "%s" is not a column of the input table.', ResponseVar);
    end
end


function checkEnoughRows(Tbl)
%checkEnoughRows Halt when a table has fewer than 2 observations.
%   Called on the assembled table before screening and on the screened table
%   after, so a too-small dataset is refused at both boundaries.
    if height(Tbl) < 2
        error("screenPredictors:tooFewObservations", ...
            ['Input has %d observation(s); at least 2 are required to engineer ' ...
            'and select features.'], height(Tbl));
    end
end


function Tf = isResponseName(Response)
%isResponseName True when Response is a NAME (scalar string / char row) rather
%   than response DATA. A string ARRAY (vector of labels) reads as data, matching
%   the rule "a vector is a separately-supplied response".
    Tf = (isstring(Response) && isscalar(Response)) || (ischar(Response) && isrow(Response));
end


function [RawTbl, ResponseVar] = combineResponse(Predictors, ResponseName, ResponseData)
%combineResponse Append a separately-supplied response to the predictor table.
%   ResponseData is a raw column vector (nameless) or a single-variable table
%   (self-naming), with height matching Predictors. A single-variable table
%   carries its own variable name, which is honored as the response column name;
%   a nameless vector is named by ResponseName. The response is appended as the
%   last column and its name must not collide with an existing predictor.

    % Accept a single-variable table (self-naming) or a raw column vector.
    if istable(ResponseData)
        if width(ResponseData) ~= 1
            error("screenPredictors:responseDataNotSingleVar", ...
                "A response table must have exactly one variable.");
        end
        ResponseVar = string(ResponseData.Properties.VariableNames(1));
        ResponseCol = ResponseData{:, 1};
    else
        ResponseVar = strtrim(string(ResponseName));
        ResponseCol = ResponseData;
    end

    if ismember(ResponseVar, string(Predictors.Properties.VariableNames))
        error("screenPredictors:responseNameCollision", ...
            'Response name "%s" already exists in the predictor table.', ResponseVar);
    end
    if size(ResponseCol, 1) ~= height(Predictors)
        error("screenPredictors:responseHeightMismatch", ...
            'The response has %d rows but the predictor table has %d.', ...
            size(ResponseCol, 1), height(Predictors));
    end

    RawTbl = Predictors;
    RawTbl.(ResponseVar) = ResponseCol;
end


function Reasoning = buildReasoning(Kept, Dropped, DroppedReasons, MissingPct)
%buildReasoning Compose a one-paragraph, human-readable screen summary.
    if isempty(Dropped)
        Reasoning = sprintf("No predictors screened out: all %d are non-constant " + ...
            "and at most %d%% missing.", numel(Kept), MissingPct);
        return;
    end
    Parts = strings(1, numel(Dropped));
    for i = 1:numel(Dropped)
        Parts(i) = sprintf("%s (%s)", Dropped(i), DroppedReasons(i));
    end
    Reasoning = sprintf("Dropped %d of %d predictors: %s. Kept %d.", ...
        numel(Dropped), numel(Kept) + numel(Dropped), ...
        strjoin(Parts, ", "), numel(Kept));
end
