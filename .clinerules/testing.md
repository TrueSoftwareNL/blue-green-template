# Testing & Validation Standards

## **IMPORTANT**

These rules are **mandatory** and must be applied **strictly and consistently** when working on this project.

---

## **Project Toolchain**

This is an **infrastructure template** project. There is no application test framework (no Vitest, no Jest).
Testing focuses on **configuration validation, build verification, and runtime health checks.**

| Tool | Purpose |
|------|---------|
| **Docker Compose** | Service orchestration, build verification |
| **Nginx** | Reverse proxy config validation (`nginx -t`) |
| **ShellCheck** | Shell script static analysis |
| **curl** | Runtime endpoint testing |
| **docker compose ps** | Service health status verification |

### Project Structure

```
blue-green-template/
├── app/                    # Express.js app, Dockerfile, healthcheck.sh
├── nginx/                  # Modular Nginx configuration
│   ├── nginx.conf          # Main config
│   ├── conf.d/             # Server-level includes
│   ├── includes/           # Reusable config snippets
│   ├── locations/          # Location blocks (numbered)
│   └── upstreams/          # Blue/green upstream definitions
├── scripts/                # Deployment and automation scripts
├── data/                   # Persistent volumes (PostgreSQL, etc.)
├── certbot/                # SSL certificate data
├── docker-compose.yml      # Service definitions with profiles
└── .env                    # Environment configuration
```

---

## **Rule 1: Validation Commands**

### Standard Commands

| Command | Description | When to Use |
|---------|-------------|-------------|
| `clear && docker compose config` | Validate Docker Compose YAML syntax | After ANY `docker-compose.yml` change |
| `clear && docker compose build` | Build all Docker images | After Dockerfile or app code changes |
| `clear && docker compose config && docker compose build` | Full validation | Before task completion / git commit |
| `clear && shellcheck scripts/*.sh app/*.sh` | Validate shell scripts | After ANY shell script change |
| `clear && docker compose --profile core up -d` | Start core infrastructure | For runtime testing |
| `clear && docker compose ps` | Check service health status | After starting services |

### Quick Validation (No Runtime Required)

```bash
# Validate Docker Compose config syntax
clear && docker compose config

# Build all images (catches Dockerfile and dependency errors)
clear && docker compose build

# Validate shell scripts
clear && shellcheck scripts/*.sh app/*.sh

# Full pre-commit validation
clear && docker compose config && docker compose build
```

### Runtime Validation (Services Must Be Running)

```bash
# Start core services + blue environment
clear && docker compose --profile core --profile blue up -d

# Verify all services are healthy
clear && docker compose ps

# Test health endpoint through Nginx
clear && curl -sf http://localhost/health | jq .

# Test ping endpoint through Nginx
clear && curl -sf http://localhost/ping | jq .

# Test health endpoint directly on app (bypassing Nginx)
clear && curl -sf http://localhost:3000/health | jq .

# Validate Nginx config inside the container
clear && docker compose exec nginx nginx -t

# Check Nginx error logs
clear && docker compose logs nginx --tail=20

# Check app logs
clear && docker compose logs app_blue --tail=20

# Stop all services
clear && docker compose --profile all down
```

### Important Notes

- **Always prefix commands with `clear &&`** for clean terminal output
- **Use YARN exclusively** for any Node.js operations — NEVER `npm`, `npx`
- Docker Compose is the primary tool — all validation goes through it

---

## **Rule 2: When to Use Which Validation**

### Use Quick Validation (no runtime) When:

- ✅ Editing `docker-compose.yml` — run `docker compose config`
- ✅ Editing Dockerfiles or app code — run `docker compose build`
- ✅ Editing shell scripts — run `shellcheck`
- ✅ Quick iteration during development
- ✅ Before any git commit

### Use Runtime Validation (services running) When:

- ✅ After changing Nginx configuration (need `nginx -t` inside container)
- ✅ After changing upstream/location routing
- ✅ After changing health check logic
- ✅ After changing environment variables or `.env`
- ✅ Before marking any task as complete
- ✅ When debugging connectivity between services

### Use Full Validation When:

- ✅ Before calling `attempt_completion`
- ✅ Before any git commit
- ✅ After changes that cross service boundaries (app + nginx + docker-compose)

