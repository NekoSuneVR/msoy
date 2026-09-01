# MSOY Docker builder

This repository is a legacy Java/Ant/Flex project. The Docker image is intentionally a **builder/development image** so the old toolchain is reproducible without installing it directly on the host.

## Image

GitHub Actions publishes multi-architecture images to:

```text
ghcr.io/nekosunevr/msoy
```

Published tags include `latest` from the default branch, branch names, Git tags, and commit SHA tags.

## Build locally

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

## Pull from GitHub Container Registry

```bash
docker pull ghcr.io/nekosunevr/msoy:latest
docker run --rm -it ghcr.io/nekosunevr/msoy:latest
```

## Docker Compose

Copy `.env.example` to `.env`, change the database password, then run:

```bash
docker compose up --build
```

Compose starts PostgreSQL and the MSOY builder.

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
