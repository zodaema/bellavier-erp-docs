# Chapter 2 — Architecture Deep Dive

**Last Updated:** January 2025  
**Purpose:** The technical blueprint of the Bellavier Group ERP system  
**Audience:** Developers working on core architecture, AI agents modifying system components

---

## Overview

This chapter provides a comprehensive technical overview of the Bellavier Group ERP architecture, covering multi-tenant design, bootstrap layers, security architecture, database topology, and the traceability engine.

**Key Topics:**
- Multi-tenant architecture design
- Tenant vs Platform separation
- Request lifecycle
- Bootstrap layers (TenantApiBootstrap, CoreApiBootstrap)
- Security layers and flow
- Database topology
- Traceability engine (token system)

---

## Key Concepts

### 1. Multi-Tenant Architecture

**Design Principle:**
Complete data isolation per organization (tenant) while sharing platform-level infrastructure.

**Core Database (`bgerp`):**
- **Purpose**: Platform-level data shared across all tenants
- **Contains**:
  - User accounts (`account` table)
  - Organizations (`organization` table)
  - Permissions (`permission` table)
  - Platform roles (`platform_role` table)
  - Platform configuration

**Tenant Databases (`bgerp_t_{org_code}`):**
- **Purpose**: Organization-specific data, completely isolated
- **Naming Pattern**: `bgerp_t_{org_code}` (e.g., `bgerp_t_default`, `bgerp_t_maison_atelier`)
- **Contains**:
  - Job tickets (`atelier_job_ticket`)
  - Tasks (`atelier_job_task`)
  - WIP logs (`atelier_wip_log`)
  - Inventory data
  - Production data
  - All business-specific data

**Data Isolation:**
- ✅ Complete isolation: Each tenant's data is in a separate database
- ✅ No cross-tenant queries: Impossible to accidentally query another tenant's data
- ✅ Tenant resolution: Handled by bootstrap layer automatically

### 2. Tenant vs Platform Separation

**Tenant Layer:**
- **Scope**: Organization-specific operations
- **Bootstrap**: `TenantApiBootstrap::init()`
- **Database**: Tenant database (`bgerp_t_{org_code}`) - 122 tables
- **APIs**: 65+ tenant-scoped APIs
- **Examples**: `product_api.php`, `materials.php`, `dag_token_api.php`, `dag_routing_api.php`, `trace_api.php`, `mo_assist_api.php`, `hatthasilpa_jobs_api.php`, `classic_api.php`

**Platform Layer:**
- **Scope**: Platform-wide operations
- **Bootstrap**: `CoreApiBootstrap::init($mode)`
- **Database**: Core database (`bgerp`) - 13 tables
- **APIs**: 12 platform-scoped APIs
- **Examples**: `platform_dashboard_api.php`, `platform_health_api.php`, `platform_roles_api.php`, `admin_org.php`

**Separation Benefits:**
- ✅ Clear boundaries: No confusion about data scope
- ✅ Security: Platform operations require platform admin
- ✅ Scalability: Tenant operations scale independently
- ✅ Maintainability: Clear separation of concerns

---

## Core Components

### Request Lifecycle

#### 1. HTTP Request Arrives

```
HTTP Request
├── Method: GET/POST/PUT/DELETE
├── URL: /source/api_name.php?action=...
├── Headers: X-Correlation-Id, X-AI-Trace, etc.
└── Body: JSON or form data
```

#### 2. Bootstrap Initialization

**Tenant API Flow:**
```php
TenantApiBootstrap::init()
    ├── Load config.php
    ├── Start session
    ├── Resolve organization (from session/context)
    ├── Initialize tenant database connection
    ├── Authenticate user
    ├── Apply rate limiting
    ├── Set up error handling
    └── Return: [$org, $tenantDb, $member]
```

**Platform API Flow:**
```php
CoreApiBootstrap::init($mode)
    ├── Load config.php
    ├── Start session (if not CLI mode)
    ├── Authenticate user (if required by mode)
    ├── Check platform admin (if mode='platform_admin')
    ├── Initialize core database connection
    ├── Apply rate limiting
    ├── Set up error handling
    └── Return: [$member, $coreDb]
```

#### 3. API Processing

```php
API Endpoint
    ├── Extract action from request
    ├── Validate input
    ├── Check permissions
    ├── Execute business logic
    │   ├── Call services
    │   ├── Database operations
    │   └── Data transformation
    └── Generate response
```

#### 4. Response Generation

