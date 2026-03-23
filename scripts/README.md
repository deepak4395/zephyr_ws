# Scripts Directory

Helper scripts for managing your Zephyr multi-project workspace.

## Setup & Build

### `setup.sh` — Main Setup & Build Orchestrator

Idempotent script that initializes the workspace and builds a project.

**Usage:**
```bash
sh scripts/setup.sh                  # Interactive: choose project
sh scripts/setup.sh native_project   # Build native_project
sh scripts/setup.sh esp32_led_blink  # Build esp32_led_blink (requires toolchain)
```

**What it does:**
1. Creates/activates Python virtual environment
2. Installs/upgrades west
3. Initializes west workspace with project manifest
4. Fetches Zephyr and project dependencies
5. Installs Zephyr Python requirements
6. Builds the selected project for appropriate board

**Re-run anytime:** Safe to run multiple times (idempotent).

---

## ESP32 Hardware Development

### `install_esp32_toolchain.sh` — One-Time Toolchain Setup

Installs prerequisites for ESP32 hardware builds:
- Zephyr SDK v0.16.8 (includes Xtensa GCC cross-compiler)
- esptool (flashing utility)
- picocom (optional serial monitor)

**Usage:**
```bash
sh scripts/install_esp32_toolchain.sh
source ./esp32_env.sh
sh scripts/setup.sh esp32_led_blink
```

**Output:**
- Zephyr SDK installed at `./zephyr-sdk-0.16.8/`
- `esp32_env.sh` created (source to activate environment)

---

### `flash_esp32.sh` — Flash Binary to Board

Flashes compiled Zephyr binary to ESP32 board via serial connection.

**Usage:**
```bash
sh scripts/flash_esp32.sh esp32_led_blink              # Uses /dev/ttyUSB0
sh scripts/flash_esp32.sh esp32_led_blink /dev/ttyACM0 # Custom port
```

**What it does:**
1. Verifies build binaries exist
2. Checks esptool is available
3. Flashes bootloader → partitions → application
4. Resets board

**Addresses flashed:**
- `0x1000` → bootloader-esp32.bin
- `0x8000` → partitions.bin
- `0x10000` → zephyr.bin

---

## Project Targets

| Project | Board | Build | Run |
|---------|-------|-------|-----|
| `native_project` | native_posix_64 | `sh scripts/setup.sh native_project` | `./native_project/build_native_posix_64/zephyr/zephyr.exe` |
| `native_project_2` | native_posix_64 | `sh scripts/setup.sh native_project_2` | `./native_project_2/build_native_posix_64/zephyr/zephyr.exe` |
| `esp32_led_blink` | esp32_devkitc_wroom | `sh scripts/setup.sh esp32_led_blink` | `sh scripts/flash_esp32.sh esp32_led_blink /dev/ttyUSB0` |

---

## Complete Workflow Example

### Native Project (No Hardware Needed)

```bash
# Build
sh scripts/setup.sh native_project

# Run
./native_project/build_native_posix_64/zephyr/zephyr.exe
```

### ESP32 Hardware Project

```bash
# One-time: Install toolchain
sh scripts/install_esp32_toolchain.sh
source ./esp32_env.sh

# Subsequent sessions: Just activate environment
source ./esp32_env.sh

# Build
sh scripts/setup.sh esp32_led_blink

# Flash to board (connected to /dev/ttyUSB0)
sh scripts/flash_esp32.sh esp32_led_blink /dev/ttyUSB0

# Monitor serial output
picocom /dev/ttyUSB0 -b 115200
```

---

## Troubleshooting

### Build fails with "west command not found"
```bash
source venv/bin/activate
```

### "xtensa/config/core-isa.h: No such file or directory"
Xtensa toolchain not installed:
```bash
sh scripts/install_esp32_toolchain.sh
source ./esp32_env.sh
```

### "Port does not exist" during flashing
Board not connected or wrong port:
```bash
ls /dev/tty* | grep -E '(USB|ACM)'  # Find your port
sh scripts/flash_esp32.sh esp32_led_blink /dev/ttyACM0
```

---

## References

- [ESP32 Hardware Build & Flash Guide](../ESP32_HARDWARE_BUILD.md)
- [Zephyr Documentation](https://docs.zephyrproject.io/)
- [esptool GitHub](https://github.com/espressif/esptool)
