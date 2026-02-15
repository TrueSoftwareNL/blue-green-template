# Implementation Plan Creation & Execution

## **TRIGGER KEYWORD: `make_plan`**

When the user types "make_plan", execute this comprehensive workflow to create a detailed, multi-document implementation plan.

## **TRIGGER KEYWORD: `exec_plan [feature-name]`**

When the user types "exec_plan [feature-name]", execute the implementation plan at `plans/[feature-name]/99-execution-plan.md`.

---

## **Part 1: Creating Plans (`make_plan`)**

### **Phase 1: Information Gathering (MANDATORY)**

**Before creating ANY plan documents, you MUST:**

#### 1.1 Ask Clarifying Questions

1. **Feature Scope** — What should it do? What should it NOT do?
2. **Technical Context** — Which services/configs are affected? Existing implementations?
3. **Dependencies** — Does this depend on other features or services?
4. **Success Criteria** — How do we know when it's done?

#### 1.2 Analyze Current Implementation

1. ✅ Read relevant source files (Docker Compose, Nginx configs, shell scripts, app code)
2. ✅ Identify affected services and configuration files
3. ✅ Check for similar patterns in the codebase
4. ✅ Note any technical debt or existing issues
5. ✅ Review service dependencies and Docker network topology

#### 1.3 Confirm Scope with User

```markdown
## Scope Confirmation

**Feature:** [Name]

**What's IN scope:**
- Item 1
- Item 2

**What's OUT of scope:**
- Item 1

**Key Decisions Needed:**
- Decision 1: [Options A, B, C]

Please confirm or adjust before I create the plan.
```

---

### **Phase 2: Create Plan Documents**

#### Folder Structure

```
plans/
└── [feature-name]/
    ├── 00-index.md           # Overview and navigation
    ├── 01-requirements.md    # Requirements and scope
    ├── 02-current-state.md   # Current implementation analysis
    ├── 03-[component-1].md   # Technical spec for component 1
    ├── 04-[component-2].md   # Technical spec for component 2
    ├── 07-testing-strategy.md # Test cases and verification
    └── 99-execution-plan.md  # Phases, sessions, task checklist
```

#### Document Templates

*(Use templates from `plans.md` rules for content structure)*

---

### **Phase 3: Quality Checklist**

Before finalizing plan documents:

- [ ] All requirements captured
- [ ] All affected services/configs identified
- [ ] Tasks are 2-4 hours max each
- [ ] Each task has clear deliverables and is independently testable
- [ ] Phase and task dependencies documented (no circular deps)
- [ ] Validation requirements defined for every component
- [ ] Tables properly formatted with task numbering (Phase.Session.Task)

---

## **Part 2: Executing Plans (`exec_plan [feature-name]`)**

### **Execution Protocol**

#### Step 1: Load the Plan

1. ✅ Read: `plans/[feature-name]/99-execution-plan.md`
2. ✅ Find incomplete tasks (unchecked `[ ]` items)
3. ✅ Read supporting technical specs in `plans/[feature-name]/`
4. ✅ Determine starting point: first incomplete phase/session/task

If the execution plan doesn't exist → STOP, suggest running `make_plan` first.

#### Step 2: Execute Tasks

For each task in order:
1. Implement the task following technical specifications
2. Run verification (Docker config, build, shellcheck, etc.)
3. Update `99-execution-plan.md` — mark task complete with `[x]`
4. Continue until all tasks complete OR context window reaches 90%

#### Step 3: Session Wrap-Up

1. ✅ Complete current task before stopping
2. ✅ Update execution plan with all completed tasks
3. ✅ Run: `clear && docker compose config && docker compose build`
4. ✅ Auto-commit if validation passes (use `gitcmp` protocol)
5. ✅ Report session summary

---

## **🚨 CRITICAL: Session Execution Rules (AUTO-INCLUDED IN EVERY PHASE) 🚨**

**These rules are AUTOMATICALLY APPLIED to every execution session. They do NOT need to be manually injected.**

### **Context Window Management**

- ✅ **Continue implementing** — do NOT wrap the session until you reach **90% of the 200K context window**
- ✅ If you reach 90%, wrap up the session then `/compact`
- ✅ Use the `gitcmp` protocol to stage all changes and create a git commit before continuing in a new session
- ❌ Do NOT stop early at 50-70% — maximize each session's output

### **File Creation Rules**

- ✅ Split files into smaller, logically grouped files to prevent AI context limits
- ✅ Follow the existing modular pattern (Nginx includes, locations, upstreams)
- ✅ Maximum AI output limit: **60K tokens**. Maximum AI input limit: **200K tokens**
- ✅ Plan file sizes accordingly — no single file should require >30K tokens to write

### **Context Threshold Protocol**

| Context Usage | Action |
|--------------|--------|
| 0-70% | Continue implementing tasks normally |
| 70-80% | Continue, but assess if current task can be completed |
| 80-90% | Complete current task, then wrap up |
| 90%+ | STOP — wrap session, commit, `/compact` |

---

## **🚨 CRITICAL: Real-Time Progress Updates 🚨**

**You MUST update `99-execution-plan.md` after completing EACH task. This is NON-NEGOTIABLE.**

### Update Protocol

