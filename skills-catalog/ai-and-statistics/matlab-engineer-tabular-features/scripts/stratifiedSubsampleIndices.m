function Sets = stratifiedSubsampleIndices(Response, M, Fraction)
%stratifiedSubsampleIndices M stratified subsamples WITHOUT replacement.
%
%   Sets = stratifiedSubsampleIndices(Response, M, Fraction) returns a 1-by-M cell
%   array; Sets{m} is a column vector of row indices for the m-th subsample, drawn
%   WITHOUT replacement at the target size floor(Fraction*n) with class
%   proportions preserved. This is the single resampling scheme both stability
%   reads use -- the fixed-pool selection-stability read (assessSelectionStability)
%   and the full-pipeline generation-stability read (assessGenerationStability) --
%   so that, run with the SAME M and Fraction, they estimate their two Nogueira
%   indices over the same resampling scheme and the two are comparable (their gap
%   is the generation-variance read).
%
%   WHY SUBSAMPLING, NOT K-FOLD. K-fold complements share ~(K-1)/K of their rows
%   (~80% at K=5); that heavy overlap inflates the Nogueira stability index into
%   an optimistic upper bound rather than an honest estimate. Subsampling without
%   replacement at half size (Fraction=0.5) is the lowest-overlap perturbation
%   (~0.33 pairwise Jaccard) and carries NO duplicate rows -- duplicates distort
%   distance/MI-based rankers, which a with-replacement bootstrap would inject.
%   See the technical-audit stability-subsampling design note for the study that
%   settled this.
%
%   STRATIFICATION. When Response is categorical / logical / string, each
%   subsample preserves class proportions via cvpartition(Response, Holdout=.);
%   this matters on imbalanced data, where an unstratified draw can starve the
%   minority class and report "the class got thin" as "the selector is unstable".
%   For a continuous (regression) response the draw is a plain stratification-free
%   subsample over the row count, matching the rest of the skill's regression path.
%
%   Inputs:
%     Response - (n,1) response vector over the rows to resample. Its TYPE decides
%                stratification (categorical/logical/string -> stratified). The
%                caller passes the working table's response so Sets index straight
%                into that table (and into any row-aligned engineered/raw table).
%     M        - (1,1) positive integer, number of subsamples to draw
%     Fraction - (1,1) double in (0,1), target subsample size as a fraction of n
%                (default 0.5 -- strict n/2, the lowest-overlap honest read)
%
%   Output:
%     Sets - (1,M) cell, each a column vector of row indices (no replacement)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Response (:,1) {mustBeVector}
        M (1,1) double {mustBePositive, mustBeInteger}
        Fraction (1,1) double {mustBePositive} = 0.5
    end

    if Fraction >= 1
        error('stratifiedSubsampleIndices:fractionOutOfRange', ...
            'Fraction must be in (0,1); got %g.', Fraction);
    end

    n = numel(Response);
    Stratify = iscategorical(Response) || islogical(Response) ...
        || isstring(Response) || iscellstr(Response);

    Sets = cell(1, M);
    for m = 1:M
        if Stratify
            % Holdout = 1-Fraction leaves a training portion of size Fraction*n,
            % class proportions preserved; take that stratified training side.
            Part = cvpartition(Response, Holdout = 1 - Fraction);
        else
            Part = cvpartition(n, Holdout = 1 - Fraction);
        end
        Sets{m} = find(training(Part));
    end
end
