# Nginx Cleanup: Remove Internet Mode

> **Document**: 04-nginx-cleanup.md
> **Parent**: [Index](00-index.md)

## Overview

Delete internet-mode Nginx files, rename the internal config, and switch to full security headers.

## 1. Files to DELETE

| File | Reason |
|------|--------|
| `nginx/nginx-internet.conf` | Entire internet-facing config (SSL, HTTPS, ACME) — ProxyBuilder handles this |
| `nginx/conf.d/server-ssl.conf` | SSL certificate paths — no more SSL |
| `nginx/includes/ssl.conf` | SSL protocols, ciphers, OCSP, DH params — no more SSL |
| `nginx/includes/security_headers_internal.conf` | Subset headers — replaced by enhanced headers everywhere |

## 2. Rename `nginx-internal.conf` → `nginx.conf`

Rename the file. Since there's only one mode now, the `-internal` suffix is misleading.

```bash
mv nginx/nginx-internal.conf nginx/nginx.conf
```

## 3. Update `nginx.conf` (renamed file)

### 3.1 Update File Header Comments

```nginx
# FROM:
# =============================================================================
# Nginx Configuration — Internal Mode (Behind Main Reverse Proxy)
# =============================================================================
# This config is for deployments behind a main reverse proxy with:
#   - HTTP only (port 80) — no SSL termination (main proxy handles HTTPS)
#   - Rate limiting keyed on X-Forwarded-For (real client IP from main proxy)
#   - Trusted proxy headers (set_real_ip_from)
#   - Reduced security headers (main proxy handles HSTS, etc.)
#   - Blue-green load balancing via active-upstream.conf
#
# Architecture:
#   Main Proxy (different machine) → HTTP → This Nginx → App replicas
#
# Mounted by Docker Compose when NGINX_MODE=internal
# =============================================================================

# TO:
# =============================================================================
# Nginx Configuration — Blue-Green Reverse Proxy
# =============================================================================
# This Nginx operates behind ProxyBuilder (external reverse proxy that handles
# SSL termination and certificate management). This config provides:
#   - HTTP only (port 80) — ProxyBuilder handles HTTPS
#   - Full security headers (HSTS, CSP, etc.) — ProxyBuilder is passthrough
#   - Rate limiting keyed on X-Forwarded-For (real client IP from ProxyBuilder)
#   - Trusted proxy headers (set_real_ip_from)
#   - Blue-green load balancing via active-upstream.conf
#
# Architecture:
#   ProxyBuilder (SSL) → HTTP → This Nginx (security + routing) → App replicas
# =============================================================================
```

### 3.2 Switch Security Headers

In the server block, change:

```nginx
# FROM:
        # Include internal security headers (subset — main proxy handles HSTS etc.)
        include /etc/nginx/includes/security_headers_internal.conf;

# TO:
        # Include full security headers (HSTS, CSP, etc.)
        # ProxyBuilder is a passthrough proxy — it adds no headers
        include /etc/nginx/includes/security_headers_enhanced.conf;
```

### 3.3 Update Rate Limiting Comments

```nginx
# FROM:
    # -------------------------------------------------------------------------
    # Rate limiting zones — keyed on X-Forwarded-For (real client IP)
    # -------------------------------------------------------------------------
    # Using $http_x_forwarded_for instead of $binary_remote_addr because
    # $remote_addr would be the main proxy's IP, rate-limiting the proxy itself

# TO:
    # -------------------------------------------------------------------------
    # Rate limiting zones — keyed on X-Forwarded-For (real client IP)
    # -------------------------------------------------------------------------
    # Using $http_x_forwarded_for instead of $binary_remote_addr because
    # $remote_addr would be ProxyBuilder's IP, rate-limiting the proxy itself
```

### 3.4 Update Server Block Comments

```nginx
# FROM:
    # =========================================================================
    # HTTP Server — Main application (no SSL, behind main proxy)
    # =========================================================================

# TO:
    # =========================================================================
    # HTTP Server — Main application (behind ProxyBuilder)
    # =========================================================================
```

```nginx
# FROM:
        # Trust the main proxy to set real client IP via X-Forwarded-For
        include /etc/nginx/includes/trusted_proxies.conf;

# TO:
        # Trust ProxyBuilder to set real client IP via X-Forwarded-For
        include /etc/nginx/includes/trusted_proxies.conf;
```

## 4. Files KEPT (no changes needed)

These files are already correct and referenced by the remaining config:

- `nginx/includes/security_headers_enhanced.conf` — Full security headers
- `nginx/includes/trusted_proxies.conf` — Proxy trust config
- `nginx/includes/error_pages.conf` — JSON error pages
- `nginx/includes/file_cache.conf` — File descriptor cache
- `nginx/includes/proxy_headers.conf` — Proxy headers
- `nginx/includes/proxy_params.conf` — Proxy params
- `nginx/includes/proxy_timeouts.conf` — Standard timeouts
- `nginx/includes/proxy_timeouts_health.conf` — Health check timeouts
- `nginx/conf.d/server-name.conf` — Server name
- `nginx/locations/*.conf` — All location blocks
- `nginx/upstreams/*.conf` — All upstream definitions

## Cross-References

- **[03-docker-compose.md](./03-docker-compose.md)** — Volume mount path change
- **[05-env-scripts-git.md](./05-env-scripts-git.md)** — Related file deletions
