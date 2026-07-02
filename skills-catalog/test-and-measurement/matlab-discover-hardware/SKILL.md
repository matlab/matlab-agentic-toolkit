---
name: matlab-discover-hardware
description: "Discovers connected MATLAB-supported hardware devices, searches by capability, and checks required support packages and add-ons. Use when the user asks what hardware is connected, finds a device that supports a capability (e.g., CAN, analog input), or checks if required support packages or add-ons are installed."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Hardware Discovery

## 1. What this skill is for

Use this skill to perform **hardware discovery** tasks from natural language: list connected devices, search by capability, inspect a device's details and capabilities, and check if required support packages or add-ons are installed.

This skill exposes hardware discovery functionality through MATLAB helper functions bundled in `scripts/`. Always use the provided helpers — do not attempt to replicate their behavior or call any internal MATLAB functions directly.

## When To Use

Activate this skill when the user asks about:

- What hardware is connected or available (e.g., "what's plugged in?", "what devices do I have?")
- Which devices support a given capability (e.g., "what supports CAN?", "which devices can do analog input?")
- Details or capabilities of a specific device (e.g., "tell me about the Arduino Due", "what can the NI USB-6211 do?")
- Whether required support packages or add-ons for a device are installed
- What needs to be installed to use a specific device

## When Not To Use

Do not activate this skill for:

- Non-hardware MATLAB work (general scripting, algorithm development, plotting, etc.)
- Acquiring or streaming data from a device (use device-specific skills instead)
- Configuring or programming a specific device after discovery (use device-specific skills)
- Installing support packages directly — this skill only reports install state; defer to an install-capable skill when one is available

## 2. One-time bootstrap (path setup)

Before invoking any helper, add the bundled `scripts/` folder to the MATLAB path **once** per session:

```matlab
addpath(fullfile("<skill-root>", "scripts"))
```

Replace `<skill-root>` with the absolute path of this skill's folder (e.g., `.../.claude/skills/matlab-discover-hardware`).

This `addpath` is the **only allowed path mutation** in this skill. After bootstrap:

- Do **not** call `addpath`, `rmpath`, or `cd` again
- Do **not** call `clear all`
- Do **not** create new `.m` files

If a helper call fails with `Undefined function`, re-run the bootstrap once. If it still fails, report the error to the user; do not invent workarounds.

The bootstrap `addpath` is performed automatically before skill activation — you do not need to include it in your helper calls.

## 3. Public helper surface

Use **only** these 4 public helpers (located in `scripts/`):

| Layer | Helper | Purpose |
|---|---|---|
| 1 — Discovery | `listHardwareDevices` | List devices (default: connected only) |
| 2 — Detail | `getDeviceDetails` | Full info for a named device (capabilities, support packages, technical details) |
| 2 — Detail | `getDeviceSetupInfo` | Required packages, install state |
| 2 — Detail | `isRequiredAddOnsInstalled` | Logical check: are all required add-ons installed? |

**Internal — do not call:** `hardwareDeviceCache.m`, `getDeviceAddOns.m`, and `getAddOnDetails.m` exist in `scripts/` only because the public helpers depend on them. They are not part of the agent surface and must not be invoked directly.

**Duplicate-name behavior:** `getDeviceDetails` returns one struct per matching device (struct array if multiple share a name). `getDeviceSetupInfo` and `isRequiredAddOnsInstalled` return a single result (all same-name devices share add-on requirements).

**Important:** Always use the public helpers listed above. Do not attempt to call internal MATLAB functions or replicate helper behavior manually.

## 4. Task routing

Pick the helper that matches the user's intent. **Combine all calls for a task into the minimum number of `evaluate_matlab_code` invocations** (see §5 for batching recipes).

| User intent | Helper(s) to call |
|---|---|
| "What hardware do I have?" / "What's connected?" | `listHardwareDevices` |
| "Which devices support X?" (capability search) | `listHardwareDevices(Capability=keyword)` |
| "Tell me about <device>" / "What can <device> do?" | `getDeviceDetails(deviceName)` + `isRequiredAddOnsInstalled(deviceName)` |
| "What do I need to install for <device>?" / "What is required to use <device>?" / "How do I use <device>?" / "Can I use <device>?" | `getDeviceSetupInfo(deviceName)` |
| "Are the add-ons for <device> installed?" | `isRequiredAddOnsInstalled(deviceName)` |
| "Install the <device> support package / toolbox" | Check the available skills list for an install-capable skill and silently invoke it if found. Otherwise, tell the user to open **MATLAB Add-On Explorer** (Home tab → Add-Ons → Get Add-Ons) and search by package name. |
| Device not found (neither connected nor in "All" mode) | Inform the user that the hardware was not detected. Do not guess what products are needed. Silently check the available skills list for skills that can search for or install products, and offer to help find what's required — without naming the specific skills to the user. |

When the user's question fits multiple tasks, prefer the cheapest/most-targeted helper first (e.g., `listHardwareDevices(Capability=...)` before `getDeviceDetails`).

