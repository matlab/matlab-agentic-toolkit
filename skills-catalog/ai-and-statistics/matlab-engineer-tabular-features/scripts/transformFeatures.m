function FeatureTbl = transformFeatures(Recipe, RawInput, Index)
%transformFeatures Apply a pool recipe to new raw data (generator-agnostic).
%
%   FeatureTbl = transformFeatures(Recipe, RawInput) reproduces the FULL feature
%   pool on new raw data, dispatching on the recipe's type so downstream code
%   never has to know which producer built the pool. It is the inference half of
%   the pool contract (describeFeatures is the other half).
%
%   FeatureTbl = transformFeatures(Recipe, RawInput, Index) reproduces only the
%   named (or numerically indexed) subset -- the scoped form. Index is a string
%   array of feature names or a numeric/logical index. The columns come back in
%   the requested order. This is what the selectFeatures entry point calls to
%   deliver the consensus-selected set; scope is just an argument here, not a
%   separate function.
%
%   Recipe is opaque and self-describing:
%     - An SMLT FeatureTransformer (from generateFeatures / gencfeatures /
%       genrfeatures): applied with the transform METHOD. Note the deliberate
%       name overlap -- this function (transformFeatures) is our generic wrapper;
%       transform(...) is the SMLT method it calls. When an Index is given it is
%       passed straight to transform(Recipe, RawInput, Index): the method subsets
%       natively (preserving requested order) and errors on an unknown name with
%       id stats:featlearn:FeatureTransformer:InvalidIndex -- no guard needed on
%       this branch. The SMLT method requires RawInput be a table and errors if
%       it is not.
%     - A domain recipe struct (Kind == "domain"): a captured extraction spec
%       produced when pool-building was routed to a domain skill. Its .Apply
%       field replays the extraction on RawInput to reproduce the full pool; an
%       Index then subsets that table by name, with an explicit missing-column
%       guard (a domain Apply must reproduce columns named identically to the
%       pool it originally produced -- the SMLT transform method guarantees this
%       automatically). If the recipe also carries an optional .ApplySelected
%       handle, a by-name Index uses it to compute ONLY the requested columns
%       (see provider-protocol.md) instead of the full pool; the same guard runs
%       on its output.
%
%   Inputs:
%     Recipe   - FeatureTransformer, or a struct with fields:
%                  .Kind  (1,1) string = "domain"
%                  .Apply (1,1) function_handle mapping the raw data to a
%                         feature table (the replayed extraction)
%     RawInput - new raw data with the inputs the recipe expects. Its form is the
%                recipe's business: an SMLT transformer requires a TABLE, while a
%                domain extraction takes whatever it consumes (table, numeric
%                matrix, cell array, datastore, ...). Left UNCONSTRAINED here so a
%                domain matrix is not silently coerced; the SMLT transform method
%                enforces its own table requirement on that branch.
%     Index    - (optional) feature names (string) or a numeric/logical index of
%                the subset to reproduce; omitted returns the full pool
%
%   Output:
%     FeatureTbl - table of engineered features on RawInput (full pool, or the
%                  requested subset in requested order)

% Copyright 2026 The MathWorks, Inc.

    arguments
        Recipe
        RawInput
        Index = string.empty
    end

    HasIndex = ~isStringEmpty(Index);

    if isa(Recipe, "FeatureTransformer")
        % SMLT artifact -- the transform method is the deterministic recipe and
        % subsets natively when handed an index. It requires a table and errors
        % itself if RawInput is not one.
        if HasIndex
            FeatureTbl = transform(Recipe, RawInput, Index);
        else
            FeatureTbl = transform(Recipe, RawInput);
        end
    elseif isDomainRecipe(Recipe, "Apply")
        % Domain artifact. For a subset request BY NAME, prefer the optional
        % ApplySelected handle -- it computes ONLY the requested columns, sparing a
        % large pool the full-Apply-then-discard cost. Absent it (or for a numeric
        % index, which it is not defined for), replay the full Apply and subset.
        % Either way the same missing-column guard runs, so a selective extractor
        % that omits a requested name fails exactly as the full path would.
        UseSelective = HasIndex && ~(isnumeric(Index) || islogical(Index)) ...
            && isDomainRecipe(Recipe, "ApplySelected");
        if UseSelective
            FeatureTbl = Recipe.ApplySelected(RawInput, string(Index));
            if ~istable(FeatureTbl)
                error("transformFeatures:domainNotTable", ...
                    "The domain recipe's ApplySelected function must return a table.");
            end
            FeatureTbl = subsetDomainPool(FeatureTbl, Index);
        else
            FeatureTbl = Recipe.Apply(RawInput);
            if ~istable(FeatureTbl)
                error("transformFeatures:domainNotTable", ...
                    "The domain recipe's Apply function must return a table.");
            end
            if HasIndex
                FeatureTbl = subsetDomainPool(FeatureTbl, Index);
            end
        end
    else
        error("transformFeatures:unknownRecipe", ...
            ['Recipe must be an SMLT FeatureTransformer or a domain recipe ' ...
            'struct (Kind == "domain" with an Apply function handle).']);
    end
end


function FeatureTbl = subsetDomainPool(FeatureTbl, Index)
%subsetDomainPool Subset a replayed domain pool by name or numeric index.
    if isnumeric(Index) || islogical(Index)
        FeatureTbl = FeatureTbl(:, Index);
        return;
    end
    Names = string(Index);
    Have = string(FeatureTbl.Properties.VariableNames);
    Missing = setdiff(Names, Have, "stable");
    if ~isempty(Missing)
        error("transformFeatures:missingColumns", ...
            ['The reproduced pool is missing selected column(s): %s. A domain ' ...
            'recipe must regenerate columns named identically to the pool it ' ...
            'was selected from.'], strjoin(Missing, ", "));
    end
    FeatureTbl = FeatureTbl(:, Names);
end
