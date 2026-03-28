#!/bin/bash
set -e

# =============================================================================
# {{PROJECT_NAME}} — PostgreSQL Backup Script
# =============================================================================
# Entrypoint for the pg-backup sidecar container.
# 1. Runs an initial backup on startup
# 2. Sets up a cron job for scheduled backups
# 3. Prunes old backups based on retention policy
#
# Environment variables:
#   PGHOST, PGUSER, PGPASSWORD, PGDATABASE — PostgreSQL connection
#   BACKUP_SCHEDULE       — cron expression (default: 0 2 * * *)
#   BACKUP_RETENTION_DAYS — days to keep backups (default: 30)
# =============================================================================

# ── Install cron (not included in postgres:16 base image) ────
if ! command -v cron &> /dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] Installing cron..."
  apt-get update -qq && apt-get install -y -qq --no-install-recommends cron > /dev/null 2>&1
  rm -rf /var/lib/apt/lists/*
fi

BACKUP_DIR="/backups"
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# ── Create the backup runner script ──────────────────────────
cat > /usr/local/bin/pg-backup-run.sh << 'RUNEOF'
#!/bin/bash
set -e

BACKUP_DIR="/backups"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/{{PROJECT_NAME}}_${TIMESTAMP}.sql.gz"

echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] Starting backup..."

if pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" | gzip > "$BACKUP_FILE"; then
  FILESIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] Backup complete: $BACKUP_FILE ($FILESIZE)"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] ERROR: Backup failed!"
  rm -f "$BACKUP_FILE"
  exit 1
fi

# Prune old backups
PRUNED=$(find "$BACKUP_DIR" -name "{{PROJECT_NAME}}_*.sql.gz" -mtime +"$BACKUP_RETENTION_DAYS" -delete -print | wc -l)
if [ "$PRUNED" -gt 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] Pruned $PRUNED backup(s) older than $BACKUP_RETENTION_DAYS days"
fi
RUNEOF
chmod +x /usr/local/bin/pg-backup-run.sh

# ── Export env vars for cron ─────────────────────────────────
ENV_FILE="/tmp/pg-backup.env"
printenv | grep -E '^(PGHOST|PGUSER|PGPASSWORD|PGDATABASE|BACKUP_DIR|BACKUP_RETENTION_DAYS|TZ)=' > "$ENV_FILE"

# ── Set up cron ──────────────────────────────────────────────
cat > /etc/cron.d/pg-backup << EOF
SHELL=/bin/bash
${BACKUP_SCHEDULE} root . /tmp/pg-backup.env && /usr/local/bin/pg-backup-run.sh >> /proc/1/fd/1 2>> /proc/1/fd/2
EOF
echo "" >> /etc/cron.d/pg-backup
chmod 0644 /etc/cron.d/pg-backup
crontab /etc/cron.d/pg-backup

echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] Backup scheduler started"
echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup]   Schedule: ${BACKUP_SCHEDULE}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup]   Retention: ${BACKUP_RETENTION_DAYS} days"
echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup]   Directory: ${BACKUP_DIR}"

# ── Run initial backup on startup ────────────────────────────
/usr/local/bin/pg-backup-run.sh || \
  echo "$(date '+%Y-%m-%d %H:%M:%S') [pg-backup] WARNING: Initial backup failed (DB may not be ready yet)"

# ── Start cron in foreground ─────────────────────────────────
exec cron -f
