# A.I Agent Instructions for Creating Implementation Plans

## **IMPORTANT**

These rules are **mandatory** and must be applied **strictly and consistently** when creating implementation plans.

---

## **Rules for Implementation Plans**

### **Rule 1: Split Plans into Logical Phases**

When asked to create implementation plans, always split the plan into **logical phases** that can be implemented sequentially.

**What Makes a Good Phase:**

- ✅ Represents a complete, cohesive unit of work
- ✅ Has clear start and end points
- ✅ Can be implemented and tested independently
- ✅ Builds upon previous phases
- ✅ Typically takes 2-5 tasks to complete

**Examples:**

❌ **Bad Phase Breakdown:**

- Phase 1: "Build everything"
- Phase 2: "Test and deploy"

✅ **Good Phase Breakdown (Nginx feature):**

- Phase 1: Create upstream configuration
- Phase 2: Add location block with proxy settings
- Phase 3: Configure rate limiting and security headers
- Phase 4: Runtime validation and endpoint testing

✅ **Good Phase Breakdown (new Docker service):**

- Phase 1: Define service in `docker-compose.yml` with YAML anchor
- Phase 2: Create Dockerfile and health check script
- Phase 3: Add Nginx upstream and location routing
- Phase 4: Integration test (start services, verify health, test endpoints)

✅ **Good Phase Breakdown (deployment script):**

- Phase 1: Create script skeleton with error handling and documentation
- Phase 2: Implement core deployment logic (blue/green switching)
- Phase 3: Add health check verification and rollback logic
- Phase 4: ShellCheck validation and runtime testing

---

### **Rule 2: Define Phase Dependencies**

For each phase, explicitly define dependencies from the previous phase.

**How to Document Dependencies:**

```markdown
## Phase 2: Add Nginx Location Block

**Dependencies:**
- Phase 1 must be complete (upstream definition exists)
- Upstream name from Phase 1 must be documented
- Service must be reachable on Docker network

**What This Phase Provides for Next Phase:**
- Routable endpoint via Nginx
- Rate limiting configured
- Proxy headers set
```

---

### **Rule 3: Provide Context and Reasoning**

Provide detailed context and reasoning for each phase.

**What to Include:**

- **Why this phase is needed** — Business/technical justification
- **What problem it solves** — Specific issues being addressed
- **Key decisions made** — Architecture choices and rationale
- **Potential challenges** — Known risks or complexities
- **Success criteria** — How to verify phase completion

**Example:**

```markdown
## Phase 1: Upstream Configuration for New Service

**Context:**
Adding a new microservice requires Nginx to route traffic to it
while maintaining the blue-green deployment pattern.

**Reasoning:**
Starting with the upstream definition allows us to:
1. Define the connection parameters before creating routes
2. Validate DNS resolution within Docker network
3. Set keepalive and failure thresholds independently

**Key Decision:**
Use the same `resolve` pattern as `bluegreen-upstream.conf` to allow
Nginx to start even if the service container isn't running yet.
```

---

### **Rule 4: Define Clear Deliverables**

Each phase must have **clear, measurable deliverables**.

**Examples:**

❌ **Vague Deliverables:**

- "Backend improvements"
- "Better error handling"
- "Config cleanup"

✅ **Clear Deliverables:**

- Nginx location block `nginx/locations/40-api.conf` with rate limiting
- Docker Compose service definition with health check and profile assignment
- Shell script passing ShellCheck with documented usage
- Health endpoint returning 200 with correct environment identifier

---

### **Rule 5: Create Granular Tasks**

**IMPORTANT:** Create small, **granular**, and manageable tasks. More tasks are better than a few large tasks.

**Task Granularity Guidelines:**

- Each task should be completable within **2-4 hours** of work
- Each task should touch **1-5 files maximum**
- Each task should have **one clear objective**
- Each task should produce **validatable output**

**Examples:**

❌ **Too Large (Bad):**

- "Implement the deployment automation system" (too broad)
- "Add SSL and security headers" (too vague)
- "Build monitoring and logging" (too complex)

✅ **Properly Granular (Good):**

- "Create `nginx/locations/40-api.conf` with rate limiting and proxy pass"
- "Add Redis health check to `docker-compose.yml`"
- "Create deployment switch script `scripts/switch-environment.sh`"
- "Add ShellCheck validation for all scripts in `scripts/` and `app/`"
- "Configure Nginx upstream `nginx/upstreams/api-upstream.conf`"

---

### **Rule 6: Task Numbering Convention**

Tasks **must** have a sequence number in the format: `Task [Phase].[Number]`

**Format:**

```
Task 1.1, Task 1.2, Task 1.3  (Phase 1, tasks 1-3)
Task 2.1, Task 2.2, Task 2.3  (Phase 2, tasks 1-3)
```

**Example:**

```markdown
### Phase 1: Docker Service Definition

- Task 1.1: Add YAML anchor for shared service config
- Task 1.2: Define blue/green service variants with profiles
- Task 1.3: Add health check configuration
- Task 1.4: Validate with `docker compose config`

### Phase 2: Nginx Routing

- Task 2.1: Create upstream definition in `nginx/upstreams/`
- Task 2.2: Create location block in `nginx/locations/`
- Task 2.3: Runtime validation with `nginx -t` and curl testing
```

---

### **Rule 7: Task Presentation Format**

