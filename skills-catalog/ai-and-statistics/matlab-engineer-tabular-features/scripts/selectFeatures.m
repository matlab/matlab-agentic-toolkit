function FeatureTbl = selectFeatures(Recipe, RawInput, SelectedNames)
%selectFeatures Reproduce the pool and filter to the delivered feature set.
%
%   FeatureTbl = selectFeatures(Recipe, RawInput, SelectedNames) is the complete
%   inference operation: it reproduces the full feature pool on new raw data with
%   transformFeatures, then subsets to the consensus-selected columns. This is
%   the one call an inference deliverable makes -- the two contract halves
%   (reproduce, then filter) composed.
%
%   Filtering is generator-agnostic: whatever produced the pool, the selected set
%   is a pure column subset by name. This is the one product-agnostic inference
%   entry point -- an inference deliverable makes exactly this call, whatever
%   built the pool. It delegates to the scoped form of transformFeatures, which
%   pushes the subset all the way down: for an SMLT FeatureTransformer the
%   selected names go straight to the transform method (native subset, in
%   requested order, native unknown-name error); for a domain recipe the replayed
%   pool is subset by name.
%
%   Filtering may be a no-op. When selection kept every feature (common for a
%   small, well-motivated pool), SelectedNames covers the whole pool and the
%   returned table equals the full reproduced pool -- reordered to SelectedNames.
%   That is a correct outcome, not a degenerate one; selection evaluates the
%   pool, it does not have to shrink it.
%
%   Inputs:
%     Recipe        - opaque pool recipe (SMLT FeatureTransformer or domain recipe
%                     struct); see transformFeatures
%     RawInput      - new raw data with the inputs the recipe expects. Form is the
%                     recipe's business (SMLT: a table; domain: whatever the
%                     extraction consumes). Left UNCONSTRAINED here so a domain
%                     matrix is not silently coerced; transformFeatures / the SMLT
%                     transform method enforce their own requirements.
%     SelectedNames - (1,:) string, the delivered feature column names
%
%   Output:
%     FeatureTbl - table of the selected engineered features on RawInput, columns
%                  in SelectedNames order

% Copyright 2026 The MathWorks, Inc.

    arguments
        Recipe
        RawInput
        SelectedNames (1,:) string
    end

    FeatureTbl = transformFeatures(Recipe, RawInput, SelectedNames);
end