```php
JSON Output
    ├── Standard format: {ok: true/false}
    ├── Data payload
    ├── Metadata (AI trace, correlation ID)
    └── Headers (Content-Type, X-Correlation-Id, X-AI-Trace)
```

### Bootstrap Layers

#### TenantApiBootstrap

**Location:** `source/BGERP/Bootstrap/TenantApiBootstrap.php`

**Purpose:**
Initialize tenant-scoped APIs with organization context, tenant database, and authenticated user.

**Initialization Steps:**
1. Load global configuration (`config.php`)
2. Start session
3. Resolve current organization (from session/context)
4. Initialize tenant database connection
5. Authenticate user
6. Apply rate limiting
7. Set up error handling

**Return Values:**
```php
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
```

- `$org`: Organization/tenant information (array)
- `$tenantDb`: Tenant database connection (mysqli)
- `$member`: Current user/member information (array)

**Usage:**
```php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Now safe to use $org, $tenantDb, $member
```

**APIs Using TenantApiBootstrap:**
- 40+ tenant-scoped APIs
- Examples: `products.php`, `materials.php`, `dag_token_api.php`, `trace_api.php`

#### CoreApiBootstrap

**Location:** `source/BGERP/Bootstrap/CoreApiBootstrap.php`

**Purpose:**
Initialize platform/core APIs with core database and authenticated user (if required).

**Modes:**
- `'platform_admin'`: Requires platform administrator
- `'auth_required'`: Requires authentication
- `'public'`: No authentication required
- `'cli'`: CLI mode (no session)

**Initialization Steps:**
1. Load global configuration (`config.php`)
2. Start session (if not CLI mode)
3. Authenticate user (if required by mode)
4. Check platform admin (if mode='platform_admin')
5. Initialize core database connection
6. Apply rate limiting
7. Set up error handling

**Return Values:**
```php
[$member, $coreDb] = CoreApiBootstrap::init($mode);
```

- `$member`: Current user/member information (array, null if public/cli)
- `$coreDb`: Core database connection (mysqli)

**Usage:**
```php
require_once __DIR__ . '/../vendor/autoload.php';

[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');

// Now safe to use $member, $coreDb
```

**APIs Using CoreApiBootstrap:**
- 12 platform-scoped APIs
- Examples: `platform_dashboard_api.php`, `platform_health_api.php`, `admin_org.php`

### Security Layers and Flow

#### 1. Authentication Layer

**Session-Based Authentication:**
- Session started by bootstrap
- User authenticated via `memberDetail->thisLogin()`
- Session stored in PHP session

**Platform Admin Check:**
- `PermissionHelper::isPlatformAdministrator($member)`
- Required for platform operations
- Checked by `CoreApiBootstrap` in `platform_admin` mode

#### 2. Authorization Layer

**Permission Checks:**
- `PermissionHelper::platform_has_permission($member, $permission)`
- `PermissionHelper::hasOrgPermission($member, $permission)`
- Applied per endpoint/action

**Tenant Isolation:**
- Automatic: Tenant database connection ensures data isolation
- No manual tenant checks needed (bootstrap handles it)

#### 3. Rate Limiting Layer

**Implementation:**
- `RateLimiter::check($userId, $endpoint, $action, $limit, $windowSeconds)`
- Applied in bootstrap layer
- Per-user, per-endpoint limits

**Configuration:**
- **Strict**: 10 req/60s (security-critical operations)
- **Standard**: 120 req/60s (normal operations)
- **Very Low**: 5 req/60s (migration operations)

#### 4. CSRF Protection Layer

**Implementation:**
- `validateCsrfToken($token)`
- Applied to state-changing operations (POST/PUT/DELETE)
- Token validation before processing

#### 5. Input Validation Layer

**Validation:**
- All inputs validated before processing
- Type checking, range validation, format validation
- Sanitization for output

#### 6. Error Handling Layer

**Structured Errors:**
- Standard JSON error format: `{ok: false, error: {code: "...", message: "..."}}`
- No sensitive data in error messages
- Comprehensive logging (non-sensitive)

### Database Topology

#### Core Database (`bgerp`)

**Tables:**
- `account` - User accounts
- `organization` - Organizations/tenants
- `permission` - Permission definitions
- `platform_role` - Platform roles
- `tenant_schema_migrations` - Migration tracking

**Connection:**
```php
$coreDb = core_db(); // Helper function
// Or via CoreApiBootstrap
[$member, $coreDb] = CoreApiBootstrap::init('platform_admin');
```

