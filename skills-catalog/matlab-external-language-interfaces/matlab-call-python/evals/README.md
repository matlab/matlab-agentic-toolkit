# Evals: matlab-call-python

## Eval 2: Traceback Trap Fixture

Eval 2 (`recover-missing-package-traceback-trap`) requires a controlled fixture
to create the path-mismatch scenario that traps agents.

### How the trap works

When a Python venv is created from a base Python (e.g.,
`AppData/Local/Programs/Python/Python312/python.exe`), the venv shares the base
Python's standard library. A `ModuleNotFoundError` traceback will reference the
base Python's importlib path — not the venv's path. Agents that extract the
Python path from the traceback will install to the wrong location.

### Setup (before running eval 2)

```bash
# 1. Create eval venv from base Python
bash evals/scripts/setup_eval_venv.sh \
  "C:/Users/<username>/AppData/Local/Programs/Python/Python312/python.exe" \
  "<workspace>/sandbox/eval-venv"
```

Then in MATLAB (or via MCP):
```matlab
% 2. Save current pyenv
originalPython = pyenv().Executable;

% 3. Point MATLAB at the eval venv
terminate(pyenv);
pyenv(Version="<workspace>/sandbox/eval-venv/Scripts/python.exe", ExecutionMode="OutOfProcess");
```

### Teardown (after eval 2 completes)

In MATLAB:
```matlab
% 1. Restore original Python
terminate(pyenv);
pyenv(Version=originalPython, ExecutionMode="OutOfProcess");
```

Then:
```bash
# 2. Delete eval venv
bash evals/scripts/teardown_eval_venv.sh "<workspace>/sandbox/eval-venv"
```

### Expected behavior

- **With skill:** Agent queries `pyenv().Executable` first, gets the venv path,
  installs there via Bash tool.
- **Without skill:** Agent sees `AppData\Local\Programs\Python\Python312` in the
  traceback and attempts to install there first (wrong target).

----

Copyright 2026 The MathWorks, Inc.

----
