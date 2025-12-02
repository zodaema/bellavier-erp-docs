# Bellavier Group ERP - Developer Documentation

**Purpose:** Entry point for developers working on the Bellavier Group ERP codebase  
**Last Updated:** January 2025  
**Status:** Active Development

**Documentation Status:** See [DOCUMENTATION_STATUS.md](DOCUMENTATION_STATUS.md) for up-to-date vs. outdated docs

---

## Overview

**Bellavier Group ERP** is a custom multi-tenant manufacturing ERP system designed for luxury (Atelier) and mass (OEM) production workflows.

### Key Architecture Components

- **Multi-tenant System**: Core DB (`bgerp`) + Tenant DBs (`bgerp_t_{org_code}`)
- **Bootstrap Layers**: 
  - `TenantApiBootstrap` - For tenant-scoped APIs (65+ APIs migrated)
  - `CoreApiBootstrap` - For platform/core APIs (12 APIs migrated)
- **PSR-4 Architecture**: 118 files under `BGERP\` namespace
  - Services (47), Helpers (17), DAG Engines (26), MO Services (6), Component Services (4), Product Services (1)
- **DAG Engine**: Complete SuperDAG system with self-healing, time engine, MO intelligence
- **Integration Testing**: System-wide test suite (Tasks 16-17) with 30+ tests
- **Security Hardening**: Rate limiting, CSRF protection, secure logging (Task 18)
- **Enterprise Features**: Rate limiting, Request validation, Idempotency, ETag/If-Match, Maintenance mode

### Current System State

- **Production Readiness**: 100% (all APIs enterprise-compliant)
- **Test Coverage**: 104+ tests (100% passing)
- **Bootstrap Migration**: ✅ 77+ APIs migrated (65 tenant + 12 platform)
- **Legacy Files**: ⚠️ 50+ files still need migration
- **System-Wide Tests**: Complete (Tasks 16-17)
- **Security Audit**: Complete (Task 18)
- **PSR-4 Structure**: ✅ Complete (118 files in BGERP namespace)
- **Database Tables**: 135 tables (13 core + 122 tenant)
- **Services/Engines**: 84 total (47 services + 26 DAG engines + 6 MO + 4 Component + 1 Product)

---

## Repository Map (Essential for Developers)

### Core Directories

```
bellavier-group-erp/
├── source/                    # Backend APIs & Services
│   ├── BGERP/                # PSR-4 Namespace Root
│   │   ├── Bootstrap/       # Bootstrap layers (TenantApiBootstrap, CoreApiBootstrap)
│   │   ├── Security/         # PermissionHelper (Task 19)
│   │   ├── Migration/        # BootstrapMigrations (Task 19)
│   │   ├── Http/             # TenantApiOutput (Task 20)
│   │   └── Service/           # Business logic services
│   ├── [module]_api.php      # API endpoints (tenant & platform)
│   ├── permission.php        # Thin wrapper (Task 19)
│   └── bootstrap_migrations.php  # Thin wrapper (Task 19)
│
├── tests/                     # Test Suite
│   ├── Integration/
│   │   ├── SystemWide/       # System-wide integration tests (Task 17)
│   │   ├── Bootstrap/       # Bootstrap tests (Task 16)
│   │   └── Api/              # API integration tests
│   └── Unit/                  # Unit tests
│
├── docs/
│   ├── bootstrap/            # Bootstrap design & task documentation
│   │   ├── Task/             # Task 16-20 documentation
│   │   ├── tenant_api_bootstrap.md
│   │   └── core_platform_bootstrap.design.md
│   ├── developer/            # Developer handbook (this directory)
│   ├── security/             # Security documentation
│   └── testing/              # Testing documentation
│
└── database/
    ├── tenant_migrations/     # PHP-based migrations (NOT SQL)
    └── tools/                 # Migration helpers
