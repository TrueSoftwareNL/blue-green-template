# Current State: Blue-Green Deployment Scaffold

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementations

### Blue-Green Template (this repo)

**What exists and will be reused:**

| File | Purpose | Scaffold Action |
|------|---------|----------------|
| `docker-compose.yml` | Blue-green profiles (core, blue, green, all) | Adapt → template with placeholders |
| `nginx/` (14 files) | Modular security-hardened Nginx config | Copy as-is (minor port placeholder) |
| `scripts/switch-environment.sh` | 11-step zero-downtime switcher | Merge into `remote-ops.sh` |
| `scripts/health-check-wait.sh` | Health check polling helper | Copy as-is |
| `app/Dockerfile` | Demo app container | Replace with tarball-based Dockerfile |
| `.env.example` | Environment template | Adapt → generalized with more options |

**What's missing (needs to be created):**
- GitHub Actions workflows (no CI/CD at all)
- Deployment package builder (no tarball system)
- Config management (no secrets system)
- Remote operations script (no server-side ops)
- Multi-server support
- Scaffolding mechanism

### LogixControl (inspiration source)

**Patterns to adopt:**

| Pattern | LogixControl File | Quality | Our Enhancement |
|---------|------------------|---------|-----------------|
| Subcommand dispatch | `scripts/remote-ops.sh` | ✅ Excellent | Add blue-green commands |
| Secret pushing | `scripts/gh-secrets-sync.sh` | ✅ Excellent | Drive from `deploy-config.json` manifest |
| Tarball builder | `deploy-package.sh` | ✅ Good | Generalize with TODO sections |
| Release pipeline | `.github/workflows/release.yml` | ✅ Good | Add blue-green deploy step |
| Operations panel | `.github/workflows/operations.yml` | ✅ Excellent | Add blue-green + multi-server ops |
| CI workflow | `.github/workflows/build-test.yml` | ✅ Good | Generalize, keep self-hosted cleanup |
| Backup sidecar | `docker/pg-backup.sh` | ✅ Good | Generalize (app name placeholder) |
| SSH setup | release.yml SSH config step | ✅ Good | Reuse with jump host / deploy server support |
| Secrets docs | `.github/SECRETS-SETUP.md` | ✅ Good | Auto-generate from manifest |

**LogixControl weaknesses our design fixes:**

| Problem in LogixControl | Our Solution |
|------------------------|--------------|
| `docker compose up --build -d` causes downtime | Blue-green switching (zero downtime) |
| Hardcoded secret names in workflow YAML | Declarative `deploy-config.json` manifest |
| Only 2 environments (acc/prod) with if/else | N environments from manifest |
| Single server only | Multi-server with matrix / deploy server fan-out |
| Rollback = symlink swap + rebuild (downtime) | Blue-green rollback (instant Nginx switch) |
| No Nginx security layer | Full security hardening |

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `toJSON(secrets)` GitHub Actions behavior changes | Low | High | Test on self-hosted runner, document fallback |
| Self-hosted runner Node.js version mismatch | Low | Medium | Check Node.js version in scripts, document minimum |
| Multi-server fan-out script complexity | Medium | Medium | Start with single-server, add multi-server later |
| Scaffold.js feature creep | Medium | Low | Strict scope per requirements |
