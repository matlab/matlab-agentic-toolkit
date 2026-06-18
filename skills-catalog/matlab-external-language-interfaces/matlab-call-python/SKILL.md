---
name: matlab-call-python
description: >
  Call Python libraries from MATLAB using the py. interface, pyrun,
  pyrunfile, or pyenv. Use when writing or executing MATLAB code that
  calls Python functions or passes data between MATLAB and Python.
  REQUIRED when triaging Python errors from MATLAB (ModuleNotFoundError,
  ImportError, "Unable to resolve the name 'py.*'"). REQUIRED when
  setting up Python environments for MATLAB, creating virtual
  environments, or installing Python packages for use with MATLAB.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Call Python from MATLAB

Call Python libraries from MATLAB using modern APIs, correct environment setup,
and structured error recovery.

## When to Use

- Writing MATLAB code that calls Python via `py.*`, `pyrun`, or `pyrunfile`
- MATLAB code fails with `ModuleNotFoundError`, `Python is not configured`, or
  other Python-related errors
- User asks to set up Python for MATLAB or create a virtual environment
- User asks to install a Python package for use in MATLAB

## When NOT to Use

- Calling MATLAB from Python (MATLAB Engine API for Python — different direction)
- Building MEX files or Python C extensions
- Pure Python development with no MATLAB involvement
- MATLAB Compiler or MATLAB Production Server deployment

## Rules

### NEVER use `pyargs`

Use MATLAB name=value syntax for Python keyword arguments. `pyargs` is outdated
(name=value available since R2021a).

```matlab
% TEMPLATE — not executable (requires scikit-learn)
rfc = py.sklearn.ensemble.RandomForestClassifier(n_estimators=int32(100), random_state=int32(42));
```

### NEVER use `pyversion`

`pyversion` is not recommended. Use `pyenv`, which supports `terminate`, `ExecutionMode`,
and environment switching.

### ALWAYS use the Bash tool for pip installs and venv creation

Do not use MATLAB `system()`. The Bash tool provides streaming output and avoids
complex string escaping.

### ALWAYS follow recovery procedure before any pip install or venv creation

BEFORE running pip install or creating virtual environments, follow
`references/environment-setup.md`. Do NOT infer Python paths from error
tracebacks — those paths show importlib internals, not the correct install
target.

### ALWAYS ask user confirmation before calling terminate(pyenv)

`terminate(pyenv)` restarts the Python process and clears all Python state
(imported modules, variables, open connections). Always inform the user what
will be lost and get explicit consent before calling terminate.

### ALWAYS wrap with integer types when Python expects int

MATLAB passes double by default. Python functions expecting int receive float,
causing TypeError. Use `int32()` for counts, indices, and size arguments. If the
value won't fit in 32 bits, use `int64()` or `uint64()` to prevent overflow.

### ALWAYS use `pystringarray` for string arrays (R2026a or later)

When passing MATLAB string arrays to Python in R2026a or later, use
`pystringarray`. Requires NumPy 2.0 or later. In R2025b and earlier, or when
NumPy < 2.0, use `py.list(cellstr(...))`.

```matlab
% R2026a and later:
names = ["Alice", "Bob", "Charlie"];
pyNames = pystringarray(names);

% R2025b and earlier:
names = ["Alice", "Bob", "Charlie"];
pyNames = py.list(cellstr(names));
```

## Workflow

When calling Python from MATLAB, follow this workflow.

### 1. Write the Python code using modern syntax

```matlab
result = py.module.function(arg1, arg2, kwarg1="value", kwarg2=42);
```

Prefer `py.module.function(...)` for direct function calls — it's readable,
integrates with the MATLAB workspace, and supports tab completion. Reserve
`pyrun` for multi-statement scripts where variables and imports persist in
Python memory across calls (REPL-like execution). Reserve `pyrunfile` for
running a standalone `.py` file (equivalent to running from the command line;
no state carries over).

### 2. Run the code

Execute via `mcp__matlab__evaluate_matlab_code` (for inline code) or
`mcp__matlab__run_matlab_file` (for script files).

### 3. If it succeeds — done

### 4. If it fails with a Python error — triage

Follow `references/environment-setup.md` ONLY for environment-related errors:

1. `ModuleNotFoundError`
2. MATLAB error about unresolved `py.*` name (e.g., "Unable to resolve the name
   'py.numpy'")
3. `pyenv().Executable` is empty
4. `py` or `pyenv` calls error stating environment is not supported
5. Any other error suggesting a missing library or unconfigured environment

For all other Python errors (ValueError, TypeError, logic errors in the Python
code itself) — debug the code directly. These are code bugs, not environment
issues.

## Key Functions

| Function | Purpose | Available From |
|----------|---------|----------------|
| `pyenv` | Query/configure Python environment | R2019b |
| `pyrun` | Execute Python statements; variables persist across calls | R2021b |
| `pyrunfile` | Execute a standalone `.py` file | R2021b |
| `pystringarray` | Pass MATLAB string array to Python | R2026a |

## InProcess vs OutOfProcess

- **OutOfProcess**: Launches Python in a separate process. Mitigates third-party
  library conflicts between MATLAB and Python, therefore works with most Python
  packages without conflict. `terminate(pyenv)` restarts Python without restarting
  MATLAB. Can switch environments freely.
- **InProcess**: (default) Launches Python within the same MATLAB process. PREFER
  for better performance. Cannot terminate. If Python is already loaded in
  InProcess mode, the user must restart MATLAB entirely to change Python
  configuration.

In `ExecutionMode="OutOfProcess"`, when working on a custom Python module and you
need to make changes after loading the module, or when you install packages
mid-session, ALWAYS call `terminate(pyenv)` before calling the module again.

In `ExecutionMode="InProcess"`, when working on a custom Python module and you
need to make changes after loading the module, ALWAYS reload the module by running:

```matlab
clear all;
clear classes;
mod = py.importlib.import_module("<module_name>");
py.importlib.reload(mod);
```

## Patterns

### Calling a Python function with keyword arguments

```matlab
rfc = py.sklearn.ensemble.RandomForestClassifier(n_estimators=int32(100), random_state=int32(42));
rfc.fit(XTrain, yTrain);
predictions = double(rfc.predict(XTest));
```

### Configuring MATLAB to use a virtual environment

After creating a virtual environment (`venv`) using the Bash tool, point MATLAB at it:

```matlab
% Terminate current Python if loaded
terminate(pyenv);

% Point at venv executable
pyenv(Version="/path/to/.venv/Scripts/python.exe");

% Verify
disp(pyenv().Executable);
py.numpy.array([1, 2, 3]);
```

## Conventions

- When a keyword argument name conflicts with a MATLAB variable, append `Val`
  (e.g., `py.complex(imag=imagVal)` not `py.complex(imag=imag)`)
- AVOID "activating" a virtual environment — MATLAB doesn't use activation
  scripts. Point `pyenv(Version=...)` at the venv executable directly.

----

Copyright 2026 The MathWorks, Inc.

----
