# Execution Plan: Blue-Green Deployment Scaffold

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-03-28 19:10
> **Progress**: 42/42 tasks (100%) ← Phase 9 complete, Phase 10 in progress

## Overview

Implement a curl-installable scaffold that adds complete blue-green deployment infrastructure to any BlendSDK application. Includes Docker, Nginx, GitHub Actions, config management, and multi-server support.

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title | Sessions | Est. Time |
|-------|-------|----------|-----------|
| 1 | Scaffold directory + Nginx templates | 1 | 60 min |
| 2 | Docker infrastructure templates | 1 | 60 min |
| 3 | Remote ops script | 2 | 90 min |
| 4 | Config management scripts | 1 | 60 min |
| 5 | Deploy package script | 1 | 45 min |
| 6 | GitHub Actions — single server | 1-2 | 90 min |
| 7 | GitHub Actions — multi server | 1 | 60 min |
| 8 | Multi-server scripts | 1 | 60 min |
| 9 | Scaffold generator (scaffold.js) | 2 | 120 min |
| 10 | Installer + docs + cleanup | 1 | 60 min |

**Total: ~12 sessions, ~12 hours**

---

## Phase 1: Scaffold Directory + Nginx Templates

### Session 1.1: Create scaffold structure and copy Nginx config

**Reference**: [03-scaffold-structure.md](03-scaffold-structure.md)
**Objective**: Set up `scaffold/templates/` directory and populate with Nginx config files

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, handle commit per active commit mode, then `/compact`.

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 1.1.1 | Create `scaffold/templates/deployment/nginx/` directory tree | directories |
| 1.1.2 | Copy `nginx/nginx.conf` → scaffold template | `scaffold/templates/deployment/nginx/nginx.conf` |
| 1.1.3 | Copy `nginx/conf.d/` → scaffold template | `scaffold/templates/deployment/nginx/conf.d/` |
| 1.1.4 | Copy `nginx/includes/` → scaffold template (all 6 files) | `scaffold/templates/deployment/nginx/includes/` |
| 1.1.5 | Copy `nginx/locations/` → scaffold template (all 4 files) | `scaffold/templates/deployment/nginx/locations/` |
| 1.1.6 | Copy + adapt `nginx/upstreams/` — replace port 3000 with `{{APP_PORT}}` | `scaffold/templates/deployment/nginx/upstreams/` |
| 1.1.7 | Copy `scripts/health-check-wait.sh` → scaffold template | `scaffold/templates/deployment/scripts/health-check-wait.sh` |

**Deliverables**:
- [ ] `scaffold/templates/deployment/nginx/` fully populated (14 files)
- [ ] `scaffold/templates/deployment/scripts/health-check-wait.sh` exists
- [ ] Upstream configs use `{{APP_PORT}}` placeholder

**Verify**: `ls -R scaffold/templates/deployment/`

---

## Phase 2: Docker Infrastructure Templates

### Session 2.1: Docker Compose, Dockerfile, .env, pg-backup, partials

**Reference**: [04-deployment-infra.md](04-deployment-infra.md)
**Objective**: Create all Docker-related template files with placeholders

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 2.1.1 | Create docker-compose.yml template (base: app blue/green, nginx, dozzle) | `scaffold/templates/deployment/docker-compose.yml` |
| 2.1.2 | Create postgres partial for docker-compose | `scaffold/partials/docker-compose-postgres.yml` |
| 2.1.3 | Create redis partial for docker-compose | `scaffold/partials/docker-compose-redis.yml` |
| 2.1.4 | Create pg-backup partial for docker-compose | `scaffold/partials/docker-compose-pgbackup.yml` |
| 2.1.5 | Create Dockerfile template (tarball-based) | `scaffold/templates/deployment/Dockerfile` |
| 2.1.6 | Create .env.example template | `scaffold/templates/deployment/.env.example` |
| 2.1.7 | Create pg-backup.sh template (generalized from LogixControl) | `scaffold/templates/deployment/pg-backup.sh` |

**Deliverables**:
- [ ] docker-compose template with `{{PLACEHOLDER}}` markers
- [ ] Partials for postgres, redis, pg-backup
- [ ] Dockerfile with tarball pattern
- [ ] .env.example with all variables
- [ ] pg-backup.sh generalized

**Verify**: Review templates for `{{PLACEHOLDER}}` syntax

---

## Phase 3: Remote Operations Script

### Session 3.1: remote-ops.sh — core structure + blue-green deploy

