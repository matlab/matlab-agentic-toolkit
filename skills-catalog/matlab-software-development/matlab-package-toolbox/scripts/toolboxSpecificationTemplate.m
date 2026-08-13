function spec = toolboxSpecification()
%toolboxSpecification Interface specification for the toolbox.
%   spec = toolboxSpecification() returns the toolbox interface spec as a struct.

    spec.toolbox.name = "";
    spec.toolbox.version = "1.0.0";
    spec.toolbox.summary = "";
    spec.toolbox.purpose = "User's stated purpose";
    spec.toolbox.sourcePath = "path/analyzed";

    % Cell array — entries may have different fields (classdef adds methods/properties)
    spec.entries = { ...
        struct("function", "funcName", "file", "relative/path.m", ...
               "signature", "out = funcName(in1, in2)", ...
               "h1", "Description", "category", "Analysis", ...
               "visibility", "public", "type", "function"); ...
        struct("function", "helper", "file", "relative/helper.m", ...
               "signature", "r = helper(x)", ...
               "h1", "", "category", "", ...
               "visibility", "internal", "type", "function"); ...
        struct("function", "MyClass", "file", "relative/MyClass.m", ...
               "signature", "obj = MyClass(arg1, arg2)", ...
               "h1", "Class description", "category", "Core", ...
               "visibility", "public", "type", "classdef", ...
               "methods", {{"compute", "reset", "plot"}}, ...
               "properties", {{"Data", "Options"}}); ...
    };
end

% Entry type conventions:
%
% For "function" entries:
%   - "function": function name
%   - "file": relative path to .m file
%   - "signature": full call signature (e.g., "out = funcName(in1, in2)")
%   - "h1": H1 help line
%   - "category": grouping for documentation
%   - "visibility": "public" or "internal"
%   - "type": "function"
%
% For "classdef" entries:
%   - "function": class name
%   - "file": relative path to .m file
%   - "signature": constructor signature
%   - "h1": class description
%   - "category": grouping for documentation
%   - "visibility": "public" or "internal"
%   - "type": "classdef"
%   - "methods": cell array of public method names
%   - "properties": cell array of public property names
%   Internal/private methods and properties are omitted — only the
%   public API surface is captured.

% Copyright 2026 The MathWorks, Inc.
