# Master Implementation Roadmap

> **Bellavier ERP - Enterprise Standards Implementation**

> **Last Updated:** 2025-12-06  
> **Total Duration:** 7 Weeks (Completed + Extensions)  
> **Priority:** 🔴 HIGH (Production Foundation)  
> **Status:** ✅ **ALL PHASES COMPLETE** (Dec 6, 2025)

---

## 📊 Executive Summary

```
┌─────────────────────────────────────────────────────────────────┐
│              IMPLEMENTATION PHASES - ALL COMPLETE ✅             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PHASE A: Foundation Layer (Week 1-2)   ✅ COMPLETE (Dec 5)    │
│  ├─ 27.12  Component Catalog            ✅ DONE                 │
│  ├─ 27.13  Component Node Type          ✅ DONE                 │
│  └─ 27.13.11b Material Architecture V2  ✅ DONE                 │
│                                                                 │
│  PHASE B: Quality Layer (Week 3-4)      ✅ COMPLETE (Dec 6)    │
│  ├─ 27.14  Defect Catalog               ✅ DONE                 │
│  └─ 27.15  QC Rework V2                 ✅ DONE                 │
│                                                                 │
│  PHASE C: Validation Layer (Week 5-6)   ✅ COMPLETE (Dec 6)    │
│  └─ 27.16  Graph Linter Rules           ✅ DONE                 │
│                                                                 │
│  PHASE D: Safety Net (Week 3-4)         ✅ COMPLETE (Dec 6)    │
│  └─ 27.17  MCI                          ✅ DONE                 │
│                                                                 │
│  PHASE E: Inventory Integration (Week 7) ✅ COMPLETE (Dec 6)   │
│  └─ 27.18  Material Requirement          ✅ DONE (Backend)      │
│                                                                 │
│  EXTENSIONS (Added During Implementation)                       │
│  ├─ 27.13.12 Component Mapping Refactor  ✅ DONE                │
│  └─ 27.19    Product Readiness System    ✅ DONE                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Dependency Graph (CORRECTED)

```
                    ┌────────────────────────────────────┐
                    │            PHASE A                 │
                    │         FOUNDATION                 │
                    │          Week 1-2                  │
                    └──────────────┬─────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    │                    ▼
    ┌──────────────────┐           │          ┌──────────────────┐
    │  27.12           │           │          │  27.13           │
    │  Component       │           │          │  Component       │
    │  Catalog         │◄──────────┘          │  Node Type       │
    │  ⭐ START HERE   │                      │  (depends 27.12) │
    └────────┬─────────┘                      └────────┬─────────┘
             │                                         │
             │  ┌──────────────────────────────────────┤
             │  │                                      │
             │  │  ┌───────────────────────────────────┤
             │  │  │                                   │
             ▼  ▼  ▼                                   ▼
    ┌─────────────────────────────────┐     ┌──────────────────┐
    │     PHASE B: QUALITY            │     │  PHASE D         │
    │        Week 3-4                 │     │  MCI             │
    │  ┌─────────────────────────┐    │     │  Week 3-4        │
    │  │  27.14 Defect Catalog   │    │     │  ────────────    │
    │  └───────────┬─────────────┘    │     │  27.17 MCI       │
    │              │                  │     │  ✅ CAN START    │
    │              ▼                  │     │  AFTER 27.13!    │
    │  ┌─────────────────────────┐    │     └────────┬─────────┘
    │  │  27.15 QC Rework V2     │    │              │
    │  │  (depends 27.13 + 27.14)│    │              │
    │  └───────────┬─────────────┘    │              │
    └──────────────┼──────────────────┘              │
                   │                                 │
                   └───────────────┬─────────────────┘
                                   ▼
                    ┌──────────────────────────────────┐
                    │          PHASE C                 │
                    │        VALIDATION                │
                    │          Week 5-6                │
                    │  ┌────────────────────────────┐  │
                    │  │  27.16 Graph Linter        │  │
                    │  │  (depends 27.13 + 27.15)   │  │
                    │  └────────────────────────────┘  │
                    └──────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │          PHASE E                 │
                    │         ADVANCED                 │
                    │          Future                  │
                    │  ┌────────────────────────────┐  │
                    │  │  27.18 Material Req/Res    │  │
                    │  │  📦 Inventory Integration  │  │
                    │  └────────────────────────────┘  │
                    └──────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │          PHASE F                 │
                    │         ADVANCED                 │
                    │          Future                  │
                    │  ┌────────────────────────────┐  │
                    │  │  27.19 Skill & Material    │  │
                    │  │  🔮 FUTURE PHASE           │  │
                    │  └────────────────────────────┘  │
                    └──────────────────────────────────┘