**Reference**: [05-remote-ops.md](05-remote-ops.md)
**Objective**: Create the server-side operations script merging LogixControl + switch-environment.sh

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 3.1.1 | Create remote-ops.sh skeleton (header, path detection, helpers, dispatcher) | `scaffold/templates/deployment/scripts/remote-ops.sh` |
| 3.1.2 | Implement deploy commands: setup-dirs, receive-deploy, rebuild | same |
| 3.1.3 | Implement blue-green-deploy command (the core 11-step algorithm) | same |
| 3.1.4 | Implement switch-color and active-color commands | same |

### Session 3.2: remote-ops.sh — operations commands

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 3.2.1 | Implement ops commands: restart-app, restart-all, health-check, wait-healthy, view-logs | same |
| 3.2.2 | Implement rollback command (revert tarball + blue-green deploy) | same |
| 3.2.3 | Implement database commands: backup, run-migrations, purge-database, db-table-counts | same |
| 3.2.4 | Implement help command | same |

**Deliverables**:
- [ ] Complete remote-ops.sh with all subcommands
- [ ] Blue-green deploy algorithm implemented
- [ ] Database commands use `{{PROJECT_NAME}}` placeholder
- [ ] `bash -n` passes

**Verify**: `bash -n scaffold/templates/deployment/scripts/remote-ops.sh`

---

## Phase 4: Config Management Scripts

### Session 4.1: deploy-config.json + resolve-config.js + deploy-config-files.sh + push-secrets.sh

**Reference**: [06-config-management.md](06-config-management.md)
**Objective**: Create the declarative config management system

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 4.1.1 | Create deploy-config.json template | `scaffold/templates/deploy-config.json` |
| 4.1.2 | Create resolve-config.js (Node.js JSON helper) | `scaffold/templates/deployment/scripts/resolve-config.js` |
| 4.1.3 | Create deploy-config-files.sh (GitHub Actions → server) | `scaffold/templates/deployment/scripts/deploy-config-files.sh` |
| 4.1.4 | Create push-secrets.sh (local → GitHub Secrets) | `scaffold/templates/scripts/push-secrets.sh` |

**Deliverables**:
- [ ] deploy-config.json template with example entries
- [ ] resolve-config.js outputs tab-separated config entries
- [ ] deploy-config-files.sh reads manifest + toJSON(secrets)
- [ ] push-secrets.sh with preflight checks, colored output, dry-run

**Verify**: `node --check scaffold/templates/deployment/scripts/resolve-config.js`

---

## Phase 5: Deploy Package Script

### Session 5.1: Generalized deploy-package.sh

**Reference**: [07-deploy-package.md](07-deploy-package.md)
**Objective**: Create generalized tarball builder template

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 5.1.1 | Create deploy-package.sh template with TODO/uncomment sections | `scaffold/templates/deploy-package.sh` |
| 5.1.2 | Include: pack packages, create deployment package.json, resolutions, tarball | same |
| 5.1.3 | Include: optional remote deploy with jump host support | same |
| 5.1.4 | Include: commented-out sections for database resources, static files, custom resources | same |

**Deliverables**:
- [ ] deploy-package.sh template with `{{PROJECT_NAME}}` and TODO sections
- [ ] Works for basic monorepo pack + tarball

**Verify**: `bash -n scaffold/templates/deploy-package.sh`

---

## Phase 6: GitHub Actions — Single Server

### Session 6.1: release-single.yml + build-test.yml

**Reference**: [08-github-actions.md](08-github-actions.md)
**Objective**: Create single-server workflow templates

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 6.1.1 | Create build-test.yml template | `scaffold/templates/.github/workflows/build-test.yml` |
| 6.1.2 | Create release-single.yml template (build → test → deploy with blue-green) | `scaffold/templates/.github/workflows/release-single.yml` |
| 6.1.3 | Create operations-single.yml template | `scaffold/templates/.github/workflows/operations-single.yml` |
| 6.1.4 | Create SECRETS-SETUP.md template | `scaffold/templates/.github/SECRETS-SETUP.md` |

**Deliverables**:
- [ ] build-test.yml with self-hosted runner cleanup
- [ ] release-single.yml with blue-green deploy step
- [ ] operations-single.yml with all operations
- [ ] SECRETS-SETUP.md with placeholder documentation

**Verify**: YAML syntax check on workflow files

---

## Phase 7: GitHub Actions — Multi Server

### Session 7.1: release-multi.yml + operations-multi.yml

**Reference**: [08-github-actions.md](08-github-actions.md), [09-multi-server.md](09-multi-server.md)
**Objective**: Create multi-server workflow templates

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 7.1.1 | Create release-multi.yml (prepare + matrix deploy + deploy-server fan-out) | `scaffold/templates/.github/workflows/release-multi.yml` |
| 7.1.2 | Create operations-multi.yml (server selection + multi-server ops) | `scaffold/templates/.github/workflows/operations-multi.yml` |

