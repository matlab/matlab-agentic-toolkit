# MATLAB Settings Internals Reference

Key facts, change patterns, and type detection rules for the settings migration workflow.

## Key facts

- The `.hpp` factory settings files at `toolbox/matlab/settings/matlab_factory_settings/` are the AUTHORITATIVE source of all MATLAB settings definitions when available.
- They define every setting name, namespace path, type, default value, and validation.
- **On Windows (and sometimes macOS), `.hpp` files are NOT shipped** — they are compiled into DLLs at `bin/win64/factory_settings/compute/settings/matlab/mwmatlab_factory_settings.dll`. Use `strings` on the DLL to extract setting names, group names, and type validators. This is fast (seconds) and gives equivalent information for diffing purposes.
- **Always try `strings` on the DLL first if `.hpp` is not found.** Do NOT fall back to grepping minified JS bundles as a primary strategy — that approach is orders of magnitude slower and less reliable.
- **String presence in a DLL ≠ setting existence.** A key name appearing in `strings` output does NOT prove the setting still exists as a defined setting. The string may persist as a UI label, panel title, migration code reference, or dead compiled artifact. To confirm existence, verify the key appears in a valid `addSetting` position: it must appear AFTER (below) its parent group name(s) in the binary string sequence. If the key appears in isolation or only near unrelated strings, the setting was removed even though its name string persists.
- **Type and validation information is embedded in the `addSetting` call and its surrounding context** (in hpp) or as nearby strings in the DLL. A setting's type is determined by: (1) the `FactoryValue` literal (e.g., `false` = logical, `charvec("...")` = string, `int32(4)` = integer), (2) the `ValidationFcn` (e.g., `mustBeLogicalScalar`, `mustBeStringScalar`), and (3) any `ValueValidator` struct (look for `ValidStringValues`, `MinValue`, `MaxValue`).
- **A rename is NOT a safe migration if the type changed.** Always extract and compare type info for both old and new when a setting is renamed/moved. The path change is only half the story — the value must also be translated if the type differs.
- The namespace hierarchy is expressed via C++ nested `addGroup`/`addSetting` calls (in hpp) or via adjacent group name strings in the DLL.
- Prefdir `.mlsettings` files only contain USER-MODIFIED settings (not all settings) — do NOT use them for discovery.
- JS panel files in `toolbox/matlab/preferences/` consume settings but don't define the complete list — use them **only as a last resort** to verify functional intent of ambiguous renames. Never scan all JS bundles for all settings.
- Always use `--exclude-dir=release` and `--include="*.js"` when searching JS panels to avoid timeouts on minified bundles.
- Language color settings (e.g., `KeywordColor`, `CommentColor`) under `editor.language.*` rarely change between releases — prioritize checking top-level groups first.
- Users may assign `settings` to ANY variable name. Always detect the variable dynamically from the script content. Do NOT assume `s`.
- `.PersonalValue` is the most common property set, but also watch for `.TemporaryValue`.
- **Legacy aliases in the SO do NOT mean "no migration needed."** When a setting path was reorganized, MATLAB often registers the old path as an alias for backward compatibility. Finding the old dotted path in the new SO's string table means the alias is registered — it does NOT mean the path is unchanged. **Always migrate to the canonical new path.** The alias exists only so old scripts don't error immediately; new code should use the new canonical path.

## Common patterns of settings changes

Each pattern below includes one concrete example so you recognize it in the wild. There are many other settings that follow the same pattern — always verify against the actual target SO/DLL rather than assuming only the example settings are affected.

### 1. SO-internal group (path exists in SO but not at runtime)

The SO/DLL organizes settings into groups that are NOT exposed in the MATLAB `settings()` runtime API. If you reconstruct a path from SO context and it errors at runtime, a group in the path is SO-internal — remove it.

**Example:** The SO shows `editor` → `displaysettings` → `code` → `HighlightCurrentLine`. But the runtime path is `s.matlab.editor.displaysettings.HighlightCurrentLine` — the `code` group is SO-internal and never existed at runtime.

**How to detect:** Run the reconstructed path in MATLAB. If it throws "Unrecognized method, property, or field" for a group name, that group is SO-internal. Remove it and retry. This is the ONLY reliable detection method.

**Important:** When the SO shows a setting under a group that errors at runtime, the setting likely exists under the PARENT group directly. Check one level up before concluding it was removed.

### 2. Path reorganization (namespace moves between releases)

A setting's key stays the same, but the group path changes between releases. The old path may error in the target release.

**Example:** In ≤R2025b, `s.matlab.editor.suggestions.ShowOnTab` exists. In R2026a, that path errors — the setting moved to `s.matlab.suggestions.editor.ShowOnTab`. The reorganization moved the entire `editor.suggestions` subtree to `suggestions.editor`.

**How to detect:** The key exists in the target SO but under a different parent group than the source. Use `grep -B40` on the target SO to find the key's new parent group.

**Release-gating:** Only apply moves that the TARGET install confirms. If a path works in the target, leave it alone — even if a later release moves it.

### 3. Promotion to common (per-context → shared)

A setting that existed separately under multiple contexts (e.g., one for editor, one for command window) merges into a single shared location in the target.

**Example:** Both `editor.suggestions.AcceptOnRightArrow` and `commandwindow.suggestions.AcceptOnRightArrow` exist in ≤R2025b. In R2026a, they merge to a single `suggestions.AcceptOnRightArrow`.

**How to detect:** Key exists in target SO at a HIGHER level (fewer parent groups). The old per-context paths error at runtime.

**Conflict handling:** If the source script sets conflicting values for the two contexts (e.g., `true` for editor, `false` for commandwindow), add a `% REVIEW:` comment noting the conflict.

