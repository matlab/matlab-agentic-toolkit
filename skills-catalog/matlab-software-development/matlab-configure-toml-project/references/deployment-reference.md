# matlab.toml Deployment Reference — `[compiler]`

The `[compiler]` table configures MATLAB Compiler and MATLAB Compiler SDK build targets. It
holds ten target types, each an **array of tables**, so a project can define several builds of
the same kind:

```toml
[[compiler.standalone]]
name = "analyzer"

[[compiler.standalone]]
name = "analyzerDebug"
```

Every key in `[compiler]` is optional except `name` on `[[compiler.standalone]]` — the only
required key in the entire deployment schema.

Path values follow the same `iri` rules described in @format-reference.md: input files must
exist and sit inside the project root, output paths need not exist. Each key below is annotated
accordingly.

## Shared Property Groups

Three groups of keys are shared across targets. Rather than repeat them ten times, they are
defined once here and referenced per target as **common**, **files**, and **installer**.

### common — build properties

Available on **all ten** targets.

```toml
[[compiler.standalone]]
name = "analyzer"
auto-detect-data-files = true
obfuscate-archive = false
secrets-manifest = "deploy/secrets.json"
support-packages = "autodetect"
verbose = true

[compiler.standalone.external-encryption-key]
key-file = "deploy/keys/build.key"
runtime-loader-file = "deploy/keys/loader.m"
```

- `auto-detect-data-files` (boolean) — include data files discovered by dependency analysis
- `obfuscate-archive` (boolean) — obfuscate the embedded archive
- `secrets-manifest` (path, must exist, within root) — secrets manifest file
- `support-packages` (string or array of strings) — support packages to include.
  Single-string values: `"autodetect"`, `"none"`. An array names specific support packages.
  *(Not validated in R2026b.)*
- `verbose` (boolean) — verbose build output
- `external-encryption-key` (table) — external encryption key configuration:
  - `key-file` (path, must exist, within root)
  - `runtime-loader-file` (path, must exist, within root)

### files — function and additional files

Available on every target **except** `standalone` and `web-app`, which declare their own
entry-point keys instead.

```toml
[[compiler.python-package]]
package-name = "myanalysis"
function-files = [
    "src/analyze.m",
    "src/report.m",
]
additional-files = [
    "data/coefficients.mat",
]
```

- `function-files` (array of paths, must exist, within root) — exported entry-point functions
- `additional-files` (array of paths, must exist, within root) — extra files to include

### installer — packaging properties

Available on `standalone`, `excel-add-in`, `dot-net-assembly`, `c-shared-library`,
`cpp-shared-library`, `com-component`, `java-package`, and `python-package`. Not available on
`web-app` or `production-server-archive`, which produce archives rather than installers.

```toml
[[compiler.standalone]]
name = "analyzer"
application-name = "Signal Analyzer"
summary = "Interactive signal analysis"
description = "Full-featured signal analysis application."
installation-notes = "Requires 2 GB of free disk space."
author-name = "Jane Doe"
author-email = "jane@example.com"
author-company = "Acme Corp"
installer-name = "SignalAnalyzerSetup"
installer-version = "1.2.0"
installer-output-folder = "release/installer"
default-installation-folder = "/opt/SignalAnalyzer"
installer-icon-file = "resources/installer.png"
installer-logo-file = "resources/logo.png"
installer-splash-file = "resources/splash.png"
add-remove-programs-icon-file = "resources/arp.png"
installer-additional-files = [
    "doc/README.txt",
]
package-type = "auto"
runtime-delivery = "web"
shortcut = "Signal Analyzer"
```

- `application-name` (string) — application name shown by the installer
- `summary` (string) — short summary
- `description` (string) — long description
- `installation-notes` (string) — notes displayed during installation
- `author-name`, `author-email`, `author-company` (strings) — author details.
  Note `author-email` is a plain string here — unlike `[[package]].provider.email`, it carries
  no `email` format annotation.
- `installer-name` (string) — installer file name
- `installer-version` (string, semver) — installer version
- `installer-output-folder` (path, output — need not exist) — where the installer is written
- `default-installation-folder` (path, output — need not exist) — default install location
- `installer-icon-file`, `installer-logo-file`, `installer-splash-file`
  (paths, must exist, within root) — installer artwork
- `add-remove-programs-icon-file` (path, must exist, within root) — Add/Remove Programs icon
- `installer-additional-files` (array of paths, must exist, within root) — files bundled with
  the installer
- `package-type` (string) — `"auto"` or `"zip"`. *(Not validated in R2026b.)*
- `runtime-delivery` (string) — how MATLAB Runtime is delivered: `"web"`, `"installer"`, or
  `"none"`. *(Not validated in R2026b.)*
