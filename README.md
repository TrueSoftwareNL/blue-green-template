# Blue-Green Deployment Template

A production-ready **blue-green deployment** infrastructure template using Docker Compose, Nginx, Node.js/Express, PostgreSQL, and Redis.

Designed to operate behind [ProxyBuilder](https://github.com/TrueSoftwareNL/nginx-proxy) — an external reverse proxy that handles SSL termination and certificate management.

## Architecture

```
                     ┌──────────────┐
ProxyBuilder ──────► │    Nginx     │ ◄── Security headers, rate limiting
  (SSL term.)        │  (reverse    │     blue-green routing
                     │   proxy)     │
                     └──────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              ▼                           ▼
     ┌────────────────┐         ┌────────────────┐
     │   App (Blue)   │         │  App (Green)   │   ◄── Only ONE active
     │  N replicas    │         │  N replicas    │       at a time
     └────────┬───────┘         └────────┬───────┘
              │                          │
       ┌──────┴──────────────────────────┴──────┐
       │                                        │
  ┌────▼───────┐                           ┌────▼─────┐
  │ PostgreSQL │                           │  Redis   │
  │   16       │                           │ 7-alpine │
  └────────────┘                           └──────────┘
```

**Key features:**
- **Zero-downtime deployments** by switching traffic between blue and green environments
- **Full security headers** (HSTS, CSP, X-Frame-Options, etc.) — ProxyBuilder is a passthrough proxy that adds no headers
- **Rate limiting** keyed on real client IP (X-Forwarded-For from ProxyBuilder)
- **GDPR-compliant logging** with anonymized IP addresses

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)
- ProxyBuilder (or compatible reverse proxy) handling SSL termination

## Quick Start

### 1. Configure Environment

```bash
# Copy the example .env (adjust values for your setup)
cp .env.example .env
```

### 2. Start Services

```bash
# Start core infrastructure + blue environment
docker compose --profile core --profile blue up -d

# Verify all services are healthy
docker compose ps

# Test health endpoint
curl -sf http://localhost/health | jq .
```

## Blue-Green Switching

### Automatic (Recommended)

```bash
# Switch to the opposite color (auto-detects current)
./scripts/switch-environment.sh

# Force switch to a specific color
./scripts/switch-environment.sh --force-color green
```

The script performs:
1. Builds new Docker image
2. Starts target replicas
3. Waits for health checks
4. Switches Nginx upstream
5. Reloads Nginx (zero downtime)
6. Verifies traffic
7. Stops old replicas
8. Cleans up

### Manual

```bash
# 1. Copy the target upstream config
cp nginx/upstreams/green-upstream.conf nginx/upstreams/active-upstream.conf

# 2. Reload Nginx
docker compose exec nginx nginx -s reload
```

## Environment Variables

Create a `.env` file in the project root:

```env
# Project
COMPOSE_PROJECT_NAME=appname

# App
APP_REPLICAS=2               # Replicas per color (blue or green)
ACTIVE_ENV=blue              # Current active env (managed by switch script)

# Nginx (operates behind ProxyBuilder — HTTP only)
NGINX_HTTP_PORT=80

# Health Checks (used by switching scripts)
HEALTH_CHECK_RETRIES=5
HEALTH_CHECK_INTERVAL=2

# Database
POSTGRES_USER=appuser
POSTGRES_PASSWORD=changeme_secure_password
POSTGRES_DB=appdb

# Redis (optional)
# REDIS_PASSWORD=changeme_redis_password
```

> **Tip:** Copy `.env.example` to `.env` to get started: `cp .env.example .env`

## Project Structure

```
├── app/                        # Node.js application
│   ├── Dockerfile              # Multi-stage Docker build
│   ├── server.js               # Express.js server
│   ├── healthcheck.sh          # Container health check script
│   ├── start.sh                # Container entrypoint
│   └── package.json
├── nginx/                      # Nginx configuration (modular)
│   ├── nginx.conf              # Main config (behind ProxyBuilder)
│   ├── conf.d/                 # Server-level includes
│   ├── includes/               # Reusable config snippets
│   ├── locations/              # Location blocks (numbered for ordering)
│   └── upstreams/              # Blue/green upstream definitions
├── scripts/                    # Automation scripts
│   ├── switch-environment.sh   # Blue-green deployment switcher
│   ├── health-check-wait.sh    # Health check polling utility
│   └── agent.sh                # VS Code settings management
├── data/                       # Persistent volumes
├── docker-compose.yml          # Service definitions
└── .env                        # Environment configuration
```

## Docker Compose Profiles

| Profile | Services | Use Case |
|---------|----------|----------|
| `core` | nginx, postgres, redis | Core infrastructure |
| `blue` | app_blue | Blue environment |
| `green` | app_green | Green environment |
| `all` | Everything | Full stack |
| `db` | postgres | Database only (migrations, backups) |

```bash
# Start core + blue
docker compose --profile core --profile blue up -d

# Start everything
docker compose --profile all up -d

# Stop everything
docker compose --profile all down
```

## Security

This Nginx provides comprehensive security hardening:

- **HSTS** — Strict Transport Security (passed through to browser via ProxyBuilder)
- **CSP** — Content Security Policy (API-focused: `default-src 'none'`)
- **X-Frame-Options** — Clickjacking protection
- **X-Content-Type-Options** — MIME type sniffing prevention
- **Referrer-Policy** — Referrer information control
- **Permissions-Policy** — Browser feature restrictions
- **Rate limiting** — Per-client IP (10 req/s API, 100 req/s health)
- **Connection limiting** — Max 10 concurrent connections per IP
- **IP anonymization** — GDPR-compliant log anonymization

> **Note:** ProxyBuilder operates in passthrough mode — it handles SSL termination only and adds no security headers. All security hardening is handled by this Nginx layer.

## Useful Commands

```bash
# Validate Docker Compose config
docker compose config

# Build all images
docker compose build

# Check service health
docker compose ps

# View logs
docker compose logs nginx --tail=50
docker compose logs app_blue --tail=50

# Validate Nginx config (inside container)
docker compose exec nginx nginx -t

# Reload Nginx (zero downtime)
docker compose exec nginx nginx -s reload

# Test endpoints
curl -sf http://localhost/health | jq .
curl -sf http://localhost/ping | jq .
```

## Troubleshooting

### Services won't start
```bash
docker compose logs --tail=50     # Check all service logs
docker compose ps                  # Check health status
```

### Nginx config errors
```bash
docker compose exec nginx nginx -t  # Test Nginx configuration
docker compose logs nginx --tail=20  # Check Nginx error logs
```

### Health check failures
```bash
# Test app directly (bypassing Nginx)
docker compose exec app_blue curl -sf http://localhost:3000/health
# Test through Nginx
curl -sf http://localhost/health | jq .
```

## License

MIT