**Deliverables**:
- [ ] release-multi.yml with matrix strategy + deploy server path
- [ ] operations-multi.yml with health-check-all + per-server ops

**Verify**: YAML syntax check

---

## Phase 8: Multi-Server Scripts

### Session 8.1: deploy-inventory.json + resolve-servers.js + multi-deploy.sh

**Reference**: [09-multi-server.md](09-multi-server.md)
**Objective**: Create multi-server deployment support scripts

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 8.1.1 | Create deploy-inventory.json template | `scaffold/templates/deploy-inventory.json` |
| 8.1.2 | Create resolve-servers.js (inventory → JSON matrix for GitHub Actions) | `scaffold/templates/deployment/scripts/resolve-servers.js` |
| 8.1.3 | Create multi-deploy.sh (deployment server fan-out script) | `scaffold/templates/deployment/scripts/multi-deploy.sh` |

**Deliverables**:
- [ ] deploy-inventory.json with example environments + servers
- [ ] resolve-servers.js filters by env/scope/filter, outputs JSON
- [ ] multi-deploy.sh parallel batch deployment with reporting

**Verify**: `node --check scaffold/templates/deployment/scripts/resolve-servers.js`

---

## Phase 9: Scaffold Generator

### Session 9.1: scaffold.js — prompts + rendering

**Reference**: [10-scaffold-generator.md](10-scaffold-generator.md)
**Objective**: Create the Node.js interactive scaffold generator (part 1)

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 9.1.1 | Create scaffold.js skeleton (arg parsing, flag-based non-interactive mode) | `scaffold/scaffold.js` |
| 9.1.2 | Implement interactive prompts (readline-based: ask, choose, confirm) | same |
| 9.1.3 | Implement template rendering (placeholder replacement) | same |
| 9.1.4 | Implement conditional assembly (postgres/redis/pg-backup partials) | same |

### Session 9.2: scaffold.js — file generation + summary

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 9.2.1 | Implement file writer (conflict detection, permission setting) | same |
| 9.2.2 | Implement deploy-config.json generation from user answers | same |
| 9.2.3 | Implement deploy-inventory.json generation (if multi-server) | same |
| 9.2.4 | Implement workflow selection (single vs multi) and environment setup | same |
| 9.2.5 | Implement summary output (files created, next steps, documentation links) | same |

**Deliverables**:
- [ ] scaffold.js works interactively
- [ ] scaffold.js works with flags (non-interactive)
- [ ] All templates rendered correctly with placeholders replaced
- [ ] Conditional sections work (postgres yes/no, etc.)
- [ ] Conflict detection works

**Verify**: `node --check scaffold/scaffold.js`

---

## Phase 10: Installer + Documentation + Cleanup

### Session 10.1: install.sh + README + cleanup

**Reference**: [11-installer.md](11-installer.md)
**Objective**: Create the curl entry point, update documentation, clean up

**Tasks**:

| # | Task | File(s) |
|---|------|---------|
| 10.1.1 | Create install.sh (curl entry point) | `install.sh` |
| 10.1.2 | Update README.md with scaffold usage documentation | `README.md` |
| 10.1.3 | Create scaffold/templates/.gitignore template (includes local_data/) | `scaffold/templates/.gitignore.template` |
| 10.1.4 | Create local_data/.gitkeep template | `scaffold/templates/local_data/.gitkeep` |
| 10.1.5 | End-to-end scaffold test (run in temp dir, verify output) | manual |

**Deliverables**:
- [ ] install.sh downloads and runs scaffold.js
- [ ] README.md documents full usage
- [ ] End-to-end scaffold produces valid output

**Verify**: `bash -n install.sh && docker compose config` (on scaffolded output)

---

## Task Checklist (All Phases)

### Phase 1: Scaffold Directory + Nginx Templates ✅
- [x] 1.1.1 Create scaffold/templates/deployment/nginx/ directory tree
- [x] 1.1.2 Copy nginx/nginx.conf → scaffold template
- [x] 1.1.3 Copy nginx/conf.d/ → scaffold template
- [x] 1.1.4 Copy nginx/includes/ → scaffold template (8 files)
- [x] 1.1.5 Copy nginx/locations/ → scaffold template (5 files)
- [x] 1.1.6 Copy + adapt nginx/upstreams/ — {{APP_PORT}} placeholder
- [x] 1.1.7 Copy health-check-wait.sh → scaffold template

### Phase 2: Docker Infrastructure Templates ✅
- [x] 2.1.1 Create docker-compose.yml template (base)
- [x] 2.1.2 Create postgres partial
- [x] 2.1.3 Create redis partial
- [x] 2.1.4 Create pg-backup partial
- [x] 2.1.5 Create Dockerfile template
- [x] 2.1.6 Create .env.example template
- [x] 2.1.7 Create pg-backup.sh template

