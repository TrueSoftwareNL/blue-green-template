# Testing Strategy

> **Document**: 12-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Verification Approach

This is an infrastructure project — testing is validation-based, not unit-test-based.

### Template Validation

| Test | Method | Automated? |
|------|--------|-----------|
| docker-compose.yml syntax | `docker compose config` after scaffold | Yes |
| GitHub Actions YAML syntax | `yamllint` or online validator | Manual |
| Shell scripts syntax | `bash -n script.sh` (syntax check) | Yes |
| Shell scripts quality | `shellcheck script.sh` (if available) | Yes |
| Node.js scripts syntax | `node --check script.js` | Yes |

### Scaffold End-to-End Test

1. Run `install.sh` in a temp directory with test flags
2. Verify all expected files were created
3. Run `docker compose config` on generated docker-compose.yml
4. Run `bash -n` on all generated shell scripts
5. Run `node --check` on all generated JS files

### Manual Verification (on test server)

1. Scaffold into a test BlendSDK project
2. Push secrets with `push-secrets.sh`
3. Trigger release workflow
4. Verify blue-green deploy works (zero downtime)
5. Test operations (health-check, rollback, view-logs)
6. Test config update via `deploy-config` operation

### Verification Checklist

- [ ] Scaffold generates all expected files
- [ ] Generated docker-compose validates
- [ ] Generated scripts have correct syntax
- [ ] Generated workflows have valid YAML
- [ ] Single-server deploy works on test server
- [ ] Blue-green switch achieves zero downtime
- [ ] Rollback works correctly
- [ ] Config deployment from secrets works
- [ ] Operations panel functions correctly
