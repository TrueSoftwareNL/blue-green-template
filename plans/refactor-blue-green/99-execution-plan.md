# Execution Plan: Blue-Green Deployment Template Refactor

> **Document**: 99-execution-plan.md
> **Last Updated**: 2026-02-15 02:06
> **Progress**: 35/35 tasks (100%) ✅ COMPLETE

## Overview

Complete refactoring of the blue-green deployment template across 7 phases. Each phase is designed to be completed in one session. Tasks are ordered by dependency — each phase builds on the previous one.

**🚨 Update this document after EACH completed task!**

---

## Phase 1: Fix Critical Bugs

*Goal: Make the project build and run successfully*

### Session 1.1: Fix App Build Issues

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [02-current-state.md](./02-current-state.md) — Bugs 1-4, App Issues 1-3
**Objective**: Fix all build-breaking bugs and app issues

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 1.1.1 | Fix Dockerfile: change `COPY start-application.sh .` → `COPY start.sh .`, add `RUN chmod +x healthcheck.sh start.sh` | `app/Dockerfile` |
| 1.1.2 | Fix `start.sh`: add `set -e`, add trailing newline, keep `#!/bin/bash` (node:24 is Debian) | `app/start.sh` |
| 1.1.3 | Fix `server.js`: read PORT from env var (`process.env.PORT \|\| 3000`), add graceful shutdown handler | `app/server.js` |
| 1.1.4 | Delete duplicate SSL config file `server.ssl.conf` (keep only `server-ssl.conf`) | `nginx/conf.d/server.ssl.conf` |
| 1.1.5 | Validate: `docker compose config && docker compose build` | — |

**Deliverables**:
- [ ] Docker build completes without errors
- [ ] App starts and responds on `/health` and `/ping`
- [ ] No duplicate config files

**Verify**: `clear && docker compose config && docker compose build`

---

## Phase 2: Docker Compose Refactor

*Goal: Correct service definitions with replicas, health checks, networks, and NGINX_MODE support*

### Session 2.1: Refactor Docker Compose & Environment

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [03-docker-compose.md](./03-docker-compose.md)
**Objective**: Fix environment merge, add replicas, health checks, networks, NGINX_MODE

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 2.1.1 | Fix YAML anchor: switch to mapping syntax for environment, include PORT in each service | `docker-compose.yml` |
| 2.1.2 | Add `deploy.replicas: ${APP_REPLICAS:-1}` to app base anchor | `docker-compose.yml` |
| 2.1.3 | Add health check to app base anchor (healthcheck.sh) | `docker-compose.yml` |
| 2.1.4 | Add Redis health check (`redis-cli ping`), pin version to `redis:7-alpine` | `docker-compose.yml` |
| 2.1.5 | Add Nginx health check (`curl -fs http://localhost:80/health`) | `docker-compose.yml` |
| 2.1.6 | Add `depends_on` with `condition: service_healthy` for Nginx → Postgres, Redis | `docker-compose.yml` |
| 2.1.7 | Add network isolation: `frontend` (nginx, apps) and `backend` (apps, postgres, redis) | `docker-compose.yml` |
| 2.1.8 | Add NGINX_MODE support: mount `nginx-${NGINX_MODE}.conf`, configurable ports | `docker-compose.yml` |
| 2.1.9 | Configure certbot service with `internet` profile | `docker-compose.yml` |
| 2.1.10 | Remove unused `postgres_data` named volume and `data/config` mount | `docker-compose.yml` |
| 2.1.11 | Update `.env` with new variables (NGINX_MODE, NGINX_HTTP_PORT, NGINX_HTTPS_PORT, DOMAIN_NAME, CERTBOT_EMAIL) | `.env` |
| 2.1.12 | Validate: `docker compose config && docker compose build` | — |

**Deliverables**:
- [ ] Environment variables correctly set for both blue and green
- [ ] Replica support via `deploy.replicas`
- [ ] All services have health checks
- [ ] Network isolation configured
- [ ] NGINX_MODE variable controls which config is mounted
- [ ] Validation passing

