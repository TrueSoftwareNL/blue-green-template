# Technical Spec: Nginx Internet-Facing Configuration

> **Document**: 04-nginx-internet.md
> **Last Updated**: 2026-02-15
> **Affects**: `nginx/nginx-internet.conf`, `nginx/conf.d/`, `nginx/includes/`, `nginx/locations/`, `nginx/upstreams/`

## 1. Overview

Refactor the current `nginx.conf` into `nginx-internet.conf` for internet-facing deployments with SSL termination, HTTPS redirect, certbot ACME challenges, and blue-green load balancing.

---

## 2. File Changes Summary

| Action | File | Description |
|--------|------|-------------|
| Rename | `nginx.conf` → `nginx-internet.conf` | Internet-facing Nginx config |
| Delete | `nginx/conf.d/server.ssl.conf` | Remove duplicate SSL config |
| Modify | `nginx/conf.d/server-ssl.conf` | Parameterize domain name |
| Modify | `nginx-internet.conf` | Fix `$loggable`, add HTTP health, document resolvers |
| Create | `nginx/upstreams/blue-upstream.conf` | Blue upstream definition |
| Create | `nginx/upstreams/green-upstream.conf` | Green upstream definition |
| Create | `nginx/upstreams/active-upstream.conf` | Active upstream (copy of blue or green) |
| Delete | `nginx/upstreams/bluegreen-upstream.conf` | Replace with 3 separate files |
| Modify | `nginx/locations/10-health.conf` | Add `proxy_params.conf` include |
| Modify | `nginx/includes/security_headers_enhanced.conf` | Tighten CSP |
| Modify | All location files with `add_header` | Fix security header inheritance |

---

## 3. Upstream Switching Architecture

### File: `nginx/upstreams/blue-upstream.conf`
```nginx
# Blue environment upstream
# Used when blue is the active deployment color
upstream active_app {
    zone active_app_zone 64k;
    server app_blue:3000 max_fails=3 fail_timeout=30s resolve;
    keepalive 32;
}
```

### File: `nginx/upstreams/green-upstream.conf`
```nginx
# Green environment upstream
# Used when green is the active deployment color
upstream active_app {
    zone active_app_zone 64k;
    server app_green:3000 max_fails=3 fail_timeout=30s resolve;
    keepalive 32;
}
```

### File: `nginx/upstreams/active-upstream.conf`
This file is a **copy** of either `blue-upstream.conf` or `green-upstream.conf`.
The switch script copies the target color's file here and reloads Nginx.

**Important:** Nginx only includes `active-upstream.conf` — it does NOT include `blue-upstream.conf` or `green-upstream.conf` directly.

```nginx
# nginx-internet.conf (and nginx-internal.conf):
include /etc/nginx/upstreams/active-upstream.conf;
```

---

## 4. Fixes to `nginx-internet.conf`

### 4.1 Fix `$loggable` map usage
```nginx
# Current (broken — $loggable defined but not used):
access_log /var/log/nginx/access.log main buffer=32k flush=5s;

# Fixed:
access_log /var/log/nginx/access.log main buffer=32k flush=5s if=$loggable;
```

### 4.2 Add health endpoint to HTTP server block
```nginx
# HTTP server block — add before the catch-all redirect:
server {
    listen 80;
    include /etc/nginx/conf.d/server-name.conf;

    # Health check over HTTP (for infrastructure tools that can't follow redirects)
    location /health {
        proxy_pass http://active_app;
        include /etc/nginx/includes/proxy_headers.conf;
        include /etc/nginx/includes/proxy_params.conf;
        include /etc/nginx/includes/proxy_timeouts_health.conf;
        proxy_buffering off;
    }

    # Allow Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

### 4.3 Document dual resolvers
```nginx
# In http block:
# Docker's internal DNS resolver — allows Nginx to resolve container names
# (e.g., app_blue, app_green) to container IPs dynamically
resolver 127.0.0.11 valid=10s ipv6=off;
resolver_timeout 5s;

