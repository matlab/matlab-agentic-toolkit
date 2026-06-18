---
name: matlab-play-record-audio
description: Reference for MATLAB audiostreamer (Audio Toolbox R2025a+). Without this skill, agents consistently default to legacy audioDeviceWriter/audioDeviceReader or base MATLAB sound(), producing less capable code. Use when writing code for audio playback, recording, full-duplex device I/O, real-time audio measurements, or audio I/O processing with callbacks. Also use when debugging audiostreamer errors, dropouts, or latency issues, or migrating from audioDeviceReader, audioDeviceWriter, audioPlayerRecorder, or audioplayer/audiorecorder.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# audiostreamer — MATLAB Audio Device I/O (R2025a+)

`audiostreamer` is the unified replacement for `audioDeviceWriter`, `audioDeviceReader`, and `audioPlayerRecorder`. It provides player-only, recorder-only, or full-duplex modes with callbacks, pre-buffering, transport control, and measurement helpers.

**Version requirements:** `audiostreamer` requires Audio Toolbox R2025a or later. The `start` and `write` methods were added in R2026a.

## When to Use

- Playing audio through a sound card or USB audio device
- Recording audio from a microphone or audio interface
- Full-duplex playback + recording (e.g., acoustic measurements, loopback tests)
- Listing or selecting audio devices and drivers
- Any workflow that involves audio hardware I/O in MATLAB

## When NOT to Use

- **Playing a single isolated sound** — `sound` or `soundsc` is fine for one-shot playback of a short clip with no sequencing. For sequential playback (e.g., before/after comparison), use `audiostreamer` — its `play()` calls queue automatically, whereas overlapping `sound` calls play simultaneously.
- **Code generation (codegen)** — `audiostreamer` does not yet support codegen; use legacy APIs if targeting codegen
- **Simulink models** — Simulink still uses the existing audio I/O blocks, not `audiostreamer`
- **Audio Toolbox not available** — fall back to `sound`/`soundsc`, `audioplayer`/`audiorecorder`, or `audioDeviceWriter` (DSP System Toolbox) if the user lacks Audio Toolbox
- **File I/O only** — reading/writing audio files without device playback or recording uses `audioread`/`audiowrite`, not this skill
- **DAQ hardware** — National Instruments or similar data acquisition devices use DAQ Toolbox and the `daq` object
- **MIDI-only devices** — MIDI control uses `mididevice`/`midicontrols`, not `audiostreamer`

## Construction

Use Name-Value pairs for `Mode` and `SampleRate` (positional shorthand exists but does not support tab-completion):

**The default Mode is `"player"`. You MUST set Mode explicitly if recording** — either `Mode="recorder"` or `Mode="full-duplex"`. Mode is not inferred from other properties like `Recorder` or `RecorderChannels`.

```matlab
as = audiostreamer                                          % default: player mode, 44100 Hz
as = audiostreamer(Mode="player", SampleRate=fs)            % player at fs Hz
as = audiostreamer(Mode="recorder", SampleRate=fs)          % recorder at fs Hz
as = audiostreamer(Mode="full-duplex", SampleRate=fs)       % simultaneous play + record
as = audiostreamer(Mode="full-duplex", SampleRate=48000, Driver="ASIO", ...
    Player="Focusrite USB ASIO", Recorder="Focusrite USB ASIO", ...
    PlayerChannels=[1 2], RecorderChannels=[1 2])
```

## Properties

### Device Configuration (set BEFORE streaming starts)

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `Mode` | `"player"` / `"recorder"` / `"full-duplex"` | `"player"` | Set at construction or via property |
| `Driver` | `"DirectSound"` / `"ASIO"` / `"WASAPI"` (Win); `"CoreAudio"` (Mac); `"ALSA"` (Linux) | OS default | Only set on Windows (Mac/Linux have one driver each). Setting at construction selects the default device for that driver. |
| `Player` | string | System default for driver | Output device name. Omit to use the default device for the selected driver. |
| `Recorder` | string | System default for driver | Input device name. Omit to use the default device for the selected driver. |
| `SampleRate` | positive scalar | 44100 | Hz |
| `DeviceBufferSize` | positive int or `"auto"` | `"auto"` | Fixed for ASIO (use `asiosettings`). |
| `DeviceBitFormat` | `"single"` / `"int24"` / `"int16"` | `"int24"` | int16 on ASIO silently uses int24 |
| `PlayerChannels` | row vector or `"auto"` | `"auto"` | 1-based mapping. "auto" upmixes mono→stereo; for N≥2 channels, opens N channels on the device |
| `RecorderChannels` | row vector | `1` | 1-based mapping. **Records 1 channel by default** — set e.g. `1:2` for stereo |
| `ExclusiveMode` | on/off | `"on"` | WASAPI only — disables OS mixing/resampling |
| `ConstantLatency` | `"off"` / `"dropPlayer"` / `"dropRecorder"` | `"off"` | Full-duplex dropout handling |