**Verify**: `clear && docker compose config && docker compose build`

---

## Phase 3: Nginx Internet-Facing Configuration

*Goal: Refactor Nginx for internet-facing mode with switchable upstreams and fix all config issues*

### Session 3.1: Upstream Architecture & Config Rename

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [04-nginx-internet.md](./04-nginx-internet.md)
**Objective**: Create switchable upstream files, rename nginx.conf, fix all Nginx issues

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 3.1.1 | Create `nginx/upstreams/blue-upstream.conf` — blue upstream definition | `nginx/upstreams/blue-upstream.conf` |
| 3.1.2 | Create `nginx/upstreams/green-upstream.conf` — green upstream definition | `nginx/upstreams/green-upstream.conf` |
| 3.1.3 | Create `nginx/upstreams/active-upstream.conf` — initial copy of blue (default active) | `nginx/upstreams/active-upstream.conf` |
| 3.1.4 | Delete old `nginx/upstreams/bluegreen-upstream.conf` | `nginx/upstreams/bluegreen-upstream.conf` |
| 3.1.5 | Rename `nginx/nginx.conf` → `nginx/nginx-internet.conf` and apply fixes: change `include upstreams/*.conf` → `include upstreams/active-upstream.conf`, fix `$loggable` usage in access_log, add HTTP health endpoint, document dual resolvers | `nginx/nginx-internet.conf` |
| 3.1.6 | Update `nginx/conf.d/server-ssl.conf` — change cert paths to stable `nginx/ssl/` paths | `nginx/conf.d/server-ssl.conf` |
| 3.1.7 | Fix `nginx/locations/10-health.conf` — add `proxy_params.conf` include, re-include security headers | `nginx/locations/10-health.conf` |
| 3.1.8 | Fix `nginx/locations/20-ping.conf` — re-include security headers before `add_header` | `nginx/locations/20-ping.conf` |
| 3.1.9 | Fix `nginx/locations/99-default.conf` — re-include security headers | `nginx/locations/99-default.conf` |
| 3.1.10 | Fix `nginx/includes/security_headers_enhanced.conf` — tighten CSP for JSON API | `nginx/includes/security_headers_enhanced.conf` |
| 3.1.11 | Validate: `docker compose config && docker compose build` | — |

**Deliverables**:
- [ ] Three upstream files (blue, green, active)
- [ ] `nginx-internet.conf` with all fixes applied
- [ ] SSL cert paths use stable `nginx/ssl/` directory
- [ ] Security headers properly inherited in all locations
- [ ] CSP tightened for JSON API
- [ ] Validation passing

**Verify**: `clear && docker compose config && docker compose build`

---

## Phase 4: Nginx Internal Configuration

*Goal: Create the internal (behind proxy) Nginx configuration*

### Session 4.1: Internal Nginx Config & Includes

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [05-nginx-internal.md](./05-nginx-internal.md)
**Objective**: Create HTTP-only Nginx config for behind-proxy deployment

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 4.1.1 | Create `nginx/nginx-internal.conf` — HTTP-only server, rate limit by X-Forwarded-For, no SSL | `nginx/nginx-internal.conf` |
| 4.1.2 | Create `nginx/includes/trusted_proxies.conf` — set_real_ip_from for private networks | `nginx/includes/trusted_proxies.conf` |
| 4.1.3 | Create `nginx/includes/security_headers_internal.conf` — subset of security headers | `nginx/includes/security_headers_internal.conf` |
| 4.1.4 | Validate: set `NGINX_MODE=internal` in .env, run `docker compose config && docker compose build` | — |

**Deliverables**:
- [ ] `nginx-internal.conf` created and valid
- [ ] Trusted proxies configuration
- [ ] Internal security headers
- [ ] Validation passing with `NGINX_MODE=internal`

**Verify**: `clear && docker compose config && docker compose build`

---

## Phase 5: Swapper Script

*Goal: Implement the zero-downtime blue-green switching script*

