# Bellavier Group ERP / Platform Overview

**Last Updated:** December 6, 2025  
**Version:** 3.0 (SuperDAG Complete + Component Architecture V2 + Material System)

---

## Purpose & Vision
- Provide a multi-tenant ERP tailored for leather goods manufacturers
- **Hatthasilpa** (Luxury, 1-50 pcs) - DAG routing, token-based tracking
- **Classic** (Mass production, 50-1000+ pcs) - Linear routing, WIP logs
- Separate **Platform Owner** governance from **Tenant Operators**
- Enable small teams of artisans to work with minimal IT friction
- Support traceability from raw material → production → QC → inventory

---

## High-Level Architecture

```
+-------------+        +-----------------+
| Platform DB |<-----> | Application PHP |
+-------------+        +-----------------+
       ^                       |
       | tenant provisioning   | runtime per-session
       v                       v
+-------------------+   +-------------------+
| Tenant DB (org A) |   | Tenant DB (org B) |
+-------------------+   +-------------------+
```

- **Core Platform (bgerp)**
  - Accounts, organizations, permissions, platform roles
  - Tenant registry + provisioning utilities
  - Platform console UI (hidden for tenant users)

- **Tenant Databases (bgerp_t_*)**
  - Provisioned via migrations (`database/tenant_migrations/*`)
  - Contain operational tables (materials, inventory, MO, jobs, tokens)

- **Runtime Separation**
  - `resolve_current_org()` selects DB connection per session
  - Permissions checked via `permission_allow_code()` for tenant scope
  - Platform access via `platform_has_permission()`

---

## Key Modules (Current State - December 2025)

| Area | Description | Status |
|------|-------------|--------|
| **Authentication & Org Switch** | Multi-tenant login, org dropdown, session isolation | ✅ stable |
| **User & Role Management** | Tenant scoped (Owner/Admin etc.), invitations | ✅ stable |
| **Inventory (Stock, Lots)** | CRUD for materials, warehouses, lot tracking | ✅ stable |
| **Goods Movements** | GRN/Issue/Transfer/Adjust with auto-refresh DataTables | ✅ stable |
| **Manufacturing Orders (MO)** | Create MO, track status, auto status from tickets | ✅ stable |
| **Job Ticket / WIP** | Full CRUD, WIP logs, tasks, QR codes, dependencies | ✅ stable |
| **Operator Sessions** | Individual operator tracking, concurrent work | ✅ stable |
| **Production Schedule** | Calendar view, drag-drop, conflict detection | ✅ stable |
| **QC Fail & Rework** | Attachments, close/reopen workflow, mobile camera | ✅ stable |
| **BOM Management** | Multi-level BOM, cost roll-up, tree view | ✅ stable |
| **Routing** | Production steps, standard times, sequence management | ✅ stable |
| **Dashboard** | Hatthasilpa-specific KPIs, real-time metrics | ✅ stable |
| **Platform Tools** | Migration Wizard, Health Check, Platform Dashboard | ✅ stable |
| **PWA Scan Station V2** | 100% Offline-capable, IndexedDB cache | ✅ production |
| **Exceptions Board** | Real-time production issue monitoring | ✅ stable |
| **Permission System** | RBAC with frontend integration | ✅ stable |
| **SuperDAG Engine** | Graph-based parallel production, token flow | ✅ production |
| **Component Architecture V2** | 3-layer model, graph mapping | ✅ stable |
| **Product Readiness** | Configuration validation before job creation | ✅ stable |
| **Material Requirement** | Backend: calculate, reserve, allocate | ✅ complete |
| **Defect Catalog** | 36 defects, 8 categories | ✅ stable |
| **QC Rework V2** | Component-aware, defect-based suggestions | ✅ stable |
| **Graph Linter** | 30+ validation rules | ✅ stable |
| **MCI (Component Injection)** | Missing component handling | ✅ stable |

---

## Data Model Highlights

### Core DB (bgerp - shared)
- `account`, `account_org`, `organization`, `permission`
- Platform-only: `platform_user`, `platform_role`, `platform_permission`
- Core migrations: `database/migrations/0001_core_bootstrap.php`

### Tenant DB (bgerp_t_* - per org)