```

---

## ⚠️ Infrastructure Gaps (Must Create)

```
┌─────────────────────────────────────────────────────────────────┐
│              CURRENT INFRASTRUCTURE STATUS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ MISSING (Must Create):                                      │
│  ────────────────────────────────────────────────────────       │
│  1. component_catalog table (not exists)                        │
│  2. routing_node.anchor_slot column (not exists)                │
│     ⚠️ Use anchor_slot, NOT component_code!                     │
│  3. graph_component_mapping table (for slot → code mapping)     │
│  4. node_type = 'component' in ENUM                             │
│     (current: start,operation,split,join,decision,end)          │
│                                                                 │
│  ✅ EXISTING (Ready to Use):                                    │
│  ────────────────────────────────────────────────────────       │
│  1. flow_token.token_type = 'component' ✅                      │
│  2. ComponentFlowService (uses component_code from metadata) ✅  │
│  3. ParallelMachineCoordinator ✅                               │
│  4. BehaviorExecutionService with component hooks ✅            │
│                                                                 │
│  📋 KEY ARCHITECTURE DECISION:                                  │
│  ────────────────────────────────────────────────────────       │
│  • Graph Designer uses anchor_slot (placeholder)                │
│  • Mapping layer resolves slot → component_code                 │
│  • Token stores resolved component_code in metadata             │
│  • This keeps Graph Designer "neutral" (no config editing)      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Phase Details

---

## PHASE A: Foundation Layer ✅ COMPLETE

> **Duration:** Week 1-2 (~50 hours)  
> **Priority:** 🔴 CRITICAL - Everything depends on this  
> **Status:** ✅ **COMPLETE** (December 5, 2025)

---

### 27.12 Component Catalog ✅ COMPLETE

**Spec:** `01-concepts/COMPONENT_CATALOG_SPEC.md`

**Completed:**
- ✅ `component_catalog` table (35 LEGACY entries)
- ✅ `component_type_catalog` table (24 Bellavier Master types)
- ✅ `product_component_mapping` table (LEGACY)
- ✅ All tables consolidated into `0001_init_tenant_schema_v2.php`
- ✅ Seed data consolidated into `0002_seed_data.php`

---

### 27.13 Component Node Type ✅ COMPLETE

**Completed:**
- ✅ `routing_node.anchor_slot` column added
- ✅ `graph_component_mapping` table created
- ✅ `node_type` ENUM extended with 'component'

---

### 27.13.11b Material Architecture V2 ✅ COMPLETE

**New 3-Layer System:**
- ✅ **Layer 1:** `component_type_catalog` (24 types)
- ✅ **Layer 2:** `product_component` (physical specs per product)
- ✅ **Layer 3:** `product_component_material` (BOM per component)

**Services:**
- ✅ `ComponentTypeService.php` - Layer 1 management
- ✅ `ProductComponentService.php` - Layer 2 + 3 management

**API (11 endpoints in product_api.php):**
- ✅ `get_component_types`, `get_product_components`, `get_component`
- ✅ `create_component`, `update_component`, `delete_component`
- ✅ `add_component_material`, `update_component_material`, `remove_component_material`
- ✅ `get_materials_dropdown`, `get_uom_dropdown`

**UI:**
- ✅ Product Modal → Components Tab
- ✅ Add/Edit Component modal with Select2 material search
- ✅ Materials summary table

**Deliverables - ALL COMPLETE:**
- [x] `component_type_catalog` with 24 Bellavier Master types
- [x] `product_component` table for physical specs
- [x] `product_component_material` table for BOM
- [x] Services with full CRUD
- [x] 11 API endpoints
- [x] Components Tab UI with Select2
- [x] Migration consolidation (100% schema match)

---

### 27.13 Component Node Type (Anchor Model)

**Spec:** `01-concepts/QC_REWORK_PHILOSOPHY_V2.md` (Section: Component Anchor Model)

