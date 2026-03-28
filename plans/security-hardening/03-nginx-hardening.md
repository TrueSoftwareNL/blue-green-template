# Nginx Hardening: Technical Specification

> **Document**: 03-nginx-hardening.md
> **Parent**: [Index](00-index.md)

## Overview

4 targeted changes to the blue-green Nginx configuration. All changes are additive or
replacement edits to existing config files, plus one new location file.

---

## Change 1: Strip `X-Powered-By` Header

### File: `nginx/includes/proxy_headers.conf`

**What:** Add `proxy_hide_header X-Powered-By;` to strip the Express framework header
from responses before they reach the client.

**Why:** Express sends `X-Powered-By: Express` by default. While apps can disable this
with `app.disable('x-powered-by')`, the Nginx layer should strip it as defense-in-depth.

**Implementation:**

```nginx
# Common proxy headers
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Request-ID $request_id;

# Strip leaked framework headers from app responses
proxy_hide_header X-Powered-By;

# Keepalive
proxy_set_header Connection "";
```

---

## Change 2: Fix CSP for Mixed HTML+API+WebSocket Apps

### File: `nginx/includes/security_headers_enhanced.conf`

**What:** Replace the API-only CSP (`default-src 'none'`) with a CSP that supports
mixed-content apps serving HTML/JS/CSS/images/documents AND REST/WebSocket.

**Why:** Every app in this ecosystem serves mixed content from a single container.
The current `default-src 'none'` blocks all browser-loaded content.

**Design decisions:**
- `'self'` for scripts, images, fonts, default — allows loading from same origin
- `'unsafe-inline'` for styles — many CSS-in-JS frameworks need this
- `data:` for images — allows data URIs (base64 images, inline SVGs)
- `ws: wss:` for connect-src — allows WebSocket connections
- `frame-ancestors 'none'` — keeps clickjacking protection
- `object-src 'none'` — blocks Flash/Java plugins

**Comment-based eval toggle:** A commented variant with `'unsafe-eval'` is placed
directly above the active CSP line, with clear instructions.

**Implementation — replace the CSP block in security_headers_enhanced.conf:**

```nginx
# Content Security Policy — Mixed content (HTML/JS/CSS/images + REST/WebSocket)
# Allows loading resources from same origin, inline styles, data URIs, and WebSocket
#
# To enable eval() (e.g., for dynamic template engines), uncomment the 'unsafe-eval'
# variant below and comment out the standard line:
#
#add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' ws: wss:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none';" always;
#
# Standard CSP (no eval):
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' ws: wss:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none';" always;
```

---

## Change 3: Auth Rate Limits (Template)

### Files: `nginx/nginx.conf` + `nginx/locations/15-auth.conf` (new)

**What:** Add a stricter rate limit zone for authentication endpoints (5 requests/minute)
and a location file with example auth paths — all commented out, ready to customize.

**Why:** Auth endpoints are the primary brute force target. The current flat 10r/s limit
on all endpoints doesn't protect against password spraying. A dedicated auth zone at 5r/m
(1 request every 12 seconds) significantly slows automated attacks.

### nginx.conf — Add commented zone after existing zones

```nginx
# Auth rate limiting — stricter limits for authentication endpoints
# Uncomment to enable (customize paths in locations/15-auth.conf)
#limit_req_zone $http_x_forwarded_for zone=auth_limit:10m rate=5r/m;
```

### nginx/locations/15-auth.conf (new file)

```nginx
# =============================================================================
# Auth Endpoint Rate Limiting (TEMPLATE — customize per deployment)
# =============================================================================
# Uncomment and adjust the location blocks below for your app's auth endpoints.
# Also uncomment the auth_limit zone in nginx.conf.
#
# Common auth paths by framework:
#   BlendSDK/WebAFX:  /auth/login, /auth/refresh, /auth/logout
#   Express/Passport: /login, /logout, /oauth/*
#   Custom:           /api/auth/*, /api/v1/auth/*
# =============================================================================

# Example: Login endpoint with strict rate limiting
#location /auth/login {
#    limit_req zone=auth_limit burst=3 nodelay;
#    client_max_body_size 100k;
#
#    proxy_pass http://active_app;
#    include /etc/nginx/includes/proxy_headers.conf;
#    include /etc/nginx/includes/proxy_params.conf;
#    include /etc/nginx/includes/proxy_timeouts.conf;
#}

# Example: All auth endpoints with strict rate limiting
#location /auth/ {
#    limit_req zone=auth_limit burst=3 nodelay;
#    client_max_body_size 100k;
#
#    proxy_pass http://active_app;
#    include /etc/nginx/includes/proxy_headers.conf;
#    include /etc/nginx/includes/proxy_params.conf;
#    include /etc/nginx/includes/proxy_timeouts.conf;
#}

# Example: OAuth endpoints
#location /oauth/ {
#    limit_req zone=auth_limit burst=3 nodelay;
#    client_max_body_size 100k;
#
#    proxy_pass http://active_app;
#    include /etc/nginx/includes/proxy_headers.conf;
#    include /etc/nginx/includes/proxy_params.conf;
#    include /etc/nginx/includes/proxy_timeouts.conf;
#}
```

---

## Change 4: Per-Location Body Size Limits

### File: `nginx/locations/99-default.conf`

**What:** Add explicit `client_max_body_size 1m` to the default location block.

**Why:** The global limit is `10m` (in nginx.conf). JSON API endpoints rarely need more
than 1MB. The explicit override makes the limit visible and intentional. The global `10m`
remains as a fallback for any unconfigured location blocks.

**The auth location template (Change 3) already includes `client_max_body_size 100k`.**

**Implementation — add to the `location /` block:**

```nginx
location / {
    limit_req zone=api_limit burst=20 nodelay;

    # Request body limit for API endpoints (override global 10m)
    client_max_body_size 1m;

    # Proxy to active backend (blue or green)
    proxy_pass http://active_app;
    # ... rest unchanged
}
```

---

## Testing Requirements

- `docker compose config` — validates Docker Compose syntax
- `docker compose build` — builds images (confirms nginx config is mountable)
- No runtime Nginx syntax test needed — all new auth location content is commented out