**IMPORTANT:** `Mode`, `SampleRate`, `Driver`, `DeviceBufferSize`, `DeviceBitFormat`, `ExclusiveMode`, `ConstantLatency`, `PlayerChannels`, and `RecorderChannels` lock once streaming starts. Call `release(as)` before changing any of these properties to avoid an automatic release with a warning.

### Callback Properties

| Property | Signature | Trigger |
|----------|-----------|---------|
| `PlayerFcn` | `@(obj, event)` | Player buffer drops below `PlayerMinSamples` |
| `PlayerMinSamples` | positive int (default 16384) | Threshold for `PlayerFcn` trigger |
| `RecorderFcn` | `@(obj, event)` | Recorder buffer exceeds `RecorderMinSamples` |
| `RecorderMinSamples` | positive int (default 1024) | Threshold for `RecorderFcn` trigger |
| `PlayerCompletedFcn` | `@(obj, event)` | Output queue empties |
| `RecorderCompletedFcn` | `@(obj, event)` | Fixed-length recording finishes |
| `PlayerUnderrunFcn` | `@(obj, event)` | Player underrun occurs |

**ALL callbacks MUST accept exactly 2 arguments.** First arg = the audiostreamer object. Second arg = event struct with `.Type` field. Use `@(obj, ~)` if you don't need the event.

Event struct fields by type:
- `PlayerFcn`: `event.Type = "Player"`, `event.NumPlayerSamples`
- `RecorderFcn`: `event.Type = "Recorder"`, `event.NumRecorderSamples`
- `PlayerCompletedFcn`: `event.Type = "PlayerCompleted"`, `event.StreamTime`
- `RecorderCompletedFcn`: `event.Type = "RecorderCompleted"`, `event.StreamTime`
- `PlayerUnderrunFcn`: `event.Type = "PlayerUnderrun"`, `event.SamplesUnderrun`

### Read-Only Status

| Property | Description |
|----------|-------------|
| `NumPlayerSamples` | Samples currently queued in output buffer |
| `NumRecorderSamples` | Samples available to `read()` without blocking |
| `MaxPlayerChannels` | Max output channels on selected device |
| `MaxRecorderChannels` | Max input channels on selected device |

## Methods

### Playback

| Method | Description |
|--------|-------------|
| `play(obj, x)` | Queue `x` and play. **Blocks** until output buffer <= `PlayerMinSamples` (up to `PlayerMinSamples` samples remain unplayed when it returns). Call `waitfor(as)` after the last `play` to ensure complete playback before `release`. |
| `play(obj, x, "non-blocking")` | Queue `x` and return immediately regardless of buffer level. |
| `play(obj)` | Start PlayerFcn callback loop (no data argument). |
| `write(obj, x)` | [R2026a+] Queue `x` to output buffer WITHOUT starting playback. Use with `start()`. |
| `write(obj, x, "non-blocking")` | [R2026a+] Queue `x` and return immediately regardless of buffer level. |

### Recording

| Method | Description |
|--------|-------------|
| `record(obj)` | Start recording indefinitely. Warns if unread samples remain in the buffer. To avoid: `stop(as)` (or `stop(as, "recorder")` in full-duplex), then `read(as)` to flush. Not needed if samples were already consumed by a callback or `read`. |
| `record(obj, numSamples)` | Record exactly `numSamples` then stop. Same unread-samples warning applies. |
| `read(obj)` | Return all available recorded samples immediately (non-blocking). Returns empty if none available. |
| `read(obj, numSamples)` | **Blocks** until `numSamples` available, then returns them. |

### Full-Duplex

| Method | Description |
|--------|-------------|
| `playrec(obj, x)` | Play `x` and record simultaneously. Non-blocking — recording continues in the background; retrieve data with `read`. |
| `playrec(obj, x, numSamples)` | Play `x` and record `numSamples`. Blocking — returns recorded matrix. |
| `playrec(obj)` | Start callback-driven full-duplex (requires RecorderFcn and/or PlayerFcn). |

