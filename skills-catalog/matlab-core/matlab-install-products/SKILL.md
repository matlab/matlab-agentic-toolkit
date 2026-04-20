---
name: matlab-install-products
description: "Deterministic workflow to download MATLAB Package Manager (mpm) and install MathWorks products from the OS command line with consistent, repeatable behavior. Use when installing MATLAB, Simulink, toolboxes, or support packages via command line, or setting up scripted installations for CI/CD, containers, or fleet provisioning."
license: "MathWorks BSD-3-Clause"
metadata:
  author: MathWorks
  version: "1.0"
---

# Installing MATLAB Products with MATLAB Package Manager (mpm) - Deterministic Protocol

Use this skill when asked to install MathWorks products using MATLAB Package Manager (mpm) from the OS command line.

$ARGUMENTS

## When to Use

- User asks to install MATLAB, Simulink, toolboxes, or support packages via the command line
- User wants a scripted, repeatable MATLAB installation (CI/CD, containers, fleet provisioning)
- User asks about mpm, MATLAB Package Manager, or non-interactive MATLAB installs
- User needs to add products to an existing MATLAB installation using mpm

## When NOT to Use

- User wants to install via the graphical MATLAB installer or MathWorks website
- User is asking about MATLAB licensing or activation (separate workflow)
- User wants to manage MATLAB Add-Ons from within MATLAB (use the Add-On Manager)
- User needs to install MATLAB Engine API for Python, Java, or C++ (different process)

## Non-Negotiable Determinism Contract (follow exactly)
- Follow the steps in **Protocol** in order. Do not add extra steps or checks.
- Use **only** the canonical shell for the OS. Do not switch shells.
- Use **absolute paths** to `mpm` / `mpm.exe`. Never rely on relative paths.
- Retry downloads at most **once**. Otherwise stop and report the error.
- If security software blocks execution: **stop** and instruct escalation. Do not bypass.

## Safety Gate (Windows) — MANDATORY, NO EXCEPTIONS

**STOP. Read this entire section before executing ANY Windows step.**

1. **NEVER** use `powershell.exe -Command` for ANY reason. Bash mangles `$`, backticks, quotes, arrays, and script blocks before PowerShell sees them. This WILL cause `unexpected EOF` or syntax errors.
2. **NEVER** use bash heredoc syntax (`cat > file <<'EOF'`) or bash redirection (`echo ... >`) to create PowerShell scripts.
3. **ALWAYS** write `.ps1` files using the **Write file tool**, then invoke with:
   `powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File <absolute-script-path>`
4. Do not emit CMD-only syntax (`if not exist`, `set VAR=`, `%USERPROFILE%`). Use PowerShell equivalents (`Test-Path`, `$env:USERPROFILE`).

5. **ASCII only** in all `.ps1` file content. No em dashes (`—`), en dashes (`–`), curly quotes, or other non-ASCII characters. They cause PowerShell parse errors (broken string terminators, missing brace errors) when file encoding doesn't preserve them.

**If you are about to type `powershell.exe -Command` — STOP. You are violating this rule. Use the Write file tool to create a .ps1 file instead.**

Windows script authoring pattern:
- **WRONG**: `powershell.exe -Command "$script = @'...`  (bash corrupts `$` and heredocs)
- **WRONG**: `cat > C:/Windows/Temp/script.ps1 <<'PS1' ... PS1`  (bash heredoc, breaks on Windows)
- **CORRECT**: create a unique temp folder, use the **Write file tool** to write `.ps1` files into it, then run with `-File`

Unique temp folder:
- Before Step 1, create a timestamped working folder using the Bash tool:
  - Windows: `mkdir -p "C:/Users/<username>/AppData/Local/Temp/mpm-<YYYYMMDD-HHMMSS>"`
  - Linux/macOS: `mkdir -p "/tmp/mpm-<YYYYMMDD-HHMMSS>"`
- Use this folder for ALL generated scripts and input files throughout the protocol
- Because the folder is new, the Write file tool can always create files in it without needing to delete anything first
- Delete the entire folder during the final cleanup step

Windows PowerShell syntax reminders:
- Bad: `if not exist C:\Users\name\Downloads mkdir C:\Users\name\Downloads` (CMD syntax)
- Good: `if (-not (Test-Path -LiteralPath 'C:\Users\name\Downloads')) { New-Item -ItemType Directory -Path 'C:\Users\name\Downloads' | Out-Null }`

