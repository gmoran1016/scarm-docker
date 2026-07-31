# syntax=docker/dockerfile:1
# scarm-docker — SCARM under Wine on a browser-accessible base image.
FROM jlesage/baseimage-gui:debian-12-v4

# --- Version / source of the SCARM installer (override at build time if needed) ---
ARG SCARM_VERSION=2.0.1
ARG SCARM_INSTALLER_URL=https://www.scarm.info/SCARMsetup2_0_1.exe

# --- App metadata + Wine environment ---
ENV APP_NAME="SCARM" \
    APP_VERSION="${SCARM_VERSION}" \
    WINEPREFIX=/config/wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=768

# --- Install Wine (WineHQ stable), software OpenGL, and fetch the installer ---
RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget ca-certificates gnupg cabextract xz-utils fonts-liberation \
        libgl1-mesa-dri libgl1-mesa-dri:i386 \
        libgl1:i386 libglx-mesa0:i386 mesa-utils; \
    mkdir -pm755 /etc/apt/keyrings; \
    wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key; \
    wget -qNP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends winehq-stable; \
    wget -qO /opt/SCARMsetup.exe "${SCARM_INSTALLER_URL}"; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- App launcher (jlesage runs /startapp.sh as the app user) ---
COPY rootfs/ /
RUN chmod +x /startapp.sh

# Web UI is exposed on 5800 and VNC on 5900 by the base image.
