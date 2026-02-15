#!/bin/bash
# =============================================================================
# Self-Signed SSL Certificate Generator
# =============================================================================
# Generates self-signed SSL certificates for local development.
# Certificates are placed in nginx/ssl/ — the same path Nginx expects for
# both self-signed and Let's Encrypt certificates.
#
# Usage: ./scripts/generate-self-signed-ssl.sh [domain]
#
# Arguments:
#   domain    Domain name for the certificate (default: from .env or localhost)
#
# Creates:
#   nginx/ssl/fullchain.pem   — Certificate (Nginx ssl_certificate)
#   nginx/ssl/privkey.pem     — Private key (Nginx ssl_certificate_key)
#   nginx/ssl/chain.pem       — Chain (Nginx ssl_trusted_certificate)
#   nginx/ssl/dhparam.pem     — DH parameters (generated once, reused)
#
# Exit codes:
#   0 = Success
#   1 = OpenSSL not available
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Load domain from .env if available
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/.env"
fi
DOMAIN="${1:-${DOMAIN_NAME:-localhost}}"

# Verify openssl is available
if ! command -v openssl &>/dev/null; then
    echo "Error: openssl is not installed" >&2
    exit 1
fi

# Create SSL directory
mkdir -p "$SSL_DIR"

echo "Generating self-signed SSL certificate for: ${DOMAIN}"

# Generate DH parameters (only if not already present — takes a while)
if [[ ! -f "$SSL_DIR/dhparam.pem" ]]; then
    echo "Generating DH parameters (this may take a moment)..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
else
    echo "DH parameters already exist, skipping."
fi

# Generate self-signed certificate (valid for 365 days)
openssl req -x509 \
    -nodes \
    -days 365 \
    -newkey rsa:2048 \
    -keyout "$SSL_DIR/privkey.pem" \
    -out "$SSL_DIR/fullchain.pem" \
    -subj "/C=NL/ST=Local/L=Dev/O=BlueGreen/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN},DNS:localhost,IP:127.0.0.1"

# Create chain.pem (same as fullchain for self-signed — no intermediate CA)
cp "$SSL_DIR/fullchain.pem" "$SSL_DIR/chain.pem"

echo ""
echo "Self-signed SSL certificates generated:"
echo "  Certificate: $SSL_DIR/fullchain.pem"
echo "  Private key: $SSL_DIR/privkey.pem"
echo "  Chain:       $SSL_DIR/chain.pem"
echo "  DH Params:   $SSL_DIR/dhparam.pem"
echo ""
echo "WARNING: Self-signed certificates will show browser warnings."
echo "         This is expected for local development."
