# Requirements: Remove Internet Mode

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)

## Feature Overview

Remove all internet-facing mode infrastructure (SSL termination, certbot, HTTPS, dual-mode switching) from the blue-green template. The template will exclusively operate behind ProxyBuilder, which handles SSL externally.

## Functional Requirements

### Must Have

- [ ] Remove the certbot Docker Compose service entirely
- [ ] Remove the `internet` Docker Compose profile
- [ ] Remove all SSL-related Nginx config files
- [ ] Remove the `NGINX_MODE` environment variable (no more mode switching)
- [ ] Rename `nginx-internal.conf` → `nginx.conf` (single config)
- [ ] Use full security headers (`security_headers_enhanced.conf`) everywhere
- [ ] Delete `security_headers_internal.conf` (replaced by enhanced)
- [ ] Delete `scripts/init-letsencrypt.sh`
- [ ] Delete `scripts/generate-self-signed-ssl.sh`
- [ ] Remove certbot-related entries from `.gitignore`
- [ ] Remove `CERTBOT_EMAIL`, `DOMAIN_NAME`, `NGINX_HTTPS_PORT`, `NGINX_MODE` from `.env` and `.env.example`
- [ ] Update `README.md` to reflect single-mode deployment behind ProxyBuilder
- [ ] Remove HTTPS port 443 from Docker Compose nginx service
- [ ] Remove certbot/SSL volume mounts from nginx service

### Should Have

- [ ] Update comments in remaining files to remove internet-mode references
- [ ] Update old plan files for accuracy

### Won't Have (Out of Scope)

- Security hardening improvements (see `plans/security-hardening-notes.md`)
- Making PostgreSQL/Redis optional in Docker Compose
- Per-endpoint rate limiting
- CSP flexibility for HTML apps
- ProxyBuilder configuration changes

## Technical Requirements

### Compatibility

- Docker Compose must validate after changes (`docker compose config`)
- Docker build must succeed (`docker compose build`)
- Nginx must start correctly with the renamed config
- Blue-green switching must still work

### No Breaking Changes To

- App container (server.js, Dockerfile, healthcheck, start.sh)
- Blue-green switching script
- Health check wait script
- Upstream configs (blue, green, active)
- Location configs
- Proxy headers/params/timeouts

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale |
|----------|--------------------|--------|-----------|
| Config rename | Keep `nginx-internal.conf` / Rename to `nginx.conf` | Rename | Single mode = no need for suffix |
| Security headers | Keep internal subset / Use enhanced everywhere | Enhanced everywhere | ProxyBuilder is passthrough — no headers added |
| `DOMAIN_NAME` | Keep / Remove | Remove | Only used by deleted SSL scripts |

## Acceptance Criteria

1. [ ] `docker compose config` passes
2. [ ] `docker compose build` succeeds
3. [ ] No references to certbot, letsencrypt, internet mode, or SSL in active config files
4. [ ] Nginx config correctly mounts `nginx.conf` (not `nginx-${NGINX_MODE}.conf`)
5. [ ] Security headers are the full enhanced set
6. [ ] README documents single-mode deployment behind ProxyBuilder
7. [ ] All deleted files are gone; no orphaned references
