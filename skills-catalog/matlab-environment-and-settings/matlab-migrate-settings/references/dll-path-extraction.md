# Step 2B: DLL path (compiled binary — Windows/macOS/Linux without source)

When `.hpp` source files are not available, extract setting names and type information directly from the compiled factory settings library using `strings`.

## Extract full string tables from both releases

```bash
OLD_DLL="<old-matlab-root>/bin/win64/factory_settings/compute/settings/matlab/mwmatlab_factory_settings.dll"
NEW_DLL="<new-matlab-root>/bin/win64/factory_settings/compute/settings/matlab/mwmatlab_factory_settings.dll"

# Extract all readable strings (setting names, group names, type info, validators)
strings "$OLD_DLL" | sort -u > /tmp/settings_old.txt
strings "$NEW_DLL" | sort -u > /tmp/settings_new.txt
```

## Identify changes via diff

```bash
# Strings only in OLD (removed or renamed away)
comm -23 /tmp/settings_old.txt /tmp/settings_new.txt > /tmp/settings_removed.txt
# Strings only in NEW (added or renamed to)
comm -13 /tmp/settings_old.txt /tmp/settings_new.txt > /tmp/settings_added.txt
```

## Verify all script settings AND dump group context in ONE batch command

**IMPORTANT:** The SO/DLL stores group names and key names as *separate adjacent strings*, NOT concatenated dotted paths. For example, you'll find the string `spelling` followed by `SpellingErrors` on a nearby line — not `matlab.editor.spelling.SpellingErrors`. The only full dotted paths stored in the SO are alias registrations (e.g., `matlab.commandwindow.suggestions.ShowAutomatically`). Do NOT grep for full dotted paths — they mostly won't exist and it wastes a round-trip.

Combine the key existence check AND group context dump into a single bash command for ALL settings from the startup script:

```bash
# ALL checks in ONE command — keys + group context for every setting
for setting in Key1 Key2 Key3 ...; do
  echo "=== $setting ==="
  echo -n "  OLD: "; grep -w "$setting" /tmp/settings_old.txt || echo "(missing)"
  echo -n "  NEW: "; grep -w "$setting" /tmp/settings_new.txt || echo "(missing)"
  echo "  OLD context:"; strings "$OLD_DLL" | grep -B40 -A5 "^${setting}$" || echo "    (none)"
  echo "  NEW context:"; strings "$NEW_DLL" | grep -B40 -A5 "^${setting}$" || echo "    (none)"
done

# Also check any full dotted alias paths that ARE known to exist in the SO:
for path in "matlab.commandwindow.suggestions.ShowAutomatically" ...; do
  echo "=== $path (alias) ==="; grep "$path" /tmp/settings_old.txt; grep "$path" /tmp/settings_new.txt
done
```

The group context (`grep -B40 -A5`) is the primary tool: the parent group name appears a few lines BEFORE the setting key. This gives you renames, moves, and splits all from one output — no separate investigation step needed. Use `-B40` (not less) because subgroups may have many sibling settings between the parent group name and the sub-group, pushing the parent group name far above.

**CRITICAL: Reconstruct the runtime settings path from the SO/DLL context.** Use `grep -B40` to see all group names above a setting key. However, the SO binary layout does NOT always match the MATLAB runtime API path — internal/organizational groups (like `guide`) may appear in the SO hierarchy but NOT in the runtime path.

**Rule: use only the IMMEDIATE parent group** (the last lowercase name directly above the setting key). For example, the SO shows `guide` → `liveeditor` → `LiveEditorInteractiveOutputs`, but the runtime path is `matlab.liveeditor.LiveEditorInteractiveOutputs` (no `guide`). Do NOT include higher-level internal groups.

**How to identify groups in SO/DLL string output:**
- Group names are **lowercase** (e.g., `liveeditor`, `addons`, `explorer`, `suggestions`)
- Setting keys are **CamelCase** (e.g., `LayoutActivate`, `LiveEditorInteractiveOutputs`)
- The IMMEDIATE parent group is the last lowercase name that appears BEFORE the setting key in the string sequence

