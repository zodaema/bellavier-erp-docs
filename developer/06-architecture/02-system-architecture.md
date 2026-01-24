# 🏗️ Bellavier Group ERP - System Architecture

**Date:** December 2025  
**Version:** 3.1 (SuperDAG + Component Architecture V2 + Material System + UI Refactor)  
**Last Updated:** December 9, 2025

---

## 📊 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER (Browser)                    │
├─────────────────────────────────────────────────────────────┤
│  • jQuery 3.7.1 + AJAX (API Communication)                  │
│  • Bootstrap 5 (UI Framework - Sash Theme)                  │
│  • Select2 (Enhanced Dropdowns)                             │
│  • DataTables (Data Lists)                                  │
│  • SweetAlert2 (Dialogs)                                    │
│  • Cytoscape.js (Graph Designer)                            │
│  • FullCalendar.js (Production Schedule)                    │
│  • Chart.js (Capacity Visualization)                        │
│  • GraphTimezone.js (Timezone normalization)                │
│  • i18n (Translation system: t('key', 'default'))           │
│                                                             │
│  Work Queue UI Components (NEW Dec 9):                      │
│  • TokenCardComponent ⭐ - Single component pattern         │
│    ├─ TokenCardState.js - State computation                 │
│    ├─ TokenCardParts.js - UI parts (buttons, warnings)      │
│    └─ TokenCardLayouts.js - Layouts (kanban/list/mobile)    │
│  • WorkModalController.js ⭐ - Behavior-specific modals      │
│  • BGTimeEngine.js - Timer management                       │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTPS
┌─────────────────────────────────────────────────────────────┐
│                  APPLICATION LAYER (PHP 8.2)                 │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │              BOOTSTRAP LAYERS                         │  │
│  │  • TenantApiBootstrap - Tenant-scoped APIs (40+)      │  │
│  │  • CoreApiBootstrap - Platform/core APIs (12)         │  │
│  │  • Auto tenant resolution & DB connection             │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ENTERPRISE API HELPERS                   │  │
│  │  • RateLimiter - Request throttling                   │  │
│  │  • RequestValidator - Input validation                │  │
│  │  • Idempotency - Duplicate prevention                 │  │
│  │  • ETag/If-Match - Concurrency control                │  │
│  │  • Maintenance Mode - Graceful shutdown               │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ROUTING & SESSION                        │  │
│  │  • index.php - Main router                            │  │
│  │  • memberLogin/memberDetail - Authentication          │  │
│  │  • resolve_current_org() - Tenant context             │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              PERMISSION LAYER                         │  │
│  │  • PermissionHelper (PSR-4) - Authorization           │  │
│  │  • is_platform_administrator() - Platform check       │  │
│  │  • is_tenant_administrator() - Tenant check           │  │
│  │  • Hybrid: Tenant-first, fallback to Core             │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              SERVICE LAYER                            │  │
│  │  Core Services:                                       │  │
│  │  • TokenLifecycleService - Token spawn/move/complete  │  │
│  │  • DAGRoutingService - Split/join/conditional         │  │
│  │  • NodeAssignmentService - Pre-assign, auto-assign    │  │
│  │  • ProductionRulesService - Hatthasilpa/Classic rules │  │
│  │  • ValidationService - Input validation               │  │
│  │  • DatabaseTransaction - Transaction management       │  │
│  │  • PermissionEngine ⭐ (NEW Dec 9) - Token-level perms│  │
│  │                                                       │  │
│  │  Component Services (NEW Dec 2025):                   │  │
│  │  • ComponentMappingService - Graph ↔ Component        │  │
│  │  • ProductReadinessService - Config validation        │  │
│  │                                                       │  │
│  │  Material Services (NEW Dec 2025):                    │  │
│  │  • MaterialRequirementService - BOM calculation       │  │
│  │  • MaterialReservationService - Stock reservation     │  │
│  │  • MaterialAllocationService - Consumption tracking │  │
│  │  • MaterialAllocationService::handleScrapMaterials() ⭐│  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              DAG ENGINE LAYER                         │  │
│  │  Execution:                                           │  │
│  │  • DagExecutionService - Token movement               │  │
│  │  • BehaviorExecutionService - Node behavior           │  │
│  │  • NodeBehaviorEngine - Behavior execution            │  │
│  │  • ParallelMachineCoordinator - Parallel execution    │  │
│  │                                                       │  │
│  │  QC & Rework (NEW Dec 2025):                          │  │
│  │  • QCReworkV2Service - Component-aware rework         │  │
│  │  • DefectCatalogService - Defect management           │  │
│  │                                                       │  │
│  │  Validation & Injection (NEW Dec 2025):               │  │
│  │  • GraphLinterService - 30+ validation rules          │  │
│  │  • ComponentInjectionService - MCI handling           │  │
│  │                                                       │  │
│  │  Self-Healing:                                        │  │
│  │  • LocalRepairEngine - L1 repairs                     │  │
│  │  • TimelineReconstructionEngine - L2/L3 repairs       │  │
│  │                                                       │  │
│  │  Time & ETA:                                          │  │
│  │  • EtaEngine - ETA/SLA calculation                    │  │
│  │  • TimeHelper - Canonical timezone                    │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              HELPER / UTILITY LAYER                   │  │
│  │  • DatabaseHelper - DB operations                     │  │
│  │  • PermissionHelper - Permission checks               │  │
│  │  • BootstrapMigrations - Migration execution          │  │
│  │  • InventoryHelper - Stock operations                 │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓ MySQLi
┌─────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER (MySQL)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │   CORE DATABASE (bgerp) - Shared Platform Data        │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │  • account - Users                                    │  │
│  │  • organization - Tenant registry                     │  │
│  │  • platform_user - Platform administrators            │  │
│  │  • platform_role - Platform roles                     │  │
│  │  • permission - Master permission list                │  │
│  │  • tenant_role_template - Role templates              │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  TENANT DATABASES (bgerp_t_*) - Isolated Org Data     │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │  CORE TABLES:                                         │  │
│  │  • permission, tenant_role                            │  │
│  │  • product, bom, routing, stock                       │  │
│  │  • work_center, machine                               │  │
│  │                                                       │  │
│  │  MANUFACTURING:                                       │  │
│  │  • mo - Manufacturing orders                          │  │
│  │  • atelier_job_ticket - Job tickets (Linear)          │  │
│  │  • atelier_job_task, atelier_wip_log                  │  │
│  │  • atelier_task_operator_session                      │  │
│  │                                                       │  │
│  │  DAG ROUTING:                                         │  │
│  │  • routing_graph, routing_node, routing_edge          │  │
│  │  • job_graph_instance, node_instance                  │  │
│  │  • flow_token, token_event                            │  │
│  │  • token_work_session, token_repair_log               │  │
│  │                                                       │  │
│  │  COMPONENT ARCHITECTURE V2 (NEW Dec 2025):            │  │
│  │  • component_type_catalog (24 types)                  │  │
│  │  • product_component                                  │  │
│  │  • product_component_material                         │  │
│  │  • graph_component_mapping                            │  │
│  │                                                       │  │
│  │  QC & DEFECT (NEW Dec 2025):                          │  │
│  │  • defect_category (8 categories)                     │  │
│  │  • defect_catalog (36 defects)                        │  │
│  │  • qc_rework_override_log                             │  │
│  │                                                       │  │
│  │  MATERIAL SYSTEM (NEW Dec 2025):                      │  │
│  │  • material_requirement                               │  │
│  │  • material_reservation                               │  │
│  │  • material_allocation                                │  │
│  │  • material_requirement_log ⭐ (NEW Dec 9: rework events)│  │
│  │    └─ Event types: rework_reserve, material_returned_  │  │
│  │       scrap, material_wasted_scrap                    │  │
│  │  • v_material_available (VIEW)                        │  │
│  │  • v_job_material_status (VIEW)                       │  │
│  │                                                       │  │
│  │  AUDIT:                                               │  │
│  │  • product_config_log                                 │  │
│  │  • component_injection_log                            │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Permission Architecture

