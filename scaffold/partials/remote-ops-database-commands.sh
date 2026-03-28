# Trigger an immediate database backup via the pg-backup sidecar.
cmd_backup() {
  dc exec -T pg-backup /usr/local/bin/pg-backup-run.sh
  log_info "Backup completed"
}

# Run database migrations by restarting the app container.
# The app applies pending migrations on startup automatically.
# Arguments:
#   --backup  Trigger a backup before restarting (production safety)
cmd_run_migrations() {
  local current_color
  current_color=$(detect_active_color)

  # Check if --backup flag is passed (production safety)
  if [ "${1:-}" = "--backup" ]; then
    echo "🔒 Triggering backup before migrations..."
    cmd_backup
    echo ""
  fi

  echo "Restarting app containers to trigger migrations on startup..."
  dc --profile "${current_color}" restart

  # Wait for the app to come back healthy (confirms migrations applied)
  wait_for_service "app_${current_color}" 150
}

# Purge the database — drops and recreates from scratch.
# This is a DESTRUCTIVE operation. Production should be blocked at the workflow level.
#
# Steps:
#   1. Stop app containers to prevent writes
#   2. Drop and recreate the database
#   3. Start app (migrations run on startup)
#   4. Wait for health check
cmd_purge_database() {
  local current_color
  current_color=$(detect_active_color)

  echo "⚠️  PURGING database — this destroys all data!"
  echo ""

  log_step "1/4" "Stopping app containers..."
  dc --profile "${current_color}" stop

  log_step "2/4" "Dropping and recreating database..."
  dc exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{{PROJECT_NAME}}' AND pid <> pg_backend_pid();
  " 2>/dev/null || true
  dc exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -c "
    DROP DATABASE IF EXISTS {{PROJECT_NAME}};
    CREATE DATABASE {{PROJECT_NAME}} OWNER ${POSTGRES_USER:-postgres};
  "

  log_step "3/4" "Starting app containers (migrations will apply)..."
  dc --profile "${current_color}" up -d

  log_step "4/4" "Waiting for app health check..."
  wait_for_service "app_${current_color}" 150

  log_info "Database purged and app is healthy"
}

# Show row counts for all user tables in the database.
# Useful for quick data verification after deploys or migrations.
cmd_db_table_counts() {
  dc exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -d "{{PROJECT_NAME}}" -c "
    SELECT schemaname || '.' || tablename AS table_name,
           n_live_tup AS row_count
    FROM pg_stat_user_tables
    ORDER BY schemaname, tablename;
  "
}