`playrec` pauses both player and recorder, queues audio, then resumes both simultaneously for **repeatable latency**. This is critical for measurements with `impzest`.

### Transport Control

| Method | Description |
|--------|-------------|
| `start(obj)` | [R2026a+] Start streaming in current mode. |
| `start(obj, Mode="player")` | [R2026a+] Start only player (full-duplex). |
| `start(obj, Mode="recorder", SamplesToRecord=N)` | [R2026a+] Start recorder with fixed count. |
| `stop(obj)` | Stop all streaming. Preserves unread input samples. Resets underrun count (as does `getUnderrunCount`). |
| `stop(obj, "player"/"recorder"/"both")` | Stop specific side. |
| `pause(obj)` / `pause(obj, "player"/"recorder"/"both")` | Pause with state preservation. |
| `resume(obj)` / `resume(obj, "player"/"recorder"/"both")` | Resume from pause. |
| `waitfor(obj)` / `waitfor(obj, "player"/"recorder"/"both")` | Block until complete. |
| `release(obj)` | Stop, flush, close device, tear down. Deletes unread samples. |

### Query / Diagnostics

| Method | Description |
|--------|-------------|
| `isPlaying(obj)` | Returns OnOffSwitchState |
| `isRecording(obj)` | Returns OnOffSwitchState |
| `isPlayerPaused(obj)` | Returns OnOffSwitchState |
| `isRecorderPaused(obj)` | Returns OnOffSwitchState |
| `getUnderrunCount(obj)` | Underrun sample count since last call. Resets counter (as does `stop`). |
| `getStreamTime(obj)` | Elapsed stream time in seconds. |
| `getStreamTime(obj, "reset")` | Reset stream timer. |
| `measureLoopbackLatency(obj)` | Full-duplex only, single channel. Returns delay in samples. |

### Static Device Enumeration

```matlab
audiostreamer.getDrivers()              % Available drivers for this OS
audiostreamer.getPlayerNames()          % All output devices
audiostreamer.getPlayerNames("ASIO")    % Output devices for specific driver
audiostreamer.getRecorderNames()        % All input devices
audiostreamer.getRecorderNames("ASIO")  % Input devices for specific driver
audiostreamer.getAudioDevices()         % Struct array: Name, Driver, MaxRecorderChannels, MaxPlayerChannels, SampleRate (channel counts are int32)
```

**Note:** `getAudioDevices()` returns `int32` for `MaxRecorderChannels` and `MaxPlayerChannels`. Cast to `double()` before using these values in UI components (e.g., `uispinner` Limits) or arithmetic that expects double.

## CRITICAL: There is NO `setup()` Method

The `audiostreamer` does NOT have a public `setup()` method. Device initialization happens implicitly on the first `play()`, `record()`, `playrec()`, or `start()` call. Do NOT call `setup()` — it will error.

If `PlayerFcn` is set, the first streaming call invokes it repeatedly to pre-buffer at least 8192 samples (or `PlayerMinSamples`, whichever is greater) before the device opens.

## Common Patterns

### Pattern 1: Simple Blocking Measurement (Sweep + IR)

```matlab
as = audiostreamer(Mode="full-duplex", SampleRate=48000, ...
    PlayerChannels=1, RecorderChannels=1);
x = sweeptone(2, 1, 48000);
y = playrec(as, x, size(x, 1));  % blocking: returns recorded audio
underruns = getUnderrunCount(as);
ir = impzest(x, y);
release(as);
```

### Pattern 2: Non-Blocking Play + Record with waitfor

```matlab
as = audiostreamer(Mode="full-duplex", SampleRate=48000);
x = sweeptone(3, 2, 48000);
playrec(as, x);          % non-blocking (no output arg)
waitfor(as);             % block until done
y = read(as);            % retrieve recorded data
release(as);
```

### Pattern 3: Pre-Buffered Playback (write + start) — R2026a+

Use `write`+`start` when you need to control exactly when playback begins (e.g., synchronized full-duplex start). For simple playback, `play(as, signal)` achieves the same result — it queues and starts automatically.

```matlab
as = audiostreamer(Mode="player", SampleRate=48000);
write(as, signal);       % queue without starting
start(as);               % begin playback
waitfor(as);             % wait for completion
release(as);
```

### Pattern 4: Callback-Driven Streaming Player

```matlab
as = audiostreamer(Mode="player", SampleRate=48000, DeviceBufferSize=1024);
gen = dsp.ColoredNoise("pink", NumChannels=2, SamplesPerFrame=1024);
as.PlayerFcn = @(obj, ~) play(obj, gen());
as.PlayerMinSamples = 4096;
play(as);    % or start(as) [R2026a+] — begins callback loop
% ... later ...
stop(as);
release(as);
```