### **Hybrid Model: Tenant-Isolated with Core Fallback + Token-Level Engine**

```
User Request
    ↓
1. Check Platform Role
    ├─ is_platform_administrator()
    │   └─ Query: platform_user + platform_role
    │       ├─ TRUE → Grant ALL access
    │       └─ FALSE → Continue
    ↓
2. Check Tenant Role (Priority)
    ├─ tenant_permission_allow_code()
    │   └─ Query: tenant_role + tenant_role_permission (Tenant DB)
    │       ├─ TRUE → Grant access
    │       ├─ FALSE → Deny access
    │       └─ NULL (not active) → Fallback to #3
    ↓
3. Fallback: Core Permission (Legacy)
    └─ permission_allow()
        └─ Query: permission_allow (Core DB)
            ├─ TRUE → Grant access
            └─ FALSE → Deny access
    ↓
4. Token-Level Permission (NEW Dec 9) ⭐
    └─ PermissionEngine::canActOnToken()
        ├─ Layer 1: Role Permission (via PermissionHelper)
        ├─ Layer 2: Assignment Method (strict, auto, pin, help)
        ├─ Layer 3: Node Config (QC self-pick, self-QC)
        └─ Layer 4: Token Type (replacement, rework, split)
```

### **PermissionEngine Service (NEW Dec 9)**

