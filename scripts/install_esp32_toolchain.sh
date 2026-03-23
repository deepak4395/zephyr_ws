#!/usr/bin/env sh
# install_esp32_toolchain.sh — Install Zephyr SDK and esptool for ESP32 development
#
# This script installs:
#   1. Zephyr SDK v0.16.8 (includes Xtensa GCC cross-compiler)
#   2. esptool (for flashing binaries to ESP32 boards)
#   3. picocom (optional: for serial monitoring)
#
# Usage:
#   sh scripts/install_esp32_toolchain.sh

set -u

info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'WARN: %s\n' "$*" >&2; }
die()   { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok()    { printf '    OK: %s\n' "$*"; }

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SDK_VERSION="0.16.8"
SDK_DIR="$REPO_ROOT/zephyr-sdk-$SDK_VERSION"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Zephyr SDK + ESP32 Toolchain Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. Zephyr SDK (includes Xtensa cross-compiler) ──────────────────────────
if [ -d "$SDK_DIR" ]; then
    ok "Zephyr SDK already installed at: $SDK_DIR"
else
    info "Downloading Zephyr SDK v$SDK_VERSION..."
    
    # Detect OS/architecture
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case "$OS-$ARCH" in
        Linux-x86_64)
            SDK_FILE="zephyr-sdk-${SDK_VERSION}_linux-x86_64.tar.xz"
            ;;
        Linux-aarch64)
            SDK_FILE="zephyr-sdk-${SDK_VERSION}_linux-aarch64.tar.xz"
            ;;
        Darwin-x86_64)
            SDK_FILE="zephyr-sdk-${SDK_VERSION}_macos-x86_64.tar.xz"
            ;;
        Darwin-arm64)
            SDK_FILE="zephyr-sdk-${SDK_VERSION}_macos-aarch64.tar.xz"
            ;;
        *)
            die "Unsupported OS/ARCH: $OS/$ARCH"
            ;;
    esac
    
    DOWNLOAD_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VERSION}/${SDK_FILE}"
    
    if command -v wget >/dev/null 2>&1; then
        wget --progress=bar "$DOWNLOAD_URL" -O "$REPO_ROOT/$SDK_FILE" || die "wget failed"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$REPO_ROOT/$SDK_FILE" "$DOWNLOAD_URL" || die "curl failed"
    else
        die "Neither wget nor curl found — please install one"
    fi
    
    info "Extracting Zephyr SDK..."
    cd "$REPO_ROOT"
    tar xf "$SDK_FILE" || die "tar extraction failed"
    rm "$SDK_FILE"
    ok "Zephyr SDK installed at: $SDK_DIR"
fi

echo ""

# ── 2. esptool (Python package for flashing) ─────────────────────────────
info "Installing esptool..."
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --upgrade esptool || die "pip3 install esptool failed"
else
    die "pip3 not found — please install Python 3 + pip"
fi
ok "esptool installed: $(esptool.py version)"

echo ""

# ── 3. picocom (optional: serial monitor) ────────────────────────────────
if command -v picocom >/dev/null 2>&1; then
    ok "picocom already installed"
else
    warn "picocom not found (optional, for serial monitoring)"
    echo "    Install on Ubuntu/Debian:  sudo apt-get install picocom"
    echo "    Install on macOS:          brew install picocom"
fi

echo ""

# ── 4. Set environment variables ─────────────────────────────────────────
info "Setting environment variables..."
cat > "$REPO_ROOT/esp32_env.sh" <<'EOF'
#!/usr/bin/env sh
# esp32_env.sh — Source this to set up ESP32 build environment
export ZEPHYR_SDK_INSTALL_DIR="$(dirname "$0")/zephyr-sdk-0.16.8"
export PATH="$ZEPHYR_SDK_INSTALL_DIR/x86_64-pokysdk-linux/usr/bin:$PATH"
export PATH="$ZEPHYR_SDK_INSTALL_DIR/tools/bin:$PATH"
echo "ESP32 environment configured."
echo "  ZEPHYR_SDK_INSTALL_DIR=$ZEPHYR_SDK_INSTALL_DIR"
EOF
chmod +x "$REPO_ROOT/esp32_env.sh"
ok "Created esp32_env.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Installation complete!"
echo ""
echo " Before building ESP32 projects, run:"
echo "   source ./esp32_env.sh"
echo ""
echo " Then rebuild the project:"
echo "   sh scripts/setup.sh esp32_led_blink"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
