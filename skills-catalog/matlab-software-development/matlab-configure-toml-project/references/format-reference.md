# matlab.toml Format Reference

Documented against the R2026b schema.

Every section is optional — the schema declares no required top-level key. In practice, set
`name`, since it supplies the project's display name.

When generating a `matlab.toml`, emit sections in this order:

`name` → `[user]` → `[folders]` → `[dependencies]` → `[project]` → `[[package]]` →
`[compiler]` → `[matlab]` → `[simulink]`

`[compiler]` deployment targets are documented separately in @deployment-reference.md.

## Validation Rules

> **Violations usually fail silently.** MATLAB's schema validator reports unrecognized keys,
> missing files, out-of-root paths, type mismatches, and missing required keys — but
> `openProject` does not run it. A `matlab.toml` containing any of these mistakes opens without
> an error or a warning; the offending setting is simply ignored. So a misspelled key does not
> announce itself, it just silently fails to take effect. Get the keys right by construction:
> check every key against this reference rather than relying on MATLAB to complain.

### Tables are closed

Any key not listed in the schema is an unrecognized property. There are no extension points.
`[user]` is the sole exception — it accepts arbitrary keys and nested tables.

### Path values carry attributes

Path-valued keys are annotated with attributes that constrain what the value may point at:

- **must exist** — the file or folder must be present on disk
- **within root** — the value must resolve to the project root or a location beneath it
- **pattern** — values containing `*` are accepted as glob patterns rather than literal paths

## Top-Level Fields

```toml
name = "My Project"        # Project display name.
```

- `name` (string) — project display name. Optional per the schema, but set it.

## `[user]`

Free-form section for custom project data not covered by other sections. No fixed schema — any
keys and nested tables are allowed. This is the only table in the file that accepts unknown
keys. Use it for team-specific metadata, external tool configuration, or workflow flags that
don't map to any standard section.

Do not record information here that can be described using other properties.

```toml
[user]
data = 2

[user.company]
answer = 42
```

## `[folders]`

Defines which directories are on the MATLAB path and which contain tests.

```toml
[folders]
path = [
    "src",
    "utilities",
    "helpers",
]
test = [
    "tests",
    "tests/integration",
]
```

- `path` (array of paths, must exist, within root) — directories added to the MATLAB path when
  the project opens
- `test` (array of paths, must exist, within root) — directories containing test files

## `[dependencies]`

Each key names either a MATLAB package or a reference project. Three value formats are
supported. MathWorks products (for example, Signal Processing Toolbox) are not packages and
must not be listed here.

### Package dependency: simple version string

```toml
[dependencies]
mytoolbox = "3.*"
```

### Package dependency: version with optional ID

```toml
[dependencies]
motor = {version = "*", id = "9b9e5bc2-a583-4d79-98c5-d2b9af135697"}
```

- `version` (string, semver) — **required**
- `id` (string) — optional UUID of the package

### Reference project path

```toml
[dependencies]
shared-utils = {path = "../shared_utils_lib"}
external-lib = {path = "/absolute/path/to/lib", absolute = true}
```

The key (`shared-utils` above) is a display label chosen by the user. It has no relationship to
the directory name — do not assume they match.

- `path` (path, must exist) — **required**; relative or absolute path to the referenced
  project. Unlike most path keys, it may point outside the project root. Resolve it by listing
  the candidate parent directory and finding the project folder. The referenced project can use
  either a legacy `.prj` definition or `matlab.toml`. `path` carries the `mustExist` attribute,
  so a guessed name that does not resolve is a schema violation — but `openProject` loads the
  file anyway without complaint, so nothing will tell you the guess was wrong.
- `absolute` (boolean) — optional; whether the path is absolute

## `[project]`

Project lifecycle configuration, shortcuts, labels, and profiles.

```toml
[project]
summary = "Short project summary"
startup-folder = "src"
startup-files = [
    "setup/startup.m",
    "setup/checkDeps.m",
]
shutdown-files = [
    "setup/cleanup.m",
]
custom-tasks = [
    "tasks/myCustomTask.m",
]
```

- `summary` (string) — short project summary
- `startup-folder` (path, must exist) — folder to set as current directory on project open.
  May be outside the project root.
- `startup-files` (array of paths, must exist, within root) — scripts run when the project
  opens, in order
- `shutdown-files` (array of paths, must exist, within root) — scripts run when the project
  closes, in order
- `custom-tasks` (array of paths, must exist, within root) — custom task scripts

### `[project.dependency-analyzer]`

```toml
[project.dependency-analyzer]
cache-file = "derived/dependencyCache.mat"
```

- `cache-file` (path, output — need not exist) — dependency analyzer cache file

### `[project.shortcuts]`

Named shortcuts to MATLAB scripts. Each shortcut is a table with a `path` and an optional
`icon`; no other keys are permitted.

- `path` (path, must exist, within root) — **required**
- `icon` (path, must exist, within root) — optional icon file

