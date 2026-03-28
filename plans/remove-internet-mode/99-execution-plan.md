# Execution Plan: Remove Internet Mode

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-03-28 15:41
> **Progress**: 18/18 tasks (100%) ✅

## Overview

Remove all internet-facing mode infrastructure from the blue-green template. The project will exclusively operate behind ProxyBuilder. Single session execution (~45 minutes).

---

## Implementation Phases

| Phase | Title | Sessions | Est. Time | Status |
|-------|-------|----------|-----------|--------|
| 1 | Docker Compose Cleanup | 1 | 5 min | ✅ Done |
| 2 | Nginx File Deletions & Rename | 1 | 10 min | ✅ Done |
| 3 | Scripts, Env & Gitignore | 1 | 5 min | ✅ Done |
| 4 | README Rewrite | 1 | 15 min | ✅ Done |
| 5 | Plan Files Update | 1 | 5 min | ✅ Done |
| 6 | Verification | 1 | 5 min | ✅ Done |

**Total: 1 session, ~45 minutes**

---

## Task Checklist (All Phases)

### Phase 1: Docker Compose Cleanup
- [x] 1.1.1 Remove certbot service block ✅ (completed: 2026-03-28 15:36)
- [x] 1.1.2 Remove HTTPS port and SSL/certbot volumes from nginx ✅ (completed: 2026-03-28 15:36)
- [x] 1.1.3 Change nginx config mount to `nginx.conf` ✅ (completed: 2026-03-28 15:36)
- [x] 1.1.4 Update header comments ✅ (completed: 2026-03-28 15:36)

### Phase 2: Nginx File Deletions & Rename
- [x] 2.1.1 Delete `nginx/nginx-internet.conf` ✅ (completed: 2026-03-28 15:37)
- [x] 2.1.2 Delete `nginx/conf.d/server-ssl.conf` ✅ (completed: 2026-03-28 15:37)
- [x] 2.1.3 Delete `nginx/includes/ssl.conf` ✅ (completed: 2026-03-28 15:37)
- [x] 2.1.4 Delete `nginx/includes/security_headers_internal.conf` ✅ (completed: 2026-03-28 15:37)
- [x] 2.1.5 Rename `nginx-internal.conf` → `nginx.conf` ✅ (completed: 2026-03-28 15:37)
- [x] 2.1.6 Update `nginx.conf` comments and security headers include ✅ (completed: 2026-03-28 15:38)

### Phase 3: Scripts, Env & Gitignore
- [x] 3.1.1 Delete `scripts/init-letsencrypt.sh` ✅ (completed: 2026-03-28 15:38)
- [x] 3.1.2 Delete `scripts/generate-self-signed-ssl.sh` ✅ (completed: 2026-03-28 15:38)
- [x] 3.1.3 Clean `.env` (remove 4 vars) ✅ (completed: 2026-03-28 15:38)
- [x] 3.1.4 Clean `.env.example` (remove vars, update section) ✅ (completed: 2026-03-28 15:38)
- [x] 3.1.5 Clean `.gitignore` (remove certbot/SSL entries) ✅ (completed: 2026-03-28 15:38)

### Phase 4: README Rewrite
- [x] 4.1.1 Rewrite `README.md` ✅ (completed: 2026-03-28 15:39)

### Phase 5: Plan Files Update
- [x] 5.1.1 Add note to `plans/refactor-blue-green/00-index.md` ✅ (completed: 2026-03-28 15:39)
- [x] 5.1.2 Add note to `plans/refactor-blue-green/07-certbot-ssl.md` ✅ (completed: 2026-03-28 15:39)

### Phase 6: Verification
- [x] 6.1.1 `docker compose config` passes ✅ (completed: 2026-03-28 15:40)
- [x] 6.1.2 `docker compose build` succeeds ✅ (completed: 2026-03-28 15:41)
- [x] 6.1.3 No orphaned references in active files ✅ (completed: 2026-03-28 15:41)

---

## Success Criteria — All Met ✅

1. ✅ All 6 phases completed
2. ✅ `docker compose config` passes
3. ✅ `docker compose build` succeeds
4. ✅ No certbot/letsencrypt/SSL/internet-mode references in active config files
5. ✅ README documents single-mode deployment behind ProxyBuilder
6. ✅ 6 files deleted, 6 files modified
7. ⏳ **Post-completion:** Ask user to re-analyze project and update `.clinerules/project.md`

---

## Files Changed Summary

### Deleted (6 files)
- `nginx/nginx-internet.conf`
- `nginx/conf.d/server-ssl.conf`
- `nginx/includes/ssl.conf`
- `nginx/includes/security_headers_internal.conf`
- `scripts/init-letsencrypt.sh`
- `scripts/generate-self-signed-ssl.sh`

### Modified (6 files)
- `docker-compose.yml` — Removed certbot service, SSL volumes, HTTPS port, NGINX_MODE
- `nginx/nginx.conf` — Renamed from nginx-internal.conf, switched to enhanced headers, updated comments
- `.env` — Removed NGINX_MODE, NGINX_HTTPS_PORT, DOMAIN_NAME, CERTBOT_EMAIL
- `.env.example` — Same removals, updated section headers
- `.gitignore` — Removed certbot/SSL entries
- `README.md` — Rewritten for single-mode deployment behind ProxyBuilder

### Updated (plan files)
- `plans/refactor-blue-green/00-index.md` — Added superseded note
- `plans/refactor-blue-green/07-certbot-ssl.md` — Added superseded note
- `plans/remove-internet-mode/99-execution-plan.md` — Marked all tasks complete
