# Technical Spec: Certbot & SSL Configuration

> **Document**: 07-certbot-ssl.md
> **Last Updated**: 2026-02-15
> **Affects**: `docker-compose.yml`, `nginx/conf.d/server-ssl.conf`, `nginx/ssl/`, `scripts/generate-self-signed-ssl.sh`, `scripts/init-letsencrypt.sh`

## 1. Overview

Implement SSL certificate management with two strategies:
1. **Self-signed certificates** for local development (internet mode)
2. **Let's Encrypt via Certbot** for production (internet mode)
3. **No SSL** for internal mode (behind main proxy)

---

## 2. SSL Architecture

### Certificate Storage Strategy

Use stable paths in `nginx/ssl/` that Nginx always points to. Both self-signed and Let's Encrypt scripts place certs at these paths.

```
nginx/ssl/
├── fullchain.pem       # SSL certificate + chain (Nginx reads this)
├── privkey.pem         # Private key (Nginx reads this)
├── chain.pem           # Certificate chain for OCSP stapling
└── dhparam.pem         # Diffie-Hellman parameters (generated once)
```

### How Certs Get There

| Mode | Script | Source | Destination |
|------|--------|--------|-------------|
| Dev (self-signed) | `scripts/generate-self-signed-ssl.sh` | OpenSSL generated | `nginx/ssl/*.pem` |
| Prod (Let's Encrypt) | `scripts/init-letsencrypt.sh` | Certbot | `certbot/conf/live/<domain>/` → symlinked/copied to `nginx/ssl/` |

---

## 3. Nginx SSL Config Update

### File: `nginx/conf.d/server-ssl.conf`

```nginx
# SSL certificates — stable paths for both self-signed (dev) and Let's Encrypt (prod)
# Managed by: scripts/generate-self-signed-ssl.sh (dev) or scripts/init-letsencrypt.sh (prod)
ssl_certificate /etc/nginx/ssl/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/privkey.pem;
ssl_trusted_certificate /etc/nginx/ssl/chain.pem;
```

This replaces the current hardcoded `example.com` paths.

---

## 4. Self-Signed SSL Script

### File: `scripts/generate-self-signed-ssl.sh`

```bash
#!/bin/bash
# Generate self-signed SSL certificates for local development
#
# Usage: ./scripts/generate-self-signed-ssl.sh [domain]
#
# Arguments:
#   domain    Domain name for the certificate (default: localhost)
#
# Creates certificates in nginx/ssl/ directory
# These work with the same Nginx SSL config as Let's Encrypt certificates
#
# Exit codes:
#   0 = Success
#   1 = OpenSSL not available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Load domain from .env or use argument or default
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/.env"
fi
DOMAIN="${1:-${DOMAIN_NAME:-localhost}}"

# Create SSL directory
mkdir -p "$SSL_DIR"

echo "Generating self-signed SSL certificate for: ${DOMAIN}"

# Generate DH parameters (if not already present)
if [[ ! -f "$SSL_DIR/dhparam.pem" ]]; then
    echo "Generating DH parameters (this may take a moment)..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
fi

# Generate self-signed certificate
openssl req -x509 \
    -nodes \
    -days 365 \
    -newkey rsa:2048 \
    -keyout "$SSL_DIR/privkey.pem" \
    -out "$SSL_DIR/fullchain.pem" \
    -subj "/C=NL/ST=Local/L=Dev/O=BlueGreen/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN},DNS:localhost,IP:127.0.0.1"

# Create chain.pem (same as fullchain for self-signed)
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
```

---

## 5. Let's Encrypt Init Script

### File: `scripts/init-letsencrypt.sh`

```bash
#!/bin/bash
# Initialize Let's Encrypt SSL certificates using Certbot
#
# Usage: ./scripts/init-letsencrypt.sh [--staging]
#
# Options:
#   --staging    Use Let's Encrypt staging server (for testing, avoids rate limits)
#
# Requires:
#   - Docker Compose
#   - .env with DOMAIN_NAME
#   - Nginx running (for ACME challenge)
#   - DNS pointing to this server
#
# Exit codes:
#   0 = Success
#   1 = Missing configuration
#   2 = Certbot failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_ROOT/nginx/ssl"

# Load .env
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env file not found" >&2
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
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

echo "Initializing Let's Encrypt for domain: ${DOMAIN}"

# Create directories
mkdir -p "$PROJECT_ROOT/certbot/conf"
mkdir -p "$PROJECT_ROOT/certbot/www"
mkdir -p "$SSL_DIR"

# Generate DH parameters (if not present)
if [[ ! -f "$SSL_DIR/dhparam.pem" ]]; then
    echo "Generating DH parameters..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
fi

# Generate temporary self-signed cert so Nginx can start
if [[ ! -f "$SSL_DIR/fullchain.pem" ]]; then
    echo "Creating temporary self-signed certificate for Nginx startup..."
    openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
        -keyout "$SSL_DIR/privkey.pem" \
        -out "$SSL_DIR/fullchain.pem" \
        -subj "/CN=${DOMAIN}"
    cp "$SSL_DIR/fullchain.pem" "$SSL_DIR/chain.pem"
fi

# Start Nginx (needed for ACME challenge)
echo "Starting Nginx for ACME challenge..."
docker compose --profile core up -d nginx

# Wait for Nginx to be ready
sleep 5

# Request certificate from Let's Encrypt
echo "Requesting certificate from Let's Encrypt..."
EMAIL_ARG=""
if [[ -n "$EMAIL" ]]; then
    EMAIL_ARG="--email ${EMAIL}"
else
    EMAIL_ARG="--register-unsafely-without-email"
fi

docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    ${STAGING} \
    ${EMAIL_ARG} \
    --agree-tos \
    --no-eff-email \
    -d "${DOMAIN}" \
    -d "www.${DOMAIN}"

# Copy certificates to Nginx SSL directory
CERT_DIR="$PROJECT_ROOT/certbot/conf/live/${DOMAIN}"
if [[ -d "$CERT_DIR" ]]; then
    echo "Copying certificates to Nginx SSL directory..."
    cp "$CERT_DIR/fullchain.pem" "$SSL_DIR/fullchain.pem"
    cp "$CERT_DIR/privkey.pem" "$SSL_DIR/privkey.pem"
    cp "$CERT_DIR/chain.pem" "$SSL_DIR/chain.pem"

    # Reload Nginx with real certificates
    docker compose exec nginx nginx -s reload
    echo "Nginx reloaded with Let's Encrypt certificates."
else
    echo "Error: Certificate directory not found: $CERT_DIR" >&2
    exit 2
fi

echo ""
echo "Let's Encrypt setup complete for: ${DOMAIN}"
```

---

## 6. Certbot Auto-Renewal

### In `docker-compose.yml`

The certbot service already has a renewal loop:
```yaml
entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
```

### Post-Renewal Hook

After certbot renews, it needs to:
1. Copy new certs to `nginx/ssl/`
2. Reload Nginx

This can be done via a certbot deploy hook. Add to the entrypoint or use a script:

```yaml
certbot:
  entrypoint: >
    /bin/sh -c 'trap exit TERM;
    while :; do
      certbot renew --deploy-hook "cp /etc/letsencrypt/live/$$DOMAIN_NAME/*.pem /etc/nginx/ssl/ && nginx -s reload" 2>&1;
      sleep 12h & wait $${!};
    done;'
  environment:
    - DOMAIN_NAME=${DOMAIN_NAME}
```

**Note:** The deploy hook only runs when a certificate is actually renewed, not on every check. The Nginx reload ensures the new certificate is picked up without downtime.

**Consideration:** The certbot container needs write access to `nginx/ssl/` and the ability to signal Nginx. This may require:
- Mounting `nginx/ssl/` as read-write in the certbot container
- Using `docker compose exec` from the host (via a cron job) instead of the container's deploy hook

**Simpler approach:** Use a host-level cron job or the switch script to handle cert renewal:
```bash
# In crontab (on the host):
0 */12 * * * cd /path/to/project && docker compose run --rm certbot renew && cp certbot/conf/live/$DOMAIN/*.pem nginx/ssl/ && docker compose exec nginx nginx -s reload
```

This keeps the architecture simple and avoids cross-container signaling.

---

## 7. Updated `.env` Variables

```env
# SSL / Certificates (internet mode only)
DOMAIN_NAME=example.com
CERTBOT_EMAIL=admin@example.com    # Optional: email for Let's Encrypt notifications
```

---

## 8. `.gitignore` Entries for SSL

```gitignore
# SSL certificates (sensitive — never commit)
nginx/ssl/*.pem
certbot/conf/
certbot/www/
```

---

## Cross-References

- **[04-nginx-internet.md](./04-nginx-internet.md)** — Nginx SSL configuration
- **[03-docker-compose.md](./03-docker-compose.md)** — Certbot service definition
- **[99-execution-plan.md](./99-execution-plan.md)** — Implementation tasks
