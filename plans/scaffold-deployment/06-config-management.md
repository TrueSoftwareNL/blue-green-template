# Config Management

> **Document**: 06-config-management.md
> **Parent**: [Index](00-index.md)

## Overview

Declarative config manifest (`deploy-config.json`) drives both local→GitHub and GitHub→server config deployment.

## deploy-config.json (committed to repo, no secrets)

```json
{
  "configs": [
    {
      "name": "Docker Environment",
      "secret_key": "{ENV}_ENV_FILE",
      "local_file": "local_data/{env}/.env",
      "deploy_path": ".env"
    },
    {
      "name": "App Config",
      "secret_key": "{ENV}_APP_CONFIG",
      "local_file": "local_data/{env}/app-config.json",
      "deploy_path": "app-config.json"
    }
  ],
  "environments": {
    "test": "TEST",
    "acceptance": "ACC",
    "production": "PROD"
  }
}
```

- `{ENV}` → replaced with prefix (TEST, ACC, PROD)
- `{env}` → replaced with directory name (test, acceptance, production)
- `deploy_path` → relative to deployment directory on server

## scripts/push-secrets.sh

Inspired by LogixControl's `gh-secrets-sync.sh` (preflight checks, colored output, dry-run mode), driven by manifest:

```bash
Usage: ./scripts/push-secrets.sh <environment> [--dry-run] [--all]
```

1. Reads `deploy-config.json`
2. Resolves local file paths + secret key names for target environment
3. Uses `gh secret set KEY < local_file` for each entry
4. Uses Node.js for JSON parsing (no jq dependency)
5. Preflight checks: `gh` CLI installed, authenticated, git repo detected, manifest exists

## deployment/scripts/deploy-config-files.sh

Runs in GitHub Actions during deployment:

```bash
Usage: deploy-config-files.sh <environment> <ssh_config> <remote_host> <remote_path>
```

1. Reads `deploy-config.json` using `resolve-config.js`
2. Extracts secret values from `ALL_SECRETS` env var (`${{ toJSON(secrets) }}`)
3. Writes each to temp file, SCPs to server at `deploy_path`
4. Uses Node.js for JSON parsing

## deployment/scripts/resolve-config.js

~30-line Node.js helper. Outputs tab-separated lines: `secret_key\tdeploy_path\tname`

```
Usage: node resolve-config.js <environment> <manifest-path>
Output: ACC_ENV_FILE\t.env\tDocker Environment
```
