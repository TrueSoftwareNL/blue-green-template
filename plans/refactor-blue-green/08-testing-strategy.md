# Testing Strategy

> **Document**: 08-testing-strategy.md
> **Last Updated**: 2026-02-15

## 1. Overview

This project is an infrastructure template — there is no application test framework. Testing focuses on configuration validation, build verification, and runtime health checks.

---

## 2. Validation Layers

| Layer | Tool | What It Catches |
|-------|------|-----------------|
| Config Syntax | `docker compose config` | YAML errors, undefined variables, profile issues |
| Build | `docker compose build` | Dockerfile errors, COPY failures, dependency issues |
| Shell Scripts | `shellcheck` | Bash/shell errors, quoting issues, portability |
| Nginx Config | `nginx -t` (inside container) | Syntax errors, missing includes, invalid directives |
| Runtime Health | `docker compose ps` | Service startup, health check pass/fail |
| Endpoint | `curl` | HTTP responses, JSON format, correct routing |
| Integration | Full flow test | End-to-end blue-green switching |

---

## 3. Per-Phase Validation

### Phase 1: Fix Critical Bugs
```bash
# After fixing Dockerfile, start.sh, server.js
clear && docker compose config
clear && docker compose build
```
**Success criteria:** Build completes without errors.

### Phase 2: Docker Compose Refactor
```bash
# Validate config syntax with new structure
clear && docker compose config

# Validate all profiles render correctly
clear && docker compose --profile all config
clear && docker compose --profile blue config
clear && docker compose --profile green config
clear && docker compose --profile core config

# Build
clear && docker compose build
```
**Success criteria:** All profiles valid, build succeeds.

### Phase 3: Nginx Internet-Facing Config
```bash
# Build and start (need SSL certs first — use self-signed)
clear && ./scripts/generate-self-signed-ssl.sh

# Start core + blue
clear && docker compose --profile core --profile blue up -d

# Validate Nginx config inside container
clear && docker compose exec nginx nginx -t

# Test health endpoint (HTTP — no redirect)
clear && curl -sf http://localhost/health | jq .

# Test health endpoint (HTTPS — with self-signed cert)
clear && curl -sfk https://localhost/health | jq .

# Test ping endpoint
clear && curl -sfk https://localhost/ping | jq .

# Check access logs (health should be suppressed)
clear && docker compose logs nginx --tail=20

# Stop
clear && docker compose --profile all down
```
**Success criteria:** `nginx -t` passes, endpoints return correct JSON, health logs suppressed.

### Phase 4: Nginx Internal Config
```bash
# Switch to internal mode
# Set NGINX_MODE=internal in .env

# Start core + blue
clear && docker compose --profile core --profile blue up -d

# Validate Nginx config
clear && docker compose exec nginx nginx -t

# Test health endpoint (HTTP only, no SSL)
clear && curl -sf http://localhost/health | jq .

# Verify no HTTPS listener
clear && curl -sf https://localhost/health 2>&1 || echo "Expected: no HTTPS (correct)"

# Stop
clear && docker compose --profile all down
```
**Success criteria:** Internal Nginx works on HTTP only, no SSL errors.

### Phase 5: Swapper Script
```bash
# Validate shell scripts
clear && shellcheck scripts/switch-environment.sh scripts/health-check-wait.sh

# Set up initial state (blue active)
cp nginx/upstreams/blue-upstream.conf nginx/upstreams/active-upstream.conf

# Start core + blue
clear && docker compose --profile core --profile blue up -d

# Wait for healthy
clear && docker compose ps

# Verify blue is active
clear && curl -sf http://localhost/health | jq .environment
# Expected: "blue"

# Run switch
clear && ./scripts/switch-environment.sh

# Verify green is now active
clear && curl -sf http://localhost/health | jq .environment
# Expected: "green"

# Verify blue is stopped
clear && docker compose ps
# Expected: app_blue containers stopped/removed

# Switch back
clear && ./scripts/switch-environment.sh

# Verify blue is active again
clear && curl -sf http://localhost/health | jq .environment
# Expected: "blue"

# Stop
clear && docker compose --profile all down
```
**Success criteria:** Switch blue→green→blue works, zero downtime during switch.

