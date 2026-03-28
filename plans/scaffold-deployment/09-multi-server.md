# Multi-Server Deployment

> **Document**: 09-multi-server.md
> **Parent**: [Index](00-index.md)

## Overview

Support deploying to 1-200+ servers per environment with three access modes: direct SSH, jump host, deployment server.

## deploy-inventory.json (committed, no secrets)

```json
{
  "ssh_key_secret": "DEPLOY_SSH_KEY",
  "environments": {
    "test": {
      "access": "direct",
      "servers": [
        { "name": "test-01", "host": "deploy@10.0.1.30" }
      ]
    },
    "acceptance": {
      "access": "jump_host",
      "jump_host_secret": "JUMP_HOST",
      "servers": [
        { "name": "acc-clientA", "host": "deploy@10.0.2.10", "group": "all" },
        { "name": "acc-clientB", "host": "deploy@10.0.2.20", "group": "all" }
      ]
    },
    "production": {
      "access": "deploy_server",
      "deploy_server_secret": "PROD_DEPLOY_SERVER",
      "max_parallel": 10,
      "servers": [
        { "name": "client-001", "host": "10.0.3.1", "group": "batch-1", "tags": ["eu-west"] },
        { "name": "client-200", "host": "10.0.3.200", "group": "batch-10", "tags": ["apac"] }
      ]
    }
  }
}
```

## deployment/scripts/resolve-servers.js

Node.js helper (~50 lines). Reads inventory, filters by scope/filter, outputs JSON array for GitHub Actions matrix:

```
Usage: node resolve-servers.js --env production --scope group --filter batch-1
Output: [{"name":"client-001","host":"10.0.3.1"}, ...]
```

Also outputs: `count`, `access_mode` for workflow routing.

## deployment/scripts/multi-deploy.sh

Runs on the **deployment server** for 20+ server fan-out:

```
Usage: multi-deploy.sh --env production --scope all --max-parallel 10
```

1. Read inventory from local copy
2. Filter servers by scope/filter
3. Group into batches
4. For each batch: deploy to N servers in parallel (background jobs + wait)
5. Collect health check results
6. Generate deployment report

## Decision Tree

```
Server count per environment?
├─ 1 server ──→ Single-server workflow (release-single.yml)
├─ 2-20 servers ──→ Multi-server workflow with GitHub Actions matrix
└─ 20+ servers ──→ Multi-server workflow with deployment server fan-out
```
