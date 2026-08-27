% classifier_branches.m
%
% Assembles the canonical branch table shared by the skill runtime and
% the skill_eval harness. This is a *script*: after
%
%     run(fullfile(skillPath, 'scripts', 'model_catalog', 'classifier_branches.m'))
%
% the caller's workspace contains BRANCHES (struct array, one entry per
% branch) and THRESHOLDS (from classifier_thresholds.m).
%
% Design:
%
%   Each branch_<name>.m file appends exactly one entry to BRANCHES.
%   Branch entries have the shape:
%
%       struct( ...
%           'id',     N, ...
%           'name',   'sparse'|'many_missing'|'categorical'|'wide'|'regular', ...
%           'entry',  @(flags) predicate, ...
%           'models', [recipe1, recipe2, ...])
%
%   Model recipes are built via model_recipe() — see that file for the
%   full schema. The branch dispatch itself is a walk in ID order; the
%   first branch whose entry predicate matches applies. select_regular
%   is the default (entry = @(f) true) and must be listed last.
%
%   Branches DO NOT know about isImbalanced. Imbalanced boosting
%   overrides live in imbalanced_boosting.m — a parallel table applied
%   after the base branch is chosen. Keeping the two tables separate
%   preserves the reviewability of the base branches (they read exactly
%   as they did in the pre-refactor markdown).

% model_recipe() lives alongside the branch tables in scripts/model_catalog/.
% The agent calls build_model_definitions() from scripts/helpers/, which
% run()s this script; while run() executes, cwd is scripts/model_catalog/
% so model_recipe.m resolves from cwd. Do not split these files across
% directories — the branch tables would no longer see model_recipe inside
% the nested run() chain.
CB_HERE = fileparts(mfilename('fullpath'));

run(fullfile(CB_HERE, 'classifier_thresholds.m'));  % populates THRESHOLDS

BRANCHES = struct('id', {}, 'name', {}, 'entry', {}, 'models', {});

run(fullfile(CB_HERE, 'branch_sparse.m'));         % id 0
run(fullfile(CB_HERE, 'branch_many_missing.m'));   % id 1
run(fullfile(CB_HERE, 'branch_categorical.m'));    % id 2
run(fullfile(CB_HERE, 'branch_wide.m'));           % id 3
run(fullfile(CB_HERE, 'branch_regular.m'));        % id 4  (default)

clear CB_HERE

% Copyright 2026 The MathWorks, Inc.
