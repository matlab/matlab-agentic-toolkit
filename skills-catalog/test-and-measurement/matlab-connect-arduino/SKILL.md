---
name: matlab-connect-arduino
description: >
  Discover, configure, and connect to Arduino boards from MATLAB using the
  Arduino Support Package. Use this skill when the user wants to set up an
  Arduino board, connect to Arduino hardware, find connected boards, scan
  serial ports, configure Arduino libraries, or any task that requires an
  Arduino connection as a prerequisite (e.g., blink LED, read sensor, read
  digital pin, read analog pin, write pin, plot sensor data, scan I2C, use
  ultrasonic sensor, control servo, read temperature, read voltage, data
  logging from hardware). Triggers on: arduino, board setup, COM port,
  serial port, hardware connection, Arduino Nano, Arduino Uno, Arduino Mega,
  Arduino Micro, Grove, sensor setup, I2C scan, ultrasonic, servo,
  readDigitalPin, writeDigitalPin, readVoltage, writePWMVoltage,
  temperature sensor, air pressure, pin read, pin write, analog input.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Set Up Arduino Board in MATLAB

Guides the agent through discovering, configuring, and connecting to Arduino
boards via USB, ensuring the user is informed and in control at each step.

## When to Use

- User wants to connect to an Arduino board from MATLAB
- User asks to discover or list connected Arduino boards
- User's task requires an Arduino connection as a prerequisite (reading
  sensors, controlling actuators, scanning I2C, etc.)
- User mentions Arduino, COM port, serial port, or hardware setup

## When NOT to Use

- Creating custom addon libraries for unsupported peripherals (see `matlab-create-custom-arduino-library`)
- Bluetooth or WiFi Arduino connections (not covered here)
- Arduino IDE or support package installation issues
- Simulink hardware-in-the-loop workflows
- Tasks that already have an active `arduino` object in the workspace

## Workflow

Follow these steps in order. **Do not skip steps or guess values.**

**Core principle:** Never assume. Always ask the user before proceeding
if any information is unclear or ambiguous.

### Step 1: Discover boards

**Always run both commands** — do not skip `serialportlist` even if
`arduinolist` already found the board. This is a hard requirement:

```matlab
list = arduinolist
ports = serialportlist("available")
```

**Both calls are mandatory.** Never omit `serialportlist` — `arduinolist`
alone misses boards without support package firmware.

`arduinolist` returns a table with Port, Board, Status, and Libraries
columns. However, it cannot list all connected boards as of R2026a — it
may only show one even when multiple are connected. Always also run
`serialportlist("available")` to catch all available ports.

If `arduinolist` is not available (pre-R2024a), skip it and rely on
`serialportlist("available")` alone.

Present both results to the user.

### Step 1b: Handle "no board detected"

If `arduinolist` returns an empty table AND `serialportlist("available")`
shows no obvious Arduino ports (or all connection attempts fail), **do not
brute-force all ports.** Instead:

1. **Ask immediately:** "No Arduino board was detected. Is the board
   physically connected via USB?"
2. **Guide to OS tools:** Present the appropriate guidance to the user
   based on their operating system:
   - **Windows:** "Open Device Manager → Ports (COM & LPT). Do you see
     a device labeled 'Arduino' or 'USB-SERIAL CH340' / 'USB Serial
     Device'? If not, the board may not be connected or needs a driver."
   - **macOS:** "Run `ls /dev/cu.usb*` in a terminal. Arduino boards
     typically appear as `/dev/cu.usbmodem*` or `/dev/cu.usbserial*`."
   - **Linux:** "Run `dmesg | tail -20` after plugging in the board.
     Look for `/dev/ttyACM*` or `/dev/ttyUSB*`."
3. **Suggest common fixes:**
   - Try a different USB cable (some are charge-only, no data)
   - Try a different USB port
   - Install the board's USB driver (CH340 for clones, FTDI for others)
   - Ensure no other application (Arduino IDE Serial Monitor, PuTTY)
     holds the port open
   - If the board was manually disconnected without clearing the
     `arduino` object, restart MATLAB and reconnect
   - For detailed troubleshooting, refer the user to:
     https://www.mathworks.com/help/matlab/supportpkg/arduino-connection-failure.html
4. **STOP and wait.** Do not proceed to Step 2 or beyond until the user
   responds. If the user confirms the board is not connected, continue
   troubleshooting here. If connected, return to Step 1 and re-run
   discovery.


### Step 2: Help user identify ports

Serial port names alone do not tell the user what device is connected.
Guide the user to identify which ports are Arduino boards:

- **Windows:** "Check Device Manager (Ports section) to see which COM
  ports correspond to Arduino boards."
- **macOS:** "Look for `/dev/cu.usbmodem*` or `/dev/cu.usbserial*`
  entries — these are typically Arduino boards."
- **Linux:** "Check `dmesg | grep tty` or look for `/dev/ttyACM*` and
  `/dev/ttyUSB*` devices."

### Step 3: Ask the user to select board

Present the discovered boards/ports and ask the user which to connect to.
**Never auto-select a board.**

Ask for:
1. **Port** (required) — which COM port / device path
2. **Board type** (optional) — if the user doesn't know, use
   `arduino('<port>')` which auto-detects the board type

For multi-board scenarios, ask the user to identify each board by port
and its intended role.

### Step 4: Determine libraries

The default libraries are `{'I2C', 'SPI', 'Servo'}` — MATLAB loads these
automatically if no `Libraries` argument is specified.

