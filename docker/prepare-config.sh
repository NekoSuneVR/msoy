#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET_DIR=${1:-"$ROOT_DIR/etc/test"}
mkdir -p "$TARGET_DIR"

copy_default() {
    name=$1
    if [ ! -f "$TARGET_DIR/$name" ]; then
        cp "$ROOT_DIR/etc/$name.dist" "$TARGET_DIR/$name"
    fi
}

copy_default build_settings.properties
copy_default burl-server.conf
copy_default burl-server.properties
copy_default msoy-server.conf
copy_default msoy-server.properties

PUBLIC_URL=${MSOY_PUBLIC_URL:-http://localhost:8080/}
case "$PUBLIC_URL" in
    */) ;;
    *) PUBLIC_URL="$PUBLIC_URL/" ;;
esac

SERVER_HOST=${MSOY_SERVER_HOST:-localhost}
DB_HOST=${MSOY_DB_HOST:-postgres}
DB_PORT=${MSOY_DB_PORT:-5432}
DB_NAME=${MSOY_DB_NAME:-msoy}
DB_USER=${MSOY_DB_USER:-msoy}
DB_PASSWORD=${MSOY_DB_PASSWORD:-msoy}

# Ant properties are deliberately appended: java.util.Properties and Ant both use
# the last explicit value for duplicate keys in these generated developer files.
cat >> "$TARGET_DIR/msoy-server.properties" <<EOF

# Docker/build defaults. Runtime values are appended by docker/entrypoint.sh.
server_url = $PUBLIC_URL
server_host = $SERVER_HOST
server_root = /opt/msoy
media_dir = /opt/msoy/pages/media
media_url = ${PUBLIC_URL}media/
static_media_url = ${PUBLIC_URL}media/static/
toybox.resource_dir = /opt/msoy/pages/media
billing_url = ${MSOY_BILLING_URL:-${PUBLIC_URL}billing/}
ga_account =
cloud_signing_key_id =
announce_group_id = 0
db.default.server = $DB_HOST
db.default.port = $DB_PORT
db.default.database = $DB_NAME
db.default.username = $DB_USER
db.default.password = $DB_PASSWORD
EOF

cat >> "$TARGET_DIR/msoy-server.conf" <<'EOF'

# Container-friendly defaults.
SMTP_HOST=
DEPOT_PG83=false
EOF

cat >> "$TARGET_DIR/burl-server.properties" <<EOF

# Container-friendly defaults.
server_host = $SERVER_HOST
server_root = /opt/msoy
db.default.driver = org.postgresql.Driver
db.default.url = jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME
db.default.username = $DB_USER
db.default.password = $DB_PASSWORD
EOF

printf 'Prepared mSOY build configuration in %s\n' "$TARGET_DIR"
