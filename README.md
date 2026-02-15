# Blue-Green Deployment Template

A production-ready **blue-green deployment** infrastructure template using Docker Compose, Nginx, Node.js/Express, PostgreSQL, and Redis.

## Architecture

```
                     ┌─────────────┐
Internet ──────────► │    Nginx    │ ◄── SSL termination, rate limiting
                     │  (reverse   │     security headers, ACME challenges
                     │   proxy)    │
                     └──────┬──────┘
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

**Key feature:** Zero-downtime deployments by switching traffic between blue and green environments.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)
- OpenSSL (for SSL certificate generation)

## Quick Start

### 1. Configure Environment

```bash
# Copy the example .env (adjust values for your setup)
cp .env.example .env   # Or create .env manually — see "Environment Variables"
```

### 2. Choose Deployment Mode

| Mode | Use Case | SSL | Set in `.env` |
|------|----------|-----|---------------|
| **internet** | Public-facing server | ✅ Nginx handles SSL | `NGINX_MODE=internet` |
| **internal** | Behind a main proxy | ❌ Main proxy handles SSL | `NGINX_MODE=internal` |

### 3. Generate SSL Certificates (Internet Mode Only)

```bash
# For local development (self-signed)
./scripts/generate-self-signed-ssl.sh

# For production (Let's Encrypt)
./scripts/init-letsencrypt.sh
```

### 4. Start Services

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

# Nginx
NGINX_MODE=internet          # internet (SSL) | internal (behind proxy)
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# Domain & SSL (internet mode only)
DOMAIN_NAME=example.com
CERTBOT_EMAIL=admin@example.com

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
│   ├── nginx-internet.conf     # Internet-facing config (SSL + HTTPS)
│   ├── nginx-internal.conf     # Internal config (HTTP only, behind proxy)
│   ├── conf.d/                 # Server-level includes
│   ├── includes/               # Reusable config snippets
│   ├── locations/              # Location blocks (numbered for ordering)
│   └── upstreams/              # Blue/green upstream definitions
├── scripts/                    # Automation scripts
│   ├── switch-environment.sh   # Blue-green deployment switcher
│   ├── health-check-wait.sh    # Health check polling utility
│   ├── generate-self-signed-ssl.sh  # Self-signed cert generator
│   └── init-letsencrypt.sh     # Let's Encrypt setup
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
| `internet` | certbot | SSL certificate renewal |
| `all` | Everything | Full stack |

```bash
# Start core + blue
docker compose --profile core --profile blue up -d

# Start everything
docker compose --profile all up -d

# Stop everything
docker compose --profile all down
```

## SSL Certificate Setup

### Local Development (Self-Signed)

```bash
./scripts/generate-self-signed-ssl.sh
# Generates certs in nginx/ssl/ — browser will show warnings
```

### Production (Let's Encrypt)

```bash
# First time — requests certificate from Let's Encrypt
./scripts/init-letsencrypt.sh

# Use --staging flag to test without rate limits
./scripts/init-letsencrypt.sh --staging
```

Certbot auto-renews when running with the `internet` profile.

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
