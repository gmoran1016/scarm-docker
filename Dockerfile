# syntax=docker/dockerfile:1
# scarm-docker — SCARM under Wine on LinuxServer's KasmVNC base (browser desktop).
FROM lscr.io/linuxserver/baseimage-kasmvnc:ubuntunoble

# --- Version / source of the SCARM installer (override at build time if needed) ---
ARG SCARM_VERSION=2.0.1
ARG SCARM_INSTALLER_URL=https://www.scarm.info/SCARMsetup2_0_1.exe

# --- Page title + Wine environment ---
ENV TITLE="SCARM" \
    SCARM_VERSION="${SCARM_VERSION}" \
    WINEPREFIX=/config/wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml="

# --- Install Wine (WineHQ stable) + software OpenGL, and fetch the installer ---
RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget ca-certificates gnupg cabextract \
        libgl1-mesa-dri libgl1-mesa-dri:i386 \
        libgl1:i386 libglx-mesa0:i386 mesa-utils; \
    mkdir -pm755 /etc/apt/keyrings; \
    wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key; \
    wget -qNP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends winehq-stable; \
    wget -qO /opt/SCARMsetup.exe "${SCARM_INSTALLER_URL}"; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- Launch SCARM instead of the base's default xterm (runs as user 'abc') ---
# custom-cont-init.d/50-scarm-launcher force-syncs the launcher into /config on
# every start, so image updates aren't shadowed by the stale /config copy that
# LinuxServer seeds once and never refreshes.
COPY root/ /
RUN chmod +x /defaults/autostart /custom-cont-init.d/50-scarm-launcher

# Web UI on 3000 (http) / 3001 (https); /config volume provided by the base.
