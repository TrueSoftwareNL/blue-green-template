# Requirements: Blue-Green Deployment Template Refactor

> **Document**: 01-requirements.md
> **Last Updated**: 2026-02-15

## 1. Project Purpose

A Docker-based template for zero-downtime blue-green deployment of a Node.js application, with Redis (cache/session), PostgreSQL (database), and Nginx (load balancer/router).

---

## 2. Core Architecture Requirements

### 2.1 Services

| Service | Count | Purpose |
|---------|-------|---------|
| App (blue) | N replicas (configurable) | Node.js application — blue environment |
| App (green) | N replicas (configurable) | Node.js application — green environment |
| PostgreSQL | 1 | Database |
| Redis | 1 | Cache / session store |
| Nginx | 1 | Load balancer, blue/green router |
| Certbot | 1 (optional) | SSL certificate auto-renewal (internet mode only) |

### 2.2 Replica Support

- Number of replicas per color is configurable via `APP_REPLICAS` in `.env`
- Only the ACTIVE color runs replicas at any given time
- The INACTIVE color has 0 running containers
- Docker Compose `deploy.replicas` + Docker internal DNS for round-robin load balancing

### 2.3 Nginx Deployment Modes

**Two modes, selected via `NGINX_MODE` in `.env`:**

#### Internet-Facing Mode (`NGINX_MODE=internet`)
- Nginx is the public entry point
- Handles SSL termination (TLS 1.2+)
- HTTP → HTTPS redirect
- Certbot/Let's Encrypt for certificate management
- Full security headers (HSTS, CSP, etc.)
- Self-signed SSL available for local development