**CRITICAL:** Always run `clear && docker compose config && docker compose build` before marking a task complete!

---

## **Rule 3: Docker Compose Validation**

### Config Validation

Validates YAML syntax, variable interpolation, profile definitions, and service references:

```bash
# Basic validation — catches syntax errors and undefined variables
clear && docker compose config

# Validate a specific profile
clear && docker compose --profile blue config

# Validate all profiles render correctly
clear && docker compose --profile all config
```

### Build Validation

Validates Dockerfiles, COPY instructions, dependency installation:

```bash
# Build all images
clear && docker compose build

# Build a specific service (faster iteration)
clear && docker compose build app_blue

# Build with no cache (clean build)
clear && docker compose build --no-cache
```

### Health Check Validation

After starting services, verify health checks pass:

```bash
# Start services and wait for health checks
clear && docker compose --profile core --profile blue up -d

# Check health status of all services
clear && docker compose ps

# Expected output should show "healthy" for postgres, app_blue
# Watch health checks in real-time
clear && docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

---

## **Rule 4: Nginx Configuration Validation**

Nginx config can only be validated inside the running container (since it uses Docker-specific resolver, upstream names, etc.):

```bash
# Start Nginx service
clear && docker compose --profile core --profile blue up -d

# Validate Nginx configuration syntax
clear && docker compose exec nginx nginx -t

# Expected output:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful

# Reload Nginx after config changes (no downtime)
clear && docker compose exec nginx nginx -s reload