## 5. Workflow patterns and batching

### Critical: minimize MCP round-trips

Each `evaluate_matlab_code` call is an MCP round-trip that requires user approval. **Batch multiple helper calls into a single `evaluate_matlab_code` invocation** whenever possible. The helpers share an internal cache (60 s TTL), so calling them sequentially in one script is efficient.

**Rules:**
1. Combine Layer 1 + Layer 2 calls when you already know the device name
2. Combine install-state checks with the detail call that precedes them
4. Target **1–2 MCP calls total** for any single user question

### Batching recipes

#### Recipe A: "What hardware is connected?" (1 MCP call)
```matlab
deviceList = listHardwareDevices();
disp(deviceList)
clear deviceList
```

#### Recipe B: "Tell me about <device>" / "What can <device> do?" (2 MCP calls)

**Call 1** — discover (to confirm device exists):
```matlab
deviceList = listHardwareDevices();
disp(deviceList)
clear deviceList
```

**Call 2** — details + install-state check (combined):
```matlab
details = getDeviceDetails("<deviceName>");
disp(details);
isInstalled = isRequiredAddOnsInstalled("<deviceName>");
if ~isInstalled
    setupInfo = getDeviceSetupInfo("<deviceName>");
    disp(setupInfo);
end
clear details isInstalled setupInfo
```

If the user **names the device directly** and you are confident in the name (e.g., they typed "Arduino Due"), skip Call 1 and do everything in a single call:
```matlab
details = getDeviceDetails("<deviceName>");
disp(details);
isInstalled = isRequiredAddOnsInstalled("<deviceName>");
if ~isInstalled
    setupInfo = getDeviceSetupInfo("<deviceName>");
    disp(setupInfo);
end
clear details isInstalled setupInfo
```

**Multi-result handling:** `getDeviceDetails` returns a struct array when multiple devices share the same name (e.g., two "Kvaser Virtual" channels). If `numel(details) > 1`, do not present all results — instead trigger the disambiguation flow (§5 Plain-text disambiguation) using `ConnectionInfo` or other distinguishing fields from each element's `BasicInfo`.

#### Recipe C: "What do I need to install for <device>?" (1 MCP call)
```matlab
setupInfo = getDeviceSetupInfo("<deviceName>");
disp(setupInfo)
clear setupInfo
```

#### Recipe D: Capability search (1–2 MCP calls)
```matlab
results = listHardwareDevices(Capability="<keyword>");
disp(results)
clear results
```
If results are found and user wants details, follow with Recipe B Call 2.


### Discover-then-detail
Call a Layer 1 helper (`listHardwareDevices` or `listHardwareDevices(Capability=...)`) before drilling into a Layer 2 helper. Do not guess device names. **Exception:** if the user explicitly names a device, skip discovery and go directly to Layer 2 (see Recipe B single-call variant).

### Capability-first search
When the user describes a *task* ("I want to read CAN messages"), call `listHardwareDevices(Capability="CAN")` before naming a specific device.

If the capability search returns **no results**, do not guess alternative keywords or invent suggestions from your own knowledge. Instead:
1. Call `listHardwareDevices()` to show all connected devices
2. Present the list to the user and ask which device they intended to use for the task
3. Once the user identifies a device, proceed with the Install-state check workflow

### Install-state check
When the user asks what they need for a device, or asks how to use / whether they can use a specific device, use Recipe C (`getDeviceSetupInfo` includes the install-state boolean). If packages are missing, list them by human-readable name. Silently check the available skills list for an install-capable skill — if one exists, offer to install on the user's behalf without naming the skill. Only fall back to telling the user to open **MATLAB Add-On Explorer** (Home tab → Add-Ons → Get Add-Ons) if no such skill is available.

### Handling empty or missing capabilities
When `getDeviceDetails` returns an empty `Capabilities` field for a device, do **not** guess or infer capabilities from general knowledge of the board. Instead:
1. Check the currently loaded skills for any skill related to that hardware type (e.g., DAQ skills for NI devices, radio skills for USRP, Arduino-specific skills)
2. If a relevant loaded skill exists, silently invoke it to gather capability or usage information — do not name the skill to the user
3. Present whatever information you gather as device capabilities, citing only the hardware and what it supports
4. If no relevant loaded skill is found and no other source is available, tell the user: "Detailed capability information is not available for this device. You may find more information in the device's documentation." and include the `HardwareSupportUrl` if available

**Never** fill in capabilities from training data. Only report capabilities sourced from helper output or from another loaded skill's verified output.

### Post-condition: always check install state after device-specific queries
Include `isRequiredAddOnsInstalled(deviceName)` in the same batched call as `getDeviceDetails` (see Recipe B). If add-ons are missing, follow the Install-state check workflow. Do not advise the user on using a device without first confirming the required add-ons are installed.