Do not ask the user for the exact product name or identifier. Look it up using the appropriate mpm input file from https://github.com/mathworks-ref-arch/matlab-dockerfile/tree/main/mpm-input-files
Do not ask the user whether to install dependencies or not. mpm will take care of it. Just install whatever the user asked for, and let mpm do the rest.
If a user types the shortname of MATLAB releases, automatically use the correct expanded full name. e.g. 25a is R2025a, 25b is R2025b

## Required Inputs (ask only if missing)
1. Operating system (Windows, Linux, macOS)
2. MATLAB release (for example `R2025b`)
3. Installation destination (absolute path)
4. Requested products / toolboxes / support packages

## Confirmation Rule
Before executing any steps, always confirm the user's choices:
- Release
- Destination folder
- Products
- Support packages

Ask for confirmation in one message. The user can reply `yes to all` to confirm everything at once. If they reply with specific changes, update the selections and confirm again.
Display each value to be confirmed in its own new line.
Note at the bottom of the confirmation message: "Required dependencies will be installed automatically by mpm."

## Plan Display (after confirmation, before execution)

Once the user confirms their inputs, display a clear installation plan before running any commands. Adapt the template below for the target OS (use forward slashes and `/tmp/` for Linux/macOS, omit `.ps1` script references, and omit the UAC note). Use this format:

```
Here's what I'll do:

Working folder: <C:\Users\<username>\AppData\Local\Temp\mpm-YYYYMMDD-HHMMSS>

Step 1 — Download mpm
  Check for mpm at <canonical mpm path>
  Download from <URL> if not present
  Script: <working folder>\mpm_download.ps1

Step 2 — Prepare input file
  Download release template for <release> from GitHub
  Set destination folder: <destination>
  Enable products: <comma-separated list>
  Input file: <working folder>\mpm_input_<releaselower>.txt
  Script: <working folder>\mpm_prepare_input.ps1

Step 3 — Run installation
  Execute mpm install using the prepared input file
  <Windows only: note that elevated permissions (UAC prompt) will be required>

Step 4 — Verify
  Confirm installation by checking for: <completion artifact path>
  Delete working folder: <working folder>
```

Resolve all environment variables and shell-specific paths to absolute paths before displaying. Generate the timestamp for the working folder name at plan display time so it is fixed for the entire session.
Do not start Step 1 until the user acknowledges the plan (a simple "ok", "go", "yes", or similar is enough).

Official documentation:
- Get mpm: https://www.mathworks.com/help/install/ug/get-mpm-os-command-line.html
- mpm install: https://www.mathworks.com/help/install/ug/mpminstall.html

## Execution Style

> **Important:** When executing steps, do not narrate or explain what you are about to do. Just run the commands and report results concisely (success, failure, or error). Reserve commentary for confirmations, the plan display, and error reporting only.

## Canonical Shell (used throughout the Protocol)
- **Windows**: Windows PowerShell (`powershell.exe`)
- **Linux**: `bash` / `sh`
- **macOS**: `zsh` or `bash` (Apple silicon only; Intel Mac is not supported — stop and inform the user)

## Pre-Execution Checklist (verify before EVERY Windows step)

Before running any command in Steps 1–3 on Windows, confirm:
- [ ] The PowerShell script was written using the **Write file tool** (not `-Command`, not heredoc, not `echo`)
- [ ] The script is invoked with `powershell.exe ... -File <path>` (not `-Command`)
- [ ] No PowerShell code appears inline in any `bash` command

If any check fails, STOP and rewrite using the Write file tool.

## Protocol (exactly 4 steps)

### Step 1 - Ensure mpm exists at canonical path

Canonical locations (resolve to absolute paths before use):
- Windows: `<user home>\Downloads\mpm.exe`
- Linux: `<user home>/Downloads/mpm`
- macOS: `<user home>/Downloads/mpm`

If the file exists at that path, reuse it. Otherwise download from:
- Windows: https://www.mathworks.com/mpm/win64/mpm
- Linux: https://www.mathworks.com/mpm/glnxa64/mpm
- macOS: https://www.mathworks.com/mpm/maca64/mpm

#### Windows (PowerShell)

**MANDATORY: Use the Write file tool to create this script. NEVER use -Command or heredoc.**

1. Create the working folder with the Bash tool (use the timestamp fixed at plan display time):

```bash
mkdir -p "C:/Users/<username>/AppData/Local/Temp/mpm-YYYYMMDD-HHMMSS"
```

2. Use the **Write file tool** to write the following content to `<working folder>\mpm_download.ps1`:

