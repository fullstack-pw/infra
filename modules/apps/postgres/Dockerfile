FROM tensorchord/pgvecto.rs:pg15-v0.2.0 AS builder

FROM bitnami/postgresql:15.4.0

USER root

# Copy the pgvecto.rs extension files from the builder image
COPY --from=builder /usr/lib/postgresql/15/lib/pgvecto-rs.so /opt/bitnami/postgresql/lib/
COPY --from=builder /usr/share/postgresql/15/extension/pgvecto-rs* /opt/bitnami/postgresql/share/extension/

# Install necessary dependencies for pgvecto.rs
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch back to non-root user
USER 1001

# Configure PostgreSQL to preload the pgvecto.rs library
ENV POSTGRESQL_EXTRA_FLAGS="-c shared_preload_libraries=pgvecto-rs.so"