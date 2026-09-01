# MSOY Docker builder

This repository is a legacy Java/Ant/Flex project. The Docker image is intentionally a **builder/development image** so the old toolchain is reproducible without installing it directly on the host.

## Image

GitHub Actions publishes multi-architecture images to:

```text
ghcr.io/nekosunevr/msoy
```

Published tags include `latest` from the default branch, branch names, Git tags, and commit SHA tags.

## Pull from GitHub Container Registry

```bash
docker pull ghcr.io/nekosunevr/msoy:latest
docker run --rm -it ghcr.io/nekosunevr/msoy:latest
```

The source tree required by Ant is baked into the image at `/opt/msoy`. The normal Compose deployment intentionally does **not** bind-mount the host directory over `/opt/msoy`; doing that from an incomplete deployment folder hides required files such as `etc/build_settings.properties.dist`.

## Docker Compose using GHCR

You only need the Compose file and optional `.env` for the normal GHCR deployment. Copy `.env.example` to `.env`, change the database password, then run:

```bash
docker compose pull
docker compose up
```

Compose starts PostgreSQL and the MSOY builder using the complete source tree already included in `ghcr.io/nekosunevr/msoy`.

To refresh after an image update:

```bash
docker compose down
docker compose pull
docker compose up --force-recreate
```

## Local source development

Only use the development override when the current directory is a **complete clone** of this repository:

```bash
git clone https://github.com/NekoSuneVR/msoy.git
cd msoy
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

`docker-compose.dev.yml` deliberately mounts the complete checkout at `/opt/msoy` so local source edits are immediately visible in the builder. Do not use that override from a folder containing only `docker-compose.yml`.

## Build locally without Compose

```bash
docker build -t msoy-builder .
docker run --rm -it msoy-builder
```

The default command runs:

```bash
ant compile
```

Choose another Ant target with `MSOY_BUILD_TARGET`, for example:

```bash
docker run --rm -e MSOY_BUILD_TARGET=tests msoy-builder
```

Full `distall` still requires the legacy Flex SDK expected by the original Ant build. Mount/provide that SDK before choosing `distall`.

## Endpoint configuration

The original repository contains development defaults that reference old Whirled hosts. The Docker entrypoint rewrites the generated test configuration on startup so deployments do not depend on dead public endpoints.

Supported variables:

- `MSOY_SERVER_URL`
- `MSOY_SERVER_HOST`
- `MSOY_HTTP_PORT`
- `MSOY_SERVER_PORT`
- `MSOY_SOCKET_POLICY_PORT`
- `MSOY_DB_HOST`
- `MSOY_DB_PORT`
- `MSOY_DB_NAME`
- `MSOY_DB_USER`
- `MSOY_DB_PASSWORD`
- `MSOY_MEDIA_URL`
- `MSOY_STATIC_MEDIA_URL`
- `MSOY_BILLING_URL`
- `MSOY_SERVER_ROOT`
- `MSOY_MEDIA_DIR`
- `MSOY_BURL_DB_DRIVER`
- `MSOY_BURL_DB_URL`

URLs that require a trailing slash are normalized by the entrypoint.

## Important legacy limitation

MSOY was originally built around Java 6/8-era libraries, GWT, ActionScript/Flex, Flash clients, and external Three Rings components. Docker makes the build environment reproducible, but it cannot make retired third-party services or Flash browser support exist again. External integrations should be configured to replacements or disabled rather than silently calling dead production services.