#### Un-grouped shortcuts

```toml
[project.shortcuts]
"Run Analysis" = {path = "scripts/runAnalysis.m"}
"Open App" = {path = "app/launch.m", icon = "resources/appIcon.png"}
```

#### Grouped shortcuts

Shortcuts can be nested one level under a group name:

```toml
[project.shortcuts.Analysis]
"Run All" = {path = "scripts/runAll.m"}
"Run Subset" = {path = "scripts/runSubset.m"}

[project.shortcuts.Deployment]
"Build" = {path = "scripts/build.m"}
```

### `[project.labels.CategoryName]`

File labeling organized by category. Each label maps to an array of file paths, directory
paths, or glob patterns. Entries must exist and sit within the project root, except that any
entry containing `*` is treated as a pattern and accepted as-is.

```toml
[project.labels.Classification]
Production = [
    "src/core.m",
    "src/utils.m",
]
Test = [
    "tests",
]
Generated = [
    "derived/*.m",
]
```

### `[[project.profile]]`

Export profiles that filter project contents. Uses TOML array-of-tables syntax.

```toml
[[project.profile]]
name = "CustomerRelease"
excluded-labels = [
    {category = "Classification", label = "Internal"},
]

[[project.profile]]
name = "TestOnly"
included-files = [
    {category = "Classification", label = "Test"},
]

[[project.profile]]
name = "NoGenerated"
excluded-files = [
    {category = "Classification", label = "Generated"},
]
```

- `name` (string) — profile display name
- `included-files` — array of `{category, label}` tables; restricts the profile to files
  carrying these labels
- `excluded-files` — array of `{category, label}` tables; drops the files carrying these labels
  from the profile
- `excluded-labels` — array of `{category, label}` tables; drops the label metadata itself, so
  exported files keep their content but lose these labels

In all three, `category` and `label` define the entry — both must be present.

### `[project.dashboards]`

Dashboard configuration using label references to define component and unit groupings.

```toml
[project.dashboards]
component = {category = "Classification", label = "Component"}
unit = {category = "Classification", label = "Unit"}
```

- `component` — label reference (`{category, label}`, both required)
- `unit` — label reference (`{category, label}`, both required)

### `[project.digital-thread]`

Digital thread traceability settings.

```toml
[project.digital-thread]
tool-output-tracking = true
ignore = ["derived/", "results/*.mat"]
```

- `tool-output-tracking` (boolean) — enable or disable tool output tracking
- `ignore` (string or array of strings) — files or patterns to exclude from tracking

## `[[package]]`

MATLAB package build metadata. Uses TOML array-of-tables syntax for defining one or more
MATLAB packages. Required fields: **`id`** and **`package-root`**. Everything else is
optional — including `name` and `version`, though a publishable package should set both.
Packages can include MATLAB code, Simulink models, apps, documentation, and other project
content. Use `matlab-package-toolbox` for the authoring and build workflow, and
`matlab-use-package-manager` to install a completed `.mltbx` package.

```toml
[[package]]
name = "My Package"
version = "1.2.5"
id = "4919a5e0-b81e-43dc-a238-ea92bcbd4d39"
package-root = "toolbox"
display-name = "My Package Display Name"
summary = "A brief toolbox summary"
description = "A longer description of what the toolbox does."
preview-image-file = "resources/preview.png"
getting-started-file = "doc/GettingStarted.mlx"
output-file-name = "MyToolbox.mltbx"
output-folder = "release"
use-license-bsd = true
release-compatibility = "24.2"
supported-platforms = ["windows", "macos", "linux"]
product-dependencies = ["MATLAB", "Signal Processing Toolbox"]
```

- `id` (string) — **required**; unique UUID for the package
- `package-root` (path, must exist, within root) — **required**; root directory for packaging
- `name` (string) — package name
- `version` (string, semver) — package version
- `display-name` (string) — display name shown in MATLAB
- `summary` (string) — short toolbox summary
- `description` (string) — longer toolbox description
- `preview-image-file` (path, must exist, within root) — preview image
- `getting-started-file` (path, must exist, within root) — getting-started guide
- `output-file-name` (path, output — need not exist) — name of the output `.mltbx` file
- `output-folder` (string) — output directory for the packaged MATLAB package. A plain string, not a
  validated path.
- `use-license-bsd` (boolean) — whether to include a BSD license
- `release-compatibility` (string, semver) — minimum compatible MATLAB release
- `supported-platforms` (array of strings) — `"windows"`, `"macos"`, `"linux"`.
- `product-dependencies` (array of strings) — required MathWorks products

### `[package.folders]`

A sub-table of the most recently declared `[[package]]`.

```toml
[[package]]
id = "4919a5e0-b81e-43dc-a238-ea92bcbd4d39"
package-root = "toolbox"

[package.folders]
path = ["src", "utilities"]
java = ["lib/java"]
```

- `path` (array of paths, must exist, within root) — directories added to the MATLAB path
- `java` (array of paths, must exist, within root) — Java class path directories

