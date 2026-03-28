# Scaffold Generator

> **Document**: 10-scaffold-generator.md
> **Parent**: [Index](00-index.md)

## Overview

`scaffold/scaffold.js` — Node.js interactive generator using only built-in modules (`readline`, `fs`, `path`). Zero external dependencies.

## Interactive Flow

1. **Project basics**: name, app port, nginx port, entry point
2. **Infrastructure**: PostgreSQL? Redis?
3. **Deployment topology**: environments, servers per env, access method
4. **Config files**: auto-generates `deploy-config.json` with standard entries (.env + app-config)
5. **Generate files**: render templates with user answers, apply conditionals

## Non-Interactive Mode

All answers via flags: `--name X --port N --entry "cmd" --with-postgres --no-redis --env test:direct:1 --env prod:deploy_server:200`

## Template Rendering

```javascript
function render(template, vars) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => vars[key] ?? `{{${key}}}`);
}
```

## Conditional Sections

For docker-compose, the generator assembles the file from:
- Base template (always) + postgres partial (if yes) + redis partial (if yes) + pg-backup partial (if postgres) + dozzle (always)

## Conflict Detection

If target files exist: ask overwrite/skip/backup. In non-interactive mode: skip existing (use `--force` to overwrite).

## Architecture

```
scaffold.js
├── prompts.js module (readline-based interactive prompts)
├── renderer.js module (template rendering + conditional assembly)
├── writer.js module (file writing with conflict detection)
└── main flow (orchestrates prompts → render → write → summary)
```

All in a single `scaffold.js` file (estimated ~300-400 lines) to avoid needing `require()` across multiple files during curl install.
