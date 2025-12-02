# Bellavier Group ERP — Developer Handbook (Chapters Overview)

This document provides the **master structure** for all chapters of the Bellavier Group ERP Developer Handbook.  
Each chapter will eventually expand into its own file under `/docs/developer/chapters/`.

The purpose of this file is:
- to serve as the *table of contents* for the handbook,
- to define what every chapter must contain,
- to make onboarding developers fast and consistent,
- to reflect the architecture introduced in Tasks 16–21.

---

# 📚 Handbook Structure (Chapters)

Below is the complete chapter structure.  
Each chapter includes:  
**Purpose → Audience → Required Knowledge → Detailed Sections → Expected Outputs**

---

## **Chapter 1 — System Overview & Philosophy**
**File:** [`chapters/01-system-overview.md`](chapters/01-system-overview.md)  
**Purpose:** Introduce developers to the high-level architecture, principles, and goals.  
**Audience:** New developers, AI agents, external consultants.  
**Contains:**
- Bellavier Group ERP purpose & mission
- System pillars (Traceability, Multi-Tenant, Security-first, AI-assisted)
- Overview of system modules
- ERP workflows (MO → WIP → QC → Rework → Completion)
- High-level data flow (Request → Bootstrap → API → Helper → DB → Output)
- API categories (Tenant APIs, Platform APIs, PWA APIs, Internal Tools)
- Codebase layout map
- “How to think inside this system” (Hermès-level reliability model)

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 2 — Architecture Deep Dive**
**File:** [`chapters/02-architecture-deep-dive.md`](chapters/02-architecture-deep-dive.md)  
**Purpose:** The technical blueprint.  
**Contains:**
- Multi-tenant architecture design
- Tenant vs Platform separation
- Lifecycle of a request
- Bootstrap layers:
  - TenantApiBootstrap
  - CoreApiBootstrap
- Security layers and flow
- DB topology (bgerp, tenantDB)
- ORM/DB Helper patterns
- Traceability engine (token system)
- WIP token system overview (from Task 11–12)

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 3 — Bootstrap System**
**File:** [`chapters/03-bootstrap-system.md`](chapters/03-bootstrap-system.md)  
**Purpose:** Explain the foundational bootstrap layers.  
**Contains:**
- Role of bootstrap in the ecosystem
- How TenantApiBootstrap works
- How CoreApiBootstrap works
- Required ENV/session/middleware assumptions
- Rate limiting
- AI-trace debug injection
- Error handler structure
- When to choose which bootstrap
- Example code flows

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 4 — Permission Architecture**
**File:** [`chapters/04-permission-architecture.md`](chapters/04-permission-architecture.md)  
**Purpose:** Explain how permission + RBAC works.  
**Contains:**
- Permission model
- `PermissionHelper` API (from Task 19)
- Tenant role mapping
- Platform role mapping
- APIs requiring permissions
- How to add new permissions safely
- Forbidden practices
- Permission testing guide

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 5 — Database Architecture**
**File:** [`chapters/05-database-architecture.md`](chapters/05-database-architecture.md)  
**Contains:**
- Global DB (`bgerp`)
- Per-tenant DB
- Table naming conventions
- Migration strategy
- BootstrapMigrations (Task 19)
- Adding new tables safely
- Tenant onboarding → DB creation guide

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 6 — API Development Guide**
**File:** [`chapters/06-api-development-guide.md`](chapters/06-api-development-guide.md)  
**Purpose:** Teach developers how to build safe APIs.  
**Contains:**
- Standard structure for every API file
- When/How to use:
  - TenantApiBootstrap
  - CoreApiBootstrap
  - TenantApiOutput