**IMPORTANT:** Place all tasks in a **table format** at the end of each plan with completion checkboxes.

**Required Format:**

```markdown
## Task Implementation Checklist

| Task | Description                          | Dependencies     | Status |
| ---- | ------------------------------------ | ---------------- | ------ |
| 1.1  | Add YAML anchor for shared config    | None             | [ ]    |
| 1.2  | Define blue/green service variants   | 1.1              | [ ]    |
| 1.3  | Add health check configuration       | 1.2              | [ ]    |
| 1.4  | Validate with docker compose config  | 1.1-1.3          | [ ]    |
| 2.1  | Create upstream definition           | Phase 1 complete | [ ]    |
| 2.2  | Create location block                | 2.1              | [ ]    |

**Legend:**
- [ ] Not started
- [x] Complete
```

---

### **Rule 8: Validation Requirements Per Task**

**IMPORTANT:** It is critical to have **validation steps** for each task.

**Validation Guidelines:**

1. **Each task must specify its validation command(s)**

   ```markdown
   Task 1.3: Add health check configuration
   Validate: `clear && docker compose config`
   Runtime: `clear && docker compose ps` (verify "healthy" status)
   ```

2. **Validation types per task:**
   - **Config validation** — `docker compose config`, `nginx -t`, `shellcheck`
   - **Build validation** — `docker compose build`
   - **Runtime validation** — `curl` endpoint testing, `docker compose ps`
   - **Integration validation** — End-to-end flow testing (start → health → endpoint → stop)

3. **Validation granularity:**
   - Each task should have at least one validation command
   - Tasks touching Docker Compose MUST validate with `docker compose config`
   - Tasks touching Nginx MUST validate with `nginx -t` (inside container)
   - Tasks touching shell scripts MUST validate with `shellcheck`

---

### **Rule 9: Pre-Implementation Re-evaluation**

**IMPORTANT:** Always re-evaluate the implementation plan before implementing, to be absolutely sure nothing was missed.

**Re-evaluation Checklist:**

1. **✅ Completeness** — Are all requirements covered?
2. **✅ Task Granularity** — Are tasks small enough (2-4 hours each)?
3. **✅ Dependencies** — Are all dependencies documented and logical?
4. **✅ Validation** — Does every task have validation commands?
5. **✅ Consistency** — Do task numbers follow convention?
6. **✅ Feasibility** — Can this be implemented with current project infrastructure?
7. **✅ File Placement** — Do new files follow existing directory patterns?

---

### **Rule 10: File Creation & Size Limits**

**IMPORTANT:** When planning implementations, always consider AI context limitations.

**File Creation Rules:**

- ✅ Split large configuration files into smaller, logically grouped includes
- ✅ Follow the modular Nginx pattern (`includes/`, `locations/`, `upstreams/`)
- ✅ Each Nginx include file should handle ONE concern
- ✅ Maximum AI output limit: **60K tokens**. Maximum AI input limit: **200K tokens**

**Infrastructure File Sizing:**

```markdown
# Good: Small, focused config files
nginx/includes/proxy_headers.conf      (~10 lines)
nginx/includes/proxy_timeouts.conf     (~5 lines)
nginx/includes/ssl.conf                (~20 lines)
nginx/locations/10-health.conf         (~15 lines)

# Bad: Monolithic config
nginx/nginx.conf                       (500+ lines with everything inline)
```

**When to Split:**

- ✅ Any config file approaching 100+ lines of directives
- ✅ Configurations mixing multiple concerns (SSL + headers + rate limiting)
- ✅ Shell scripts exceeding 200 lines (split into functions or separate scripts)
- ❌ Simple, focused files that handle one thing well — leave as-is

---

## **Summary: Creating Effective Plans**

**Every implementation plan must include:**

1. 📋 **Logical phases** — Sequential, buildable units of work
2. 🔗 **Dependencies** — Clear phase and task dependencies
3. 💡 **Context & reasoning** — Why this approach, key decisions
4. ✅ **Clear deliverables** — Measurable outcomes for each phase
5. 🔨 **Granular tasks** — Small, focused, validatable tasks (2-4 hours each)
6. 🔢 **Numbered tasks** — Format: Task [Phase].[Number]
7. 📊 **Table format** — All tasks in a table with checkboxes
8. 🧪 **Validation requirements** — Docker/Nginx/shell validation per task
9. 🔍 **Pre-implementation review** — Verify completeness and consistency
10. 📦 **File size limits** — Split large files, follow modular patterns

---

## **Adapting to Task Type**

| Task Type | Typical Components |
|-----------|--------------------|
| **New Docker Service** | YAML anchor, service definition, health check, profiles |
| **Nginx Routing** | Upstream definition, location block, proxy settings |
| **Security Feature** | SSL config, security headers, rate limiting |
| **Deployment Script** | Shell script, error handling, health verification |
| **App Endpoint** | Express route, JSON response, Nginx location, health check |
| **Bug Fix** | Root cause analysis, fix, validation, regression check |
| **Configuration** | `.env` variable, Docker Compose, Nginx include |

---

## **Cross-References**

- See **agents.md** for task granularity requirements and verification rules
- See **code.md** for coding/configuration standards and quality guidelines
- See **testing.md** for validation commands and workflow
- See **make_plan.md** for plan creation trigger and execution protocol
- See **git-commands.md** for commit workflow during plan execution
