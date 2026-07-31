# SCARM Docker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the Windows freeware SCARM under Wine on a browser-accessible base image, publish it to GHCR via GitHub Actions, and provide an Unraid template so it runs in a browser tab on Unraid.

**Architecture:** `FROM jlesage/baseimage-gui` (Debian) supplies the noVNC web desktop, X server, VNC, and PUID/PGID handling. The Dockerfile adds WineHQ-stable, software OpenGL (llvmpipe), and downloads+bakes the pinned SCARM installer. On first container start, `startapp.sh` (running as the app user) initializes the Wine prefix under `/config/wine`, silently installs SCARM, symlinks `/projects` to Wine drive `P:`, then launches `SCARM.exe`. GitHub Actions builds `linux/amd64` and pushes to `ghcr.io/gmoran1016/scarm-docker`.

**Tech Stack:** Docker, jlesage/baseimage-gui (Debian 12), WineHQ stable, Mesa (llvmpipe), noVNC, GitHub Actions, Unraid Community Applications template (XML).

**Note on infra testing:** There is no unit-test framework here. Each task's "verify" step is a concrete build/run command with expected output, and every task ends with a commit. The full end-to-end smoke test is Task 7.

---

## File Structure

```
scarm-docker/
├── .gitignore
├── .dockerignore
├── Dockerfile                       # base image + Wine + Mesa + baked installer
├── rootfs/
│   └── startapp.sh                  # jlesage entrypoint: first-run install + launch SCARM
├── .github/workflows/build.yml      # CI: build amd64 → push to ghcr.io
├── unraid-template/scarm-docker.xml # Unraid "Add Container" template
├── docs/superpowers/                # spec + this plan (already present)
└── README.md                        # usage, first-run behavior, smoke test
```

Responsibilities:
- **Dockerfile** — everything build-time: install Wine/Mesa, fetch the SCARM installer, set env/metadata, copy the launcher.
- **rootfs/startapp.sh** — everything run-time: idempotent first-run install, `/projects` drive, locate + exec SCARM.
- **build.yml** — reproducible image publishing.
- **scarm-docker.xml** — Unraid one-click deployment.
- **README.md** — human instructions.

---

## Task 1: Repository scaffolding

**Files:**
- Create: `.gitignore`
- Create: `.dockerignore`
- Create: `README.md` (skeleton; finalized in Task 8)

- [ ] **Step 1: Create `.gitignore`**

```gitignore
# Local build/test artifacts
cfg/
proj/
*.log

# OS junk
.DS_Store
Thumbs.db
```

- [ ] **Step 2: Create `.dockerignore`**

Keeps the build context tiny (only the Dockerfile + rootfs matter):

```dockerignore
docs/
unraid-template/
cfg/
proj/
*.md
.git
.github
```

- [ ] **Step 3: Create `README.md` skeleton**

```markdown
# scarm-docker

Run [SCARM](https://www.scarm.info/) (Simple Computer Aided Railway Modeller),
a Windows model-railway design program, in your browser via Docker — built for Unraid.

> Unofficial community image. SCARM is freeware by its author; this project only
> packages it under Wine. Named `scarm-docker` to stay distinct from the official project.

Status: work in progress.
```

- [ ] **Step 4: Verify files exist**

Run: `ls -1 .gitignore .dockerignore README.md`
Expected: all three filenames print, no error.

- [ ] **Step 5: Commit**

```bash
git add .gitignore .dockerignore README.md
git commit -m "chore: repo scaffolding (gitignore, dockerignore, readme skeleton)"
```

---

## Task 2: Dockerfile

