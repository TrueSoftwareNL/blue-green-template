#!/usr/bin/env node
// =============================================================================
// resolve-servers.js — Deploy Inventory Resolver
// =============================================================================
// Reads deploy-inventory.json and resolves server list for a given environment.
// Outputs JSON for GitHub Actions matrix consumption (no jq dependency).
//
// Usage:
//   node resolve-servers.js --env production [--scope all|group|tag|server] [--filter value]
//
// Output (JSON to stdout):
//   {
//     "servers": [{"name":"prod-01","host":"deploy@10.0.3.10"}, ...],
//     "count": 2,
//     "access_mode": "direct"
//   }
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');

// Parse arguments
const args = process.argv.slice(2);
const flags = {};
for (let i = 0; i < args.length; i += 2) {
  const key = args[i].replace(/^--/, '');
  flags[key] = args[i + 1] || '';
}

const env = flags.env;
const scope = flags.scope || 'all';
const filter = flags.filter || '';

if (!env) {
  console.error('Usage: node resolve-servers.js --env <environment> [--scope all|group|tag|server] [--filter value]');
  process.exit(1);
}

// Find inventory file
function findInventory() {
  let dir = path.resolve(__dirname, '..', '..');
  for (let i = 0; i < 5; i++) {
    const candidate = path.join(dir, 'deploy-inventory.json');
    if (fs.existsSync(candidate)) return candidate;
    dir = path.dirname(dir);
  }
  console.error('Error: deploy-inventory.json not found');
  process.exit(1);
}

// Read inventory
let inventory;
try {
  inventory = JSON.parse(fs.readFileSync(findInventory(), 'utf-8'));
} catch (err) {
  console.error(`Error reading inventory: ${err.message}`);
  process.exit(1);
}

// Look up environment
const envConfig = inventory.environments[env];
if (!envConfig) {
  console.error(`Error: Unknown environment "${env}". Valid: ${Object.keys(inventory.environments).join(', ')}`);
  process.exit(1);
}

// Filter servers
let servers = envConfig.servers || [];

switch (scope) {
  case 'all':
    // No filtering
    break;
  case 'group':
    if (!filter) { console.error('Error: --filter required for scope "group"'); process.exit(1); }
    servers = servers.filter(s => s.group === filter);
    break;
  case 'tag':
    if (!filter) { console.error('Error: --filter required for scope "tag"'); process.exit(1); }
    servers = servers.filter(s => (s.tags || []).includes(filter));
    break;
  case 'server':
    if (!filter) { console.error('Error: --filter required for scope "server"'); process.exit(1); }
    servers = servers.filter(s => s.name === filter);
    break;
  default:
    console.error(`Error: Unknown scope "${scope}". Valid: all, group, tag, server`);
    process.exit(1);
}

if (servers.length === 0) {
  console.error(`Error: No servers matched env="${env}" scope="${scope}" filter="${filter}"`);
  process.exit(1);
}

// Output for GitHub Actions matrix
const result = {
  servers: servers.map(s => ({ name: s.name, host: s.host })),
  count: servers.length,
  access_mode: envConfig.access || 'direct'
};

console.log(JSON.stringify(result));