```

### Key Files to Know

- **Bootstrap**: `source/BGERP/Bootstrap/TenantApiBootstrap.php`, `CoreApiBootstrap.php`
- **Helpers**: `source/BGERP/Security/PermissionHelper.php`, `source/BGERP/Migration/BootstrapMigrations.php`
- **Test Base**: `tests/Integration/IntegrationTestCase.php`
- **Config**: `config.php`, `composer.json`

---

## How to Onboard Quickly

### Step 1: Read Developer Policy (15 minutes)
**File:** `docs/developer/01-policy/DEVELOPER_POLICY.md`

Essential reading that covers:
- Core principles (reliability, backward compatibility, security)
- Forbidden changes (business logic, auth, JSON format)
- Safety rails (bootstrap, permission, migration rules)
- Workflow guidelines (Task docs, tests, documentation)

### Step 2: Read Quick Start Guide (20 minutes)
**File:** `docs/developer/02-quick-start/QUICK_START.md`

Covers:
- Prerequisites (PHP, Composer, MySQL, MAMP)
- Local setup (clone, config, database)
- Running migrations (BootstrapMigrations helper)
- Running tests (SystemWide, Bootstrap, Api suites)
- Safely modifying APIs (bootstrap usage, helpers, JSON format)

### Step 3: Read Global Helpers Reference (10 minutes)
**File:** `docs/developer/02-quick-start/GLOBAL_HELPERS.md`

Essential helper map:
- `BGERP\Security\PermissionHelper` - Permission checks
- `BGERP\Migration\BootstrapMigrations` - Migration execution
- `DatabaseHelper` - Database operations
- `LogHelper` - Logging & error handling
- Bootstrap layers overview (links to detailed docs)

### Step 4: For AI Agents (5 minutes)
**File:** `docs/developer/02-quick-start/AI_QUICK_START.md`

If you're an AI agent (Cursor, ChatGPT, etc.):
- Golden rules for AI
- When editing bootstrap/security code
- Step-by-step workflow
- Examples of allowed/forbidden changes

---

## Documentation Index

### Developer Handbook (`docs/developer/`)

| File | Purpose |
|------|---------|
| `README.md` | Entry point (this file) |
| **`PROJECT_AUDIT_REPORT.md`** ⭐ | **Complete project audit (Database, APIs, Services, Architecture)** |
| `01-policy/DEVELOPER_POLICY.md` | Developer rules and standards |
| `02-quick-start/QUICK_START.md` | Setup and run guide |
| `02-quick-start/GLOBAL_HELPERS.md` | Helper functions reference |
| `02-quick-start/AI_QUICK_START.md` | AI agent quick start guide |
| `chapter.md` | Master structure for all chapters |
| `chapters/` | Detailed chapter documentation (15 chapters) |

### SuperDAG Documentation (`docs/developer/03-superdag/`)

**Complete SuperDAG documentation organized by context:**

- **[03-superdag/README.md](03-superdag/README.md)** ⭐ **START HERE**
  - Complete SuperDAG documentation structure
  - Quick start guide for developers and AI agents
  - All documentation organized by context

**Documentation Structure:**
- **01-core/** - Core Knowledge Documents (ความรู้พื้นฐาน)
- **02-reference/** - Reference Documents (เอกสารอ้างอิง)
- **03-specs/** - Specifications (สเปกสำหรับเตรียม Implement)
- **04-implementation/** - Implementation Guides (คู่มือการพัฒนา)
- **05-planning/** - Planning & Analysis (เอกสารการวางแผน)

**Key Documents:**
- `01-core/SuperDAG_Architecture.md` - System architecture (6 layers)
- `01-core/SuperDAG_Execution_Model.md` - Token state machine & execution flow
- `01-core/SuperDAG_Flow_Map.md` - Token flow (linear, parallel, conditional)
- `01-core/Node_Behavier.md` + `node_behavior_model.md` - Node behavior specification
- `01-core/time_model.md` - Time engine model

> **Note:** All SuperDAG core documentation is now in `docs/developer/03-superdag/`.  
> Task and test documentation remain in `docs/super_dag/tasks/` and `docs/super_dag/tests/`.

### Developer Handbook Chapters (`docs/developer/chapters/`)

| Chapter | File | Purpose |
|---------|------|---------|
| [Chapter 1](../chapters/01-system-overview.md) | `01-system-overview.md` | System overview & philosophy |
| [Chapter 2](../chapters/02-architecture-deep-dive.md) | `02-architecture-deep-dive.md` | Architecture deep dive |
| [Chapter 3](../chapters/03-bootstrap-system.md) | `03-bootstrap-system.md` | Bootstrap system |
| [Chapter 4](../chapters/04-permission-architecture.md) | `04-permission-architecture.md` | Permission architecture |
| [Chapter 5](../chapters/05-database-architecture.md) | `05-database-architecture.md` | Database architecture |
| [Chapter 6](../chapters/06-api-development-guide.md) | `06-api-development-guide.md` | API development guide |
| [Chapter 7](../chapters/07-global-helpers.md) | `07-global-helpers.md` | Global helpers |
| [Chapter 8](../chapters/08-traceability-token-system.md) | `08-traceability-token-system.md` | Traceability / token system |
| [Chapter 9](../chapters/09-pwa-scan-system.md) | `09-pwa-scan-system.md` | PWA scan system |
| [Chapter 10](../chapters/10-testing-framework.md) | `10-testing-framework.md` | Testing framework |
| [Chapter 11](../chapters/11-security-handbook.md) | `11-security-handbook.md` | Security handbook |
| [Chapter 12](../chapters/12-performance-guide.md) | `12-performance-guide.md` | Performance guide |
| [Chapter 13](../chapters/13-refactor-contribution-guide.md) | `13-refactor-contribution-guide.md` | Refactor & contribution guide |
| [Chapter 14](../chapters/14-pwa-frontend-integration.md) | `14-pwa-frontend-integration.md` | PWA/Frontend integration |
| [Chapter 15](../chapters/15-ai-developer-guidelines.md) | `15-ai-developer-guidelines.md` | AI developer guidelines |

**Status:** ✅ All 15 chapters completed and available.

### API Documentation (`docs/developer/04-api/`)

| File | Purpose |
|------|---------|
| `01-api-reference.md` | Complete API endpoint documentation |
| `02-service-api-reference.md` | Service layer documentation |
| `03-api-standards.md` | API Standard Playbook |
| `04-api-enterprise-audit.md` | Enterprise compliance audit |

### Database Documentation (`docs/developer/05-database/`)

| File | Purpose |
|------|---------|
| `01-schema-reference.md` | Database schema reference |
| `02-naming-policy.md` | Database naming policy |

### Architecture Documentation (`docs/developer/06-architecture/`)

| File | Purpose |
|------|---------|
| `01-system-overview.md` | System overview |
| `02-system-architecture.md` | System architecture overview |
| `03-platform-overview.md` | Platform overview |
| `04-ai-context.md` | Strategic context for AI agents |

### Security Documentation (`docs/developer/07-security/`)

| File | Purpose |
|------|---------|
| `01-tenant-cache-audit.md` | Tenant cache audit |
| `02-security-notes.md` | Security notes and best practices |

### Development Guides (`docs/developer/08-guides/`)

| File | Purpose |
|------|---------|
| `01-api-development.md` | Complete API development guide |
| `02-troubleshooting.md` | Common issues and solutions |
| `03-permission-management.md` | Permission system guide |
| `04-migration-wizard.md` | Migration system guide |
| `05-memory-guide.md` | AI memory catalog |
| `06-service-auto-binding.md` | Service auto binding guide |
| `07-service-reuse.md` | Service reuse guide |
| `08-i18n-implementation.md` | I18n implementation guide |
| `09-loghelper-usage.md` | LogHelper usage guide |
| `10-linear-deprecation.md` | Linear deprecation guide |
| `11-graph-viewer-usage.md` | Graph viewer usage |
| `12-manual-test-checklist.md` | Manual test checklist |

### Serial Number Documentation (`docs/developer/09-serial-number/`)

| File | Purpose |
|------|---------|
| `01-index.md` | Serial number system index |
| `02-design.md` | Serial number design |
| `03-implementation.md` | Implementation guide |
| `04-system-context.md` | System context |
| `05-integration-analysis.md` | Integration analysis |
| `06-context-awareness.md` | Context awareness |
| `07-prep-checklist.md` | Preparation checklist |
| `08-salt-quick-start.md` | Salt quick start |
| `09-salt-setup.md` | Salt setup guide |
| `10-salt-after-generate.md` | Salt after generate |
| `11-salt-ui-guide.md` | Salt UI guide |
| `12-salt-version-auto-update.md` | Salt version auto update |
| `13-setup-salt.md` | Setup salt guide |

### Production Documentation (`docs/developer/10-production/`)

| File | Purpose |
|------|---------|
| `01-production-hardening.md` | Production hardening guidelines |

### Bootstrap Documentation (`docs/developer/11-bootstrap/`)

| File | Purpose |
|------|---------|
| `01-tenant-api-bootstrap.md` | Tenant API bootstrap specification |
| `02-tenant-api-bootstrap-discovery.md` | Tenant API bootstrap discovery |
| `03-core-platform-bootstrap-discovery.md` | Core platform bootstrap discovery |

---

## Quick Navigation by Role

### I'm a New Developer
1. Read `DEVELOPER_POLICY.md` (rules and standards)
2. Read `QUICK_START.md` (setup and run)
3. Read `GLOBAL_HELPERS.md` (important helpers)
4. Explore `docs/bootstrap/` (architecture)

### I'm an AI Agent
1. Read `AI_QUICK_START.md` (5-minute guide)
2. Read `DEVELOPER_POLICY.md` (safety rails)
3. Follow workflow in `AI_QUICK_START.md`

### I'm Working on Bootstrap
1. Read `docs/bootstrap/tenant_api_bootstrap.md`
2. Read `docs/bootstrap/core_platform_bootstrap.design.md`
3. Read Task docs (task16.md - task20.md)
4. Check `tests/Integration/SystemWide/` for test patterns

### I'm Working on Security
1. Read `docs/security/task18_security_notes.md`
2. Read `DEVELOPER_POLICY.md` (security section)
3. Check `tests/Integration/SystemWide/SecurityAuditSystemWideTest.php`

---

## Related Documentation

### Architecture & Design
- `docs/bootstrap/tenant_api_bootstrap.md` - Tenant bootstrap specification
- `docs/bootstrap/core_platform_bootstrap.design.md` - Core bootstrap design
- `docs/architecture/` - System architecture documentation

### API Development
- `docs/guide/API_DEVELOPMENT_GUIDE.md` - Complete API development guide
- `docs/api/` - API reference documentation

### Testing
- `docs/testing/bootstrap_task16_integration_harness.md` - Integration test guide
- `tests/Integration/IntegrationTestCase.php` - Test base class

---

## Current Development Status

### Completed Tasks (Tasks 1-20)

- ✅ **Tasks 1-15**: Bootstrap migration (TenantApiBootstrap, CoreApiBootstrap)
- ✅ **Task 16**: Integration test harness (`IntegrationTestCase`)
- ✅ **Task 17**: System-wide integration tests (30+ tests)
- ✅ **Task 18**: Security review & hardening (audit complete)
- ✅ **Task 19**: PSR-4 helper migration (PermissionHelper, BootstrapMigrations)
- ✅ **Task 20**: Tenant API JSON output enforcement (TenantApiOutput)

### System State

- **Bootstrap Migration**: ✅ 77+ APIs migrated (65 tenant + 12 platform)
- **Legacy Files**: ⚠️ 50+ files still need migration
- **Integration Tests**: 30+ system-wide tests
- **Security Audit**: Complete (all findings documented)
- **PSR-4 Structure**: ✅ 118 files in BGERP namespace
- **Database Tables**: 135 tables (13 core + 122 tenant)
- **Services/Engines**: 84 total (47 services + 26 DAG + 6 MO + 4 Component + 1 Product)

**See [PROJECT_AUDIT_REPORT.md](PROJECT_AUDIT_REPORT.md) for complete audit details.**

---

## Getting Help

### Documentation
- Check `docs/developer/` for developer guides
- Check `docs/bootstrap/` for bootstrap architecture
- Check `docs/security/` for security guidelines

### Code Examples
- Bootstrap usage: `source/BGERP/Bootstrap/`
- Helper usage: `source/BGERP/Security/`, `source/BGERP/Migration/`
- Test patterns: `tests/Integration/SystemWide/`

### Questions
- Review relevant task documentation (`docs/bootstrap/Task/taskXX.md`)
- Check existing code patterns (grep, codebase_search)
- Read developer policy for rules and constraints

---

**Ready to start?** → Begin with `01-policy/DEVELOPER_POLICY.md` and `02-quick-start/QUICK_START.md`