# Note: ssl.conf defines a separate resolver (8.8.8.8, 8.8.4.4) for OCSP stapling.
# OCSP needs public DNS to verify certificate status with the CA.
# The Docker resolver cannot reach external OCSP responders.
```

### 4.4 Change upstream include to only load active
```nginx
# Current:
include /etc/nginx/upstreams/*.conf;

# Fixed — only load the active upstream (blue or green):
include /etc/nginx/upstreams/active-upstream.conf;
```

---

## 5. Parameterize SSL Certificate Paths

### File: `nginx/conf.d/server-ssl.conf`

The domain name should come from the Nginx config via an environment variable, but Nginx doesn't natively support env vars. Two options:

**Option A (chosen — simple):** Keep the hardcoded path but document that it must match the domain in `.env`. The SSL init script creates certs at the correct path.

```nginx
# SSL certificates from Let's Encrypt (or self-signed for development)
# Path must match DOMAIN_NAME in .env
# Certificates are placed here by certbot (production) or generate-self-signed-ssl.sh (development)
ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/chain.pem;
```

**Actually**, we can use `envsubst` in the Nginx Docker entrypoint or use a template. But the simplest approach: use a fixed path like `/etc/nginx/ssl/fullchain.pem` and have the SSL scripts (certbot or self-signed) place/symlink certs there.

**Revised approach:** Create a `nginx/conf.d/server-ssl.conf` that points to a stable path:
```nginx
# SSL certificates — stable paths for both certbot and self-signed
# These are symlinks or copies managed by the SSL setup scripts
ssl_certificate /etc/nginx/ssl/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/privkey.pem;
ssl_trusted_certificate /etc/nginx/ssl/chain.pem;
```

The SSL setup scripts (certbot or self-signed) will place the actual cert files at these paths.

---

## 6. Fix Security Header Inheritance

### Problem
Nginx's `add_header` directive in a location block **clears** all parent (server-level) `add_header` directives. So security headers from `security_headers_enhanced.conf` are lost in locations that add their own headers (like Cache-Control in `10-health.conf`).

### Solution
Re-include `security_headers_enhanced.conf` in every location block that uses `add_header`:

```nginx
# 10-health.conf
location /health {
    limit_req zone=health_limit burst=20 nodelay;
    proxy_pass http://active_app;
    include /etc/nginx/includes/proxy_headers.conf;
    include /etc/nginx/includes/proxy_params.conf;
    include /etc/nginx/includes/proxy_timeouts_health.conf;
    proxy_buffering off;

    # Must re-include security headers because add_header below clears parent headers
    include /etc/nginx/includes/security_headers_enhanced.conf;

    # Cache control for health checks
    add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    add_header Pragma "no-cache" always;
    add_header Expires "0" always;
}
```

Apply same pattern to `20-ping.conf` and `99-default.conf`.

---

## 7. Fix CSP for JSON API

### File: `nginx/includes/security_headers_enhanced.conf`

```nginx
# Current (too permissive for a JSON API):
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; ..." always;

# Fixed (strict — appropriate for JSON API):
add_header Content-Security-Policy "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none';" always;
```

This is appropriate for a pure JSON API that serves no HTML, JS, or CSS.

---

## 8. Fix Health Location

### File: `nginx/locations/10-health.conf`
Add missing `proxy_params.conf` include for proper keepalive:

```nginx
location /health {
    limit_req zone=health_limit burst=20 nodelay;
    proxy_pass http://active_app;
    include /etc/nginx/includes/proxy_headers.conf;
    include /etc/nginx/includes/proxy_params.conf;        # ← ADD THIS
    include /etc/nginx/includes/proxy_timeouts_health.conf;
    proxy_buffering off;
    # ... headers ...
}
```

---

## Cross-References

- **[03-docker-compose.md](./03-docker-compose.md)** — Docker Compose service definition
- **[05-nginx-internal.md](./05-nginx-internal.md)** — Internal mode counterpart
- **[07-certbot-ssl.md](./07-certbot-ssl.md)** — SSL certificate management
- **[99-execution-plan.md](./99-execution-plan.md)** — Implementation tasks
