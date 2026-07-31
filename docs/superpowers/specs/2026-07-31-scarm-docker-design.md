# SCARM-in-a-Browser Docker Image — Design

**Date:** 2026-07-31
**Status:** Approved (pending spec review)
**Owner:** gmoran1016

## Goal

Run **SCARM** (Simple Computer Aided Railway Modeller), a native Windows model-railway
design program, inside a Docker container on **Unraid**, accessed entirely through a web
browser (no Windows machine, no VNC client required).

SCARM is freeware. Current version: **2.0.1** (released 2026-03-31).
Direct installer: `https://www.scarm.info/SCARMsetup2_0_1.exe`.
System requirement of note: **OpenGL-compatible graphics** (used by the 3D view).

## Approach

Package SCARM's Windows binary under **Wine** on top of the
**`jlesage/baseimage-gui`** (Debian) base image, which provides a browser-accessible
desktop (noVNC web server + X server + window manager + VNC), PUID/PGID/timezone
handling, and Unraid-friendly conventions out of the box. We add only Wine, software
OpenGL, the SCARM installer, and glue scripts.

Rejected alternatives:
- **linuxserver/baseimage-kasmvnc + Wine** — smoother rendering but heavier and more
  assembly; noVNC is adequate for SCARM's primarily-2D editor.
- **Roll our own (ubuntu + x11vnc + noVNC + openbox + Wine)** — re-implements what the
  base image gives for free; higher maintenance.

## Architecture

```
Browser ──http:5800──▶ noVNC ──▶ X server ──▶ Wine ──▶ SCARM.exe
                   (jlesage/baseimage-gui provides everything left of Wine)
        VNC:5900 (optional, native VNC client)

Volumes:
  /config    ──▶ Wine prefix + SCARM install + Wine internals (persists)
  /projects  ──▶ dedicated Wine drive for the user's .scarm layout files
                 (clean, easy-to-back-up, separate from Wine internals)
```

## Base-image course-correction (2026-07-31, approved)

The original base, `jlesage/baseimage-gui` (Debian), proved unworkable for Wine: it
compiles its **own** fontconfig from source into custom directories and does not register
it with dpkg. Wine's OpenGL/X libraries hard-depend on the distro `libfontconfig1`, forcing
apt to install the distro `fontconfig` package on top, whose `fc-cache` postinst then fails
against the base's custom setup — cascading to every downstream package (pango, Wine). The
build was switched to **`lscr.io/linuxserver/baseimage-kasmvnc:ubuntunoble`** (LinuxServer
KasmVNC, a full Ubuntu desktop base using standard distro packages), which hosts Wine
cleanly. Consequent changes: web UI port is **3000/3001** (was 5800/5900); the launcher is
`root/defaults/autostart` run as user `abc` (was `startapp.sh`); env vars use `TITLE` and
LinuxServer `PUID/PGID`. Persistence model (`/config` prefix, `/projects` → drive `P:`),
amd64-only scope, and GHCR/Actions publishing are unchanged.

## Implementation deviations (approved during planning)

Two refinements were adopted over the sketch below, with the same runtime result:
- The SCARM installer is **downloaded at build time** by the Dockerfile (to
  `/opt/SCARMsetup.exe`) rather than committed to the repo — cleaner repo, no
  redistribution of the freeware installer, still no *runtime* dependency on scarm.info.
- First-run install/launch lives in **`rootfs/startapp.sh`** (run as the app user, so the
  Wine prefix is owned correctly) rather than a root-run `cont-init.d` script. Idempotency
  keys off the presence of `SCARM.exe`, so a failed install retries on the next start.

## Repository layout

```
scarm-docker/
├── Dockerfile
├── rootfs/
│   ├── startapp.sh                  # jlesage entrypoint: launches SCARM under Wine
│   └── etc/cont-init.d/
│       └── 48-scarm-install         # first-run: init wineprefix + silent-install SCARM
├── SCARMsetup2_0_1.exe              # baked into image at build (version-pinned)
├── .github/workflows/build.yml      # build amd64 → push to ghcr.io on push + tags
├── unraid-template/
│   └── scarm-docker.xml             # Unraid "Add Container" template
├── docs/superpowers/specs/          # this design + future specs
└── README.md
```

