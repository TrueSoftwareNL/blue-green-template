# Requirements: Security Hardening

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)

## Feature Overview

Harden the blue-green Nginx layer with 4 targeted security improvements. These address
gaps identified in `plans/security-hardening-notes.md` (the assessment rated the current
setup 7/10).

All apps in this ecosystem serve **mixed content** — HTML/JS/CSS/images/documents AND
REST/WebSocket from the same Docker container. This drives the CSP design.

## Functional Requirements

### Must Have

- [x] Strip leaked framework headers (`X-Powered-By: Express`)
- [x] CSP that supports mixed HTML+API+WebSocket content (not API-only)
- [x] Comment-based toggle for `'unsafe-eval'` in CSP
- [x] Auth endpoint rate limit template (commented, customizable per-deployment)
- [x] Per-location request body size limits

### Won't Have (Out of Scope)

- WAF / ModSecurity (belongs to ProxyBuilder or dedicated container)
- IP blocklist/allowlist (belongs to ProxyBuilder edge)
- DDoS protection (belongs to Cloudflare/CDN)
- Application-level input validation (belongs to BlendSDK/WebAFX)
- CSRF protection (belongs to app layer)
- Smart brute force detection (belongs to app layer)
- Trusted proxy tightening (Docker is private network — broad ranges are fine)
- End-to-end X-Request-ID (current `$request_id` is sufficient)

## Scope Decisions

| Decision                     | Options Considered                    | Chosen     | Rationale                                                |
|------------------------------|---------------------------------------|------------|----------------------------------------------------------|
| CSP configurability          | A: envsubst, B: volume swap, C: comments | C: comments | Simplest, no moving parts, template is meant to be customized |
| `'unsafe-eval'`              | Always on, always off, toggleable     | Toggleable | Some apps need eval (dynamic templates), most don't      |
| Auth rate limit paths        | Hardcoded paths, configurable, template | Template   | Different apps have different auth paths                 |
| Auth rate limit severity     | 1r/m, 3r/m, 5r/m                     | 5r/m       | Strict enough to slow brute force, lenient enough for legitimate use |
| Default body size for API    | 100k, 500k, 1m                        | 1m         | Reasonable for JSON payloads, stricter than global 10m   |
| Auth body size               | 50k, 100k, 200k                      | 100k       | Login payloads are small (username + password)           |

## Acceptance Criteria

1. [ ] `proxy_hide_header X-Powered-By` present in proxy config
2. [ ] CSP supports `'self'` for scripts, styles, images, fonts, connections (including ws/wss)
3. [ ] Commented `'unsafe-eval'` variant exists with clear instructions
4. [ ] Auth rate limit zone exists (commented) in nginx.conf
5. [ ] Auth location file exists (commented) with example paths
6. [ ] Default location has explicit `client_max_body_size 1m`
7. [ ] `docker compose config` passes
8. [ ] `docker compose build` succeeds
9. [ ] README Security section updated
10. [ ] security-hardening-notes.md updated with completion status
