# Security Hardening Implementation Plan

> **Feature**: Nginx-layer security hardening for blue-green template
> **Status**: Planning Complete
> **Created**: 2026-03-28

## Overview

This plan implements 4 security improvements at the blue-green Nginx layer. All changes are
Nginx configuration edits — no application code, no Docker Compose structural changes, no
new containers.

The improvements address gaps identified during the `remove-internet-mode` plan and documented
in `plans/security-hardening-notes.md`. Only items that belong to the blue-green Nginx layer
are in scope — ProxyBuilder-level, app-level, and CDN-level items are explicitly excluded.

**Architecture context:**
```
Internet → ProxyBuilder (SSL termination only) → HTTP → Blue-Green Nginx (ALL hardening) → App
```

## Document Index

| #  | Document                                       | Description                                |
|----|------------------------------------------------|--------------------------------------------|
| 00 | [Index](00-index.md)                           | This document — overview and navigation    |
| 01 | [Requirements](01-requirements.md)             | Requirements, scope, and design decisions  |
| 02 | [Current State](02-current-state.md)           | Current nginx config analysis              |
| 03 | [Nginx Hardening](03-nginx-hardening.md)       | Technical specification for all 4 changes  |
| 99 | [Execution Plan](99-execution-plan.md)         | Phases, tasks, and checklist               |

## Quick Reference

### What's Changing

| # | Change                          | File(s)                                      |
|---|---------------------------------|----------------------------------------------|
| 1 | Strip `X-Powered-By` header    | `nginx/includes/proxy_headers.conf`          |
| 2 | Fix CSP for mixed HTML+API+WS  | `nginx/includes/security_headers_enhanced.conf` |
| 3 | Auth rate limits (template)     | `nginx/nginx.conf`, `nginx/locations/15-auth.conf` (new) |
| 4 | Per-location body size limits   | `nginx/locations/99-default.conf`, `nginx/locations/15-auth.conf` |

### Key Decisions

| Decision                  | Outcome                                                    |
|---------------------------|------------------------------------------------------------|
| CSP configurability       | Option C — comment-based toggle (no envsubst, no scripts)  |
| `'unsafe-eval'` support   | Commented variant included in header file                  |
| Auth rate limit paths     | Template/example, commented out — deployer customizes      |
| Trusted proxies scope     | Leave as-is (broad private ranges, Docker is private)      |
| X-Request-ID end-to-end   | Dropped (current `$request_id` is sufficient)              |

## Related Files

### Modified
- `nginx/includes/proxy_headers.conf`
- `nginx/includes/security_headers_enhanced.conf`
- `nginx/nginx.conf`
- `nginx/locations/99-default.conf`
- `plans/security-hardening-notes.md`
- `README.md`

### Created
- `nginx/locations/15-auth.conf`
