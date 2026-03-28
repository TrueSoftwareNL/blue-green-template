# {{PROJECT_NAME}} — GitHub Secrets Setup

## Required Secrets

Configure these secrets in your GitHub repository settings:
**Settings → Secrets and variables → Actions → New repository secret**

### Infrastructure Secrets

| Secret | Description | Example |
|--------|-------------|---------|
| `DEPLOY_PATH` | Remote deployment path | `/opt/{{PROJECT_NAME}}` |
| `JUMP_HOST` | SSH jump host (optional) | `deploy@jump.example.com` |
| `TEST_SERVER` | Test server SSH address | `deploy@test.example.com` |
| `ACC_SERVER` | Acceptance server SSH address | `deploy@acc.example.com` |
| `PROD_SERVER` | Production server SSH address | `deploy@prod.example.com` |

### SSH Key

| Secret | Description |
|--------|-------------|
| `SSH_PRIVATE_KEY` | SSH private key for server access (if needed by runner) |

### Per-Environment Config Secrets

These are derived from `deploy-config.json`. Each config entry generates secrets
for every environment using the pattern: `{ENV_PREFIX}_{SECRET_KEY}`.

{{CONFIG_SECRETS_TABLE}}

## Setup Steps

### 1. Generate SSH key pair (if needed)

```bash
ssh-keygen -t ed25519 -C "github-actions-{{PROJECT_NAME}}" -f ~/.ssh/github-actions
```

Copy the public key to each server:
```bash
ssh-copy-id -i ~/.ssh/github-actions.pub deploy@your-server.com
```

### 2. Push secrets using push-secrets.sh

```bash
# Set up local config files first
mkdir -p local_data/{test,acceptance,production}
cp deployment/.env.example local_data/test/.env
# Edit each environment's .env with correct values

# Push to GitHub Secrets
./scripts/push-secrets.sh test
./scripts/push-secrets.sh acceptance
./scripts/push-secrets.sh production
# Or push all at once:
./scripts/push-secrets.sh --all
```

### 3. Set infrastructure secrets manually

Go to **Settings → Secrets and variables → Actions** and add:
- `DEPLOY_PATH`
- `TEST_SERVER`, `ACC_SERVER`, `PROD_SERVER`
- `JUMP_HOST` (if using a jump host)

### 4. Verify

Run the **Operations** workflow with `health-check` to verify connectivity.

## Notes

- Secrets are **not visible** after creation — you can only update or delete them
- Use `push-secrets.sh --dry-run` to preview what will be pushed
- The `deploy-config.json` file is committed to the repo (no secrets in it)
- Actual secret values live only in `local_data/` (gitignored) and GitHub Secrets