### 4. Type change on rename

A setting is renamed AND its value type changes. A naive path swap will produce runtime type errors.

**Example:** `editor.spelling.SpellingErrors` (logical: `true`/`false`) was renamed to `editor.spelling.CheckSpelling` (string enum: `"on"`/`"off"`/`"auto"`). Carrying `false` to `CheckSpelling` errors — must translate to `"off"`.

**How to detect:** After finding a rename via SO diff, compare the `FactoryValue` and `ValidationFcn` between old and new. If types differ, value translation is required.

### 5. Broken SO-based path (never worked at runtime)

Some scripts use paths copied from SO/DLL exploration that reflect internal structure but never worked at the MATLAB runtime API. These error in ALL releases, not just the target.

**Example:** `commandwindow.suggestions.ShowTypoSuggestions` appears in the SO under the `suggestions` subgroup of `commandwindow`. But at runtime, `ShowTypoSuggestions` has always been directly under `commandwindow` — the correct path is `s.matlab.commandwindow.ShowTypoSuggestions` in all releases.

**How to detect:** The path errors at runtime in the TARGET install. The key itself exists in the target SO, but not under the group the script uses. Search the target SO for the key name and reconstruct from its actual context.

### 6. Deletion (removed without replacement)

A setting is removed entirely — not renamed, not moved. It does not exist in the target at any path.

**Example:** `editor.displaysettings.EnableNonCEFZoom` was removed in R2026a. It does not appear in any `addSetting` context in the R2026a SO.

**How to detect:** The key name does not appear in any valid `addSetting` position in the target SO/DLL. ONLY then classify as removed and comment out. Never comment out a setting just because the PATH errors — that usually means a move, not removal.

## Common type change patterns in MATLAB settings

When a setting's type changes across releases, these are the typical transitions:

| Old type | New type | Value mapping |
|----------|----------|---------------|
| logical (`true`/`false`) | string enum (`"on"`/`"off"`/`"auto"`) | `false` → `"off"`, `true` → `"on"` |
| numeric (0/1) | logical (`true`/`false`) | `0` → `false`, `1` → `true` |
| numeric (0/1) | string enum | `0` → `"off"`, `1` → `"on"` |
| logical | numeric with range | `false` → `0`, `true` → `1` |
| free string | enum string with `ValidStringValues` | check if old value is in valid set |

**Detecting type from hpp source:**
- `FactoryValue`, `false` or `true` → logical
- `FactoryValue`, `charvec("...")` → string
- `FactoryValue`, integer literal (e.g., `50`, `200`) → numeric
- `FactoryValue`, `int32(N)` → int32
- `ValidationFcn`, `"matlab.settings.mustBeLogicalScalar"` → confirms logical
- `ValidationFcn`, `"matlab.settings.mustBeStringScalar"` → confirms string
- `ValidationFcn`, `"matlab.settings.mustBeNumericScalar"` → confirms numeric
- `ValueValidator` with `ValidStringValues = {u"a", u"b", ...}` → string enum (only these values allowed)
- `ValueValidator` with `MinValue`/`MaxValue` → bounded numeric

## Startup deployment options

When the migrated file is a startup script, offer these three options:

**Option 1 — Replace your startup.m (simplest)**
```
Copy the migrated file to your userpath folder as startup.m:
  copyfile('<output-path>', fullfile(userpath, 'startup.m'))
MATLAB automatically runs startup.m from userpath at launch.
```

**Option 2 — Keep both and switch per-release**
```
Keep release-specific files (startup_R2025b.m, startup_R2026a.m, etc.)
in your cloud-synced folder, and make your actual startup.m a dispatcher:

  % startup.m — in userpath or on the MATLAB path
  v = version('-release');
  releaseFile = fullfile('<cloud-folder>', ['startup_' v '.m']);
  if isfile(releaseFile)
      run(releaseFile);
  else
      warning('No startup preferences file found for %s', v);
  end
```

**Option 3 — Symlink or copy into userpath**
```
On macOS/Linux:
  ln -sf <output-path> "$(matlab -batch "disp(userpath)")/startup.m"

On Windows (run as admin):
  mklink "%USERPROFILE%\Documents\MATLAB\startup.m" "<output-path>"
```

Remind the user:
- `userpath` returns the folder MATLAB searches for startup.m
- They can verify with: `which startup` after restarting MATLAB
- The original file is preserved unchanged at its original location

## Type detection from JS bundles

When type is ambiguous from the DLL alone (common for string enums), batch-grep the relevant JS bundle:

```bash
# JS bundle path pattern (hardcoded — no need to `find`):
# <root>/toolbox/matlab/preferences/<panel>/release/bundle.mwBundle.<panel>-ui.js
#
# Panel mapping by setting group:
#   editor.*          → editorpanels
#   suggestions.*     → suggestionspanel
#   commandwindow.*   → commandwindowpanel
#   figure.*          → figurecopyprefspanel

# Batch grep ALL changed keys from relevant bundle in ONE command:
grep -oP ".{0,200}(ChangedKey1|ChangedKey2|ChangedKey3).{0,200}" \
  "<new-root>/toolbox/matlab/preferences/editorpanels/release/bundle.mwBundle.editorpanels-ui.js"
```

Type indicators in JS bundles:
- `ComboBox` / `SpellingState:{Auto:l,On:"on",Off:"off"}` → string enum, values are the object values
- `CheckboxAttribute` / `.set("checked", ...)` → logical
- `SettingDefaults:{Key:false}` or `{Key:"auto"}` → reveals factory default and type
- `ValidStringValues` or explicit value list → enum members

---

Copyright 2026 The MathWorks, Inc.
