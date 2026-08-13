---
name: matlab-connect-bluetooth-low-energy-device
description: >
  Discover and connect to Bluetooth Low Energy (BLE) peripheral devices from
  MATLAB. Use this skill when the user wants to scan for BLE devices, connect
  to a BLE peripheral, read or write BLE characteristics, subscribe to
  notifications, or any task that requires a BLE connection as a prerequisite
  (e.g., read sensor data over BLE, monitor heart rate, log accelerometer,
  stream data from wearable, IoT device communication). Triggers on: BLE,
  Bluetooth Low Energy, blelist, ble device, BLE characteristic, GATT,
  service UUID, scan for devices, BLE sensor, subscribe notify, BLE read,
  BLE write, peripheral device, BLE connect, wireless sensor.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "2.0"
---

# Connect to BLE Device in MATLAB

Guides the agent through discovering, connecting to, and accessing
characteristics on BLE peripheral devices, ensuring efficient use of
filtering APIs and correct function signatures.

**BLE functions are part of MATLAB — no additional toolbox is required.**
Do not reference the Bluetooth Toolbox for BLE functionality — it is
not needed.

## When to Use

- User wants to scan for or connect to a BLE device
- User wants to read, write, or subscribe to BLE characteristics
- User's task requires a BLE connection as a prerequisite (sensor data,
  IoT communication, wearable monitoring)
- User mentions BLE, Bluetooth Low Energy, GATT, service UUID, or
  characteristic UUID

## When NOT to Use

- Bluetooth Classic connections (`bluetooth()` object — different API)
- BLE peripheral mode (MATLAB acting as a BLE server/advertiser)
- Arduino BLE via Arduino Support Package (see `matlab-connect-arduino`)
- Support package installation or Bluetooth adapter driver issues
- Simulink BLE blocks

## Workflow

Follow these steps in order. **Do not skip steps or guess values.**

### Step 0: Check workspace for existing connections

**Always check first** — a connected BLE device stops advertising, so
scanning will never find it:

```matlab
% Check for existing ble objects in workspace
bleVars = whos;
bleVars = bleVars(strcmp({bleVars.class}, 'ble'));
```

If a `ble` object exists and its `Connected` property is `1`:
- Tell the user: "Found existing connection to [Name] on [Address]."
- Ask if they want to reuse it or connect to a different device.
- **STOP and wait for user response.**
- If reusing, skip to Step 4.

If a `ble` object exists but `Connected` is `0`, it is stale — proceed
to Step 1.

### Step 1: Discover devices

Use filtered scanning when possible. **Do not scan all devices and then
search through results manually.**

| User provides | Use this call |
|---------------|---------------|
| Device name | `blelist("Name", "<name>")` |
| Service UUID | `blelist("Services", "<uuid>")` |
| Nothing specific | `blelist("Timeout", 10)` |

```matlab
% Filter by name (prefix match)
devices = blelist("Name", "HeartSensor");

% Filter by advertised service UUID
devices = blelist("Services", "180D");

% General scan with extended timeout
devices = blelist("Timeout", 10);
```

Filters can be combined:
```matlab
devices = blelist("Name", "Sensor", "Timeout", 15);
```

`blelist` returns a table with columns: Name, Address, RSSI, Advertisement.
Results are sorted by signal strength (strongest first).

Present results to the user.

### Step 1b: Handle "no device found"

If `blelist` returns an empty table:

1. **Check Step 0 again** — the device may already be connected (and
   therefore not advertising).
2. **Ask the user:** "No BLE device was found. Is the device powered on
   and advertising?"
3. **Suggest common fixes:**
   - Ensure the device is in advertising/pairing mode
   - Move closer (BLE range is typically 10-30 meters)
   - Check that no other application holds the connection (nRF Connect,
     LightBlue, another MATLAB session)
   - Try a longer timeout: `blelist("Timeout", 20)`
   - Restart the device to force re-advertising
4. **STOP and wait.** Do not proceed until the user confirms the device
   is available.

### Step 2: Let user choose device

Present the discovered devices and ask which to connect to.
**Never auto-select a device.**

