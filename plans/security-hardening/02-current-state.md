# Current State: Security Hardening

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

The blue-green Nginx already has a solid security foundation (rated 7/10). This document
describes the specific files and configurations that will be modified.

## Relevant Files

| File | Purpose | Changes Needed |
|------|---------|----------------|
| `nginx/includes/proxy_headers.conf` | Sets proxy headers (Host, X-Real-IP, X-Forwarded-For, X-Request-ID) | Add `proxy_hide_header X-Powered-By` |
| `nginx/includes/security_headers_enhanced.conf` | Full security headers (HSTS, CSP, X-Frame-Options, etc.) | Replace API-only CSP with mixed-content CSP, add eval toggle |
| `nginx/nginx.conf` | Main config — rate limit zones, server block, includes | Add commented `auth_limit` rate limit zone |
| `nginx/locations/99-default.conf` | Catch-all location — proxies to active app | Add explicit `client_max_body_size 1m` |
| `nginx/locations/15-auth.conf` | **Does not exist yet** | Create as commented auth rate limit template |

## Current Config Analysis

### proxy_headers.conf (current)

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Request-ID $request_id;
proxy_set_header Connection "";
```

**Gap:** No `proxy_hide_header` — if Express sends `X-Powered-By`, it reaches the client.

### security_headers_enhanced.conf — Current CSP

```nginx
add_header Content-Security-Policy "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none';" always;
```

**Gap:** `default-src 'none'` blocks ALL content loading — HTML, JS, CSS, images, fonts,
WebSocket connections. This is perfect for a pure JSON API but **breaks any app serving
HTML/JS/CSS/images/documents or using WebSocket**.

### nginx.conf — Current Rate Limit Zones

```nginx
limit_req_zone $http_x_forwarded_for zone=api_limit:10m rate=10r/s;
limit_req_zone $http_x_forwarded_for zone=health_limit:10m rate=100r/s;
```

**Gap:** No auth-specific zone. All endpoints share the same 10r/s limit. Auth endpoints
should have much stricter limits (5r/m) to slow brute force attacks.

### 99-default.conf — Current Body Size

```nginx
location / {
    limit_req zone=api_limit burst=20 nodelay;
    proxy_pass http://active_app;
    # ... (no explicit client_max_body_size)
}
```

**Gap:** Inherits global `client_max_body_size 10m` from nginx.conf. JSON API endpoints
should have a stricter default (1m). Auth endpoints should be even smaller (100k).

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CSP change breaks existing deployments | Medium | Medium | New CSP is permissive (`'self'`), not restrictive. Only tighter than browser defaults, not tighter than current. |
| Auth rate limits block legitimate users | Low | Low | Shipped commented-out — deployer explicitly enables and customizes |
| Body size limit rejects large API payloads | Low | Low | 1m is generous for JSON. Upload endpoints can override to higher values. |