**String presence ≠ setting existence.** When a key appears in NEW context, confirm it is in a valid setting-definition position: it must appear AFTER its parent group name(s) in the string sequence, with the same positional pattern as other confirmed settings in that group. If the key appears in isolation (no parent group nearby) or only adjacent to unrelated strings (UI labels, panel names), classify as **Removed**. Settings can disappear as definitions while their name string persists in the binary for other purposes.

## Determine renames from the batch output

From the combined output above, apply this decision tree:

| Situation | How to identify |
|-----------|----------------|
| Key exists in both AND full path confirmed via `addSetting` context in NEW | **Unchanged** — no action |
| Key string exists in both but NOT confirmed as an `addSetting` in the new context (appears only as UI label, dead string, or in unrelated context) | **Removed** — treat as deleted. The string persists in the binary but the setting definition is gone. |
| Key missing in new, same group has a new key | **Rename** — old group's context in NEW shows the replacement |
| Key exists in both but different parent group | **Path move** — context shows the new parent |
| Both old dotted alias AND new dotted alias exist in SO | **Path move with legacy alias** — MUST migrate to the new canonical path. The alias only exists for backward compat; always update the script to use the new path. |
| Key missing, group has multiple new keys | **Split** — one setting became several |
| Key missing, no plausible match anywhere | **Removed** |

**Before classifying as "Removed":** Search the entire target SO/DLL for partial key name matches. Renames can move across groups (not just siblings). For example, if `InterfacesBlacklist` is missing, grep for `Interfaces` — you might find `InterfacesBlocklist` under a different group. Only classify as "Removed" after exhausting rename searches.

The "string presence ≠ setting existence" rule applies here: if the key exists in `strings` output but is NOT in valid `addSetting` position relative to its expected parent group, classify as **Removed**.

## Extract type information for ALL changed settings in ONE batch

Once you know which settings changed, determine their types. Do this in ONE command:

```bash
# Validators from the new DLL
strings "$NEW_DLL" | grep "mustBe"

# Batch type check: for each changed key, get extended context that may show type info
for setting in ChangedKey1 ChangedKey2 ...; do
  echo "=== TYPE: $setting ==="; strings "$NEW_DLL" | grep -B5 -A15 "^${setting}$"
done
```

When a setting changes from logical to string, the `-A15` context will often show candidate values. Look for strings like `on`, `off`, `auto`, `all` appearing after the setting key. For example, `CheckSpelling` shows `on`, `off`, `auto` in its context.

**Strings near a key are a hint, not a constraint.** Adjacent strings in the binary are not proof that the setting only accepts those values — the SO interleaves unrelated literals, and many settings are unconstrained (any string-convertible value is accepted). Do not assume an enum from proximity alone.

**Confirm the accepted values in the target release before translating.** A read-only check in the target MATLAB is authoritative and costs one round-trip:

```matlab
s = settings;
o = s.matlab.<group>.<Key>;
class(o.FactoryValue)     % char/string => string-valued; logical => keep true/false
o.FactoryValue            % the shipped default
```

Then verify a candidate translation is actually accepted, restoring state afterward:

```matlab
o.TemporaryValue = "off";  % errors if the value is rejected
o.clearTemporaryValue;     % always clear — never leave a TemporaryValue set
```

If the target value is accepted and the class is `char`/`string`, translate `true`/`false` to the release's own vocabulary. If the class is `logical`, keep the boolean — do **not** convert it to `"on"`/`"off"`.

If type is still ambiguous from the DLL alone, batch-grep the relevant JS bundle. See `references/settings-internals.md` § "Type detection from JS bundles" for panel mapping and type indicators.

If a setting isn't found in the main DLL, check additional DLLs:
```bash
find "<matlab-root>/bin" -path "*factory_settings*" -name "*.dll" 2>/dev/null
```

---

Copyright 2026 The MathWorks, Inc.
