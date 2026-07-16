# Supported Hardware Targets

## STM32 Discovery Boards (ARM Cortex-M)

| Board | MCU | RAM | Flash |
|-------|-----|-----|-------|
| STM32F746G-Discovery | ARM Cortex-M7 | 340KB SRAM | 1MB |
| STM32F769I-Discovery | ARM Cortex-M7 | 512KB SRAM | 2MB |
| STM32F4-Discovery | ARM Cortex-M4 | 192KB SRAM | 1MB |

**Support package:** "Embedded Coder Support Package for STMicroelectronics Discovery Boards"

**PIL interface:** Serial (UART over USB)

```matlab
cfg.Hardware = coder.hardware("STM32F746G-Discovery");
cfg.Hardware.PILInterface = "Serial";
cfg.Hardware.PILCOMPort = "COM4";       % Windows
cfg.Hardware.PILCOMPort = "/dev/ttyACM0"; % Linux
```

**Constraints:**
- No dynamic memory — `EnableDynamicMemoryAllocation = false` required
- All arrays must be bounded at compile time
- Prefer `TargetLang = "C"` for smaller code footprint
- Set `StackUsageMax` based on available SRAM (typically 512–2048 bytes for DL models)

## Raspberry Pi (ARM Cortex-A)

| Board | MCU | RAM |
|-------|-----|-----|
| Raspberry Pi 4 Model B | ARM Cortex-A72 | 1–8GB |
| Raspberry Pi 5 | ARM Cortex-A76 | 4–8GB |

**Support package:** "MATLAB Support Package for Raspberry Pi Hardware" (or "Raspberry Pi Blockset" from R2026a)

**PIL interface:** SSH (Linux-based board)

```matlab
cfg = coder.config("lib", "ecoder", true);
cfg.VerificationMode = "PIL";
cfg.Hardware = coder.hardware("Raspberry Pi");
cfg.Hardware.BuildDir = "/home/pi/mymodel";
```

**Characteristics:**
- PIL deploys an ELF executable to the Pi and generates a PIL MEX on the host
- Runs over SSH (unlike serial for Cortex-M)
- Generates pure portable C code by default (no ARM Compute Library required)
- Dynamic memory is available but can be disabled for determinism

## Choosing Between Cortex-M and Cortex-A

| Factor | Cortex-M (STM32) | Cortex-A (Raspberry Pi) |
|--------|-------------------|------------------------|
| Memory | KB range — must be static | GB range — heap available |
| OS | Bare-metal or RTOS | Linux |
| PIL transport | Serial (UART) | SSH |
| Dynamic memory | Must disable | Optional |
| Use case | Hard real-time, low power | Soft real-time, complex models |

----

Copyright 2026 The MathWorks, Inc.

----
