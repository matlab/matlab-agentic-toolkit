---
name: matlab-create-custom-arduino-library
description: >
  Use when the user wants to use Arduino sensors or peripherals from MATLAB that are
  not directly supported by the MATLAB Support Package for Arduino Hardware. Triggers on
  requests to create, wrap, or expose a custom Arduino library to MATLAB. Also triggers
  on indirect questions like "How do I read humidity in MATLAB?" or "How do I display
  text on an LCD from MATLAB?" where the answer requires a custom Arduino add-on library.
  Covers: custom addon creation, third-party Arduino library integration, LibraryBase
  class, C++ header files, DependentLibraries, arduinoioaddons namespace, I2C/SPI/GPIO
  peripheral wrappers.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Create Custom Arduino Library

Help the user interface with Arduino sensors or peripherals from MATLAB by creating
a custom arduino library that bridges MATLAB and Arduino C++ code.

## When to Use

- User wants to read sensors not natively supported (DHT11, DHT22, IMU, air quality)
- User wants to control peripherals not natively supported (OLED displays, motor drivers, NeoPixels)
- User asks "How do I use [sensor/actuator/peripheral] from MATLAB with Arduino?"
- User wants to wrap an existing Arduino C++ library for MATLAB access
- User mentions `LibraryBase`, `arduinoioaddons`, or custom addon creation

## When NOT to Use

- Peripheral is already supported natively (use `listArduinoLibraries` to check)
- User needs to discover or connect to an Arduino board (see `matlab-connect-arduino`)
- User wants generic I2C/SPI communication (built-in)
- User wants to deploy standalone Arduino code (no MATLAB connection)
- User wants Simulink Arduino deployment (different workflow)
- User wants to fix Arduino hardware setup screens

## Workflow

**MANDATORY GATE — do not skip, but keep it fast:**

Before creating a custom addon, you MUST run Steps 0 and 1 below. These are quick
checks (one MATLAB command + one sentence about File Exchange), not deep research.
Report findings in 1-2 lines and move on. If native support or a community addon
exists, stop. Otherwise proceed to Step 2 immediately.

### STEP 0: Check Native Support (ALWAYS DO FIRST)

```matlab
listArduinoLibraries
```

If the peripheral is in the list, tell the user and **STOP**. Do NOT proceed to Step 2
or beyond. Do NOT generate custom library code. Common built-in:
`I2C`, `SPI`, `Serial`, `Servo`, `RotaryEncoder`, `Ultrasonic`, `ShiftRegister`

### STEP 1: Search File Exchange (MathWorks contributions only)

Search for existing add-ons contributed by the MathWorks MATLAB Hardware Team:
- Search: `site:mathworks.com/matlabcentral/fileexchange Arduino <peripheral>`
- Look for packages with `+arduinoioaddons` folder structure
- **Only use results authored by MathWorks** — filter by author "MathWorks Hardware Team"
  or "MathWorks". Do NOT recommend community contributions from unknown third parties.

If a MathWorks-contributed add-on is found, guide the user through installation:
1. Download/extract the addon package
2. `addpath` the folder containing `+arduinoioaddons`
3. Install third-party Arduino libraries via `arduinoio.customLibrary.downloadLibrary`
4. Verify with `listArduinoLibraries`

**STOP here if a MathWorks add-on is found — do NOT proceed to Step 2 or beyond.**

### STEP 2: Gather Required Inputs

Before creating a custom library, the user MUST provide:
1. **Custom library name** (e.g., `MyDHT22`)
2. **Third-party Arduino library name** (if wrapping one; e.g., `DHT22`, `U8g2`)
3. **Target output directory** for the MATLAB add-on files

Do NOT proceed to any further steps until all required inputs are provided. If any are
missing, ask the user explicitly and wait for their response.

### STEP 3: Install Third-Party Arduino Library

```matlab
% R2025a+ — use downloadLibrary (preferred)
arduinoio.customLibrary.downloadLibrary("<ArduinoLibraryName>")

% Accepts: library name, name@version, GitHub URL, or local .zip path
% Examples:
arduinoio.customLibrary.downloadLibrary("DHT22")
arduinoio.customLibrary.downloadLibrary("U8g2")
arduinoio.customLibrary.downloadLibrary("https://github.com/olikraus/u8g2")
```

Verify installation:
```matlab
dir(fullfile(arduinoio.CLIRoot, 'user', 'libraries'))
```

**For R2024a-R2024b** (no `downloadLibrary`): manually extract the library zip into
`fullfile(arduinoio.CLIRoot, 'user', 'libraries', '<LibName>')`.

**For pre-R2024a** (no `CLIRoot`): use `arduinoio.IDERoot` instead of `arduinoio.CLIRoot`.

### STEP 4: Scaffold the Add-On