- `shortcut` (string) — shortcut name created by the installer

## Target Summary

| Target | common | files | installer | Required |
|--------|:------:|:-----:|:---------:|----------|
| `[[compiler.standalone]]` | ✅ | — | ✅ | `name` |
| `[[compiler.web-app]]` | ✅ | — | — | — |
| `[[compiler.excel-add-in]]` | ✅ | ✅ | ✅ | — |
| `[[compiler.dot-net-assembly]]` | ✅ | ✅ | ✅ | — |
| `[[compiler.c-shared-library]]` | ✅ | ✅ | ✅ | — |
| `[[compiler.cpp-shared-library]]` | ✅ | ✅ | ✅ | — |
| `[[compiler.production-server-archive]]` | ✅ | ✅ | — | — |
| `[[compiler.com-component]]` | ✅ | ✅ | ✅ | — |
| `[[compiler.java-package]]` | ✅ | ✅ | ✅ | — |
| `[[compiler.python-package]]` | ✅ | ✅ | ✅ | — |

## `[[compiler.standalone]]`

Standalone desktop application. Groups: **common** + **installer**. Uses `app-file` rather
than `function-files`.

```toml
[[compiler.standalone]]
name = "analyzer"
executable-name = "SignalAnalyzer"
app-file = "app/SignalAnalyzer.mlapp"
additional-files = [
    "data/defaults.mat",
]
executable-version = "1.2.0"
executable-icon-file = "resources/app.png"
executable-splash-screen-file = "resources/splash.png"
custom-help-text-file = "doc/helpText.txt"
runtime-log-file = "derived/analyzer.log"
build-output-folder = "derived/standalone"
embed-archive = true
treat-inputs-as-numeric = false
suppress-windows-cmd-prompt = true
```

- `name` (string) — **required**; identifies this build configuration
- `executable-name` (string) — name of the generated executable
- `app-file` (path, must exist, within root) — entry-point app or script
- `additional-files` (array of paths, must exist, within root) — extra files to include
- `executable-version` (string, semver) — executable version
- `executable-icon-file`, `executable-splash-screen-file`
  (paths, must exist, within root) — executable artwork
- `custom-help-text-file` (path, must exist, within root) — custom `-help` text
- `runtime-log-file` (path, output — need not exist) — runtime log destination
- `build-output-folder` (path, output — need not exist) — build output directory
- `embed-archive` (boolean) — embed the archive in the executable
- `treat-inputs-as-numeric` (boolean) — parse command-line inputs as numbers
- `suppress-windows-cmd-prompt` (boolean) — hide the Windows console window

## `[[compiler.web-app]]`

MATLAB Web App Server archive. Groups: **common** only.

```toml
[[compiler.web-app]]
app-file = "app/Dashboard.mlapp"
additional-files = [
    "data/lookup.mat",
]
archive-name = "Dashboard"
output-folder = "derived/webapps"
```

- `app-file` (string) — entry-point app. Note this is a plain string in the schema, not an
  `iri` — it is not existence-checked, unlike `standalone`'s `app-file`.
- `additional-files` (array of paths, must exist, within root)
- `archive-name` (string) — name of the generated `.ctf` archive
- `output-folder` (path, output — need not exist)

## `[[compiler.excel-add-in]]`

Microsoft Excel add-in. Groups: **common** + **files** + **installer**.

```toml
[[compiler.excel-add-in]]
add-in-name = "SignalTools"
add-in-version = "1.0.0"
class-name = "SignalClass"
function-files = ["src/smooth.m"]
generate-visual-basic-file = true
embed-archive = true
debug-build = false
runtime-log-file = "derived/addin.log"
build-output-folder = "derived/excel"
```

- `add-in-name` (string) — add-in name
- `add-in-version` (string, semver) — add-in version
- `class-name` (string) — generated class name
- `generate-visual-basic-file` (boolean) — emit a `.bas` Visual Basic file
- `embed-archive` (boolean) — embed the archive in the add-in
- `debug-build` (boolean) — build with debug symbols
- `runtime-log-file` (path, output — need not exist)
- `build-output-folder` (path, output — need not exist)

## `[[compiler.dot-net-assembly]]`

.NET assembly. Groups: **common** + **files** + **installer**.

```toml
[[compiler.dot-net-assembly]]
assembly-name = "SignalTools"
assembly-version = "1.0.0"
class-name = "SignalClass"
function-files = ["src/smooth.m"]
framework-version = "4.8"
interface = "matlab-data"
enable-remoting = false
debug-build = false
embed-archive = true
sample-generation-files = ["samples/useSmooth.m"]
strong-name-key-file = "deploy/signing.snk"
build-output-folder = "derived/dotnet"
```

