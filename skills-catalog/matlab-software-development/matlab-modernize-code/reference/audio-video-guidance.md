
# Audio/Video I/O Modernization

## Quick Reference: Function Mappings

| Deprecated Function | Recommended Replacement | Introduced | Status |
|---------------------|------------------------|------------|--------|
| wavread | audioread | R2012b | Removed |
| wavwrite | audiowrite | R2012b | Removed |
| wavfinfo | audioinfo | R2012b | Removed |
| wavplay | audioplayer | R2010a | Removed |
| wavrecord | audiorecorder | R2010a | Removed |
| aviread | VideoReader | R2010b | Removed |
| aviinfo | VideoReader | R2010b | Removed |
| avifile | VideoWriter | R2010b | Removed |
| mmreader | VideoReader | R2010b | Removed |
| mmfileinfo | VideoReader | R2010b | Removed |

## Audio File Reading

### wavread → audioread

**Status:** `wavread` removed. Use `audioread`.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: wavread no longer exists
[y, fs] = wavread('audio.wav');
[y, fs, nbits] = wavread('audio.wav');
y = wavread('audio.wav', [1000 5000]);  % Read samples 1000-5000
```

**Modern Pattern (Use This):**
```matlab
% Read entire file
[y, fs] = audioread('audio.wav');

% Read specific sample range
[y, fs] = audioread('audio.wav', [1000 5000]);

% Get native format (for bit depth)
[y, fs] = audioread('audio.wav', 'native');
info = audioinfo('audio.wav');  % Contains BitsPerSample
```

**Why Modern is Better:**
- Supports multiple formats: WAV, FLAC, MP3, MPEG-4 AAC, OGG, OPUS
- Cross-platform compatibility (no platform-specific quirks)
- Better large file handling
- Native format preservation option

**Migration Notes:**
- `audioread` returns audio normalized to [-1, 1] by default
- Use `'native'` option to get original integer format
- Use `audioinfo` separately to get bit depth and other metadata

---

### wavfinfo → audioinfo

**Status:** `wavfinfo` removed. Use `audioinfo`.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: wavfinfo no longer exists
[size, fs, nbits, opts] = wavfinfo('audio.wav');
```

**Modern Pattern (Use This):**
```matlab
% Get complete audio file information
info = audioinfo('audio.wav');

% Access specific properties
fs = info.SampleRate;
numSamples = info.TotalSamples;
duration = info.Duration;
numChannels = info.NumChannels;
bitsPerSample = info.BitsPerSample;
```

**Why Modern is Better:**
- Returns structured information (easier to work with)
- Supports all audio formats MATLAB can read
- More comprehensive metadata

---

## Audio File Writing

### wavwrite → audiowrite

**Status:** `wavwrite` removed. Use `audiowrite`.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: wavwrite no longer exists
wavwrite(y, fs, 'output.wav');
wavwrite(y, fs, 16, 'output.wav');  % 16-bit
```

**Modern Pattern (Use This):**
```matlab
% Write audio file (default format)
audiowrite('output.wav', y, fs);

% Specify bit depth
audiowrite('output.wav', y, fs, 'BitsPerSample', 16);

% Write to different formats
audiowrite('output.flac', y, fs);  % FLAC (lossless)
audiowrite('output.ogg', y, fs);   % Ogg Vorbis
audiowrite('output.m4a', y, fs);   % MPEG-4 AAC
```

**Why Modern is Better:**
- Multiple output format support
- Quality settings for compressed formats
- Better metadata support

---

## Audio Playback

### wavplay → audioplayer

**Status:** `wavplay` removed. Use `audioplayer` object.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: wavplay no longer exists
wavplay(y, fs);
wavplay(y, fs, 'sync');  % Synchronous playback
```

**Modern Pattern (Use This):**
```matlab
% Create audio player object
player = audioplayer(y, fs);

% Play asynchronously (non-blocking)
play(player);

% Play synchronously (blocking) - use playblocking
playblocking(player);

% Control playback
pause(player);
resume(player);
stop(player);

% Play specific range (sample indices)
play(player, [1000 5000]);

% Clean up
clear player;
```

**Why Modern is Better:**
- Non-blocking by default (better for GUIs)
- Playback control (pause, resume, stop)
- Supports callbacks during playback
- Can query playback position

**Callback Example:**
```matlab
player = audioplayer(y, fs);
player.StopFcn = @(~,~) disp('Playback complete');
play(player);
```

---

## Audio Recording

### wavrecord → audiorecorder

**Status:** `wavrecord` removed. Use `audiorecorder` object.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: wavrecord no longer exists
y = wavrecord(n, fs);           % Record n samples
y = wavrecord(n, fs, ch);       % Specify channels
y = wavrecord(n, fs, ch, nbits);
```

**Modern Pattern (Use This):**
```matlab
% Create recorder object
recorder = audiorecorder(fs, nBits, nChannels);

% Record for specific duration
recordblocking(recorder, duration);  % Blocking record

% Or record asynchronously
record(recorder);
pause(duration);  % Or wait for user input
stop(recorder);

% Get recorded data
y = getaudiodata(recorder);

% Get data in specific format
y = getaudiodata(recorder, 'double');
y = getaudiodata(recorder, 'int16');

