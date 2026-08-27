---
name: matlab-migrate-settings
description: Diff MATLAB settings between releases AND update any .m file that configures MATLAB settings to use the correct setting paths for the target release. Use when upgrading MATLAB releases and startup scripts or preference files need path/type updates for the new release.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  version: "1.1"
---

# MATLAB Settings Migration

Diff MATLAB settings between two releases and automatically update any `.m` file that configures MATLAB settings (via `.PersonalValue` or `.TemporaryValue` assignments) so that setting paths point to the correct locations in the target release. Works with startup scripts, team preference files, test setup scripts, deployment configs, or any code that programmatically sets MATLAB settings.

## When To Use

- Upgrading MATLAB releases and existing `.m` scripts set `PersonalValue` or `TemporaryValue` on settings whose paths changed between releases
- Setting paths moved, were renamed, or had their value types changed between the source and target release
- Migrating startup scripts, team preference files, test setup, or deployment configs to a newer (or older) MATLAB release

## When Not To Use

- The `.m` file does not set any MATLAB settings (`s.PersonalValue` / `s.TemporaryValue` assignments)
- You want to change MATLAB preferences interactively (use the Preferences dialog instead)
- You need to migrate Simulink or toolbox-specific settings (this skill covers core MATLAB settings only)

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

If `from:` or `to:` are missing, auto-detect installed MATLAB releases. Read `references/auto-detect-installations.md` for the full procedure (platform detection, folder scanning, source/target resolution). Key behavior:
- Detect platform via `uname -s` → determines default install directory
- List installed releases by scanning the default directory for `R20*` folders
- Source release: detected from script content (filename hints, comments, or key matching against SO/DLLs)
- Target release: defaults to the latest installed release (unless `to:` was explicit)
- Downgrade requires explicit `to:` — default always goes to the latest

## How to execute

**Performance constraint:** Minimize tool calls. Target ≤6 total bash/read invocations for the entire migration. Batch aggressively — never check settings one-by-one in separate commands. Phase 1 setup (find libs, extract strings, diff) and Phase 2 (read startup script) are independent and MUST run in parallel.

### Phase 1: Build the settings change map

Produce the full change map (renamed, moved, removed, added) between releases.

#### Step 1: Validate paths and determine source format

Check for `.hpp` source files first (available on some Linux installs):
```
OLD_HPP=<old-matlab-root>/toolbox/matlab/settings/matlab_factory_settings
NEW_HPP=<new-matlab-root>/toolbox/matlab/settings/matlab_factory_settings
```

If `.hpp` files exist in both, use the **HPP path** (Step 2A).
If `.hpp` files do NOT exist (common on Windows where they are compiled to DLLs), use the **DLL path** (Step 2B).

To locate the shared library (extension depends on platform detected in Phase 0):
```bash
# Linux: .so | macOS: .dylib | Windows: .dll
find "<matlab-root>/bin" -path "*factory_settings*" -name "mwmatlab_factory_settings.*" 2>/dev/null
# Typical paths:
#   Linux:   <root>/bin/glnxa64/factory_settings/compute/settings/matlab/mwmatlab_factory_settings.so
#   macOS:   <root>/bin/maci64/factory_settings/compute/settings/matlab/mwmatlab_factory_settings.dylib
#   Windows: <root>/bin/win64/factory_settings/compute/settings/matlab/mwmatlab_factory_settings.dll
```

#### Step 2A: HPP path (plain-text source available)

##### File-level diff

Compare which `.hpp` files exist in each release:
```bash
ls "$OLD_HPP"/*.hpp | xargs -I{} basename {} | sort > /tmp/hpp_old.txt
ls "$NEW_HPP"/*.hpp | xargs -I{} basename {} | sort > /tmp/hpp_new.txt
comm -23 /tmp/hpp_old.txt /tmp/hpp_new.txt   # files only in OLD (removed)
comm -13 /tmp/hpp_old.txt /tmp/hpp_new.txt   # files only in NEW (added)
```

For any NEWLY added `.hpp` file, read it and list all settings it defines.
For any REMOVED `.hpp` file, read it from OLD and list all settings.

