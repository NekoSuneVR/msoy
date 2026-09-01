# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:8-jdk-jammy

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

WORKDIR /opt/msoy
COPY . .

RUN chmod +x bin/* docker/entrypoint.sh \
    && mkdir -p etc/test pages/media log run dist \
    && cp -n etc/build_settings.properties.dist etc/test/build_settings.properties \
    && cp -n etc/msoy-server.conf.dist etc/test/msoy-server.conf \
    && cp -n etc/msoy-server.properties.dist etc/test/msoy-server.properties \
    && cp -n etc/burl-server.conf.dist etc/test/burl-server.conf \
    && cp -n etc/burl-server.properties.dist etc/test/burl-server.properties

ENV MSOY_BUILD_TARGET=compile \
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

ENTRYPOINT ["/opt/msoy/docker/entrypoint.sh"]
CMD ["build"]