**Purpose:** Token-level permission checks for Work Queue operations

**Key Methods:**
- `canActOnToken()` - Main permission check
- `canStartToken()` - Start permission
- `canPauseToken()` - Pause permission
- `canCompleteToken()` - Complete permission
- `canQCToken()` - QC permission (self-QC rules)

**Integration:**
- Used by `dag_token_api.php` for action validation
- Supports ACTION_PERMISSIONS pattern (Task 27.23)

---

## 📦 Component Architecture V2

### **3-Layer Model:**

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: component_type_catalog (Generic Types)            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ MAIN: BODY, FLAP, POCKET, GUSSET, BASE, DIVIDER, FRAME  ││
│  │ ACCESSORY: STRAP, HANDLE, ZIPPER_PANEL, ZIP_POCKET, LOOP││
│  │ INTERIOR: LINING, INTERIOR_PANEL, CARD_SLOT_PANEL       ││
│  │ REINFORCEMENT: REINFORCEMENT, PADDING, BACKING          ││
│  │ DECORATIVE: LOGO_PATCH, DECOR_PANEL, BADGE              ││
│  └─────────────────────────────────────────────────────────┘│
│                            ↓                                 │
│  LAYER 2: product_component (Product-Specific)              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Example: Product "Aimee Mini Green Tea"                 ││
│  │ ├─ AimeeMini_BODY (type: BODY)                          ││
│  │ ├─ AimeeMini_FLAP (type: FLAP)                          ││
│  │ └─ AimeeMini_STRAP_LONG (type: STRAP)                   ││
│  └─────────────────────────────────────────────────────────┘│
│                            ↓                                 │
│  LAYER 3: product_component_material (BOM)                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ AimeeMini_BODY:                                         ││
│  │ ├─ Leather Green Tea: 2.5 sq.ft × 1.05 waste            ││
│  │ ├─ Lining Cotton: 1.0 sq.ft                             ││
│  │ └─ Thread Gold: 10 m                                    ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### **Graph Mapping:**

```
routing_node.anchor_slot          graph_component_mapping
┌─────────────────────┐           ┌─────────────────────────┐
│ anchor_slot: BODY   │──────────▶│ id_product_component: 42│
│ anchor_slot: FLAP   │──────────▶│ id_product_component: 43│
│ anchor_slot: STRAP  │──────────▶│ id_product_component: 44│
└─────────────────────┘           └─────────────────────────┘
                                            │
                                            ▼
                                  product_component
                                  ┌─────────────────────────┐
                                  │ AimeeMini_BODY (id: 42) │
                                  │ AimeeMini_FLAP (id: 43) │
                                  │ AimeeMini_STRAP (id: 44)│
                                  └─────────────────────────┘
```

---

## 🧮 Material System Architecture

### **Data Flow:**

```
Job Creation
    ↓
┌────────────────────────────────────────────────────────────┐
│ MaterialRequirementService.calculateForJob()               │
│ ├─ Read graph_component_mapping for product                │
│ ├─ For each mapping → product_component                    │
│ ├─ For each component → product_component_material (BOM)   │
│ └─ Calculate: material × qty_target × waste_factor         │
└────────────────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────────────────┐
│ MaterialReservationService.reserveForJob()                 │
│ ├─ Check: on_hand - reserved = available                   │
│ ├─ If available >= required → CREATE reservation           │
│ └─ If available < required → partial or pending_materials  │
└────────────────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────────────────┐
│ Job Execution (Token Flow)                                 │
│ ├─ Token arrives at CUT node                               │
│ ├─ MaterialAllocationService.allocateToToken()             │
│ └─ Convert reservation → allocation                        │
└────────────────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────────────────┐
│ Token Completes                                            │
│ ├─ MaterialAllocationService.consumeMaterial()             │
│ ├─ Update: actual_qty, consumed_at                         │
│ └─ Log waste/scrap if applicable                           │
└────────────────────────────────────────────────────────────┘
```

### **Key Formulas:**

```
available_for_new_jobs = on_hand - reserved

required_qty = BOM_qty × job_qty × waste_factor

shortage = MAX(0, required_qty - available_for_new_jobs)
```

---

## ✅ Product Readiness System

### **Validation Flow:**

