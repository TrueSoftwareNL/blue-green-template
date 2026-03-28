
  echo ""
  echo "=== PostgreSQL ==="
  dc exec -T postgres pg_isready -U "${POSTGRES_USER:-postgres}" 2>/dev/null || echo "  PostgreSQL health check failed"
