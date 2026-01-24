# Bellavier ERP - Current System State

> **Last Updated:** 2025-12-09  
> **Version:** SuperDAG 2.0 + Component Architecture V2  
> **Status:** Production Ready (Core Features Complete)

---

## 📊 Executive Summary

```
┌─────────────────────────────────────────────────────────────────┐
│              BELLAVIER ERP - CURRENT SYSTEM STATE               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CORE SYSTEMS                                                   │
│  ├─ DAG Routing Engine          ✅ Production Ready             │
│  ├─ Token Lifecycle             ✅ Production Ready             │
│  ├─ Component Architecture V2   ✅ Complete                     │
│  ├─ QC Rework V2                ✅ Complete                     │
│  ├─ Graph Linter               ✅ Complete                      │
│  ├─ MCI (Missing Component)     ✅ Complete                     │
│  ├─ Material Requirement        ✅ Backend Complete             │
│  └─ Product Readiness           ✅ Complete                     │
│                                                                 │
│  PRODUCTION MODES                                               │
│  ├─ Hatthasilpa (DAG-based)     ✅ Full Feature                 │
│  └─ Classic (Linear)            ✅ Full Feature                 │
│                                                                 │
│  UI SYSTEMS                                                     │
│  ├─ Graph Designer              ✅ Complete                     │
│  ├─ Work Queue / PWA            ✅ Complete                     │
│  ├─ Product Configuration       ✅ Complete                     │
│  └─ Admin Panels                ✅ Complete                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗃️ Database Architecture

### Component Architecture (3-Layer Model)

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPONENT ARCHITECTURE V2                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 1: Component Types (Global Catalog)                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  component_type_catalog (24 Bellavier Master Types)     │    │
│  │  ├─ MAIN: BODY, FLAP, POCKET, GUSSET, BASE, DIVIDER,   │    │
│  │  │        FRAME, PANEL                                  │    │
│  │  ├─ ACCESSORY: STRAP, HANDLE, ZIPPER_PANEL, ZIP_POCKET,│    │
│  │  │             LOOP, TONGUE, CLOSURE_TAB               │    │
│  │  ├─ INTERIOR: LINING, INTERIOR_PANEL, CARD_SLOT_PANEL  │    │
│  │  ├─ REINFORCEMENT: REINFORCEMENT, PADDING, BACKING     │    │
│  │  └─ DECORATIVE: LOGO_PATCH, DECOR_PANEL, BADGE         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           ↓                                     │
│  Layer 2: Product Components (Per Product)                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  product_component                                       │    │
│  │  ├─ id_product (FK → product)                           │    │
│  │  ├─ component_type_code (FK → component_type_catalog)   │    │
│  │  ├─ component_code (unique per product)                 │    │
│  │  ├─ component_name                                      │    │
│  │  └─ physical specs (dimensions, color, etc.)            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           ↓                                     │
│  Layer 3: BOM (Materials per Component)                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  product_component_material                              │    │
│  │  ├─ id_product_component (FK)                           │    │
│  │  ├─ material_sku (FK → material)                        │    │
│  │  ├─ qty_per_component                                   │    │
│  │  └─ uom_code                                            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### DAG Core Tables

| Table | Purpose |
|-------|---------|
| `routing_graph` | Graph definitions (templates) |
| `routing_node` | Nodes with behaviors (operation, qc, split, merge) |
| `routing_edge` | Edges with conditions |
| `job_graph_instance` | Active job instances |
| `node_instance` | Active node instances |
| `flow_token` | Token state machine |
| `token_event` | Canonical event log |

### Quality Control Tables

| Table | Purpose |
|-------|---------|
| `defect_category` | 8 defect categories |
| `defect_catalog` | 36 defect definitions |
| `qc_rework_override_log` | Supervisor override audit |

### Material Requirement Tables

| Table | Purpose |
|-------|---------|
| `material_requirement` | Calculated requirements per job |
| `material_reservation` | Soft-lock on inventory |
| `material_allocation` | Token-to-material hard link |
| `material_requirement_log` | Audit trail |

### Mapping Tables

| Table | Purpose |
|-------|---------|
| `graph_component_mapping` | Anchor slot → Product component mapping |
| `component_injection_log` | MCI audit log |

---

## 🔧 Service Architecture

### DAG Engine Services

| Service | Purpose |
|---------|---------|
| `DAGRoutingService` | Core routing, token movement |
| `TokenLifecycleService` | Spawn, complete, scrap tokens |
| `NodeBehaviorEngine` | Execute node behaviors |
| `BehaviorExecutionService` | Behavior dispatch |
| `ParallelMachineCoordinator` | Handle parallel splits/merges |
| `GraphValidationEngine` | Validate graph structure |
| `GraphLinterService` | Lint rules (S, C, Q, B) |

### Component Services

| Service | Purpose |
|---------|---------|
| `ComponentTypeService` | Layer 1 CRUD |
| `ProductComponentService` | Layer 2 + 3 CRUD |
| `ComponentMappingService` | Graph anchor → component mapping |
| `ComponentInjectionService` | MCI - inject missing components |
| `ComponentFlowService` | Component token tracking |

### Quality Control Services

| Service | Purpose |
|---------|---------|
| `DefectCatalogService` | Defect CRUD + suggestions |
| `QCReworkService` | Rework target calculation |

### Material Services

| Service | Purpose |
|---------|---------|
| `MaterialRequirementService` | Calculate BOM requirements |
| `MaterialReservationService` | Reserve inventory (FIFO) |
| `MaterialAllocationService` | Allocate to tokens |

### Product Services

| Service | Purpose |
|---------|---------|
| `ProductReadinessService` | Calculate config completeness |
| `ProductDependencyScanner` | Check product dependencies |

---

## 📡 API Endpoints

### Product API (`source/product_api.php`)

| Action | Purpose |
|--------|---------|
| `get_component_types` | Layer 1 types |
| `get_product_components` | Layer 2 per product |
| `create_component`, `update_component`, `delete_component` | CRUD |
| `add_component_material`, `update_component_material`, `remove_component_material` | BOM CRUD |
| `get_component_mappings_v2`, `save_component_mapping_v2` | Mapping CRUD |
| `get_product_readiness` | Readiness check |

### Defect Catalog API (`source/defect_catalog_api.php`)

| Action | Purpose |
|--------|---------|
| `list`, `get`, `create`, `update`, `delete` | CRUD |
| `categories`, `for_component_type` | Filtering |
| `suggest_rework` | Rework suggestions |

### Material Requirement API (`source/material_requirement_api.php`)

| Action | Purpose |
|--------|---------|
| `calculate_requirements` | Calculate from BOM |
| `get_requirements` | Get requirements list |
| `check_availability` | Stock availability |
| `create_reservations`, `release_reservations` | Reservation management |
| `get_job_material_summary` | Summary |

### Graph Actions API (`source/graph_actions_api.php`)

| Action | Purpose |
|--------|---------|
| Token spawn, move, complete | Core operations |
| QC pass/fail | Quality control |
| Graph instance management | Job graph lifecycle |

---

## 🎨 UI Components

### Product Configuration

| Tab | Purpose |
|-----|---------|
| **General** | Basic product info |
| **Components** | Layer 2 + Layer 3 (BOM) management |
| **Component Mapping** | Anchor slot → component (Hatthasilpa only) |
| **Graph Binding** | Link product to graph |
| **Assets** | Product images |

### Graph Designer

| Feature | Status |
|---------|--------|
| Node palette (operation, qc, split, merge, component) | ✅ |
| Edge conditions | ✅ |
| Behavior assignment | ✅ |
| Validation/Linting | ✅ |
| Publish workflow | ✅ |

### Admin Panels

| Panel | Purpose |
|-------|---------|
| Defect Catalog | Manage defects |
| Component Types | View Layer 1 catalog |
| Work Centers | Work center management |

---

## 🔒 Product Readiness System

### Readiness Criteria

| Production Line | Requirements |
|-----------------|--------------|
| **Hatthasilpa** | Production Line + Graph Binding (active, published, has START) + Components (at least 1) + Materials (all components have materials) + Component Mapping (all anchor slots mapped) |
| **Classic** | Production Line + Components (at least 1) + Materials (all components have materials) |

### Readiness UI

- **Product List:** ✓ badge for ready products
- **Job Creation:** Non-ready products disabled with "(รอตั้งค่า)"
- **Classic Products:** Component Mapping tab hidden

---

## 📁 Key File Locations

### Backend (PHP)

```
source/
├─ BGERP/
│  ├─ Service/
│  │  ├─ MaterialRequirementService.php
│  │  ├─ MaterialReservationService.php
│  │  ├─ MaterialAllocationService.php
│  │  ├─ ProductReadinessService.php
│  │  ├─ ComponentMappingService.php
│  │  ├─ ComponentTypeService.php
│  │  ├─ ProductComponentService.php
│  │  ├─ DefectCatalogService.php
│  │  ├─ DAGRoutingService.php
│  │  ├─ TokenLifecycleService.php
│  │  └─ ...
│  └─ Dag/
│     ├─ ComponentInjectionService.php
│     ├─ GraphLinterService.php
│     └─ ...
├─ product_api.php
├─ defect_catalog_api.php
├─ material_requirement_api.php
└─ graph_actions_api.php
```

### Frontend (JS)

```
assets/javascripts/
├─ products/
│  ├─ products.js
│  ├─ product_components.js
│  └─ product_graph_binding.js
├─ graph_designer/
│  └─ graph_designer.js
└─ defect/
   └─ defect_selector.js
