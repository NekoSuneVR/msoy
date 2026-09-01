#!/usr/bin/env bash
set -euo pipefail

cd /opt/msoy

TEST_DIR="etc/test"
mkdir -p "$TEST_DIR" pages/media log run dist

copy_if_missing() {
  local source="$1"
  local dest="$2"
  if [[ ! -f "$dest" ]]; then
    cp "$source" "$dest"
  fi
}

copy_if_missing etc/build_settings.properties.dist "$TEST_DIR/build_settings.properties"
copy_if_missing etc/msoy-server.conf.dist "$TEST_DIR/msoy-server.conf"
copy_if_missing etc/msoy-server.properties.dist "$TEST_DIR/msoy-server.properties"
copy_if_missing etc/burl-server.conf.dist "$TEST_DIR/burl-server.conf"
copy_if_missing etc/burl-server.properties.dist "$TEST_DIR/burl-server.properties"

set_property() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/[&|]/\\&/g')"

  if grep -Eq "^[[:space:]#]*${key}[[:space:]]*=" "$file"; then
    sed -Ei "s|^[[:space:]#]*${key}[[:space:]]*=.*$|${key} = ${escaped}|" "$file"
  else
    printf '\n%s = %s\n' "$key" "$value" >> "$file"
  fi
}

MSOY_SERVER_URL="${MSOY_SERVER_URL:-http://localhost:8080/}"
MSOY_SERVER_HOST="${MSOY_SERVER_HOST:-localhost}"
MSOY_HTTP_PORT="${MSOY_HTTP_PORT:-8080}"
MSOY_SERVER_PORT="${MSOY_SERVER_PORT:-47624}"
MSOY_SOCKET_POLICY_PORT="${MSOY_SOCKET_POLICY_PORT:-47623}"
MSOY_DB_HOST="${MSOY_DB_HOST:-postgres}"
MSOY_DB_PORT="${MSOY_DB_PORT:-5432}"
MSOY_DB_NAME="${MSOY_DB_NAME:-msoy}"
MSOY_DB_USER="${MSOY_DB_USER:-msoy}"
MSOY_DB_PASSWORD="${MSOY_DB_PASSWORD:-msoy}"
MSOY_MEDIA_URL="${MSOY_MEDIA_URL:-${MSOY_SERVER_URL}media/}"
MSOY_STATIC_MEDIA_URL="${MSOY_STATIC_MEDIA_URL:-${MSOY_SERVER_URL}media/static/}"
MSOY_BILLING_URL="${MSOY_BILLING_URL:-${MSOY_SERVER_URL}}"
MSOY_SERVER_ROOT="${MSOY_SERVER_ROOT:-/opt/msoy}"
MSOY_MEDIA_DIR="${MSOY_MEDIA_DIR:-/opt/msoy/pages/media}"

case "$MSOY_SERVER_URL" in */) ;; *) MSOY_SERVER_URL="${MSOY_SERVER_URL}/" ;; esac
case "$MSOY_MEDIA_URL" in */) ;; *) MSOY_MEDIA_URL="${MSOY_MEDIA_URL}/" ;; esac
case "$MSOY_STATIC_MEDIA_URL" in */) ;; *) MSOY_STATIC_MEDIA_URL="${MSOY_STATIC_MEDIA_URL}/" ;; esac
case "$MSOY_BILLING_URL" in */) ;; *) MSOY_BILLING_URL="${MSOY_BILLING_URL}/" ;; esac

PROPS="$TEST_DIR/msoy-server.properties"
set_property "$PROPS" server_url "$MSOY_SERVER_URL"
set_property "$PROPS" server_host "$MSOY_SERVER_HOST"
set_property "$PROPS" http_port "$MSOY_HTTP_PORT"
set_property "$PROPS" server_ports "$MSOY_SERVER_PORT"
set_property "$PROPS" socket_policy_port "$MSOY_SOCKET_POLICY_PORT"
set_property "$PROPS" server_root "$MSOY_SERVER_ROOT"
set_property "$PROPS" media_dir "$MSOY_MEDIA_DIR"
set_property "$PROPS" media_url "$MSOY_MEDIA_URL"
set_property "$PROPS" static_media_url "$MSOY_STATIC_MEDIA_URL"
set_property "$PROPS" billing_url "$MSOY_BILLING_URL"
set_property "$PROPS" db.default.server "$MSOY_DB_HOST"
set_property "$PROPS" db.default.port "$MSOY_DB_PORT"
set_property "$PROPS" db.default.database "$MSOY_DB_NAME"
set_property "$PROPS" db.default.username "$MSOY_DB_USER"
set_property "$PROPS" db.default.password "$MSOY_DB_PASSWORD"

BURL_PROPS="$TEST_DIR/burl-server.properties"
set_property "$BURL_PROPS" server_host "$MSOY_SERVER_HOST"
set_property "$BURL_PROPS" server_root "$MSOY_SERVER_ROOT"

if [[ -n "${MSOY_BURL_DB_URL:-}" ]]; then
  set_property "$BURL_PROPS" db.default.url "$MSOY_BURL_DB_URL"
fi
if [[ -n "${MSOY_BURL_DB_DRIVER:-}" ]]; then
  set_property "$BURL_PROPS" db.default.driver "$MSOY_BURL_DB_DRIVER"
fi
set_property "$BURL_PROPS" db.default.username "$MSOY_DB_USER"
set_property "$BURL_PROPS" db.default.password "$MSOY_DB_PASSWORD"

command="${1:-build}"
shift || true

case "$command" in
  build)
    target="${MSOY_BUILD_TARGET:-compile}"
    echo "Building MSOY with Ant target: ${target}"
    exec ant "$target" "$@"
    ;;
  shell)
    exec /bin/bash "$@"
    ;;
  server)
    if [[ ! -f dist/msoy-server.conf ]]; then
      echo "dist/msoy-server.conf is missing. Run a build target that creates the dist runtime first." >&2
      exit 2
    fi
    exec ./bin/msoyserver "$@"
    ;;
  *)
    exec "$command" "$@"
    ;;
esac
