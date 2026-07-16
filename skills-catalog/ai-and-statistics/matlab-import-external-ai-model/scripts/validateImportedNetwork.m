function results = validateImportedNetwork(net, referenceInputFile, referenceOutputFile, options)
%validateImportedNetwork Compare imported dlnetwork output against PyTorch reference.
%
%   results = validateImportedNetwork(net, referenceInputFile, referenceOutputFile)
%   results = validateImportedNetwork(..., InputFormat="SSCB")
%   results = validateImportedNetwork(..., Tolerance=1e-5)
%
%   Inputs:
%       net                - Imported dlnetwork from importNetworkFromPyTorch
%       referenceInputFile - Path to .npy file with PyTorch input (NCHW order)
%       referenceOutputFile - Path to .npy file with PyTorch output
%
%   Name-Value Arguments:
%       InputFormat  - dlarray format string for the input (default: "SSCB")
%       Tolerance    - Maximum absolute difference for pass (default: 1e-5)
%
%   Output:
%       results - struct with fields: passed, maxAbsDiff, meanAbsDiff

    arguments
        net dlnetwork
        referenceInputFile (1,1) string {mustBeFile}
        referenceOutputFile (1,1) string {mustBeFile}
        options.InputFormat (1,1) string = "SSCB"
        options.Tolerance (1,1) double {mustBePositive} = 1e-5
    end

    % Load reference data
    refInput = readNPY(referenceInputFile);
    refOutput = readNPY(referenceOutputFile);

    % Convert from PyTorch dimension order to MATLAB
    nd = ndims(refInput);
    inputMATLAB = permute(refInput, nd:-1:1);

    % Create dlarray with specified format
    dlIn = dlarray(single(inputMATLAB), options.InputFormat);

    % Run inference
    dlOut = predict(net, dlIn);
    matlabOutput = double(extractdata(dlOut));

    % Convert output back to PyTorch order for comparison
    ndOut = ndims(matlabOutput);
    matlabOutput = permute(matlabOutput, ndOut:-1:1);

    % Compare
    absDiff = abs(matlabOutput - double(refOutput));
    results.maxAbsDiff = max(absDiff(:));
    results.meanAbsDiff = mean(absDiff(:));
    results.passed = results.maxAbsDiff < options.Tolerance;

    % Report
    fprintf("Max absolute difference:  %.2e\n", results.maxAbsDiff);
    fprintf("Mean absolute difference: %.2e\n", results.meanAbsDiff);
    fprintf("Tolerance:                %.2e\n", options.Tolerance);

    if results.passed
        fprintf("[PASS] Numeric validation passed.\n");
    else
        fprintf("[FAIL] Max difference exceeds tolerance.\n");
    end
end


function data = readNPY(filename)
%readNPY Read a NumPy .npy file (float32/float64) into a MATLAB array.

    fid = fopen(filename, 'r', 'l');
    if fid == -1
        error('validateImportedNetwork:FileOpenFailed', ...
            'Cannot open file: %s', filename);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    % Read and validate magic number
    magic = fread(fid, 6, '*uint8')';
    assert(isequal(magic, uint8([147 78 85 77 80 89])), ...
        'validateImportedNetwork:InvalidNPY', 'Not a valid .npy file.');

    % Version and header
    majorVer = fread(fid, 1, '*uint8');
    fread(fid, 1, '*uint8'); % minor version
    if majorVer == 1
        headerLen = fread(fid, 1, 'uint16', 0, 'l');
    else
        headerLen = fread(fid, 1, 'uint32', 0, 'l');
    end
    header = char(fread(fid, headerLen, '*uint8')');

    % Parse dtype
    descrMatch = regexp(header, "'descr':\s*'([^']+)'", 'tokens');
    dtypeStr = descrMatch{1}{1};

    if startsWith(dtypeStr, '>')
        fclose(fid);
        error('validateImportedNetwork:BigEndian', ...
            'Big-endian .npy files not supported. Re-save with little-endian.');
    end

    switch dtypeStr(end-1:end)
        case 'f4', precision = 'single';
        case 'f8', precision = 'double';
        otherwise
            fclose(fid);
            error('validateImportedNetwork:UnsupportedDtype', ...
                'Unsupported dtype: %s', dtypeStr);
    end

    % Parse shape
    shapeMatch = regexp(header, "'shape':\s*\(([^)]*)\)", 'tokens');
    shapeStr = strtrim(shapeMatch{1}{1});
    shapeVals = str2double(strsplit(shapeStr, ','));
    shapeVals = shapeVals(~isnan(shapeVals));

    % Read data
    numElements = prod(shapeVals);
    data = fread(fid, numElements, ['*' precision]);

    % Reshape from C-order to MATLAB column-major
    if numel(shapeVals) > 1
        data = reshape(data, fliplr(shapeVals));
        data = permute(data, numel(shapeVals):-1:1);
    end
end
% Copyright 2026 The MathWorks, Inc.