### Pattern 5: Callback-Driven Level Metering (Recorder)

```matlab
as = audiostreamer(Mode="recorder", SampleRate=48000);
as.RecorderFcn = @(obj, ~) updateMeter(read(obj));
as.RecorderMinSamples = 1024;
start(as);       % or record(as) before R2026a
% ... meter updates in background ...
stop(as);
release(as);
```

### Pattern 6: Frame-at-a-Time Processing Loop (Full-Duplex)

The most direct replacement for legacy `audioDeviceReader`/`audioDeviceWriter` loops. Call `start(as)` before the loop so that `read` has samples available.

```matlab
as = audiostreamer(Mode="full-duplex", SampleRate=48000, RecorderChannels=1:2);
start(as);
for iter = 1:numIterations
    in = read(as, frameLength);      % blocks until frameLength samples available
    out = process(myPlugin, in);
    write(as, out);                  % blocks until buffer has room
end
nUnderruns = getUnderrunCount(as);   % total underruns since last call (resets counter)
release(as);
```

Before R2026a, use `record(as)` + `play(as, out)` instead of `start`/`write`.

For player-only (e.g., file input → device output), use `play(as, out)` with no `start` needed — `play` queues and starts automatically.

### Pattern 7: Repeated Measurements with Callbacks (Full-Duplex)

```matlab
as = audiostreamer(Mode="full-duplex", SampleRate=48000, PlayerChannels=1, RecorderChannels=1);
x = sweeptone(2, 1, 48000);
as.RecorderMinSamples = size(x, 1);
as.RecorderFcn = @(obj, ~) processMeasurement(obj, x);
as.PlayerFcn = @(obj, ~) write(obj, x);  % or play(obj, x) before R2026a
as.PlayerMinSamples = size(x, 1);
as.ConstantLatency = "dropPlayer";  % keep in sync for impzest
playrec(as);   % starts callback-driven measurement loop
% ... runs continuously ...
stop(as);
release(as);
```

### Pattern 8: App with Timer-Based GUI Updates

```matlab
as = audiostreamer(Mode="player", SampleRate=fs, DeviceBufferSize=1024);
as.PlayerFcn = @(obj, ~) play(obj, getNextFrame());
as.PlayerMinSamples = 20 * 1024;
as.PlayerUnderrunFcn = @(~, ev) fprintf("Dropped %d samples\n", ev.SamplesUnderrun);

figTimer = timer(ExecutionMode="fixedRate", Period=0.05, ...
    TimerFcn=@(~,~) updatePlot(as));

play(as);           % starts callback loop
start(figTimer);    % starts GUI updates
% ...
stop(as);
release(as);
stop(figTimer);
delete(figTimer);
```

In the timer callback, check buffer health before expensive GUI operations:
```matlab
function updatePlot(as)
    if as.NumPlayerSamples < 0.5 * as.PlayerMinSamples
        return  % skip GUI update to prevent dropout
    end
    % ... update plots ...
    if as.NumPlayerSamples > 0.9 * as.PlayerMinSamples
        drawnow("limitrate");
    end
end
```

### Pattern 9: Full-Duplex with write/start for Control — R2026a+

```matlab
as = audiostreamer(Mode="full-duplex", SampleRate=48000);
write(as, excitation);                         % queue output
start(as, SamplesToRecord=size(excitation,1)); % start both
waitfor(as, "both");
y = read(as);
release(as);
```

## Teardown Best Practice

`release(as)` is sufficient — it implicitly stops streaming, flushes buffers, and closes the device. No need to call `stop` first. However, `release` discards any unplayed samples — call `waitfor(as)` first if playback must complete.

```matlab
waitfor(as);   % ensure all queued audio finishes playing
release(as);
```

In apps, wrap in try-catch and nil the reference:
```matlab
try
    release(as);
catch
end
as = [];
```

The destructor calls `release()` automatically, but explicit cleanup is preferred in apps to avoid device lock-up. Calling `release` from within `PlayerCompletedFcn` is safe and does not deadlock.

**Note:** `isvalid(as)` returns `true` even after release — it cannot be used to detect a released audiostreamer. To track released state, nil the object reference and check with `isempty`.

## ConstantLatency Modes (Full-Duplex)

