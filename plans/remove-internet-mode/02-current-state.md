# Current State: Remove Internet Mode

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

The project currently supports two deployment modes controlled by `NGINX_MODE` environment variable:
- **internet** — Public-facing with SSL termination, HTTPS redirect, certbot ACME challenges
- **internal** — Behind a main reverse proxy, HTTP only

## Files to DELETE

| File | Purpose | Why Delete |
|------|---------|------------|
| `nginx/nginx-internet.conf` | Internet-facing Nginx config with SSL, HTTPS, ACME | ProxyBuilder handles SSL |
| `nginx/conf.d/server-ssl.conf` | SSL certificate paths for Nginx | No more SSL in this Nginx |
| `nginx/includes/ssl.conf` | SSL protocols, ciphers, OCSP, DH params | No more SSL in this Nginx |
| `nginx/includes/security_headers_internal.conf` | Subset of security headers (assumed main proxy adds rest) | ProxyBuilder is passthrough — needs full headers |
| `scripts/init-letsencrypt.sh` | Let's Encrypt certificate setup via certbot | ProxyBuilder handles certificates |
| `scripts/generate-self-signed-ssl.sh` | Self-signed SSL for local development | No more SSL in this Nginx |

## Files to MODIFY

| File | Current State | Changes Needed |
|------|--------------|----------------|
| `docker-compose.yml` | Has certbot service, SSL volumes, NGINX_MODE, HTTPS port | Remove certbot, SSL volumes, HTTPS port; hardcode nginx.conf path |
| `nginx/nginx-internal.conf` | Internal mode config behind proxy | Rename → `nginx/nginx.conf`; change `security_headers_internal` → `security_headers_enhanced`; update comments |
| `.env` | Has `NGINX_MODE`, `NGINX_HTTPS_PORT`, `DOMAIN_NAME`, `CERTBOT_EMAIL` | Remove these 4 variables |
| `.env.example` | Same variables as `.env` | Remove same 4 variables |
| `.gitignore` | Has `certbot/conf/`, `certbot/www/`, `nginx/ssl/` entries | Remove certbot and SSL entries |
| `README.md` | Documents both modes, SSL setup, certbot | Rewrite for single-mode behind ProxyBuilder |

## Files UNTOUCHED

### Nginx Includes (all still needed)
- `nginx/includes/security_headers_enhanced.conf` — Now the ONLY security header file
- `nginx/includes/trusted_proxies.conf` — Trusts ProxyBuilder's forwarded headers
- `nginx/includes/error_pages.conf` — JSON error pages
- `nginx/includes/file_cache.conf` — File descriptor cache
- `nginx/includes/proxy_headers.conf` — Proxy headers to app
- `nginx/includes/proxy_params.conf` — Proxy buffering and retry
- `nginx/includes/proxy_timeouts.conf` — Standard timeouts
- `nginx/includes/proxy_timeouts_health.conf` — Fast health check timeouts

### Nginx Config
- `nginx/conf.d/server-name.conf` — Server name (`server_name _;`)

### Nginx Locations (all still needed)
- `nginx/locations/10-health.conf`
- `nginx/locations/20-ping.conf`
- `nginx/locations/30-nginx-status.conf`
- `nginx/locations/99-default.conf`

### Nginx Upstreams (all still needed)
- `nginx/upstreams/active-upstream.conf`
- `nginx/upstreams/blue-upstream.conf`
- `nginx/upstreams/green-upstream.conf`

### App (completely untouched)
- `app/server.js`, `app/Dockerfile`, `app/healthcheck.sh`, `app/start.sh`, `app/package.json`

### Scripts (still needed)
- `scripts/switch-environment.sh` — Blue-green switching
- `scripts/health-check-wait.sh` — Health check polling
- `scripts/agent.sh` — VS Code settings

## Certbot Reference Count

Total references found across project: **183 matches** in search for certbot/letsencrypt/ACME.

After this plan, all certbot references in active files will be zero. Only historical plan documents will retain references.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Nginx fails to start with renamed config | Low | High | Verify with `docker compose config` and `docker compose build` |
| Missing security headers after change | Low | High | Verify enhanced headers are included at both server and location level |
| Orphaned references break something | Low | Low | Search for leftover references after changes |
