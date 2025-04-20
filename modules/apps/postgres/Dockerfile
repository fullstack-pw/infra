FROM pgvector/pgvector:pg15 AS builder

FROM bitnami/postgresql:15.4.0

COPY --from=builder /usr/lib/postgresql/16/lib/vector.so /opt/bitnami/postgresql/lib/
COPY --from=builder /usr/share/postgresql/16/extension/vector* /opt/bitnami/postgresql/share/extension/
