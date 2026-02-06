# Custom PostgreSQL image with init scripts
FROM postgres:18-alpine

# Copy initialization scripts
COPY scripts/*.sh /docker-entrypoint-initdb.d/

# Fix permissions - ensure scripts are executable and owned by postgres user
RUN chmod +x /docker-entrypoint-initdb.d/*.sh && \
    chown -R postgres:postgres /docker-entrypoint-initdb.d
