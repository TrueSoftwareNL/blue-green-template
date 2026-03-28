# Docker Compose Changes: Remove Internet Mode

> **Document**: 03-docker-compose.md
> **Parent**: [Index](00-index.md)

## Overview

Remove all internet-mode infrastructure from `docker-compose.yml`: certbot service, SSL volume mounts, HTTPS port, and NGINX_MODE switching.

## Changes Required

### 1. Remove Certbot Service (entire block)

Delete the entire `certbot:` service definition:

```yaml
# DELETE THIS ENTIRE BLOCK:
  certbot:
    image: certbot/certbot
    profiles: ["internet"]
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    depends_on:
      nginx:
        condition: service_healthy
```

### 2. Update Nginx Service

**Remove from ports:**
```yaml
# REMOVE this line:
      - "${NGINX_HTTPS_PORT:-443}:443"
```

**Remove from volumes:**
```yaml
# REMOVE these 3 lines:
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
```

**Change config mount — remove NGINX_MODE variable:**
```yaml
# FROM:
      - ./nginx/nginx-${NGINX_MODE:-internet}.conf:/etc/nginx/nginx.conf:ro
# TO:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
```

### 3. Update Header Comments

Remove references to certbot, internet mode, and SSL from the file header comment block:

```yaml
# FROM:
#   - internet: Certbot for SSL (only in internet-facing mode)
# REMOVE this line entirely

# FROM:
#   - "internet": SSL termination, HTTPS redirect, certbot integration
#   - "internal": HTTP only, behind main reverse proxy, trusts X-Forwarded-For
# TO:
#   Nginx operates behind ProxyBuilder (external reverse proxy that handles SSL).
#   This Nginx handles security headers, rate limiting, and blue-green routing.
```

### 4. Update SSL Comment in Nginx Volumes

```yaml
# FROM:
      # SSL certificates (self-signed or Let's Encrypt)
# TO: (remove this comment — no more SSL volumes)
```

## Resulting Nginx Service

After changes, the nginx service should look like:

```yaml
  nginx:
    image: nginx:alpine
    profiles: ["core", "all"]
    ports:
      - "${NGINX_HTTP_PORT:-80}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/includes:/etc/nginx/includes:ro
      - ./nginx/locations:/etc/nginx/locations:ro
      - ./nginx/upstreams:/etc/nginx/upstreams:ro
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "curl -fs http://localhost:80/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - frontend
```

## Cross-References

- **[04-nginx-cleanup.md](./04-nginx-cleanup.md)** — Nginx file changes
- **[05-env-scripts-git.md](./05-env-scripts-git.md)** — .env variable removals