# Check Nginx error logs for issues
clear && docker compose logs nginx --tail=50
```

### What Nginx Validation Catches

- ✅ Syntax errors in `.conf` files
- ✅ Missing include files
- ✅ Invalid directives or parameters
- ✅ Duplicate location blocks
- ✅ SSL certificate path errors

### What Nginx Validation Does NOT Catch

- ❌ Upstream connectivity (app must be running)
- ❌ Rate limit behavior (requires load testing)
- ❌ SSL handshake issues (requires valid certificates)

---

## **Rule 5: Shell Script Validation**

### ShellCheck Static Analysis

```bash
# Validate all shell scripts
clear && shellcheck scripts/*.sh app/*.sh

# Validate a specific script with more detail
clear && shellcheck -x scripts/agent.sh

# Check scripts in app/ directory (healthcheck.sh, start.sh)
clear && shellcheck app/healthcheck.sh app/start.sh
```

### What ShellCheck Catches

- ✅ Quoting issues (`$var` vs `"$var"`)
- ✅ Unused variables
- ✅ Deprecated syntax
- ✅ Portability issues (`#!/bin/sh` scripts using bash-only features)
- ✅ Common pitfalls (`cd` without error handling, etc.)

### Important: Alpine Compatibility

Scripts that run inside Docker containers (e.g., `healthcheck.sh`) must use `#!/bin/sh` because Alpine Linux does not include bash by default. ShellCheck will flag bash-specific features in `#!/bin/sh` scripts.

---

## **Rule 6: Curl-Based Endpoint Testing**

### Health Endpoint

```bash
# Test through Nginx (port 80 → proxy → app)
clear && curl -sf http://localhost/health | jq .

# Expected response:
# {
#   "status": "healthy",
#   "host": "container-id",
#   "environment": "blue",
#   "timestamp": "2026-01-01T00:00:00.000Z"
# }
```

### Ping Endpoint

```bash
# Test through Nginx
clear && curl -sf http://localhost/ping | jq .

# Expected response:
# {
#   "msg": "pong",
#   "host": "container-id",
#   "environment": "blue"
# }
```

### Nginx Status Endpoint

```bash
# Only accessible from Docker network / localhost
clear && curl -sf http://localhost/nginx_status

# Expected: Active connections, request counts, etc.
```

### Testing Error Handling

```bash
# Test 404 handling
clear && curl -sf http://localhost/nonexistent-path || true

# Test with verbose output (shows headers, status codes)
clear && curl -v http://localhost/health 2>&1 | head -30
```

---

## **Rule 7: Infrastructure Change Verification Workflow**

When making infrastructure changes, follow this workflow:

### For Docker Compose Changes

1. Edit `docker-compose.yml`
2. Validate: `clear && docker compose config`
3. Build: `clear && docker compose build`
4. (If runtime test needed) Start: `clear && docker compose --profile core --profile blue up -d`
5. Verify: `clear && docker compose ps`
6. Clean up: `clear && docker compose --profile all down`

### For Nginx Configuration Changes

1. Edit files in `nginx/` directory
2. Start services: `clear && docker compose --profile core --profile blue up -d`
3. Validate config: `clear && docker compose exec nginx nginx -t`
4. Reload Nginx: `clear && docker compose exec nginx nginx -s reload`
5. Test endpoints: `clear && curl -sf http://localhost/health | jq .`
6. Check logs: `clear && docker compose logs nginx --tail=20`
7. Clean up: `clear && docker compose --profile all down`

### For App Code Changes

1. Edit files in `app/` directory
2. Build image: `clear && docker compose build`
3. Start services: `clear && docker compose --profile core --profile blue up -d`
4. Wait for health check: `clear && docker compose ps` (check for "healthy")
5. Test endpoint: `clear && curl -sf http://localhost/health | jq .`
6. Check logs: `clear && docker compose logs app_blue --tail=20`
7. Clean up: `clear && docker compose --profile all down`

### For Shell Script Changes

1. Edit scripts in `scripts/` or `app/`
2. Validate: `clear && shellcheck scripts/*.sh app/*.sh`
3. If script runs in container, rebuild: `clear && docker compose build`
4. Test execution (if applicable)

---

## **Rule 8: Blue-Green Deployment Testing**

### Testing Blue Environment

```bash
# Start core + blue
clear && docker compose --profile core --profile blue up -d

# Verify blue is active
clear && curl -sf http://localhost/health | jq .environment
# Expected: "blue"

# Stop
clear && docker compose --profile all down
```

### Testing Green Environment

```bash
# Start core + green
clear && docker compose --profile core --profile green up -d

# Verify green is active
clear && curl -sf http://localhost/health | jq .environment
# Expected: "green"

# Stop
clear && docker compose --profile all down
```

### Testing Both Environments

```bash
# Start everything
clear && docker compose --profile all up -d

# Verify services
clear && docker compose ps
```

> **Note:** The upstream in `nginx/upstreams/bluegreen-upstream.conf` determines which environment receives traffic. Switching requires changing the upstream server directive and reloading Nginx.

---

## **Rule 9: Debugging Failing Services**

When services fail to start or become unhealthy:

### Step 1: Check Service Status

```bash
clear && docker compose ps
```

### Step 2: Check Logs

```bash
# All services
clear && docker compose logs --tail=50

# Specific service
clear && docker compose logs app_blue --tail=50
clear && docker compose logs nginx --tail=50
clear && docker compose logs postgres --tail=50
```

### Step 3: Inspect Container

```bash
# Get a shell in the container
clear && docker compose exec app_blue sh

# Check if health endpoint responds from inside the container
clear && docker compose exec app_blue curl -sf http://localhost:3000/health
```

### Step 4: Check Network Connectivity

```bash
# Verify DNS resolution between containers
clear && docker compose exec nginx nslookup app_blue

# Test connectivity from Nginx to app
clear && docker compose exec nginx curl -sf http://app_blue:3000/health
```

---

## **Summary**

| Situation | Command |
|-----------|---------|
| Docker Compose YAML changed | `clear && docker compose config` |
| Dockerfile or app code changed | `clear && docker compose build` |
| Shell script changed | `clear && shellcheck scripts/*.sh app/*.sh` |
| Nginx config changed | Start services → `docker compose exec nginx nginx -t` |
| Before task completion | `clear && docker compose config && docker compose build` |
| Before git commit | `clear && docker compose config && docker compose build` |
| Runtime endpoint test | `clear && curl -sf http://localhost/health \| jq .` |
| Full integration test | Start services → test endpoints → check logs → stop |

**Remember:** Always use `clear &&` prefix. Never use `npm` or `npx`. Docker Compose is the primary validation tool.

---

## **Cross-References**

- See **code.md** for coding standards (Docker, Nginx, Shell, JavaScript)
- See **agents.md** for shell command rules and task completion criteria
- See **git-commands.md** for git workflow instructions