**Files:**
- Create: `Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

```dockerfile
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
        wget ca-certificates gnupg cabextract xz-utils winbind \
        libgl1-mesa-dri libgl1-mesa-dri:i386 mesa-utils; \
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
```

- [ ] **Step 2: Add a placeholder launcher so the image builds**

The `COPY rootfs/ /` line requires the file to exist. Create a stub now (replaced in Task 3):

Create `rootfs/startapp.sh`:

```sh
#!/bin/sh
echo "placeholder"
```

- [ ] **Step 3: Build the image to verify the Dockerfile is valid**

Run:
```bash
docker build -t scarm-docker:dev .
```
Expected: build completes with `naming to docker.io/library/scarm-docker:dev` (or `writing image ... done`). Wine + Mesa install succeeds; `/opt/SCARMsetup.exe` downloads (~4 MB).

Troubleshooting if it fails:
- If the `debian-12-v4` tag is unavailable, list current tags at https://hub.docker.com/r/jlesage/baseimage-gui/tags and pin the newest `debian-12-*` tag.
- If the WineHQ `.sources` path 404s, confirm the bookworm URL at https://dl.winehq.org/wine-builds/debian/dists/.

- [ ] **Step 4: Commit**

```bash
git add Dockerfile rootfs/startapp.sh
git commit -m "feat: Dockerfile with WineHQ, software OpenGL, baked SCARM installer"
```

---

## Task 3: First-run install + launch script

**Files:**
- Modify: `rootfs/startapp.sh` (replace the placeholder)

- [ ] **Step 1: Replace `rootfs/startapp.sh` with the real launcher**

```sh
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
```

- [ ] **Step 2: Rebuild the image**

Run:
```bash
docker build -t scarm-docker:dev .
```
Expected: build succeeds.

- [ ] **Step 3: Verify the script is syntactically valid inside the image**

Run:
```bash
docker run --rm --entrypoint sh scarm-docker:dev -n /startapp.sh && echo "SYNTAX_OK"
```
Expected: prints `SYNTAX_OK` (the `sh -n` flag checks syntax without executing).

- [ ] **Step 4: Verify the baked installer is present in the image**

Run:
```bash
docker run --rm --entrypoint sh scarm-docker:dev -c 'ls -l /opt/SCARMsetup.exe'
```
Expected: a file around 4 MB is listed.

- [ ] **Step 5: Commit**

```bash
git add rootfs/startapp.sh
git commit -m "feat: first-run silent SCARM install + /projects drive + launch"
```

---

## Task 4: Local end-to-end run (install + GUI)

This task is a manual verification of the running container. Do it on a machine with Docker (your Unraid box works: `docker build`/`docker run` from its console).

**Files:** none (verification only).

- [ ] **Step 1: Start the container with both volumes**

Run:
```bash
docker run -d --name scarm-test \
  -p 5800:5800 \
  -v "$PWD/cfg:/config" \
  -v "$PWD/proj:/projects" \
  scarm-docker:dev
```
Expected: prints a container ID.

- [ ] **Step 2: Watch first-run logs for the install**

Run:
```bash
docker logs -f scarm-test
```
Expected: `[scarm] First run: initializing Wine prefix ...`, then `[scarm] Installing SCARM (silent) ...`, then `[scarm] Launching: .../SCARM.exe`. Press Ctrl-C to stop following.

If it prints `ERROR: SCARM.exe not found`, the silent flags didn't install cleanly under Wine — see the fallback in Task 5.

- [ ] **Step 3: Open the web UI**

Open `http://localhost:5800` (or `http://<docker-host-ip>:5800`) in a browser.
Expected: the SCARM application window is visible in the desktop.

- [ ] **Step 4: Functional check**

