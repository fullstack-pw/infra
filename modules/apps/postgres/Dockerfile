FROM pgvector/pgvector:pg15 AS builder

FROM bitnami/postgresql:15.4.0

USER root

COPY --from=builder /usr/lib/postgresql/15/lib/vector.so /opt/bitnami/postgresql/lib/
COPY --from=builder /usr/share/postgresql/15/extension/vector* /opt/bitnami/postgresql/share/extension/

USER 1001

ENV POSTGRESQL_EXTRA_FLAGS="-c shared_preload_libraries=vector.so"