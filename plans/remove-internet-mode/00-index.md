# Remove Internet Mode — Implementation Plan

> **Feature**: Remove internet-facing mode, certbot, and SSL from the blue-green template
> **Status**: Planning Complete
> **Created**: 2026-03-28

## Overview

Remove the entire internet-facing deployment mode from the blue-green template. The project will operate exclusively behind ProxyBuilder (a passthrough reverse proxy that handles SSL termination). This Nginx becomes the sole security/hardening layer between ProxyBuilder and the application containers.

### Architecture After This Change

```
Internet → ProxyBuilder (SSL termination, routing) → HTTP → This Nginx (security, rate limiting, blue/green routing) → App replicas
```

### Why

- ProxyBuilder handles SSL termination, certificate management (Let's Encrypt), and HTTP→HTTPS redirect
- Dual-mode (internet/internal) adds complexity without benefit
- Certbot, SSL config, and self-signed certs are redundant when ProxyBuilder exists
- Simplifies the template for all future BlendSDK/WebAFX applications

## Document Index

| # | Document | Description |
|---|----------|-------------|
| [00](./00-index.md) | Index | This document — overview and navigation |
| [01](./01-requirements.md) | Requirements | Scope: what to remove, what to keep |
| [02](./02-current-state.md) | Current State | All certbot/internet-mode touchpoints |
| [03](./03-docker-compose.md) | Docker Compose | Docker Compose changes spec |
| [04](./04-nginx-cleanup.md) | Nginx Cleanup | Nginx file deletions, rename, header changes |
| [05](./05-env-scripts-git.md) | Env, Scripts, Git | .env, .gitignore, script deletions |
| [06](./06-documentation.md) | Documentation | README rewrite spec |
| [99](./99-execution-plan.md) | Execution Plan | Phases, sessions, tasks, and checklist |

## Key Decisions

| Decision | Outcome |
|----------|---------|
| Remove internet mode? | Yes — ProxyBuilder handles SSL |
| Rename `nginx-internal.conf` → `nginx.conf`? | Yes — single mode, no suffix needed |
| Remove `DOMAIN_NAME` from .env? | Yes — only used by deleted SSL scripts |
| Keep `security_headers_enhanced.conf`? | Yes — now the ONLY security header file |
| Delete `security_headers_internal.conf`? | Yes — was a subset; enhanced is now used everywhere |
| Keep `trusted_proxies.conf`? | Yes — needed to trust ProxyBuilder's forwarded headers |

## Related Files

- [Security Hardening Notes](../security-hardening-notes.md) — Future security improvements
- [Original Refactor Plan](../refactor-blue-green/00-index.md) — How this project was built
