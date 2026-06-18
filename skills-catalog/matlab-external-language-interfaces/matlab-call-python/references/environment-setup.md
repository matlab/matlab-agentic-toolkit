# Python Environment Recovery

Loaded when SKILL.md Step 4 triage identifies an environment-related error.

## Recovery Steps

### Step 1: Query pyenv

```matlab
pe = pyenv;
disp(pe.Executable)
```

Use `pe.Executable` as the Python path for ALL subsequent commands. Do NOT use
paths from error tracebacks (see Reference: Traceback Trap).

- If `pe.Executable` is empty or pyenv throws an error about an unsupported
  version → Step 2
- Otherwise → Step 3

### Step 2: Help user install Python

Python is not configured or the configured version is unsupported.

- Check the MATLAB version connected via MCP and look up the latest supported
  Python version for that release
- Guide the user to install from python.org (see Reference: Windows Store Python
  for what to avoid)
- After install, have user configure pyenv and return to Step 1

### Step 3: Ask permission and branch

- Offer: "Install `<package>` to the Python at `<pe.Executable>`?"
  - Yes → Step 5
  - No → MUST offer the alternative: "Would you like me to create a virtual
    environment instead?"
    - Yes → Step 4
    - No → stop, provide the manual pip install command for reference

### Step 4: Create venv and configure pyenv

- Create venv via Bash tool
- OS-specific executable: Windows → `Scripts/pythonw.exe`; Unix → `bin/python`
- Before reconfiguring pyenv, check execution state (see SKILL.md: InProcess
  vs OutOfProcess):
  - OutOfProcess + Loaded → ask permission to run `terminate(pyenv)`, then
    reconfigure
  - InProcess + Loaded → tell user: must restart MATLAB to change Python
- `pyenv(Version="<venv-exe>", ExecutionMode="OutOfProcess")`

### Step 5: Install and verify

```bash
"<pe.Executable>" -m pip install <package>
"<pe.Executable>" -m pip show <package>
```

If `pip show` confirms the package:
- If Python was already loaded in this session (`pyenv` shows Status = "Loaded"),
  follow the reload procedure in SKILL.md (see: InProcess vs OutOfProcess)
- Re-run the original code

---

## Reference

### Traceback Trap

When `ModuleNotFoundError` occurs, the traceback shows paths like:

```
C:\Users\...\AppData\Local\Programs\Python\Python312\Lib\importlib\__init__.py
```

This is the base Python's standard library path — NOT the correct install target.
On Windows, venvs share the base Python's stdlib, so tracebacks always reference
the base install location. The correct Python is ONLY available from
`pyenv().Executable`.

### Windows Store Python

Windows Store Python (path contains `WindowsApps` or `Microsoft\WindowsApps`) is
not compatible with MATLAB. MATLAB's Python interface relies on loading the Python
runtime (shared library) directly into the MATLAB process or Python host process.
The Windows Store Python uses a sandboxed packaging model that prevents external
applications from loading its shared library. This is a known limitation that also
affects other tools relying on embedding Python.

When guiding users to install Python in Step 2, direct them to python.org or a
compatible distribution that provides a standard shared library — never the
Windows Store.

----

Copyright 2026 The MathWorks, Inc.

----
