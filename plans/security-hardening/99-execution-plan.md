# Execution Plan: Security Hardening

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-03-28 16:00
> **Progress**: 8/8 tasks (100%)

## Overview

4 Nginx security improvements: strip X-Powered-By, fix CSP for mixed apps, auth rate limit
template, per-location body size limits. Plus documentation updates and verification.

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title                     | Sessions | Est. Time |
|-------|---------------------------|----------|-----------|
| 1     | Nginx Config Changes      | 1        | 20 min    |
| 2     | Documentation Updates     | 1        | 10 min    |
| 3     | Verification & Commit     | 1        | 5 min     |

**Total: 1 session, ~35 min**

---

## Phase 1: Nginx Config Changes

### Session 1.1: All Nginx Hardening Changes

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, handle commit per active commit mode, then `/compact`.
- Commit mode is determined by `exec_plan` flags: `--ask-commit` (default), `--no-commit`, `--auto-commit`.

**Reference**: [Nginx Hardening Spec](03-nginx-hardening.md)
**Objective**: Implement all 4 security changes

**Tasks**:

| #     | Task                                                    | File                                           |
|-------|---------------------------------------------------------|------------------------------------------------|
| 1.1.1 | Add `proxy_hide_header X-Powered-By`                   | `nginx/includes/proxy_headers.conf`            |
| 1.1.2 | Replace CSP with mixed-content policy + eval toggle     | `nginx/includes/security_headers_enhanced.conf` |
| 1.1.3 | Add commented `auth_limit` zone                         | `nginx/nginx.conf`                             |
| 1.1.4 | Create auth rate limit location template                | `nginx/locations/15-auth.conf` (new)           |
| 1.1.5 | Add `client_max_body_size 1m` to default location       | `nginx/locations/99-default.conf`              |

**Deliverables**:
- [ ] X-Powered-By stripped from proxy responses
- [ ] CSP supports mixed HTML+API+WebSocket content
- [ ] Commented eval variant available
- [ ] Auth rate limit zone and location template ready
- [ ] Per-location body size limits set

---

## Phase 2: Documentation Updates

### Session 2.1: Update Docs

**Reference**: `plans/security-hardening-notes.md`, `README.md`
**Objective**: Mark completed items and update Security section

**Tasks**:

| #     | Task                                                    | File                               |
|-------|---------------------------------------------------------|------------------------------------|
| 2.1.1 | Mark completed items in security-hardening-notes.md     | `plans/security-hardening-notes.md` |
| 2.1.2 | Update README.md Security section                       | `README.md`                        |

**Deliverables**:
- [ ] security-hardening-notes.md reflects completed work
- [ ] README Security section accurate for new CSP and features

---

## Phase 3: Verification & Commit

### Session 3.1: Verify and Ship

**Tasks**:

| #     | Task                                                    |
|-------|---------------------------------------------------------|
| 3.1.1 | Run `docker compose config && docker compose build`     |

**Verify**: `clear && sleep 3 && docker compose config && docker compose build`

---

## Task Checklist (All Phases)

### Phase 1: Nginx Config Changes
- [x] 1.1.1 Add `proxy_hide_header X-Powered-By` ✅ (completed: 2026-03-28 16:10)
- [x] 1.1.2 Replace CSP with mixed-content policy + eval toggle ✅ (completed: 2026-03-28 16:10)
- [x] 1.1.3 Add commented `auth_limit` zone to nginx.conf ✅ (completed: 2026-03-28 16:11)
- [x] 1.1.4 Create auth rate limit location template (15-auth.conf) ✅ (completed: 2026-03-28 16:10)
- [x] 1.1.5 Add `client_max_body_size 1m` to default location ✅ (completed: 2026-03-28 16:10)

### Phase 2: Documentation Updates
- [x] 2.1.1 Update security-hardening-notes.md ✅ (completed: 2026-03-28 16:12)
- [x] 2.1.2 Update README.md Security section ✅ (completed: 2026-03-28 16:12)

### Phase 3: Verification & Commit
- [x] 3.1.1 Verify: `docker compose config && docker compose build` ✅ (completed: 2026-03-28 16:12)

---

## Session Protocol

### Starting a Session

1. Start agent settings: `clear && sleep 3 && scripts/agent.sh start`
2. Reference this plan: "Implement per `plans/security-hardening/99-execution-plan.md`"

### Ending a Session

1. Run verify: `clear && sleep 3 && docker compose config && docker compose build`
2. Handle commit per active commit mode
3. End agent settings: `clear && sleep 3 && scripts/agent.sh finished`
4. Compact: `/compact`

---

## Dependencies

```
Phase 1 (Nginx changes)
    ↓
Phase 2 (Documentation)
    ↓
Phase 3 (Verification & Commit)
```

---

## Success Criteria

**Feature is complete when:**

1. ✅ All phases completed
2. ✅ All verification passing (`docker compose config && docker compose build`)
3. ✅ No warnings/errors
4. ✅ Documentation updated
5. ✅ **Post-completion:** Ask user to re-analyze project and update `.clinerules/project.md`
