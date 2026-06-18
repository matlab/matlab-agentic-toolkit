---
name: matlab-set-up-usrp-radio
description: >
  Set up and verify a connection to an NI USRP radio (USRP E320, N300, N310, N320,
  N321, X300, X310, or X410) using Wireless Testbench. Use when connecting a USRP
  for the first time, configuring radio hardware, troubleshooting connection failures,
  or verifying a radio setup. Covers host inspection (OS, NIC type/speed/MTU), device
  discovery (findsdru, probesdru), UHD version checking, programmatic radio
  configuration, and basebandTransceiver verification. Also use when the user mentions
  USRP setup, radio not found, connection errors, dropped samples, or network
  configuration for SDR hardware.
license: MathWorks BSD-3-Clause
compatibility: ">=R2026a"
metadata:
  author: MathWorks
  version: "1.0"
---

# Set Up USRP Radio with Wireless Testbench

Connect, configure, and verify a supported NI USRP radio for use with Wireless Testbench in MATLAB.

## Required References — Load Immediately

- [references/troubleshooting.md](references/troubleshooting.md) — diagnostic checklist, Mender updates, network path isolation

## When to Use

- Connecting a USRP radio to a host computer for the first time
- Configuring network settings (NIC, IP address, MTU) for USRP streaming
- Running `radioSetupWizard` or `radioConfigurations`
- Troubleshooting "radio not found", connection errors, or dropped samples
- Verifying a radio setup works end-to-end

## When Not to Use

These workflows each require a working radio connection first — use this skill for that setup step.