```
ProductReadinessService.getProductReadiness($productId)
    ↓
┌────────────────────────────────────────────────────────────┐
│ For Hatthasilpa Products:                                  │
│ ├─ ✓ has_production_line (must be 'hatthasilpa')           │
│ ├─ ✓ has_graph_binding                                     │
│ ├─ ✓ graph_is_published                                    │
│ ├─ ✓ graph_has_start_node                                  │
│ ├─ ✓ has_components (at least 1)                           │
│ ├─ ✓ components_have_materials (each has BOM)              │
│ └─ ✓ mapping_complete (all anchor_slots mapped)            │
└────────────────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────────────────┐
│ For Classic Products:                                      │
│ ├─ ✓ has_production_line (must be 'classic')               │
│ ├─ ✓ has_components (at least 1)                           │
│ └─ ✓ components_have_materials (each has BOM)              │
└────────────────────────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────────────────────────┐
│ Result:                                                    │
│ ├─ is_ready: true/false                                    │
│ ├─ checks: { ... detailed check results ... }              │
│ └─ missing: ['mapping_complete', ...]                      │
└────────────────────────────────────────────────────────────┘
```

### **UI Integration:**

```javascript
// Product List - Ready badge
if (product.is_ready) {
    return '<i class="fe fe-check-circle text-success"></i>';
} else {
    return ''; // No badge
}

// Job Creation - Block non-ready
if (!product.is_ready) {
    option.disabled = true;
    option.text += ' (รอตั้งค่า)';
}
```

---

## 🔧 Key Design Patterns

### **1. Service Layer Pattern**
```php
// All business logic in services
class MaterialRequirementService {
    public function calculateForJob(int $jobId, int $productId, int $qtyTarget): array;
    public function checkStockAvailability(int $productId, int $qtyTarget): array;
    public function recalculateRequirements(int $jobId): void;
}
```

### **2. Factory Pattern** (CapacityCalculator)
```php
CapacityCalculatorFactory::create($db, $mode);
// → SimpleCapacityCalculator | WorkCenterCapacityCalculator
```

### **3. Strategy Pattern** (Permission)
```php
// Try tenant system first, fallback to legacy
$result = tenant_permission_allow_code();
if ($result === null) {
    $result = permission_allow();
}
```

### **4. Event Sourcing** (Token Events)
```php
// All token state changes logged as events
INSERT INTO token_event (id_token, event_type, event_data, ...)
// State reconstructable from event history
```

---

## 🎯 Technology Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Frontend** | jQuery | 3.7.1 | AJAX & DOM |
| **Frontend** | Bootstrap | 5.x (Sash) | UI framework |
| **Frontend** | Select2 | 4.1.0 | Enhanced dropdowns |
| **Frontend** | DataTables | 2.3.2 | Data tables |
| **Frontend** | SweetAlert2 | 11.x | Dialogs |
| **Frontend** | Cytoscape.js | 3.x | Graph designer |
| **Frontend** | FullCalendar | 6.1.10 | Calendar |
| **Frontend** | Chart.js | 4.4.0 | Charts |
| **Backend** | PHP | 8.2+ | Application logic |
| **Backend** | MySQLi | - | Database driver |
| **Database** | MySQL | 5.7+ | Data persistence |
| **Server** | Apache (MAMP) | - | Web server |

---

## 🚀 Scalability

| Metric | Current | Phase 2 | Phase 3 |
|--------|---------|---------|---------|
| **Tenants** | 2 | 10 | 50+ |
| **Users/Tenant** | 5-10 | 20-50 | 100+ |
| **MO/Day** | 5-10 | 20-50 | 100+ |
| **Tokens/Day** | 50-100 | 200-500 | 1000+ |
| **Concurrent Users** | 2-3 | 10-15 | 50+ |

**Optimizations:**
- ✅ Indexed queries (id, code, dates, status)
- ✅ Prepared statements (SQL injection prevention)
- ✅ Minimal JOINs (optimized queries)
- ✅ Views for complex aggregations
- 🔄 Future: Redis cache for permissions
- 🔄 Future: Read replicas for reports

---

## 📝 Summary

**Architecture Type:** Monolithic (Multi-Tenant) with DAG Execution Engine

**Database Strategy:** Tenant-per-Database (Isolated)

**Permission Model:** Hybrid (Tenant-first, Core fallback)

**Production Model:** Dual-Mode (Hatthasilpa/DAG + Classic/Linear)

**Key Components:**
- ✅ Bootstrap Layers (TenantApiBootstrap, CoreApiBootstrap)
- ✅ DAG Engine (Token-based routing, parallel execution)
- ✅ Component Architecture V2 (3-layer model)
- ✅ Material System (Requirement, Reservation, Allocation)
- ✅ Product Readiness (Configuration validation)
- ✅ Self-Healing (LocalRepairEngine, TimelineReconstruction)
- ✅ QC Rework V2 (Component-aware, defect-based)
- ✅ Graph Linter (30+ validation rules)

**Status:** ✅ **Production Ready** (100% enterprise-compliant, 104+ tests)
