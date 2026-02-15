# Coding Standards

## **IMPORTANT**

These rules are **mandatory** and must be applied **strictly and consistently** across the entire codebase.

---

## Project Overview

This is a **Blue-Green Deployment Infrastructure Template** using:
- **Docker Compose** with profiles for blue/green switching
- **Nginx** as reverse proxy with SSL, rate limiting, and security headers
- **Node.js + Express.js 5** for the application server (plain JavaScript, CommonJS)
- **PostgreSQL 16** as the database
- **Redis** as cache/session store
- **Bash shell scripts** for deployment automation
- **Certbot / Let's Encrypt** for SSL certificates

---

## 1. General Code Quality

1. **DRY Principle (Don't Repeat Yourself)**
   - Eliminate duplicated logic, constants, and patterns across all file types
   - Extract reusable config into shared includes (Nginx) or YAML anchors (Docker Compose)
   - If configuration looks similar in more than one place, refactor it

2. **Clarity Over Cleverness**
   - Write configurations and scripts that are easy to read and reason about
   - Prefer explicit, understandable approaches over short or "smart" solutions
   - Every configuration directive should be understandable by a junior DevOps engineer

3. **Single Responsibility**
   - Each config file, script, or module must have **one clear responsibility**
   - Avoid monolithic config files that handle multiple unrelated concerns

---

## 2. Docker Compose Standards

4. **Use YAML Anchors for Shared Configuration**
   - Define shared service config with `x-` extension fields and YAML anchors (`&anchor`)
   - Reference shared config with merge keys (`<<: *anchor`)
   - Override only what differs per service

   ✅ **Correct (current pattern):**
   ```yaml
   x-app-base: &app-base
     build: ./app
     restart: always
     environment:
       - PORT=3000

   services:
     app_blue:
       <<: *app-base
       profiles: ["blue", "all"]
       environment:
         - APP_ENV=blue
   ```

5. **Use Docker Compose Profiles**
   - Group services by deployment role: `blue`, `green`, `core`, `all`, `db`
   - Core infrastructure (nginx, redis, postgres) uses `core` and `all` profiles
   - App instances use their respective color profile and `all`
   - Start services with: `docker compose --profile <profile> up -d`

6. **Health Checks Are Mandatory for Stateful Services**
   - Every database and stateful service MUST have a `healthcheck` block
   - Use standard health check patterns:
     - PostgreSQL: `pg_isready -U $USER -d $DB`
     - Redis: `redis-cli ping`
     - App: `curl -fs http://localhost:PORT/health`
   - Define `interval`, `timeout`, and `retries`

7. **Environment Variables via `.env` File**
   - All environment-specific values go in `.env`
   - Reference in Docker Compose with `${VARIABLE}` syntax
   - Never hardcode secrets, passwords, or environment-specific values in `docker-compose.yml`

8. **Volume Mounts Must Be Read-Only When Possible**
   - Configuration volumes should use `:ro` (read-only) flag
   - Only data volumes (databases, uploads) should be read-write
   - Follow the existing pattern: `./nginx/conf.d:/etc/nginx/conf.d:ro`

---

## 3. Nginx Configuration Standards

9. **Modular Configuration Structure**
   - Follow the existing directory layout:
     ```
     nginx/
     ├── nginx.conf          # Main config (worker, http block, server blocks)
     ├── conf.d/             # Server-level includes (server_name, SSL certs)
     ├── includes/           # Reusable config snippets (headers, timeouts, SSL)
     ├── locations/          # Location blocks (numbered for ordering)
     └── upstreams/          # Upstream definitions (blue/green)
     ```
   - **NEVER** put location blocks or upstream definitions directly in `nginx.conf`
   - Use `include` directives to assemble configuration

10. **Location File Naming Convention**
    - Prefix location files with numbers for ordering: `10-`, `20-`, `30-`, `99-`
    - Lower numbers = higher priority / more specific routes
    - `99-default.conf` is always the catch-all location
    - Example: `10-health.conf`, `20-ping.conf`, `30-nginx-status.conf`, `99-default.conf`

11. **Security Defaults**
    - Always include `security_headers_enhanced.conf` in HTTPS server blocks
    - Always include `ssl.conf` for TLS configuration
    - Always hide server version: `server_tokens off;`
    - Always use rate limiting zones for public endpoints
    - Restrict monitoring endpoints (e.g., `nginx_status`) to internal networks

12. **Upstream Configuration for Blue-Green**
    - Use dynamic DNS resolution with Docker's internal resolver (`127.0.0.11`)
    - Use `resolve` parameter in `server` directive for dynamic upstream resolution
    - Use `zone` directive for shared memory across workers
    - Configure `keepalive` connections for performance
    - Configure `max_fails` and `fail_timeout` for resilience

13. **Comment All Non-Obvious Configuration**
    - Every `include` directive must have a comment explaining what it includes
    - Rate limit zones must document their purpose and limits
    - Security headers must explain what attack they prevent
    - Upstream configurations must document the deployment strategy

---

## 4. Shell Script Standards

14. **Error Handling Is Mandatory**
    - Every shell script MUST start with `set -e` (exit on error)
    - Use `set -euo pipefail` for strict mode when applicable
    - Handle errors explicitly with meaningful error messages

15. **Use Portable Shell Constructs**
    - Scripts that need bash features: use `#!/bin/bash`
    - Scripts that must be portable (Alpine/Docker): use `#!/bin/sh`
    - Health check scripts (`healthcheck.sh`) MUST use `#!/bin/sh` for Alpine compatibility
    - Deployment scripts can use `#!/bin/bash` for full feature set

16. **ShellCheck Compliance**
    - All shell scripts MUST pass `shellcheck` without warnings
    - Run validation: `clear && shellcheck scripts/*.sh app/*.sh`
    - Fix all warnings — do not use `# shellcheck disable` without documented justification

17. **Script Documentation**
    - Every script must have a header comment explaining:
      - Purpose of the script
      - Usage instructions
      - Required environment variables
      - Exit codes

    ```bash
    #!/bin/bash
    # Blue-green deployment switcher
    # Usage: ./scripts/switch-environment.sh [blue|green]
    # Requires: COMPOSE_PROJECT_NAME (from .env)
    # Exit codes: 0=success, 1=invalid args, 2=health check failed
    ```

---

## 5. JavaScript / Express Standards

18. **Keep the App Server Simple**
    - This is an infrastructure template — the app is intentionally minimal
    - Every endpoint must return JSON responses
    - Always include a `/health` endpoint that returns `{ "status": "healthy" }`
    - Always include environment identification in responses (`APP_ENV`)

19. **Health Check Endpoint Requirements**
    - MUST return HTTP 200 with `{ "status": "healthy" }` when operational
    - SHOULD include: hostname, environment, timestamp
    - MUST respond within the Docker health check timeout (3s default)
    - MUST NOT have external dependencies (database, cache) in basic health checks

20. **Dependencies**
    - Use `yarn install` (never npm) for package management
    - Keep dependencies minimal — only what's needed
    - Pin major versions in `package.json` (e.g., `"express": "^5.1.0"`)
    - No dev dependencies needed for the template app (no build step, no tests in app/)

---

## 6. Security Rules

21. **Never Commit Secrets**
    - Passwords, API keys, and tokens go in `.env` (which should be in `.gitignore`)
    - Use `${VARIABLE}` references in Docker Compose, never literal values
    - SSL certificate paths should reference mount points, not host paths

22. **SSL/TLS Configuration**
    - Only allow TLS 1.2 and TLS 1.3 (`ssl_protocols TLSv1.2 TLSv1.3`)
    - Use strong cipher suites (ECDHE + AES-GCM + CHACHA20)
    - Enable OCSP stapling for performance
    - Enable HSTS with `includeSubDomains` and `preload`
    - Generate DH parameters: `openssl dhparam -out nginx/ssl/dhparam.pem 2048`

23. **Rate Limiting**
    - All public endpoints MUST have rate limiting
    - Health check endpoints can have higher limits (`100r/s`)
    - API endpoints should use standard limits (`10r/s`)
    - Always configure `burst` with `nodelay` for graceful handling

---

## 7. Documentation

24. **Comments Explain WHY, Not Just WHAT**
    - Comment _why_ something is done, not just _what_ is done
    - Complex configuration, edge cases, and non-obvious decisions must always be explained
    - Example: `# DNS resolver for Docker - allows dynamic upstream resolution` ✅

25. **Assume a Junior DevOps Engineer as the Reader**
    - Write comments so that a junior engineer can understand:
      - The intent of the configuration
      - The deployment workflow
      - Any assumptions or constraints
    - Document the blue-green switching process clearly

26. **README Must Cover**
    - Project overview and architecture
    - Prerequisites (Docker, Docker Compose)
    - How to start/stop services
    - How to switch between blue and green
    - How to set up SSL certificates
    - Environment variable documentation

---

## 8. Project Structure Rules

27. **Respect the Existing Directory Layout**
    - `app/` — Application code, Dockerfile, and app-level scripts
    - `nginx/` — All Nginx configuration (modular subdirectories)
    - `scripts/` — Deployment and automation scripts
    - `data/` — Persistent data volumes (database, etc.)
    - `certbot/` — SSL certificate data (Let's Encrypt)
    - `.env` — Environment-specific configuration

28. **New Configuration Files Follow Existing Patterns**
    - New Nginx includes go in `nginx/includes/`
    - New location blocks go in `nginx/locations/` with proper numbering
    - New upstream definitions go in `nginx/upstreams/`
    - New shell scripts go in `scripts/` with descriptive names
    - New Docker services follow the YAML anchor pattern

---

## 9. Maintainability First

29. **Optimize for Long-Term Maintainability**
    - Infrastructure configurations should be easy to modify and extend
    - Use modular patterns so changes are isolated to specific files
    - Future services should be easy and safe to add

30. **Consistency Is Non-Negotiable**
    - Follow existing patterns, naming conventions, and structure
    - Do not introduce new styles or patterns without a strong reason
    - If adding a new location block, follow the `XX-name.conf` pattern
    - If adding a new include, follow the existing `snake_case.conf` pattern

---

## **Summary**

| Area | Key Rule |
|------|----------|
| Docker Compose | YAML anchors, profiles, health checks, `.env` for config |
| Nginx | Modular includes, numbered locations, security defaults |
| Shell Scripts | `set -e`, ShellCheck compliant, documented, portable |
| JavaScript | Minimal, JSON responses, health endpoint, `yarn` only |
| Security | No secrets in code, TLS 1.2+, rate limiting, HSTS |
| Documentation | Comments explain why, junior-friendly, README coverage |

---

## **Cross-References**

- See **testing.md** for validation commands and testing workflow
- See **agents.md** for verification procedures and task completion criteria
- See **plans.md** for task-level breakdowns and implementation planning
- See **git-commands.md** for git workflow instructions
