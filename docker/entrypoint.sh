#!/bin/sh
set -eu

cd /opt/msoy

PROPS=dist/msoy-server.properties
CONF=dist/msoy-server.conf

if [ -n "${MSOY_CONFIG_DIR:-}" ] && [ -d "$MSOY_CONFIG_DIR" ]; then
    for name in msoy-server.properties msoy-server.conf burl-server.properties burl-server.conf; do
        if [ -f "$MSOY_CONFIG_DIR/$name" ]; then
            cp "$MSOY_CONFIG_DIR/$name" "dist/$name"
        fi
    done
fi

if [ ! -f "$PROPS" ] || [ ! -f "$CONF" ]; then
    echo "mSOY runtime configuration is missing from dist/." >&2
    exit 78
fi

PUBLIC_URL=${MSOY_PUBLIC_URL:-http://localhost:8080/}
case "$PUBLIC_URL" in
    */) ;;
    *) PUBLIC_URL="$PUBLIC_URL/" ;;
esac

SERVER_HOST=${MSOY_SERVER_HOST:-localhost}
HTTP_PORT=${MSOY_HTTP_PORT:-8080}
SERVER_PORTS=${MSOY_SERVER_PORTS:-47624}
POLICY_PORT=${MSOY_SOCKET_POLICY_PORT:-47623}
DB_HOST=${MSOY_DB_HOST:-postgres}
DB_PORT=${MSOY_DB_PORT:-5432}
DB_NAME=${MSOY_DB_NAME:-msoy}
DB_USER=${MSOY_DB_USER:-msoy}
DB_PASSWORD=${MSOY_DB_PASSWORD:-msoy}
MEDIA_DIR=${MSOY_MEDIA_DIR:-/opt/msoy/pages/media}
MEDIA_URL=${MSOY_MEDIA_URL:-${PUBLIC_URL}media/}
STATIC_MEDIA_URL=${MSOY_STATIC_MEDIA_URL:-${MEDIA_URL}static/}
BILLING_URL=${MSOY_BILLING_URL:-${PUBLIC_URL}billing/}

# Replace stale production-domain SEO files with URLs for this deployment.
cat > pages/robots.txt <<EOF
User-agent: *
Allow: /
Sitemap: ${PUBLIC_URL}sitemap.xml
EOF

cat > pages/sitemap.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url><loc>${PUBLIC_URL}</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>
    <url><loc>${PUBLIC_URL}go/games</loc><changefreq>always</changefreq><priority>0.95</priority></url>
    <url><loc>${PUBLIC_URL}go/people</loc><changefreq>always</changefreq><priority>0.6</priority></url>
    <url><loc>${PUBLIC_URL}go/groups</loc><changefreq>always</changefreq><priority>0.6</priority></url>
</urlset>
EOF

# These files use Java properties semantics. Appending overrides the stale legacy
# defaults while keeping the original distribution file available for reference.
cat >> "$PROPS" <<EOF

# Runtime container overrides.
server_url = $PUBLIC_URL
server_host = $SERVER_HOST
http_port = $HTTP_PORT
server_ports = $SERVER_PORTS
socket_policy_port = $POLICY_PORT
server_root = /opt/msoy
media_dir = $MEDIA_DIR
media_url = $MEDIA_URL
static_media_url = $STATIC_MEDIA_URL
toybox.resource_dir = $MEDIA_DIR
billing_url = $BILLING_URL
ga_account =
db.default.server = $DB_HOST
db.default.port = $DB_PORT
db.default.database = $DB_NAME
db.default.username = $DB_USER
db.default.password = $DB_PASSWORD
EOF

# Keep the optional bureau launcher on the same database when its config exists.
if [ -f dist/burl-server.properties ]; then
    cat >> dist/burl-server.properties <<EOF

# Runtime container overrides.
server_host = $SERVER_HOST
server_root = /opt/msoy
db.default.driver = org.postgresql.Driver
db.default.url = jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME
db.default.username = $DB_USER
db.default.password = $DB_PASSWORD
EOF
fi

mkdir -p "$MEDIA_DIR" dist/tmp /tmp/msoy
export MSOY_RSRC_CACHE_DIR=${MSOY_RSRC_CACHE_DIR:-/tmp/msoy}
export MSOY_NODE=${MSOY_NODE:-msoy1}
export MSOY_HOSTNAME=${MSOY_HOSTNAME:-$SERVER_HOST}
export DEPOT_PG83=${DEPOT_PG83:-false}

if [ -n "${MSOY_JAVA_MEMORY:-}" ]; then
    export SERVER_MEMORY=$MSOY_JAVA_MEMORY
fi

exec "$@"
