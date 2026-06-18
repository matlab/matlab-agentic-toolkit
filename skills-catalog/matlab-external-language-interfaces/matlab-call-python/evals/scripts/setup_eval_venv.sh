#!/usr/bin/env bash
# Setup: Create a fresh venv from base Python for eval-2b (traceback trap).
# The venv has no packages beyond stdlib, so importing numpy will fail.
# The error traceback will reference the base Python path (the trap),
# while pyenv().Executable points to the venv (the correct target).
#
# Usage: bash setup_eval_venv.sh <base-python-exe> <venv-path>
# Example: bash setup_eval_venv.sh \
#   "C:/Users/<username>/AppData/Local/Programs/Python/Python312/python.exe" \
#   "C:/Users/<username>/Documents/.../sandbox/eval-venv"
#
# Copyright 2026 The MathWorks, Inc.

set -e

BASE_PYTHON="${1:?Usage: setup_eval_venv.sh <base-python-exe> <venv-path>}"
VENV_PATH="${2:?Usage: setup_eval_venv.sh <base-python-exe> <venv-path>}"

if [ -d "$VENV_PATH" ]; then
    echo "Removing existing eval venv at: $VENV_PATH"
    rm -rf "$VENV_PATH"
fi

echo "Creating eval venv from: $BASE_PYTHON"
"$BASE_PYTHON" -m venv "$VENV_PATH"

echo "Eval venv created at: $VENV_PATH"
echo "Venv Python: $VENV_PATH/Scripts/python.exe"
echo ""
echo "Next: In MATLAB, run:"
echo "  terminate(pyenv);"
echo "  pyenv(Version=\"$VENV_PATH/Scripts/python.exe\", ExecutionMode=\"OutOfProcess\");"
