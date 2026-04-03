function [result, snapshots] = captureAtLines(funcFile, captureLines, varargin)
%captureAtLines Run a function and capture workspace at specified lines.
%
%   [result, snapshots] = captureAtLines(funcFile, captureLines, arg1, arg2, ...)
%
%   Creates a temporary instrumented copy of the function, runs it, and
%   captures all workspace variables at the specified line numbers. The
%   original source file is never modified.
%
%   Inputs:
%       funcFile     - Path to the .m function file
%       captureLines - Vector of line numbers to capture workspace at
%       varargin     - Arguments to pass to the function
%
%   Outputs:
%       result    - Cell array of the function's return values
%       snapshots - Cell array of structs, each with 'line' field plus workspace variables

    funcFile = string(funcFile);
    captureLines = captureLines(:);

    % Read original source
    src = fileread(funcFile);
    lines = strsplit(src, newline, 'CollapseDelimiters', false);

    % Extract original function name from first line
    tokens = regexp(lines{1}, 'function\s+.*=\s*(\w+)\s*\(', 'tokens');
    if isempty(tokens)
        tokens = regexp(lines{1}, 'function\s+(\w+)\s*\(', 'tokens');
    end
    origName = tokens{1}{1};
    tempName = [origName '_dbgcap'];

    % Count output arguments from signature
    outTokens = regexp(lines{1}, 'function\s+\[?([^\]=]*)\]?\s*=', 'tokens');
    if ~isempty(outTokens)
        nOut = numel(strsplit(strtrim(outTokens{1}{1}), ','));
    else
        nOut = 0;
    end

    % Inject capture code at target lines (work backwards to preserve line numbers)
    captureLines = sort(captureLines, 'descend');
    for k = 1:numel(captureLines)
        ln = captureLines(k);
        if ln > numel(lines), continue; end
        captureCode = sprintf('    w__=whos; s__=struct(''line'',%d); for i__=1:numel(w__), if ~startsWith(w__(i__).name,{''w__'',''s__'',''i__'',''DBGCAP__''}), s__.(w__(i__).name)=eval(w__(i__).name); end; end; global DBGCAP__; DBGCAP__{end+1}=s__;', ln);
        lines = [lines(1:ln) {captureCode} lines(ln+1:end)];
    end

    % Rename function to avoid shadowing
    lines{1} = strrep(lines{1}, origName, tempName);

    % Write temp file
    tempDir = tempdir;
    tempFile = fullfile(tempDir, [tempName '.m']);
    fid = fopen(tempFile, 'w');
    fprintf(fid, '%s\n', lines{:});
    fclose(fid);
    addpath(tempDir);

    % Initialize capture storage (global required — injected code in temp
    % function writes snapshots here since it cannot return them directly)
    global DBGCAP__ %#ok<GVMIS>
    DBGCAP__ = {};

    % Run instrumented copy
    try
        if nOut > 0
            outArgs = cell(1, nOut);
            [outArgs{:}] = feval(tempName, varargin{:});
            result = outArgs;
        else
            feval(tempName, varargin{:});
            result = {};
        end
    catch ME
        % Cleanup on error
        rmpath(tempDir);
        delete(tempFile);
        DBGCAP__ = [];
        rethrow(ME);
    end

    % Collect snapshots (cell array — each snapshot may have different fields)
    snapshots = DBGCAP__;
    DBGCAP__ = [];

    % Cleanup
    rmpath(tempDir);
    delete(tempFile);
end