- Required format for JSON success
- Required format for JSON errors
- Examples of good vs bad API design
- Security rules (CSRF, rate-limit)
- Adding new API endpoints (step-by-step)

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 7 — Global Helpers**
**File:** [`chapters/07-global-helpers.md`](chapters/07-global-helpers.md)  
**Purpose:** Describe all global subsystem helpers.  
**Contains:**
- PermissionHelper
- BootstrapMigrations
- TenantApiOutput
- DatabaseHelper
- Logging system (LogHelper)
- RateLimiter
- Utility helpers
- Example use cases
- Forbidden changes for helpers

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 8 — Traceability / Token System**
**File:** [`chapters/08-traceability-token-system.md`](chapters/08-traceability-token-system.md)  
**Contains:**
- Full lifecycle of a token
- DAG routing design
- How QC, Rework, MO link
- API touchpoints (trace_api, dag_token_api)
- Token security model
- How to extend WIP logic safely

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 9 — PWA Scan System**
**File:** [`chapters/09-pwa-scan-system.md`](chapters/09-pwa-scan-system.md)  
**Contains:**
- Overview of pwa_scan_api.php
- Architecture issues (duplicate db_fetch_all, legacy structure)
- Migration plan (future task)
- Recommended refactor plan
- Barcode scanning logic
- Device workflow (Scan → Resolve → Action)

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 10 — Testing Framework**
**File:** [`chapters/10-testing-framework.md`](chapters/10-testing-framework.md)  
**Purpose:** Explain all test types added in Tasks 16–17.  
**Contains:**
- Bootstrap tests
- SystemWide tests
- Security audits
- Smoke tests
- Endpoint permission matrix tests
- Writing new tests
- How AI should write tests
- How to run selective tests

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 11 — Security Handbook**
**File:** [`chapters/11-security-handbook.md`](chapters/11-security-handbook.md)  
**Purpose:** Centralize security policy.  
**Contains:**
- Security posture summary (Task 18)
- Sensitive data rules
- Directory permission rules
- Salts + cryptographic rules
- CSRF/RateLimit rules
- Logging rules
- Common vulnerabilities & examples

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 12 — Performance Guide**
**File:** [`chapters/12-performance-guide.md`](chapters/12-performance-guide.md)  
**Purpose:** Explain optimization logic.  
**Contains:**
- Query optimization strategy
- Results from Task 21
- Query anti-patterns to avoid
- Caching strategy (future)
- Heavy endpoint profiling
- Scaling roadmap

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 13 — Refactor & Contribution Guide**
**File:** [`chapters/13-refactor-contribution-guide.md`](chapters/13-refactor-contribution-guide.md)  
**Purpose:** Define how developers modify the codebase.  
**Contains:**
- Stable-core rules
- Refactor zones (Safe vs Dangerous)
- AI-assisted development workflow
- Adding a new module
- Adding new tests
- Review workflow
- Commit style
- Breaking change policy

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 14 — PWA/Frontend Integration**
**File:** [`chapters/14-pwa-frontend-integration.md`](chapters/14-pwa-frontend-integration.md)  
**Contains:**
- How backend links to the PWA
- QR scanning workflows
- Mobile UX constraints
- API → PWA response conventions

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Chapter 15 — AI Developer Guidelines**
**File:** [`chapters/15-ai-developer-guidelines.md`](chapters/15-ai-developer-guidelines.md)  
**Purpose:** Teach AI how to modify code safely.  
**Contains:**
- Golden Rules for AI
- Safety rails
- Dangerous zones
- Good vs Bad patches
- Handling bootstrap/security files
- Handling permission-sensitive code

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

## **Future Chapters (Reserved)**
- Chapter 16 — Async Jobs System

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

- Chapter 17 — Redis cache layer

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

- Chapter 18 — Observability / Monitoring

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

- Chapter 19 — ERP Extensions

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

- Chapter 20 — Export/Import subsystem

### Section Outline
- **Overview**
- **Key Concepts**
- **Core Components**
- **Developer Responsibilities**
- **Common Pitfalls**
- **Examples**
- **Reference Documents**
- **Future Expansion**

---

# 🎯 Final Notes

This is the **master plan** for the ERP developer handbook.  
**Status:** ✅ All 15 chapters completed and available (November 19, 2025).

Developers (and AI agents) can now follow:
- One handbook,
- One architecture,
- One workflow,
- One policy set.

This is the foundation of a scalable engineering culture.

---

## 📚 Quick Navigation

- **Start Here:** [`README.md`](README.md) - Entry point for all developers
- **All Chapters:** [`chapters/`](chapters/) - Complete handbook (15 chapters)
- **Master Structure:** This file (`chapter.md`) - Overview and links to all chapters

---

## 🤖 AI Agent Operating Rules (Bellavier Group ERP)

These rules apply to **all AI Agents** (Cursor, ChatGPT, Copilot, etc.) that modify this repository.  
They are designed to keep the system **stable, secure, and backward compatible**.

---

### 1. Primary Mission

AI Agents must always prioritize:

1. **Stability over cleverness**
2. **Security over convenience**
3. **Backward compatibility over refactor “beauty”**

If a change could break a working flow → **do not apply it** without explicit human approval.

---

### 2. Core Principles

1. **Stability First**
   - Do not break working behavior.
   - Do not introduce new side effects.
   - Do not change business rules unless explicitly requested.

2. **Backward Compatibility**
   - Existing APIs must keep the same input/output contract unless a task explicitly allows a breaking change.
   - If a new behavior is needed, prefer:
     - New functions,
     - New flags/options,
     - Or new versioned endpoints.

3. **Minimal & Targeted Changes**
   - Edit the **smallest possible surface**.
   - Do not rewrite entire files when you only need to touch a few lines.
   - Avoid “cleanup refactors” that are not requested in the task.

4. **Security Above All**
   - Never weaken authentication, authorization, or cryptographic operations.
   - Any change touching security/permission/crypto must include:
     - A short explanation,
     - A clear risk/impact note,
     - And, if possible, a test.

---

### 3. Forbidden Zones (Do Not Touch Without Explicit Human Approval)

