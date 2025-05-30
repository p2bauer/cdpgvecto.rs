ARG ALPINE_VERSION=3.21.3
ARG CRUNCHYDATA_VERSION=ubi9-16.9-2520
ARG PG_MAJOR=16

FROM alpine:${ALPINE_VERSION} AS builder

RUN apk add --no-cache curl alien rpm binutils xz

WORKDIR /tmp

ARG PG_MAJOR
ARG TARGETARCH
# renovate: datasource=github-releases depName=tensorchord/pgvecto.rs
ARG PGVECTORS_TAG=v0.4.0
ARG VECTORCHORD_TAG=0.4.1

WORKDIR /tmp/pgvectors

RUN curl --fail -o pgvectors.deb -sSL https://github.com/tensorchord/pgvecto.rs/releases/download/${PGVECTORS_TAG}/vectors-pg${PG_MAJOR}_${PGVECTORS_TAG:1}_${TARGETARCH}.deb && \
    alien -r pgvectors.deb && \
    rm -f pgvectors.deb

# RUN echo https://github.com/tensorchord/VectorChord/releases/download/${VECTORCHORD_TAG}/postgresql-${PG_MAJOR}-vchord_${VECTORCHORD_TAG:1}-1_${TARGETARCH}.deb
# https://github.com/tensorchord/VectorChord/releases/download/0.4.1/postgresql-16-vchord_0.4.1-1_arm64.deb

RUN rpm2cpio /tmp/pgvectors/*.rpm | cpio -idmv

WORKDIR /tmp/vchord

RUN curl --fail -o vchord.deb -sSL https://github.com/tensorchord/VectorChord/releases/download/${VECTORCHORD_TAG}/postgresql-${PG_MAJOR}-vchord_0${VECTORCHORD_TAG:1}-1_${TARGETARCH}.deb && \
    alien -r vchord.deb && \
    rm -f vchord.deb

RUN rpm2cpio /tmp/vchord/*.rpm | cpio -idmv


ARG CRUNCHYDATA_VERSION
FROM registry.developers.crunchydata.com/crunchydata/crunchy-postgres:${CRUNCHYDATA_VERSION}

ARG PG_MAJOR

COPY --chown=root:root --chmod=755 --from=builder /tmp/pgvectors/usr/lib/postgresql/${PG_MAJOR}/lib/vectors.so /usr/pgsql-${PG_MAJOR}/lib/
COPY --chown=root:root --chmod=755 --from=builder /tmp/vchord/usr/lib/postgresql/${PG_MAJOR}/lib/vchord.so /usr/pgsql-${PG_MAJOR}/lib/
COPY --chown=root:root --chmod=755 --from=builder /tmp/pgvectors/usr/share/postgresql/${PG_MAJOR}/extension/vectors* /usr/pgsql-${PG_MAJOR}/share/extension/
COPY --chown=root:root --chmod=755 --from=builder /tmp/vchord/usr/share/postgresql/${PG_MAJOR}/extension/vchord* /usr/pgsql-${PG_MAJOR}/share/extension/

# Numeric User ID for Default Postgres User
USER 26

COPY app/pgvectors.sql /docker-entrypoint-initdb.d/