If only one device matches a filtered scan (e.g., `blelist("Name","MyDevice")`
returned exactly one row), confirm with the user: "Found [Name] at
[Address]. Shall I connect?"

### Step 3: Connect

```matlab
% Connect by name (substitute the user's actual device name)
b = ble("HeartSensor");

% Connect by address (use when name is empty or ambiguous)
b = ble("A1B2C3D4E5F6");
```

After connecting, confirm to the user:
- Device name and address
- Number of services and characteristics available

If the connection succeeds but a service shows "Access denied":
- **Most likely cause:** Another MATLAB session (or application) holds a
  connection to the same device. The Windows BLE stack denies access to
  services that are already claimed.
- **Fix:** Ask the user to disconnect from all other sessions (`clear b`
  in the other session, or close it), then reconnect from this session.
- **Do NOT diagnose this as a pairing/bonding issue** — that is rarely
  the cause for custom services that previously worked.

If the connection fails entirely:
1. Report the exact error to the user
2. Common causes: device out of range, device already connected elsewhere,
   Bluetooth adapter disabled
3. Do not retry automatically — wait for user instruction

### Step 4: Access characteristics

Inspect available services and characteristics:

```matlab
% View all services
b.Services

% View all characteristics (includes service, name, UUID, attributes)
b.Characteristics
```

To access a specific characteristic, use the **two-UUID signature**:

```matlab
% Access by service UUID + characteristic UUID
c = characteristic(b, "<serviceUUID>", "<characteristicUUID>");

% Access by service name + characteristic name (standard services only)
c = characteristic(b, "Battery Service", "Battery Level");
```

**Important:** `characteristic()` always requires both a service
identifier and a characteristic identifier. Never call it with just
one UUID.

**Never invent or assume device names, addresses, service UUIDs, or
characteristic UUIDs.** Use only values provided by the user or
discovered from `blelist` / `b.Characteristics`.

If characteristic access fails:
- "No characteristic found" → UUID is wrong. Inspect `b.Characteristics`
  to find the correct service and characteristic UUIDs.
- "Access denied" → another session holds the connection (same fix as
  Step 3: disconnect from other sessions first).
- Never guess UUIDs — ask the user or read them from the device.

### Step 5: Read / Write / Subscribe

```matlab
% Read raw bytes from a characteristic (returns numeric array)
data = read(c);

% Read with timestamp
[data, timestamp] = read(c);

% Read oldest buffered notification (use in DataAvailableFcn callbacks)
data = read(c, "oldest");

% Write data to a characteristic
write(c, [1 0 1 0]);

% Write without response (faster, no confirmation)
write(c, [1 0 1 0], "WithoutResponse");

% Subscribe to notifications
subscribe(c);
c.DataAvailableFcn = @(src, evt) disp(read(src));

% Unsubscribe
unsubscribe(c);
```

**`read` and `write` operate on characteristic objects, not on the `ble`
object directly.** Never use `read(b, uuid)` — this will error.

## Key Functions

| Function | Purpose |
|----------|---------|
| `blelist` | Scan for BLE peripherals (with optional Name/Services/Timeout filters) |
| `ble(name)` | Connect to a BLE device by advertised name |
| `ble(address)` | Connect to a BLE device by MAC address |
| `characteristic(b, svcID, charID)` | Access a characteristic (requires both service and characteristic identifiers) |
| `read(c)` | Read data from a characteristic object |
| `write(c, data)` | Write data to a characteristic object |
| `subscribe(c)` | Subscribe to notifications/indications |
| `unsubscribe(c)` | Unsubscribe from notifications/indications |

All functions are part of MATLAB — no toolbox required.

## Patterns

### Single device by name

```matlab
% TEMPLATE — not executable without hardware
% Step 0: Check workspace
bleVars = whos;
bleVars = bleVars(strcmp({bleVars.class}, 'ble'));

% Step 1: Filtered discovery
devices = blelist("Name", "TempLogger");

% Step 3: Connect
b = ble("TempLogger");

% Step 4-5: Access and read custom characteristic
c = characteristic(b, "181A", "2A6E");
data = read(c);
```

### Find device by service UUID

