# Technical Spec: Blue-Green Swapper Script

> **Document**: 06-swapper-script.md
> **Last Updated**: 2026-02-15
> **Affects**: `scripts/switch-environment.sh`, `scripts/health-check-wait.sh`

## 1. Overview

Create a deployment switching script that performs zero-downtime blue-green deployment. The script builds a new Docker image, starts the target color's replicas, waits for health checks, switches Nginx, stops the old color, and cleans up.

---

## 2. Scripts to Create

| Script | Purpose |
|--------|---------|
| `scripts/switch-environment.sh` | Main switching script — orchestrates the full deployment flow |
| `scripts/health-check-wait.sh` | Reusable health check polling — waits for all replicas to be healthy |

---

## 3. Switching Flow (Detailed)

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. DETECT: Read active-upstream.conf → current color (e.g. blue)│
│ 2. TARGET: Opposite color → green                               │
│ 3. BUILD:  docker compose build app_green                       │
│ 4. START:  docker compose --profile green up -d                 │
│            (starts APP_REPLICAS replicas of app_green)           │
│ 5. WAIT:   Poll until ALL green replicas are healthy            │
│    ├── Success → continue to step 6                             │
│    └── Failure → ABORT (tear down green, keep blue running)     │
│ 6. SWITCH: cp green-upstream.conf → active-upstream.conf        │
│ 7. RELOAD: docker compose exec nginx nginx -s reload            │
│ 8. VERIFY: curl /health → confirm environment == green          │
│ 9. STOP:   docker compose --profile blue stop                   │
│10. CLEAN:  docker system prune -f (only dangling/stopped)       │
│11. REPORT: Print success summary                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Script Specification: `scripts/switch-environment.sh`

### Header
```bash
#!/bin/bash
# Blue-Green Deployment Switcher
# Performs zero-downtime switching between blue and green environments
#
# Usage: ./scripts/switch-environment.sh [--force-color blue|green]
#
# Options:
#   --force-color <color>  Force switch to a specific color (default: auto-detect opposite)
#
# Requires:
#   - Docker Compose
#   - .env file with APP_REPLICAS, NGINX_HTTP_PORT
#   - nginx/upstreams/active-upstream.conf (to detect current color)
#
# Exit codes:
#   0 = Success
#   1 = Invalid arguments
#   2 = Build failed
#   3 = Health check failed (replicas didn't start)
#   4 = Nginx reload failed
#   5 = Verification failed (traffic not reaching new color)

set -euo pipefail
```

### Variables
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UPSTREAM_DIR="$PROJECT_ROOT/nginx/upstreams"
ACTIVE_UPSTREAM="$UPSTREAM_DIR/active-upstream.conf"

# Load .env
# shellcheck source=/dev/null
source "$PROJECT_ROOT/.env"

