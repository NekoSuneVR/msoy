# syntax=docker/dockerfile:1.7

# MSOY's dependency resolution and Java compilation are architecture-independent.
# Validate them once on the native build platform instead of repeating the heavy
# legacy Maven/Ant work under QEMU for every target architecture.
FROM --platform=$BUILDPLATFORM eclipse-temurin:8-jdk-jammy AS validated

ARG DEBIAN_FRONTEND=noninteractive
ARG MSOY_BUILD_TARGET=compile

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ant \
       ca-certificates \
       curl \
       git \
       maven \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.m2
COPY docker/maven-settings.xml /root/.m2/settings.xml
COPY docker/entrypoint.sh /usr/local/bin/msoy-entrypoint
COPY docker/bootstrap-legacy-artifacts.sh /usr/local/bin/msoy-bootstrap-legacy-artifacts
RUN chmod 0755 /usr/local/bin/msoy-entrypoint /usr/local/bin/msoy-bootstrap-legacy-artifacts

WORKDIR /opt/msoy
COPY . .

RUN chmod +x bin/* \
    && mkdir -p etc/test pages/media log run dist \
    && cp -n etc/build_settings.properties.dist etc/test/build_settings.properties \
    && cp -n etc/msoy-server.conf.dist etc/test/msoy-server.conf \
    && cp -n etc/msoy-server.properties.dist etc/test/msoy-server.properties \
    && cp -n etc/burl-server.conf.dist etc/test/burl-server.conf \
    && cp -n etc/burl-server.properties.dist etc/test/burl-server.properties \
    && test -x /usr/local/bin/msoy-entrypoint \
    && test -x /usr/local/bin/msoy-bootstrap-legacy-artifacts

ENV MSOY_BUILD_TARGET=${MSOY_BUILD_TARGET} \
    MSOY_SERVER_URL=http://localhost:8080/ \
    MSOY_SERVER_HOST=localhost \
    MSOY_HTTP_PORT=8080 \
    MSOY_SERVER_PORT=47624 \
    MSOY_SOCKET_POLICY_PORT=47623 \
    MSOY_DB_HOST=postgres \
    MSOY_DB_PORT=5432 \
    MSOY_DB_NAME=msoy \
    MSOY_DB_USER=msoy \
    MSOY_DB_PASSWORD=msoy \
    MSOY_MEDIA_URL=http://localhost:8080/media/ \
    MSOY_STATIC_MEDIA_URL=http://localhost:8080/media/static/ \
    MSOY_BILLING_URL=http://localhost:8080/

# Restore coordinates that disappeared with Three Rings' original private Maven
# infrastructure, then execute the real clean Java build. A dependency or javac
# failure stops the Docker build and prevents a broken GHCR image being published.
RUN /usr/local/bin/msoy-bootstrap-legacy-artifacts \
    && /usr/local/bin/msoy-entrypoint build


FROM eclipse-temurin:8-jdk-jammy AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG MSOY_BUILD_TARGET=compile

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ant \
       ca-certificates \
       curl \
       git \
       maven \
       postgresql-client \
       gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Carry the validated source tree, compiled dist output and restored legacy Maven
# coordinates into every target-architecture image. The final image still keeps
# Ant/Maven/JDK installed, so it remains a usable builder/development image.
COPY --from=validated /root/.m2 /root/.m2
COPY --from=validated /usr/local/bin/msoy-entrypoint /usr/local/bin/msoy-entrypoint
COPY --from=validated /usr/local/bin/msoy-bootstrap-legacy-artifacts /usr/local/bin/msoy-bootstrap-legacy-artifacts
COPY --from=validated /opt/msoy /opt/msoy

WORKDIR /opt/msoy

ENV MSOY_BUILD_TARGET=${MSOY_BUILD_TARGET} \
    MSOY_SERVER_URL=http://localhost:8080/ \
    MSOY_SERVER_HOST=localhost \
    MSOY_HTTP_PORT=8080 \
    MSOY_SERVER_PORT=47624 \
    MSOY_SOCKET_POLICY_PORT=47623 \
    MSOY_DB_HOST=postgres \
    MSOY_DB_PORT=5432 \
    MSOY_DB_NAME=msoy \
    MSOY_DB_USER=msoy \
    MSOY_DB_PASSWORD=msoy \
    MSOY_MEDIA_URL=http://localhost:8080/media/ \
    MSOY_STATIC_MEDIA_URL=http://localhost:8080/media/static/ \
    MSOY_BILLING_URL=http://localhost:8080/

EXPOSE 8080 47623 47624

ENTRYPOINT ["/usr/local/bin/msoy-entrypoint"]
CMD ["build"]