```matlab
% R2025a+ — use createLibraryTemplate (preferred)
arduinoio.customLibrary.createLibraryTemplate("<CustomLibraryName>")
```

This creates the folder structure **in the current working directory (pwd)** and adds the
path automatically. After calling it, the generated files are at:
```
<pwd>/+arduinoioaddons/+<CustomLibraryName>Folder/<CustomLibraryName>.m
<pwd>/+arduinoioaddons/+<CustomLibraryName>Folder/src/<CustomLibraryName>.h
```

Do NOT search other locations — the files are always in pwd.

**Naming:** `createLibraryTemplate("X")` creates `+XFolder/X.m` — it appends "Folder"
to the package name automatically. The generated `setup()` has placeholder comments —
clear the body (no `.begin()` calls). The generated `loop()` is unused and can be deleted.

**For pre-R2025a**: create the folder structure manually:
```
<targetDir>/+arduinoioaddons/+<FolderName>/<ClassName>.m
<targetDir>/+arduinoioaddons/+<FolderName>/src/<HeaderName>.h
```

Then register:
```matlab
addpath('<targetDir>');
savepath;
```

### STEP 5: Configure the MATLAB Class

Update the generated `.m` file. See "MATLAB Class Property Rules" below for exact values.

**Add minimal comments** to the generated `.m` file for user understanding:
- A file-level comment block stating the class purpose and the peripheral it wraps
- Brief comments on non-obvious property values (e.g., why `DependentLibraries` is empty)
- A one-line comment above each public method explaining what it does

### STEP 6: Write the C++ Header

Update the generated `.h` file. See "C++ Header Rules" below and read
`references/cpp-patterns.md` for templates.

**Add minimal comments** to the generated `.h` file for user understanding:
- A file-level comment stating the addon name and peripheral it supports
- A one-line comment above each command ID `#define` explaining the command
- A brief comment in `commandHandler` for each `case` describing what it does

### STEP 7: Verify

```matlab
listArduinoLibraries  % Must show your library name
a = arduino("<port>", "<board>", "Libraries", "<FolderName>/<ClassName>");
obj = addon(a, "<FolderName>/<ClassName>", <args>);
```

## MATLAB Class Property Rules

| Property | Format | Example | Notes |
|----------|--------|---------|-------|
| `LibraryName` | `'FolderName/ClassName'` | `'Adafruit/DHT22'` | Must match namespace |
| `DependentLibraries` | Cell of MATLAB addon names | `{}` or `{'I2C'}` | See decision table below |
| `LibraryHeaderFiles` | `'<ArduinoLibFolder>/<header.h>'` | `'DHT/DHT.h'` | Folder name in CLIRoot + header filename |
| `CppHeaderFile` | `fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', '<Name>.h')` | — | Always this pattern |
| `CppClassName` | Must match C++ class name | `'DHT22Base'` | Exact match required |

### DependentLibraries Decision Table

| Scenario | Value | Reason |
|----------|-------|--------|
| GPIO-only peripheral (DHT, NeoPixel) | `{}` | No MATLAB bus dependency |
| I2C device using SW_I2C (displays, most sensors) | `{}` | Software I2C bypasses MATLAB's bus |
| I2C device delegating to MATLAB's I2C infrastructure | `{'I2C'}` | MATLAB manages Wire init and pins |
| SPI device | `{}` | MATLAB does not own SPI bus |
| Uses another custom addon | `{'OtherAddon/Name'}` | Chain dependency |

### LibraryHeaderFiles Format

Format: `'<FolderNameInCLIRoot>/<HeaderFilename>'`

```matlab
% GOOD — folder name matches what's in CLIRoot/user/libraries/
LibraryHeaderFiles = {'DHT/DHT.h'}
LibraryHeaderFiles = {'U8g2/U8g2lib.h'}
LibraryHeaderFiles = {'Adafruit_Motor_Shield_V2_Library/Adafruit_MotorShield.h'}

% BAD — just filename without folder
LibraryHeaderFiles = {'DHT.h'}

% BAD — subdirectory path (NEVER include src/ even if the file physically lives there)
LibraryHeaderFiles = {'U8g2/src/U8g2lib.h'}

% BAD — Arduino library name (Wire is not in CLIRoot/user/libraries)
LibraryHeaderFiles = {'Wire/Wire.h'}
```

The Arduino build system automatically searches the `src/` subdirectory within
the library folder, so **NEVER include `src/` in this path**. This is the most
common mistake — even though headers like `U8g2lib.h` physically reside in
`<LibFolder>/src/`, you must write `'U8g2/U8g2lib.h'` NOT `'U8g2/src/U8g2lib.h'`.

## C++ Header Rules

Read `references/cpp-patterns.md` for full templates. Critical rules:

1. **`setup()` MUST NOT initialize hardware** — calling `.begin()`, `Wire.begin()`,
   `SPI.begin()` etc. in setup() causes "Internal error: The initialization of the
   server code is incorrect." Simple variable assignments (e.g., `cursorRow = 0`) are safe.
2. **Use lazy initialization** — init hardware on first command via a dedicated INIT command
3. **`sendResponseMsg` must send >= 1 byte** — `sendResponseMsg(cmdID, 0, 0)` crashes ARM boards (UNO R4, ESP32)
4. **NEVER `#include <Wire.h>` in your addon header** — causes I2C bus conflict with MATLAB.
   Your code must never contain this line. Third-party libraries may include it internally
   (that is fine — you don't control their code), but YOUR .h file must not.
5. **`#include <SPI.h>` is safe** — MATLAB does not own SPI
6. **Use angle brackets** for third-party headers: `#include <U8g2lib.h>`
7. **Use constructor initializer list** for member objects, not in-class initialization

### I2C Bus Conflict — Read `references/bus-conflicts.md`

MATLAB owns the hardware I2C bus (Wire). If your peripheral uses I2C:
- **Preferred:** Use software I2C constructors (e.g., `U8G2_..._SW_I2C`) with `DependentLibraries = {}`
- **Do NOT call `Wire.begin()`** directly
- **Do NOT `#include <Wire.h>`** in your own addon header

If the third-party library requires hardware I2C (e.g., SGP30, motor shields): set
`DependentLibraries = {'I2C'}` and let MATLAB manage the bus. The third-party library
may include Wire.h internally — this is safe because MATLAB has already initialized Wire.
Your C++ code must NOT call `Wire.begin()` since MATLAB already did.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `DependentLibraries = {'Wire'}` | `Wire` is not in `listArduinoLibraries` | Use `{}` or `{'I2C'}` |
| Third-party lib in `+arduinoioaddons/src/` | Wrong location; build can't find it | `arduinoio.CLIRoot/user/libraries/` |
| `LibraryHeaderFiles = {'U8g2lib.h'}` | Missing folder prefix | `{'U8g2/U8g2lib.h'}` |
| `U8G2_..._HW_I2C` constructor | Conflicts with MATLAB's Wire management | Use `_SW_I2C` constructor |
| `.begin()` calls in `setup()` | Server handshake fails | Init hardware via command; variable assignments are OK |
| `sendResponseMsg(cmdID, 0, 0)` | Crashes ARM boards (nullptr) | Send >= 1 byte always |
| `#include <Wire.h>` in your addon header | Conflicts with MATLAB I2C server | Omit; use SW_I2C or `DependentLibraries = {'I2C'}` |
| Installing via Arduino IDE Library Manager | MATLAB uses its own CLIRoot path | Use `downloadLibrary()` |
| Not calling `addpath` after creating addon | `listArduinoLibraries` won't find it | `addpath` + `savepath` |

## Conventions

- Always check native support first, File Exchange second, create last
- Always use `downloadLibrary` (R2025a+) or manual copy to CLIRoot for third-party libs
- Always verify with `listArduinoLibraries` after registration
- Never call `.begin()` or hardware init in `setup()` — use lazy init via dedicated command
- Always send >= 1 byte in `sendResponseMsg`
- Never include `<Wire.h>` in your own code — use software I2C or depend on `{'I2C'}`
- Never put third-party Arduino libraries inside `+arduinoioaddons`
- Prefer `createLibraryTemplate` (R2025a+) over manual folder creation

## Fallback: When Automated Steps Fail or Take Too Long

If `listArduinoLibraries` hangs, File Exchange search takes too long, `downloadLibrary`
fails, or `createLibraryTemplate` fails — fall back to the pre-R2025a manual approach:

1. **Install library manually:** Download the third-party Arduino library .zip and extract
   it into `fullfile(arduinoio.CLIRoot, 'user', 'libraries', '<LibName>')`.
2. **Create folder structure manually:**
   ```
   <targetDir>/+arduinoioaddons/+<FolderName>/<ClassName>.m
   <targetDir>/+arduinoioaddons/+<FolderName>/src/<HeaderName>.h
   ```
3. **Register manually:** `addpath('<targetDir>'); savepath;`
4. **Continue from Step 5** (configure MATLAB class and C++ header as normal).

Do not retry failing commands repeatedly. Switch to manual creation and proceed.

## Troubleshooting

When errors occur during deployment or usage, read the appropriate reference:

- **Compilation or "source not found" errors** → read `references/common-errors.md`
- **Runtime errors ("unable to receive data", "server code incorrect")** → read `references/common-errors.md`
- **Bus conflicts (I2C/SPI/UART)** → read `references/bus-conflicts.md`
- **C++ code patterns (lazy init, response format, includes)** → read `references/cpp-patterns.md`

----

Copyright 2026 The MathWorks, Inc.

----
