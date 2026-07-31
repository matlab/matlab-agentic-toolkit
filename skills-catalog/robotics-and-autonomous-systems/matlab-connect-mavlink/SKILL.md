---
name: matlab-connect-mavlink
description: >
  Establish MAVLink connections between MATLAB and PX4/ArduPilot autopilots.
  Use when connecting to a drone, flight controller, or autopilot via MAVLink
  protocol over UDP. Covers dialect setup, UDP transport, timer-based heartbeat,
  and client discovery. Use when: "connect to PX4", "MAVLink connection",
  "heartbeat", "ground control station", "GCS", "connect to ArduPilot",
  "drone communication", "mavlinkio", "SITL".
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MAVLink Connection Setup

Establish a MAVLink UDP connection from MATLAB to a PX4 or ArduPilot flight
controller, with MATLAB acting as a ground control station (GCS). This skill
encodes the correct protocol sequence and heartbeat pattern that agents
consistently get wrong.

## When to Use

- User wants to connect MATLAB to a PX4 or ArduPilot autopilot via UDP
- User is building a ground control station in MATLAB
- User needs to set up MAVLink communication with SITL or networked autopilot
- User asks about heartbeat exchange or client discovery
- User references `mavlinkio`, `mavlinkdialect`, or `sendudpmsg`

## When NOT to Use

- User wants to read/set parameters, upload missions, or download logs over an
  already-established connection — these work well without this skill
- User is working with Simulink MAVLink blocks (different workflow)
- User only wants to parse a `.ulg` log file offline — use `ulogreader` directly
- User asks about MAVLink message serialization/deserialization only

## Workflow

Follow this exact sequence. The order matters — skipping or reordering steps
causes silent failures.

### 1. Create the dialect

```matlab
dialect = mavlinkdialect("common.xml", 2);
```

Use `"common.xml"` for both PX4 and ArduPilot (covers all standard messages).
Use `"ardupilotmega.xml"` only if you need ArduPilot-specific extension messages.
The `2` specifies MAVLink protocol version 2.

Available dialects: `common.xml`, `ardupilotmega.xml`, `standard.xml`, `minimal.xml`

### 2. Create the MAVLink IO interface

```matlab
mavlink = mavlinkio(dialect, 'SystemID', 255, 'ComponentID', 1);
```

- SystemID 255, ComponentID 1 is the standard GCS identity
- Do NOT create `mavlinksub(mavlink, "HEARTBEAT")` for connection verification.
  `mavlinkio` has a built-in heartbeat subscriber that feeds `listClients()`.
  Creating a manual HEARTBEAT subscriber is redundant and wasteful.

### 3. Connect UDP transport

```matlab
connect(mavlink, "UDP", LocalPort=14550);
```

All transport options are **name-value pairs**. Never use positional arguments.

Name-value options: `LocalPort` (default 0), `ConnectionName` (default "Connection#")

### 4. Build the GCS heartbeat message

**`createmsg` signature: `createmsg(dialect, msgName)`** — the dialect object is
always the first argument, message name string is second. Do NOT pass the
`mavlinkio` object to `createmsg`.

```matlab
hbMsg = createmsg(dialect, "HEARTBEAT");
hbMsg.Payload.type(:) = dialect.enum2num("MAV_TYPE", "MAV_TYPE_GCS");
hbMsg.Payload.autopilot(:) = dialect.enum2num("MAV_AUTOPILOT", "MAV_AUTOPILOT_INVALID");
hbMsg.Payload.base_mode(:) = 0;
hbMsg.Payload.custom_mode(:) = 0;
hbMsg.Payload.system_status(:) = 0;  % GCS has no vehicle state
```

**CRITICAL: Always access fields via `msg.Payload.fieldname(:)`** — never
`msg.fieldname(:)`. The message struct has a `.Payload` sub-struct that contains
all protocol fields. Writing `hbMsg.type(:) = ...` fails because `type` is not a
top-level field — it lives at `hbMsg.Payload.type`.

**CRITICAL: Always use `(:)` indexing on payload field assignments.** Writing
`msg.Payload.type = 6` (without `(:)`) silently replaces the wire type (uint8)
with double, producing corrupted MAVLink packets. The `(:)` preserves the
original data type.

### 5. Start periodic heartbeat

There are two workflows depending on whether the autopilot is already broadcasting:

**Workflow A: Auto-discovery (autopilot already broadcasting heartbeats)**

If PX4 SITL configured to broadcast mavlink messages, the autopilot's
heartbeats arrive automatically. Poll `listClients` first, then send heartbeats
back to the discovered client:

```matlab
% Wait for autopilot to appear
timeout = 10;
tic;
discovered = false;
while toc < timeout
    clients = listClients(mavlink);
    if height(clients) > 1
        discovered = true;
        break;
    end
    pause(0.5);
end

if discovered
    % Use SystemID/ComponentID from listClients output
    remoteClient = clients(clients.SystemID ~= 255, :);  % exclude local GCS
    autopilot = mavlinkclient(mavlink, remoteClient.SystemID, remoteClient.ComponentID);
    hbTimer = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
        'TimerFcn', @(~,~) sendmsg(mavlink, hbMsg, autopilot));
    start(hbTimer);
end
```