**Library strategy:**
1. Start with the defaults: `{'I2C', 'SPI', 'Servo'}`
2. Infer additional libraries from the user's prompt using this mapping:

| User mentions | Add library |
|---------------|-------------|
| ultrasonic, distance sensor, HC-SR04 | `'Ultrasonic'` |
| shift register, 74HC595 | `'ShiftRegister'` |
| rotary encoder, quadrature | `'RotaryEncoder'` |
| motor shield, Adafruit motor | `'Adafruit/MotorShieldV2'` |
| motor carrier, MKR motor | `'MotorCarrier'` |
| CAN bus | `'CAN'` |
| serial device, UART | `'Serial'` |
| APDS9960, gesture, color sensor | `'APDS9960'` |

**Only infer from the table above when the match is explicit and
unambiguous.** If uncertain, ask the user rather than guessing libraries.

3. **Tell the user** which libraries you are including and why
4. **Ask the user** if any additional libraries are needed
5. If the user asks what's available, run `listArduinoLibraries` and
   show the full list

### Step 5: Connect

Build the `arduino()` call based on what you gathered:

```matlab
% TEMPLATE — not executable
% With board type known + custom libraries:
a = arduino('<port>', '<board>', 'Libraries', {'I2C', 'SPI', 'Servo', ...});

% With board type known, default libraries only:
a = arduino('<port>', '<board>');

% Auto-detect board type (uses libraries already flashed on board):
a = arduino('<port>');
```

**Important:** You cannot specify `'Libraries'` without also specifying the
board type. If the user doesn't know their board type but needs extra
libraries, run `arduino('<port>')` first to auto-detect, then read
`a.Board` and reconnect with the board type and libraries specified.

If the connection fails:
1. **Stop immediately** — do not retry automatically
2. Report the exact error message to the user
3. Provide 1–2 targeted fixes based on the error
4. Do not retry with different ports or board types unless the user
   explicitly instructs

Common issues:
- Port is busy (another application has it open)
- "Device in use" — an `arduino` object already exists in the workspace;
  the user must `clear` it before reconnecting
- Wrong board type specified
- Board needs a firmware reset (double-tap reset button)

### Step 6: Confirm and hand off

After successful connection:

1. **Confirm to the user:** "Connection established to [Board] on [Port]
   with libraries: [list]."
2. **If the user's prompt includes a task** beyond just connecting (e.g.,
   "blink LED", "read ultrasonic sensor"), announce: "Now proceeding
   with [task]..." and continue with the downstream workflow.

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `arduinolist` | Discover connected Arduino boards (table output) | R2024a |
| `serialportlist("available")` | List all available serial ports | R2019b |
| `arduino(port)` | Connect with auto-detected board type, default libraries | R2014b |
| `arduino(port, board)` | Connect with specified board, default libraries | R2014b |
| `arduino(port, board, 'Libraries', libs)` | Connect with specified board and custom libraries | R2014b |
| `listArduinoLibraries` | List all available add-on libraries | R2014b |

## Patterns

### Single board connection

```matlab
% TEMPLATE — not executable
% Step 1: Discover
list = arduinolist;
ports = serialportlist("available");

% Step 3-5: Connect (after user selects port and board is known)
a = arduino('COM8', 'Nano33BLE', 'Libraries', {'I2C', 'SPI', 'Servo', 'Ultrasonic'});
```

### Multi-board connection

```matlab
% TEMPLATE — not executable
% Connect to each board with its own variable and libraries
a1 = arduino('COM8', 'Nano33BLE', 'Libraries', {'I2C', 'SPI', 'Servo'});
a2 = arduino('COM52', 'Uno', 'Libraries', {'I2C', 'SPI', 'Servo', 'Ultrasonic'});
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using `arduino()` with no arguments | Connects to arbitrary board without user consent | Always discover first, let user choose |
| Guessing COM port or board type | Wastes time on wrong ports, reflashes wrong boards | Ask the user, or use auto-detect with port only |
| Loading only the needed library | Reconnecting later with more libraries takes 30+ sec | Load defaults `{'I2C','SPI','Servo'}` plus any inferred extras |
| Using `arduino(port, 'Libraries', libs)` without board | Error: must specify both port and board before name-value pairs | Use `arduino(port, board, 'Libraries', libs)` or `arduino(port)` for auto-detect with defaults |
| Skipping `serialportlist` when `arduinolist` succeeds | Misses boards without support package firmware or pre-R2024a boards | Always run both — `serialportlist` is mandatory even when `arduinolist` returns results |
| Killing processes to free a port | Destructive action without user consent | Report the port conflict, ask user to close the other application |

## Conventions

- **MUST run both `arduinolist` AND `serialportlist("available")` in every discovery step** — even if `arduinolist` already found the board. `serialportlist` catches boards that `arduinolist` does not recognize.
- Always present discovered information to the user before acting
- Board type is optional — let MATLAB auto-detect when user doesn't know
- Default libraries `{'I2C', 'SPI', 'Servo'}` are always included
- Never take destructive actions (killing processes, clearing workspaces) without asking
- Clearly separate the connection step from downstream task execution
- **Arduino hardware is not shareable** — only one MATLAB session can hold a
  connection to a given board at a time. Do not run multiple parallel agents
  that each try to connect to Arduino hardware. Run Arduino workflows
  sequentially.

----

Copyright 2026 The MathWorks, Inc.

----
