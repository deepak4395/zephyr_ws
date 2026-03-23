#!/usr/bin/env sh
# setup.sh — Idempotent Zephyr multi-project setup. Safe to run multiple times.
#
# Usage:
#   sh scripts/setup.sh                        # Interactive: choose project
#   sh scripts/setup.sh native_project         # Non-interactive: use native_project
#   sh scripts/setup.sh native_project_2       # Non-interactive: use native_project_2
#   sh scripts/setup.sh pico_led_blink         # Non-interactive: use pico_led_blink
#
# What it does (each step is skipped if already done):
#   1. Creates venv at <repo>/venv if absent
#   2. Installs / upgrades west inside the venv
#   3. Sets up west workspace using the chosen project's manifest
#   4. Installs Zephyr Python build requirements
#   5. Prints build + run commands

# Do NOT use set -e: we guard every step explicitly so a re-run after a
# partial failure recovers cleanly rather than aborting at the first issue.
set -u

# ── helpers ─────────────────────────────────────────────────────────────────
info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'WARN: %s\n' "$*" >&2; }
die()   { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok()    { printf '    OK: %s\n' "$*"; }

detect_board() {
    case "$1" in
        esp32*)  echo "esp32_devkitc_wroom" ;;
        pico*)   echo "rpi_pico" ;;
        native*) echo "native_posix_64" ;;
        *)       echo "native_posix_64" ;;
    esac
}

# ── repo / venv paths ────────────────────────────────────────────────────────
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VENV_DIR="$REPO_ROOT/venv"

# ── project selection ────────────────────────────────────────────────────────
PROJECT=${1:-}

if [ -z "$PROJECT" ]; then
    # Interactive: discover and list available projects dynamically.
    info "Discovering projects..."

    PROJECTS_FILE=$(mktemp) || die "Failed to create temporary file"
    trap 'rm -f "$PROJECTS_FILE"' EXIT INT TERM

    # Build a numbered list from west.yml locations.
    find "$REPO_ROOT" -maxdepth 2 -name "west.yml" -type f | sort | while IFS= read -r manifest; do
        basename "$(dirname "$manifest")"
    done > "$PROJECTS_FILE"

    project_count=$(wc -l < "$PROJECTS_FILE" | awk '{print $1}')
    if [ "$project_count" -eq 0 ]; then
        die "No projects found with west.yml"
    fi

    i=1
    while IFS= read -r project_name; do
        echo "  $i) $project_name"
        i=$((i + 1))
    done < "$PROJECTS_FILE"

    printf "Select project (1 to %s): " "$project_count"
    read -r choice

    case "$choice" in
        ''|*[!0-9]*) die "Invalid choice: $choice" ;;
    esac

    if [ "$choice" -lt 1 ] || [ "$choice" -gt "$project_count" ]; then
        die "Invalid choice: $choice"
    fi

    PROJECT=$(sed -n "${choice}p" "$PROJECTS_FILE")
fi

# Validate project exists
if [ ! -f "$REPO_ROOT/$PROJECT/west.yml" ]; then
    die "Project '$PROJECT' not found: $REPO_ROOT/$PROJECT/west.yml"
fi

# Detect board based on project name.
BOARD=$(detect_board "$PROJECT")

info "Repo root  : $REPO_ROOT"
info "Project    : $PROJECT"
info "Board      : $BOARD"
info "Venv dir   : $VENV_DIR"
echo ""

# ── 0. Hardware target SDK environment (if needed) ──────────────────────────
if [ "$BOARD" != "native_posix_64" ]; then
    info "Setting up hardware target environment..."

    # Check if Zephyr SDK is installed
    SDK_DIR="$REPO_ROOT/zephyr-sdk-0.16.8"
    if [ ! -d "$SDK_DIR" ]; then
        die "Zephyr SDK not found at: $SDK_DIR
        
Please install it first:
  sh scripts/install_esp32_toolchain.sh"
    fi
    
    # Export SDK paths
    export ZEPHYR_SDK_INSTALL_DIR="$SDK_DIR"
    export PATH="$SDK_DIR/x86_64-pokysdk-linux/usr/bin:$PATH"
    export PATH="$SDK_DIR/tools/bin:$PATH"

    ok "ZEPHYR_SDK_INSTALL_DIR=$ZEPHYR_SDK_INSTALL_DIR"
fi
echo ""

# ── 1. Python virtual environment ────────────────────────────────────────────
if [ ! -f "$VENV_DIR/bin/activate" ]; then
    info "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR" || die "python3 -m venv failed"
else
    ok "Virtual environment already exists."
fi

# shellcheck source=/dev/null
. "$VENV_DIR/bin/activate"
ok "Activated: $VIRTUAL_ENV"
echo ""