```matlab
% TEMPLATE — not executable without hardware
% Find devices advertising a specific service
devices = blelist("Services", "180D");

% Connect to the first match (after user confirms)
b = ble(devices.Name(1));

% List characteristics under that service
b.Characteristics
```

### Reuse existing connection

```matlab
% TEMPLATE — not executable without hardware
% Check if 'b' already exists and is connected
if exist('b', 'var') && isa(b, 'ble') && b.Connected
    disp("Reusing existing connection to " + b.Name);
else
    b = ble("MyDevice");
end

% Access characteristic on existing connection
c = characteristic(b, "180F", "2A19");
batteryLevel = read(c);
```

### Subscribe to notifications

```matlab
% TEMPLATE — not executable without hardware
c = characteristic(b, "180D", "2A37");
subscribe(c);
c.DataAvailableFcn = @(src, evt) processHeartRate(read(src));

% Later: clean up
unsubscribe(c);
```

### Log characteristic data via notifications

When the user wants to **log** or **collect** BLE data over a time period,
use `DataAvailableFcn` with `subscribe`/`unsubscribe` — **do not poll with
`read(c)` in a loop** (polling misses data between reads and may flush the
buffer).

Deploy `scripts/bleDataCollector.m` to the user's working directory and run:

```matlab
% TEMPLATE — not executable without hardware
% Log notifications to a tab-separated text file for 10 seconds:
bleDataCollector(b, "<serviceUUID>", "<charUUID>", 10, "sensorLog.txt")
```

Output file format (one row per notification):
```
2026-06-25 10:30:01.0529	3 12 255
2026-06-25 10:30:01.2478	4 13 0
```

**Key points for notification-based logging:**
- Set `DataAvailableFcn` to a callback that calls `read(src, "oldest")` —
  using `"oldest"` reads buffered notification data in order; `"latest"` may
  flush and lose earlier packets
- Call `subscribe(c)` to start receiving notifications, `unsubscribe(c)` to
  stop
- `pause(duration)` keeps MATLAB alive while callbacks fire — this is NOT
  polling, it is the idle loop that allows notifications to be delivered
- Always `unsubscribe`, clear `DataAvailableFcn`, and `fclose` when done
- Log to `.txt` with tab separation — BLE packets vary in length, so
  fixed-column CSV is impractical

Script: [scripts/bleDataCollector.m](scripts/bleDataCollector.m) (bundled with this skill — deploy to the user's working directory before use)

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Using unfiltered `blelist` when name/service is known | Scans all devices unnecessarily; slower and noisier | Use `blelist("Name","...")` or `blelist("Services","...")` |
| Calling `read(b, uuid)` on the ble object | `read` works on characteristic objects, not ble objects — will error | Create characteristic first: `c = characteristic(b, svc, char)`, then `read(c)` |
| Using `blescanner` | This function does not exist in MATLAB | Use `blelist` (with optional name-value filters) |
| Saying BLE requires "Bluetooth Toolbox" | BLE functions are part of MATLAB — no toolbox needed | Do not check for or reference the Bluetooth Toolbox |
| Scanning for a device that is already connected | Connected devices stop advertising — scan will never find them | Check workspace for existing `ble` objects first (Step 0) |
| Calling `characteristic(b, uuid)` with one UUID | Requires both service and characteristic identifiers | Use `characteristic(b, serviceUUID, characteristicUUID)` |
| Auto-selecting a device without user confirmation | User may have multiple devices; wrong choice wastes time | Always present options and ask which device to connect to |
| Diagnosing "Access denied" as a pairing issue | Usually caused by another session holding the connection, not missing pairing | Ask user to disconnect from other MATLAB sessions first |

## Conventions

- **Always check workspace for existing `ble` connections before scanning** — connected devices stop advertising
- **Use filtered `blelist` when name or service UUID is known** — never scan all and search manually
- Always present discovered devices to the user before connecting
- Never auto-select a device — let the user choose
- `read`/`write`/`subscribe` operate on characteristic objects, not ble objects
- `characteristic()` requires two identifiers: service + characteristic
- BLE is part of MATLAB — never state or check for toolbox requirements
- **BLE connections are exclusive** — only one application can hold a connection to a given device at a time

----

Copyright 2026 The MathWorks, Inc.

----
