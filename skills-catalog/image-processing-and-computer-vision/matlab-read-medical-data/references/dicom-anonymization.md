# DICOM Anonymization

Remove patient-identifying information from DICOM files using `dicomanon`. Works with Image Processing Toolbox (R2006a+).

## dicomanon — Anonymize a DICOM File

Removes or replaces patient health information (PHI) per DICOM PS3.15 standard.

```matlab
dicomanon(inputFile, outputFile)
```

## Single File Anonymization

```matlab
dicomanon("input.dcm", "anonymized.dcm");
```

## Key Options

| Option | Purpose | Example |
|--------|---------|---------|
| `'keep'` | Preserve specific DICOM tags | `'keep', {'StudyDescription', 'PatientSex'}` |
| `'update'` | Replace tags with specified values | `'update', struct('PatientName', 'ANON')` |

```matlab
% Keep certain fields during anonymization
dicomanon("input.dcm", "output.dcm", ...
    keep={'StudyDescription', 'PatientSex', 'PatientAge'});

% Update specific fields with custom values
dicomanon("input.dcm", "output.dcm", ...
    update=struct('PatientName', 'Subject001', 'PatientID', 'S001'));
```

## Batch Anonymization with Shared UIDs

When anonymizing a DICOM series, all files must share the same `StudyInstanceUID` and `SeriesInstanceUID` so viewers group them as one volume. Generate UIDs once with `dicomuid`, then apply to all files via `'update'`.

```matlab
inputFolder = "path/to/dicom/series";
outputFolder = "path/to/output";

% Generate consistent UIDs for the entire series
sharedUIDs = struct();
sharedUIDs.StudyInstanceUID = dicomuid;
sharedUIDs.SeriesInstanceUID = dicomuid;

% Get all DICOM files
allFiles = dir(fullfile(inputFolder, '*.dcm'));

% Anonymize each file with shared UIDs
for i = 1:numel(allFiles)
    inFile = fullfile(inputFolder, allFiles(i).name);
    outFile = fullfile(outputFolder, allFiles(i).name);
    dicomanon(inFile, outFile, update=sharedUIDs);
end
```

## dicomuid — Generate Unique DICOM Identifiers

```matlab
uid = dicomuid;  % Returns a unique DICOM UID string
```

Use `dicomuid` to create new UIDs for `StudyInstanceUID`, `SeriesInstanceUID`, or `SOPInstanceUID` when you need consistent identifiers across a batch.

## Pattern: Anonymize with Custom Patient Info

```matlab
customInfo = struct();
customInfo.StudyInstanceUID = dicomuid;
customInfo.SeriesInstanceUID = dicomuid;
customInfo.PatientName = 'ANONYMIZED';
customInfo.PatientID = 'ANON_001';

allFiles = dir(fullfile(inputFolder, '*.dcm'));
for i = 1:numel(allFiles)
    inFile = fullfile(inputFolder, allFiles(i).name);
    outFile = fullfile(outputFolder, allFiles(i).name);
    dicomanon(inFile, outFile, update=customInfo);
end
```

## Pattern: Verify Anonymization

```matlab
% Read original and anonymized metadata
infoOrig = dicominfo("original.dcm");
infoAnon = dicominfo("anonymized.dcm");

% Check key PHI fields are removed/changed
fprintf("Original PatientName: %s\n", infoOrig.PatientName.FamilyName);
fprintf("Anonymized PatientName: %s\n", infoAnon.PatientName.FamilyName);
fprintf("UIDs match: %d\n", strcmp(infoOrig.StudyInstanceUID, infoAnon.StudyInstanceUID));
```

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| `dicomanon` on series without `'update'` for UIDs | Each file gets different UIDs — viewers treat each slice as separate study. Use shared UIDs via `'update'` |
| Manually blanking DICOM fields one-by-one | Use `dicomanon` — handles all PHI tags per standard |

----

Copyright 2026 The MathWorks, Inc.

----
