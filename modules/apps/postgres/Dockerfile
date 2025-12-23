FROM tensorchord/pgvecto-rs:pg15-v0.3.0 AS builder

FROM postgres:15.10

USER root

# Copy the pgvecto.rs extension files from the builder image
COPY --from=builder /usr/lib/postgresql/15/lib/vectors.so /usr/lib/postgresql/15/lib/
COPY --from=builder /usr/share/postgresql/15/extension/vectors* /usr/share/postgresql/15/extension/

# Install necessary dependencies for pgvecto.rs
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch back to non-root user
USER postgres

# Configure PostgreSQL to preload the pgvecto.rs library
CMD ["postgres", "-c", "shared_preload_libraries=vectors.so"]