**Core Tables:**
- `product`, `bom`, `routing`, `stock`, `warehouse`
- `work_center`, `machine`
- `tenant_role`, `permission`

**Manufacturing:**
- `mo` - Manufacturing orders
- `atelier_job_ticket` - Job tickets (Linear routing)
- `atelier_job_task`, `atelier_wip_log`
- `atelier_task_operator_session`

**DAG Routing:**
- `routing_graph`, `routing_node`, `routing_edge` - Graph templates
- `job_graph_instance`, `node_instance` - Job execution
- `flow_token`, `token_event` - Token tracking
- `token_work_session`, `token_repair_log`

**Component Architecture V2 (NEW Dec 2025):**
- `component_type_catalog` - 24 generic types (BODY, STRAP, etc.)
- `product_component` - Product-specific components
- `product_component_material` - BOM per component
- `graph_component_mapping` - Map anchor_slot → product_component

**QC & Defect (NEW Dec 2025):**
- `defect_category` - 8 categories
- `defect_catalog` - 36 defect definitions
- `qc_rework_override_log` - Supervisor override audit

**Material System (NEW Dec 2025):**
- `material_requirement` - Calculated requirements per job
- `material_reservation` - Reserved stock
- `material_allocation` - Consumed materials
- `material_requirement_log` - Audit trail
- `v_material_available` (VIEW) - Available stock
- `v_job_material_status` (VIEW) - Job material summary

**Audit:**
- `product_config_log` - Product configuration changes
- `component_injection_log` - MCI audit trail

---

## December 2025 Milestones

### **Task 27.12-27.19 Complete:**

| Task | Name | Deliverables |
|------|------|--------------|
| 27.12 | Component Catalog | `component_type_catalog` table, 24 seed types |
| 27.13.11b | Product Component BOM | `product_component`, `product_component_material` tables |
| 27.13.12 | Component Mapping Refactor | `graph_component_mapping` V2, UI refactor |
| 27.14 | Defect Catalog | `defect_category`, `defect_catalog` tables, API |
| 27.15 | QC Rework V2 | `QCReworkV2Service`, component-aware rework |
| 27.16 | Graph Linter | `GraphLinterService`, 30+ validation rules |
| 27.17 | MCI | `ComponentInjectionService`, `component_injection_log` |
| 27.18 | Material Requirement | 3 services, 4 tables, 2 views, 8 API endpoints |
| 27.19 | Product Readiness | `ProductReadinessService`, `product_config_log` |

### **New Services Created:**

```
source/BGERP/Service/
├─ ComponentMappingService.php
├─ ProductReadinessService.php
├─ MaterialRequirementService.php
├─ MaterialReservationService.php
├─ MaterialAllocationService.php

source/BGERP/Dag/
├─ ComponentInjectionService.php
├─ GraphLinterService.php
├─ QCReworkV2Service.php
```

### **New API Endpoints:**

```
source/defect_catalog_api.php
├─ list, get, create, update, delete, list_categories

source/material_requirement_api.php
├─ calculate, list, check_availability, recalculate
├─ reserve, release, get_reservations
├─ allocate, consume, get_allocations, log_waste

source/product_api.php (extended)
├─ get_product_readiness
├─ get_component_mappings_v2
├─ save_component_mapping_v2
├─ remove_component_mapping_v2
```

---

## API Endpoint Patterns

### **Standard JSON Response:**
```php
// Success
json_success(['data' => $result, 'message' => 'Operation completed']);
// → {"ok": true, "data": {...}, "message": "..."}

// Error
json_error('Validation failed', 400);
// → {"ok": false, "error": "Validation failed"}
```

### **Enterprise API Helpers:**
```php
// Rate Limiting
RateLimiter::check($member, 120, 60, 'endpoint_name');

// Request Validation
$validation = RequestValidator::make($data, [
    'product_id' => 'required|int',
    'qty' => 'required|numeric|min:1'
]);

// Idempotency
Idempotency::guard($key, 'create_job');
Idempotency::store($key, $response, 201);

// ETag/If-Match
$etag = $this->generateETag($record);
if (isset($_SERVER['HTTP_IF_MATCH']) && $_SERVER['HTTP_IF_MATCH'] !== $etag) {
    json_error('Conflict: record has been modified', 409);
}
```