**Workflow B: Manual initiation (autopilot not yet broadcasting)**

If the autopilot requires GCS heartbeats before it will respond, use `sendudpmsg`
with the autopilot's listening port. For PX4 SITL, find this in the build log:
`[mavlink] ... on udp port <SITL_PORT> remote port 14550`. Ask the user for
this port if not known.

```matlab
sitlHost = "172.x.x.x";  % IP of SITL instance (use "ip a" in WSL to find it)
sitlPort = 18570;         % PX4 SITL listening port (from SITL build log "udp port" line)
hbTimer = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
    'TimerFcn', @(~,~) sendudpmsg(mavlink, hbMsg, sitlHost, sitlPort));
start(hbTimer);
```

- `sendudpmsg(io, msg, host, port)` sends to a specific UDP endpoint — use when
  the client is not yet discovered
- `sendmsg(io, msg, client)` sends to a discovered client — use after `listClients`
  shows the autopilot
- MAVLink standard heartbeat rate is 1 Hz
- **Do NOT use port 14550 as the remote port** — that is the GCS local port.
  The autopilot's listening port is different (e.g., PX4 SITL `-u` port).

### 6. Verify client discovery (Workflow B only)

After starting heartbeat via `sendudpmsg`, poll until the autopilot responds:

```matlab
timeout = 10;
tic;
discovered = false;
while toc < timeout
    clients = listClients(mavlink);
    if height(clients) > 1  % local GCS client is always listed
        discovered = true;
        break;
    end
    pause(0.5);
end

if discovered
    disp(clients);
else
    error("Autopilot not discovered within %d seconds.", timeout);
end
```

`listClients(mavlink)` uses the built-in heartbeat subscriber — no manual
`mavlinksub` needed. For Workflow A, discovery is already done in Step 5.

### 7. Clean up when done

```matlab
stop(hbTimer);
delete(hbTimer);
disconnect(mavlink);
```

Always stop and delete the timer before disconnecting to prevent orphaned timers.

## Key Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `mavlinkdialect` | `(xmlFile, version)` | Parse dialect XML, create message definitions |
| `mavlinkio` | `(dialect, 'SystemID', N, 'ComponentID', N)` | Create I/O interface |
| `connect` | `(io, "UDP", LocalPort=N)` | Open UDP transport |
| `mavlinkclient` | `(io, systemID, componentID)` | Create client handle for a remote system |
| `createmsg` | `(dialect, msgType)` | Create message struct — **dialect first, not io** |
| `sendudpmsg` | `(io, msg, remoteHost, remotePort)` | Send message to specific UDP endpoint |
| `sendmsg` | `(io, msg)` or `(io, msg, client)` | Send to all or to a discovered client |
| `listClients` | `(io)` | List all discovered clients (uses built-in subscriber) |
| `listTopics` | `(io)` | List all received message topics |
| `listConnections` | `(io)` | List active transport connections |
| `mavlinksub` | `(io, topic)` or `(io, client, topic)` | Subscribe to messages |
| `latestmsgs` | `(subscriber, count)` | Read most recent messages from subscriber |
| `disconnect` | `(io)` | Close all connections |

## Patterns

### UDP Connection to PX4 SITL (Auto-Discovery)

PX4 SITL configured to broadcast to GCS port 14550 (check build log for
`remote port 14550`). The autopilot appears in `listClients` automatically.

```matlab
% Setup
dialect = mavlinkdialect("common.xml", 2);
mavlink = mavlinkio(dialect, 'SystemID', 255, 'ComponentID', 1);
connect(mavlink, "UDP", LocalPort=14550);

% Build GCS heartbeat
hbMsg = createmsg(dialect, "HEARTBEAT");
hbMsg.Payload.type(:) = dialect.enum2num("MAV_TYPE", "MAV_TYPE_GCS");
hbMsg.Payload.autopilot(:) = dialect.enum2num("MAV_AUTOPILOT", "MAV_AUTOPILOT_INVALID");
hbMsg.Payload.base_mode(:) = 0;
hbMsg.Payload.custom_mode(:) = 0;
hbMsg.Payload.system_status(:) = 0;

% Wait for autopilot to be discovered
timeout = 10;
tic;
while toc < timeout
    clients = listClients(mavlink);
    if height(clients) > 1
        break;
    end
    pause(0.5);
end
disp(clients);

% Start GCS heartbeat back to the discovered autopilot
remoteClient = clients(clients.SystemID ~= 255, :);
autopilot = mavlinkclient(mavlink, remoteClient.SystemID, remoteClient.ComponentID);
hbTimer = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
    'TimerFcn', @(~,~) sendmsg(mavlink, hbMsg, autopilot));
start(hbTimer);

% ... perform operations ...

% Clean up
stop(hbTimer);
delete(hbTimer);
disconnect(mavlink);
```

### Subscribing to Specific Messages

