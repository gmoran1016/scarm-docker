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
