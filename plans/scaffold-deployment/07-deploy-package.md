# Deploy Package

> **Document**: 07-deploy-package.md
> **Parent**: [Index](00-index.md)

## Overview

`deploy-package.sh` — generalized tarball builder for BlendSDK monorepo applications. Based on LogixControl's `deploy-package.sh`, with TODO/uncomment customization sections.

## Usage

```bash
./deploy-package.sh                          # Build locally only
./deploy-package.sh user@server              # Build + deploy
./deploy-package.sh user@server user@jump    # Deploy via jump host
```

## Template Structure

1. **Configuration section** with TODO comments for customization:
   - `APP_NAME="{{PROJECT_NAME}}"` — set by scaffold
   - `# COPY_DATABASE_RESOURCES=true` — uncomment if needed
   - `# COPY_EXTRA_RESOURCES()` — custom function stub

2. **Pack packages** — loops through `./packages/` and runs `yarn pack`
3. **Create deployment package.json** with resolutions for local .tgz files
4. **Copy optional resources** — database schema, static files (commented out by default)
5. **Install dependencies** — `cd deployment && yarn add file:packages/*.tgz`
6. **Create versioned tarball** — `deployment-X.Y.Z.tgz`
7. **Optional remote deploy** — SCP + symlink `deployment-latest.tgz`

## Key Patterns from LogixControl

- Version extracted from root `package.json`
- Resolutions block for monorepo package resolution
- SSH options with jump host support via ProxyCommand
- Symlink `deployment-latest.tgz` → versioned file
