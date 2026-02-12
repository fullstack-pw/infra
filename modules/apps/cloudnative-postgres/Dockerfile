FROM tensorchord/pgvecto-rs:pg15-v0.3.0 AS builder

FROM ghcr.io/cloudnative-pg/postgresql:15

USER root

# Reminder: Verify right folders when using  ghcr.io/cloudnative-pg/postgresql:15
COPY --from=builder /usr/lib/postgresql/15/lib/vectors.so /usr/lib/postgresql/15/lib/
COPY --from=builder /usr/share/postgresql/15/extension/vectors* /usr/share/postgresql/15/extension/

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgomp1 \
    postgresql-15-wal2json \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER postgres
ENV POSTGRESQL_EXTRA_FLAGS="-c shared_preload_libraries=vectors.so"
