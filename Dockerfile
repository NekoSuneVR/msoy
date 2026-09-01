# syntax=docker/dockerfile:1.7

# mSOY's Java source level and a number of its build tools require Java 8.
FROM eclipse-temurin:8-jdk-jammy AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG WHIRLED_API_COMMIT=98c15e4d33b4340ce0e9b84b0aca1dd1a38f8508

RUN apt-get update \
    && apt-get install -y --no-install-recommends ant ca-certificates git gzip maven \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# mSOY depends on com.threerings:whirled-code:1.1-SNAPSHOT, which was never
# published as a durable Maven Central release. Build that exact API revision
# locally so the historic build no longer depends on a vanished snapshot repo.
RUN git clone https://github.com/greyhavens/whirled-api.git /tmp/whirled-api \
    && git -C /tmp/whirled-api checkout "$WHIRLED_API_COMMIT" \
    && mvn -q -N -f /tmp/whirled-api/pom.xml -DskipTests install \
    && mvn -q -f /tmp/whirled-api/core/pom.xml -DskipTests install

RUN chmod +x docker/prepare-config.sh \
    && ./docker/prepare-config.sh etc/test

# Build the Java server plus its GWT web application. The historic distall
# target additionally requires Flex 3, Flash clients and a native Thane VM;
# those obsolete components are intentionally not required by this image.
RUN ant -Ddeployment=test mavendeps dist gclients

FROM eclipse-temurin:8-jre-jammy AS runtime

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system msoy \
    && useradd --system --gid msoy --home-dir /opt/msoy --shell /usr/sbin/nologin msoy

WORKDIR /opt/msoy

COPY --from=builder --chown=msoy:msoy /src/dist ./dist
COPY --from=builder --chown=msoy:msoy /src/pages ./pages
COPY --from=builder --chown=msoy:msoy /src/rsrc ./rsrc
COPY --from=builder --chown=msoy:msoy /src/data ./data
COPY --from=builder --chown=msoy:msoy /src/etc/logging.properties ./etc/logging.properties
COPY --from=builder --chown=msoy:msoy /src/bin/msoyjava ./bin/msoyjava
COPY --from=builder --chown=msoy:msoy /src/bin/msoyserver ./bin/msoyserver
COPY --chown=msoy:msoy docker/entrypoint.sh /usr/local/bin/msoy-entrypoint

RUN chmod +x /usr/local/bin/msoy-entrypoint ./bin/msoyjava ./bin/msoyserver \
    && mkdir -p pages/media dist/tmp /tmp/msoy \
    && chown -R msoy:msoy /opt/msoy /tmp/msoy

USER msoy

ENV MSOY_PUBLIC_URL=http://localhost:8080/ \
    MSOY_SERVER_HOST=localhost \
    MSOY_HTTP_PORT=8080 \
    MSOY_SERVER_PORTS=47624 \
    MSOY_SOCKET_POLICY_PORT=47623 \
    MSOY_DB_HOST=postgres \
    MSOY_DB_PORT=5432 \
    MSOY_DB_NAME=msoy \
    MSOY_DB_USER=msoy \
    MSOY_DB_PASSWORD=msoy \
    MSOY_JAVA_MEMORY=512M

EXPOSE 8080 47623 47624
VOLUME ["/opt/msoy/pages/media"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=5 \
    CMD curl --fail --silent --show-error "http://127.0.0.1:${MSOY_HTTP_PORT}/" >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/msoy-entrypoint"]
CMD ["./bin/msoyserver"]
