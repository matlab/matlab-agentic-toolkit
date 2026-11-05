# Load-Status Check

Decision table for interpreting the `Status` field returned by `jenv` (no args).

## The `jenv` output

`jenv` (called with no arguments) returns a `JavaEnvironment` object with five fields:

| Field | Type | Meaning |
|-------|------|---------|
| `Version` | string | JDK version currently configured. Empty (`[0×0 string]`) when nothing is configured. |
| `Home` | string | Absolute path to the JDK. Empty when nothing is configured. |
| `Library` | string | Absolute path to the JVM shared library. Empty when nothing is configured. |
| `Status` | string | `"loaded"` or `"notloaded"`. Governs the restart decision. |
| `Configuration` | string | The configured value (`""` when nothing is configured). It does not say whether the personal or the installation (`-allusers`) configuration set it. |

## Decision table

| `Status` value | Meaning | Restart required after a switch or reset (`jenv(path)`, or the reset command for the release and platform in SKILL.md Branch B step 4)? | What to tell the user |
|---|---|---|---|
| `notloaded` | MATLAB has selected a JRE but has not yet started the JVM. On R2025a+ MATLAB loads Java lazily on the first `java.*` call. | **No.** | *"The new setting will be picked up on the next `java.*` call — no MATLAB restart required."* |
| `loaded` | MATLAB has started the JVM. In-process JVM swap is not supported. | **Yes.** | *"MATLAB must be quit and relaunched to pick up the new JVM."* |

## Verification

After the switch (and, if `Status: loaded`, after the MATLAB relaunch), call `jenv` again with no arguments. Confirm `Version` names the requested JDK. If a `java.*` call has run since the switch, `Status` will be `loaded`; otherwise `notloaded`.

Do **not** use `version -java` for verification — it reports only the version string and gives no signal about whether a restart is still pending.

## Notes

- **The observation-recommendation link is the whole point of this table.** The common failure mode is reading `Status: notloaded` correctly and then recommending a restart anyway. Wire the two together explicitly in the response.
- **`Configuration` is informational, not decisional.** On R2025a+ with a fresh auto-discovered JDK, this field is `""`. It becomes non-empty once a Java is configured at either level. An installation configuration takes precedence over a personal one; if a personal change leaves `jenv` output unchanged, see SKILL.md Branch B step 4, *Configuration levels*.
- **`Status` is the only field that governs restart advice.** Do not branch on `Configuration`, `Home`, or `Version` for the restart decision.

----

Copyright 2026 The MathWorks, Inc.

----
