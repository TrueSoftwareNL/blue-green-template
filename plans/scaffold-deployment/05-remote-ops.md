# Remote Operations Script

> **Document**: 05-remote-ops.md
> **Parent**: [Index](00-index.md)

## Overview

`deployment/scripts/remote-ops.sh` — single server-side script handling all operations. Merges LogixControl's `remote-ops.sh` subcommand pattern with `switch-environment.sh` blue-green logic.

## Subcommands

### Deploy Commands
| Command | Description |
|---------|-------------|
| `setup-dirs` | Create directory structure on server |
| `receive-deploy` | Copy tarball into Docker build context |
| `blue-green-deploy` | **Full zero-downtime deploy** (build → start new color → health check → switch nginx → stop old) |
| `rebuild` | Rebuild current active color (docker compose up --build -d) |

### Blue-Green Commands
| Command | Description |
|---------|-------------|
| `switch-color` | Manual blue↔green switch without rebuild |
| `active-color` | Print current active color |

### Operations Commands
| Command | Description |
|---------|-------------|
| `restart-app` | Restart current active color containers |
| `restart-all` | Down + up all containers |
| `health-check` | Full health check (containers + app + db) |
| `wait-healthy [secs]` | Loop health check until healthy |
| `view-logs [lines]` | Show last N app log lines |
| `rollback` | Revert to previous tarball + blue-green deploy |
| `health-check-all` | **Multi-server only**: check all servers in inventory |

### Database Commands (conditional on PostgreSQL)
| Command | Description |
|---------|-------------|
| `backup` | Trigger database backup |
| `run-migrations [--backup]` | Restart app to trigger migrations |
| `purge-database` | Drop/recreate DB (acceptance only) |
| `db-table-counts` | Show row counts for all tables |

## blue-green-deploy Flow (the core algorithm)

```
1. Detect current active color from nginx/upstreams/active-upstream.conf
2. Target = opposite color (or --force-color)
3. Copy deployment-latest.tgz into Docker build context
4. docker compose build app_{target}
5. docker compose --profile {target} up -d
6. health-check-wait.sh app_{target} (wait for all replicas healthy)
7. cp {target}-upstream.conf → active-upstream.conf
8. docker compose exec nginx nginx -s reload
9. Verify traffic reaches {target} via /health endpoint
10. docker compose --profile {old} stop
11. docker system prune -f --filter "until=24h"
```

## Key Design Patterns from LogixControl

- `dc()` helper function wraps `docker compose -f` with correct path
- `log_info()`, `log_error()`, `log_warn()`, `log_step()` — consistent logging
- `DEPLOY_PATH` auto-detected from script location
- `main()` with case-statement dispatcher
- `cmd_help()` for usage documentation