```

### Migrations

```
database/tenant_migrations/
├─ 0001_init_tenant_schema_v2.php (Main schema)
├─ 0002_seed_data.php (Seed data)
├─ 2025_12_component_mapping_refactor.php
├─ 2025_12_material_requirement.php
└─ 2025_12_product_readiness.php
```

---

## 🚀 Next Steps (Future)

1. **27.18 UI** - Material requirements panel in job detail
2. **27.20** - Skill & Material Tolerance (when worker system ready)
3. **Reporting** - Advanced analytics dashboard
4. **Mobile PWA** - Enhanced scan station features

---

## 📚 Related Documentation

| Document | Location |
|----------|----------|
| Master Roadmap | `docs/super_dag/tasks/MASTER_IMPLEMENTATION_ROADMAP.md` |
| Component Architecture | `docs/super_dag/01-concepts/PRODUCT_COMPONENT_ARCHITECTURE.md` |
| QC Rework Philosophy | `docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md` |
| Graph Linter Rules | `docs/super_dag/01-concepts/GRAPH_LINTER_RULES.md` |
| MCI Spec | `docs/super_dag/01-concepts/MISSING_COMPONENT_INJECTION_SPEC.md` |
| Defect Catalog Spec | `docs/super_dag/01-concepts/DEFECT_CATALOG_SPEC.md` |