**Dependencies:** 27.12 (Component Catalog)

**Why Second?**
- QC Rework V2 needs component anchors
- Graph Linter validates component nodes
- MCI uses component context

**Architecture Decision: Anchor Model**

```
┌─────────────────────────────────────────────────────────────────┐
│              ANCHOR MODEL (NOT Direct Binding)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Graph Designer:                                                │
│  ├─ node_type = 'component'                                     │
│  ├─ anchor_slot = 'SLOT_A' (placeholder, NOT component_code)   │
│  └─ NO catalog selection in Graph Designer!                    │
│                                                                 │
│  Product Config / Graph Instance:                               │
│  └─ graph_component_mapping.slot → component_code               │
│                                                                 │
│  Runtime (Token):                                               │
│  └─ token.metadata.component_code = resolved from mapping       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Database Migration Required:**

```sql
-- Modify routing_node ENUM
ALTER TABLE routing_node 
  MODIFY COLUMN node_type ENUM('start','operation','split','join','decision','end','component','router') 
  NOT NULL COMMENT 'Node types including component anchor';

-- Add anchor_slot column (NOT component_code!)
ALTER TABLE routing_node 
  ADD COLUMN anchor_slot VARCHAR(50) NULL 
  COMMENT 'Anchor slot for component nodes (e.g., SLOT_A, SLOT_B)';

ALTER TABLE routing_node 
  ADD INDEX idx_anchor_slot (anchor_slot);

-- Mapping table: slot → component_code
CREATE TABLE graph_component_mapping (
    id INT AUTO_INCREMENT PRIMARY KEY,
    graph_id INT NOT NULL,
    anchor_slot VARCHAR(50) NOT NULL,
    component_code VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_graph_slot (graph_id, anchor_slot),
    FOREIGN KEY (graph_id) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (component_code) REFERENCES component_catalog(component_code)
);
```

**Tasks:**

| Task | Description | Est. Hours |
|------|-------------|------------|
| 27.13.1 | Database: Migration to extend `node_type` ENUM | 2h |
| 27.13.2 | Database: Add `anchor_slot` column to `routing_node` | 1h |
| 27.13.3 | Database: Create `graph_component_mapping` table | 2h |
| 27.13.4 | Service: `findComponentAnchor()` in DAGRoutingService | 3h |
| 27.13.5 | Service: `getNodesInComponent()` for rework targets | 3h |
| 27.13.6 | Service: `resolveComponentCode()` from mapping | 2h |
| 27.13.7 | Graph Designer: Component Node palette item | 4h |
| 27.13.8 | Graph Designer: Anchor slot input (generic, NOT catalog dropdown) | 2h |
| 27.13.9 | Graph Designer: Visual styling for component nodes | 2h |
| 27.13.10 | Product Config UI: Mapping anchor_slot → component_code | 4h |
| 27.13.11 | Validation: Component node cannot have work_center | 2h |
| 27.13.12 | Tests: Unit + Integration | 4h |

**Total:** ~31 hours (~4 days)

**Deliverables:**
- [ ] `node_type='component'` supported in schema
- [ ] `anchor_slot` column in `routing_node`
- [ ] `graph_component_mapping` table for slot → code mapping
- [ ] Graph Designer creates component nodes with anchor_slot (NOT catalog dropdown)
- [ ] Product Config UI maps slots to catalog components
- [ ] `findComponentAnchor()` works for any node in graph
- [ ] `resolveComponentCode()` resolves slot → code at runtime

---

## PHASE B + D: Quality Layer + MCI (PARALLEL!)

> **Duration:** Week 3-4  
> **Priority:** 🟠 HIGH - Core functionality  
> **Strategy:** Run in parallel tracks!
> **Status:** 🟡 **IN PROGRESS** - 27.14 Complete, 27.15 & 27.17 Ready

```
┌─────────────────────────────────────────────────────────────────┐
│              WEEK 3-4: PARALLEL EXECUTION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TRACK 1: Quality (Developer A)       TRACK 2: MCI (Dev B)     │
│  ─────────────────────────────        ────────────────────     │
│  27.14 Defect Catalog (~35h)          27.17 MCI (~50h)          │
│  27.15 QC Rework V2   (~38h)                                    │
│                                                                 │
│  Total: ~73h                          Total: ~50h               │
│                                                                 │
│  ⚠️ Note: 27.15 needs 27.14 first    No dependency on Track 1! │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 27.14 Defect Catalog (Track 1) ✅ COMPLETE

