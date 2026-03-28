#!/bin/bash
# =============================================================================
# deploy-config-files.sh — Deploy Config Files to Server
# =============================================================================
# Runs in GitHub Actions during deployment. Reads deploy-config.json to
# determine which config files to deploy, extracts their values from
# GitHub Secrets (via ALL_SECRETS env var), and SCPs them to the server.
#
# Usage:
#   deploy-config-files.sh <environment> <ssh_config> <remote_host> <remote_path>
#
# Arguments:
#   environment  - Environment name (test, acceptance, production)
#   ssh_config   - SSH config file path (e.g., ~/.ssh/config)
#   remote_host  - SSH host alias or IP
#   remote_path  - Remote deployment path (e.g., /opt/{{PROJECT_NAME}})
#
# Environment variables (set by GitHub Actions):
#   ALL_SECRETS  - JSON object of all secrets (${{ toJSON(secrets) }})
#
# Dependencies:
#   - Node.js (for resolve-config.js — no jq needed)
#   - SSH/SCP access to the remote server
# =============================================================================

set -euo pipefail

# ── Arguments ────────────────────────────────────────────────
ENVIRONMENT="${1:?Usage: $0 <environment> <ssh_config> <remote_host> <remote_path>}"
SSH_CONFIG="${2:?Missing ssh_config argument}"
REMOTE_HOST="${3:?Missing remote_host argument}"
REMOTE_PATH="${4:?Missing remote_path argument}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying config files for environment: ${ENVIRONMENT}"
echo "  Remote: ${REMOTE_HOST}:${REMOTE_PATH}"

# ── Resolve config entries ───────────────────────────────────
# resolve-config.js outputs tab-separated: secret_key\tdeploy_path\tname
CONFIG_ENTRIES=$(node "${SCRIPT_DIR}/resolve-config.js" "${ENVIRONMENT}")

if [[ -z "$CONFIG_ENTRIES" ]]; then
  echo "No config entries found for environment: ${ENVIRONMENT}"
  exit 0
fi

# ── Extract secrets and deploy ───────────────────────────────
# ALL_SECRETS is a JSON string from ${{ toJSON(secrets) }}
# We use Node.js to extract individual values (no jq dependency)
SUCCESS=0
FAILED=0

while IFS=$'\t' read -r secret_key deploy_path name; do
  echo "  Deploying: ${name} → ${deploy_path}"

  # Extract the secret value from ALL_SECRETS JSON using Node.js
  SECRET_VALUE=$(node -e "
    const secrets = JSON.parse(process.env.ALL_SECRETS || '{}');
    const value = secrets['${secret_key}'];
    if (value) process.stdout.write(value);
    else process.exit(1);
  " 2>/dev/null) || {
    echo "    ⚠ Secret ${secret_key} not found — skipping"
    FAILED=$((FAILED + 1))
    continue
  }

  # Write to temp file and SCP to server
  local_tmp=$(mktemp)
  printf '%s' "$SECRET_VALUE" > "$local_tmp"

  if scp -F "$SSH_CONFIG" "$local_tmp" "${REMOTE_HOST}:${REMOTE_PATH}/${deploy_path}" 2>/dev/null; then
    echo "    ✅ Deployed"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "    ❌ SCP failed for ${deploy_path}"
    FAILED=$((FAILED + 1))
  fi

  rm -f "$local_tmp"
done <<< "$CONFIG_ENTRIES"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "Config deployment complete: ${SUCCESS} deployed, ${FAILED} failed"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