# ── 2. west ──────────────────────────────────────────────────────────────────
info "Installing / verifying west..."
pip install --quiet --upgrade pip
pip install --quiet --upgrade west || die "Failed to install west"
ok "west $(west --version)"
echo ""

# ── 3. West workspace init + update ──────────────────────────────────────────
cd "$REPO_ROOT"

if [ ! -d ".west" ]; then
    info "Initialising west workspace..."
    west init -l "$PROJECT" || die "west init failed"
fi

# Always ensure manifest.path points to the chosen project (allows switching)
west config manifest.path "$PROJECT"
ok "Manifest path: $PROJECT"

# Validate manifest before fetching
info "Validating manifest..."
west manifest --validate || die "Manifest validation failed"
ok "Manifest is valid."

info "Running west update (fetches / syncs Zephyr v3.7.0 — may take a while on first run)..."
west update || die "west update failed"
ok "Zephyr fetched."
echo ""

# ── 4. Zephyr Python requirements ────────────────────────────────────────────
ZEPHYR_REQ="$REPO_ROOT/zephyr/scripts/requirements.txt"
if [ -f "$ZEPHYR_REQ" ]; then
    info "Installing Zephyr Python requirements..."
    pip install --quiet -r "$ZEPHYR_REQ" || die "pip install requirements failed"
    ok "Zephyr requirements installed."
else
    warn "$ZEPHYR_REQ not found — west update may not have completed."
fi
echo ""

# ── 5. Build the project ─────────────────────────────────────────────────────
BUILD_DIR="$REPO_ROOT/$PROJECT/build_$BOARD"

info "Building $PROJECT for $BOARD..."
cd "$REPO_ROOT"

# For native POSIX simulation, use host compiler. For hardware targets, use Zephyr SDK.
if [ "$BOARD" = "native_posix_64" ]; then
    # Native simulation: leverage host compiler (no cross-compiler needed)
    west build -b "$BOARD" "$PROJECT/app" -d "$BUILD_DIR" -p always -- -DZEPHYR_TOOLCHAIN_VARIANT=host || die "west build failed"
else
    # Hardware targets (ESP32, etc.): Zephyr SDK environment already configured above
    west build -b "$BOARD" "$PROJECT/app" -d "$BUILD_DIR" -p always || die "west build failed"
fi

ok "Build successful at: $BUILD_DIR"
echo ""

# ── 6. Next steps ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setup & build complete for '$PROJECT'! Re-running this script any time is safe."
echo ""
echo " Switch to a different project and rebuild:"
echo "   sh scripts/setup.sh native_project  # or native_project_2, esp32_led_blink, pico_led_blink"
echo ""
echo " Activate the environment in any new terminal:"
echo "   source $VENV_DIR/bin/activate"
echo ""

if [ "$BOARD" = "native_posix_64" ]; then
    echo " Run the built app (native POSIX):"
    echo "   ./$PROJECT/build_native_posix_64/zephyr/zephyr.exe"
elif [ "$BOARD" = "rpi_pico" ]; then
    UF2_FILE="$BUILD_DIR/zephyr/zephyr.uf2"
    ELF_FILE="$BUILD_DIR/zephyr/zephyr.elf"
    echo " Build outputs (Raspberry Pi Pico):"
    echo "   UF2 image:   $UF2_FILE"
    echo "   ELF image:   $ELF_FILE"
    echo ""
    echo " To flash with UF2 drag-and-drop:"
    echo "   1) Hold BOOTSEL and connect Pico via USB"
    echo "   2) Copy $UF2_FILE to the mounted RPI-RP2 drive"
    echo ""
    echo " Or flash using west (if probe/runner is configured):"
    echo "   west flash -d $BUILD_DIR"
else
    BUILD_BINARY="$BUILD_DIR/zephyr/zephyr.bin"
    echo " Build outputs (hardware target):"
    echo "   Application:  $BUILD_BINARY"
    echo "   Bootloader:   $BUILD_DIR/zephyr/bootloader-esp32.bin"
    echo "   Partitions:   $BUILD_DIR/zephyr/partitions.bin"
    echo ""
    echo " To flash to ESP32 board:"
    echo "   esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 460800 write_flash \\"
    echo "     0x1000 $BUILD_DIR/zephyr/bootloader-esp32.bin \\"
    echo "     0x8000 $BUILD_DIR/zephyr/partitions.bin \\"
    echo "     0x10000 $BUILD_DIR/zephyr/zephyr.bin"
    echo ""
    echo " Monitor serial output:"
    echo "   picocom /dev/ttyUSB0 -b 115200"
fi

echo ""
echo " Rebuild $PROJECT without full setup:"
echo "   cd $REPO_ROOT && source venv/bin/activate"
echo "   west build -b $BOARD $PROJECT/app -d $PROJECT/build_$BOARD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
