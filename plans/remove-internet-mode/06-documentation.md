# Documentation: Remove Internet Mode

> **Document**: 06-documentation.md
> **Parent**: [Index](00-index.md)

## Overview

Rewrite `README.md` to reflect single-mode deployment behind ProxyBuilder. Remove all references to internet mode, SSL, certbot, dual-mode architecture.

## README.md — Sections to Change

### Architecture Diagram

Update to show ProxyBuilder in the chain:

```
                     ┌──────────────┐
ProxyBuilder ──────► │    Nginx     │ ◄── Security headers, rate limiting
  (SSL term.)        │  (reverse    │     blue-green routing
                     │   proxy)     │
                     └──────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              ▼                           ▼
     ┌────────────────┐         ┌────────────────┐
     │   App (Blue)   │         │  App (Green)   │
     │  N replicas    │         │  N replicas    │
     └────────┬───────┘         └────────┬───────┘
              │                          │
       ┌──────┴──────────────────────────┴──────┐
       │                                        │
  ┌────▼───────┐                           ┌────▼─────┐
  │ PostgreSQL │                           │  Redis   │
  └────────────┘                           └──────────┘
```

### Sections to REMOVE

- "Choose Deployment Mode" section (internet vs internal table)
- "Generate SSL Certificates" section entirely
- "SSL Certificate Setup" section entirely (self-signed + Let's Encrypt)
- References to `NGINX_MODE` environment variable
- `internet` profile from Docker Compose Profiles table
- `DOMAIN_NAME` and `CERTBOT_EMAIL` from Environment Variables section
- `NGINX_HTTPS_PORT` from Environment Variables section
- "ACME challenges" from architecture description
- References to `init-letsencrypt.sh` and `generate-self-signed-ssl.sh`
- "Certbot auto-renews" note

### Sections to UPDATE

- **Architecture description** — Mention ProxyBuilder as external SSL proxy
- **Prerequisites** — Remove OpenSSL requirement
- **Quick Start** — Simplify (no SSL step, no mode selection)
- **Environment Variables** — Remove SSL/certbot vars, remove NGINX_MODE
- **Project Structure** — Remove `init-letsencrypt.sh`, `generate-self-signed-ssl.sh` from tree
- **Docker Compose Profiles** — Remove `internet` profile row
- **Useful Commands** — Remove certbot-related commands

### Sections to ADD

- Brief note about ProxyBuilder being the expected external proxy
- Note that this Nginx handles all security headers (ProxyBuilder is passthrough)

## Plan Files Updates

### `plans/refactor-blue-green/00-index.md`

Add a note at the top:

```markdown
> **Note**: The internet mode and certbot described in this plan were subsequently
> removed. See [plans/remove-internet-mode/](../remove-internet-mode/00-index.md).
```

### `plans/refactor-blue-green/07-certbot-ssl.md`

Add a superseded note:

```markdown
> **⚠️ SUPERSEDED**: This document describes certbot/SSL integration that has been
> removed from the project. See [plans/remove-internet-mode/](../remove-internet-mode/00-index.md).
> Kept for historical reference only.
```

## Cross-References

- **[01-requirements.md](./01-requirements.md)** — Acceptance criteria for docs
- **[99-execution-plan.md](./99-execution-plan.md)** — Task checklist
