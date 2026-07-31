#!/bin/sh
# scarm-docker launcher. Runs as the app user with DISPLAY already set by the base image.
set -e

WINEPREFIX="${WINEPREFIX:-/config/wine}"
export WINEPREFIX
INSTALLER="/opt/SCARMsetup.exe"

find_scarm() {
    find "$WINEPREFIX/drive_c" -iname 'SCARM.exe' 2>/dev/null | head -n1
}

# Install on first run (or retry if a previous install failed). The presence of
# SCARM.exe is the idempotency guard, so a failed install naturally retries on the
# next start instead of bricking the container into a restart loop.
SCARM_EXE="$(find_scarm)"
if [ -z "$SCARM_EXE" ]; then
    echo "[scarm] SCARM not found; initializing Wine prefix at $WINEPREFIX and installing ..."
    wineboot --init || true
    wineserver -w || true

    echo "[scarm] Installing SCARM (silent) ..."
    # SCARM ships an Inno Setup installer; these are its silent flags.
    wine "$INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true
    wineserver -w || true

    SCARM_EXE="$(find_scarm)"
fi

if [ -z "$SCARM_EXE" ]; then
    echo "[scarm] ERROR: SCARM.exe not found after install attempt." >&2
    echo "[scarm] The silent install may have failed under Wine; see the README" >&2
    echo "[scarm] troubleshooting section for the interactive-install fallback." >&2
    find "$WINEPREFIX/drive_c" -iname '*.exe' 2>/dev/null | head -n 20 >&2 || true
    exit 1
fi

# Expose the /projects host folder as Wine drive P: for saving/opening layouts.
mkdir -p /projects
ln -sfn /projects "$WINEPREFIX/dosdevices/p:"

echo "[scarm] Launching: $SCARM_EXE"
exec wine "$SCARM_EXE"
