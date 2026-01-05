FROM ghcr.io/cloudnative-pg/postgresql:15

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-15-wal2json \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER postgres
