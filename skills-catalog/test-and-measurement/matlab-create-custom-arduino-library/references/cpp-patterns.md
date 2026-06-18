# C++ Header File Patterns

## Lazy Initialization Pattern

The MATLAB Arduino server calls `setup()` during its own boot sequence. If `setup()`
initializes hardware (Wire.begin, SPI.begin, sensor.begin, etc.), it conflicts
with the server's handshake and causes "Internal error: The initialization of the
server code is incorrect."

**Solution:** Initialize hardware lazily on first command.

```cpp
// MySensor addon — custom MATLAB Arduino library for MySensor peripheral
#include "LibraryBase.h"
#include <MySensor.h>

// Command IDs sent from MATLAB to identify the requested operation
#define CMD_INIT    0x00  // Initialize sensor on specified pin
#define CMD_READ    0x01  // Read sensor value and return to MATLAB
#define CMD_DELETE  0x02  // Release sensor resources

class MySensorAddon : public LibraryBase {
public:
    MySensor* sensor;
    bool initialized;
    uint8_t sensorPin;

    MySensorAddon(MWArduinoClass& a) : sensor(nullptr), initialized(false) {
        libName = "MySensorFolder/MySensor";
        a.registerLibrary(this);
    }

    void setup() {
        // EMPTY — do NOT initialize hardware here
    }

    void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize) {
        switch (cmdID) {
            case CMD_INIT: {
                // Create sensor instance and initialize hardware
                sensorPin = dataIn[0];
                sensor = new MySensor(sensorPin);
                sensor->begin();
                initialized = true;
                byte val = 1;
                sendResponseMsg(cmdID, &val, 1);
                break;
            }
            case CMD_READ: {
                // Read sensor data and send back to MATLAB
                float reading = sensor->read();
                sendResponseMsg(cmdID, (byte*)&reading, sizeof(float));
                break;
            }
            case CMD_DELETE: {
                // Clean up sensor resources
                if (sensor != nullptr) {
                    delete sensor;
                    sensor = nullptr;
                }
                initialized = false;
                byte val = 1;
                sendResponseMsg(cmdID, &val, 1);
                break;
            }
            default:
                break;
        }
    }
};
```

## Member Object Initialization

Use the **constructor initializer list**, not in-class member initializers. In-class
initialization can fail on ARM-based boards (UNO R4, ESP32).

```cpp
// GOOD — initializer list
MySensorAddon(MWArduinoClass& a) : sensor(nullptr), initialized(false) {
    libName = "MySensorFolder/MySensor";
    a.registerLibrary(this);
}

// BAD — in-class initialization (can crash on UNO R4)
private:
    MySensor* sensor = nullptr;
    bool initialized = false;
```

## sendResponseMsg Pattern

Always send at least 1 byte of response data. Do NOT use `0` or `nullptr` as the
data pointer — ARM-based toolchains (UNO R4, ESP32) may crash.

```cpp
// GOOD — always send >= 1 byte
byte val = 1;
sendResponseMsg(cmdID, &val, 1);

// GOOD — send actual data
float reading = sensor->read();
sendResponseMsg(cmdID, (byte*)&reading, sizeof(float));

// BAD — crashes on ARM boards
sendResponseMsg(cmdID, 0, 0);
```

## Include Directives

- Use angle brackets for third-party Arduino library headers: `#include <U8g2lib.h>`
- Do NOT use quoted paths like `#include "LibraryName/src/header.h"`
- The Arduino build system resolves paths automatically via `LibraryHeaderFiles` in
  the MATLAB .m file

### Wire.h — Hard Rule

**Your addon header MUST NOT contain `#include <Wire.h>`.** No exceptions for your
own code. MATLAB owns the Wire/I2C bus — including Wire.h causes compilation
conflicts or runtime bus contention.

If your peripheral uses I2C, use a software I2C constructor (e.g., `_SW_I2C`).
Third-party libraries (like SGP30 or Adafruit_MotorShield) may include Wire.h
internally — that is fine, you do not control their code. But in YOUR .h file,
the line `#include <Wire.h>` must never appear.

## Debug Logging

Use `debugPrint` from `LibraryBase` with `PROGMEM` strings for trace output.
User enables via: `arduino('COM3', 'Uno', 'Trace', true)`

```cpp
const char MSG_INIT[] PROGMEM = "MySensor::init(pin=%d)\n";
const char MSG_READ[] PROGMEM = "MySensor::read() --> %s\n";

// In commandHandler:
debugPrint(MSG_INIT, sensorPin);
```

## MATLAB Constructor Calling INIT Command

When hardware needs initialization after server handshake, the MATLAB constructor
sends a dedicated INIT command:

```matlab
methods(Hidden, Access = public)
    function obj = MySensor(parentObj, pin)
        % MySensor — Connect to sensor on the specified pin
        obj.Parent = parentObj;
        terminal = getTerminalsFromPins(obj.Parent, pin);
        configurePinResource(obj.Parent, pin, obj.ResourceOwner, 'DigitalInput');
        % Send INIT command to Arduino to initialize the sensor hardware
        sendCommand(obj, obj.LibraryName, obj.CMD_INIT, terminal);
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----
