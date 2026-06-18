# Hardware Bus Conflicts with MATLAB Arduino Server

The MATLAB Arduino server manages certain hardware peripherals. Using them directly
in your add-on C++ code causes communication failures.

## Conflict Table

| Bus | MATLAB owns it? | Safe to use directly? | Workaround |
|-----|-----------------|----------------------|------------|
| I2C (Wire) | YES | NO | Use software I2C (SW_I2C constructors) |
| SPI | NO | YES | Include `<SPI.h>`, use HW_SPI constructors |
| UART/Serial | YES (Serial) | NO | Use Serial1/Serial2 if available |
| GPIO | Shared | YES | Reserve pins via MATLAB `configurePinResource` |

## I2C Conflict Details

- The MATLAB server initializes and owns the hardware I2C bus (`Wire`).
- If your add-on calls `Wire.begin()` (directly or via a library like U8g2's HW_I2C
  constructor), it re-initializes the bus and breaks the server communication.
- **Symptom:** `addon()` call hangs or returns "Unable to receive data from target hardware"
- **Fix:** Use software-bit-banged I2C (e.g., `U8G2_..._SW_I2C` constructors).
  Software I2C just toggles GPIO pins and never touches the Wire peripheral.

Example for U8g2 OLED via software I2C:

```cpp
// GOOD — software I2C, no Wire conflict
U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, /* clock=*/ SCL, /* data=*/ SDA, /* reset=*/ U8X8_PIN_NONE);
```

```cpp
// BAD — hardware I2C, conflicts with MATLAB server
#include <Wire.h>  // NEVER include this
U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* reset=*/ U8X8_PIN_NONE);
```

## When DependentLibraries = {'I2C'} IS Correct

Use `DependentLibraries = {'I2C'}` only when your addon **delegates I2C communication
to MATLAB's built-in I2C infrastructure** — meaning your MATLAB class calls
`scanI2CBus`, uses `getI2CTerminals`, or configures I2C pins via `configurePinResource`
with the `'I2C'` resource owner.

In this case, MATLAB manages Wire initialization and your C++ code can use Wire
(without calling `Wire.begin()`) because MATLAB already set it up.

Example: the shipped `Adafruit/MotorShieldV2` addon uses `DependentLibraries = {'Servo', 'I2C'}`
because it calls `getI2CTerminals`, `configurePinResource`, and manages I2C addresses
through MATLAB's infrastructure.

## SPI is Generally Safe

- The MATLAB server does NOT own the SPI bus.
- You can freely include `<SPI.h>` and use HW_SPI constructors.
- Just ensure CS/DC/RESET pins are reserved in MATLAB via `configurePinResource`.

Example for U8g2 OLED via hardware SPI:

```cpp
#include <SPI.h>
U8G2_SSD1306_128X64_NONAME_F_4W_HW_SPI u8g2(U8G2_R0, /* cs=*/ 10, /* dc=*/ 9, /* reset=*/ 8);
```

## Combining Multiple Add-ons

Multiple custom libraries can be loaded simultaneously:

```matlab
a = arduino("COM19", "UnoR4Minima", "Libraries", {"MyDHT22Folder/MyDHT22", "MyOLEDFolder/MyOLED"});
dht = addon(a, "MyDHT22Folder/MyDHT22", "D2");
oled = addon(a, "MyOLEDFolder/MyOLED");
```

Both add-ons compile into a single server binary. Ensure no pin or bus conflicts
between them.

----

Copyright 2026 The MathWorks, Inc.

----