### Phase 6: Certbot + SSL
```bash
# Test self-signed generation
clear && ./scripts/generate-self-signed-ssl.sh localhost
ls -la nginx/ssl/

# Verify Nginx starts with self-signed certs
clear && docker compose --profile core --profile blue up -d
clear && docker compose exec nginx nginx -t
clear && curl -sfk https://localhost/health | jq .

# Stop
clear && docker compose --profile all down

# Note: Let's Encrypt testing requires a real domain + DNS
# Use --staging flag for testing: ./scripts/init-letsencrypt.sh --staging
```

### Phase 7: Documentation
```bash
# Verify .gitignore works
clear && git status
# .env, nginx/ssl/*.pem, data/postgresql/, certbot/ should be ignored

# Verify README renders (visual check)
```

---

## 4. Integration Test Checklist

### Full System Test (Internet Mode)
- [ ] Generate self-signed SSL: `./scripts/generate-self-signed-ssl.sh`
- [ ] Set `NGINX_MODE=internet` in `.env`
- [ ] Start core + blue: `docker compose --profile core --profile blue up -d`
- [ ] All services healthy: `docker compose ps` → all show "healthy"
- [ ] Health endpoint works (HTTP): `curl -sf http://localhost/health`
- [ ] Health endpoint works (HTTPS): `curl -sfk https://localhost/health`
- [ ] Ping endpoint works: `curl -sfk https://localhost/ping`
- [ ] Nginx status restricted: `curl -sf http://localhost/nginx_status` (should work from localhost)
- [ ] HTTP redirects to HTTPS: `curl -sI http://localhost/ping` → 301
- [ ] Switch to green: `./scripts/switch-environment.sh`
- [ ] Green is active: `curl -sfk https://localhost/health | jq .environment` → "green"
- [ ] Switch back to blue: `./scripts/switch-environment.sh`
- [ ] Blue is active: `curl -sfk https://localhost/health | jq .environment` → "blue"
- [ ] Cleanup: `docker compose --profile all down`

### Full System Test (Internal Mode)
- [ ] Set `NGINX_MODE=internal` in `.env`
- [ ] Start core + blue: `docker compose --profile core --profile blue up -d`
- [ ] All services healthy: `docker compose ps`
- [ ] Health endpoint works (HTTP): `curl -sf http://localhost/health`
- [ ] No HTTPS: `curl -sf https://localhost/health` → connection refused
- [ ] Switch to green: `./scripts/switch-environment.sh`
- [ ] Green is active: `curl -sf http://localhost/health | jq .environment` → "green"
- [ ] Cleanup: `docker compose --profile all down`

---

## 5. Failure Scenario Tests

### Swapper script failure handling
```bash
# Test: What happens when new color fails health checks?
# Simulate by breaking the app (e.g., wrong port in .env)

# 1. Start blue (working)
docker compose --profile core --profile blue up -d

# 2. Break green by temporarily modifying something
# 3. Run switch
./scripts/switch-environment.sh
# Expected: Script aborts, blue stays active, green torn down

# 4. Verify blue still serves traffic
curl -sf http://localhost/health | jq .environment
# Expected: "blue"
```

---

## 6. Quick Reference: Common Validation Commands

```bash
# Config validation (no runtime needed)
clear && docker compose config
clear && docker compose build
clear && shellcheck scripts/*.sh app/*.sh

# Full pre-commit validation
clear && docker compose config && docker compose build

# Runtime validation
clear && docker compose --profile core --profile blue up -d
clear && docker compose ps
clear && docker compose exec nginx nginx -t
clear && curl -sf http://localhost/health | jq .
clear && docker compose --profile all down
```

---

## Cross-References

- **[`.clinerules/testing.md`](../../.clinerules/testing.md)** — Base testing standards
- **[06-swapper-script.md](./06-swapper-script.md)** — Switch script testing
- **[99-execution-plan.md](./99-execution-plan.md)** — Per-task validation commands