```powershell
param(
  [Parameter(Mandatory = $true)]
  [string]$Destination
)
if (Test-Path -LiteralPath $Destination) {
  Write-Host "mpm already present at $Destination"
} else {
  Write-Host "Downloading mpm from https://www.mathworks.com/mpm/win64/mpm - this may take a few minutes..."
  Invoke-WebRequest -Uri "https://www.mathworks.com/mpm/win64/mpm" -OutFile $Destination -UseBasicParsing
  if (-not (Test-Path -LiteralPath $Destination)) { throw "mpm download failed: $Destination" }
  Write-Host "mpm downloaded to $Destination"
}
```

3. Run it:

```bash
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<working folder>\mpm_download.ps1" -Destination "C:\Users\<username>\Downloads\mpm.exe"
```

#### Linux/macOS

See `reference/linux-macos-steps.md` for full shell scripts. Summary: create working folder at `/tmp/mpm-YYYYMMDD-HHMMSS`, download mpm with `curl -fL -o` to `~/Downloads/mpm`, and `chmod +x`.

### Step 2 - Download and edit the release input file

Always use a release template input file from:
https://github.com/mathworks-ref-arch/matlab-dockerfile/tree/main/mpm-input-files

Download the template input file for the requested release, then edit it:
- Uncomment and set `destinationFolder` to the requested installation path.
- Uncomment each `product.<Name>` line for requested products and support packages.
- Add `noJRE=true` to the input file (on its own line, after `destinationFolder`). This prevents mpm from bundling a Java Runtime. Only omit this line if the user explicitly requests JRE installation.
- Leave `updateLevel` commented unless the user requests a specific update.
- Do not edit the checksum line (`?checksum=...`).

After editing the file, verify:
- The input file exists at the expected path.
- `destinationFolder` matches the user-requested install path exactly.
- Each requested `product.<Name>` line is uncommented (no leading `#`).
- Non-requested products remain commented out.

If any verification fails, stop and retry the download once, then re-edit and re-verify.
If it still fails, stop and report the error.

The input file format uses `product.<Name>` entries for both products and support packages.
You must look up the exact `product.<Name>` identifiers in the release input file.
Product identifiers use underscores for spaces (e.g. "Signal Processing Toolbox" -> `product.Signal_Processing_Toolbox`).

- Always display the full path to the ps1 script that was generated

#### Windows (PowerShell)

**MANDATORY: Use the Write file tool to create this script. NEVER use -Command or heredoc.**

1. Use the **Write file tool** to write the following content to `<working folder>\mpm_prepare_input.ps1`:

```powershell
param(
  [Parameter(Mandatory = $true)]
  [string]$Release,
  [Parameter(Mandatory = $true)]
  [string]$Destination,
  [Parameter(Mandatory = $true)]
  [string]$WorkingFolder,
  [Parameter(Mandatory = $true)]
  [string]$Products
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -File mode passes "a,b" as one string; split into an array
$ProductList = $Products -split ',' | ForEach-Object { $_.Trim() }

$releaseLower = $Release.ToLower()
$inputUrl  = "https://raw.githubusercontent.com/mathworks-ref-arch/matlab-dockerfile/refs/heads/main/mpm-input-files/$Release/mpm_input_${releaseLower}.txt"
$inputFile = Join-Path $WorkingFolder "mpm_input_${releaseLower}.txt"

Write-Host "Downloading input file from $inputUrl..."
Invoke-WebRequest -Uri $inputUrl -OutFile $inputFile -UseBasicParsing
if (-not (Test-Path -LiteralPath $inputFile)) {
  throw "Input file was not downloaded: $inputFile"
}

$lines = Get-Content -LiteralPath $inputFile

$lines = $lines | ForEach-Object {
  if ($_ -match '^\s*#?\s*destinationFolder=') {
    "destinationFolder=$Destination"
    "noJRE=true"
  }
  else {
    $_
  }
}

foreach ($product in $ProductList) {
  $escaped = [Regex]::Escape($product)
  $lines = $lines | ForEach-Object {
    if ($_ -match "^\s*#\s*$escaped\s*$") {
      $product
    }
    else {
      $_
    }
  }
}

Set-Content -LiteralPath $inputFile -Value $lines -Encoding UTF8

$lines = Get-Content -LiteralPath $inputFile

$destinationLine = $lines | Where-Object { $_ -match '^destinationFolder=' } | Select-Object -First 1
if (-not $destinationLine) { throw "destinationFolder line not found in $inputFile" }
if ($destinationLine -ne "destinationFolder=$Destination") { throw "destinationFolder mismatch: $destinationLine" }

$uncommentedProducts = $lines | Where-Object { $_ -match '^\s*product\.' }
$unexpectedProducts  = $uncommentedProducts | Where-Object { $ProductList -notcontains $_ }
if ($unexpectedProducts) { throw "Unrequested products enabled: $($unexpectedProducts -join ', ')" }

foreach ($product in $ProductList) {
  if (-not ($lines -contains $product)) { throw "Requested product not enabled: $product" }
}

Write-Host "Input file ready: $inputFile"
```