**Spec:** `01-concepts/DEFECT_CATALOG_SPEC.md`

**Dependencies:** 27.12 (Component Catalog for `allowed_component_types`)

**Status:** ✅ **COMPLETE** (December 6, 2025)

**Completed:**
- ✅ `defect_category` table (8 categories)
- ✅ `defect_catalog` table (36 defects)
- ✅ `DefectCatalogService.php` - CRUD + filtering + suggestions
- ✅ `defect_catalog_api.php` - 10 API endpoints
- ✅ Admin UI (`page/defect_catalog.php`, `views/defect_catalog.php`)
- ✅ QC Component (`defect_selector.js`)
- ✅ Sidebar menu integration
- ✅ Unit tests (20 tests, 75 assertions)
- ✅ API documentation (`docs/API_DEFECT_CATALOG.md`)

**API Endpoints:**
- `list`, `get`, `create`, `update`, `delete`, `reactivate`
- `categories`, `for_component_type`, `component_types`
- `statistics`, `suggest_rework`

**Total:** ~35 hours → ✅ Completed

---

### 27.15 QC Rework V2 (Track 1) ✅ COMPLETE

**Status:** ✅ **COMPLETE** (Dec 6, 2025)  
**Spec:** `01-concepts/QC_REWORK_PHILOSOPHY_V2.md`  
**Implementation:** `tasks/task27.15_QC_REWORK_V2_PLAN.md` → See Results Section

**Dependencies:** 
- 27.13 (Component Node for anchor) ✅
- 27.14 (Defect Catalog for suggestions) ✅

**Tasks:**

| Task | Description | Status |
|------|-------------|--------|
| 27.15.1 | Service: `getReworkTargetsForQC()` V2 + `getDefectSuggestionPriority()` | ✅ |
| 27.15.2 | Service: `isValidReworkTarget()` + same-component enforcement | ✅ |
| 27.15.3 | API: `get_rework_targets` + `validate_rework_target` endpoints | ✅ |
| 27.15.4 | QC Behavior: `handleQCFailV2()` with target selection | ✅ |
| 27.15.5-6 | QC UI: `qc_rework_v2.js` modal with defect suggestions | ✅ |
| 27.15.7 | Routing: `moveTokenToNode()` with canonical events | ✅ |
| 27.15.8 | Safety: Supervisor PIN, max rework count, audit log | ✅ |
| 27.15.9 | Migration: `qc_rework_override_log` table | ✅ |

**CTO Audit Fixes (All Applied):**
1. ✅ UI wording: "เลือกขั้นตอนที่ต้องแก้ไข"
2. ✅ Same-component branch enforcement
3. ✅ Defect Catalog V2 integration
4. ✅ Supervisor PIN for high-risk overrides

**Actual Duration:** ~6 hours (faster due to existing infrastructure)

---

### 27.17 MCI - Missing Component Injection (Track 2)

**Spec:** `01-concepts/MISSING_COMPONENT_INJECTION_SPEC.md`  
**Plan:** `tasks/task27.17_MCI_IMPLEMENTATION_PLAN.md` ✅ COMPLETE

**Dependencies (CORRECTED):**
- 27.12 (Component Catalog for validation) ✅
- 27.13 (Component Node for context) ✅
- ~~27.14 Defect Catalog~~ ❌ NOT REQUIRED
- ~~27.15 QC Rework V2~~ ❌ NOT REQUIRED
- ~~27.16 Graph Linter~~ ❌ NOT REQUIRED

**Why MCI Can Start Early:**
- MCI uses catalog for component validation
- MCI uses component context from tokens
- MCI does NOT need defect catalog
- MCI does NOT need QC rework algorithm
- MCI does NOT need linter rules

**Progressive Enhancement Note:**

