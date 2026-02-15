#!/bin/bash
# =============================================================================
# Blue-Green Deployment Switcher
# =============================================================================
# Performs zero-downtime switching between blue and green environments.
#
# Flow:
#   1. Detect current active color from active-upstream.conf
#   2. Determine target color (opposite of current, or forced)
#   3. Build new Docker image for target color
#   4. Start target replicas (APP_REPLICAS count)
#   5. Wait for ALL replicas to pass health checks
#   6. Switch Nginx upstream to target color
#   7. Reload Nginx (zero-downtime — graceful reload)
#   8. Verify traffic reaches the new color
#   9. Stop old color's replicas
#  10. Docker cleanup (remove dangling images/containers)
#  11. Print success summary
#
# Usage: ./scripts/switch-environment.sh [--force-color blue|green]
#
# Options:
#   --force-color <color>  Force switch to a specific color (default: auto-detect)
#
# Requires:
#   - Docker Compose
#   - .env file with APP_REPLICAS, NGINX_HTTP_PORT
#   - nginx/upstreams/active-upstream.conf
#
# Exit codes:
#   0 = Success
#   1 = Invalid arguments or missing configuration
#   2 = Build failed
#   3 = Health check failed (replicas didn't become healthy)
#   4 = Nginx reload failed
#   5 = Verification failed (traffic not reaching new color)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
UPSTREAM_DIR="$PROJECT_ROOT/nginx/upstreams"
ACTIVE_UPSTREAM="$UPSTREAM_DIR/active-upstream.conf"

# Load environment variables from .env
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env file not found at $PROJECT_ROOT/.env" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$PROJECT_ROOT/.env"

# Configurable settings (with defaults from .env or fallback values)
HEALTH_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-120}"
HEALTH_INTERVAL="${HEALTH_CHECK_INTERVAL:-2}"
NGINX_PORT="${NGINX_HTTP_PORT:-80}"

# ---------------------------------------------------------------------------
# Step 1: Detect current active color from upstream config
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Step 2: Get the opposite color
# ---------------------------------------------------------------------------
get_target_color() {
    local current="$1"
    if [[ "$current" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}

# ---------------------------------------------------------------------------
# Step 3: Build the Docker image for the target color
# ---------------------------------------------------------------------------
build_target() {
    local target="$1"
    echo ""
    echo "=== Step 3: Building app_${target} image ==="
    if ! docker compose build "app_${target}"; then
        echo "Error: Build failed for app_${target}" >&2
        exit 2
    fi
    echo "Build successful."
}

# ---------------------------------------------------------------------------
# Step 4: Start target replicas
# ---------------------------------------------------------------------------
start_target() {
    local target="$1"
    echo ""
    echo "=== Step 4: Starting ${APP_REPLICAS:-1} replicas of app_${target} ==="
    docker compose --profile "$target" up -d
    echo "Replicas starting..."
}

# ---------------------------------------------------------------------------
# Step 5: Wait for all replicas to be healthy
# ---------------------------------------------------------------------------
wait_for_health() {
    local target="$1"
    echo ""
    echo "=== Step 5: Waiting for app_${target} health checks ==="

    if ! "$SCRIPT_DIR/health-check-wait.sh" "app_${target}" "$HEALTH_TIMEOUT" "$HEALTH_INTERVAL"; then
        echo "Error: Health checks failed for app_${target}" >&2
        echo "Aborting switch — tearing down ${target} replicas..." >&2
        docker compose --profile "$target" stop
        exit 3
    fi

    echo "All replicas healthy."
}

# ---------------------------------------------------------------------------
# Step 6: Switch the Nginx upstream to target color
# ---------------------------------------------------------------------------
switch_upstream() {
    local target="$1"
    local source="$UPSTREAM_DIR/${target}-upstream.conf"

    echo ""
    echo "=== Step 6: Switching Nginx upstream to ${target} ==="

    if [[ ! -f "$source" ]]; then
        echo "Error: Upstream config not found: $source" >&2
        exit 1
    fi

    cp "$source" "$ACTIVE_UPSTREAM"
    echo "Upstream config switched to ${target}."
}

# ---------------------------------------------------------------------------
# Step 7: Reload Nginx (graceful — no dropped connections)
# ---------------------------------------------------------------------------
reload_nginx() {
    echo ""
    echo "=== Step 7: Reloading Nginx ==="
    if ! docker compose exec nginx nginx -s reload; then
        echo "Error: Nginx reload failed" >&2
        exit 4
    fi
    echo "Nginx reloaded successfully."
}

# ---------------------------------------------------------------------------
# Step 8: Verify traffic reaches the new color
# ---------------------------------------------------------------------------
verify_traffic() {
    local target="$1"
    local max_attempts=5
    local attempt=0
    local response=""

    echo ""
    echo "=== Step 8: Verifying traffic reaches ${target} ==="

    while [[ "$attempt" -lt "$max_attempts" ]]; do
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

# ---------------------------------------------------------------------------
# Step 9: Stop old color's replicas
# ---------------------------------------------------------------------------
stop_old_color() {
    local old_color="$1"
    echo ""
    echo "=== Step 9: Stopping old ${old_color} replicas ==="
    docker compose --profile "$old_color" stop
    echo "Old ${old_color} replicas stopped."
}

# ---------------------------------------------------------------------------
# Step 10: Docker cleanup (only dangling/stopped resources)
# ---------------------------------------------------------------------------
cleanup_docker() {
    echo ""
    echo "=== Step 10: Docker cleanup ==="
    # Only removes stopped containers, dangling images, unused networks
    # Does NOT remove running containers or in-use images
    docker system prune -f --filter "until=24h" 2>/dev/null || true
    echo "Cleanup complete."
}

# ---------------------------------------------------------------------------
# Main orchestration
# ---------------------------------------------------------------------------
main() {
    local force_color=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force-color)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --force-color requires a value (blue or green)" >&2
                    exit 1
                fi
                force_color="$2"
                if [[ "$force_color" != "blue" && "$force_color" != "green" ]]; then
                    echo "Error: --force-color must be 'blue' or 'green', got: $force_color" >&2
                    exit 1
                fi
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [--force-color blue|green]"
                echo ""
                echo "Options:"
                echo "  --force-color <color>  Force switch to blue or green"
                echo "  -h, --help             Show this help"
                exit 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                echo "Usage: $0 [--force-color blue|green]" >&2
                exit 1
                ;;
        esac
    done

    echo "========================================="
    echo "  Blue-Green Deployment Switch"
    echo "========================================="

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
        echo "Note: Target is same as current — this is a restart/rebuild scenario."
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

    # Step 11: Summary
    echo ""
    echo "========================================="
    echo "  Deployment switch complete!"
    echo "  Active: ${target_color}"
    echo "  Replicas: ${APP_REPLICAS:-1}"
    echo "========================================="
}

main "$@"