### Plain-text disambiguation
If a query returns multiple matches (or a partial name matches several devices), you **MUST ask the user which device they mean BEFORE fetching or presenting details**. Do not silently show details for all matches — present a numbered list of options with distinguishing attributes and wait for the user to choose.

Identify each option by `FriendlyName` plus its **Device ID** or `ConnectionInfo` as the distinguishing attribute. **Never** call `input()` or any blocking prompt. When multiple entries represent the same physical port discovered by different plugins, explain that they are different *interfaces* to the same port (e.g., VISA vs. serialport) and which toolbox each corresponds to — but **never mention plugin names, plugin sources, or internal detection mechanisms**.

## 6. Communication rules

- Identify devices to the user by **`FriendlyName`**, not by vendor IDs or class names
- When disambiguating devices with identical names, show the **Device ID** as the distinguishing attribute. Resolve Device ID using this fallback chain: `UUID` → `ConnectionInfo` (from `listHardwareDevices` table, which includes port info from `CustomData.TransportProperties.Port`). Present it as "Device ID" to the user — never say "UUID"
- **Never mention plugins** to the user — not plugin names, plugin sources, the `Plugin` parameter, or internal detection mechanisms. These are implementation details. When disambiguating duplicate entries, explain the difference in terms of **interface type** (e.g., "VISA interface" vs. "serialport interface") and which toolbox/function the user would call.
- Do not pass the `Plugin=` option to `listHardwareDevices` unless you need it internally for performance; never surface the plugin name in your response.
- When listing more than ~10 devices, summarize counts per category first, then offer to drill in
- **Do not mention support packages, install state, or "additional packages available"** when answering general listing/browsing queries (e.g., "what's connected?", "what device types are supported?"). This applies to your entire response — body text AND follow-up offers. Do not include the words "support package" anywhere in a listing response, even as one option among several. Bad: "Would you like details on capabilities, support packages, or setup?" Good: "Would you like details on any specific device or its capabilities?" Only bring up support packages when the user expresses intent to *use* a specific device (e.g., "how do I use the Arduino?", "can I use the webcam?").
- When support packages *are* relevant, present them by their **human-readable names** (e.g., "MATLAB Support Package for Arduino Hardware"). Never expose raw base codes (e.g., `"ML_ARDUINO"`) to the user.
- Be faithful to helper output: do not invent capabilities, examples, or documentation links the helpers did not return

## 7. Hard guardrails

- **No internal API calls.** Never call internal MATLAB functions directly — always use the provided helpers
- **No path mutations beyond bootstrap.** No `addpath`, `rmpath`, or `cd` after the one-time bootstrap
- **No `clear all`.** Clear specific variables only if needed
- **No `Refresh=true` by default.** Pass `Refresh=true` only when the user explicitly asks for fresh data ("scan again", "refresh", "what's connected now?")
- **No new MATLAB files.** This skill is consumption-only
- **No install assumptions.** Always check install state via `isRequiredAddOnsInstalled` or `getDeviceSetupInfo` before claiming a package is ready
- **No manual install fallback when an install-capable skill is available.** Silently check the available skills list; if one can install products, offer to install on the user's behalf rather than describing Add-On Explorer steps. Never expose internal skill names to the user.

## 8. Interpreting CustomData

The `getDeviceDetails` output may include a **CustomData** field containing device-specific technical information not available in the standard fields. When `CustomData` is present and non-empty, it contains extra details worth surfacing to the user — for example:

- **Transport properties:** serial port (`Address`/`Port`), baud rate, connection type (Serial, WiFi, Bluetooth)
- **Hardware identifiers:** serial number, manufacturer, VID/PID (USB vendor/product IDs)
- **Board-specific info:** board variant, firmware version, WiFi port

**Always inspect CustomData** when answering questions about a device's connection, port, address, or hardware identity. The standard `BasicInfo.ConnectionInfo` field may be empty even when `CustomData` contains the actual port or address. Treat CustomData as the authoritative source for transport-level details.

When presenting CustomData to the user, use plain language (e.g., "connected on COM4 via USB") rather than dumping raw struct fields.

## 9. Output-handling guidance

All helpers support **dual output** based on `nargout`:

- **Capture the output** (`x = listHardwareDevices()`) when you need to reason over the data, filter it, or extract a field for the next call. This suppresses MATLAB's display.
- **Call without output** (`listHardwareDevices()`) when the user explicitly wants the helper's formatted display in the MATLAB command window.

Default to capturing outputs and using `disp()` to show them. This allows you to chain multiple calls in a single script while still surfacing results. Use display mode (no output capture) only for standalone single-helper calls.

When batching multiple helpers in one script, use `disp()` or `fprintf()` between calls to surface intermediate results. **Always clear temporary variables at the end** to avoid polluting the user's workspace:
```matlab
details = getDeviceDetails("Arduino Due");
disp(details);
isInstalled = isRequiredAddOnsInstalled("Arduino Due");
fprintf("Add-ons installed: %d\n", isInstalled);
clear details isInstalled
```

----

Copyright 2026 The MathWorks, Inc.

----
