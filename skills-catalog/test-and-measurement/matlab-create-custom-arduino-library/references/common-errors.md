# Common Errors and Fixes

## "The Arduino source '<header>' cannot be found"

**Cause:** `LibraryHeaderFiles` format is wrong in the MATLAB .m file.

**Fix:** Use `'<LibraryFolderName>/<HeaderFileName.h>'`:
- The folder name must match the folder under `arduinoio.CLIRoot/user/libraries/`
- Use just the header filename — NOT a full path with subdirectories
- The Arduino resolver searches `src/` automatically

```matlab
% GOOD
LibraryHeaderFiles = {'U8g2/U8g2lib.h'}
LibraryHeaderFiles = {'DHT22/DHT22.h'}
LibraryHeaderFiles = {'Adafruit_Motor_Shield_V2_Library/Adafruit_MotorShield.h'}

% BAD — subdirectory path
LibraryHeaderFiles = {'U8g2/src/U8g2lib.h'}

% BAD — just the filename without library folder
LibraryHeaderFiles = {'U8g2lib.h'}
```

## "Failed to add library '<Name>'. The library is dependent on the unavailable library '<X>'"

**Cause:** `DependentLibraries` contains a name that is NOT in `listArduinoLibraries`.

**Fix:** `DependentLibraries` must only contain names from `listArduinoLibraries`.
Common valid values: `'I2C'`, `'SPI'`, `'Serial'`, `'Servo'`.
Common wrong values: `'Wire'`, `'SPI.h'`, `'Adafruit_NeoPixel'`.

```matlab
% GOOD
DependentLibraries = {}
DependentLibraries = {'I2C'}
DependentLibraries = {'Servo', 'I2C'}

% BAD — Arduino library names, not MATLAB addon names
DependentLibraries = {'Wire'}
DependentLibraries = {'SPI.h'}
```

## "Internal error: The initialization of the server code is incorrect"

**Cause:** Hardware initialization (`.begin()`, `Wire.begin()`, `SPI.begin()`) in
`setup()` conflicts with the server boot sequence.

**Fix:** Move hardware init out of `setup()` into a command handler triggered from
the MATLAB constructor. Simple variable assignments in `setup()` are safe.

See `cpp-patterns.md` for the lazy initialization pattern.

## "Unable to receive data from the target hardware"

**Cause:** The command handler or hardware init blocks serial communication.
Most common: `Wire.begin()` / hardware I2C init conflicts with MATLAB server.

**Fix:** Switch to software I2C constructors, or ensure your addon uses
`DependentLibraries = {'I2C'}` and never calls `Wire.begin()` directly.

See `bus-conflicts.md` for which buses are safe.

## Library not appearing in listArduinoLibraries

**Cause:** The parent folder containing `+arduinoioaddons` is not on the MATLAB path.

**Fix:**
```matlab
addpath('<folder containing +arduinoioaddons>');
savepath;
listArduinoLibraries  % verify
```

If using `createLibraryTemplate` (R2025a+), the path is added automatically.

## Nested +arduinoioaddons directory after createLibraryTemplate

**Cause:** Running `createLibraryTemplate` when the current directory already contains
`+arduinoioaddons` creates a nested structure.

**Fix:** After running, check the output path. If nested, move the inner
`+<FolderName>` up to the correct level:
```
<targetDir>/+arduinoioaddons/+<FolderName>/<ClassName>.m
<targetDir>/+arduinoioaddons/+<FolderName>/src/<HeaderName>.h
```

## Compilation error: "No such file or directory" for #include

**Cause:** Using quoted relative path in C++ code like `#include "LibraryName/src/header.h"`

**Fix:** Use angle brackets with just the header name: `#include <U8g2lib.h>`.
The Arduino build system resolves the path automatically via the `LibraryHeaderFiles`
property in the MATLAB .m file.

----

Copyright 2026 The MathWorks, Inc.

----
