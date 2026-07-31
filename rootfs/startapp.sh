#!/bin/sh
# scarm-docker launcher. Runs as the app user with DISPLAY already set by the base image.
set -e

WINEPREFIX="${WINEPREFIX:-/config/wine}"
export WINEPREFIX
INSTALLER="/opt/SCARMsetup.exe"
INSTALL_MARKER="$WINEPREFIX/.scarm-installed"

# First run: create the Wine prefix and silently install SCARM.
if [ ! -f "$INSTALL_MARKER" ]; then
    echo "[scarm] First run: initializing Wine prefix at $WINEPREFIX ..."
    wineboot --init
    wineserver -w || true

    echo "[scarm] Installing SCARM (silent) ..."
    # SCARM ships an Inno Setup installer; these are its silent flags.
    wine "$INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true
    wineserver -w || true

    touch "$INSTALL_MARKER"
    echo "[scarm] Install step complete."
fi

# Expose the /projects host folder as Wine drive P: for saving/opening layouts.
mkdir -p /projects
ln -sfn /projects "$WINEPREFIX/dosdevices/p:"

# Locate the installed executable (Program Files or Program Files (x86)).
SCARM_EXE="$(find "$WINEPREFIX/drive_c" -iname 'SCARM.exe' 2>/dev/null | head -n1)"
if [ -z "$SCARM_EXE" ]; then
    echo "[scarm] ERROR: SCARM.exe not found after install. Prefix contents:" >&2
    find "$WINEPREFIX/drive_c" -iname '*.exe' 2>/dev/null | head -n 20 >&2 || true
    exit 1
fi

echo "[scarm] Launching: $SCARM_EXE"
exec wine "$SCARM_EXE"
