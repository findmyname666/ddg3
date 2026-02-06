FROM nginx:1.29-alpine

# Build argument to select environment (dev or prod)
ARG ENV=prod

# Remove default nginx configuration
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy main nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the appropriate configuration file based on environment
COPY conf.d/feedduck.${ENV}.conf /etc/nginx/conf.d/feedduck.conf.template

# Copy entrypoint script to substitute environment variables
COPY docker-entrypoint.d/40-envsubst-on-templates.sh /docker-entrypoint.d/40-envsubst-on-templates.sh
RUN chmod +x /docker-entrypoint.d/40-envsubst-on-templates.sh

# Create SSL directory (for production SSL certificates)
RUN mkdir -p /etc/nginx/ssl

# Health check (uses HTTPS with --no-check-certificate for self-signed certs)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider --no-check-certificate https://localhost/nginx-health || exit 1

EXPOSE 443/tcp 443/udp

# Use the default nginx entrypoint
CMD ["nginx", "-g", "daemon off;"]
