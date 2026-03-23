#!/usr/bin/env sh
# setup.sh — Idempotent Zephyr multi-project setup. Safe to run multiple times.
#
# Usage:
#   sh scripts/setup.sh                        # Interactive: choose project
#   sh scripts/setup.sh native_project         # Non-interactive: use native_project
#   sh scripts/setup.sh native_project_2       # Non-interactive: use native_project_2
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

# ── repo / venv paths ────────────────────────────────────────────────────────
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VENV_DIR="$REPO_ROOT/venv"

# ── project selection ────────────────────────────────────────────────────────
PROJECT=${1:-}

if [ -z "$PROJECT" ]; then
    # Interactive: list available projects
    info "Available projects:"
    echo "  1) native_project"
    echo "  2) native_project_2"
    printf "Select project (1 or 2): "
    read -r choice
    case "$choice" in
        1) PROJECT="native_project" ;;
        2) PROJECT="native_project_2" ;;
        *) die "Invalid choice: $choice" ;;
    esac
fi

# Validate project exists
if [ ! -f "$REPO_ROOT/$PROJECT/west.yml" ]; then
    die "Project '$PROJECT' not found: $REPO_ROOT/$PROJECT/west.yml"
fi

info "Repo root  : $REPO_ROOT"
info "Project    : $PROJECT"
info "Venv dir   : $VENV_DIR"
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
BUILD_DIR="$REPO_ROOT/$PROJECT/build_native"

info "Building $PROJECT for native_posix_64..."
cd "$REPO_ROOT"
west build -b native_posix_64 "$PROJECT/app" -d "$BUILD_DIR" -p always -- -DZEPHYR_TOOLCHAIN_VARIANT=host || die "west build failed"
ok "Build successful."
echo ""

# ── 6. Next steps ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setup & build complete for '$PROJECT'! Re-running this script any time is safe."
echo ""
echo " Switch to a different project and rebuild:"
echo "   sh scripts/setup.sh native_project  # or native_project_2"
echo ""
echo " Activate the environment in any new terminal:"
echo "   source $VENV_DIR/bin/activate"
echo ""
echo " Run the built app:"
echo "   ./$PROJECT/build_native/zephyr/zephyr.exe"
echo ""
echo " Rebuild $PROJECT without full setup:"
echo "   cd $REPO_ROOT"
echo "   source venv/bin/activate"
echo "   west build -b native_posix_64 $PROJECT/app -d $PROJECT/build_native"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
