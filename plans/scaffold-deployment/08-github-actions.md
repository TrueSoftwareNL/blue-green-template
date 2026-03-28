# GitHub Actions

> **Document**: 08-github-actions.md
> **Parent**: [Index](00-index.md)

## Workflow Templates

### build-test.yml (always scaffolded)

Based on LogixControl's `build-test.yml`:
- Triggers: push + PR on all branches
- Concurrency: cancel-in-progress per branch
- Self-hosted runner workspace cleanup: `find . -mindepth 1 -delete`
- Steps: checkout → install deps → build → test
- Uses `yarn` (BlendSDK standard)

### release-single.yml (single-server topology)

Based on LogixControl's `release.yml`, enhanced with blue-green:

```
Jobs:
  build_and_test → release (version + publish) → deploy
    deploy steps:
      1. Resolve target (test/acc/prod → server secret)
      2. Setup SSH (with optional jump host)
      3. Pre-deploy health check
      4. Upload remote-ops.sh
      5. Setup remote directories
      6. Deploy tarball (deploy-package.sh)
      7. Deploy Docker/Nginx configuration
      8. Deploy config files from secrets (deploy-config-files.sh + toJSON(secrets))
      9. Blue-green deploy (remote-ops.sh blue-green-deploy)  ← THE KEY CHANGE
      10. Post-deploy health check
```

### release-multi.yml (multi-server topology)

Same as single but with:
- `prepare` job to resolve target servers from `deploy-inventory.json`
- `deploy-direct` job with matrix strategy (for <20 servers)
- `deploy-via-server` job for deployment server fan-out (for 20+ servers)
- Inputs: deploy_scope (all/group/tag/server), deploy_filter, max_parallel

### operations-single.yml

Based on LogixControl's `operations.yml`:
- Operations: deploy-config, restart-app, restart-all, health-check, view-logs, rollback, switch-color
- Conditional: backup, run-migrations, purge-database, db-table-counts (if PostgreSQL)
- Production safety guard (block destructive ops)
- Auto-backup before production migrations

### operations-multi.yml

Same operations plus:
- Server selection: all/group/tag/specific server
- `health-check-all` operation
- Multi-server dispatch via matrix or deploy server

### SECRETS-SETUP.md

Template documenting all required secrets, generated based on:
- Environments from `deploy-config.json`
- Infrastructure secrets (server addresses, jump host, deploy path)
- Per-environment config secrets (from manifest entries)
- SSH key setup instructions

## Common Patterns Across All Workflows

- `concurrency` groups per environment (prevent parallel deploys)
- Self-hosted runner workspace cleanup as first step
- SSH config file approach (not inline options) for jump host support
- Timeout limits per job
- `workflow_dispatch` with choice inputs for environment/operation