## Key decisions

### Image identity
- Image name: **`ghcr.io/gmoran1016/scarm-docker`** — named `scarm-docker` to stay clearly
  distinct from the official SCARM project and its naming.
- Tags: `latest`, plus a SCARM-version tag (`2.0.1`) for rollback.
- Published as a **public** GHCR package so Unraid pulls without authentication.

### Installer handling
- The `.exe` is **copied into the image at build time** — reproducible, version-pinned,
  no runtime dependency on scarm.info.
- Installation happens on **first container start** via `cont-init.d`, guarded by a check:
  install only if SCARM isn't already present in the prefix. Restarts are therefore
  instant, and the installed state persists in `/config`.
- `WINEPREFIX=/config/wine`.

### Silent install
- SCARM's installer is an Inno Setup installer; run silently with
  `wine SCARMsetup2_0_1.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART`.
- If silent flags prove unreliable under Wine, fall back to a first-run interactive
  install (documented in README). This is the one runtime unknown; verified during the
  smoke test.

### Persistence
- **`/config`** — single mapping holding the Wine prefix (which contains the SCARM
  installation and Wine internals).
- **`/projects`** — a dedicated host folder surfaced inside Wine as a drive letter (e.g.
  `P:` via a symlink in `dosdevices`), so the user's `.scarm` files live in a clean
  location that's easy to back up independently of Wine internals. README will point
  users to save/open layouts there.

### Rendering
- Install `libgl1-mesa-dri` (+ `mesa-utils`) so OpenGL uses **llvmpipe** software
  rendering — the 3D view works without a GPU (slow on large 3D scenes; the 2D editor,
  the primary workflow, stays responsive).

### Architecture support
- **amd64 only.** Unraid is x86_64; Wine under arm64 emulation isn't worth it.

### Ports
- `5800` — web UI (noVNC).
- `5900` — VNC (optional).

## CI (GitHub Actions → GHCR)

- Trigger: push to `main` and version tags (`v*`).
- Steps: checkout → set up Buildx → log in to GHCR with `GITHUB_TOKEN` →
  `docker/build-push-action` for `linux/amd64` → push `latest` and version tags.
- Also builds on PRs (without push) so breakage is caught early.
- The workflow needs `packages: write` permission; the resulting package is set public.

## Unraid template (`scarm-docker.xml`)

Provides one-click "Add Container" fields:
- Repository: `ghcr.io/gmoran1016/scarm-docker:latest`
- WebUI: `http://[IP]:[PORT:5800]`
- Port mapping: `5800` (web), optional `5900` (VNC).
- Path mappings: `/config` and `/projects` to user-chosen Unraid shares.
- Variables: `PUID`, `PGID`, `TZ`, and jlesage display vars (e.g. `DISPLAY_WIDTH`,
  `DISPLAY_HEIGHT`) with sensible defaults.
- Category, icon, and description for the Unraid UI.

## Testing / verification

This is infrastructure; verification is a documented smoke test plus a CI build gate.

**CI gate:** every push/PR builds the image — a broken Dockerfile fails the pipeline.

**Manual smoke test (documented in README):**
1. `docker run --rm -p 5800:5800 -v ./cfg:/config -v ./proj:/projects ghcr.io/gmoran1016/scarm-docker:latest`
2. Open `http://localhost:5800`.
3. Confirm the SCARM window loads (first run performs the install).
4. Draw a couple of track pieces; open the 3D view briefly to confirm OpenGL works.
5. Save a `.scarm` file into the `/projects` location.
6. Restart the container; reopen the file — verify install + layout persisted.

## Out of scope (YAGNI)

- arm64 images.
- Audio (SCARM has no meaningful audio needs).
- Automated download of new SCARM versions (bump the pinned installer + tag manually).
- Multi-user / auth in front of the web UI (rely on Unraid network / reverse proxy if
  the user wants it later).

## Open runtime unknowns (resolved during smoke test)

1. Whether SCARM's Inno Setup installer accepts `/VERYSILENT` cleanly under Wine
   (fallback: first-run interactive install).
2. Whether llvmpipe OpenGL is sufficient for SCARM's 3D view to render at all
   (2D editor is unaffected regardless).
