# Technical Spec: Nginx Internal Configuration (Behind Main Proxy)

> **Document**: 05-nginx-internal.md
> **Last Updated**: 2026-02-15
> **Affects**: `nginx/nginx-internal.conf`, `nginx/includes/trusted_proxies.conf`, `nginx/includes/security_headers_internal.conf`

## 1. Overview

Create a new `nginx-internal.conf` for deployments where this Nginx sits behind a main reverse proxy on a different machine. This config handles HTTP-only traffic, trusts proxy headers, and performs blue-green load balancing without SSL.

---

## 2. Architecture

```
Main Proxy (different machine)
  │
  │  HTTP request with X-Forwarded-For, X-Forwarded-Proto headers
  │
  ▼
This Nginx (exposed on host port, e.g., 80 or 8080)
  │
  │  proxy_pass to active_app upstream
  │
  ▼
App replicas (blue or green, via Docker DNS round-robin)
```

### Key Differences from Internet Mode

| Aspect | Internet Mode | Internal Mode |
|--------|--------------|---------------|
| Listens on | Port 80 + 443 | Port 80 only |
| SSL | ✅ Handles termination | ❌ Not needed |
| Certbot | ✅ Certificate renewal | ❌ Not needed |
| HSTS | ✅ Enforced | ❌ Not set (main proxy handles) |
| HTTP → HTTPS redirect | ✅ | ❌ Not needed |
| Rate limit key | `$binary_remote_addr` | `$http_x_forwarded_for` |
| Trusted proxies | Not applicable | ✅ `set_real_ip_from` |
| Security headers | Full set | Subset (avoid duplication) |
| ACME challenge location | ✅ | ❌ Not needed |

---

## 3. New Files to Create

### 3.1 `nginx/nginx-internal.conf`

```nginx
# Nginx configuration for INTERNAL deployment (behind main reverse proxy)
# This Nginx handles blue-green load balancing only — no SSL, no certbot

worker_processes auto;
worker_rlimit_nofile 65535;

# Error log - set to 'crit' to suppress DNS resolution errors for inactive upstreams
error_log /var/log/nginx/error.log crit;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # Basic settings
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # GDPR-compliant logging - Anonymize IP addresses
    map $remote_addr $remote_addr_anon {
        ~(?P<ip>\d+\.\d+\.\d+)\.    $ip.0;
        ~(?P<ip>[^:]+:[^:]+):       $ip::;
        default                      0.0.0.0;
    }

    # Logging format with anonymized IPs
    log_format main '$remote_addr_anon - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'upstream: $upstream_addr response_time: $upstream_response_time';

    # Don't log health checks (reduces log noise)
    map $request_uri $loggable {
        ~^/health 0;
        default 1;
    }

    # Buffered logging for performance (only loggable requests)
    access_log /var/log/nginx/access.log main buffer=32k flush=5s if=$loggable;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    # Timeouts
    keepalive_timeout 65;
    keepalive_requests 100;
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;

    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;
    gzip_disable "msie6";

    # Hide nginx version
    server_tokens off;

    # Docker's internal DNS resolver — allows dynamic resolution of container names
    resolver 127.0.0.11 valid=10s ipv6=off;
    resolver_timeout 5s;

    # Include file cache for performance
    include /etc/nginx/includes/file_cache.conf;

    # Include active upstream definition (blue or green)
    include /etc/nginx/upstreams/active-upstream.conf;

    # Rate limiting zones — keyed on X-Forwarded-For (real client IP from main proxy)
    # Using $binary_remote_addr would rate-limit the main proxy itself
    limit_req_zone $http_x_forwarded_for zone=api_limit:10m rate=10r/s;
    limit_req_zone $http_x_forwarded_for zone=health_limit:10m rate=100r/s;

    # Connection limiting
    limit_conn_zone $http_x_forwarded_for zone=addr:10m;

    # HTTP server — main application (no SSL, behind main proxy)
    server {
        listen 80;
        include /etc/nginx/conf.d/server-name.conf;

        # Trust the main proxy to set real client IP
        include /etc/nginx/includes/trusted_proxies.conf;

        # Include internal security headers (subset — main proxy handles HSTS etc.)
        include /etc/nginx/includes/security_headers_internal.conf;

        # Include error pages
        include /etc/nginx/includes/error_pages.conf;

        # Connection limit per IP (based on X-Forwarded-For)
        limit_conn addr 10;

        # Include all location configurations
        include /etc/nginx/locations/*.conf;
    }
}
```