#### Tenant Databases (`bgerp_t_{org_code}`)

**Tables:**
- `atelier_job_ticket` - Job tickets
- `atelier_job_task` - Tasks
- `atelier_wip_log` - WIP logs (soft-delete)
- `atelier_task_operator_session` - Operator sessions
- `routing_graph` - DAG graphs
- `routing_node` - DAG nodes
- `routing_edge` - DAG edges
- `flow_token` - Tokens
- `token_event` - Token events
- `node_instance` - Node instances
- `tenant_schema_migrations` - Migration tracking

**Connection:**
```php
$tenantDb = tenant_db($orgCode); // Helper function
// Or via TenantApiBootstrap
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
```

#### Cross-Database Queries

**Pattern:**
Two-step fetch + merge (MySQL limitation with prepared statements)

```php
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

**Why:**
- MySQL prepared statements don't support cross-database JOINs reliably
- Two-step approach ensures data integrity
- Clear separation of concerns

### Traceability Engine (Token System)

#### Token Lifecycle

```
Token Spawn
    ├── Create token in flow_token table
    ├── Assign to initial node
    └── Set status: 'pending'
    ↓
Node Assignment
    ├── Assign operator to node
    ├── Create node_instance
    └── Update token status: 'assigned'
    ↓
Enter Node (Start Work)
    ├── Create token_event: 'enter'
    ├── Update node_instance: started_at
    └── Update token status: 'in_progress'
    ↓
Work (Start/Pause/Resume/Complete)
    ├── Create token_event: 'start', 'pause', 'resume', 'complete'
    ├── Update operator session
    └── Track work time
    ↓
Route to Next Node
    ├── Determine next node (DAG routing)
    ├── Create token_event: 'route'
    ├── Update token: current_node_id
    └── Update status: 'pending' (if more nodes) or 'completed' (if end node)
    ↓
Token Completed
    ├── Update token status: 'completed'
    ├── Set completed_at timestamp
    └── Finalize audit trail
```

#### DAG Routing Design

**Components:**
- `routing_graph` - Graph definitions
- `routing_node` - Node definitions (work stations)
- `routing_edge` - Edge definitions (routing paths)
- `flow_token` - Tokens flowing through graph
- `token_event` - Token events (audit trail)
- `node_instance` - Node instances (work sessions)

**Routing Logic:**
- Determine next node based on current node and conditions
- Support split/join/conditional routing
- Handle parallel paths
- Support rework loops

**Security:**
- Token ownership validation
- Node access control
- Operator assignment checks
- Complete audit trail

---

## Developer Responsibilities

### When Working with Bootstrap

**MUST:**
- ✅ Use correct bootstrap (`TenantApiBootstrap` or `CoreApiBootstrap`)
- ✅ Don't bypass bootstrap initialization
- ✅ Use returned values correctly (`$org`, `$tenantDb`, `$member`, `$coreDb`)
- ✅ Don't create manual database connections

**DO NOT:**
- ❌ Create manual database connections
- ❌ Bypass tenant resolution
- ❌ Mix tenant and platform operations
- ❌ Change bootstrap return values

### When Working with Database

**MUST:**
- ✅ Use prepared statements (100% coverage)
- ✅ Use correct database connection (`$tenantDb` or `$coreDb`)
- ✅ Filter soft-deleted records (for WIP logs: `WHERE deleted_at IS NULL`)
- ✅ Use two-step fetch + merge for cross-DB queries

**DO NOT:**
- ❌ Use raw SQL without prepared statements
- ❌ Mix tenant and core database connections
- ❌ Forget soft-delete filter (for WIP logs)
- ❌ Use cross-DB JOINs in prepared statements

### When Working with Security

**MUST:**
- ✅ Check permissions before operations
- ✅ Validate all inputs
- ✅ Apply rate limiting
- ✅ Apply CSRF protection (state-changing operations)
- ✅ Log errors (non-sensitive)

**DO NOT:**
- ❌ Skip permission checks
- ❌ Trust user input
- ❌ Log sensitive data
- ❌ Expose internal errors to users

---

## Common Pitfalls

### 1. Wrong Bootstrap Usage

**Problem:**
```php
// ❌ Wrong: Using TenantApiBootstrap for platform operation
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// Then trying to access core database
```

**Solution:**
```php
// ✅ Correct: Use CoreApiBootstrap for platform operations
[$member, $coreDb] = CoreApiBootstrap::init('platform_admin');
```

### 2. Manual Database Connection

**Problem:**
```php
// ❌ Wrong: Manual connection bypasses bootstrap
$db = mysqli_connect('localhost', 'user', 'pass', 'bgerp_t_default');
```

**Solution:**
```php
// ✅ Correct: Use bootstrap
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// $tenantDb is already initialized
```

### 3. Cross-Database JOIN

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
// (See Database Topology section above)
```

