# Technical Spec: Docker Compose Refactor

> **Document**: 03-docker-compose.md
> **Last Updated**: 2026-02-15
> **Affects**: `docker-compose.yml`, `.env`

## 1. Overview

Refactor `docker-compose.yml` to fix the environment merge bug, add replica support, health checks for all services, network isolation, and support for `NGINX_MODE` switching.

---

## 2. YAML Anchor Fix (Environment Merge)

### Problem
YAML `<<:` merge with list-style `environment` causes replacement instead of merging.

### Solution
Switch to **mapping syntax** for environment variables:

```yaml
x-app-base: &app-base
  build: ./app
  restart: always
  environment:
    PORT: "3000"
  deploy:
    replicas: ${APP_REPLICAS:-1}

services:
  app_blue:
    <<: *app-base
    profiles: ["blue", "all"]
    environment:
      PORT: "3000"          # Must repeat because YAML replaces the mapping
      APP_ENV: "blue"

  app_green:
    <<: *app-base
    profiles: ["green", "all"]
    environment:
      PORT: "3000"
      APP_ENV: "green"
```

**Note:** Even with mapping syntax, YAML `<<:` replaces the entire `environment` key. We must include `PORT` in each service. The anchor still provides value for `build`, `restart`, `deploy`, `healthcheck`, and `networks`.

---

## 3. Replica Support

### Implementation
Use `deploy.replicas` with the `APP_REPLICAS` variable from `.env`:

```yaml
x-app-base: &app-base
  build: ./app
  restart: always
  deploy:
    replicas: ${APP_REPLICAS:-1}
```

### How It Works
- Docker Compose creates N containers for each color service
- Docker internal DNS (`127.0.0.11`) resolves the service name to ALL container IPs
- Nginx's `resolve` parameter re-queries DNS periodically
- Nginx load balances across all replicas via DNS round-robin

### `.env` Variable
```env
APP_REPLICAS=5
```

---

## 4. Health Checks

### App Health Check (in anchor — shared by blue and green)
```yaml
x-app-base: &app-base
  healthcheck:
    test: ["CMD", "./healthcheck.sh"]
    interval: 5s
    timeout: 3s
    retries: 3
    start_period: 10s
```

### Redis Health Check
```yaml
redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Nginx Health Check
```yaml
nginx:
  healthcheck:
    test: ["CMD-SHELL", "curl -fs http://localhost:80/health || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 3
```

### PostgreSQL Health Check (already exists, keep as-is)
```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
    interval: 10s
    timeout: 5s
    retries: 5
```

---

## 5. Network Isolation

### Network Definitions
```yaml
networks:
  frontend:
    driver: bridge
    # Nginx ↔ App communication
  backend:
    driver: bridge
    # App ↔ Database/Cache communication
```

### Service Network Assignments

| Service | `frontend` | `backend` |
|---------|-----------|-----------|
| nginx | ✅ | ❌ |
| app_blue | ✅ | ✅ |
| app_green | ✅ | ✅ |
| postgres | ❌ | ✅ |
| redis | ❌ | ✅ |

This ensures Nginx cannot directly reach PostgreSQL or Redis.

---

## 6. Service Dependencies

```yaml
nginx:
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy

# Note: Nginx does NOT depend on app_blue/app_green because:
# - Only one color is active at a time
# - The resolve parameter allows Nginx to start without the upstream being available
# - The swapper script handles startup ordering
```

---

## 7. NGINX_MODE Support

### `.env` Variable
```env
NGINX_MODE=internet
```

### Docker Compose Volume Mount
```yaml
nginx:
  volumes:
    - ./nginx/nginx-${NGINX_MODE}.conf:/etc/nginx/nginx.conf:ro
```

This mounts either `nginx-internet.conf` or `nginx-internal.conf` based on the mode.

### Nginx Port Exposure
```yaml
nginx:
  ports:
    - "${NGINX_HTTP_PORT:-80}:80"
    - "${NGINX_HTTPS_PORT:-443}:443"   # Only used in internet mode
```

For internal mode, only port 80 is needed, but exposing 443 doesn't hurt (nothing listens on it in internal mode).

---

## 8. Certbot Service

```yaml
certbot:
  image: certbot/certbot
  profiles: ["internet"]
  volumes:
    - ./certbot/conf:/etc/letsencrypt
    - ./certbot/www:/var/www/certbot
  entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
  depends_on:
    nginx:
      condition: service_healthy
```

Only starts with `--profile internet` — not needed for internal mode.

---

## 9. Cleanup

### Remove
- `volumes: postgres_data:` (unused named volume at bottom of file)
- `./data/config:/app/config` volume mount (directory doesn't exist)

---

## 10. Updated `.env` Template

```env
# Project
COMPOSE_PROJECT_NAME=appname

# App Configuration
APP_REPLICAS=5
ACTIVE_ENV=blue

# Nginx Mode: "internet" (public-facing with SSL) or "internal" (behind main proxy)
NGINX_MODE=internet
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# Domain (used for SSL certificates in internet mode)
DOMAIN_NAME=example.com

# Health Check Configuration
HEALTH_CHECK_RETRIES=5
HEALTH_CHECK_INTERVAL=2

# PostgreSQL Configuration
POSTGRES_USER=appuser
POSTGRES_PASSWORD=changeme_secure_password
POSTGRES_DB=appdb
```

---

## 11. Target File Structure (docker-compose.yml)

```yaml
x-app-base: &app-base
  build: ./app
  restart: always
  environment:
    PORT: "3000"
  deploy:
    replicas: ${APP_REPLICAS:-1}
  healthcheck:
    test: ["CMD", "./healthcheck.sh"]
    interval: 5s
    timeout: 3s
    retries: 3
    start_period: 10s
  networks:
    - frontend
    - backend

services:
  app_blue:
    <<: *app-base
    profiles: ["blue", "all"]
    environment:
      PORT: "3000"
      APP_ENV: "blue"

  app_green:
    <<: *app-base
    profiles: ["green", "all"]
    environment:
      PORT: "3000"
      APP_ENV: "green"

  redis:
    image: redis:7-alpine
    profiles: ["core", "all"]
    restart: always
    ports:
      - "127.0.0.1:6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  postgres:
    image: postgres:16
    profiles: ["core", "all", "db"]
    restart: always
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - ./data/postgresql:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  certbot:
    image: certbot/certbot
    profiles: ["internet"]
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  nginx:
    image: nginx:alpine
    profiles: ["core", "all"]
    ports:
      - "${NGINX_HTTP_PORT:-80}:80"
      - "${NGINX_HTTPS_PORT:-443}:443"
    volumes:
      - ./nginx/nginx-${NGINX_MODE:-internet}.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/includes:/etc/nginx/includes:ro
      - ./nginx/locations:/etc/nginx/locations:ro
      - ./nginx/upstreams:/etc/nginx/upstreams:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "curl -fs http://localhost:80/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

---

## Cross-References

- **[01-requirements.md](./01-requirements.md)** — Requirements this spec implements
- **[04-nginx-internet.md](./04-nginx-internet.md)** — Internet-facing Nginx config
- **[05-nginx-internal.md](./05-nginx-internal.md)** — Internal Nginx config
- **[99-execution-plan.md](./99-execution-plan.md)** — Implementation tasks
