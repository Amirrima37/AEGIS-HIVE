#!/usr/bin/env bash
# ==============================================================================
# Project: Aegis-Hive — Universal Linux Launcher & Compatibility Wrapper
# Supports both:
#   1) Exported Linux builds (aegis-hive.x86_64 + aegis-hive.pck)
#   2) Direct execution from cloned GitHub source repository (via system Godot)
# ==============================================================================
set -e

# Resolve script directory (follows symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

BIN_NAME="aegis-hive.x86_64"
EXEC_PATH="$SCRIPT_DIR/$BIN_NAME"

# Parse arguments and provide compatibility fallbacks
EXTRA_ARGS=()
RUN_TESTS=0
for arg in "$@"; do
    case "$arg" in
        --gl|--opengl)
            echo "[INFO] Starting Aegis-Hive in OpenGL 3 (Compatibility) mode..."
            EXTRA_ARGS+=(--rendering-driver opengl3)
            ;;
        --wayland)
            echo "[INFO] Starting Aegis-Hive in native Wayland mode..."
            EXTRA_ARGS+=(--display-driver wayland)
            ;;
        --x11)
            echo "[INFO] Starting Aegis-Hive in X11 / XWayland mode..."
            EXTRA_ARGS+=(--display-driver x11)
            ;;
        --test|--run-tests)
            echo "[INFO] Running headless test runner suite..."
            RUN_TESTS=1
            EXTRA_ARGS+=(--headless "res://tests/test_runner.tscn")
            ;;
        *)
            EXTRA_ARGS+=("$arg")
            ;;
    esac
done

# Mode 1: Exported standalone binary is present next to this script
if [ -f "$EXEC_PATH" ]; then
    if [ ! -x "$EXEC_PATH" ]; then
        chmod +x "$EXEC_PATH" 2>/dev/null || true
    fi
    cd "$SCRIPT_DIR"
    exec "$EXEC_PATH" "${EXTRA_ARGS[@]}"
fi

# Mode 2: Running directly from a cloned GitHub source repository
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -f "$REPO_ROOT/project.godot" ]; then
    GODOT_CMD=""
    if command -v godot4 >/dev/null 2>&1; then
        GODOT_CMD="godot4"
    elif command -v godot >/dev/null 2>&1; then
        GODOT_CMD="godot"
    elif command -v flatpak >/dev/null 2>&1 && flatpak info org.godotengine.Godot >/dev/null 2>&1; then
        GODOT_CMD="flatpak run org.godotengine.Godot"
    fi

    if [ -n "$GODOT_CMD" ]; then
        echo "[INFO] Launching Project: Aegis-Hive from source using '$GODOT_CMD'..."
        cd "$REPO_ROOT"

        # Import project resources if .godot/ cache does not exist yet (e.g. fresh git clone)
        if [ ! -d "$REPO_ROOT/.godot/imported" ]; then
            echo "[INFO] First-time setup: importing assets into .godot/ cache..."
            $GODOT_CMD --path "$REPO_ROOT" --headless --import
        fi

        if [ "$RUN_TESTS" -eq 1 ]; then
            exec $GODOT_CMD --path "$REPO_ROOT" "${EXTRA_ARGS[@]}"
        else
            exec $GODOT_CMD --path "$REPO_ROOT" "${EXTRA_ARGS[@]}"
        fi
    else
        echo "[ERROR] Neither exported binary ($BIN_NAME) nor Godot 4 executable was found!" >&2
        echo "" >&2
        echo "To play on Linux without installing Godot:" >&2
        echo "  Download the pre-built 'aegis-hive-linux-x86_64.tar.gz' from GitHub Releases / Actions." >&2
        echo "" >&2
        echo "To run directly from source:" >&2
        echo "  Install Godot 4.7.2+ (or 'flatpak install flathub org.godotengine.Godot') and re-run this script." >&2
        exit 1
    fi
fi

echo "[ERROR] Could not find $BIN_NAME or project.godot!" >&2
exit 1
