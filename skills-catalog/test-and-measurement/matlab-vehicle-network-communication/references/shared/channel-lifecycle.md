# Start, Stop, and Cleanup

## start / stop

```matlab
start(ch);   % Begin bus participation
stop(ch);    % Leave bus
```

## Requirements

- For CAN FD channels, `configBusSpeed` **must** be called before `start`
- Channel also stops when you `clear` the variable from workspace

## Cleanup Pattern

```matlab
ch = canChannel("MathWorks", "Virtual 1", 1);
cleanup = onCleanup(@() stop(ch));
configBusSpeed(ch, 500000);
start(ch);

% ... work with channel ...
% If error occurs, onCleanup ensures stop(ch) is called
```

## Why Cleanup Matters

- Errors mid-script leave channels in running state
- Running channels hold InitializationAccess — blocking new channel creation
- `clear all` triggers destructors for all in-scope channel objects
- `clear ch` specifically stops and releases that one channel

## Releasing a Channel

```matlab
stop(ch);    % explicit stop
clear ch;    % releases from workspace, also stops if running
```

No need to call both — `clear` alone is sufficient. Use explicit `stop` when you want to keep the variable but take the channel offline.

---

Copyright 2026 The MathWorks, Inc.
