function DescTbl = describeFeatures(Recipe, Index)
%describeFeatures Human-readable feature definitions (generator-agnostic).
%
%   DescTbl = describeFeatures(Recipe) returns a table with variables
%   Feature | Type | Definition -- one row per engineered feature in the FULL
%   pool -- dispatching on the recipe's type so downstream code (the report's
%   Selected Feature Definitions chapter) never has to know which producer built
%   the pool. It is the description half of the pool contract (transformFeatures
%   is the inference half).
%
%   DescTbl = describeFeatures(Recipe, Index) returns only the named (or
%   numerically indexed) subset, rows in the requested order -- the scoped form
%   the report uses to document just the consensus-selected features. Scope is an
%   argument here, mirroring transformFeatures.
%
%   Recipe is opaque and self-describing:
%     - An SMLT FeatureTransformer: its describe() table (Type | IsOriginal |
%       InputVariables | Transformations, keyed by feature name) is normalized to
%       the Feature | Type | Definition shape. The Transformations text is the
%       Definition; an empty one denotes an original passthrough. When an Index
%       is given it is passed straight to describe(Transformer, Index): the
%       method subsets natively (preserving requested order) and errors on an
%       unknown name with id stats:featlearn:FeatureTransformer:InvalidIndex.
%     - A domain recipe struct (Kind == "domain"): its .Describe field already
%       holds a Feature | Type | Definition table (assembled when pool-building
%       was routed to a domain skill), returned after a shape check and, if an
%       Index is given, subset by matching the Feature column.
%
%   Inputs:
%     Recipe - FeatureTransformer, or a struct with fields:
%                .Kind     (1,1) string = "domain"
%                .Describe        table with Feature | Type | Definition
%     Index  - (optional) feature names (string) or a numeric/logical index of
%              the subset to describe; omitted returns the whole pool
%
%   Output:
%     DescTbl - table with string variables Feature, Type, Definition

% Copyright 2026 The MathWorks, Inc.

    arguments
        Recipe
        Index = string.empty
    end

    HasIndex = ~isStringEmpty(Index);

    if isa(Recipe, "FeatureTransformer")
        if HasIndex
            DescTbl = fromTransformer(Recipe, Index);
        else
            DescTbl = fromTransformer(Recipe);
        end
    elseif isDomainRecipe(Recipe, "Describe")
        DescTbl = checkDomainDescribe(Recipe.Describe);
        if HasIndex
            DescTbl = subsetDomainDescribe(DescTbl, Index);
        end
    else
        error("describeFeatures:unknownRecipe", ...
            ['Recipe must be an SMLT FeatureTransformer or a domain recipe ' ...
            'struct (Kind == "domain" with a Describe table).']);
    end
end


function DescTbl = fromTransformer(Transformer, Index)
%fromTransformer Normalize an SMLT describe() table to Feature|Type|Definition.
    arguments
        Transformer
        Index = string.empty
    end
    if isStringEmpty(Index)
        D = describe(Transformer);
    else
        D = describe(Transformer, Index);
    end
    Names = string(D.Properties.RowNames);
    n = numel(Names);
    Type = strings(n, 1);
    Definition = strings(n, 1);
    for i = 1:n
        Type(i) = string(D.Type(i));
        Def = describeCell(D.Transformations(i));
        if strlength(Def) == 0
            Def = "Original input variable (passed through).";
        end
        Definition(i) = Def;
    end
    DescTbl = table(Names, Type, Definition, ...
        VariableNames=["Feature", "Type", "Definition"]);
end


function Str = describeCell(Val)
%describeCell Pull a scalar string/char out of a table cell or string element.
    if iscell(Val)
        if isempty(Val)
            Str = "";
            return;
        end
        Val = Val{1};
    end
    Str = strtrim(string(Val));
    if isscalar(Str)
        return;
    end
    Str = strjoin(Str, "; ");
end


function DescTbl = checkDomainDescribe(DescTbl)
%checkDomainDescribe Validate a domain recipe's Describe table shape.
    if ~istable(DescTbl)
        error("describeFeatures:domainNotTable", ...
            "The domain recipe's Describe field must be a table.");
    end
    Required = ["Feature", "Type", "Definition"];
    Have = string(DescTbl.Properties.VariableNames);
    if ~all(ismember(Required, Have))
        error("describeFeatures:domainMissingVars", ...
            "The domain Describe table must have variables Feature, Type, Definition.");
    end
end


function DescTbl = subsetDomainDescribe(DescTbl, Index)
%subsetDomainDescribe Subset a domain Describe table by name or numeric index.
    if isnumeric(Index) || islogical(Index)
        DescTbl = DescTbl(Index, :);
        return;
    end
    Names = string(Index);
    Have = string(DescTbl.Feature);
    Missing = setdiff(Names, Have, "stable");
    if ~isempty(Missing)
        error("describeFeatures:missingFeatures", ...
            "The domain Describe table is missing requested feature(s): %s.", ...
            strjoin(Missing, ", "));
    end
    [~, Loc] = ismember(Names, Have);
    DescTbl = DescTbl(Loc, :);
end
