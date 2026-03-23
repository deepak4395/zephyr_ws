#!/usr/bin/env sh
# setup.sh — Idempotent project setup. Safe to run multiple times.
#
# Usage (run from anywhere; the script finds the repo root itself):
#   sh zephyr_ws/scripts/setup.sh
#   -- or --
#   cd zephyr_ws && sh scripts/setup.sh
#
# What it does (each step is skipped if already done):
#   1. Creates venv at <repo>/venv if absent
#   2. Installs / upgrades west inside the venv
#   3. Runs west init if .west is absent, then always west update
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

# ── repo / venv paths ────────────────────────────────────────────────────────
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VENV_DIR="$REPO_ROOT/venv"

info "Repo root : $REPO_ROOT"
info "Venv dir  : $VENV_DIR"
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
    west init -l native_project || die "west init failed"
fi

# Always ensure manifest.path is correct (harmless if already set)
west config manifest.path native_project

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

# ── 5. Next steps ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setup complete! Re-running this script any time is safe."
echo ""
echo " Activate the environment in any new terminal:"
echo "   source $VENV_DIR/bin/activate"
echo ""
echo " Build the native app:"
echo "   cd $REPO_ROOT"
echo "   west build -b native_posix_64 native_project/app \\"
echo "              -d native_project/build_native \\"
echo "              -- -DZEPHYR_TOOLCHAIN_VARIANT=host"
echo ""
echo " Run it:"
echo "   ./native_project/build_native/zephyr/zephyr.exe"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