---

## Code Organization

```
source/
├── BGERP/
│   ├── Service/              ← Core services
│   │   ├── TokenLifecycleService.php
│   │   ├── DAGRoutingService.php
│   │   ├── ComponentMappingService.php
│   │   ├── ProductReadinessService.php
│   │   ├── MaterialRequirementService.php
│   │   └── ...
│   └── Dag/                  ← DAG-specific services
│       ├── ComponentInjectionService.php
│       ├── GraphLinterService.php
│       └── QCReworkV2Service.php
├── utils/
│   ├── InventoryHelper.php
│   ├── ssdt.php              ← Server-side DataTables
│   └── refs.php              ← Centralized lookups
└── *_api.php                 ← API endpoints

assets/javascripts/
├── global_script.js          ← Global helpers (formatNumber, BG.ui, BG.api, etc.)
├── products/                 ← Product module JS
│   ├── products.js
│   ├── product_components.js
│   └── product_graph_binding.js
├── dag/                      ← DAG JS
│   └── behavior_ui_templates.js
├── pwa_scan/                 ← PWA JS
└── platform/                 ← Platform tools

views/
├── products.php
├── pwa_scan_v2.php
└── ...

page/
├── products.php              ← Page definitions
├── pwa_scan_v2.php
└── ...

database/
├── migrations/               ← Core DB
└── tenant_migrations/        ← Tenant DB
    ├── 0001_init_tenant_schema_v2.php
    ├── 0002_seed_data.php
    ├── 2025_12_component_mapping_refactor.php
    ├── 2025_12_product_readiness.php
    └── 2025_12_material_requirement.php
```

---

## Best Practices

### **1. i18n (Internationalization)**
```php
// PHP - Default English, translate to Thai
$message = translate('material.shortage', 'Material shortage');

// JavaScript
const message = t('material.shortage', 'Material shortage');

// ❌ NEVER hardcode Thai in code
// ✅ ALWAYS use translation keys with English defaults
```

### **2. Database Queries**
```php
// ✅ ALWAYS use prepared statements
$stmt = $db->prepare("SELECT * FROM product WHERE id = ?");
$stmt->bind_param('i', $productId);

// ❌ NEVER use string concatenation
$db->query("SELECT * FROM product WHERE id = $productId");
```

### **3. API Responses**
```php
// ✅ Use json_success() and json_error()
json_success(['data' => $result]);
json_error('Error message', 400);

// ❌ NEVER echo json_encode directly
echo json_encode(['success' => true]);
```

### **4. Migrations**
```php
// ✅ Use PHP migrations with helpers
return function(mysqli $db): void {
    migration_add_column_if_missing($db, 'table', 'column', 'definition');
    migration_add_index_if_missing($db, 'table', 'idx_name', 'definition');
};

// ❌ NEVER create .sql files
```

### **5. Frontend**
```javascript
// ✅ Use existing notification helpers
notifySuccess(message, title);
notifyError(message, title);

// ✅ Use SweetAlert2 for dialogs
Swal.fire({ title, icon, showCancelButton: true });

// ❌ NEVER use alert() or confirm()
```

---

## Technical Stack

| Component | Technology | Version |
|-----------|------------|---------|
| **Backend** | PHP | 8.2+ |
| **Database** | MySQL (MAMP) | 5.7+ |
| **Frontend** | jQuery | 3.7.1 |
| **UI Framework** | Bootstrap 5 (Sash) | 5.x |
| **Dropdowns** | Select2 | 4.1.0 |
| **Tables** | DataTables | 2.3.2 |
| **Dialogs** | SweetAlert2 | 11.x |
| **Graphs** | Cytoscape.js | 3.x |
| **Calendar** | FullCalendar | 6.1.10 |
| **Charts** | Chart.js | 4.4.0 |
| **Server** | Apache (MAMP) | - |

---

## Recent Completions (December 2025)

### ✅ **Task 27.20: Work Modal Behavior** (Complete)
- Work Modal Controller with behavior-specific UI
- Integration with Token Card Component
- Dynamic UI panels per node behavior (CUT, STITCH, QC, etc.)
- API integration for data submission
- Results: `docs/super_dag/tasks/archive/results/task27.20_results.md`

