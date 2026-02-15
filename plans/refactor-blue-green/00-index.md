# Refactor Blue-Green Deployment Template

> **Plan Created**: 2026-02-15
> **Status**: Planning Complete — Ready for Execution
> **Estimated Sessions**: 7 (one per phase)

## Overview

Complete refactoring of the blue-green deployment template to implement:
- Working Docker build (fix critical bugs)
- Multi-replica blue/green app services
- Switchable Nginx load balancer with two deployment modes (internet-facing / internal)
- Automated blue-green switching script (zero-downtime deployment)
- Certbot SSL integration + self-signed SSL for local development
- Full documentation

## Architecture

```
INTERNET MODE (NGINX_MODE=internet):
Internet → This Nginx (port 80+443, SSL, certbot, blue/green LB) → App replicas (blue or green)

INTERNAL MODE (NGINX_MODE=internal):
Main Proxy (different machine) → This Nginx (exposed HTTP port, blue/green LB) → App replicas (blue or green)
```

## Plan Documents

| # | Document | Description |
|---|----------|-------------|
| [00](./00-index.md) | Index | This file — overview and navigation |
| [01](./01-requirements.md) | Requirements | All requirements gathered from discussion |
| [02](./02-current-state.md) | Current State | Current implementation analysis and gap report |
| [03](./03-docker-compose.md) | Docker Compose | Docker Compose refactor specification |
| [04](./04-nginx-internet.md) | Nginx Internet | Internet-facing Nginx configuration spec |
| [05](./05-nginx-internal.md) | Nginx Internal | Internal (behind proxy) Nginx configuration spec |
| [06](./06-swapper-script.md) | Swapper Script | Blue-green switching script specification |
| [07](./07-certbot-ssl.md) | Certbot & SSL | Certbot integration + self-signed SSL spec |
| [08](./08-testing-strategy.md) | Testing Strategy | Test cases and verification procedures |
| [99](./99-execution-plan.md) | Execution Plan | Phases, sessions, tasks, and checklist |

## Phases

| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| 1 | Fix Critical Bugs | Working Docker build, fixed scripts |
| 2 | Docker Compose Refactor | Replicas, health checks, networks, NGINX_MODE |
| 3 | Nginx Internet-Facing Config | Switchable upstreams, fixed issues, SSL |
| 4 | Nginx Internal Config | HTTP-only config behind main proxy |
| 5 | Swapper Script | Automated zero-downtime blue-green switching |
| 6 | Certbot + SSL | Auto-renewal, self-signed for dev |
| 7 | Documentation & Polish | .gitignore, README.md |

## Cross-References

- See [`.clinerules/code.md`](../../.clinerules/code.md) for coding standards
- See [`.clinerules/testing.md`](../../.clinerules/testing.md) for validation commands
- See [`.clinerules/agents.md`](../../.clinerules/agents.md) for AI agent rules
- See [`.clinerules/make_plan.md`](../../.clinerules/make_plan.md) for plan execution protocol
