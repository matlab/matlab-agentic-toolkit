---
name: matlab-configure-java
description: >
  Check which Java version MATLAB is using, switch it, or reset it without
  accidentally starting Java. Use this skill when a user wants to determine
  which Java/JDK/JRE version MATLAB is using, configure MATLAB to use a
  different JDK, or revert to the MATLAB default Java, or when a MATLAB
  script errors on a java.* API call ("no runtime environment for Java
  applications has been found", "Unable to find Java library"). Covers jenv
  and matlab_jenv, R2025a+ dynamic loading, restart requirements based on
  Java load status, and release- and platform-specific reset behavior. Also
  handles installing OpenJDK (the MATLAB Add-Ons Explorer, Adoptium, or a
  command-line mpm install through matlab-core:matlab-install-products).
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# Configure the MATLAB Java Runtime

Configure the MATLAB Java runtime by using `jenv` and `matlab_jenv`. For example, install OpenJDK after a `java.*` API failure, or select and switch to a specific JDK. The load status determines whether MATLAB requires a restart.

## When to Use

- A MATLAB script errors on a `java.*` API call with *"no runtime environment for Java applications has been found"* (R2026a and later) or *"Unable to find Java library"* (R2025a, R2025b). Error text often includes a link to `mathworks.com/matlab-openjdk`.
- User asks *"which Java version is my MATLAB session using?"* or wants to check the current MATLAB Java configuration. This is a read-only question: answer it with `jenv` alone (see Branch B step 1).
- User wants to switch MATLAB to a specific Java version — *"point MATLAB at the JDK at /path"*, *"change Java version used by MATLAB"*, *"switch MATLAB to Java 21"*.
- User wants to reset the MATLAB Java to the default. The reset command depends on release and platform (Branch B step 4).

## When NOT to Use

**If the user's request is about Java tooling *outside* MATLAB — compiling source with `javac`, building JARs, IDE Java configuration, OS-level `JAVA_HOME` for the terminal shell, or any other non-MATLAB Java toolchain — this skill does not apply. Exit silently with a minimal redirect: state briefly that the question is outside MATLAB Java-runtime setup, and point to general JDK / Java-toolchain documentation. Do NOT name `jenv`, `matlab_jenv`, `MATLAB_JAVA`, Adoptium, the Add-Ons Explorer, `mathworks.com/matlab-openjdk`, or any other mechanism from this skill — not even to disclaim them, and not in an "if you meant X instead" offer. Naming the tools of this skill in a response to a `javac` prompt implies MATLAB is involved even though it is not, which confuses the user rather than helping.**

The `javac` boundary is the most-commonly-confused adjacent topic. If a prompt matches either of these shapes, treat it as out of scope:

- *"How do I compile my Java code / class / program with `javac`?"*
- *"How do I build a JAR / set up a Java project / configure my Java IDE?"*

Also out of scope:

- **Installing a MathWorks support package (any product, not Java-specific).** Use `matlab-core:matlab-install-products`. This skill hands off to that skill only for a command-line (`mpm`) install of the OpenJDK support package in Branch A Option A.
- **Java errors with Java already loaded, or non-Java errors in the script.** Use `matlab-core:matlab-debug-code`.
- **Choosing a Databricks JDBC driver or adding a driver JAR.** Use `matlab-connect-databricks`. This skill handles only the Java runtime switch the driver might need.
- **Class-loading debugging inside a running Java-enabled MATLAB.** `javaaddpath`, `ClassNotFoundException`, and similar errors that occur *after* MATLAB has Java loaded are a different domain — the JVM is up, the classpath is wrong.
- **Non-Java MATLAB startup failures.** License errors, corrupted preferences, install issues. Different failure mode.

**Tool identity note:** The MATLAB `jenv` command (introduced R2021b) is unrelated to the third-party shell tool [github.com/jenv/jenv](https://github.com/jenv/jenv). This skill refers to the MATLAB `jenv` command only. Reading the current `JavaEnvironment` object (the `Version`/`Home`/`Library`/`Status`/`Configuration` fields this skill branches on) requires R2023a, when `jenv` gained its output-argument form.

## Workflow — Branch A: Script Hits a Java API

Fires when a MATLAB script errors on a `java.*` call with the Java-runtime-not-found signature. See [`references/error-signatures.md`](references/error-signatures.md) for the verbatim error-text patterns per release.

1. **Match the error text.** Confirm it is the Java-runtime-not-found error (R2026a and later) or the *"Unable to find Java library"* error (R2025a, R2025b). If the error text does not match either signature, this skill does not apply — the failure is a different Java problem (class-loading, `javaaddpath`, and so on).
2. **Present two install paths.** Do not enumerate more.
   - **Option A — OpenJDK support package.** The user installs it from the MATLAB Add-Ons Explorer. For a command-line install with `mpm` instead, hand off to `matlab-core:matlab-install-products`, then come back to step 3.
   - **Option B — Adoptium system install** ([adoptium.net](https://adoptium.net)). Download a supported LTS JDK for the user's platform and install it.

   **You MUST quote the URL `https://www.mathworks.com/matlab-openjdk` verbatim in your response** as the source of truth for supported JDK versions. Do not paraphrase it as "the MathWorks supported-JDK page" or "the OpenJDK documentation" — output the full URL so the user can navigate to it. Do **not** invent per-release JDK-version claims (*"R2026b requires Java 11"*, *"JDK 21 support arrived in R2025a"*, and so on). If asked which JDK version to use, direct the user to the URL.
3. **State the R2025a+ behavior positively.** Tell the user:
   > On R2025a+, MATLAB auto-discovers a system-installed JDK and loads it dynamically on the next `java.*` call. **No MATLAB restart, no agent session restart, and nothing else to configure.** Re-run the failing script.
4. **Re-run the script.** The originally failing `java.*` call now succeeds.
5. **Verify with `jenv`.** Call `jenv` (no arguments) via `evaluate_matlab_code`. Read the five fields (`Version`, `Home`, `Library`, `Status`, `Configuration`). After the first successful `java.*` call, `Status` is `loaded` and `Version` names the discovered JDK.

## Workflow — Branch B: Choose or Switch Java Version

Fires on version-switch prompts (*"switch to Java 21"*, *"point MATLAB at /opt/jdk21"*, *"which Java is MATLAB using?"*).

1. **Probe with `jenv` (no args).** Call `jenv` via `evaluate_matlab_code`. Report all five fields — `Version`, `Home`, `Library`, `Status`, `Configuration` — verbatim to the user. **Use `jenv` alone to inspect Java.** It reads the configuration without starting the JVM. Calling any Java class or method from MATLAB starts the JVM, which flips `Status` to `loaded` and means any later switch needs a MATLAB restart. If the user asked only which Java is in use, report the fields and stop.
2. **Read the `Status` field.** Consult [`references/load-status-check.md`](references/load-status-check.md) for the decision table. In short:
   - `Status: notloaded` → the new setting will be picked up on the next `java.*` call. **No MATLAB restart required.**
   - `Status: loaded` → **MATLAB must be quit and relaunched** to pick up the new JVM. In-process JVM swap is not supported.
3. **Recommend the switch call.** Default to `jenv("/path/to/jdk")` inside MATLAB. If the user prefers a shell workflow or MATLAB is not running, use the shell peer at `<matlabroot>/bin/matlab_jenv /path/to/jdk`. On Windows the shell peer is `<matlabroot>\bin\matlab_jenv.bat`. Always spell the executable exactly as `matlab_jenv` — no other spelling of the shell peer is valid. Do not name any alternative form to the user, even to warn against it. These calls write the personal configuration; if an installation configuration is set, it wins (see step 4, *Configuration levels*).
4. **Reset to the MATLAB default Java by clearing the configuration.** If the user asks only how to reset or whether a reset command works, explain it; run it only when they ask you to. The MATLAB default Java is what it uses if neither level has a Java configuration (see *Configuration levels* below). Check the release with `isMATLABReleaseOlderThan` and the platform with `computer("arch")` (`maca64` is Apple Silicon, `maci64` is Mac Intel). Neither call starts Java.
   - **What the default is:**
     - R2026a and earlier on Windows, Linux, and Mac Intel (maci64): the MATLAB-shipped JRE.
     - R2026a and earlier on Apple Silicon (maca64): system-installed Java. MATLAB has never shipped Java on Apple Silicon.
     - R2026b and later on every platform: system-installed Java (via `JAVA_HOME` / OS default). MATLAB ships no Java from R2026b.
   - **R2026a and later, every platform:** use `jenv("-clear")`. It removes the personal configuration so MATLAB uses the default above.
   - **R2025a and R2025b:** on Windows, Linux, and Mac Intel, use `jenv("factory")` to select the MATLAB-shipped JRE. On Apple Silicon there is no shipped JRE, so do not recommend `jenv("factory")`. Choose a JDK explicitly with `jenv("/path/to/jdk")`.
   - **Configuration levels.** `jenv(path)`, `jenv("system")`, and `jenv("factory")` write the *personal* configuration, and `jenv("-clear")` clears it. `jenv("-allusers", path)` (or `"system"` / `"factory"`) writes the *installation* configuration for every user of that MATLAB installation, and `jenv("-allusers", "-clear")` clears it. **If an installation configuration is set, it takes precedence over the personal one.** So if `jenv` still reports the old Java after a personal switch or `jenv("-clear")`, one of two things is true: an installation configuration is in effect, or the default above is itself that Java (for example, the system's default JDK on Apple Silicon or on R2026b and later). Tell the user about both. If they want MATLAB to use a different Java, recommend `jenv(path)`; do not suggest setting or changing `JAVA_HOME`. Recommend `jenv("-allusers", "-clear")` (or `jenv("-allusers", path)`) only after they confirm that changing Java for every user of the installation is what they want.
   - Restart rule is unchanged: a restart is required only if the current `Status` is `loaded`.
   - `jenv` treats any unrecognized string as a filesystem path, so `jenv("default")` errors with *"Java folder default does not exist."* Never suggest `jenv("default")`.
   - **The built-in `jenv` help text on R2026a and R2026b does not match this behavior** (for example, it says a restart is always required). Follow the rules in this step rather than re-checking the help text or the documentation.
5. **Verify with `jenv` (no args) — again.** Do **not** use `version -java` as the verify step. `jenv` reports both the configured JRE and its load status in a single call; `version -java` reports only the version and does not indicate whether the swap requires a restart.

## Key Functions

| Function | Purpose | Toolbox | Available From |
|----------|---------|---------|----------------|
| `jenv` (no args) | Report the current JavaEnvironment: `Version`, `Home`, `Library`, `Status`, `Configuration`. Primary probe and verify step. | (core MATLAB) | R2023a (object return) |
| `jenv(path)` | Configure MATLAB to use the JDK at `path` on the next `java.*` call. Restart required only if current `Status: loaded`. | (core MATLAB) | R2021b |
| `jenv("factory")` | Write the personal configuration to the MATLAB-shipped JRE. The reset to use on R2025a and R2025b on Windows, Linux, and Mac Intel (maci64). Not applicable on Apple Silicon (no shipped JRE). From R2026b it lands on system-installed Java. Restart required only if current `Status: loaded`. | (core MATLAB) | R2021b |
| `jenv("-clear")` | Clear the personal configuration so MATLAB uses its default Java for the release and platform. The reset to recommend on **R2026a and later** (all platforms). Does not override an installation configuration. Restart required only if current `Status: loaded`. | (core MATLAB) | R2026a |
| `jenv("-allusers", ...)` | Write (`path`, `"system"`, `"factory"`) or clear (`"-clear"`) the installation configuration, which applies to every user of the MATLAB installation and takes precedence over the personal one. Use only if the user confirms an all-users change. | (core MATLAB) | R2026a |
| `computer("arch")` | Identify the platform before recommending a reset: `maca64` (Apple Silicon), `maci64` (Mac Intel), `win64`, `glnxa64`. Does not start Java. | (core MATLAB) | — |
| `isMATLABReleaseOlderThan(release)` | Check the release before recommending a reset, e.g. `isMATLABReleaseOlderThan("R2026a")`. Does not start Java. | (core MATLAB) | R2020b |
| `<matlabroot>/bin/matlab_jenv <path>` | Shell peer of `jenv`. Use if MATLAB is not running or if you are scripting Java config from the shell. On Windows: `<matlabroot>\bin\matlab_jenv.bat <path>`. | (core MATLAB, shell) | R2021b |

## Patterns

### Pattern A — Verify After Install (Branch A)

Use after the user reports Java has been installed via Option A or Option B. Confirms auto-discovery worked without needing a restart.

```matlab
% After installing OpenJDK (Add-Ons Explorer or Adoptium), re-run the
% originally failing script; the java.* call succeeds. Then verify:
jenv
% Read Status; on R2025a+ after a successful java.* call it will be
% "loaded" and Version will name the discovered JDK.
```

### Pattern B — Probe, Then Switch (Branch B)

Use for any version-switch request. The probe result determines whether restart advice is needed.

```matlab
% 1. Probe current environment.
env = jenv;

% 2. Point MATLAB at the requested JDK.
jenv("/opt/jdk21");

% 3. Restart decision is a function of env.Status BEFORE the switch call:
%      "notloaded" -> no restart; the next java.* call picks it up
%      "loaded"    -> quit and relaunch MATLAB

% 4. Verify after (re)start, or after the next java.* call:
jenv
```

## Conventions

- **Always** use `jenv` (no args) as the probe and the verify step. It reports Version and Status in one call, and it is the only inspection call to make: it reads the configuration without starting the JVM.
- **Always** name the shell peer as `matlab_jenv`, not `jenv`. The `matlab_jenv` executable lives at `<matlabroot>/bin/matlab_jenv` (`<matlabroot>\bin\matlab_jenv.bat` on Windows).
- **Always** wire the restart recommendation to the `Status` field: `notloaded → no restart`, `loaded → restart`. Do not give blanket restart advice.
- **Never** recommend legacy environment-variable-based Java configuration. `jenv` inside MATLAB and `matlab_jenv` from the shell are the R2021b+ sanctioned APIs and are the only APIs to recommend. Do not name the legacy env-var mechanism to the user even to warn against it — surface it only if the user brings it up first.
- **Never** use `version -java` as the verify step. It does not report load status, and the goal of verification is to confirm the swap will take effect without a restart.
- **Ask first** before recommending or running `jenv("-allusers", ...)`. It changes Java for every user of the MATLAB installation, so confirm that is what the user wants. Personal-level `jenv` calls need no confirmation.
- **Never** invent per-release JDK-compatibility claims (*"R2026b requires Java 11 specifically"*, and so on). Whenever JDK version compatibility comes up — in either branch, on any prompt that names a JDK version or asks which one to use — your response **MUST include the full URL `https://www.mathworks.com/matlab-openjdk`** verbatim, not paraphrased.

## Common Mistakes

**This table is diagnostic — for your reasoning only. Do NOT quote, paraphrase, or name these anti-patterns in your response to the user. Give positive guidance ("do X") rather than negative warnings ("don't do Y"), because naming the anti-pattern in the response teaches it back to the reader.**

Each row is a common mistake made without this skill.

| Mistake | Why It Is Wrong | Correct Approach |
|---------|----------------|------------------|
| Present the legacy env-var mechanism as the primary or coequal switch mechanism. | The legacy env var is superseded by `jenv` in R2021b. It bypasses the load-status branch and gives no visibility into the current environment. | Use `jenv(path)` inside MATLAB or `<matlabroot>/bin/matlab_jenv <path>` from the shell. Do not surface the legacy mechanism unless the user asks about it explicitly. |
| Say *"any change requires restarting MATLAB"* / *"swapping the JVM always requires a restart regardless"*. | Ignores R2025a+ dynamic loading. If `Status` is `notloaded`, MATLAB picks up the new setting on the next `java.*` call with no restart. | Probe with `jenv` first. Branch on `Status` per [`references/load-status-check.md`](references/load-status-check.md). |
| Read `Status: notloaded` correctly, then recommend a restart anyway. | The observation and the recommendation must be wired together. `notloaded` means MATLAB has not started the JVM yet and can pick up the new configuration on the next call. | State it aloud: *"Status is notloaded, so no restart is required — the new JDK will be picked up on the next java.\* call."* |
| Name the shell peer without the `matlab_` prefix. | The bare-name form of the shell peer does not exist; users following that path get a *file not found* error. | Always spell the shell peer exactly as `matlab_jenv`, located at `<matlabroot>/bin/matlab_jenv`. Do not mention any other spelling to the user. |
| Use `version -java` as the verify step. | `version -java` reports only the version string; it does not indicate load status, so it cannot confirm whether a restart is required. | Use `jenv` (no args). Reports Version, Home, Library, `Status`, Configuration in one call. |
| Confuse the MATLAB `jenv` command with the third-party shell tool [github.com/jenv/jenv](https://github.com/jenv/jenv). | Two products named "jenv" exist. The third-party tool works through `PATH` / `JAVA_HOME` shims and does not control the MATLAB JVM. | Disambiguate on first mention. This skill refers exclusively to the MATLAB `jenv` command (R2021b+). |
| After installing Java on R2025a+, tell the user they must point MATLAB at it explicitly. | On R2025a+, MATLAB auto-discovers a system-installed JDK. No pointing required for a clean install. | State positively: *"MATLAB will auto-discover it — re-run the script."* Reserve `jenv(path)` for the version-switch case (Branch B), not the fresh-install case (Branch A). |
| Answer *"which Java is my MATLAB session using?"* by calling a Java class method from MATLAB, such as reading a JVM system property. | The call starts the JVM. `Status` becomes `loaded`, so a switch the user makes next requires an avoidable MATLAB restart. | Call `jenv` (no args) and report its fields. |
| Run `jenv("factory")` on Apple Silicon to reset. | MATLAB never shipped Java on Apple Silicon, so there is no shipped JRE to restore. A reset means clearing the configuration, not picking `factory`. | Check `computer("arch")` and the release first, then pick the reset from Branch B step 4 (`jenv("-clear")` on R2026a and later). |
| Assume a personal `jenv` switch or `jenv("-clear")` took effect even though `jenv` still shows the old Java. | An installation configuration (set with `-allusers`) takes precedence over the personal one. | Re-probe with `jenv`. If nothing changed, explain the installation configuration and the possibility that the default is that same Java. Offer the `-allusers` form only with the user's confirmation. |
| Invent JDK-version compatibility claims per release (*"R2026b requires Java 11"*, *"JDK 21 support arrived in R2025a"*). | The supported-OpenJDK table changes across releases. Guessing produces contradictory advice. | Quote the URL `https://www.mathworks.com/matlab-openjdk` verbatim as the source of truth. |

----

Copyright 2026 The MathWorks, Inc.

----