```
┌─────────────────────────────────────────────────────────────────┐
│              MCI: PROGRESSIVE ENHANCEMENT                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MCI ทำงานได้ใน 2 สถานการณ์:                                    │
│                                                                 │
│  1. กราฟมี Component Anchor Node แล้ว                           │
│     → MCI ใช้ context จาก anchor_slot + mapping                │
│     → inject component ที่ตรงกับ branch                        │
│                                                                 │
│  2. กราฟไม่มี Component Anchor Node (Phase 1 / Simple Graph)   │
│     → MCI ใช้ product_component_mapping แทน                    │
│     → validate จาก catalog โดยตรง                              │
│     → ยังคง inject ได้                                         │
│                                                                 │
│  ⚠️ ไม่จำเป็นต้องมี component node ก่อนเสมอไป!                  │
│  MCI ออกแบบให้ใช้ได้แบบ progressive enhancement               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Status:** Full plan already created (~1,000 lines)

**Total:** ~45-55 hours (~6-7 days)

---

## PHASE C: Validation Layer

> **Duration:** Week 5-6 (~44 hours)  
> **Priority:** 🟡 MEDIUM - Prevent bad graphs

---

### 27.16 Graph Linter Rules

**Spec:** `01-concepts/GRAPH_LINTER_RULES.md`

**Dependencies:**
- 27.13 (Component Node for C1, C2 rules)
- 27.15 (QC Rework logic for Q rules validation)

**Tasks:**

| Task | Description | Est. Hours |
|------|-------------|------------|
| 27.16.1 | Integrate with `GraphValidationEngine` | 4h |
| 27.16.2 | Rule S1: Start/End validation | 2h |
| 27.16.3 | Rule S2: Orphan node detection | 2h |
| 27.16.4 | Rule S3: Reachability check | 3h |
| 27.16.5 | Rule S4: Merge node incoming edges | 3h |
| 27.16.6 | Rule C1: Parallel split needs component nodes | 4h |
| 27.16.7 | Rule C2: Component node positioning | 3h |
| 27.16.8 | Rule Q1: QC no edge_condition (ERROR) | 2h |
| 27.16.9 | Rule Q2: QC has operation upstream | 3h |
| 27.16.10 | Rule B1: QC before merge suggestion | 2h |
| 27.16.11 | Graph Designer: Show linter warnings in UI | 4h |
| 27.16.12 | Graph Designer: Auto-fix suggestions | 6h |
| 27.16.13 | Tests: Each rule has test cases | 6h |

**Total:** ~44 hours (~5-6 days)

**Deliverables:**
- [ ] All S, C, Q, B rules implemented
- [ ] Linter runs on save/validate
- [ ] Errors block publish
- [ ] Warnings shown but allow publish
- [ ] Auto-fix for common issues

---

## PHASE E: Inventory Integration ✅ COMPLETE

> **Duration:** Week 7  
> **Priority:** 🟠 HIGH - Inventory Integration  
> **Status:** ✅ **COMPLETE** (December 6, 2025)

---

### 27.18 Material Requirement & Reservation ✅ COMPLETE

**Spec:** `tasks/task27.18_MATERIAL_REQUIREMENT_PLAN.md`
**Results:** `results/task27.18_material_requirement_results.md`

**Completed:**
- ✅ Migration: 4 tables (material_requirement, material_reservation, material_allocation, material_requirement_log)
- ✅ MaterialRequirementService - Calculate requirements from BOM
- ✅ MaterialReservationService - Soft-lock inventory (FIFO)
- ✅ MaterialAllocationService - Hard-link token to material
- ✅ API: 8 endpoints in `material_requirement_api.php`

**Note:** UI Panel จะทำในระยะถัดไป

---

## EXTENSIONS (Added During Implementation) ✅ COMPLETE

> **Tasks ที่เพิ่มขึ้นระหว่าง Implementation**

---

### 27.13.12 Component Mapping Refactor ✅ COMPLETE

**Purpose:** Refactor Component Mapping ให้ใช้ V2 Architecture (Product Components)

**Completed:**
- ✅ Migration: Add `id_product`, `id_product_component` to `graph_component_mapping`
- ✅ Migration: Add `expected_component_type` to `routing_node`
- ✅ `ComponentMappingService.php` - V2 methods for product-scoped mappings
- ✅ API: `save_component_mapping_v2`, `get_component_mappings_v2`, `get_product_components_for_mapping`
- ✅ UI: Component Mapping tab uses Product Components dropdown
- ✅ Product Duplication: Copy components, BOM, and mappings with modal selection
- ✅ Duplicate validation: Real-time and save-time check for duplicate component selections

---

### 27.19 Product Readiness System ✅ COMPLETE

**Purpose:** Validate product configuration before allowing job creation

**Completed:**
- ✅ Migration: `product_config_log` table for audit
- ✅ `ProductReadinessService.php` - Calculate readiness status (Pass/Fail)
- ✅ API: `get_product_readiness`, `get_products_readiness_batch`
- ✅ UI: Badge in product list (Font Awesome icon)
- ✅ UI: Disabled options + "(รอตั้งค่า)" in job creation dropdown
- ✅ Classic products: Require Components + Materials, hide Component Mapping tab
- ✅ Hatthasilpa products: Full requirements (Graph + Components + Mapping)

**Readiness Criteria:**
- **Hatthasilpa:** Production Line + Graph Binding (active, published, has START) + Components + Materials + Mapping
- **Classic:** Production Line + Components + Materials (no Graph required)

---

## PHASE F: Execution Integration (Week 8+)

> **Duration:** 3-4 days  
> **Priority:** 🟠 HIGH - Production Ready  
> **Status:** 📋 PLANNED

---

### 27.21 Material Integration ✅ COMPLETE

**Plan:** `tasks/task27.21_MATERIAL_INTEGRATION_PLAN.md`
**Status:** ✅ **COMPLETE** (December 7, 2025)

**Completed:**
- ✅ Phase 1: Material Check Panel ใน Hatthasilpa Job Creation
- ✅ Phase 2: Materials Tab ใน Job Ticket
- ✅ Phase 3: Material Consumption on Node Complete (FIFO deduction)

**Duration:** ~16 hours

---

### 27.21.1 Rework Material Reserve 📋 PLANNED

**Plan:** `tasks/task27.21.1_REWORK_MATERIAL_RESERVE_PLAN.md`
**Status:** 📋 PLANNED

**Purpose:** จัดการวัสดุเมื่อ QC Fail → Rework (Recut/Scrap)

**Scope:**
- Reserve materials for replacement tokens (Recut)
- Return/waste materials for scrapped tokens
- Shortage handling policy

**Estimated:** 5-7 hours (1 day)

---

### 27.20 Node Behavior UI Enhancement

**Plan:** `tasks/task27.20_NODE_BEHAVIOR_UI_PLAN.md`

**Purpose:** Dynamic UI per behavior สำหรับ PWA Work Queue

**Scope:**
- Complete Handlers (init, validate, submit) for CUT, STITCH, QC
- API Integration for behavior-specific data
- Data Validation

**Estimated:** 12-16 hours (2-3 days)

---

## PHASE G: Future Enhancements

> **Duration:** TBD  
> **Priority:** 🔮 FUTURE - After core ERP stable

---

### 27.22 Production Stock Dashboard (Future)

**Purpose:** Factory Planning Dashboard

**Scope:**
- All Products + Can Produce
- Bottleneck Analysis
- Shortage Overview
- Purchase Suggestions

**Estimated:** 12-16 hours

---

### 27.23 Skill & Material Tolerance (Future)

**Spec:** `01-concepts/SKILL_MATERIAL_TOLERANCE_SPEC.md`

**Dependencies:**
- People DB / Worker system
- ERP Core complete
- Product owner approval

**Status:** Specification ready, implementation deferred

**Estimated:** 4-6 weeks when ready

---

## 📅 Timeline Overview (COMPLETE)

```
┌─────────────────────────────────────────────────────────────────┐
│              OPTIMIZED WEEK-BY-WEEK PLAN                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  WEEK 1-2: PHASE A (Foundation)                                │
│  ├─ 27.12 Component Catalog     (~26h)                         │
│  └─ 27.13 Component Node Type   (~24h)                         │
│      Total: ~50h                                                │
│                                                                 │
│  WEEK 3-4: PHASE B + D (PARALLEL TRACKS!)                      │
│  ├─ Track 1: Quality                                           │
│  │   ├─ 27.14 Defect Catalog        (~35h)                     │
│  │   └─ 27.15 QC Rework V2          (~38h)                     │
│  │                                                              │
│  └─ Track 2: Safety Net                                        │
│      └─ 27.17 MCI                   (~50h)                     │
│                                                                 │
│  WEEK 5-6: PHASE C (Validation)                                │
│  └─ 27.16 Graph Linter          (~44h)                         │
│                                                                 │
│  ════════════════════════════════════════════════════════════  │
│  BEFORE (Sequential):  8 weeks, 217h                           │
│  AFTER (Parallel):     6 weeks, 217h   ← 25% faster!           │
│  ════════════════════════════════════════════════════════════  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Quick Reference