- FPGA targeting or HDL workflows — check for a dedicated skill, or see [Target NI USRP Radios](https://www.mathworks.com/help/wireless-testbench/target-ni-usrp-devices.html)
- Generating or transmitting waveforms — check for a dedicated skill, or see [Transmit and Capture](https://www.mathworks.com/help/wireless-testbench/transmit-and-capture-RF-signals.html)
- Intelligent capture (preamble/energy detection) — check for a dedicated skill, or see [Spectrum Monitoring](https://www.mathworks.com/help/wireless-testbench/spectrum-monitoring.html)
- Multi-device synchronization — check for a dedicated skill, or see [Radio Management](https://www.mathworks.com/help/wireless-testbench/radio-management.html)
- `comm.SDRuReceiver` or `comm.SDRuTransmitter` path — this skill covers the modern Wireless Testbench path
- Installing MATLAB or toolboxes — do not use or recommend `mpm` (MATLAB Package Manager). This skill assumes MATLAB and the Wireless Testbench support package are already installed.

## Workflow

Follow these steps in order. **Inspect the host and radio before creating any radio configuration.** Every check catches a different class of failure.

### Step 0: Verify Support Package

```matlab
addons = matlab.addons.installedAddons;
if ~any(addons.Identifier == "NI_USRP")
    error("Install 'Wireless Testbench Support Package for NI USRP Radios' via Add-On Explorer.")
end
```

If missing, the user must install it via Add-On Explorer before proceeding.

### Step 1: Inspect Host

Before touching the radio, gather host system information. This determines whether the hardware is capable of 10 GbE streaming.

#### Detect OS and Platform

```matlab
if ispc
    platform = "Windows";
elseif ismac
    platform = "macOS";
else
    platform = "Linux";
end
fprintf("Platform: %s, MATLAB %s\n", platform, version)
```

#### Inspect Network Interfaces (Linux)

```matlab
% List all network interfaces with speed, MTU, and driver info
[~, interfaces] = system('ip -o link show | grep -v "lo:"');
disp(interfaces)
```

Then for each interface that could connect to the USRP, check NIC details:

```matlab
% Replace <iface> with the actual interface name (for example, enp1s0f0)
[~, nicDetails] = system('ethtool <iface> 2>/dev/null | head -30');
disp(nicDetails)

% Check if it's a USB dongle
[~, usbInfo] = system('readlink -f /sys/class/net/<iface>/device 2>/dev/null');
disp(usbInfo)  % If path contains "usb", it's a USB adapter
```

#### Inspect Network Interfaces (Windows)

```matlab
[~, interfaces] = system('powershell "Get-NetAdapter | Format-Table Name, InterfaceDescription, LinkSpeed, MacAddress"');
disp(interfaces)
```

#### What to Look For

| Check | Good | Bad — will cause problems |
|-------|------|--------------------------|
| NIC type | Dedicated PCIe NIC (Intel X520/X710, Mellanox ConnectX) | USB-to-Ethernet dongle |
| Link speed | See link speed table below | 100 Mbps or lower |
| USB path | Not USB | USB hub, USB 2.0, low-performance chipset |
| MTU | See table below — depends on NIC speed | Using wrong MTU for link speed |

#### Link Speed by Device

| Device | FPGA variant | Supported link speeds | Notes |
|--------|--------------|----------------------|-------|
| X410 | — | 10 GbE only | QSFP → 4 × SFP+ breakout cable required; native QSFP (100 GbE) not supported |
| X310, N310, N320 | HG | 1 GbE and 10 GbE | Both speeds work with the HG variant the MATLAB installation includes |
| E320 | 1G (default) | 1 GbE default; 10 GbE with XG variant | Defaults to 1G; switch to XG through `sdruload` for 10 GbE over SFP+ |

#### MTU and Jumbo Frames

| Link speed | MTU | Jumbo frames | Notes |
|------------|-----|--------------|-------|
| 10 GbE | 9000 | Enabled (9014 bytes) | Required for full-rate streaming |
| 1 GbE (Linux) | 1500 | Disabled | Default is correct; jumbo frames not supported |
| 1 GbE (Windows) | 1498 | Disabled | UHD 4.6 on Windows adds 2 bytes; MTU must be 1498. Expect a benign "send frame size" warning from UHD — safe to ignore |

#### X410 Note

The X410 has a QSFP28 connector but Wireless Testbench does not support native 100 GbE QSFP. You must use a QSFP → 4 × 10 GbE SFP+ breakout cable — each lane appears as a separate 10 GbE SFP+ port (Port 0–3).

#### E320 Note

The MATLAB installation includes the `1G` FPGA variant by default. A standard 1 GbE NIC (PCIe or onboard) is correct for default operation. The E320 also has an SFP+ port — switch to the XG variant through `sdruload` for 10 GbE streaming (requires a 10 GbE NIC and SFP+ module).

#### Check MTU and Kernel Buffer Sizes (Linux)

```matlab
[~, mtu] = system('cat /sys/class/net/<iface>/mtu');
fprintf("MTU: %s", mtu)

[~, rmem] = system('sysctl net.core.rmem_max');
[~, wmem] = system('sysctl net.core.wmem_max');
fprintf("%s%s", rmem, wmem)
```

**USB dongle warning:** USB-to-Ethernet adapters are unreliable for USRP streaming, even USB 3.0 models. They cause dropped samples, timeouts, and intermittent failures. If a USB dongle is detected, warn the user strongly and recommend a dedicated PCIe NIC. If the user must use a dongle (for example, laptop), suggest:
- Connect laptop to power supply (USB power management throttles adapters)
- Try alternative adapter models
- Reduce sample rate to lower bandwidth demands

**Detect bridge and virtual interfaces:** If the host runs Hyper-V, Docker, libvirt, or NIC teaming, the USRP-facing NIC may be enslaved to a bridge. See [references/bridge-detection.md](references/bridge-detection.md) for detection commands (Linux and Windows). If a bridge is found, set static IP and MTU on the bridge interface, not the physical NIC.

### Step 2: Discover and Inspect Radio

Before running discovery, confirm with the user that the radio is powered on, cabled, and the Ethernet link LED is lit. E320 and N3xx devices take 30–60 seconds to boot after power-on — `findsdru` returns empty until the device finishes booting. If `findsdru` returns empty and the user needs cabling help, point them to the archived doc for their release: `https://www.mathworks.com/help/releases/<release>/wireless-testbench/ug/resolve-issues-with-connecting-radio-to-host.html` (derive `<release>` from `version('-release')`).

Use `findsdru` to discover devices — this is the only recommended MATLAB function for radio discovery. Do not use `uhd_find_devices`.

```matlab
radios = findsdru
```

Returns a structure array with fields: `Platform`, `IPAddress`, `SerialNum`, `Status`. A `Status` of `'Success'` means the device is reachable.

#### Multiple Devices Found

If `numel(radios) > 1`, list all discovered devices and ask the user which one to set up.

```matlab
if numel(radios) > 1
    fprintf("Found %d devices:\n", numel(radios));
    for i = 1:numel(radios)
        fprintf("  [%d] %s at %s (Serial: %s) — %s\n", ...
            i, radios(i).Platform, radios(i).IPAddress, radios(i).SerialNum, radios(i).Status);
    end
end
```

Ask the user which device to configure. This skill sets up one radio at a time. For multi-device synchronization (shared clock, coordinated capture), a separate workflow is needed after each device is individually configured.

**Target device not in results:** If the user identifies a specific device (for example, "my E320") but that device does not appear in `findsdru` output, do not select a different device from the list. The target device is unreachable — skip directly to troubleshooting (Step 6) focused on why that specific device is not discovered. Common causes: wrong subnet on the NIC facing that device, dongle or NIC not configured, device still booting, or cabling issue. Never assume a discovered device "is" the user's target under a different name — each USRP model reports its actual platform string.

If no radio is found at all, the NIC is likely misconfigured (wrong subnet, interface down, or firewall). Go back to Step 1 and check specifically: is the interface up? Is there a static IP on the same subnet as the USRP (for example, 192.168.10.x)? Then retry `findsdru`. If it still fails, go to Step 6 (Troubleshooting).

**Inspect the selected radio in detail:**

```matlab
% Use the IP address of the device the user selected
selectedRadio = radios(idx);  % idx = user's choice (e.g., 1)
info = probesdru(selectedRadio.IPAddress)
```

This returns motherboard, daughterboard, firmware, FPGA image, and the device-side UHD version.

**Check UHD version match:**

```matlab
hostUHD = getSDRuDriverVersion
```

Compare the host UHD version with the device UHD version from the `probesdru` output. **Version mismatch is a common failure.** Each MATLAB release includes a specific UHD version. If mismatched, the radio configuration step (Step 4) attempts to update device firmware.

Default USRP IP addresses (factory defaults, all models):

| Port | Default IP |
|------|-----------|
| SFP+ Port 0 | 192.168.10.2 |
| SFP+ Port 1 | 192.168.20.2 |

### Step 3: Fix Host Issues

Based on Step 1 findings, fix any issues before proceeding to radio configuration.

**Do not execute these commands directly** — they require `sudo` (root privileges). Present them to the user and ask them to run the commands themselves. If the radio is already reachable through `findsdru` and no streaming issues are expected yet, skip to Step 4 and address host fixes later if dropped samples occur.

**Linux — set static IP, MTU, and buffers:**

```bash
# Set static IP on the same subnet as the USRP (replace <iface>)
sudo ip addr add 192.168.10.1/24 dev <iface>
sudo ip link set <iface> up

# Enable jumbo frames (REQUIRED for 10 GbE only — skip for 1 GbE)
sudo ip link set <iface> mtu 9000

# Increase kernel network buffers (REQUIRED for streaming)
sudo sysctl -w net.core.rmem_max=33554432
sudo sysctl -w net.core.wmem_max=33554432
```

For 1 GbE connections (for example, E320), leave MTU at the default 1500 — do not enable jumbo frames.

To make persistent, add to `/etc/sysctl.conf` and configure the interface in `/etc/network/interfaces` or NetworkManager.

**Windows — adjust adapter settings (10 GbE):**
- Open Device Manager → Network Adapters → your NIC → Advanced
- Set Jumbo Frame/Packet to 9014 bytes
- Increase Receive Buffers and Transmit Buffers to maximum (adapter-dependent — check valid range first)
- Disable interrupt moderation if available

**Windows — adjust adapter settings (1 GbE, for example E320):**
- Set MTU to **1498** (required for UHD 4.6 on Windows — do not use 9000)
- Leave Jumbo Frame/Packet **disabled** (1514 bytes)
- Increase Receive Buffers to maximum (varies by adapter: Intel may support 2048+, Realtek often caps at 512)
- Disable power saving: `Disable-NetAdapterPowerManagement -Name "<adapter>"`
- Disable all protocols except TCP/IPv4 on the radio NIC
- Disable Windows Firewall on the radio NIC interface

All Windows NIC configuration commands (`New-NetIPAddress`, `netsh`, `Set-NetAdapterAdvancedProperty`) require an elevated (Administrator) terminal. MATLAB `system()` calls cannot elevate — the user must run these from an admin prompt.

After fixing, rerun Step 2 (`findsdru`) to confirm the radio is now reachable. If the radio is still not found or shows `USRPDriverNotCompatible`, go to Step 6 (Troubleshooting).

### Step 4: Create Radio Configuration

A saved radio configuration is required before using `basebandTransceiver` or `basebandReceiver`.

**First, check for existing configurations** that might already match the radio:

```matlab
configs = radioConfigurations;
if ~isempty(configs)
    for i = 1:numel(configs)
        fprintf("  '%s' — %s at %s\n", configs(i).Name, configs(i).Hardware, configs(i).IPAddress);
    end
end
```

If any existing configuration matches the device (same IP, same model), **ask the user** if they want to reuse it before creating a new one. Do not silently reuse or overwrite — the user may have specific settings in their existing configuration.

**Determine the correct SFP+ port index:** Devices with multiple SFP+ ports (X310, X410) expose multiple IP addresses in `probesdru` output (for example, `ip-addr0`, `ip-addr1`, `ip-addr2`, `ip-addr3`). Compare the IP found by `findsdru` against the `probesdru` port list to determine which port index (0, 1, 2, 3) the radio was discovered on. Use that index for the `HostIPx`/`DeviceIPx` pair below — using the wrong port index causes misleading errors.

**Option A: Programmatic (preferred when agent is driving)**

Use the internal `DeviceStore` API to create a configuration without the GUI. **You MUST use the `getUsrp<Model>Params()` function matching the user's selected device** — do not copy example names blindly. **Read the `probesdru` output carefully before setting any fields** — do not assume values. Default params assume UBX-160 daughterboards; if `probesdru` reports a different board (e.g., OBX, TwinRX) or "Unknown", ask the user what is installed. For unsupported/unknown boards, configure as if UBX-160 — streaming still works but is untested. For TwinRX, skip transmit verification (RX-only board).

```matlab
% Get default parameters — MUST match the selected radio's model:
%   E320 → getUsrpE320Params()    N310 → getUsrpN310Params()
%   X310 → getUsrpX310Params()    X410 → getUsrpX410Params()
%   N320 → getUsrpN320Params()    N300 → getUsrpN300Params()
params = wt.internal.hardware.DefaultDevices.getUsrpE320Params();  % ← match user's device
params.Name = "MyE320";  % ← user-chosen config name
% Use actual IPs from findsdru (Step 2) and host NIC inspection (Step 1)
% IMPORTANT: Use the correct port index (0 or 1) matching the SFP+ port
% where the radio was discovered. For single-port setups, port 0 is typical.
params.Network.DeviceIP0 = selectedRadio.IPAddress;
params.Network.HostIP0 = "<host-ip-from-step-1>";

% Save the configuration
store = wt.internal.hardware.DeviceStore();
store.setDeviceParameters("MyE320", params);  % ← same as params.Name

% Verify it was saved
configs = radioConfigurations;
disp(configs)
```

**CRITICAL:** If multiple radios were discovered, configure only the one the user selected. Do not use IPs, model names, or parameters from other discovered devices.

**Recovery from bad store writes:** The `wt.radio.*` classes cache state. If you write a bad configuration (for example, wrong daughterboard string), the corrupted values persist in memory. To recover:

```matlab
clear all
rehash toolboxcache
```

Then recreate the configuration from scratch.

**Option B: GUI wizard (when user is driving interactively)**

```matlab
radioSetupWizard
```

The wizard walks through device selection, IP configuration, connectivity test, firmware or FPGA update if needed, clock, time, and LO source configuration, and saves a named configuration. Use this when the user prefers a guided interactive experience or when firmware needs updating (the wizard handles firmware flashing). **Note:** After support package installation, a dialog box prompts the user to open the Radio Setup Wizard — tell the user to close it (the skill handles setup).

After either option, verify the configuration exists:

```matlab
radio = radioConfigurations("MyN310");
disp(radio)
```

This returns a `wt.radio.<Model>` object (R2025a+) with properties and synchronization methods.

### Step 5: Verify Connection

Create a `basebandTransceiver` to confirm the full pipeline works. The `basebandTransceiver` loads its own FPGA bitstream onto the device — do not use `sdruload` for streaming (that is the legacy `comm.SDRuReceiver` path). However, `sdruload` is still valid for **FPGA image management** on E320 (for example, switching between `1G` and `XG` variants — see [Set Up USRP E320 for 10GbE](https://www.mathworks.com/help/wireless-testbench/ug/set-up-usrp-e320-radio-for-10-gigabit-ethernet.html)).

```matlab
radio = radioConfigurations("MyN310");

bbtrx = basebandTransceiver(radio);
bbtrx.SampleRate = 5e6;  % Use a rate safe for 1 GbE; increase for 10 GbE
bbtrx.TransmitCenterFrequency = 2.4e9;
bbtrx.CaptureCenterFrequency = 2.4e9;
bbtrx.TransmitRadioGain = 10;
bbtrx.CaptureRadioGain = 30;
% Do not set TransmitAntennas/CaptureAntennas — defaults are device-specific

% Generate a test tone
numSamples = 10000;
t = (0:numSamples-1)' / bbtrx.SampleRate;
txWaveform = 0.8 * exp(1j*2*pi*1e6*t);

% Transmit and capture
transmit(bbtrx, txWaveform, "continuous");
[rxData, ~, droppedSamples] = capture(bbtrx, milliseconds(1));
stopTransmission(bbtrx);

if droppedSamples == 0
    disp("Verification passed: TX/RX working, no dropped samples.")
else
    warning("Dropped %d samples — check NIC MTU and buffer settings.", droppedSamples)
end

% Release the radio so it's available for the user's application code
clear bbtrx
```

If `basebandTransceiver` errors out or streaming consistently drops samples, go to Step 6 (Troubleshooting).

**`UseRadioBuffer` option:** By default, `capture` uses the radio's onboard memory buffer (`UseRadioBuffer=true`). This gives the most reliable streaming for captures that fit in onboard memory.

```matlab
[rxData, ~, droppedSamples] = capture(bbtrx, seconds(5), UseRadioBuffer=false);
```

Set `UseRadioBuffer=false` when:
- Capture length exceeds radio onboard memory (varies by device, up to 2^30 samples) — this is the primary reason
- Using X310 with TwinRX capturing on more than 2 antennas

For dropped samples, `UseRadioBuffer=false` can help diagnose the source: compare drop counts with and without the buffer to isolate whether the issue is buffer-related or NIC-related. But it is not a fix — direct streaming is more demanding on the network, so fix the underlying NIC/MTU/buffer issues in Step 3.

### Step 6: Troubleshooting

If any step fails, consult [references/troubleshooting.md](references/troubleshooting.md) — it covers the full diagnostic checklist, manual Mender firmware updates, network path diagnostics, and bridge interference.

## Key Functions

| Function | Purpose | Path |
|----------|---------|------|
| `findsdru` | Discover USRP devices on the network | Modern |
| `probesdru` | Get detailed hardware/firmware info | Modern |
| `getSDRuDriverVersion` | Host-side UHD version | Modern |
| `radioSetupWizard` | GUI to configure and save radio setup | Modern |
| `radioConfigurations` | List/load saved radio configs | Modern |
| `wt.radio.*` | Typed radio objects (R2025a+): N310, X410, etc. | Modern |
| `basebandTransceiver` | Combined TX/RX, loads own FPGA bitstream | Modern |
| `basebandTransmitter` | TX only | Modern |
| `basebandReceiver` | RX only | Modern |
| `wt.internal.hardware.DeviceStore` | Programmatic radio config creation | Internal |
| `wt.internal.hardware.DefaultDevices` | Default parameters per device model (`getUsrp<Model>Params()` static methods) | Internal |
| `sdruload` | Load/switch FPGA image variant | Legacy for streaming; valid for E320 image management (1G ↔ XG) |

## Conventions

- **Inspect host first.** Always check OS, NIC type/speed, MTU, and buffers before touching the radio.
- **Stay in MATLAB.** Use `findsdru` or `probesdru` for discovery — never call `uhd_find_devices` or other UHD CLI tools.
- **Modern path for streaming.** Use `basebandTransceiver`, `basebandReceiver`, or `basebandTransmitter`. These load their own FPGA bitstream. Do not use `sdruload` for streaming — that is the legacy `comm.SDRu*` path. `sdruload` remains valid for FPGA image management (for example, E320 variant switching).
- **Programmatic config when agent-driven.** Use `DeviceStore` to create configs without the GUI. Fall back to `radioSetupWizard` when the user prefers interactive setup or firmware needs updating.
- **Check versions early.** Compare `getSDRuDriverVersion` (host) with `probesdru` output (device) before proceeding.
- **Diagnose before configuring.** Complete all host and radio checks before creating a radio configuration or launching the wizard.
- **Use release-specific doc URLs.** When linking to MathWorks docs, use `https://www.mathworks.com/help/releases/<release>/wireless-testbench/...` (derive `<release>` from `version('-release')`). This ensures docs match the user's installed version.

----

Copyright 2026 The MathWorks, Inc.

----