Note: the script writes the input file to `<working folder>\mpm_input_<releaselower>.txt`, so cleanup of the working folder deletes it automatically. The input file path will be reported by the script on completion.

2. Run it (substitute actual working folder, release, destination, and product identifiers):

```bash
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<working folder>\mpm_prepare_input.ps1" -Release "R2025b" -Destination "C:\MATLAB\R2025b" -WorkingFolder "<working folder>" -Products "product.MATLAB,product.Simulink"
```

#### Linux/macOS

See `reference/linux-macos-steps.md` for the full shell script. Summary: download the release input file with `curl`, edit with `sed` to set `destinationFolder` and uncomment requested products, then verify all edits.

- Do not delete generated files yet; cleanup happens after Step 3.

### Step 3 - Run the install command and completion check

**IMPORTANT:**
- When using `--inputfile`, do not pass any other mpm options.
- Windows requires elevation. Use `Start-Process -Verb RunAs` for elevated execution.
- Always display the fully expanded command before running it.
- Substitute actual values for release, working folder, and destination in the snippets below.

#### Windows

**MANDATORY: Use the Write file tool to create a .ps1 script for this step. NEVER use -Command or heredoc. Then invoke with `powershell.exe ... -File <path>`.**

Write the following to `<working folder>\mpm_install.ps1` using the **Write file tool**, then run with `-File`:

```powershell
param(
  [Parameter(Mandatory = $true)]
  [string]$MpmPath,
  [Parameter(Mandatory = $true)]
  [string]$InputFile
)

$installArgs = @(
  "install",
  "--inputfile=$InputFile"
)

$display = '"' + $MpmPath + '" install ' + ('--inputfile="' + $InputFile + '"')
Write-Host "Running: $display"

Start-Process -FilePath $MpmPath -ArgumentList $installArgs -Verb RunAs -Wait
```

Run it:

```bash
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<working folder>\mpm_install.ps1" -MpmPath "C:\Users\<username>\Downloads\mpm.exe" -InputFile "<working folder>\mpm_input_<releaselower>.txt"
```

#### Linux/macOS

See `reference/linux-macos-steps.md`. Summary: run `mpm install --inputfile=<path>` directly (no elevation needed).

### Step 4 - Verification

This step defines **completion**. It is mandatory.
Wait until the mpm process has exited. Do not proceed until it is done.
If the completion artifact exists, the installation is complete. **STOP. Do not re-run Step 3.**
On successful completion of Step 3, delete the entire working folder and its contents using the Bash tool:

```bash
rm -rf "C:/Users/<username>/AppData/Local/Temp/mpm-YYYYMMDD-HHMMSS"
```
If the artifact does not exist, stop and report failure.

Completion artifacts (use the destination folder you set in the input file):
- **Windows**: `<DESTINATION>\bin\matlab.exe`
- **Linux**: `<DESTINATION>/bin/matlab`
- **macOS**: `<DESTINATION>/Contents/MacOS/MATLAB`

Use the Bash tool with `test -f` to check existence. Do **not** use `powershell.exe -Command` for this check.

```bash
test -f "<DESTINATION>/bin/matlab.exe" && echo "VERIFIED" || echo "NOT FOUND"
```

## Common Errors

- **`ErrorCode::IncompatibleProduct`** ("Selected products are incompatible"): The destination folder most likely contains an existing MATLAB installation. Inform the user and ask them to choose an empty destination folder.

## Key Functions and Patterns

| Command / Pattern | Purpose |
|---|---|
| `mpm install --inputfile=<file>` | Install products defined in an input file |
| `mpm_input_<release>.txt` | Release-specific input file template from GitHub |
| `product.<Name>` | Input file entry format for products and support packages |
| `destinationFolder=<path>` | Input file directive setting the install location |
| `Start-Process -Verb RunAs -Wait` | Elevated execution on Windows (UAC) |
| `Invoke-WebRequest -OutFile` | Download files in PowerShell |
| `curl -fL -o` | Download files on Linux/macOS |

## Notes
- mpm installs required dependencies automatically.
- Licensing and activation are separate workflows. Do not ask the user about licensing or activation at the end of the install.
- Always use a release input file from:
  https://github.com/mathworks-ref-arch/matlab-dockerfile/tree/main/mpm-input-files

----

Copyright 2026 The MathWorks, Inc.

----