### Task Completion Status

| Priority | Task | Dependencies | Status |
|----------|------|--------------|--------|
| **1** | 27.12 Component Catalog | None | ✅ COMPLETE |
| **2** | 27.13 Component Node Type | 27.12 | ✅ COMPLETE |
| **2b** | 27.13.11b Material Architecture V2 | 27.12, 27.13 | ✅ COMPLETE |
| **3a** | 27.14 Defect Catalog | 27.12 | ✅ COMPLETE |
| **3b** | 27.15 QC Rework V2 | 27.13, 27.14 | ✅ COMPLETE |
| **4** | 27.17 MCI | 27.12, 27.13 | ✅ COMPLETE |
| **5** | 27.16 Graph Linter | 27.13, 27.15 | ✅ COMPLETE |
| **6** | 27.18 Material Requirement | 27.13.11b | ✅ COMPLETE (Backend) |
| **EXT** | 27.13.12 Component Mapping Refactor | 27.13.11b | ✅ COMPLETE |
| **EXT** | 27.19 Product Readiness System | 27.13.12 | ✅ COMPLETE |
| **7** | 27.21 Material Integration | 27.18 | ✅ COMPLETE |
| **7.1** | 27.21.1 Rework Material Reserve | 27.21, 27.15 | 📋 PLANNED |
| **8** | 27.20 Node Behavior UI | 27.21 | 📋 PLANNED |
| **9** | 27.22 Production Stock Dashboard | 27.21 | 🔮 Future |
| **10** | 27.23 Skill/Material Tolerance | All above | 🔮 Future |

