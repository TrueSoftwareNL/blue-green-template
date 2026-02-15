#!/bin/bash
# =============================================================================
# Let's Encrypt SSL Certificate Initializer
# =============================================================================
# Sets up Let's Encrypt SSL certificates via Certbot for production use.
# Handles first-time setup: generates temporary self-signed certs so Nginx
# can start, then requests real certs from Let's Encrypt via ACME challenge.
#
# Usage: ./scripts/init-letsencrypt.sh [--staging]
#
# Options:
#   --staging    Use Let's Encrypt staging server (for testing, avoids rate limits)
#
# Requires:
#   - Docker Compose
#   - .env with DOMAIN_NAME and optionally CERTBOT_EMAIL
#   - Nginx must be able to start (for ACME challenge)
#   - DNS for DOMAIN_NAME must point to this server
#
# Creates:
#   nginx/ssl/fullchain.pem   — Certificate (copied from certbot)
#   nginx/ssl/privkey.pem     — Private key (copied from certbot)
#   nginx/ssl/chain.pem       — Chain (copied from certbot)
#   nginx/ssl/dhparam.pem     — DH parameters
#   certbot/conf/             — Certbot data (renewal configs, accounts)
#
# Exit codes:
#   0 = Success
#   1 = Missing configuration
#   2 = Certbot failed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Load .env
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env file not found at $PROJECT_ROOT/.env" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$PROJECT_ROOT/.env"

DOMAIN="${DOMAIN_NAME:?DOMAIN_NAME must be set in .env}"
EMAIL="${CERTBOT_EMAIL:-}"
STAGING=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --staging) STAGING="--staging"; shift ;;
        -h|--help)
            echo "Usage: $0 [--staging]"
            echo ""
            echo "Options:"
            echo "  --staging  Use Let's Encrypt staging server (for testing)"
            exit 0
            ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

echo "Initializing Let's Encrypt for domain: ${DOMAIN}"
if [[ -n "$STAGING" ]]; then
    echo "Using STAGING server (certificates won't be trusted by browsers)"
fi

# Create required directories
mkdir -p "$PROJECT_ROOT/certbot/conf"
mkdir -p "$PROJECT_ROOT/certbot/www"
mkdir -p "$SSL_DIR"

# Generate DH parameters (if not present)
if [[ ! -f "$SSL_DIR/dhparam.pem" ]]; then
    echo "Generating DH parameters..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
fi

# Generate temporary self-signed cert so Nginx can start for ACME challenge
if [[ ! -f "$SSL_DIR/fullchain.pem" ]]; then
    echo "Creating temporary self-signed certificate for Nginx startup..."
    openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
        -keyout "$SSL_DIR/privkey.pem" \
        -out "$SSL_DIR/fullchain.pem" \
        -subj "/CN=${DOMAIN}"
    cp "$SSL_DIR/fullchain.pem" "$SSL_DIR/chain.pem"
fi

# Start Nginx (needed to serve ACME challenge on port 80)
echo "Starting Nginx for ACME challenge..."
docker compose --profile core up -d nginx

# Wait for Nginx to be ready
echo "Waiting for Nginx to start..."
sleep 5

# Build certbot command arguments as an array (ShellCheck-safe)
CERTBOT_ARGS=(certonly --webroot --webroot-path=/var/www/certbot)

if [[ -n "$STAGING" ]]; then
    CERTBOT_ARGS+=("$STAGING")
fi

if [[ -n "$EMAIL" ]]; then
    CERTBOT_ARGS+=(--email "$EMAIL")
else
    CERTBOT_ARGS+=(--register-unsafely-without-email)
fi

CERTBOT_ARGS+=(--agree-tos --no-eff-email)
CERTBOT_ARGS+=(-d "${DOMAIN}" -d "www.${DOMAIN}")

# Request certificate from Let's Encrypt
echo "Requesting certificate from Let's Encrypt..."
if ! docker compose run --rm certbot "${CERTBOT_ARGS[@]}"; then
    echo "Error: Certbot failed to obtain certificate" >&2
    exit 2
fi

# Copy certificates to Nginx SSL directory (stable paths)
CERT_DIR="$PROJECT_ROOT/certbot/conf/live/${DOMAIN}"
if [[ -d "$CERT_DIR" ]]; then
    echo "Copying certificates to Nginx SSL directory..."
    cp "$CERT_DIR/fullchain.pem" "$SSL_DIR/fullchain.pem"
    cp "$CERT_DIR/privkey.pem" "$SSL_DIR/privkey.pem"
    cp "$CERT_DIR/chain.pem" "$SSL_DIR/chain.pem"

    # Reload Nginx with real certificates (zero downtime)
    docker compose exec nginx nginx -s reload
    echo "Nginx reloaded with Let's Encrypt certificates."
else
    echo "Error: Certificate directory not found: $CERT_DIR" >&2
    exit 2
fi

echo ""
echo "========================================="
echo "  Let's Encrypt setup complete!"
echo "  Domain: ${DOMAIN}"
echo "  Certs:  $SSL_DIR/"
echo "========================================="
echo ""
echo "Auto-renewal: Start certbot service with:"
echo "  docker compose --profile internet up -d certbot"