# Configurable settings
HEALTH_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-120}"   # Max seconds to wait for health checks
HEALTH_INTERVAL="${HEALTH_CHECK_INTERVAL:-2}"   # Seconds between health check polls
NGINX_PORT="${NGINX_HTTP_PORT:-80}"
```

### Step 1: Detect Current Active Color
```bash
detect_active_color() {
    if [[ ! -f "$ACTIVE_UPSTREAM" ]]; then
        echo "Error: active-upstream.conf not found at $ACTIVE_UPSTREAM" >&2
        exit 1
    fi

    if grep -q "app_blue" "$ACTIVE_UPSTREAM"; then
        echo "blue"
    elif grep -q "app_green" "$ACTIVE_UPSTREAM"; then
        echo "green"
    else
        echo "Error: Cannot detect active color from $ACTIVE_UPSTREAM" >&2
        exit 1
    fi
}
```

### Step 2: Determine Target Color
```bash
get_target_color() {
    local current="$1"
    if [[ "$current" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}
```

### Step 3: Build New Image
```bash
build_target() {
    local target="$1"
    echo "Building app_${target} image..."
    if ! docker compose build "app_${target}"; then
        echo "Error: Build failed for app_${target}" >&2
        exit 2
    fi
    echo "Build successful."
}
```

### Step 4: Start Target Replicas
```bash
start_target() {
    local target="$1"
    echo "Starting ${APP_REPLICAS} replicas of app_${target}..."
    docker compose --profile "$target" up -d
    echo "Replicas starting..."
}
```

### Step 5: Wait for Health Checks
```bash
wait_for_health() {
    local target="$1"
    echo "Waiting for all app_${target} replicas to be healthy..."

    if ! "$SCRIPT_DIR/health-check-wait.sh" "app_${target}" "$HEALTH_TIMEOUT" "$HEALTH_INTERVAL"; then
        echo "Error: Health checks failed for app_${target}" >&2
        echo "Aborting switch — tearing down ${target} replicas..." >&2
        docker compose --profile "$target" stop
        exit 3
    fi

    echo "All replicas healthy."
}
```

### Step 6: Switch Upstream
```bash
switch_upstream() {
    local target="$1"
    local source="$UPSTREAM_DIR/${target}-upstream.conf"

    if [[ ! -f "$source" ]]; then
        echo "Error: Upstream config not found: $source" >&2
        exit 1
    fi

    echo "Switching Nginx upstream to ${target}..."
    cp "$source" "$ACTIVE_UPSTREAM"
    echo "Upstream switched."
}
```

### Step 7: Reload Nginx
```bash
reload_nginx() {
    echo "Reloading Nginx configuration..."
    if ! docker compose exec nginx nginx -s reload; then
        echo "Error: Nginx reload failed" >&2
        exit 4
    fi
    echo "Nginx reloaded."
}
```

### Step 8: Verify Traffic
```bash
verify_traffic() {
    local target="$1"
    local max_attempts=5
    local attempt=0

    echo "Verifying traffic reaches ${target} environment..."

    while [[ $attempt -lt $max_attempts ]]; do
        local response
        response=$(curl -sf "http://localhost:${NGINX_PORT}/health" 2>/dev/null || true)

        if echo "$response" | grep -q "\"environment\":\"${target}\""; then
            echo "Verification successful — traffic is reaching ${target}."
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 1
    done

    echo "Warning: Could not verify traffic reaches ${target}." >&2
    echo "Response: ${response:-empty}" >&2
    exit 5
}
```

### Step 9: Stop Old Color
```bash
stop_old_color() {
    local old_color="$1"
    echo "Stopping old ${old_color} replicas..."
    docker compose --profile "$old_color" stop
    echo "Old replicas stopped."
}
```

### Step 10: Docker Cleanup
```bash
cleanup_docker() {
    echo "Cleaning up unused Docker resources..."
    # Only removes stopped containers, dangling images, unused networks
    # Does NOT remove running containers or in-use images
    docker system prune -f --filter "until=24h" 2>/dev/null || true
    echo "Cleanup complete."
}
```

### Main Orchestration
```bash
main() {
    local force_color=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force-color)
                force_color="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1" >&2
                exit 1
                ;;
        esac
    done

    # Step 1: Detect current color
    local current_color
    current_color=$(detect_active_color)
    echo "Current active color: ${current_color}"

    # Step 2: Determine target
    local target_color
    if [[ -n "$force_color" ]]; then
        target_color="$force_color"
    else
        target_color=$(get_target_color "$current_color")
    fi
    echo "Target color: ${target_color}"

    if [[ "$current_color" == "$target_color" ]]; then
        echo "Warning: Target color is already active. Proceeding anyway (restart scenario)."
    fi

    # Step 3: Build
    build_target "$target_color"

    # Step 4: Start replicas
    start_target "$target_color"

    # Step 5: Wait for health
    wait_for_health "$target_color"

    # Step 6: Switch upstream
    switch_upstream "$target_color"

    # Step 7: Reload Nginx
    reload_nginx

    # Step 8: Verify
    verify_traffic "$target_color"

    # Step 9: Stop old (only if different from target)
    if [[ "$current_color" != "$target_color" ]]; then
        stop_old_color "$current_color"
    fi

    # Step 10: Cleanup
    cleanup_docker

    echo ""
    echo "========================================="
    echo "  Deployment switch complete!"
    echo "  Active: ${target_color}"
    echo "  Replicas: ${APP_REPLICAS}"
    echo "========================================="
}

main "$@"
```

---

## 5. Script Specification: `scripts/health-check-wait.sh`

### Header
```bash
#!/bin/bash
# Health Check Wait Script
# Polls Docker Compose service health until all replicas are healthy
#
# Usage: ./scripts/health-check-wait.sh <service-name> [timeout-seconds] [poll-interval]
#
# Arguments:
#   service-name    Docker Compose service name (e.g., app_blue)
#   timeout-seconds Maximum seconds to wait (default: 120)
#   poll-interval   Seconds between polls (default: 2)
#
# Exit codes:
#   0 = All replicas healthy
#   1 = Timeout — not all replicas became healthy

set -euo pipefail
```

### Logic
```bash
SERVICE="${1:?Usage: $0 <service-name> [timeout] [interval]}"
TIMEOUT="${2:-120}"
INTERVAL="${3:-2}"

ELAPSED=0

echo "Waiting for ${SERVICE} to be healthy (timeout: ${TIMEOUT}s)..."

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    # Count total and healthy containers for this service
    TOTAL=$(docker compose ps --format json "$SERVICE" 2>/dev/null | wc -l)
    HEALTHY=$(docker compose ps --format json "$SERVICE" 2>/dev/null | grep -c '"healthy"' || true)

    if [[ "$TOTAL" -gt 0 && "$TOTAL" -eq "$HEALTHY" ]]; then
        echo "All ${TOTAL} replicas of ${SERVICE} are healthy (${ELAPSED}s elapsed)."
        exit 0
    fi

    echo "  ${HEALTHY}/${TOTAL} healthy (${ELAPSED}s elapsed)..."
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Timeout: Only ${HEALTHY:-0}/${TOTAL:-0} replicas of ${SERVICE} became healthy after ${TIMEOUT}s." >&2

# Print container logs for debugging
echo "--- Last 20 lines of ${SERVICE} logs ---" >&2
docker compose logs "$SERVICE" --tail=20 2>&1 >&2 || true

exit 1
```

---

## 6. Edge Cases

### Same-color switch (restart scenario)
When `--force-color` matches the current color, the script:
1. Rebuilds the image (picks up code/config changes)
2. Restarts replicas by stopping old and starting new
3. This handles the "config change → restart" use case

### First-time deployment (no active-upstream.conf)
If `active-upstream.conf` doesn't exist, the script should fail with a clear error message. The initial setup should copy `blue-upstream.conf` → `active-upstream.conf`.

### Partial failure recovery
If the script fails mid-way:
- Steps 1-4: No impact — old color still serving
- Step 5 failure: Script tears down target, old keeps running
- Steps 6-7: If Nginx reload fails, the old upstream file was already overwritten. Manual recovery needed (copy old color upstream back).
- Step 9: If stop fails, both colors run — wasteful but not harmful

---

## 7. ShellCheck Compliance

Both scripts must pass `shellcheck` without warnings:
```bash
shellcheck scripts/switch-environment.sh scripts/health-check-wait.sh
```

---

## Cross-References

- **[01-requirements.md](./01-requirements.md)** — Switching flow requirements (Section 3)
- **[03-docker-compose.md](./03-docker-compose.md)** — Docker Compose profiles used by the script
- **[04-nginx-internet.md](./04-nginx-internet.md)** — Upstream file structure
- **[99-execution-plan.md](./99-execution-plan.md)** — Implementation tasks
