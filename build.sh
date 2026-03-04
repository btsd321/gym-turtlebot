#!/bin/bash
set -e

# Activate virtual environment if present
VENV_DIR="$(cd "$(dirname "$0")" && pwd)/.venv"
if [ -f "$VENV_DIR/bin/activate" ]; then
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
    VENV_PYTHON="$VENV_DIR/bin/python3"
    echo "[build.sh] Using venv: $VENV_PYTHON"
else
    VENV_PYTHON=""
fi

# Set the default build type
BUILD_TYPE=RelWithDebInfo
colcon build \
        --merge-install \
        --symlink-install \
        --cmake-args "-DCMAKE_BUILD_TYPE=$BUILD_TYPE" \
        -Wall -Wextra -Wpedantic

# Patch entry-point shebangs to use venv python so ROS packages
# can import packages installed in the venv (e.g. gymnasium, stable_baselines3)
if [ -n "$VENV_PYTHON" ] && [ -d install/lib ]; then
    echo "[build.sh] Patching Python entry-point shebangs -> $VENV_PYTHON"
    find install/lib -maxdepth 2 -type f -executable | while read -r f; do
        # Only patch files whose first line is a python shebang
        first_line=$(head -1 "$f" 2>/dev/null || true)
        if echo "$first_line" | grep -qE '^#!.*/python'; then
            sed -i "1s|^#!.*python[0-9.]*|#!${VENV_PYTHON}|" "$f"
        fi
    done
    echo "[build.sh] Shebang patching done."
fi