##### Extract all setting names with namespace context

For EACH `.hpp` file that exists in BOTH releases, extract `addSetting` and `addGroup` lines:
```bash
grep -n "addSetting\|addGroup" "$OLD_HPP/factorysettings_XXXX.hpp"
grep -n "addSetting\|addGroup" "$NEW_HPP/factorysettings_XXXX.hpp"
```

The group hierarchy gives you the full setting path:
- `matlabFactoryGroup.addGroup("editor")` → `matlab.editor`
- `editor.addGroup("spelling")` → `matlab.editor.spelling`
- `spelling.addSetting("CheckSpelling")` → `matlab.editor.spelling.CheckSpelling`

##### Diff setting names within each file

For each shared `.hpp` file:
1. Identify settings REMOVED (in old, not in new)
2. Identify settings ADDED (in new, not in old)
3. For removed+added pairs in the same namespace, determine if it's a RENAME (same group, different key name) vs. truly removed/added

##### Extract type and validation for changed settings

For every setting that is renamed, moved, or split, extract the **full `addSetting` block** (not just the name line) from BOTH releases — capture `FactoryValue`, `ValidationFcn`, and any `ValueValidator`:

```bash
grep -B 5 -A 8 'spelling.addSetting("CheckSpelling"' "$NEW_HPP/factorysettings_editor.hpp"
```

See `references/settings-internals.md` for reading types from these fields and for the type-transition mapping rules (same type, type changed, type narrowed). Confirm the result against the target runtime before translating a value — `class(o.FactoryValue)` is authoritative where the hpp is ambiguous.

##### Classify and determine moves

For settings that appear removed from one file and added to another file, classify as MOVED.

##### Optional — verify renames via JS panel source

If a rename is ambiguous from hpp alone, confirm by reading the JS panel source files.

#### Step 2B: DLL path (compiled binary — Windows/macOS/Linux without source)

When `.hpp` source files are not available, extract setting names and type information directly from the compiled factory settings library using `strings`. Read `references/dll-path-extraction.md` for the full procedure — it covers string table extraction, batch context verification, rename classification decision tree, and type extraction. Key principles:

- SO/DLL stores group names and key names as **separate adjacent strings**, NOT dotted paths — do NOT grep full paths
- Use `grep -B40 -A5` for group context; the IMMEDIATE parent group (last lowercase name above the key) gives the runtime path
- **String presence ≠ setting existence** — confirm keys are in valid `addSetting` position, not just present as dead strings
- Before classifying as "Removed", search the entire target SO/DLL for partial key name matches (renames can cross groups)
- For type changes, use `-A15` context to find `ValidStringValues` — never stringify boolean literals

### Phase 2: Parse the user's script

#### Step 7: Read the script and identify all settings references

Read `<script-path>` and find every line that references a setting path. Users may use ANY variable name for the settings root — not just `s`. Common patterns:

1. **Direct assignment** — `s.matlab.editor.spelling.CheckSpelling.PersonalValue = false;`
2. **Any variable name** — `prefs`, `mySettings`, `settings_root`, etc.
3. **Variable from `settings`** — `prefs = settings;` then `prefs.matlab...`
4. **Inside try-catch** — nested fallbacks for cross-release compatibility; migrate every branch
5. **Version-conditional** — `if isMATLABReleaseOlderThan("R2026a") ... else ... end`; migrate both branches

**Detection strategy:**
1. Find the settings variable: look for `= settings;` or `= matlab.settings.SettingsGroup` or any variable used with `.matlab.` followed by known setting paths.
2. Extract the variable name (everything before `.matlab.`).
3. Extract the full setting path (everything between the variable and `.PersonalValue`, `.TemporaryValue`, or `.FactoryValue`).

Build a list of `(line_number, variable_name, full_setting_path, assigned_value)` tuples.

#### Step 8: Positively verify EACH script setting in the target release

**This is the critical correctness gate.** Do NOT rely solely on the diff/change map from Phase 1. For EVERY setting key extracted from the user's script, positively confirm it exists in the target release by grepping the target's hpp files or DLL.