In SCARM: place a couple of track pieces on the plan. Open the **3D view** menu once to confirm software OpenGL renders (it may be slow — that's expected). Save the layout via **File → Save**, navigating to drive **P:** so it lands in `/projects` on the host.
Expected: `ls proj/` on the host shows your saved `.scarm` file.

- [ ] **Step 5: Persistence check**

Run:
```bash
docker restart scarm-test
docker logs --tail 20 scarm-test
```
Expected: logs do **not** repeat the install (marker present); SCARM launches directly. Reopen the web UI and open your saved file from drive P: — it loads.

- [ ] **Step 6: Tear down**

Run:
```bash
docker rm -f scarm-test
```

- [ ] **Step 7: Record the result**

If everything passed, note in the commit that the silent install works. If you had to use the fallback, Task 5 covers it. Commit any nothing-to-change checkpoint is unnecessary here; proceed. (No file changes in this task.)

---

## Task 5: Silent-install fallback (only if Task 4 Step 2 failed)

**Do this task only if the silent install did not produce `SCARM.exe`.** If Task 4 passed, skip to Task 6.

**Files:**
- Modify: `rootfs/startapp.sh`

- [ ] **Step 1: Switch the install to interactive-first-run**

Replace the install block in `rootfs/startapp.sh` (the `if [ ! -f "$INSTALL_MARKER" ]` body's install line) so the installer's GUI shows on first launch instead of running silent:

Change this line:
```sh
    wine "$INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true
```
to:
```sh
    # Silent flags unreliable under Wine for this installer: show the installer GUI.
    # The user clicks through Next/Install once; the marker prevents repeats.
    echo "[scarm] Complete the SCARM installer in the browser window, then it launches automatically."
    wine "$INSTALLER" /SP- || true
```

- [ ] **Step 2: Rebuild and re-run Task 4**

Run:
```bash
docker build -t scarm-docker:dev . && docker rm -f scarm-test 2>/dev/null; \
docker run -d --name scarm-test -p 5800:5800 -v "$PWD/cfg:/config" -v "$PWD/proj:/projects" scarm-docker:dev
```
Expected: on first open of `http://localhost:5800`, the SCARM setup wizard appears; click through it; SCARM then launches. Restart no longer shows the wizard.

- [ ] **Step 3: Commit**

```bash
git add rootfs/startapp.sh
git commit -m "fix: fall back to interactive first-run install for Wine compatibility"
```

---

## Task 6: GitHub Actions build → GHCR

**Files:**
- Create: `.github/workflows/build.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: build

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/gmoran1016/scarm-docker
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}
            type=raw,value=2.0.1,enable={{is_default_branch}}
            type=semver,pattern={{version}}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

- [ ] **Step 2: Validate YAML locally**

Run (Python is available cross-platform):
```bash
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/build.yml')); print('YAML_OK')"
```
Expected: prints `YAML_OK`. (If `yaml` is missing, `pip install pyyaml` first, or skip — GitHub will validate on push.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "ci: build linux/amd64 and push to ghcr.io on main and tags"
```

- [ ] **Step 4: Note for the publish step (done in Task 8)**

After the first successful push to GitHub, the package appears at
`https://github.com/gmoran1016?tab=packages`. Open the `scarm-docker` package →
**Package settings** → set visibility to **Public** so Unraid pulls without a login.

---

## Task 7: Unraid template

**Files:**
- Create: `unraid-template/scarm-docker.xml`

- [ ] **Step 1: Write the Unraid template**

```xml
<?xml version="1.0"?>
<Container version="2">
  <Name>scarm-docker</Name>
  <Repository>ghcr.io/gmoran1016/scarm-docker:latest</Repository>
  <Registry>https://ghcr.io/gmoran1016/scarm-docker</Registry>
  <Network>bridge</Network>
  <MyIP/>
  <Shell>sh</Shell>
  <Privileged>false</Privileged>
  <Support/>
  <Project>https://www.scarm.info/</Project>
  <Overview>SCARM (Simple Computer Aided Railway Modeller) running under Wine, accessed from your browser. Unofficial community image; SCARM is freeware by its author. Open the WebUI to design track plans. Save your layouts to the /projects folder (Wine drive P:).</Overview>
  <Category>Tools: HomeAutomation:</Category>
  <WebUI>http://[IP]:[PORT:5800]/</WebUI>
  <TemplateURL/>
  <Icon>https://www.scarm.info/images/scarm_logo.png</Icon>
  <ExtraParams/>
  <PostArgs/>
  <CPUset/>
  <DateInstalled/>
  <DonateText/>
  <DonateLink/>
  <Description>SCARM in a browser via Wine. Design model railway track plans on Unraid.</Description>
  <Networking>
    <Mode>bridge</Mode>
    <Publish>
      <Port>
        <HostPort>5800</HostPort>
        <ContainerPort>5800</ContainerPort>
        <Protocol>tcp</Protocol>
      </Port>
    </Publish>
  </Networking>
  <Config Name="WebUI Port" Target="5800" Default="5800" Mode="tcp" Description="Browser access to SCARM" Type="Port" Display="always" Required="true" Mask="false">5800</Config>
  <Config Name="Config Storage" Target="/config" Default="/mnt/user/appdata/scarm-docker" Mode="rw" Description="Wine prefix and SCARM installation" Type="Path" Display="always" Required="true" Mask="false">/mnt/user/appdata/scarm-docker</Config>
  <Config Name="Projects" Target="/projects" Default="/mnt/user/scarm-projects" Mode="rw" Description="Your saved .scarm layout files (Wine drive P:)" Type="Path" Display="always" Required="true" Mask="false">/mnt/user/scarm-projects</Config>
  <Config Name="PUID" Target="USER_ID" Default="99" Mode="" Description="User ID" Type="Variable" Display="advanced" Required="false" Mask="false">99</Config>
  <Config Name="PGID" Target="GROUP_ID" Default="100" Mode="" Description="Group ID" Type="Variable" Display="advanced" Required="false" Mask="false">100</Config>
  <Config Name="TZ" Target="TZ" Default="America/New_York" Mode="" Description="Timezone" Type="Variable" Display="advanced" Required="false" Mask="false">America/New_York</Config>
  <Config Name="Display Width" Target="DISPLAY_WIDTH" Default="1280" Mode="" Description="Web desktop width" Type="Variable" Display="advanced" Required="false" Mask="false">1280</Config>
  <Config Name="Display Height" Target="DISPLAY_HEIGHT" Default="768" Mode="" Description="Web desktop height" Type="Variable" Display="advanced" Required="false" Mask="false">768</Config>
</Container>
```

- [ ] **Step 2: Validate the XML**

Run:
```bash
python -c "import xml.dom.minidom as m; m.parse('unraid-template/scarm-docker.xml'); print('XML_OK')"
```
Expected: prints `XML_OK`.

- [ ] **Step 3: Commit**

```bash
git add unraid-template/scarm-docker.xml
git commit -m "feat: Unraid Add Container template"
```

---

## Task 8: Finalize README + publish

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace `README.md` with full documentation**

```markdown
# scarm-docker

Run [SCARM](https://www.scarm.info/) (Simple Computer Aided Railway Modeller) — a
Windows model-railway track-design program — in your browser via Docker. Built for Unraid.

> **Unofficial community image.** SCARM is freeware by its author; this project only
> packages it under Wine so it runs in a browser. Named `scarm-docker` to stay distinct
> from the official SCARM project. Pinned to SCARM **2.0.1**.

## What you get

- SCARM's full 2D track-plan editor in a browser tab (noVNC), plus a VNC port.
- The 3D view works via **software OpenGL** (llvmpipe) — usable but slow on large 3D
  scenes; the 2D editor is responsive.
- Persistent Wine prefix + install (`/config`) and a clean folder for your layouts
  (`/projects`, shown inside SCARM as drive **P:**).

## Quick start (any Docker host)

```bash
docker run -d --name scarm \
  -p 5800:5800 \
  -v /path/to/config:/config \
  -v /path/to/projects:/projects \
  ghcr.io/gmoran1016/scarm-docker:latest
```

Open `http://<host>:5800`. On first launch the container installs SCARM (watch
`docker logs -f scarm`); subsequent starts skip straight to the app.

Save/open your layouts on drive **P:** so they land in the `/projects` folder.

## Unraid

Two options:

1. **Template:** add `unraid-template/scarm-docker.xml` from this repo to
   `/boot/config/plugins/dockerMan/templates-user/`, then **Add Container → Template:
   scarm-docker**. Set the `/config` and `/projects` paths to shares you want, and open
   the WebUI.
2. **Manual:** Docker tab → **Add Container**, Repository
   `ghcr.io/gmoran1016/scarm-docker:latest`, map port `5800`, and paths `/config` and
   `/projects`.

## Building / publishing (maintainer)

Pushing to `main` (or a `v*` tag) triggers `.github/workflows/build.yml`, which builds
`linux/amd64` and pushes to `ghcr.io/gmoran1016/scarm-docker`. After the first push,
make the GHCR package **Public** (GitHub → your packages → scarm-docker → Package
settings → Change visibility) so Unraid can pull without authentication.

Build locally:

```bash
docker build -t scarm-docker:dev .
```

Bump SCARM version by editing the `SCARM_VERSION` / `SCARM_INSTALLER_URL` build args in
the `Dockerfile` and the `2.0.1` tag in the workflow.

## Notes & limitations

- **amd64 only** (Unraid is x86_64; Wine on arm64 isn't supported here).
- The free SCARM has the author's own feature limits — unrelated to this container.
- No audio; none needed.
```

- [ ] **Step 2: Verify README renders as valid Markdown (basic sanity)**

Run:
```bash
grep -c "scarm-docker" README.md
```
Expected: a number ≥ 3 (the name appears multiple times), confirming the file wrote.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: full README with Unraid + build instructions"
```

- [ ] **Step 4: Create the GitHub repo and push (manual, one-time)**

```bash
git branch -M main
git remote add origin https://github.com/gmoran1016/scarm-docker.git
git push -u origin main
```
Then in GitHub: create the repo `scarm-docker` first if it doesn't exist (or use `gh repo create gmoran1016/scarm-docker --public --source . --push`). Watch the **Actions** tab for a green build, then set the package public per Task 6 Step 4.

- [ ] **Step 5: Deploy on Unraid and run the smoke test**

Pull `ghcr.io/gmoran1016/scarm-docker:latest` on Unraid via the template, open the WebUI,
and repeat the Task 4 functional + persistence checks against the published image.

---

## Self-Review notes

- **Spec coverage:** base image + Wine + Mesa (Task 2) ✓; baked installer (Task 2) ✓;
  first-run guarded install + `WINEPREFIX=/config/wine` (Task 3) ✓; `/config` + `/projects`
  drive P: (Task 3, Task 7) ✓; software OpenGL (Task 2) ✓; amd64-only (Task 2, Task 6) ✓;
  ports 5800/5900 (base image; Task 7 maps 5800) ✓; GHCR + Actions, public package
  (Task 6) ✓; Unraid template (Task 7) ✓; smoke test (Task 4, Task 8) ✓; version pinning
  `latest`+`2.0.1` (Task 6) ✓. Silent-install unknown handled with explicit fallback
  (Task 5) ✓.
- **Deviations from spec (approved with user):** installer is downloaded at build time
  rather than committed to the repo (same runtime result, cleaner repo, no
  redistribution); first-run install lives in `startapp.sh` rather than `cont-init.d`
  (runs as the app user → correct Wine-prefix ownership).
- **Type/name consistency:** `WINEPREFIX=/config/wine`, marker `.scarm-installed`, drive
  `P:` → `/projects`, image `ghcr.io/gmoran1016/scarm-docker` used consistently across
  Dockerfile, startapp.sh, workflow, template, and README.
- **VNC 5900:** exposed by the base image; intentionally not mapped in the Unraid template
  (web UI is the primary path) — users can add it manually if they want a native client.
```