### 3.2 `nginx/includes/trusted_proxies.conf`

```nginx
# Trusted Proxies Configuration
# Tells Nginx to trust X-Forwarded-For headers from the main reverse proxy
# This allows rate limiting and logging to use the real client IP
# instead of the main proxy's IP

# Private network ranges (adjust to your main proxy's network)
set_real_ip_from 10.0.0.0/8;       # Class A private networks
set_real_ip_from 172.16.0.0/12;    # Class B private networks (includes Docker)
set_real_ip_from 192.168.0.0/16;   # Class C private networks

# Use the X-Forwarded-For header to extract the real client IP
real_ip_header X-Forwarded-For;

# Recursively search through X-Forwarded-For to find the real client IP
# (handles chains of proxies)
real_ip_recursive on;
```

### 3.3 `nginx/includes/security_headers_internal.conf`

```nginx
# Security Headers for Internal Deployment (behind main proxy)
# Only includes headers that won't conflict with or duplicate
# headers set by the main reverse proxy

# IMPORTANT: Headers like HSTS, CSP with frame-ancestors, and
# X-Frame-Options are typically set by the main proxy.
# We only set headers here that the main proxy is unlikely to set.

# Content Security Policy — strict for JSON API
# Main proxy may override this for HTML-serving applications
add_header Content-Security-Policy "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none';" always;

# X-Content-Type-Options - Prevent MIME sniffing
add_header X-Content-Type-Options "nosniff" always;

# X-Download-Options - Prevent file execution in IE
add_header X-Download-Options "noopen" always;

# X-Permitted-Cross-Domain-Policies - Restrict Adobe Flash/PDF
add_header X-Permitted-Cross-Domain-Policies "none" always;

# Referrer Policy - Control referrer information leakage
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

---

## 4. Shared Configuration (No Changes Needed)

These files work identically in both modes and require no mode-specific changes:

| File | Reason |
|------|--------|
| `nginx/includes/proxy_headers.conf` | Same proxy headers for both modes |
| `nginx/includes/proxy_params.conf` | Same proxy parameters |
| `nginx/includes/proxy_timeouts.conf` | Same timeouts |
| `nginx/includes/proxy_timeouts_health.conf` | Same health check timeouts |
| `nginx/includes/error_pages.conf` | Same JSON error pages |
| `nginx/includes/file_cache.conf` | Same file caching |
| `nginx/locations/*.conf` | Same location blocks |
| `nginx/upstreams/*.conf` | Same upstream definitions |

---

## 5. Location Block Adjustment for Internal Mode

The location blocks include `security_headers_enhanced.conf` (internet mode). In internal mode, the server block includes `security_headers_internal.conf` instead. However, location blocks that re-include security headers need to include the right file.

### Solution: Use a single security headers include
Create a "current mode" security headers file that both modes can reference. But this adds complexity.

### Simpler Solution
The location blocks should include `security_headers_enhanced.conf` for internet mode. For internal mode, the same file can be used — the extra headers (HSTS etc.) won't cause harm because the main proxy's headers take precedence (browsers use the last header or the most restrictive).

**Decision:** Location blocks always include `security_headers_enhanced.conf`. In internal mode, the server-level `security_headers_internal.conf` provides the baseline, and location-level re-includes use the enhanced version. Any overlapping headers are harmless (the main proxy's response wins for the client).

Actually, the cleaner approach: location blocks that need to re-include headers should include the **same** file referenced at server level. We'll create a symlink or use the same include path.

**Final Decision:** Both modes use `security_headers_enhanced.conf` in location blocks. Internal mode uses `security_headers_internal.conf` at server level (which has fewer headers). The overlap in location blocks is acceptable — the extra headers like HSTS don't cause issues when behind a proxy.

---

## 6. Port Exposure for Main Proxy

The main proxy on a different machine needs to reach this Nginx. The port is configurable via `.env`:

```env
NGINX_HTTP_PORT=80        # Or 8080, or any available port
```

Docker Compose:
```yaml
nginx:
  ports:
    - "${NGINX_HTTP_PORT:-80}:80"
```

The main proxy then configures its upstream to point to `<this-server-ip>:${NGINX_HTTP_PORT}`.

---

## Cross-References

- **[04-nginx-internet.md](./04-nginx-internet.md)** — Internet-facing counterpart
- **[03-docker-compose.md](./03-docker-compose.md)** — Docker Compose NGINX_MODE support
- **[99-execution-plan.md](./99-execution-plan.md)** — Implementation tasks
