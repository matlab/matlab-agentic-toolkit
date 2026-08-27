function Tf = isDomainRecipe(Recipe, RequiredField)
%isDomainRecipe True for a well-formed domain recipe struct.
%
%   Tf = isDomainRecipe(Recipe) returns true when Recipe is a scalar struct with
%   Kind == "domain" -- the shape a domain skill's captured extraction spec takes
%   (see provider-protocol.md).
%
%   Tf = isDomainRecipe(Recipe, RequiredField) additionally requires the named
%   field(s) to be present, so each caller checks only what it consumes:
%     - transformFeatures needs an "Apply" function handle (the replay).
%     - describeFeatures needs a "Describe" table (the definitions).
%   The Apply field is further checked to be a function handle; other fields are
%   checked for presence only.
%
%   Inputs:
%     Recipe        - value to test
%     RequiredField - (optional) string array of field names that must exist
%
%   Output:
%     Tf - logical scalar

% Copyright 2026 The MathWorks, Inc.

    arguments
        Recipe
        RequiredField (1,:) string = string.empty
    end

    Tf = isstruct(Recipe) && isscalar(Recipe) ...
        && isfield(Recipe, "Kind") && Recipe.Kind == "domain";
    if ~Tf
        return;
    end

    for Field = RequiredField
        if ~isfield(Recipe, Field)
            Tf = false;
            return;
        end
        if Field == "Apply" && ~isa(Recipe.Apply, "function_handle")
            Tf = false;
            return;
        end
    end
end
