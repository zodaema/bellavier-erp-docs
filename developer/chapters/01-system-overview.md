# Chapter 1 — System Overview & Philosophy

**Last Updated:** January 2025  
**Purpose:** Introduce developers to the high-level architecture, principles, and goals  
**Audience:** New developers, AI agents, external consultants

---

## Overview

**Bellavier Group ERP** is a custom multi-tenant manufacturing ERP system designed for **Hatthasilpa** (luxury, handcrafted) and **Classic** (mass production) workflows. The system handles end-to-end manufacturing operations from Manufacturing Orders (MO) through Work-in-Progress (WIP) tracking, Quality Control (QC), Rework, and Completion.

### System Mission

To provide a **Hermès-grade reliable** manufacturing ERP system that:
- Ensures **100% traceability** of every piece through production
- Supports **multi-tenant** operations with complete data isolation
- Maintains **security-first** architecture with comprehensive audit trails
- Enables **AI-assisted** development while maintaining stability

### Current System State

- **Production Readiness**: 100% (all APIs enterprise-compliant)
- **Bootstrap Migration**: ✅ 77+ APIs migrated (65 tenant + 12 platform)
- **Legacy Files**: ⚠️ 8+ files still need migration
- **Database Tables**: 135 tables (13 core + 122 tenant)
- **Services/Engines**: 84 total (47 services + 26 DAG + 6 MO + 4 Component + 1 Product)
- **PSR-4 Classes**: 118 files in BGERP namespace
- **Integration Tests**: 30+ system-wide tests (Tasks 16-17)
- **Security Audit**: Complete (Task 18)
- **JSON Output**: Standardized (Task 20)
- **Performance**: Optimized (Task 21)

---

## Key Concepts

### 1. Multi-Tenant Architecture

**Core Database (`bgerp`):**
- Users, organizations, permissions
- Platform-level configuration
- Shared master data

**Tenant Databases (`bgerp_t_{org_code}`):**
- Organization-specific data
- Job tickets, WIP logs, inventory
- Complete data isolation per tenant

**Example:**
- `bgerp_t_default` - Default tenant
- `bgerp_t_maison_atelier` - Maison Atelier tenant

### 2. Bootstrap Layers

**TenantApiBootstrap:**
- For tenant-scoped APIs (65+ APIs)
- Resolves organization/tenant
- Initializes tenant database connection via DatabaseHelper
- Returns: `[$org, $db]` (where $db is DatabaseHelper instance)

**CoreApiBootstrap:**
- For platform/core APIs (12 APIs)
- Handles platform-level operations
- Supports multiple modes (platform_admin, auth_required, public, cli)
- Returns: `[$member, $coreDb, $tenantDb, $org, $cid]` (varies by mode)

### 3. Traceability Engine

**Token System:**
- Every piece tracked through production
- DAG (Directed Acyclic Graph) routing
- Full lifecycle: Spawn → Assign → Work → Route → Complete
- Complete audit trail for compliance

**WIP Tracking:**
- Real-time work progress
- Operator sessions
- Pause/Resume/Complete workflows
- Help Mode (Assist/Replace)

### 4. Security-First Architecture

**Rate Limiting:**
- All APIs protected
- Per-user, per-endpoint limits
- Configurable limits (strict, standard, low)

**CSRF Protection:**
- State-changing operations protected
- Token validation
- Secure session handling

**Secure Logging:**
- No sensitive data in logs
- Structured logging format
- Audit trails for compliance

---

## Core Components

### System Modules

1. **Manufacturing Orders (MO)**
   - Classic production planning
   - Scheduled production
   - Batch operations
   - MO Intelligence (ETA, Load Simulation, Cache)

2. **Hatthasilpa Jobs**
   - Luxury custom production
   - Flexible workflows
   - Small batch (1-50 pieces)
   - DAG-based routing

3. **Work-in-Progress (WIP)**
   - Real-time work tracking
   - Operator sessions
   - Progress calculation

4. **Quality Control (QC)**
   - QC checkpoints
   - Pass/Fail tracking
   - Rework management

5. **Traceability**
   - Token lifecycle
   - DAG routing
   - Complete audit trail

### API Categories

**Tenant APIs (65+ APIs):**
- `product_api.php`, `materials.php`, `bom.php`
- `dag_token_api.php`, `dag_routing_api.php`, `trace_api.php`
- `qc_rework.php`, `assignment_api.php`, `team_api.php`
- `mo_assist_api.php`, `mo_eta_api.php`, `mo_load_simulation_api.php`
- `hatthasilpa_jobs_api.php`, `hatthasilpa_operator_api.php`, `classic_api.php`
- Uses: `TenantApiBootstrap::init()`

**Platform APIs (12 APIs):**
- `platform_dashboard_api.php`, `platform_health_api.php`
- `platform_roles_api.php`, `platform_tenant_owners_api.php`
- `platform_migration_api.php`, `admin_org.php`
- Uses: `CoreApiBootstrap::init($mode)`

