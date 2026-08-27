function MatPath = saveResults(Results, OutputDir, Options)
%saveResults Persist the full run Results struct to fe_results_<dataset>.mat.
%
%   MatPath = saveResults(Results, OutputDir) writes the complete Results
%   struct -- every phase's output verbatim (vote table, selection frequency,
%   quality, baseline/k-fold, deliverables, ...) -- to
%   <OutputDir>/fe_results_<dataset>.mat and returns its path.
%
%   This is the machine-readable companion to the written report: the report
%   previews the top features, but this .mat holds every table at full
%   resolution, so nothing shown in a plot or a truncated table is lost. It is
%   saved UNCONDITIONALLY -- on a report opt-out the report and its figures are
%   skipped, but this file still ships, so a run's numbers are always recoverable.
%   Load it and inspect the Results struct:
%
%       S = load("fe_results_<dataset>.mat");
%       S.Results.VoteTable                 % complete consensus vote
%       S.Results.SelStab.SelectionFrequency % complete per-feature stability
%
%   Inputs:
%     Results   (1,1) struct  - the assembled run Results (see generateFeatureReport)
%     OutputDir (1,1) string  - destination folder (created if absent)
%     Options.DatasetName (1,1) string = "dataset"  names the file; sanitized to
%                                                    a valid identifier, matching
%                                                    the fe_transform_<dataset> pair
%
%   Output:
%     MatPath - full path to the written .mat

% Copyright 2026 The MathWorks, Inc.

    arguments
        Results (1,1) struct
        OutputDir (1,1) string
        Options.DatasetName (1,1) string = "dataset"
    end

    if ~isfolder(OutputDir)
        mkdir(OutputDir);
    end

    % Share the fe_transform_<dataset> stem-sanitizing rule so the results file
    % sits alongside the inference pair under one recognizable dataset label.
    Stem = "fe_results_" + matlab.lang.makeValidName(Options.DatasetName);
    MatPath = fullfile(OutputDir, Stem + ".mat");
    save(MatPath, "Results");

    fprintf('Wrote full results to       %s\n', MatPath);
end
