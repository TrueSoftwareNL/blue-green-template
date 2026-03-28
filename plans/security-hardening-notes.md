# Security Hardening Notes

> **Created**: 2026-03-28
> **Status**: Future Reference — Not yet a formal plan
> **Context**: Analysis done during `remove-internet-mode` planning session

## Architecture

```
Internet → ProxyBuilder (passthrough: SSL termination only) → HTTP → Blue-Green Nginx (ALL hardening) → App (BlendSDK/WebAFX)
```

### Ecosystem Stack

Every application in this system is a combination of:
1. **BlendSDK/WebAFX** — Express.js wrapper framework with auth, plugins, etc.
2. **Blue-Green Template** — Docker Compose + Nginx blue/green deployment
3. **ProxyBuilder** — Nginx reverse proxy builder with SSL (Let's Encrypt), load balancing, maintenance mode

### ProxyBuilder Passthrough Mode (What It Does)

- ✅ SSL/TLS termination (HTTPS → HTTP)
- ✅ HTTP → HTTPS redirect
- ✅ Proxy headers: `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Forwarded-Port`
- ❌ **No security headers** (no HSTS, no CSP, no X-Frame-Options)
- ❌ No gzip compression
- ❌ No logging per-domain
- ❌ No rate limiting
- ❌ No WAF

**Implication:** The blue-green Nginx MUST own ALL security hardening.

---

## Current Security Assessment (Score: 7/10)

### What's Good ✅

| Layer | What | Status |
|-------|------|--------|
| ProxyBuilder | SSL/TLS termination (TLS 1.2/1.3, strong ciphers, OCSP) | ✅ |
| ProxyBuilder | HTTP → HTTPS redirect | ✅ |
| ProxyBuilder | Forwarded headers (`X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) | ✅ |
| Blue-Green Nginx | Rate limiting (10 req/s per IP via `X-Forwarded-For`) | ✅ |
| Blue-Green Nginx | Connection limiting (10 concurrent per IP) | ✅ |
| Blue-Green Nginx | Security headers: HSTS, CSP, X-Frame-Options, X-Content-Type-Options, XSS Protection, Permissions-Policy, Referrer-Policy | ✅ |
| Blue-Green Nginx | Custom JSON error pages (no server info leaks) | ✅ |
| Blue-Green Nginx | `server_tokens off` (Nginx version hidden) | ✅ |
| Blue-Green Nginx | GDPR-compliant logging (IP anonymization) | ✅ |
| Blue-Green Nginx | Trusted proxy (`set_real_ip_from` for private networks) | ✅ |
| Blue-Green Nginx | CSP: `default-src 'none'` (strict for JSON APIs) | ✅ |

### Concerns ⚠️

| Issue | Severity | Details |
|-------|----------|---------|
| HTTP between ProxyBuilder and Blue-Green Nginx | ⚠️ Medium | Unencrypted HTTP on the wire. Fine if same machine (localhost). If different machines, plaintext traffic. |
| `trusted_proxies.conf` trusts entire private ranges | ⚠️ Medium | Trusts ALL of `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`. Should be tightened to ProxyBuilder's specific IP. Wide trust = any machine on private network can spoof `X-Forwarded-For`. |
| No per-location request body size | ⚠️ Low | `client_max_body_size 10m` is global. JSON API endpoints should have much smaller limits (e.g., `1m` or `100k`). |
| CSP is API-only | ℹ️ Info | CSP `default-src 'none'` is perfect for JSON APIs. Will break any BlendSDK app serving HTML/JS (SSR, admin panels). Needs to be configurable per-application. |
| No `X-Request-ID` end-to-end tracing guarantee | ⚠️ Low | Blue-green Nginx sets `X-Request-ID`, but ProxyBuilder may not pass an existing one through. Request tracing across the full chain may not work end-to-end. |
| HSTS via HTTP | ℹ️ Info | Blue-green Nginx sends HSTS over HTTP. Works because ProxyBuilder passes the header through to the browser (which sees HTTPS). Unconventional but functional. |

### Missing ❌

| Missing | Severity | Recommendation |
|---------|----------|----------------|
| No WAF or request filtering | ❌ Medium | No protection against SQL injection, XSS payloads, path traversal in URLs. Security relies entirely on BlendSDK/WebAFX app layer. |
| No brute force protection | ❌ Medium | Rate limiting is flat 10 req/s for all API endpoints. Auth endpoints (`/login`, `/oauth`) should have much stricter limits (3-5 req/min). |
| No IP blocklist/allowlist | ⚠️ Low | No mechanism to block known bad IPs or restrict access to admin endpoints. |
| No response header sanitization | ⚠️ Low | If the app leaks headers (e.g., `X-Powered-By: Express`), neither ProxyBuilder nor Nginx strips them. |

---

## Security Responsibility Map

### Layer 1: ProxyBuilder (Edge)

| Concern | Status | Notes |
|---------|--------|-------|
| SSL/TLS termination | ✅ Handled | Correct placement |
| HTTP → HTTPS redirect | ✅ Handled | Correct placement |
| Certificate management (Let's Encrypt) | ✅ Handled | ProxyBuilder owns renewal |
| Maintenance mode | ✅ Handled | File-based, CI/CD friendly |
| **IP blocklist/allowlist** | ⬜ Future | Edge is the right place to block IPs |
| **DDoS protection** | ⬜ Future | Or use Cloudflare/CDN |

### Layer 2: Blue-Green Nginx (Infrastructure Security)

| Concern | Status | Notes |
|---------|--------|-------|
| Security headers (full set) | ✅ Handled | Enhanced headers file |
| Rate limiting (general) | ✅ Handled | 10 req/s per IP |
| Connection limiting | ✅ Handled | 10 concurrent per IP |
| Error page sanitization | ✅ Handled | JSON error pages |
| `server_tokens off` | ✅ Handled | |
| Trusted proxy config | ⚠️ Too broad | Needs tightening to ProxyBuilder IP |
| **Per-endpoint rate limits** | ⬜ Future | Auth endpoints need stricter limits |
| **Strip leaked headers** | ⬜ Future | `proxy_hide_header X-Powered-By;` |
| **Request size per-location** | ⬜ Future | Different limits for different endpoints |
| **Flexible CSP per-app** | ⬜ Future | JSON API vs HTML app need different CSPs |

### Layer 3: BlendSDK/WebAFX App (Application Security)

| Concern | Status | Notes |
|---------|--------|-------|
| Authentication (JWT, OAuth) | ✅ Handled | webafx-auth: JwtAuthProvider, MemoryAuthProvider |
| Authorization (scopes, roles) | ✅ Handled | webafx-auth scopes system |
| **Input validation/sanitization** | ⬜ Per-app | App must validate. Nginx can't understand business logic. |
| **CSRF protection** | ⬜ Per-app | App-level tokens |
| **Request body validation** | ⬜ Per-app | JSON schema validation, field-level sanitization |
| **Brute force detection (smart)** | ⬜ Per-app + Nginx | App tracks failed attempts per-user. Nginx rate-limits as safety net. |
| Session management | ⬜ Per-app | Redis-backed sessions |
| `X-Powered-By` removal | ⬜ Per-app OR Nginx | `app.disable('x-powered-by')` or `proxy_hide_header` |

---

## Future Improvement Items (When Creating `plans/security-hardening/`)

### Priority 1 — Quick Wins
1. Tighten `trusted_proxies.conf` to ProxyBuilder's specific IP
2. Add `proxy_hide_header X-Powered-By;` to proxy config
3. Add per-endpoint rate limits for auth endpoints in nginx locations

### Priority 2 — Medium Effort
4. Make CSP configurable (support both JSON API and HTML app modes)
5. Add request body size limits per-location
6. End-to-end `X-Request-ID` tracing (ProxyBuilder → Nginx → App)

### Priority 3 — Larger Effort
7. IP blocklist/allowlist at ProxyBuilder edge
8. WAF rules or integration (ModSecurity, etc.)
9. DDoS protection strategy (Cloudflare, rate limiting tiers)

---

## Additional Context

### PostgreSQL/Redis Deployment Flexibility

Some applications in this ecosystem will have:
- PostgreSQL and Redis **in the same Docker Compose** (local)
- PostgreSQL and Redis **in a different Docker Compose on the same machine**
- PostgreSQL and Redis **on an entirely different server**

This means the blue-green template's `docker-compose.yml` should eventually support making postgres/redis services optional (separate future task).

### BlendSDK/WebAFX Auth Capabilities

The `@blendsdk/webafx-auth` package provides:
- **JwtAuthProvider** — Local JWT verification (HS256/RS256 via `jose`)
- **MemoryAuthProvider** — Testing mock with pre-configured token map
- **Token extraction chain** — Configurable: header → cookie → query → custom
- **Claims mapping** — Pluggable mapper for non-standard JWT claims
- **Silent failure pattern** — Invalid tokens return `undefined`, never throw
- **Future providers** — OAuth2 introspection, OIDC, multi-tenant (planned)