### ✅ **Task 27.21.1: Rework Material Reserve Plan** (Complete)
- Material reservation for rework tokens
- Partial reserve handling with shortage detection
- Material logging and audit trail
- Migration: `2025_12_rework_material_logging.php`
- Results: `docs/super_dag/tasks/archive/results/task27.21.1_results.md`

### ✅ **Task 27.22: Token Card Component Refactor** (Complete)
- Single component pattern (TokenCardComponent)
- Modular architecture (State → Parts → Layouts)
- Replaces legacy renderKanbanTokenCard, renderListTokenCard
- Files: `assets/javascripts/pwa_scan/token_card/`

### ✅ **Task 27.22.1: Token Card Logic Issues** (Complete)
- Issue 4: Fixed data-job-id field name
- Issue 3: Timer Data Attributes Contract documented
- Issue 5: renderActionButtons logic verified (7/7 tests passed)
- Issue 2: Material Warning Display for in_progress tokens
- Issue 1: QC Node Business Rule verified (current implementation correct)
- Specs: `docs/super_dag/specs/QC_POLICY_RULES.md`

### ✅ **Task 27.23: Permission Engine Refactor** (Phase 0-4 Complete)
- Centralized permission checks using `ACTION_PERMISSIONS` mapping
- Refactored 7 API files (15+ checks → 1 check per file)
- PermissionEngine service with multi-layer checks
- Phase 5 (Node permission config) deferred

### ✅ **Task 27.24: Work Modal Refactor** (Complete)
- WorkModalController with unified behavior handling
- Integration with Token Card Component

### ✅ **Task 27.25: Permission UI Improvement** (Complete)
- Improved permission error messages
- Better UX for permission-denied scenarios

## Pending / Roadmap

### **Task 27.26: DAG Routing API & JS Refactor** (Planned Q1 2026)
- Refactor `dag_routing_api.php` (7,793 lines, 40 actions)
- Refactor `graph_designer.js` (8,839 lines)
- High risk, deferred to Q1 2026
- Audit: `docs/super_dag/00-audit/20251209_DAG_ROUTING_API_AUDIT.md`

### **Future:**
- Production Stock Dashboard
- Cost calculation from BOM
- Production analytics and reporting
- Operator KPI dashboard

---

## Testing & Quality

```bash
# Run all tests
vendor/bin/phpunit

# Current: 104+ tests passing

# Test coverage targets:
# - Services: 80%+
# - Critical APIs: 70%+
# - Overall: 75%+
```

---

## Deployment & Environment

- **Environment:** macOS (MAMP), PHP 8.2.0
- **Databases:** MySQL (per tenant + core)
- **Cache Management:** PHP OPcache configured for development
- **Browser Cache:** Auto-busting with `?v=filemtime()`

### **Migration Commands:**
```bash
# Core migrations
php source/bootstrap_migrations.php

# Tenant migrations (specific)
php source/bootstrap_migrations.php --tenant=<org_code>

# Check migration status
SELECT * FROM tenant_schema_migrations;
```

---

## Glossary

| Term | Definition |
|------|------------|
| **Platform Owner** | Maintains global tenants, platform roles, uses platform tools |
| **Tenant Owner** | Manages users, inventory, production for a specific org |
| **MO** | Manufacturing Order - production order for finished goods |
| **Job Ticket** | Planned work packet for artisans (Linear routing) |
| **Token** | Work unit in DAG system - represents 1 piece flowing through graph |
| **Anchor Slot** | Placeholder in graph for component (e.g., BODY, STRAP) |
| **Component Mapping** | Links anchor_slot to product_component |
| **Product Readiness** | Validation that product is fully configured |
| **BOM** | Bill of Materials - materials needed for production |
| **MCI** | Missing Component Injection - create missing component tokens |

---

## Contact & Next Steps

- **Current Status:** SuperDAG Complete, Material Backend Complete
- **Next Priorities:** Node Behavior UI, Material Integration UI
- **Documentation:** Keep this file updated as modules evolve

---

**Version:** 3.0 (December 2025)  
**Status:** ✅ Production Ready