The following areas are **protected**. An AI Agent must not modify them unless the user explicitly asks for it in the current task.

#### 3.1 Bootstrap Core

- `TenantApiBootstrap` (and any file under `source/BGERP/Bootstrap/` related to tenant bootstrap)
- `CoreApiBootstrap`
- `CoreCliBootstrap`
- Any future bootstrap classes

These define the **entry contract** and are extremely sensitive.

#### 3.2 Security & Permission Core

- `BGERP\Security\PermissionHelper`
- Any `permission.php` thin wrapper
- `LogHelper` (except to add safe, non-sensitive logs)
- `RateLimiter` and related rate limit logic
- `platform_serial_salt_api.php` and related salt/crypto logic

#### 3.3 Migration Core

- `BGERP\Migration\BootstrapMigrations`
- `bootstrap_migrations.php` wrapper
- `run_tenant_migrations.php`

Migration behavior must remain stable across all tenants and environments.

#### 3.4 Legacy PWA Scan System (Until Official Refactor Task)

- `pwa_scan_api.php` and related legacy helpers

This file is known to be complex and fragile. Only touch it when there is a **dedicated PWA Scan refactor task**.

#### 3.5 System-Wide Tests (Behavior Contracts)

- Files under `tests/Integration/SystemWide/*`

These tests define **system contracts**. AI Agents should:
- Add new tests if needed,
- But avoid modifying existing assertions unless the task is specifically about updating contracts.

---

### 4. Allowed but Restricted Zones

Some areas can be modified, but with **strict constraints**.

#### 4.1 Tenant APIs (e.g., `products.php`, `materials.php`, `bom.php`, `qc_rework.php`)

Allowed:
- Use `TenantApiOutput` to standardize JSON format.
- Improve error handling and validation.
- Add logging (via `LogHelper`) without exposing sensitive data.

Forbidden:
- Changing the meaning of existing actions (`action=list` must still “list” in the same way).
- Changing DB queries in ways that filter out or include additional records unless clearly requested.
- Renaming or removing existing actions without migration steps.

#### 4.2 Platform APIs (e.g., `platform_*_api.php`)

Allowed:
- Migrate to `CoreApiBootstrap` when needed (if not already).
- Normalize JSON output and error formats.
- Add additional safety checks (permissions, CSRF, rate limits).

Forbidden:
- Weakening permission checks.
- Changing role/permission mappings without explicit approval.
- Exposing internal IDs or sensitive configuration data.

---

### 5. Required Workflow for Any AI Task

For every task (Task 16–100 and beyond), AI Agents must follow this flow:

1. **Read the relevant docs first**
   - `docs/developer/README.md`
   - `docs/developer/01-policy/DEVELOPER_POLICY.md`
   - `docs/developer/02-quick-start/QUICK_START.md`
   - `docs/developer/02-quick-start/GLOBAL_HELPERS.md`
   - Task-specific doc under `docs/bootstrap/Task/` or `docs/performance/`, etc.

2. **Identify the Scope Clearly**
   - Which file(s) are allowed to change?
   - Which behavior must remain the same?
   - Which task number (e.g., Task 20, Task 21) is being executed?

3. **Plan Before Editing**
   - Write a short reasoning: what will be changed and why.
   - Ensure the plan respects forbidden zones and safety rules.

4. **Apply Minimal Patch**
   - Change the smallest possible area.
   - Keep old behavior intact unless clearly instructed.

5. **Run Basic Checks (if applicable)**
   - `php -l` on modified files.
   - `composer dump-autoload` if new classes were added.
   - Appropriate `phpunit` command for related tests.

6. **Document the Change**
   - Update the corresponding `docs/bootstrap/Task/taskXX.md` or related doc.
   - Summarize:
     - Files changed,
     - Behavior changes (if any),
     - Tests run.

7. **Leave TODO/NOTE When Unsure**
   - If environment prevents full testing (e.g., missing DB table), leave:
     - `// TODO(ai): Needs manual verification in real environment.`
   - Never “fake” a passing state.

---

### 6. What AI Must Never Do

- Rewrite large files just for style.
- Remove legacy code paths without confirming that they are unused.
- Change configuration for production (DB, domain, credentials).
- Log sensitive data (passwords, tokens, salts, personal data).
- Silence errors by blindly catching exceptions and ignoring them.

---

### 7. AI + Human Collaboration

- AI is a **co-pilot**, not the owner.
- For decisions involving:
  - Security,
  - Permission changes,
  - Data model changes,
  - Public API contracts,
  
  → AI must **propose** options and **wait for explicit human approval** before applying large or irreversible changes.

---

By following these rules, AI Agents will:
- Keep Bellavier Group ERP stable,
- Respect all safety rails designed in Tasks 16–21,
- And help build a **Hermès-grade** engineering culture instead of a fragile, auto-generated codebase.