**HPP path (preferred — fast and definitive):**
```bash
# Batch-verify ALL keys from the script in ONE command against target hpp files:
for key in Key1 Key2 Key3 ...; do
  echo "=== $key ==="; grep -r "addSetting(\"$key\"" "$NEW_HPP"/ || echo "NOT FOUND"
done
```

If `addSetting("KeyName")` is NOT found in any target hpp file, the setting does NOT exist in the target — regardless of what the Phase 1 diff said.

**DLL path (when hpp unavailable):** Use the `addSetting` context verification from Phase 1 Step 2B — the key must appear in valid definition position below its parent group.

**Runtime confirmation (authoritative — required before classifying anything as Removed).** Grep proves only that a *string* is present; `hasSetting` proves a setting is defined at a given path. Batch it over the script's keys:

```matlab
s = settings;
s.matlab.<group>.hasSetting('<Key>')   % 1 = exists here, 0 = not here
```

#### Step 9: Classify each setting based on verification results

For each setting from the user's script, classify using BOTH the Phase 1 change map AND the Step 8 verification:

1. **Unchanged** — key found via `addSetting` in target at the same full path → no action
2. **Renamed** — key NOT found at old path, but Phase 1 change map identifies a rename → update key name
3. **Moved** — key found in target but under a different parent group → update full path
4. **Removed with no replacement** — key NOT found in target via Step 8, `hasSetting` returns 0 for every candidate group from the search below, AND no rename/move identified in Phase 1 → comment out
5. **Already uses new path** — key confirmed at same path → no action
6. **Not found in target release** — cannot confirm existence via `addSetting` grep AND the `hasSetting` search below is exhausted → treat as Removed, comment out. Do NOT leave it active — an unrecognized setting will error at runtime.

**A vanished intermediate group does NOT mean the setting was removed** — this is the most common failure in this skill. When a subgroup is retired the key usually survives one level up. Before classifying as Removed, run `hasSetting` on each candidate: the group with the subgroup dropped (`a.b.suggestions.Key` → test `a.b`), the parent's siblings, then the renamed key. "Removed" is correct only after all return 0.

Example: `commandwindow.suggestions.ShowTypoSuggestions` into R2025b+. The `suggestions` subgroup is gone, so the old path errors — but `s.matlab.commandwindow.hasSetting('ShowTypoSuggestions')` returns 1. Rewrite the path and keep the original logical value; commenting it out silently drops a preference the user still has.


### Phase 3: Update the script

#### Step 10: Determine output file path

**CRITICAL: Never overwrite the original file.** Always write to a NEW file. Derive the output path automatically:
- Same directory as the original file
- Append the target release name before the extension
- If input is `startup.m` → write to `startup_R2026a.m` (same folder)
- If input is `my_prefs.m` → write to `my_prefs_R2026a.m` (same folder)
- If input is `test/setup_settings.m` → write to `test/setup_settings_R2026a.m`
- If the user provided a 4th argument as an explicit output path, use that instead

Do NOT ask the user for confirmation — just create the new file. The original is never touched.

#### Step 11: Apply transformations

For each setting that needs updating:

1. **Simple rename/move (same type)**: Replace the old path with the new path in-place, keeping the original value.
   ```matlab
   % Before (logical → logical, no type change):
   s.matlab.editor.displaysettings.OldName.PersonalValue = true;
   % After:
   s.matlab.editor.displaysettings.NewName.PersonalValue = true;
   ```

