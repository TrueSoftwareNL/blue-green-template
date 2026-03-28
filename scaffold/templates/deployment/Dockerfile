# =============================================================================
# {{PROJECT_NAME}} — Production Application Container
# =============================================================================
# Builds from the deployment-latest.tgz tarball produced by deploy-package.sh.
# The tarball contains pre-built application code and package manifests.
#
# Build context expects:
#   - deployment-latest.tgz (copied by GitHub Actions or deploy-package.sh)
# =============================================================================

FROM node:22-slim

# Install procps for debugging (ps, top)
RUN apt-get update && \
    apt-get install -y --no-install-recommends procps && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and extract the deployment package
COPY deployment-latest.tgz /tmp/deployment-latest.tgz
RUN tar -xzf /tmp/deployment-latest.tgz -C /app && \
    rm /tmp/deployment-latest.tgz && \
    yarn install --production --no-lockfile

# Create directories for runtime data
RUN mkdir -p /app/data /app/temp

# Expose the application port
EXPOSE {{APP_PORT}}

# Health check via app's HTTP health endpoint
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=15s \
  CMD node -e "fetch('http://localhost:{{APP_PORT}}/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Application entrypoint — runs as PID 1
# All stdout/stderr goes to Docker's log driver
ENTRYPOINT [{{ENTRYPOINT_ARRAY}}]
