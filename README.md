# scarm-docker

Run [SCARM](https://www.scarm.info/) (Simple Computer Aided Railway Modeller) — a
Windows model-railway track-design program — in your browser via Docker. Built for Unraid.

> **Unofficial community image.** SCARM is freeware by its author; this project only
> packages it under Wine so it runs in a browser. Named `scarm-docker` to stay distinct
> from the official SCARM project. Pinned to SCARM **2.0.1**.

## What you get

- SCARM's full track-plan editor in a browser tab, on a lightweight KasmVNC desktop
  ([LinuxServer.io](https://www.linuxserver.io/) base image).
- Renders through your host **GPU** (see below) — SCARM draws its canvas with OpenGL, so
  a GPU (`/dev/dri`) is required; without it the canvas renders black.
- Persistent Wine prefix + install (`/config`) and a clean folder for your layouts
  (`/projects`, shown inside SCARM as drive **P:**).
- Auto-relaunches SCARM if you close it, so you never need to restart the container.

## Quick start (any Docker host)

```bash
docker run -d --name scarm \
  -p 3000:3000 \
  --device /dev/dri:/dev/dri \
  -v /path/to/config:/config \
  -v /path/to/projects:/projects \
  ghcr.io/gmoran1016/scarm-docker:latest
```

Open `http://<host>:3000`. On first launch the container installs SCARM (watch
`docker logs -f scarm`); subsequent starts skip straight to the app.

> **GPU passthrough (`--device /dev/dri`) is strongly recommended.** SCARM draws its
> canvas with OpenGL; without a GPU it falls back to software rendering (llvmpipe) and the
> canvas renders **black**. Passing the host GPU (an Intel iGPU is ideal and common on
> Unraid) gives hardware OpenGL and correct rendering. On most hosts `/dev/dri` is
> world-accessible; if yours is `root:video 0660`, also add the container to that group.

Save/open your layouts on drive **P:** so they land in the `/projects` folder.

## Unraid

Two options:

1. **Template:** add `unraid-template/scarm-docker.xml` from this repo to
   `/boot/config/plugins/dockerMan/templates-user/`, then **Add Container → Template:
   scarm-docker**. Set the `/config` and `/projects` paths to shares you want, and open
   the WebUI.
2. **Manual:** Docker tab → **Add Container**, Repository
   `ghcr.io/gmoran1016/scarm-docker:latest`, map port `3000`, and paths `/config` and
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

## Troubleshooting

**`SCARM.exe not found` / a terminal opens instead of SCARM.** The silent install didn't
produce an executable under Wine. The launcher retries the install on every start (it keys
off whether `SCARM.exe` exists), so it won't get stuck — but if it keeps failing, switch to
an interactive first-run install: edit `root/defaults/autostart` and change the install line

```sh
wine "$INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true
```

to

```sh
wine "$INSTALLER" /SP- || true
```

then rebuild. The SCARM setup wizard will appear in the browser on first launch; click
through it once and SCARM starts. (To recover a bad `/config`, delete the `/config/wine`
folder and restart to reinstall cleanly.)

**Canvas is blank/white after SCARM reopens.** When you open the browser tab, SCARM
renders fully. But SCARM draws its canvas with OpenGL and only fully repaints on a
browser-driven resize — so if SCARM is closed and auto-relaunches, the canvas can stay
blank until you **refresh the tab (F5)** or resize the browser window. This is a known
limitation of running a Wine OpenGL app through a hardware-accelerated web desktop; the
refresh restores it instantly. (The window auto-maximizes to fit your browser on launch.)

## Notes & limitations

- **amd64 only** (Unraid is x86_64; Wine on arm64 isn't supported here).
- The free SCARM has the author's own feature limits — unrelated to this container.
- The web desktop is unauthenticated by default; keep it on your LAN or put it behind a
  reverse proxy / the LinuxServer `CUSTOM_USER`+`PASSWORD` variables if you expose it.
