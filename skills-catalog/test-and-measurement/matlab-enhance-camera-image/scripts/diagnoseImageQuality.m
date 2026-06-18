function results = diagnoseImageQuality(img)
%diagnoseImageQuality Analyze image quality metrics for camera-acquired images.
%   results = diagnoseImageQuality(img) returns a struct with fields:
%   brightness, clipping, contrast, sharpness, noise, colorBalance,
%   backlightRatio. Each field contains .value (numeric or struct) and
%   .assessment (string: "OK", "Problem", or "Severe").

    arguments
        img (:,:,:) {mustBeNumeric}
    end

    if size(img, 3) == 3
        grayImg = im2gray(img);
    else
        grayImg = img;
    end
    grayDouble = im2double(grayImg);

    results.brightness = assessBrightness(grayDouble);
    results.clipping = assessClipping(grayDouble);
    results.contrast = assessContrast(grayDouble);
    results.sharpness = assessSharpness(grayDouble);
    results.noise = assessNoise(grayDouble);
    results.colorBalance = assessColorBalance(img);
    results.backlightRatio = assessBacklight(grayDouble);
end

function result = assessBrightness(grayDouble)
    meanIntensity = mean(grayDouble, "all") * 255;
    result.value = meanIntensity;
    if meanIntensity < 60
        result.assessment = "Severe";
    elseif meanIntensity < 80
        result.assessment = "Problem";
    elseif meanIntensity > 200
        result.assessment = "Severe";
    elseif meanIntensity > 180
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

function result = assessContrast(grayDouble)
    stdIntensity = std(grayDouble, 0, "all") * 255;
    result.value = stdIntensity;
    if stdIntensity < 25
        result.assessment = "Severe";
    elseif stdIntensity < 40
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

function result = assessSharpness(grayDouble)
    laplacian = fspecial("laplacian", 0);
    filtered = imfilter(grayDouble, laplacian, "replicate");
    laplacianVar = var(filtered, 0, "all");
    result.value = laplacianVar;
    if laplacianVar < 0.0002
        result.assessment = "Severe";
    elseif laplacianVar < 0.001
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

function result = assessNoise(grayDouble)
    smoothed = imgaussfilt(grayDouble, 1.5);
    noiseDiff = grayDouble - smoothed;
    noiseLevel = std(noiseDiff, 0, "all") * 255;
    result.value = noiseLevel;
    if noiseLevel > 10
        result.assessment = "Severe";
    elseif noiseLevel > 5
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

function result = assessColorBalance(img)
    if size(img, 3) ~= 3
        result.value = struct("rgRatio", 1.0, "bgRatio", 1.0);
        result.assessment = "OK";
        return;
    end
    imgDouble = im2double(img);
    rMean = mean(imgDouble(:,:,1), "all");
    gMean = mean(imgDouble(:,:,2), "all");
    bMean = mean(imgDouble(:,:,3), "all");
    if gMean < 0.01
        rgRatio = 1.0;
        bgRatio = 1.0;
    else
        rgRatio = rMean / gMean;
        bgRatio = bMean / gMean;
    end
    result.value = struct("rgRatio", rgRatio, "bgRatio", bgRatio);
    maxDeviation = max(abs(rgRatio - 1.0), abs(bgRatio - 1.0));
    if maxDeviation > 0.3
        result.assessment = "Severe";
    elseif maxDeviation > 0.15
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

function result = assessBacklight(grayDouble)
    [rows, cols] = size(grayDouble);
    rowStart = round(rows * 0.25);
    rowEnd = round(rows * 0.75);
    colStart = round(cols * 0.25);
    colEnd = round(cols * 0.75);
    centerRegion = grayDouble(rowStart:rowEnd, colStart:colEnd);
    mask = true(rows, cols);
    mask(rowStart:rowEnd, colStart:colEnd) = false;
    borderRegion = grayDouble(mask);
    centerMean = mean(centerRegion, "all");
    borderMean = mean(borderRegion, "all");
    if centerMean < 0.01
        ratio = 1.0;
    else
        ratio = borderMean / centerMean;
    end
    result.value = ratio;
    if ratio > 2.0
        result.assessment = "Severe";
    elseif ratio > 1.5
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

function result = assessClipping(grayDouble)
    highPct = mean(grayDouble >= (250/255), "all") * 100;
    lowPct = mean(grayDouble <= (5/255), "all") * 100;
    result.value = struct("highPct", highPct, "lowPct", lowPct);
    maxClip = max(highPct, lowPct);
    if maxClip > 15
        result.assessment = "Severe";
    elseif maxClip > 5
        result.assessment = "Problem";
    else
        result.assessment = "OK";
    end
end

% Copyright 2026 The MathWorks, Inc.
