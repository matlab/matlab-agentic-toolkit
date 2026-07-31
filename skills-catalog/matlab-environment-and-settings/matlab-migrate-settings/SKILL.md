---
name: matlab-migrate-settings
description: Diff MATLAB settings between releases AND update any .m file that configures MATLAB settings to use the correct setting paths for the target release. Use when upgrading MATLAB releases and startup scripts or preference files need path/type updates for the new release.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Settings Migration

Diff MATLAB settings between two releases and automatically update any `.m` file that configures MATLAB settings (via `.PersonalValue` or `.TemporaryValue` assignments) so that setting paths point to the correct locations in the target release. Works with startup scripts, team preference files, test setup scripts, deployment configs, or any code that programmatically sets MATLAB settings.

## When To Use

- Upgrading MATLAB releases and startup scripts need path updates for the new release
- Migrating team preference files or CI configs to a newer MATLAB version
- Settings paths have changed between releases (moved, renamed, type-changed, or removed)
- You need to know what settings changed between two specific MATLAB releases

## When Not To Use

- The script does not use `settings()` API (no `.PersonalValue` or `.TemporaryValue` assignments)
- Both source and target MATLAB releases are not installed on this machine
- You want to change MATLAB preferences via the GUI (use Preferences dialog instead)

## Arguments

- `<script-path>` — **(required)** Path to any `.m` file that sets PersonalValue/TemporaryValue on MATLAB settings
- `[from:R20XXy]` or `[from:/path/to/MATLAB/R20XXy]` — *(optional)* Source release the script was written for. Accepts either a release name (e.g., `R2025b`) which is resolved to the platform default install location, or a full path to a MATLAB installation root. If omitted, auto-detected from script content.
- `[to:R20XXy]` or `[to:/path/to/MATLAB/R20XXy]` — *(optional)* Target release to migrate to. Accepts either a release name or a full path to a MATLAB installation root. If omitted, defaults to the **latest** installed MATLAB release on this machine.

**Examples:**
```
/matlab-settings-migrate ~/startup.m
/matlab-settings-migrate ~/startup.m from:R2025b to:R2026a
/matlab-settings-migrate ~/startup.m to:R2025a
/matlab-settings-migrate ./test/setup_prefs.m from:/opt/matlab/R2025b to:/opt/matlab/R2026a
/matlab-settings-migrate ~/team_settings.m from:/network/apps/MATLAB/R2024b to:R2026a
```

**Default behavior (no from/to):** Detect the source release from the script, then migrate to the newest installed MATLAB release. If you want to migrate to an older release (downgrade), specify `to:` explicitly.

## Argument parsing

Parse the arguments string to extract:
1. The script path (first argument that looks like a file path)
2. Optional `from:` value — either a release name (`R20XXy`) or a full path (`/path/to/MATLAB/R20XXy`)
3. Optional `to:` value — either a release name (`R20XXy`) or a full path (`/path/to/MATLAB/R20XXy`)