#### Internal Mode (`NGINX_MODE=internal`)
- Nginx sits behind a main reverse proxy on a different machine
- HTTP only (no SSL — main proxy handles SSL termination)
- Trusts `X-Forwarded-For` / `X-Forwarded-Proto` from main proxy
- Rate limiting based on `X-Forwarded-For` (not the proxy's IP)
- Exposed on a configurable host port for the main proxy to reach
- No certbot needed
- Subset of security headers (avoids duplicating what main proxy sets)

---

## 3. Blue-Green Switching Requirements

### 3.1 Switching Flow (Zero-Downtime)

```
1. Current state: Color A active (N replicas running), Nginx → Color A
2. Switch triggered
3. Build new Docker image for app
4. Start N replicas of Color B (new version)
5. Wait for ALL Color B replicas to be healthy
6. Switch Nginx upstream → Color B
7. Reload Nginx (zero downtime: nginx -s reload)
8. Verify traffic flows to Color B
9. Stop all Color A replicas
10. Docker cleanup (prune stopped/dangling only — don't touch running containers)
```

### 3.2 Failure Handling

- If Color B replicas fail health checks → abort switch
- Do NOT change Nginx upstream
- Tear down Color B replicas
- Color A stays active and unaffected
- Report failure with diagnostic information

### 3.3 Switch Triggers

The switch script is used when:
1. **New software release** — New code deployed via fresh Docker image build
2. **Problem recovery** — Apps need to be restarted cleanly
3. **Configuration change** — App config changed, requires restart

### 3.4 Active Color Detection

- Read `nginx/upstreams/active-upstream.conf` to determine current active color
- Grep for `app_blue` or `app_green` in the `server` directive
- Target color is always the opposite of current active

---

## 4. SSL / Certificate Requirements

### 4.1 Internet Mode — Let's Encrypt (Production)
- Certbot container runs alongside Nginx
- Checks certificate expiry periodically
- Renews certificates automatically
- Reloads Nginx after successful renewal
- Domain name configurable via `.env`

### 4.2 Internet Mode — Self-Signed (Local Development)
- Script generates self-signed CA + certificate
- Placed in the same path structure as Let's Encrypt (`certbot/conf/live/<domain>/`)
- Same Nginx SSL config works for both self-signed and Let's Encrypt
- Domain configurable (defaults to `localhost`)

### 4.3 Internal Mode
- No SSL needed (main proxy handles it)
- No certbot needed

---

## 5. Docker Compose Requirements

### 5.1 Profiles

| Profile | Services |
|---------|----------|
| `blue` | app_blue |
| `green` | app_green |
| `core` | nginx, redis, postgres |
| `internet` | certbot (only in internet mode) |
| `all` | All services |
| `db` | postgres only |

### 5.2 Health Checks (Mandatory for All Stateful Services)

| Service | Health Check |
|---------|-------------|
| PostgreSQL | `pg_isready -U $USER -d $DB` |
| Redis | `redis-cli ping` |
| App (blue/green) | `curl -fs http://localhost:3000/health` |
| Nginx | `curl -fs http://localhost:80/health` or process check |

### 5.3 Network Isolation

| Network | Services | Purpose |
|---------|----------|---------|
| `frontend` | nginx, app_blue, app_green | Nginx → App communication |
| `backend` | app_blue, app_green, postgres, redis | App → Database/Cache communication |

Nginx should NOT have direct access to PostgreSQL or Redis.

### 5.4 Environment Variables

| Variable | Example | Purpose |
|----------|---------|---------|
| `COMPOSE_PROJECT_NAME` | `appname` | Docker Compose project name |
| `APP_REPLICAS` | `5` | Number of replicas per color |
| `ACTIVE_ENV` | `blue` | Currently active environment |
| `NGINX_MODE` | `internet` or `internal` | Nginx deployment mode |
| `NGINX_PORT` | `80` | Port Nginx exposes (relevant for internal mode) |
| `DOMAIN_NAME` | `example.com` | Domain for SSL certificates |
| `POSTGRES_USER` | `appuser` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `changeme` | PostgreSQL password |
| `POSTGRES_DB` | `appdb` | PostgreSQL database name |

---

## 6. Nginx Configuration Requirements

### 6.1 Upstream Switching Mechanism

```
nginx/upstreams/
├── blue-upstream.conf      # upstream active_app { server app_blue:3000 ... }
├── green-upstream.conf     # upstream active_app { server app_green:3000 ... }
└── active-upstream.conf    # ← Copy of blue or green (Nginx loads this one)
```

- Nginx `include`s only `active-upstream.conf`
- Switch script copies the target color's file → `active-upstream.conf`
- `nginx -s reload` picks up the change with zero downtime

### 6.2 Shared Configuration (Both Modes)

- Location blocks (`/health`, `/ping`, `/nginx_status`, `/` default)
- Upstream definitions (blue, green, active)
- Proxy headers, params, timeouts
- Error pages
- Rate limiting (zone definitions differ between modes)

### 6.3 File Cache, Gzip, Performance

- Shared between both modes
- Already well-configured in current implementation

---

## 7. Application Requirements

### 7.1 Express.js App
- Minimal template app (infrastructure demo, not a full application)
- `/health` — returns `{ status: "healthy", host, environment, timestamp }`
- `/ping` — returns `{ msg: "pong", host, environment }`
- PORT configurable via environment variable
- Graceful shutdown on SIGTERM/SIGINT

### 7.2 Health Check Script
- `#!/bin/sh` (Alpine-compatible)
- Checks `/health` endpoint
- Returns exit code 0 (healthy) or 1 (unhealthy)

---

## 8. Non-Functional Requirements

### 8.1 Security
- No secrets in code (all via `.env`)
- TLS 1.2+ only (internet mode)
- Strong cipher suites
- Security headers (HSTS, CSP, X-Frame-Options, etc.)
- Rate limiting on all public endpoints
- Network isolation (Nginx can't reach database directly)

### 8.2 Documentation
- README.md covering both deployment modes
- All config files commented for junior DevOps engineers
- `.gitignore` for sensitive files

### 8.3 Maintainability
- Modular Nginx configuration (includes/, locations/, upstreams/)
- YAML anchors for shared Docker Compose config
- ShellCheck-compliant shell scripts
- Single responsibility per config file

---

## Cross-References

- **[02-current-state.md](./02-current-state.md)** — Gap analysis against these requirements
- **[99-execution-plan.md](./99-execution-plan.md)** — Implementation phases and tasks