### `[[package.apps]]`

An array of tables. The inline-array form shown below is equivalent and often more readable for
a single app.

```toml
[[package]]
id = "4919a5e0-b81e-43dc-a238-ea92bcbd4d39"
package-root = "toolbox"
apps = [
    {app-file = "apps/MyApp.mlapp"},
]
```

- `app-file` (path, must exist, within root) — **required**; path to an `.mlapp` file

### `[package.provider]`

A single table, not an array — a package has one provider.

```toml
[[package]]
id = "4919a5e0-b81e-43dc-a238-ea92bcbd4d39"
package-root = "toolbox"
provider = {name = "Jane Doe", organization = "Acme Corp", email = "jane@acme.com", url = "https://acme.com"}
```

- `name` (string) — author name
- `organization` (string) — organization name
- `email` (string, email) — contact email
- `url` (string, url) — website URL

### `[[package.required-additional-software]]`

An array of tables — a package may require several pieces of third-party software. All four
keys are required in each entry.

```toml
[[package]]
id = "4919a5e0-b81e-43dc-a238-ea92bcbd4d39"
package-root = "toolbox"

[[package.required-additional-software]]
name = "Python"
platform = "linux"
download-url = "https://www.python.org/downloads/"
license-url = "https://docs.python.org/3/license.html"
```

- `name` (string) — **required**; software name
- `platform` (string) — **required**; `"windows"`, `"macos"`, or `"linux"`.
- `download-url` (string, url) — **required**; download URL
- `license-url` (string, url) — **required**; license URL

## `[compiler]`

MATLAB Compiler and Compiler SDK build targets — ten target types, each an array of tables.
Documented in full in @deployment-reference.md.

```toml
[[compiler.standalone]]
name = "analyzer"
executable-name = "SignalAnalyzer"
app-file = "app/SignalAnalyzer.mlapp"
build-output-folder = "derived/standalone"
```

## `[matlab.test]`

MATLAB test runner configuration for coverage and test suite definitions.

### `[matlab.test.coverage-setting]`

```toml
[matlab.test.coverage-setting]
enabled = true
auto-open = false
mode = "statement"
generation-enabled = true
```

- `enabled` (boolean) — enable coverage collection
- `auto-open` (boolean) — automatically open coverage results
- `mode` (string) — coverage mode. The schema does not constrain the value.
- `generation-enabled` (boolean) — enable coverage report generation

### `[[matlab.test.test-suite]]`

```toml
[[matlab.test.test-suite]]
name = "Unit Tests"
type = "folder"
value = ["tests/unit"]

[[matlab.test.test-suite]]
name = "Integration Tests"
type = "folder"
value = ["tests/integration"]
```

- `name` (string) — test suite display name
- `type` (string) — how to interpret the value (e.g., `"folder"`). The schema does not constrain
  the value.
- `value` (array of strings) — paths or identifiers for the test suite

## `[simulink]`

Simulink integration settings.

```toml
[simulink]
start-simulink = false
cache-folder = "derived/slcache"
codegen-folder = "derived/codegen"
refresh-customizations = true
```

- `start-simulink` (boolean) — whether to launch Simulink when the project opens
- `cache-folder` (path, output — need not exist) — Simulink cache files
- `codegen-folder` (path, output — need not exist) — generated code
- `refresh-customizations` (boolean) — whether to refresh Simulink customizations on project
  open

Note that `top-model`, `private-dictionary`, `exported-dictionary`, and
`managed-simulink-project` are **not** in the schema and count as unrecognized properties, even
though MATLAB product code reads them.

### `[simulink.process-advisor]`

Process Advisor settings for Simulink projects. Every value is a **string**, including the ones
that look boolean or numeric.

```toml
[simulink.process-advisor]
incremental-build = "on"
enable-model-caching = "on"
max-num-models-in-cache = "10"
max-num-test-results-in-cache = "20"
suppress-output-when-interactive = "off"
show-file-extension = "on"
handle-untracked-io = "warn"
filter-digital-thread-messages = "off"
detect-multiple-process-models = "on"
publish-to-results-cloud = "off"
show-test-case-path = "on"
```

- `incremental-build` (string) — enable incremental builds
- `enable-model-caching` (string) — cache compiled models
- `max-num-models-in-cache` (string) — maximum number of cached models
- `max-num-test-results-in-cache` (string) — maximum number of cached test results
- `suppress-output-when-interactive` (string) — suppress console output in interactive mode
- `show-file-extension` (string) — show file extensions in the advisor
- `handle-untracked-io` (string) — behavior for untracked I/O artifacts
- `filter-digital-thread-messages` (string) — filter digital thread messages
- `detect-multiple-process-models` (string) — detect multiple process models in the project
- `publish-to-results-cloud` (string) — publish results to cloud
- `show-test-case-path` (string) — show test case paths in results

----

Copyright 2026 The MathWorks, Inc.

----