### Phase 3: Remote Operations Script ✅
- [x] 3.1.1 Create remote-ops.sh skeleton
- [x] 3.1.2 Implement deploy commands
- [x] 3.1.3 Implement blue-green-deploy command
- [x] 3.1.4 Implement switch-color and active-color
- [x] 3.2.1 Implement ops commands
- [x] 3.2.2 Implement rollback command
- [x] 3.2.3 Implement database commands (as partials)
- [x] 3.2.4 Implement help command

### Phase 4: Config Management Scripts ✅
- [x] 4.1.1 Create deploy-config.json template
- [x] 4.1.2 Create resolve-config.js
- [x] 4.1.3 Create deploy-config-files.sh
- [x] 4.1.4 Create push-secrets.sh

### Phase 5: Deploy Package Script ✅
- [x] 5.1.1 Create deploy-package.sh template
- [x] 5.1.2 Include pack + package.json + resolutions
- [x] 5.1.3 Include optional remote deploy
- [x] 5.1.4 Include commented-out resource sections

### Phase 6: GitHub Actions — Single Server ✅
- [x] 6.1.1 Create build-test.yml
- [x] 6.1.2 Create release-single.yml
- [x] 6.1.3 Create operations-single.yml (+ database ops partials)
- [x] 6.1.4 Create SECRETS-SETUP.md

### Phase 7: GitHub Actions — Multi Server ✅
- [x] 7.1.1 Create release-multi.yml (matrix + deploy-server fan-out)
- [x] 7.1.2 Create operations-multi.yml (multi-server ops dispatch)

### Phase 8: Multi-Server Scripts ✅
- [x] 8.1.1 Create deploy-inventory.json template
- [x] 8.1.2 Create resolve-servers.js
- [x] 8.1.3 Create multi-deploy.sh

### Phase 9: Scaffold Generator ✅
- [x] 9.1.1 Create scaffold.js skeleton + arg parsing ✅ (completed: 2026-03-28 20:46)
- [x] 9.1.2 Implement interactive prompts ✅ (completed: 2026-03-28 20:46)
- [x] 9.1.3 Implement template rendering ✅ (completed: 2026-03-28 20:46)
- [x] 9.1.4 Implement conditional assembly ✅ (completed: 2026-03-28 20:46)
- [x] 9.2.1 Implement file writer ✅ (completed: 2026-03-28 20:46)
- [x] 9.2.2 Implement deploy-config.json generation ✅ (completed: 2026-03-28 20:46)
- [x] 9.2.3 Implement deploy-inventory.json generation ✅ (completed: 2026-03-28 20:46)
- [x] 9.2.4 Implement workflow selection + environment setup ✅ (completed: 2026-03-28 20:46)
- [x] 9.2.5 Implement summary output ✅ (completed: 2026-03-28 20:46)

### Phase 10: Installer + Documentation + Cleanup
- [ ] 10.1.1 Create install.sh
- [ ] 10.1.2 Update README.md
- [ ] 10.1.3 Create .gitignore template
- [ ] 10.1.4 Create local_data/.gitkeep template
- [ ] 10.1.5 End-to-end scaffold test

---

## Session Protocol

### Starting a Session

1. Start agent settings: `clear && sleep 3 && scripts/agent.sh start`
2. Reference: "Implement Phase X, Session X.X per `plans/scaffold-deployment/99-execution-plan.md`"

### Ending a Session

1. Verify: `clear && sleep 3 && docker compose config && docker compose build`
2. Handle commit per active commit mode
3. End agent settings: `clear && sleep 3 && scripts/agent.sh finished`
4. Compact: `/compact`

### Between Sessions

1. Review completed tasks in this checklist
2. Start new conversation
3. Run `exec_plan scaffold-deployment` to continue

---

## Dependencies

```
Phase 1 (nginx)
    ↓
Phase 2 (docker) ──→ Phase 3 (remote-ops)
    ↓                     ↓
Phase 4 (config) ──→ Phase 5 (deploy-package)
    ↓                     ↓
Phase 6 (GH single) ──→ Phase 7 (GH multi)
    ↓                     ↓
Phase 8 (multi scripts)   ↓
    ↓                     ↓
Phase 9 (scaffold.js) ←──┘
    ↓
Phase 10 (install + docs)
```

---

## Success Criteria

**Feature is complete when:**

1. ✅ All phases completed
2. ✅ All verification passing (docker compose config, bash -n, node --check)
3. ✅ No warnings/errors
4. ✅ Documentation updated
5. ✅ End-to-end scaffold test passes
6. ✅ **Post-completion:** Ask user to re-analyze project and update `.clinerules/project.md`