% Clean up
clear recorder;
```

**Why Modern is Better:**
- Non-blocking recording option
- Can pause and resume recording
- Real-time audio data access
- Callback support for monitoring

**Real-Time Monitoring Example:**
```matlab
recorder = audiorecorder(44100, 16, 1);
recorder.TimerFcn = @(~,~) plotAudio(recorder);
recorder.TimerPeriod = 0.1;
record(recorder);
```

---

## Video File Reading

### aviread, aviinfo → VideoReader

**Status:** `aviread` and `aviinfo` removed. Use `VideoReader`.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: aviread and aviinfo no longer exist
info = aviinfo('video.avi');
mov = aviread('video.avi');
frame = aviread('video.avi', 10);  % Read frame 10
```

**Modern Pattern (Use This):**
```matlab
% Create VideoReader object
v = VideoReader('video.mp4');

% Get video properties
numFrames = v.NumFrames;
frameRate = v.FrameRate;
duration = v.Duration;
width = v.Width;
height = v.Height;

% Read all frames
while hasFrame(v)
    frame = readFrame(v);
    % Process frame
end

% Read specific frame (R2014b+)
frame = read(v, 10);  % Frame 10

% Read range of frames
frames = read(v, [10 20]);  % Frames 10-20

% Seek to time position
v.CurrentTime = 5.0;  % Jump to 5 seconds
frame = readFrame(v);
```

**Why Modern is Better:**
- Supports many formats: MP4, AVI, MOV, MKV, WMV, etc.
- Time-based and frame-based access
- Hardware-accelerated decoding
- Better memory management

**Reading Large Videos Efficiently:**
```matlab
v = VideoReader('video.mp4');
% Process frame-by-frame to avoid loading entire video
while hasFrame(v)
    frame = readFrame(v);
    processedFrame = myProcessing(frame);
end
```

---

## Video File Writing

### avifile → VideoWriter

**Status:** `avifile` removed. Use `VideoWriter`.

**Old Pattern (Will Not Work):**
```matlab
% REMOVED: avifile no longer exists
aviobj = avifile('output.avi');
aviobj.FPS = 30;
for i = 1:numFrames
    aviobj = addframe(aviobj, frame);
end
aviobj = close(aviobj);
```

**Modern Pattern (Use This):**
```matlab
% Create VideoWriter object
v = VideoWriter('output.mp4', 'MPEG-4');
v.FrameRate = 30;
v.Quality = 90;  % For compressed formats

% Open, write frames, close
open(v);
for i = 1:numFrames
    frame = getFrame(i);  % Your frame generation
    writeVideo(v, frame);
end
close(v);
```

**Output Format Options:**
```matlab
% Uncompressed AVI
v = VideoWriter('output.avi', 'Uncompressed AVI');

% Motion JPEG AVI
v = VideoWriter('output.avi', 'Motion JPEG AVI');

% MPEG-4 (requires license on some platforms)
v = VideoWriter('output.mp4', 'MPEG-4');

% Grayscale AVI
v = VideoWriter('output.avi', 'Grayscale AVI');

% Indexed AVI (with colormap)
v = VideoWriter('output.avi', 'Indexed AVI');
```

**Why Modern is Better:**
- Multiple format support
- Quality control for compressed video
- Frame rate and resolution control
- Better error handling

---

### mmreader, mmfileinfo → VideoReader

**Status:** `mmreader` and `mmfileinfo` removed. Use `VideoReader`.

These were earlier multimedia reader functions that have been fully replaced by `VideoReader`.

---

## Complete Audio Processing Example

**Modern Audio Processing Workflow:**

```matlab
% Read audio
[signal, fs] = audioread('input.wav');

% Get file info
info = audioinfo('input.wav');
fprintf('Duration: %.2f seconds, Channels: %d\n', info.Duration, info.NumChannels);

% Process (example: apply gain)
processed = signal * 0.8;

% Write output
audiowrite('output.wav', processed, fs, 'BitsPerSample', 24);

% Play result
player = audioplayer(processed, fs);
playblocking(player);
```

---

## Complete Video Processing Example

**Modern Video Processing Workflow:**

```matlab
% Read video
reader = VideoReader('input.mp4');

% Create output
writer = VideoWriter('output.mp4', 'MPEG-4');
writer.FrameRate = reader.FrameRate;
open(writer);

% Process frame-by-frame
while hasFrame(reader)
    frame = readFrame(reader);

    % Example: Convert to grayscale
    grayFrame = rgb2gray(frame);
    grayFrame = repmat(grayFrame, 1, 1, 3);  % Back to RGB for writing

    writeVideo(writer, grayFrame);
end

close(writer);
```

---

## Version Compatibility Notes

- **R2012b:** `audioread`/`audiowrite`/`audioinfo` introduced (replacing wav* functions)
- **R2010b:** `VideoReader`/`VideoWriter` introduced (replacing avi* functions)
- **R2010a:** `audioplayer`/`audiorecorder` became primary audio playback/recording

---

## Summary: Functions to Avoid

| Avoid | Use Instead | Notes |
|-------|-------------|-------|
| `wavread` | `audioread` | Removed - will error |
| `wavwrite` | `audiowrite` | Removed - will error |
| `wavfinfo` | `audioinfo` | Removed - will error |
| `wavplay` | `audioplayer` | Removed - will error |
| `wavrecord` | `audiorecorder` | Removed - will error |
| `aviread` | `VideoReader` | Removed - will error |
| `aviinfo` | `VideoReader` | Removed - will error |
| `avifile` | `VideoWriter` | Removed - will error |
| `mmreader` | `VideoReader` | Removed - will error |
| `mmfileinfo` | `VideoReader` | Removed - will error |


----

Copyright 2026 The MathWorks, Inc.

----