**Path resolution:** If the value after `from:` or `to:` starts with `/`, `~`, or a drive letter (e.g., `C:\`), treat it as a full path to a MATLAB installation root. Otherwise, treat it as a release name and resolve it to a full path using the platform-specific default install location (determined in Phase 0).

If only the script path is provided, run Phase 0 (auto-discovery).

## Phase 0: Auto-detect MATLAB installations (skip if both roots provided)

### Step 1: Determine platform

Detect the OS to know where MATLAB installs by default:

```bash
# One command to determine platform
uname -s
```

- `Linux` → default install dir: `/usr/local/MATLAB/`
- `Darwin` → default install dir: `/Applications/`
- Windows (MINGW/CYGWIN/MSYS or if uname unavailable) → default install dir: `C:\Program Files\MATLAB\`

### Step 2: Find all installed releases

```bash
# Linux:
ls -d /usr/local/MATLAB/R20* 2>/dev/null | sort

# macOS:
ls -d /Applications/MATLAB_R20*.app 2>/dev/null | sort

# Windows (from Git Bash / MSYS):
ls -d "/c/Program Files/MATLAB/R20"* 2>/dev/null | sort
```

### Step 3: Identify the source release (what the script was written for)

Determine which installed release the script currently targets. Do this by reading the script (Phase 2, which runs in parallel) and then matching its setting paths against each installed release's factory settings library. The release whose settings match the most paths in the script is the source.

Quick heuristics to try first (cheaper than full matching):
- A comment in the script like `% Written for R2025b` or `% R2025b`
- The filename contains a release hint (e.g., `startup_2025b.m`, `prefs_R2026a.m`)

If heuristics fail, do a quick match: pick one or two setting keys from the script and grep them in each release's factory settings SO/DLL. The release that has ALL of them is the source.

### Step 4: Determine the target release

- **If `to:` was provided:** Resolve that release name to its install path.
- **If `to:` was NOT provided:** Default to the **latest** (chronologically newest) installed release that is NOT the source release. This is the most common case — user just installed a new release and wants to update their script.
- **If only the source release is installed (no other releases):** Ask the user to provide the target path manually.

The release sort order is: `R20XXa` < `R20XXb` (e.g., `R2025a` < `R2025b` < `R2026a`).

**Note:** If the user wants to migrate backward (downgrade), they must specify `to:` explicitly. The default always goes to the latest.

## How to execute

**Performance constraint:** Minimize tool calls. Target ≤4 total bash/read invocations for the entire migration. Batch aggressively — never check settings one-by-one in separate commands. Do NOT diff the entire factory settings library upfront — only look up the specific settings that appear in the user's script.

### Phase 1: Read script + locate factory settings (parallel)

These two operations are independent — run them in a SINGLE parallel tool call:

**Tool call 1:** Read the user's script file (Phase 2 below).

**Tool call 2:** Locate factory settings source and extract strings for ONLY the settings in the script. Determine the format:

```bash
# Check for hpp source first
OLD_HPP=<old-matlab-root>/toolbox/matlab/settings/matlab_factory_settings
NEW_HPP=<new-matlab-root>/toolbox/matlab/settings/matlab_factory_settings
ls "$NEW_HPP"/*.hpp 2>/dev/null | head -3
```

If `.hpp` files exist → use HPP path. Otherwise locate the SO/DLL:
```bash
# Linux: .so | macOS: .dylib | Windows: .dll
find "<matlab-root>/bin" -path "*factory_settings*" -name "mwmatlab_factory_settings.*" 2>/dev/null
```

### Phase 2: Parse the user's script

#### Step 1: Read the script and identify all settings references

Read `<script-path>` and find every line that references a setting path. Users may use ANY variable name for the settings root — not just `s`. Common patterns:

```matlab
% Pattern 1: Direct assignment
s.matlab.editor.spelling.CheckSpelling.PersonalValue = false;

% Pattern 2: Different variable name
settings_root.matlab.editor.spelling.CheckSpelling.PersonalValue = false;
mySettings.matlab.editor.SaveFilesOnClickAway.PersonalValue = false;

% Pattern 3: Variable obtained from matlab.settings.SettingsGroup
prefs = settings;
prefs.matlab.editor.spelling.CheckSpelling.PersonalValue = false;

% Pattern 4: Inside try-catch (common for cross-release compatibility)
try
    s.matlab.editor.spelling.SpellingErrors.PersonalValue = false;
catch
    try
        s.matlab.editor.spelling.CheckSpelling.PersonalValue = false;
    catch
    end
end

% Pattern 5: Conditional on version
if isMATLABReleaseOlderThan("R2026a")
    s.matlab.editor.spelling.SpellingErrors.PersonalValue = false;
else
    s.matlab.editor.spelling.CheckSpelling.PersonalValue = "off";
end
```

**Detection strategy:**
1. Find the settings variable: look for `= settings;` or `= matlab.settings.SettingsGroup` or any variable used with `.matlab.` followed by known setting paths.
2. Extract the variable name (everything before `.matlab.`).
3. Extract the full setting path (everything between the variable and `.PersonalValue`, `.TemporaryValue`, or `.FactoryValue`).

Build a list of `(line_number, variable_name, full_setting_path, assigned_value)` tuples.

### Phase 3: Look up ONLY the script's settings in the target (ONE batch command)

**This is the critical correctness gate.** For every unique setting key from the script, determine its status in the target release. Do this in ONE batch command — not one-by-one.

**HPP path (preferred — fast and definitive):**
```bash
# Batch-verify ALL keys AND get their group context in ONE command:
for key in Key1 Key2 Key3 ...; do
  echo "=== $key ==="
  echo "  TARGET:"; grep -r -B5 "addSetting(\"$key\"" "$NEW_HPP"/ || echo "  NOT FOUND"
  echo "  SOURCE:"; grep -r -B5 "addSetting(\"$key\"" "$OLD_HPP"/ || echo "  NOT FOUND"
done
```

**SO/DLL path (when hpp unavailable):**
```bash
OLD_SO="<path-to-old-so>"
NEW_SO="<path-to-new-so>"

# ALL keys in ONE command — check existence + group context in both releases
for key in Key1 Key2 Key3 ...; do
  echo "=== $key ==="
  echo "  TARGET context:"; strings "$NEW_SO" | grep -B40 -A5 "^${key}$" || echo "  NOT FOUND"
  echo "  SOURCE context:"; strings "$OLD_SO" | grep -B40 -A5 "^${key}$" || echo "  NOT FOUND"
done
```

**IMPORTANT:** The SO/DLL stores group names and key names as *separate adjacent strings*, NOT concatenated dotted paths. Group names are **lowercase** (`liveeditor`, `suggestions`, `spelling`). Setting keys are **CamelCase** (`ShowAutomatically`, `CheckSpelling`). The IMMEDIATE parent group is the last lowercase name that appears BEFORE the key in the string sequence.

**How to read the context and reconstruct paths:**
- The `-B40` context shows all group names above the setting key
- Build the path by chaining group names in order: `matlab.<group1>.<group2>.<KeyName>`
- Compare source path vs target path — if different, the setting MOVED
- If the key is NOT FOUND in target → check if there's a renamed replacement (look at sibling settings in the same group from the source; one may have been renamed)

#### Step 2: Classify each setting

| Situation | Action |
|-----------|--------|
| Key in target at SAME path as script | **Unchanged** — no action |
| Key in target at DIFFERENT path | **Moved** — update path |
| Key NOT in target, sibling group has new key | **Renamed** — update key name, check for type change |
| Key NOT in target, no plausible match | **Removed** — comment out |

**Key rule:** Finding the key in the target is necessary but NOT sufficient to classify as "Unchanged." You must also confirm the FULL PATH matches. A key can exist in both releases but under a different parent group.

**IMPORTANT — Only change what the TARGET install tells you to change.** Do NOT apply transformations based on general knowledge about MATLAB release history. Every change must be justified by what you observe in the target SO/DLL/hpp. If a path exists and works in the target install, leave it alone — even if you "know" it changed in a later release.

**For moved/renamed settings — check type change:** Extract `FactoryValue` and `ValidationFcn` from the target. If the type differs from source (e.g., logical → string enum), you must translate the value. See `references/settings-internals.md` § "Common type change patterns."


### Phase 4: Write the migrated script

#### Step 3: Determine output file path

**CRITICAL: Never overwrite the original file.** Always write to a NEW file. Derive the output path automatically:
- Same directory as the original file
- Append the target release name before the extension
- If input is `startup.m` → write to `startup_R2026a.m` (same folder)
- If input is `my_prefs.m` → write to `my_prefs_R2026a.m` (same folder)
- If input is `test/setup_settings.m` → write to `test/setup_settings_R2026a.m`
- If the user provided a 4th argument as an explicit output path, use that instead

Do NOT ask the user for confirmation — just create the new file. The original is never touched.

#### Step 4: Apply transformations

For each setting that needs updating:

1. **Simple rename/move (same type)**: Replace the old path with the new path in-place, keeping the original value.
   ```matlab
   % Before (logical → logical, no type change):
   s.matlab.editor.displaysettings.OldName.PersonalValue = true;
   % After:
   s.matlab.editor.displaysettings.NewName.PersonalValue = true;
   ```

1b. **Rename/move with type change**: Replace the path AND translate the value to match the new type. Add a comment showing the original value for auditability.
   ```matlab
   % Before (logical → string enum {"auto","on","off"}):
   s.matlab.editor.spelling.SpellingErrors.PersonalValue = false;
   % After:
   s.matlab.editor.spelling.CheckSpelling.PersonalValue = "off";  % was: false (type changed logical→string)
   ```

   Value translation rules:
   - `false` → `"off"` when ValidStringValues contains "off"
   - `true` → `"on"` when ValidStringValues contains "on"
   - `0` (numeric used as logical) → `"off"` or `false` depending on new type
   - `1` (numeric used as logical) → `"on"` or `true` depending on new type
   - If the mapping is ambiguous (e.g., factory default is `"auto"` and user had `true`), flag it with a `% REVIEW:` comment explaining the options so the user can choose

2. **Try-catch blocks referencing old paths**: If the script already has nested try-catch for the same setting, collapse them into a single assignment with the new path (remove the try-catch if only one path is needed for the target release). If the user wants cross-release compatibility, keep a try-catch with new path first, old path as fallback:
   ```matlab
   try
       s.matlab.editor.spelling.CheckSpelling.PersonalValue = false;
   catch
       s.matlab.editor.spelling.SpellingErrors.PersonalValue = false;
   end
   ```

3. **Version-conditional blocks**: Update the condition and paths:
   ```matlab
   if isMATLABReleaseOlderThan("R2026a")
       s.matlab.old.path.Setting.PersonalValue = value;
   else
       s.matlab.new.path.Setting.PersonalValue = value;
   end
   ```

4. **Removed settings OR settings not found in target release**: Comment out with explanation. This includes settings that were explicitly removed AND settings whose key cannot be found in any factory settings SO/DLL or JS bundle in the target release (internal/undocumented settings that were dropped). Never leave an unverified setting active — it will error at runtime.
   ```matlab
   % REMOVED in <new-release>: s.matlab.X.Y.Z no longer exists
   % s.matlab.X.Y.Z.PersonalValue = false;
   ```
   Also comment out any associated `fprintf`/`disp` line for that setting.

5. **Promoted/merged settings**: When two settings from different contexts (e.g., one for editor, one for command window) merge into a single shared setting in the target, output ONE assignment. If both had the same value, use that value. If they differed, add a `% REVIEW:` comment noting the conflict and use the value that was `true` (enabling is safer than silently disabling).

#### Step 5: Preserve user intent

- Keep all fprintf/disp statements that document what each setting does
- Keep the user's chosen variable name (don't rename `prefs` to `s`)
- **If the setting still exists in the target (same key name), KEEP that setting name.** Translate the value to match the new type (e.g., `false` → `"off"` or `"0"`). Do NOT substitute a different setting — even if another setting seems semantically related. The user's script sets `LiveEditorInteractiveOutputs`, so the output must set `LiveEditorInteractiveOutputs` (at its new path, with type-translated value).
- If you cannot determine the equivalent value with confidence, add a `% REVIEW:` comment with the available options.
- Keep comment blocks and section separators
- If a setting was split into multiple settings in the new release, add all new settings with appropriate values and add a comment explaining the split. If the split settings have different types, translate each independently.

#### Step 6: Runtime validation of the output file (MANDATORY)

**This is the PRIMARY correctness mechanism.** Run the output file in the target MATLAB to confirm zero runtime errors. Use `mcp__matlab__evaluate_matlab_code` if available; otherwise fall back to `"<target-matlab-root>/bin/matlab" -batch "run('<output-file>')"` via Bash.

If MATLAB reports errors:
1. For **path errors** ("Unrecognized method, property, or field"): the reconstructed path is wrong. This usually means:
   - An SO-internal group is in the path (a group that exists in the SO for organizational purposes but is not exposed in the runtime API). Remove the suspect group level and retry.
   - The setting moved to a different parent. Search the target SO for the key name again, check broader context (`grep -B60`), and try alternative parent groups.
   - Do NOT comment it out — a runtime path error means you reconstructed wrong, not that the setting was removed.
2. For **type errors** ("invalid value"): the type changed. Query `s.<path>.ValidStringValues` in MATLAB to get accepted values, then translate.
3. For **missing group errors** (add-on settings like `copilot`): wrap in try-catch.
4. Fix the output file and re-run until MATLAB reports zero errors.

**NEVER comment out a setting just because its path errors at runtime.** A runtime path error means the setting MOVED or the path was reconstructed incorrectly — it was NOT removed. Only classify as "removed" if the key name does not exist anywhere in the target SO/DLL. Runtime validation is mandatory and must not be skipped.

#### Step 7: Report changes and provide setup instructions

After writing the migrated file, present:

**A) Migration summary:**

```
## Migration Summary: <input-file> → <output-file>

### Updated (N settings)
- s.matlab.old.Path → s.matlab.new.Path (line 42)
- s.matlab.old.Path → s.matlab.new.Path (line 55) ⚠️ TYPE CHANGED: logical → string {"auto","on","off"}, value translated: false → "off"
- ...

### Already correct (N settings)
- s.matlab.editor.SaveFilesOnClickAway (line 15)
- ...

### Removed — requires manual review (N settings)
- s.matlab.X.Y.Z (line 67) — commented out
- ...

### Needs manual review — ambiguous type mapping (N settings)
- s.matlab.X.Y.Z (line 72) — old value `true` could map to "on" or "auto" (factory default is "auto")
- ...

### New settings available (not in your script)
- s.matlab.new.Setting — type: string, default: "auto"
- ...
```

**B) Setup instructions (only if the file appears to be a startup script):**

If the file is named `startup.m` or appears to be a startup/preferences script, provide deployment options. See `references/settings-internals.md` § "Startup deployment options" for the three options (replace, per-release dispatcher, symlink).

If the file is NOT a startup script, skip setup instructions and just report the output file path.

## Key facts, change patterns, and type detection

See `references/settings-internals.md` for the full reference on factory settings file locations, type/validation extraction from `addSetting` blocks, legacy aliases, common change patterns (rename, reorganization, split, promotion, deletion, type change), type change mapping rules, and type detection from hpp source or DLL strings.

---

Copyright 2026 The MathWorks, Inc.