**PWA APIs:**
- `pwa_scan_api.php` (legacy, needs refactor)
- Mobile/scanning workflows
- QR code scanning

**Internal Tools:**
- `bootstrap_migrations.php` - Migration runner
- `run_tenant_migrations.php` - Tenant migration tool

---

## ERP Workflows

### Standard Production Flow

```
Manufacturing Order (MO)
    ↓
Job Ticket Creation
    ↓
Task Assignment
    ↓
Work-in-Progress (WIP)
    ↓
Quality Control (QC)
    ↓
[Pass] → Completion
[Fail] → Rework → WIP → QC
    ↓
Final Completion
```

### Token Lifecycle (DAG System)

```
Token Spawn
    ↓
Node Assignment
    ↓
Enter Node (Start Work)
    ↓
Work (Start/Pause/Resume/Complete)
    ↓
Route to Next Node
    ↓
[More Nodes] → Continue
[End Node] → Token Completed
```

### WIP Event Flow

```
WIP Log Created/Updated/Deleted
    ↓
1. OperatorSessionService->handleWIPEvent()
    ↓
2. JobTicketStatusService->updateAfterLog()
    ↓
3. Recalc Task Status
    ↓
4. Recalc Ticket Status
```

---

## High-Level Data Flow

### Request Lifecycle

```
HTTP Request
    ↓
Bootstrap Layer (TenantApiBootstrap or CoreApiBootstrap)
    ├── Resolve tenant/org
    ├── Initialize database
    ├── Authenticate user
    ├── Apply rate limiting
    └── Set up error handling
    ↓
API Endpoint
    ├── Validate input
    ├── Check permissions
    ├── Execute business logic
    └── Generate response
    ↓
Helper Layer (Services, Helpers)
    ├── Database operations
    ├── Business logic
    └── Data transformation
    ↓
Database (Core or Tenant)
    ├── Read/Write operations
    └── Transaction management
    ↓
JSON Output
    ├── Standard format: {ok: true/false}
    ├── Data payload
    └── Metadata (AI trace, correlation ID)
```

---

## Developer Responsibilities

### Code Quality

- ✅ **Read First**: 20-30 minutes reading documentation prevents hours of debugging
- ✅ **Check Existing**: Search for similar code before creating new
- ✅ **Follow Patterns**: Use existing bootstrap, helpers, and services
- ✅ **Test Everything**: Write tests for all new features
- ✅ **Document Changes**: Update relevant documentation

### Security

- ✅ **Prepared Statements**: 100% coverage, no exceptions
- ✅ **Input Validation**: All inputs validated before processing
- ✅ **Rate Limiting**: All APIs protected
- ✅ **CSRF Protection**: State-changing operations protected
- ✅ **Secure Logging**: No sensitive data in logs

### Backward Compatibility

- ✅ **Preserve Contracts**: Don't break existing API contracts
- ✅ **Thin Wrappers**: Preserve legacy function wrappers
- ✅ **Gradual Migration**: Support both old and new patterns
- ✅ **Version Awareness**: Document breaking changes clearly

### Performance

- ✅ **Query Optimization**: Use indexes, avoid N+1 queries
- ✅ **Efficient Patterns**: Follow Task 21 optimization patterns
- ✅ **Profile Before Optimize**: Measure, don't guess
- ✅ **Scalability**: Design for 1000+ users, 10,000+ records

---

## Common Pitfalls

### 1. Missing Bootstrap

**Problem:**
```php
// ❌ Wrong: No bootstrap
$db = mysqli_connect(...);
```

**Solution:**
```php
// ✅ Correct: Use bootstrap
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();
```

### 2. Wrong JSON Format

**Problem:**
```php
// ❌ Wrong: Non-standard format
echo json_encode(['success' => true, 'data' => $data]);
```

**Solution:**
```php
// ✅ Correct: Standard format
TenantApiOutput::success($data, $meta, 200);
// Or
json_success(['data' => $data]);
```

### 3. Missing Rate Limiting

**Problem:**
```php
// ❌ Wrong: No rate limiting
// API vulnerable to abuse
```

**Solution:**
```php
// ✅ Correct: Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'api_name', 'action', 120, 60);
```

### 4. Missing Soft-Delete Filter

**Problem:**
```php
// ❌ Wrong: Includes deleted records
SELECT * FROM atelier_wip_log WHERE id_job_task=?
```

**Solution:**
```php
// ✅ Correct: Filter soft-deleted
SELECT * FROM atelier_wip_log 
WHERE id_job_task=? AND deleted_at IS NULL
```

### 5. Cross-Database JOIN

**Problem:**
```php
// ❌ Wrong: Cross-DB JOIN in prepared statement
SELECT t.*, u.name 
FROM atelier_job_task t 
LEFT JOIN bgerp.account u ON u.id_member=t.assigned_to
```