1b. **Rename/move with type change**: Replace the path AND translate the value to match the new type. You MUST use the allowed values discovered from the target DLL/hpp `ValidStringValues` (Phase 1 Step 6). Add a comment showing the original value for auditability.
   ```matlab
   % Before (logical → string enum {"auto","on","off"}):
   s.matlab.editor.spelling.SpellingErrors.PersonalValue = false;
   % After (ValidStringValues shows {"on","off","auto"}, so false maps to "off"):
   s.matlab.editor.spelling.CheckSpelling.PersonalValue = "off";  % was: false (type changed logical→string)
   ```

   Value translation rules when type changes from logical to string:
   - MUST look up the `ValidStringValues` for the setting in the target DLL/hpp (Phase 1 Step 6). The `-A15` context around the setting key in `strings` output shows the allowed values.
   - Map `true` to the "enabled" value (typically `"on"`) and `false` to the "disabled" value (typically `"off"`) based on what `ValidStringValues` contains.
   - `0` (numeric used as logical) → `"off"` or `false` depending on new type
   - `1` (numeric used as logical) → `"on"` or `true` depending on new type
   - Never guess the string value from the boolean literal — `"false"`, `"0"`, `'0'` are never valid setting values. Always use the actual allowed values from the target binary.
   - If the mapping is ambiguous (e.g., factory default is `"auto"` and user had `true`), flag it with a `% REVIEW:` comment explaining the options so the user can choose

2. **Try-catch blocks referencing old paths**: If the script already has nested try-catch for the same setting, collapse them into a single assignment with the new path (remove the try-catch if only one path is needed for the target release). If the user wants cross-release compatibility, keep a try-catch with new path first, old path as fallback:
   ```matlab
   try
       s.matlab.editor.spelling.CheckSpelling.PersonalValue = false;
   catch
       s.matlab.editor.spelling.SpellingErrors.PersonalValue = false;
   end
   ```

3. **Version-conditional blocks**: Update the condition and the paths in **both** branches.

4. **Removed settings OR settings not found in target release**: Comment out with explanation — both settings explicitly removed and those whose key cannot be found anywhere in the target release. Never leave an unverified setting active; it will error at runtime.
   ```matlab
   % REMOVED in <new-release>: s.matlab.X.Y.Z no longer exists
   % s.matlab.X.Y.Z.PersonalValue = false;
   ```
   Also comment out any associated `fprintf`/`disp` line.

   **First confirm the key is absent from every candidate group** via the Step 9 `hasSetting` search. If found, this is a **Moved** setting — rewrite the path instead. Never justify a comment-out with "the group no longer exists"; that says nothing about the key.

#### Step 12: Preserve user intent

- Keep all fprintf/disp statements that document what each setting does
- Keep the user's chosen variable name (don't rename `prefs` to `s`)
- **If the setting still exists in the target (same key name), KEEP that setting name.** Do NOT substitute a different setting — even if another setting seems semantically related. The user's script sets `LiveEditorInteractiveOutputs`, so the output must set `LiveEditorInteractiveOutputs` (at its new path).
- **Only translate the value if the type actually changed.** Check `class(o.FactoryValue)` in the target (Phase 1 Step 2B). If it is still `logical`, keep `true`/`false` — converting to `"on"`/`"off"` errors at runtime. Translate to a string only when the target type is `char`/`string`.
- If you cannot determine the equivalent value with confidence, add a `% REVIEW:` comment with the available options.
- Keep comment blocks and section separators
- If a setting was split into multiple settings in the new release, add all new settings with appropriate values and add a comment explaining the split. If the split settings have different types, translate each independently.

#### Step 12b: Runtime validation of the output file (MANDATORY)

**Run the output file in the target MATLAB** to confirm zero runtime errors. Use `mcp__matlab__evaluate_matlab_code` if available; otherwise fall back to `"<target-matlab-root>/bin/matlab" -batch "run('<output-file>')"` via Bash.

If MATLAB reports errors:
1. For **path errors** ("Unrecognized method, property, or field"): the setting MOVED — do NOT comment it out. Find the correct new path: search the target SO for the key name, check its surrounding group context, and reconstruct the full path. Verify the new path with another MATLAB call.
2. For **type errors** ("invalid value"): the type changed. Query `s.<path>.ValidStringValues` in MATLAB to get accepted values, then translate.
3. For **missing group errors** (add-on settings like `copilot`): wrap in try-catch.
4. Fix the output file and re-run until MATLAB reports zero errors.

**NEVER comment out a setting just because its path errors at runtime.** A runtime path error means the setting MOVED (to a new intermediate group or restructured path) — it was NOT removed. Only classify as "removed" if the key name does not exist anywhere in the target SO/DLL. Runtime validation is mandatory and must not be skipped.

#### Step 13: Report changes and provide setup instructions

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
