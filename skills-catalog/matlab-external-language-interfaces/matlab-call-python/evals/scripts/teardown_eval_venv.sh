#!/usr/bin/env bash
# Teardown: Restore original pyenv and delete the eval venv.
#
# Usage: bash teardown_eval_venv.sh <venv-path>
#
# Note: Before running this, restore pyenv in MATLAB:
#   terminate(pyenv);
#   pyenv(Version="<original-python>", ExecutionMode="OutOfProcess");
#
# Copyright 2026 The MathWorks, Inc.

set -e

VENV_PATH="${1:?Usage: teardown_eval_venv.sh <venv-path>}"

if [ -d "$VENV_PATH" ]; then
    echo "Removing eval venv: $VENV_PATH"
    rm -rf "$VENV_PATH"
    echo "Done."
else
    echo "Venv not found at: $VENV_PATH (already cleaned?)"
fi
