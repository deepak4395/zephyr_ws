#!/usr/bin/env sh
# flash_esp32.sh — Flash Zephyr binary to ESP32 board via esptool
#
# Usage:
#   sh scripts/flash_esp32.sh [project_name] [port]
#
# Examples:
#   sh scripts/flash_esp32.sh esp32_led_blink           # Uses /dev/ttyUSB0 (default)
#   sh scripts/flash_esp32.sh esp32_led_blink /dev/ttyUSB1
#
# Note: Board must have USB/UART connection and be in bootloader mode (or auto-reset jumper)

set -u

info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'WARN: %s\n' "$*" >&2; }
die()   { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok()    { printf '    OK: %s\n' "$*"; }

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJECT="${1:-esp32_led_blink}"
PORT="${2:-/dev/ttyUSB0}"
BAUD="460800"

# Detect board type from project name
case "$PROJECT" in
    esp32*)
        BOARD="esp32_devkitc_wroom"
        CHIP="esp32"
        ;;
    *)
        die "Unknown project: $PROJECT (only esp32* projects can be flashed)"
        ;;
esac

BUILD_DIR="$REPO_ROOT/$PROJECT/build_$BOARD"
BIN_APP="$BUILD_DIR/zephyr/zephyr.bin"
BIN_BOOTLOADER="$BUILD_DIR/zephyr/bootloader-esp32.bin"
BIN_PARTITIONS="$BUILD_DIR/zephyr/partitions.bin"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ESP32 Flasher"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Project:     $PROJECT"
info "Board:       $BOARD"
info "Chip:        $CHIP"
info "Port:        $PORT"
info "Baud rate:   $BAUD"
echo ""

# Verify binaries exist
if [ ! -f "$BIN_APP" ]; then
    die "Application binary not found: $BIN_APP"
fi
ok "Found: zephyr.bin"

if [ ! -f "$BIN_BOOTLOADER" ]; then
    die "Bootloader not found: $BIN_BOOTLOADER"
fi
ok "Found: bootloader-esp32.bin"

if [ ! -f "$BIN_PARTITIONS" ]; then
    die "Partition table not found: $BIN_PARTITIONS"
fi
ok "Found: partitions.bin"

echo ""

# Verify esptool is installed
if ! command -v esptool.py >/dev/null 2>&1; then
    die "esptool.py not found. Install with: pip install esptool"
fi
ok "esptool.py available: $(esptool.py version)"

# Verify port exists
if [ ! -e "$PORT" ]; then
    warn "Port does not exist: $PORT"
    echo "    Available USB/serial devices:"
    ls -1 /dev/tty* 2>/dev/null | grep -E '(USB|ACM|ttyS)' || echo "    (none found)"
    die "Please specify correct port as 2nd argument"
fi
ok "Port accessible: $PORT"

echo ""
info "Flashing binaries to $CHIP on $PORT..."
echo ""

# Flash: bootloader (0x1000) + partitions (0x8000) + app (0x10000)
esptool.py \
    --chip "$CHIP" \
    --port "$PORT" \
    --baud "$BAUD" \
    --before "default_reset" \
    --after "hard_reset" \
    write_flash \
        0x1000 "$BIN_BOOTLOADER" \
        0x8000 "$BIN_PARTITIONS" \
        0x10000 "$BIN_APP" \
    || die "esptool flashing failed"

echo ""
ok "✓ Flashing complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Next: Monitor serial output"
echo "   picocom $PORT -b 115200"
echo "   (or: screen $PORT 115200)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