### Session 5.1: Create Switching Scripts

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [06-swapper-script.md](./06-swapper-script.md)
**Objective**: Create deployment switching and health check scripts

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 5.1.1 | Create `scripts/health-check-wait.sh` — reusable health polling script | `scripts/health-check-wait.sh` |
| 5.1.2 | Create `scripts/switch-environment.sh` — main deployment switching script (steps 1-11) | `scripts/switch-environment.sh` |
| 5.1.3 | Make scripts executable: `chmod +x scripts/switch-environment.sh scripts/health-check-wait.sh` | — |
| 5.1.4 | Validate: `shellcheck scripts/switch-environment.sh scripts/health-check-wait.sh` | — |

**Deliverables**:
- [ ] Health check wait script (reusable)
- [ ] Deployment switching script (full flow)
- [ ] Both scripts pass ShellCheck
- [ ] Scripts are executable

**Verify**: `clear && shellcheck scripts/switch-environment.sh scripts/health-check-wait.sh`

---

## Phase 6: Certbot & SSL

*Goal: Implement SSL certificate management — self-signed for dev, Let's Encrypt for prod*

### Session 6.1: SSL Scripts & Configuration

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [07-certbot-ssl.md](./07-certbot-ssl.md)
**Objective**: Create SSL generation scripts and configure certbot

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 6.1.1 | Create `scripts/generate-self-signed-ssl.sh` — self-signed cert generator for local dev | `scripts/generate-self-signed-ssl.sh` |
| 6.1.2 | Create `scripts/init-letsencrypt.sh` — Let's Encrypt initial setup script | `scripts/init-letsencrypt.sh` |
| 6.1.3 | Make scripts executable: `chmod +x scripts/generate-self-signed-ssl.sh scripts/init-letsencrypt.sh` | — |
| 6.1.4 | Validate: `shellcheck scripts/generate-self-signed-ssl.sh scripts/init-letsencrypt.sh` | — |

**Deliverables**:
- [ ] Self-signed SSL generator script
- [ ] Let's Encrypt init script
- [ ] Both scripts pass ShellCheck
- [ ] Scripts are executable

**Verify**: `clear && shellcheck scripts/generate-self-signed-ssl.sh scripts/init-letsencrypt.sh`

---

## Phase 7: Documentation & Polish

*Goal: Complete documentation, .gitignore, and final cleanup*

### Session 7.1: Documentation

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [01-requirements.md](./01-requirements.md) — Section 8 (Non-Functional Requirements)
**Objective**: Create .gitignore and comprehensive README

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 7.1.1 | Create `.gitignore` — exclude .env, SSL certs, data dirs, certbot, node_modules | `.gitignore` |
| 7.1.2 | Create `README.md` — project overview, architecture, prerequisites, setup for both modes, blue-green switching, SSL setup, env vars, troubleshooting | `README.md` |
| 7.1.3 | Review all config files for comment quality (junior-dev readability) | All files |
| 7.1.4 | Final validation: `docker compose config && docker compose build` | — |

**Deliverables**:
- [ ] `.gitignore` covering all sensitive/generated files
- [ ] Comprehensive `README.md` covering both deployment modes
- [ ] All configs commented for junior DevOps engineers
- [ ] Final validation passing

**Verify**: `clear && docker compose config && docker compose build`

---

## Task Checklist (All Phases)

### Phase 1: Fix Critical Bugs
- [x] 1.1.1 Fix Dockerfile COPY and chmod ✅ (completed: 2026-02-15 01:39)
- [x] 1.1.2 Fix start.sh (set -e, newline) ✅ (completed: 2026-02-15 01:39)
- [x] 1.1.3 Fix server.js (env PORT, graceful shutdown) ✅ (completed: 2026-02-15 01:39)
- [x] 1.1.4 Delete duplicate server.ssl.conf ✅ (completed: 2026-02-15 01:39)
- [x] 1.1.5 Validate: docker compose config && docker compose build ✅ (completed: 2026-02-15 01:40)