| Value | Behavior | Use For |
|-------|----------|---------|
| `"off"` | After dropout, inserts silence frame (latency increases) | General use |
| `"dropPlayer"` | Late output frames dropped; latency stays constant | Measurements with `impzest` (sweep-based) |
| `"dropRecorder"` | Input frames dropped; latency constant | Adaptive filters (NOT compatible with `impzest`) |

## Error Conditions

| Error ID | Cause |
|----------|-------|
| `audio:device:methodRequiresModes` | Calling method invalid for current Mode (e.g., `record()` in player mode). Set Mode to `"full-duplex"` if you need both playback and recording methods. |
| `audio:device:invalidChannelMap` | Channel indices exceed device max. Check `MaxPlayerChannels` or `MaxRecorderChannels` and adjust mapping. |
| `audio:device:callbackNargin` | Callback doesn't accept exactly 2 arguments. Use `@(obj, ~)` or `@(obj, event)` signature. |
| `audio:device:playrecRecorderFcnConflict` | `playrec` called with output argument while `RecorderFcn` is set — callback consumes samples via `read()`, leaving nothing for the return value. Clear `RecorderFcn` before blocking `playrec`. |
| `audio:device:startModePlayerNotValid` | `start(Mode="player")` in recorder-only mode |
| `audio:device:startModeRecorderNotValid` | `start(Mode="recorder")` in player-only mode |
| `MATLAB:validators:mustBeFinite` | Audio data contains NaN or Inf |
| `MATLAB:validators:mustBeReal` | Audio data is complex |

## audiostreamer vs. Legacy Audio APIs

`audiostreamer` is strongly preferred for all audio device I/O when Audio Toolbox is available. Legacy alternatives may be useful as fallbacks when Audio Toolbox is not installed or in edge cases.

| Legacy API | Limitation | audiostreamer Equivalent |
|------------|-----------|-----------|
| `audiodevinfo` | Does not support ASIO; incomplete device list | `audiostreamer.getAudioDevices()`, `audiostreamer.getPlayerNames()`, etc. |
| `audioplayer` / `audiorecorder` | No ASIO/WASAPI exclusive; limited driver model; no callbacks | `audiostreamer` in player/recorder/full-duplex mode |
| `sound` / `soundsc` | Creates an `audioplayer` under the hood; concurrent calls overlap (do NOT queue) | `audiostreamer` with `play()` for sequential playback |
| `audioDeviceWriter` / `audioDeviceReader` | Separate objects; no callbacks; no pre-buffering; frame-at-a-time loops only | Single `audiostreamer` object with blocking/non-blocking modes |
| `audioPlayerRecorder` | Limited full-duplex; no transport control; no latency measurement | `playrec`, `measureLoopbackLatency`, start/stop/pause/resume |

**`audiodevreset`** is fine to call — it resets the audio subsystem and can help recover from device errors regardless of which API you use.

**When `sound`/`soundsc` is acceptable:** Only for a single isolated playback with no sequencing. If you need to play two clips back-to-back (e.g., before/after comparison), use `audiostreamer` — its `play()` calls queue automatically.

### Migration Pitfalls (audioDeviceReader/Writer → audiostreamer)

| Legacy | audiostreamer | Gotcha |
|--------|--------------|--------|
| `audioDeviceReader` with `NumChannels=2` | `RecorderChannels=1:2` | audiostreamer records **1 channel by default**. You must set `RecorderChannels` explicitly for stereo/multichannel. |
| `audioDeviceWriter` returns underrun count per frame | `getUnderrunCount(as)` after loop | `play()` has no return value. Call `getUnderrunCount` when you need the total — it resets the counter each call. |
| `audioDeviceReader` returns overrun count per frame | No equivalent needed | audiostreamer buffers all recorded samples internally — recorder cannot overrun. |
| `Device='Default'` | Omit `Player`/`Recorder` | No "Default" string — omitting the property selects the system default for the current driver. |
| `[data, nOverrun] = deviceReader()` | `record(as)` then `data = read(as, N)` | Must call `record(as)` (or `start(as)` [R2026a+]) before the loop — otherwise `read` blocks forever waiting for samples. |
| Two separate objects for reader+writer | Single `audiostreamer(Mode="full-duplex")` | One object handles both directions. Use two separate objects if devices require different drivers or conflict when opened together. |

## Diagnostics

For debugging streaming issues, enable the diagnostic trace:
```matlab
as = audiostreamer(Mode="full-duplex", SampleRate=44100);
as.TraceEnabled = true;   % logs internal timing and buffer state
```

----

Copyright 2026 The MathWorks, Inc.

----
