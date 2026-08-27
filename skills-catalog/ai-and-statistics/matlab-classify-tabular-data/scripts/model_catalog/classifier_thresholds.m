% classifier_thresholds.m
%
% Numeric thresholds shared by the skill runtime and the skill_eval
% harness. This is the ONE place where these constants are defined —
% narrative documents that reference a threshold must name the field
% (e.g. "when N > THRESHOLDS.big_N") and not the number, so that a
% threshold change is a single-file edit.
%
% This file is a *script*: `run(fullfile(skillPath, 'scripts',
% 'model_catalog', 'classifier_thresholds.m'))` populates THRESHOLDS in
% the caller's workspace. Do not add function keywords.

THRESHOLDS = struct();

% Data-shape thresholds (mirror what compute_data_flags.m uses)
THRESHOLDS.wide_D_over_N       = 1;      % isWide when D >= N
THRESHOLDS.highD_D             = 100;    % isHighD when D > highD_D
THRESHOLDS.big_N               = 50000;  % isBig when N > big_N
THRESHOLDS.many_missing_frac   = 0.05;   % hasManyMissing when frac > 0.05

% Class-balance thresholds
THRESHOLDS.imbalance_ratio           = 5;    % isImbalanced when max/min > 5
THRESHOLDS.extreme_imbalance_ratio   = 500;  % advisory when ratio > 500
THRESHOLDS.extreme_smallest_class    = 30;   % advisory when smallestClass < 30
THRESHOLDS.rusboost_smallest_class   = 100;  % RUSBoost only when smallestClass >= 100
THRESHOLDS.exclude_class_min         = 100;  % extreme-imbalance advisory: suggest excluding classes with fewer than this many observations

% Branch-inclusion thresholds
THRESHOLDS.standardized_svm_N        = 10000;  % wide-branch StandardizedSVM only when N <= 10000
THRESHOLDS.wide_knn_N                = 50000;  % wide-branch KNN only when N <= 50000
THRESHOLDS.wide_knn_smallest_class   = 100;    % wide-branch KNN only when smallestClass >= 100
THRESHOLDS.cat_svm_nn_levels         = 100;    % categorical branch drops SVM/NN when totalCatLevels > 100

% Evaluation-strategy threshold
THRESHOLDS.holdout_smallest_class    = 300;    % recommend holdout when smallestClass > 300; else CV

% Subsampling threshold (used with isBig)
THRESHOLDS.subsample_smallest_class  = 100;    % subsample only when smallestClass >= 100
THRESHOLDS.subsample_total           = 20000;  % target: floor(subsample_total / nClasses) per class

% Copyright 2026 The MathWorks, Inc.