**Solution:**
```php
// ✅ Correct: Two-step fetch + merge
// Step 1: Fetch from tenant
$tasks = db_fetch_all($tenantDb, "SELECT * FROM atelier_job_task WHERE id_job_ticket=?", [$ticketId]);

// Step 2: Fetch users from core
$userIds = array_column($tasks, 'assigned_to');
$users = fetch_users_by_ids($userIds); // From core DB

// Step 3: Merge
foreach ($tasks as &$task) {
    $task['assigned_name'] = $users[$task['assigned_to']]['name'] ?? null;
}
```

---

## Examples

### Example 1: Tenant API Structure

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'products', 'list', 120, 60);

// Action routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'list':
            // Permission check
            use BGERP\Security\PermissionHelper;
            if (!PermissionHelper::platform_has_permission($member, 'products.list')) {
                json_error('forbidden', 403);
            }
            
            // Business logic
            $products = fetch_products($tenantDb);
            
            // Output
            use BGERP\Http\TenantApiOutput;
            TenantApiOutput::success(['data' => $products], null, 200);
            break;
            
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### Example 2: Platform API Structure

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap (platform admin mode)
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'platform_dashboard', 'summary', 120, 60);

// Action routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'summary':
            // Business logic
            $summary = fetch_platform_summary($coreDb);
            
            // Output
            json_success(['data' => $summary]);
            break;
            
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

---

## Reference Documents

### Essential Reading

- **Developer Handbook**: `docs/developer/README.md` - Entry point
- **Developer Policy**: `docs/developer/01-policy/DEVELOPER_POLICY.md` - Rules and standards
- **Quick Start**: `docs/developer/02-quick-start/QUICK_START.md` - Setup guide
- **Global Helpers**: `docs/developer/02-quick-start/GLOBAL_HELPERS.md` - Helper reference
- **AI Quick Start**: `docs/developer/02-quick-start/AI_QUICK_START.md` - AI agent guide

### Architecture Documentation

- **Tenant Bootstrap**: `docs/bootstrap/tenant_api_bootstrap.md` - Tenant bootstrap specification
- **Core Bootstrap**: `docs/bootstrap/core_platform_bootstrap.design.md` - Core bootstrap design
- **Task Documentation**: `docs/bootstrap/Task/task16.md` - `task21.md` - Recent task history

### Security Documentation

- **Security Notes**: `docs/security/task18_security_notes.md` - Security audit findings
- **Security Tests**: `tests/Integration/SystemWide/SecurityAuditSystemWideTest.php`

### Performance Documentation

- **Task 21 Results**: `docs/performance/task21_results.md` - Query optimization results

---

## Future Expansion

### Planned Enhancements

1. **DAG Production System** (Q1 2026 - Conditional)
   - Full DAG-based routing
   - Graph visualization
   - Advanced analytics

2. **Async Jobs System**
   - Background processing
   - Queue management
   - Job scheduling

3. **Redis Cache Layer**
   - Performance optimization
   - Session caching
   - Query result caching

4. **Observability / Monitoring**
   - Real-time metrics
   - Performance monitoring
   - Error tracking

5. **ERP Extensions**
   - Additional modules
   - Third-party integrations
   - Custom workflows

### Migration Roadmap

- **Phase 1**: Bootstrap migration (✅ Complete - 77+ APIs migrated)
- **Phase 2**: System-wide testing (✅ Complete - Tasks 16-17)
- **Phase 3**: Security hardening (✅ Complete - Task 18)
- **Phase 4**: PSR-4 helpers (✅ Complete - Task 19)
- **Phase 5**: JSON standardization (✅ Complete - Task 20)
- **Phase 6**: Performance optimization (✅ Complete - Task 21)
- **Phase 7**: DAG production system (✅ Complete - SuperDAG with self-healing, time engine, MO intelligence)
- **Phase 8**: Legacy file migration (⏳ In Progress - 8+ files remaining)

---

## "How to Think Inside This System"

### Hermès-Level Reliability Model

This system follows a **Hermès-grade reliability model**:

1. **Stability First**
   - No breaking changes without explicit approval
   - Backward compatibility is sacred
   - Test coverage is mandatory

2. **Security Above All**
   - Every endpoint protected
   - Every input validated
   - Every output sanitized

3. **Explicit Over Implicit**
   - Clear error messages
   - No silent failures
   - Comprehensive logging

4. **Quality Over Speed**
   - Read documentation first
   - Test thoroughly
   - Document changes

5. **Production Mindset**
   - This system handles real businesses
   - Data integrity is critical
   - User experience matters

### Development Philosophy

- **Read → Check → Design → Code → Test → Document**
- **Minimal changes, maximum impact**
- **Backward compatibility is non-negotiable**
- **Security is everyone's responsibility**
- **Documentation is code**

---

**Next Chapter:** [Chapter 2 — Architecture Deep Dive](../chapters/02-architecture-deep-dive.md)