### Parallel Execution Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│              CAN THESE RUN IN PARALLEL?                         │
├───────────┬───────┬───────┬───────┬───────┬───────┬─────────────┤
│           │ 27.12 │ 27.13 │ 27.14 │ 27.15 │ 27.16 │ 27.17 (MCI) │
├───────────┼───────┼───────┼───────┼───────┼───────┼─────────────┤
│ 27.12     │   -   │  NO   │  NO   │  NO   │  NO   │     NO      │
│ 27.13     │       │   -   │  YES  │  NO   │  NO   │     NO      │
│ 27.14     │       │       │   -   │  NO   │  YES  │     YES ⭐  │
│ 27.15     │       │       │       │   -   │  NO   │     YES ⭐  │
│ 27.16     │       │       │       │       │   -   │     YES     │
│ 27.17     │       │       │       │       │       │      -      │
└───────────┴───────┴───────┴───────┴───────┴───────┴─────────────┘

⭐ Key Insight: MCI can run parallel with 27.14 and 27.15!
```

---

## 📚 Related Documents

### Specifications

| Document | Phase | Status |
|----------|-------|--------|
| [COMPONENT_CATALOG_SPEC.md](../01-concepts/COMPONENT_CATALOG_SPEC.md) | A | ✅ Ready |
| [QC_REWORK_PHILOSOPHY_V2.md](../01-concepts/QC_REWORK_PHILOSOPHY_V2.md) | A+B | ✅ Ready |
| [DEFECT_CATALOG_SPEC.md](../01-concepts/DEFECT_CATALOG_SPEC.md) | B | ✅ Ready |
| [GRAPH_LINTER_RULES.md](../01-concepts/GRAPH_LINTER_RULES.md) | C | ✅ Ready |
| [MISSING_COMPONENT_INJECTION_SPEC.md](../01-concepts/MISSING_COMPONENT_INJECTION_SPEC.md) | D | ✅ Ready |
| [SKILL_MATERIAL_TOLERANCE_SPEC.md](../01-concepts/SKILL_MATERIAL_TOLERANCE_SPEC.md) | E | 🔮 Future |

### Implementation Plans

| Plan | Status | Est. Hours |
|------|--------|------------|
| [task27.17_MCI_IMPLEMENTATION_PLAN.md](./task27.17_MCI_IMPLEMENTATION_PLAN.md) | ✅ Complete | ~50h |
| [task27.12_COMPONENT_CATALOG_PLAN.md](./task27.12_COMPONENT_CATALOG_PLAN.md) | ✅ Complete | ~26h |
| [task27.13_COMPONENT_NODE_PLAN.md](./task27.13_COMPONENT_NODE_PLAN.md) | ✅ Complete | ~31h |
| [task27.14_DEFECT_CATALOG_PLAN.md](./task27.14_DEFECT_CATALOG_PLAN.md) | ✅ Complete | ~35h |
| [task27.15_QC_REWORK_V2_PLAN.md](./task27.15_QC_REWORK_V2_PLAN.md) | ✅ Complete | ~38h |
| [task27.16_GRAPH_LINTER_PLAN.md](./task27.16_GRAPH_LINTER_PLAN.md) | ✅ Complete | ~44h |
| [task27.18_MATERIAL_REQUIREMENT_PLAN.md](./task27.18_MATERIAL_REQUIREMENT_PLAN.md) | 📋 Ready | ~50h |

---

## ✅ Definition of Done (Per Phase)

### Phase A Complete When: ✅ ALL DONE (Dec 5, 2025)
- [x] Component Catalog has 20+ components seeded (24 + 35 legacy = 59 total)
- [x] Product-component mapping table exists
- [x] `routing_node.node_type` ENUM includes 'component'
- [x] `routing_node.anchor_slot` column exists (NOT component_code!)
- [x] `graph_component_mapping` table exists (slot → code mapping)
- [x] Component nodes can be created in Graph Designer (with anchor_slot)
- [x] Product Config UI can map anchor_slot → component_code
- [x] `ComponentTypeService` and `ProductComponentService` working
- [x] 11 API endpoints for component/material management
- [x] Components Tab UI in Product Modal
- [x] Migration consolidation verified (100% schema match)

### Phase B Complete When:
- [x] Defect Catalog has 30+ defects seeded (36 defects ✅)
- [x] Defect Admin UI complete ✅
- [x] Defect Catalog API complete (10 endpoints) ✅
- [ ] QC Fail uses defect selector (not free text)
- [ ] `getReworkTargetsForQC()` returns component branch nodes
- [ ] Rework targets limited to component branch
- [ ] Defect-based suggestions working

### Phase C Complete When:
- [ ] All S, C, Q, B linter rules implemented
- [ ] Errors block graph publish
- [ ] Warnings visible in Graph Designer UI
- [ ] Auto-fix for common issues (optional)

### Phase D (MCI) Complete When:
- [ ] MCI button in Work Queue/Assembly/QC Final
- [ ] Missing component modal shows correct options
- [ ] Component token can be injected
- [ ] Merge waits for injected components
- [ ] Full audit trail in `component_injection_log`

---

## ⚠️ Risk Mitigation

### Schema Migration Risks

| Risk | Mitigation |
|------|------------|
| ENUM modification fails | Test on staging first, backup before migration |
| Existing nodes break | Add column as NULL, backfill later |
| Foreign key issues | Seed catalog BEFORE adding FK to routing_node |

### Parallel Execution Risks

| Risk | Mitigation |
|------|------------|
| Code conflicts | Daily sync meetings, clear file ownership |
| Integration failures | Integration tests run after each track completes |
| Merge conflicts | Small, focused commits; rebase frequently |

---

## 🚀 Recommended Team Allocation

### Single Developer:
```
Week 1-2: Phase A (Foundation)
Week 3-4: Track 1 (Quality) OR Track 2 (MCI) - pick one
Week 5-6: Remaining track
Week 7: Phase C (Linter)
```

### Two Developers:
```
Dev A (Quality Track):
  Week 1-2: 27.12 (Catalog) + 27.13 (Node)
  Week 3-4: 27.14 (Defect) + 27.15 (QC Rework)
  Week 5-6: 27.16 (Linter)

Dev B (Safety Track):
  Week 1-2: Support Phase A + prepare MCI environment
  Week 3-4: 27.17 (MCI)
  Week 5-6: Integration testing + documentation
```

---

> **"Build the foundation first, parallelize what you can, ship quality"**
