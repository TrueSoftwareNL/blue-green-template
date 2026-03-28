# Env, Scripts & Git: Remove Internet Mode

> **Document**: 05-env-scripts-git.md
> **Parent**: [Index](00-index.md)

## Overview

Remove environment variables, delete SSL scripts, and clean up `.gitignore`.

## 1. Scripts to DELETE

| File | Reason |
|------|--------|
| `scripts/init-letsencrypt.sh` | Entire script is certbot/Let's Encrypt specific — ProxyBuilder handles this |
| `scripts/generate-self-signed-ssl.sh` | Self-signed SSL for development — no more SSL in this Nginx |

## 2. `.env` Changes

Remove these variables and their comments:

```env
# REMOVE this section:
# Nginx Mode: "internet" (public-facing with SSL) or "internal" (behind main proxy)
NGINX_MODE=internet
NGINX_HTTPS_PORT=443

# REMOVE this section:
# Domain (used for SSL certificates in internet mode)
DOMAIN_NAME=example.com

# REMOVE this section:
# Certbot / Let's Encrypt (internet mode only)
CERTBOT_EMAIL=admin@example.com
```

**Keep:**
```env
NGINX_HTTP_PORT=80   # Still needed
```

## 3. `.env.example` Changes

Same removals as `.env`:

```env
# REMOVE:
NGINX_MODE=internet
NGINX_HTTPS_PORT=443

# REMOVE the entire "Domain & SSL" section:
# -----------------------------------------------------------------------------
# Domain & SSL (internet mode only)
# -----------------------------------------------------------------------------
# Your domain name — used for SSL certificates and Nginx server_name
DOMAIN_NAME=example.com

# Email for Let's Encrypt certificate notifications
CERTBOT_EMAIL=admin@example.com

# REMOVE "NGINX_MODE" from the "Nginx Mode" section header
# Update the section to just document the HTTP port
```

**Update the Nginx section to:**
```env
# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------
# Port exposed on the host (ProxyBuilder forwards traffic here)
NGINX_HTTP_PORT=80
```

## 4. `.gitignore` Changes

Remove these entries:

```gitignore
# REMOVE:
# SSL certificates (sensitive — never commit private keys)
nginx/ssl/*.pem
nginx/ssl/

# REMOVE:
# Certbot data (Let's Encrypt account keys and certificates)
certbot/conf/
certbot/www/
```

## 5. Scripts KEPT (no changes)

- `scripts/switch-environment.sh` — Blue-green switching (no certbot references)
- `scripts/health-check-wait.sh` — Health check polling (no certbot references)
- `scripts/agent.sh` — VS Code settings management

## Cross-References

- **[03-docker-compose.md](./03-docker-compose.md)** — NGINX_MODE removal from docker-compose
- **[04-nginx-cleanup.md](./04-nginx-cleanup.md)** — Nginx file deletions