1. ✅ Update IMMEDIATELY after each task completion
2. ✅ Use `replace_in_file` to change `[ ]` to `[x]` with timestamp
3. ✅ Update "Last Updated" and "Progress" in document header

### Task Completion Format

```markdown
- [x] 1.1.1 Task description ✅ (completed: 2026-02-08 10:45)
```

---

## **🚨 CRITICAL: Auto-Commit on Successful Task Completion 🚨**

### When to Auto-Commit

Auto-commit is **MANDATORY** when ALL of these conditions are met:

1. ✅ Task or session is successfully complete
2. ✅ All validation passes (`clear && docker compose config && docker compose build`)
3. ✅ Execution plan has been updated

### Commit Protocol

```bash
# 1. Verify validation passes
clear && docker compose config && docker compose build

# 2. Stage and commit
clear && git add .
git commit -m "feat([scope]): [task description]

- [Specific change 1]
- [Specific change 2]
- Validation: docker compose config ✓, docker compose build ✓

Ref: plans/[feature-name]/99-execution-plan.md
Task: [X.X.X]"
```

### When NOT to Auto-Commit

- ❌ Validation is failing (`docker compose config` errors)
- ❌ Build errors exist (`docker compose build` fails)
- ❌ Task is only partially complete

---

## **Execution Plan Template (`99-execution-plan.md`)**

Every generated execution plan MUST include the session execution rules in each phase:

````markdown
# Execution Plan: [Feature Name]

> **Document**: 99-execution-plan.md
> **Last Updated**: [YYYY-MM-DD HH:MM]
> **Progress**: 0/X tasks (0%)

## Overview

[Brief description of the feature implementation]

**🚨 Update this document after EACH completed task!**

---

## Phase 1: [Phase Name]

### Session 1.1: [Session Objective]

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

**Reference**: [Link to technical doc]
**Objective**: [What this session achieves]

**Tasks**:

| # | Task | File |
|---|------|------|
| 1.1.1 | [Task description] | `nginx/locations/[file].conf` |
| 1.1.2 | [Task description] | `docker-compose.yml` |

**Deliverables**:
- [ ] Deliverable 1
- [ ] Deliverable 2
- [ ] Validation passing

**Verify**: `clear && docker compose config && docker compose build`

---

## Phase 2: [Phase Name]

### Session 2.1: [Session Objective]

**⚠️ Session Execution Rules:**
- Continue implementing until 90% of the 200K context window is reached.
- If 90% reached: wrap up, `/compact`, then `gitcmp` to commit.
- Split large files into smaller, logically grouped files.
- Max AI output: 60K tokens. Max AI input: 200K tokens.

...

---

## Task Checklist (All Phases)

### Phase 1: [Phase Name]
- [ ] 1.1.1 [Task]
- [ ] 1.1.2 [Task]

### Phase 2: [Phase Name]
- [ ] 2.1.1 [Task]
- [ ] 2.1.2 [Task]

---

## Success Criteria

1. ✅ All phases completed
2. ✅ `docker compose config` passes
3. ✅ `docker compose build` succeeds
4. ✅ Runtime health checks pass (if applicable)
5. ✅ Documentation updated
````

---

## **Session Summary Template**

At the end of each execution session, provide:

```markdown
## Session Complete

**Feature:** [feature-name]
**Execution Plan:** `plans/[feature-name]/99-execution-plan.md`

**Completed This Session:**
- [x] Phase X, Task X.X.X: [description]
- [x] Phase X, Task X.X.X: [description]

**Remaining Work:**
- [ ] Phase X, Task X.X.X: [description]

**Validation:** docker compose config ✓ / docker compose build ✓
**Commit:** [hash] or "Committed successfully"
**Context Used:** ~XX%

**To Continue:**
Run `exec_plan [feature-name]` in a new session after `/compact`
```

---

## **Adapting to Task Type**

| Task Type | Typical Components |
|-----------|--------------------|
| **New Docker Service** | YAML anchor, service definition, health check, profiles |
| **Nginx Routing** | Upstream, location block, proxy settings, rate limiting |
| **Security Feature** | SSL config, security headers, rate limiting zones |
| **Deployment Script** | Shell script, error handling, health verification |
| **App Endpoint** | Express route, JSON response, Nginx location |
| **Bug Fix** | Root cause analysis, fix, validation, regression check |
| **Configuration** | `.env` variable, Docker Compose, Nginx include |

---

## **Integration with Other Rules**

When executing plans:
- ✅ Follow **code.md** for coding standards (Docker, Nginx, Shell, JavaScript)
- ✅ Follow **testing.md** for validation commands and workflows
- ✅ Follow **git-commands.md** for `gitcm`/`gitcmp` protocol
- ✅ Follow **plans.md** for task granularity and format
- ✅ Follow **agents.md** for general AI agent rules

---

## **Summary**

| Trigger | Action |
|---------|--------|
| `make_plan` | Create implementation plan in `plans/[feature]/` |
| `exec_plan [feature]` | Execute `plans/[feature]/99-execution-plan.md` |
| `/compact` | Compact context after session ends |
| `gitcmp` | Commit and push after successful validation |

**Session Flow:**
```
exec_plan [feature] → implement tasks → update plan → validate → commit → /compact → exec_plan [feature]
```
