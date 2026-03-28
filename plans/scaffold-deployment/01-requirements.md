# Requirements: Blue-Green Deployment Scaffold

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)

## Feature Overview

Create a curl-installable scaffold that generates a complete blue-green deployment infrastructure for any BlendSDK/WebAFX application. The scaffold handles everything from Docker configuration to GitHub Actions CI/CD pipelines, supporting topologies from single-server to 200+ multi-tenant deployments.

## Functional Requirements

### Must Have

- [ ] `install.sh` — curl one-liner that downloads and runs the Node.js scaffold generator
- [ ] `scaffold.js` — interactive Node.js generator (zero external deps) with flag-based non-interactive mode
- [ ] `deployment/docker-compose.yml` — blue-green profiles (core, blue, green, all) with optional postgres, redis, pg-backup, dozzle
- [ ] `deployment/Dockerfile` — generalized tarball-based app container
- [ ] `deployment/.env.example` — comprehensive environment template
- [ ] `deployment/nginx/` — full modular Nginx config (security headers, rate limiting, upstream switching)
- [ ] `deployment/scripts/remote-ops.sh` — server-side ops script with blue-green deploy + standard operations
- [ ] `deployment/scripts/health-check-wait.sh` — health check helper
- [ ] `deployment/scripts/deploy-config-files.sh` — manifest-driven config deployment (secrets → server)
- [ ] `deployment/scripts/resolve-config.js` — Node.js JSON helper for deploy-config.json
- [ ] `deploy-config.json` — declarative config manifest (local files → GitHub secrets → server paths)
- [ ] `scripts/push-secrets.sh` — push local config files to GitHub Secrets via manifest
- [ ] `deploy-package.sh` — generalized tarball builder with TODO/uncomment sections
- [ ] `.github/workflows/release.yml` — build → test → blue-green deploy pipeline
- [ ] `.github/workflows/operations.yml` — operations panel (health, rollback, logs, restart, deploy-config, etc.)
- [ ] `.github/workflows/build-test.yml` — CI for PRs (build + test, self-hosted runner cleanup)
- [ ] `.github/SECRETS-SETUP.md` — comprehensive secrets documentation
- [ ] `deployment/pg-backup.sh` — PostgreSQL backup sidecar (conditional on postgres selection)
- [ ] Dozzle log viewer service in docker-compose (always included)
- [ ] Self-hosted runner workspace cleanup in all workflow files

### Should Have

- [ ] `deploy-inventory.json` — server inventory for multi-server deployments
- [ ] `deployment/scripts/resolve-servers.js` — Node.js helper for server resolution
- [ ] `deployment/scripts/multi-deploy.sh` — deployment server fan-out script
- [ ] Batched/staged deployment support for 200+ servers
- [ ] Tagged deployment support (deploy to specific groups/tags)
- [ ] Production safety guards (block destructive ops)
- [ ] Auto-backup before production migrations

### Won't Have (Out of Scope)

- SSL/TLS handling (ProxyBuilder's responsibility)
- Centralized monitoring stack (Grafana/Prometheus) — documented as recommendation only
- Per-server secrets/config (all servers in an environment share the same config)
- Application code scaffolding (only deployment infrastructure)
- Database migration framework (app-specific concern)

## Deployment Topology Matrix

| Scenario | Access Mode | Server Count | Deployment Method |
|----------|-------------|-------------|-------------------|
| Single server, direct SSH | `direct` | 1 | GitHub Actions → SSH → server |
| Single server, via jump host | `jump_host` | 1 | GitHub Actions → SSH → jump → server |
| Multi-server, direct SSH | `direct` | 2-20 | GitHub Actions matrix (parallel jobs) |
| Multi-server, via jump host | `jump_host` | 2-20 | GitHub Actions matrix via jump host |
| Multi-server, via deploy server | `deploy_server` | 20+ | GitHub Actions → deploy server → fan-out |

## Scaffold Generator Questions

The `scaffold.js` interactive generator asks:

| # | Question | Default | Affects |
|---|----------|---------|---------|
| 1 | Project name | `my-app` | docker-compose, deploy-package, .env |
| 2 | App port | `3000` | Dockerfile, docker-compose, nginx, health checks |
| 3 | Nginx host port | `80` | docker-compose, .env |
| 4 | App entry point | `node dist/main.js` | Dockerfile |
| 5 | Include PostgreSQL? | yes | docker-compose, .env, remote-ops, pg-backup |
| 6 | Include Redis? | yes | docker-compose, .env |
| 7 | Environments | `test,acceptance,production` | GitHub Actions, deploy-config, inventory |
| 8 | Servers per env + access method | `1, direct` | GitHub Actions, inventory |
| 9 | Max parallel (if multi) | `10` | GitHub Actions, multi-deploy |
| 10 | App replicas per color | `2` | .env, docker-compose |

## Acceptance Criteria

1. [ ] Running `curl -fsSL .../install.sh | bash` from an empty directory scaffolds all files
2. [ ] Running with `--name myapp --port 8080` flags works non-interactively
3. [ ] Scaffolded `docker compose config` validates without errors
4. [ ] Scaffolded GitHub Actions workflows have valid YAML syntax
5. [ ] All scripts are executable and pass `shellcheck` (where applicable)
6. [ ] `push-secrets.sh` successfully pushes to GitHub Secrets (manual verification)
7. [ ] Single-server blue-green deploy works end-to-end (manual verification on test server)
8. [ ] Documentation is clear enough for a new developer to set up deployment
