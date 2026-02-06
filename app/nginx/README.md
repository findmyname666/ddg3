# Nginx Reverse Proxy Container

This directory defines the nginx container that terminates TLS and proxies
traffic to the [feedback web application][1].

## Overview

- Listens on HTTPS (port 443) with HTTP/2 and HTTP/3 (QUIC)
- Proxies all requests to the `web` service on port 8080
- Exposes a health endpoint at `/nginx-health`
- Applies basic rate limiting and caching for static assets

## Important Files

- `Dockerfile` - Builds the nginx image; selects dev/prod config via `ENV`
  build arg
- `nginx.conf` - Global nginx settings (logging, gzip, security headers)
- `conf.d/feedduck.dev.conf` – Development virtual host (self-signed certs)
- `conf.d/feedduck.prod.conf` – Production virtual host (Let's Encrypt certs)
- `ssl/` – Directory for TLS certificates (see SSL section below)

## SSL and Certificates

This section documents how SSL certificates are used by the nginx container.

### Development

For development, use **self-signed certificates** stored under `ssl/`:

- Generate them from the project root with:

  ```bash
  # Run the following command from the project root
  make ssl-dev
  ```

This creates:

- `app/nginx/ssl/fullchain.pem` – self-signed certificate
- `app/nginx/ssl/privkey.pem` – private key

Details:

- **Valid for**: 30 days
- **Domains**: `localhost`, `feedduck.localhost`, `127.0.0.1`

#### Browser Warning

When accessing `https://localhost` or `https://feedduck.localhost`, your
browser will show a security warning because the certificate is self-signed.
This is expected and safe for development.

To bypass:

- Chrome/Edge: Click "Advanced" → "Proceed to localhost (unsafe)"
- Firefox: Click "Advanced" → "Accept the Risk and Continue"

### Production

In production, certificates are managed by **Let's Encrypt** using certbot on
the host.

#### Certificate Renewal

Since nginx does **not** use port 80, certbot can run while nginx is running.

Certbot automatically renews certificates via a systemd timer. To renew
manually:

```bash
# Renew certificate (nginx stays running - port 80 is free!)
sudo certbot renew

# Reload nginx to pick up new certificates (zero downtime)
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

#### Why Port 80 is Not Used by Nginx

Port 80 is kept **free** for certbot's standalone mode during certificate
verification. This avoids conflicts and simplifies the setup:

- **Certbot** uses port 80 temporarily during verification
- **Nginx** only uses port 443 for HTTPS traffic
- No need for complex webroot or DNS challenge configurations

#### Files and Security Notes

Files in `app/nginx/ssl/`:

- `*.pem` – generated certificate and key files (gitignored)

Notes:

- All certificate files are gitignored
- Private keys should never be committed to version control
- Production certificates are mounted read-only from `/etc/letsencrypt/`
  (entire directory to support symlinks)
- Certificate paths use `/etc/letsencrypt/live/${FQDN}/` where `FQDN` is
  passed as an environment variable
- Development certificates are mounted from `app/nginx/ssl/`

## Config Template and FQDN

The Dockerfile copies `conf.d/feedduck.${ENV}.conf` as a template into the
image. On container startup, an entrypoint script runs:

- Reads `/etc/nginx/conf.d/feedduck.conf.template`
- Substitutes the `${FQDN}` placeholder using the `FQDN` environment variable
- Writes the final config to `/etc/nginx/conf.d/feedduck.conf`

Make sure `FQDN` is set in production so nginx can load the correct
certificate paths.

## Health Check

The image defines a Docker `HEALTHCHECK` that calls:

- `https://localhost/nginx-health`

If this endpoint stops returning `200`, the container will be marked
unhealthy by Docker.

[1]: ../feedback/