- `assembly-name` (string) — assembly name
- `assembly-version` (string, semver) — assembly version
- `class-name` (string) — generated class name
- `framework-version` (string) — target .NET framework version
- `interface` (string) — API style: `"mwarray"` or `"matlab-data"`. *(Not validated in R2026b.)*
- `enable-remoting` (boolean) — enable .NET remoting
- `debug-build` (boolean) — build with debug symbols
- `embed-archive` (boolean) — embed the archive in the assembly
- `sample-generation-files` (array of paths, must exist, within root) — MATLAB files used to
  generate sample driver code
- `strong-name-key-file` (path, within root — need not exist) — strong-name key file
- `build-output-folder` (path, output — need not exist)

## `[[compiler.c-shared-library]]`

C shared library. Groups: **common** + **files** + **installer**.

```toml
[[compiler.c-shared-library]]
library-name = "libsignal"
function-files = ["src/smooth.m"]
debug-build = false
embed-archive = true
build-output-folder = "derived/clib"
```

- `library-name` (string) — library name
- `debug-build` (boolean) — build with debug symbols
- `embed-archive` (boolean) — embed the archive in the library
- `build-output-folder` (path, output — need not exist)

## `[[compiler.cpp-shared-library]]`

C++ shared library. Groups: **common** + **files** + **installer**.

```toml
[[compiler.cpp-shared-library]]
library-name = "libsignal"
library-version = "1.0.0"
function-files = ["src/smooth.m"]
interface = "matlab-data"
sample-generation-files = ["samples/useSmooth.m"]
debug-build = false
build-output-folder = "derived/cpplib"
```

- `library-name` (string) — library name
- `library-version` (string, semver) — library version
- `interface` (string) — API style: `"mwarray"` or `"matlab-data"`. *(Not validated in R2026b.)*
- `sample-generation-files` (array of paths, must exist, within root)
- `debug-build` (boolean) — build with debug symbols
- `build-output-folder` (path, output — need not exist)

## `[[compiler.production-server-archive]]`

MATLAB Production Server deployable archive. Groups: **common** + **files**. No installer
group — this target produces a `.ctf` archive.

```toml
[[compiler.production-server-archive]]
archive-name = "signalService"
function-files = ["src/smooth.m"]
function-signatures = "deploy/signatures.json"
routes-file = "deploy/routes.json"
output-folder = "derived/mps"
```

- `archive-name` (string) — archive name
- `function-signatures` (string) — function signatures file. A plain string in R2026b; later
  releases tighten this to a path that must exist inside the project root.
- `routes-file` (path, within root — need not exist) — HTTP routes file
- `output-folder` (path, output — need not exist)

## `[[compiler.com-component]]`

COM component. Groups: **common** + **files** + **installer**.

```toml
[[compiler.com-component]]
component-name = "SignalTools"
component-version = "1.0.0"
class-name = "SignalClass"
function-files = ["src/smooth.m"]
debug-build = false
embed-archive = true
build-output-folder = "derived/com"
```

- `component-name` (string) — component name
- `component-version` (string, semver) — component version
- `class-name` (string) — generated class name
- `debug-build` (boolean) — build with debug symbols
- `embed-archive` (boolean) — embed the archive in the component
- `build-output-folder` (path, output — need not exist)

## `[[compiler.java-package]]`

Java package. Groups: **common** + **files** + **installer**.

```toml
[[compiler.java-package]]
package-name = "com.acme.signal"
class-name = "SignalClass"
function-files = ["src/smooth.m"]
interface = "matlab-data"
sample-generation-files = ["samples/UseSmooth.java"]
debug-build = false
build-output-folder = "derived/java"
```

- `package-name` (string) — Java package name
- `class-name` (string) — generated class name
- `interface` (string) — API style: `"mwarray"` or `"matlab-data"`. *(Not validated in R2026b.)*
- `sample-generation-files` (array of paths, must exist, within root)
- `debug-build` (boolean) — build with debug symbols
- `build-output-folder` (path, output — need not exist)

## `[[compiler.python-package]]`

Python package. Groups: **common** + **files** + **installer**.

```toml
[[compiler.python-package]]
package-name = "myanalysis"
function-files = [
    "src/analyze.m",
    "src/report.m",
]
additional-files = [
    "data/coefficients.mat",
]
sample-generation-files = [
    "samples/use_analyze.py",
]
build-output-folder = "derived/python"
application-name = "My Analysis"
author-name = "Jane Doe"
installer-version = "1.0.0"
runtime-delivery = "installer"
verbose = true
```

- `package-name` (string) — Python package name
- `sample-generation-files` (array of paths, must exist, within root)
- `build-output-folder` (path, output — need not exist)

----

Copyright 2026 The MathWorks, Inc.

----
