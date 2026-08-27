function [WorkingIdx, UserHeldOutIdx, Info] = reserveHoldoutForUser(T, ProblemType, Response, Options)
%reserveHoldoutForUser Set aside an untouched slice for the user's own testing.
%
%   [WorkingIdx, UserHeldOutIdx, Info] = reserveHoldoutForUser(T, ProblemType,
%   Response) is the LEVEL-0 carve that runs once, before the pipeline's own
%   evaluation split. It answers a single question decided at intake: does the
%   user already have a separate test set?
%
%     HAS a separate test set (ReserveForUser=false): carve nothing. WorkingIdx
%       spans every row and UserHeldOutIdx is empty -- the whole dataset is the
%       pipeline's working data.
%
%     NO separate test set (ReserveForUser=true, the default): carve a stratified
%       (classification) or random (regression) HoldoutFraction slice and set it
%       aside UNTOUCHED. Those rows are handed back to the user for their own
%       downstream testing and are never seen again by this skill -- not by
%       generation, selection, assessment, or the final refit. The remaining rows
%       become WorkingIdx, the pipeline's "whole dataset" from here on.
%
%   The carve is a RANDOM SAMPLE, not a contiguous block: cvpartition draws the
%   held-out rows from across the whole dataset (stratified by class for
%   classification), so a dataset that arrives sorted by response or by time does
%   not hand the user one end of it. Seed rng at the orchestration layer (see
%   REPRODUCIBILITY below) to make that draw repeat run to run.
%
%   This is deliberately ABOVE splitStrategy: the pipeline's own holdout / k-fold
%   evaluation (Level 1) operates only on WorkingIdx, so "all working data" never
%   includes the user's reserved slice. The two levels compose --
%   no-separate-test + holdout means the working 80% is itself split again.
%
%   Options:
%     ReserveForUser  (1,1) logical         - carve the untouched slice (default
%                       true). Set false when the user supplies their own separate
%                       test set, so the full dataset is working data.
%     HoldoutFraction (1,1) double in (0,1) - reserved fraction (default 0.2).
%
%   REPRODUCIBILITY. The carve is a random draw (stratified for classification).
%   Seed the global generator ONCE at the orchestration layer before calling this
%   -- as the assessment partitions are seeded -- so the same dataset yields the
%   same carve. This function does not touch rng itself; controlling randomness in
%   one place keeps the whole run reproducible without functions fighting over the
%   generator.
%
%   Outputs:
%     WorkingIdx     - (:,1) global row indices the pipeline runs on
%     UserHeldOutIdx - (:,1) global row indices set aside untouched (empty when
%                      ReserveForUser=false)
%     Info           - struct(.Reserved logical, .Fraction, .Method, .NumWorking,
%                      .NumHeldOut, .Reasoning) for reporting the carve

% Copyright 2026 The MathWorks, Inc.

    arguments
        T table
        ProblemType (1,1) string {mustBeMember(ProblemType, ["classification","regression"])}
        Response (1,1) string
        Options.ReserveForUser (1,1) logical = true
        Options.HoldoutFraction (1,1) double {mustBePositive, mustBeLessThan(Options.HoldoutFraction, 1)} = 0.2
    end

    NRows = height(T);

    if ~Options.ReserveForUser
        WorkingIdx = (1:NRows)';
        UserHeldOutIdx = zeros(0, 1);
        Info = struct( ...
            Reserved = false, ...
            Fraction = 0, ...
            Method = "none", ...
            NumWorking = NRows, ...
            NumHeldOut = 0, ...
            Reasoning = sprintf(['User supplied a separate test set; no rows reserved, ' ...
                'all %d rows are working data'], NRows));
        printReserveSummary(Info);
        return
    end

    % cvpartition samples random rows (stratified for classification), so a
    % dataset arriving sorted by response or time is still split across its whole
    % range, not handed one end of it. Reproducibility is the CALLER'S job: seed
    % rng once at the orchestration layer before this call (as the assessment
    % partitions are seeded), so the whole run's randomness is controlled in one
    % place rather than each function reaching for the generator itself.
    if ProblemType == "classification"
        Cv = cvpartition(T.(Response), Holdout=Options.HoldoutFraction);
        Method = "stratified";
    else
        Cv = cvpartition(NRows, Holdout=Options.HoldoutFraction);
        Method = "random";
    end
    WorkingIdx = find(training(Cv));
    UserHeldOutIdx = find(test(Cv));

    Info = struct( ...
        Reserved = true, ...
        Fraction = Options.HoldoutFraction, ...
        Method = Method, ...
        NumWorking = numel(WorkingIdx), ...
        NumHeldOut = numel(UserHeldOutIdx), ...
        Reasoning = sprintf(['No separate test set; reserved %.0f%% (%d rows, %s) UNTOUCHED ' ...
            'for the user''s own testing, %d rows are working data'], ...
            100 * Options.HoldoutFraction, numel(UserHeldOutIdx), Method, numel(WorkingIdx)));
    printReserveSummary(Info);
end


function printReserveSummary(Info)
    if Info.Reserved
        fprintf('Reserved for user: %d rows (%.0f%%, %s) set aside untouched | Working=%d\n', ...
            Info.NumHeldOut, 100 * Info.Fraction, Info.Method, Info.NumWorking);
    else
        fprintf('Reserved for user: none (separate test set supplied) | Working=%d\n', ...
            Info.NumWorking);
    end
    fprintf('  Reasoning: %s\n', Info.Reasoning);
end