When you need to monitor a specific message type (beyond connection verification):

```matlab
% Subscribe to all messages of a type
sub = mavlinksub(mavlink, "GLOBAL_POSITION_INT");

% Subscribe to messages from a specific discovered client
remoteClient = clients(clients.SystemID ~= 255, :);
autopilot = mavlinkclient(mavlink, remoteClient.SystemID, remoteClient.ComponentID);
sub = mavlinksub(mavlink, autopilot, "ATTITUDE");

% Read the latest message(s)
msgs = latestmsgs(sub, 1);
if ~isempty(msgs)
    disp(msgs.Payload);
end
```

### Sending Commands After Discovery

Once a client is discovered via `listClients`, you can use `sendmsg` with the client:

```matlab
% After discovery, send to specific client
clients = listClients(mavlink);
if height(clients) > 1
    remoteClient = clients(clients.SystemID ~= 255, :);
    autopilot = mavlinkclient(mavlink, remoteClient.SystemID, remoteClient.ComponentID);

    % Create command message
    cmdMsg = createmsg(dialect, "COMMAND_LONG");
    cmdMsg.Payload.target_system(:) = remoteClient.SystemID;
    cmdMsg.Payload.target_component(:) = remoteClient.ComponentID;
    cmdMsg.Payload.command(:) = 400;  % MAV_CMD_COMPONENT_ARM_DISARM
    cmdMsg.Payload.param1(:) = 1;     % arm

    sendmsg(mavlink, cmdMsg, autopilot);
end
```

### Heartbeat Timer with Error Handling

For robust applications, wrap the timer callback to prevent silent failures:

```matlab
% Using sendudpmsg (pre-discovery, to known SITL endpoint)
hbTimer = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
    'ErrorFcn', @(~,evt) warning("Heartbeat error: %s", evt.Data.message), ...
    'TimerFcn', @(~,~) sendudpmsg(mavlink, hbMsg, sitlHost, sitlPort));
start(hbTimer);
```

## Gotchas

- **Port 14550 is the GCS local port, not the autopilot's port.** When using
  `sendudpmsg`, the remote port must be the autopilot's listening port (PX4 SITL
  `-u` flag), not 14550. If the autopilot is already discovered via `listClients`,
  use `sendmsg(io, msg, client)` instead — it routes automatically.
- **Use `sendudpmsg` for pre-discovery messages, not `sendmsg`.** Calling
  `sendmsg(io, msg, client)` throws an error if the client hasn't been discovered
  yet. Use `sendudpmsg(io, msg, host, port)` for heartbeats and any pre-discovery
  communication.
- **All message fields live under `.Payload`.** Write `msg.Payload.type(:) = ...`,
  never `msg.type(:) = ...`. The top-level message struct contains metadata;
  protocol fields are always at `msg.Payload.fieldname`.
- **Always use `(:)` on payload field assignments.** `msg.Payload.field(:) = value`
  preserves the wire type (uint8, uint16, int32, etc.). Without `(:)`, MATLAB
  replaces the field with a double, producing corrupted MAVLink packets on the wire.
  This bug is silent — no error, no warning — and only manifests during interop.
- **`createmsg(dialect, msgName)` — dialect is the first argument.** Do NOT pass
  `mavlinkio` to `createmsg`. The io object sends messages; the dialect creates them.
- **`connect()` uses name-value pairs only.** It is `connect(io, "UDP", LocalPort=14550)`
  not `connect(io, "udpin", "0.0.0.0", 14550)`.
- **Do NOT create `mavlinksub(mavlink, "HEARTBEAT")` for connection verification.**
  `mavlinkio` already has a built-in heartbeat subscriber that populates
  `listClients()`. A manual HEARTBEAT subscriber is redundant. Only use `mavlinksub`
  for non-heartbeat message types (e.g., `"GLOBAL_POSITION_INT"`, `"ATTITUDE"`).
- **`listClients` always includes the local GCS client.** Check `height(clients) > 1`
  to confirm a remote system was discovered, not `> 0`.
- **`mavlinkclient(io, sysID, compID)` is a constructor, not a listing function.**
  It creates a handle — it does not verify the client exists. Use `listClients(io)`
  to check for discovered clients.
- **The subscriber read method is `latestmsgs(sub, count)`** — not `read()`,
  `receive()`, or `next()`.
- **Always stop and delete timers.** Orphaned timers continue running after
  `disconnect` and can cause MATLAB instability. Use `stop(t); delete(t)` or
  wrap in `onCleanup`.

## Conventions

- GCS identity: SystemID 255, ComponentID 1
- GCS local port (what GCS binds to): 14550
- PX4 SITL listening port: varies (check SITL build log for `udp port <N>`; e.g., 18570)
- ArduPilot SITL default outbound port to GCS: 14550
- Typical autopilot identity: SystemID 1, ComponentID 1
- Heartbeat rate: 1 Hz (MAVLink standard)
- Use `"common.xml"` dialect unless ArduPilot-specific extensions are needed

Copyright 2026 The MathWorks, Inc.