### 4. Missing Tenant Resolution

**Problem:**
```php
// ❌ Wrong: Hardcoded tenant
$tenantDb = tenant_db('default'); // Hardcoded!
```

**Solution:**
```php
// ✅ Correct: Use bootstrap (automatic tenant resolution)
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// $org contains resolved tenant information
```

---

## Examples

### Example 1: Tenant API with Bootstrap

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap (automatic tenant resolution)
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'products', 'list', 120, 60);

// Permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::platform_has_permission($member, 'products.list')) {
    json_error('forbidden', 403);
}

// Database operation (using tenant database)
$stmt = $tenantDb->prepare("SELECT * FROM products WHERE org_id=?");
$stmt->bind_param('i', $org['id_org']);
$stmt->execute();
$products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Output
use BGERP\Http\TenantApiOutput;
TenantApiOutput::success(['data' => $products], null, 200);
```

### Example 2: Platform API with Bootstrap

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap (platform admin mode)
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'platform_dashboard', 'summary', 120, 60);

// Database operation (using core database)
$stmt = $coreDb->prepare("SELECT COUNT(*) as total_orgs FROM organization WHERE status=1");
$stmt->execute();
$result = $stmt->get_result()->fetch_assoc();

// Output
json_success(['data' => ['total_orgs' => $result['total_orgs']]]);
```

### Example 3: Cross-Database Query

```php
<?php
// Step 1: Fetch tasks from tenant database
$tasks = db_fetch_all($tenantDb, 
    "SELECT * FROM atelier_job_task WHERE id_job_ticket=?", 
    [$ticketId]
);

// Step 2: Extract user IDs
$userIds = array_filter(array_column($tasks, 'assigned_to'));

// Step 3: Fetch users from core database
if (!empty($userIds)) {
    $placeholders = implode(',', array_fill(0, count($userIds), '?'));
    $types = str_repeat('i', count($userIds));
    $stmt = $coreDb->prepare("SELECT id_member, name FROM account WHERE id_member IN ($placeholders)");
    $stmt->bind_param($types, ...$userIds);
    $stmt->execute();
    $users = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $userMap = array_column($users, 'name', 'id_member');
} else {
    $userMap = [];
}

// Step 4: Merge
foreach ($tasks as &$task) {
    $task['assigned_name'] = $userMap[$task['assigned_to']] ?? null;
}
```

---

## Reference Documents

### Architecture Documentation

- **Tenant Bootstrap**: `docs/bootstrap/tenant_api_bootstrap.md` - Complete specification
- **Core Bootstrap**: `docs/bootstrap/core_platform_bootstrap.design.md` - Design specification
- **Chapter 3**: `docs/developer/chapters/03-bootstrap-system.md` - Detailed bootstrap guide

### Task Documentation

- **Tasks 1-15**: Bootstrap migration (TenantApiBootstrap, CoreApiBootstrap)
- **Task 16**: Integration test harness
- **Task 17**: System-wide integration tests
- **Task 19**: PSR-4 helper migration

### Code Examples

- **Bootstrap Classes**: `source/BGERP/Bootstrap/TenantApiBootstrap.php`, `CoreApiBootstrap.php`
- **Test Examples**: `tests/Integration/SystemWide/BootstrapTenantInitTest.php`, `BootstrapCoreInitTest.php`

---

## Future Expansion

### Planned Enhancements

1. **CLI Bootstrap** (`CoreCliBootstrap`)
   - For command-line tools
   - No session, no authentication
   - Direct database access

2. **Async Job Bootstrap**
   - For background jobs
   - Queue-based processing
   - Retry mechanisms

3. **GraphQL API Layer**
   - Alternative to REST APIs
   - Unified query interface
   - Type-safe queries

4. **Microservices Architecture**
   - Service decomposition
   - Independent scaling
   - Service mesh

---

**Previous Chapter:** [Chapter 1 — System Overview](../chapters/01-system-overview.md)  
**Next Chapter:** [Chapter 3 — Bootstrap System](../chapters/03-bootstrap-system.md)