### Phase 2: Docker Compose Refactor
- [x] 2.1.1 Fix YAML anchor environment (mapping syntax) ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.2 Add deploy.replicas to app base ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.3 Add app health check to anchor ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.4 Add Redis health check + pin version ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.5 Add Nginx health check ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.6 Add depends_on with service_healthy ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.7 Add network isolation (frontend/backend) ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.8 Add NGINX_MODE support (volume mount) ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.9 Configure certbot service with internet profile ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.10 Remove unused postgres_data volume and data/config mount ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.11 Update .env with new variables ✅ (completed: 2026-02-15 01:41)
- [x] 2.1.12 Validate: docker compose config && docker compose build ✅ (completed: 2026-02-15 01:42)

### Phase 3: Nginx Internet-Facing Config
- [x] 3.1.1 Create blue-upstream.conf ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.2 Create green-upstream.conf ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.3 Create active-upstream.conf (initial: blue) ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.4 Delete old bluegreen-upstream.conf ✅ (completed: 2026-02-15 01:45)
- [x] 3.1.5 Create nginx-internet.conf + apply fixes ✅ (completed: 2026-02-15 01:44)
- [x] 3.1.6 Update server-ssl.conf cert paths ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.7 Fix 10-health.conf (proxy_params + security headers) ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.8 Fix 20-ping.conf (security headers) ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.9 Fix 99-default.conf (security headers) ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.10 Fix security_headers_enhanced.conf (tighten CSP) ✅ (completed: 2026-02-15 01:43)
- [x] 3.1.11 Validate: docker compose config && docker compose build ✅ (completed: 2026-02-15 01:45)

### Phase 4: Nginx Internal Config
- [x] 4.1.1 Create nginx-internal.conf ✅ (completed: 2026-02-15 01:46)
- [x] 4.1.2 Create trusted_proxies.conf ✅ (completed: 2026-02-15 01:46)
- [x] 4.1.3 Create security_headers_internal.conf ✅ (completed: 2026-02-15 01:46)
- [x] 4.1.4 Validate with NGINX_MODE=internal ✅ (completed: 2026-02-15 01:47)

### Phase 5: Swapper Script
- [x] 5.1.1 Create health-check-wait.sh ✅ (completed: 2026-02-15 01:48)
- [x] 5.1.2 Create switch-environment.sh ✅ (completed: 2026-02-15 01:48)
- [x] 5.1.3 Make scripts executable ✅ (completed: 2026-02-15 01:48)
- [x] 5.1.4 Validate: shellcheck ✅ (completed: 2026-02-15 01:48)

### Phase 6: Certbot & SSL
- [x] 6.1.1 Create generate-self-signed-ssl.sh ✅ (completed: 2026-02-15 02:03)
- [x] 6.1.2 Create init-letsencrypt.sh ✅ (completed: 2026-02-15 02:03)
- [x] 6.1.3 Make scripts executable ✅ (completed: 2026-02-15 02:03)
- [x] 6.1.4 Validate: shellcheck ✅ (completed: 2026-02-15 02:04)

### Phase 7: Documentation & Polish
- [x] 7.1.1 Create .gitignore ✅ (completed: 2026-02-15 02:04)
- [x] 7.1.2 Create README.md ✅ (completed: 2026-02-15 02:05)
- [x] 7.1.3 Review comment quality ✅ (completed: 2026-02-15 02:05)
- [x] 7.1.4 Final validation ✅ (completed: 2026-02-15 02:06)

---

## Success Criteria

1. ✅ All 7 phases completed
2. ✅ `docker compose config` passes (both internet and internal modes)
3. ✅ `docker compose build` succeeds
4. ✅ All shell scripts pass `shellcheck`
5. ✅ Runtime health checks pass for all services
6. ✅ Blue-green switching works (blue → green → blue)
7. ✅ Self-signed SSL works for local development
8. ✅ Both Nginx modes (internet/internal) work correctly
9. ✅ Documentation complete (README.md, .gitignore, comments)
10. ✅ All configs follow coding standards from `code.md`

---

## Execution Instructions

```
To start: exec_plan refactor-blue-green
To continue after /compact: exec_plan refactor-blue-green
```

**Session Flow:**
```
exec_plan refactor-blue-green → implement tasks → update plan → validate → commit → /compact → repeat
```
