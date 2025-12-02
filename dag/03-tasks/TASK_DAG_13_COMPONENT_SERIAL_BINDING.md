# DAG Task 13: Component Serial Binding (Stage 1 – Hatthasilpa Line)

**Task ID:** DAG-13  
**Status:** 🟡 **IN PROGRESS** (Phase 2: Data Model & Storage Complete)  
**Scope:** Component / Serial / Hatthasilpa  
**Type:** Implementation Task (Stage 1: Capture & Expose Only)

**Related Task File:** `docs/dag/tasks/task13.md`

---

## 1. Context

### Current State

**Hatthasilpa Production Line:**
- ✅ Hatthasilpa jobs are partially live (DAG routing working)
- ✅ Token lifecycle stable (spawn, split, join, complete)
- ✅ Serial tracking infrastructure exists (`UnifiedSerialService`, `serial_registry`)
- ✅ `flow_token` table has `token_type` enum including 'component'
- ✅ `trace_api.php` has `serial_components` endpoint (but only queries `inventory_transaction_item`)

**Missing:**
- ❌ No component serial binding table or fields
- ❌ No way to link component serials to final product serials
- ❌ No component-aware queries in trace API
- ❌ No UI showing component serial relationships

### Problem

For multi-part products (e.g., bags with BODY, FLAP, STRAP components), the system cannot:
- Track which component serials belong to which final product
- Query "what components went into this bag?"
- Query "which bag contains this component serial?"
- Expose component serial relationships in APIs

### Impact

- Cannot trace component genealogy (component → final product relationships)
- Trace API `serial_components` only shows inventory transactions, not component tokens
- No visibility into component-level serial tracking
- Multi-part product workflows lack component serial traceability

---

## 2. Objective

Implement Component Serial Binding - Stage 1 (Capture & Expose) for Hatthasilpa line that:
- **Captures** component serial relations (component serial → final product serial)
- **Exposes** component serial data in read APIs (trace_api, dag_token_api, job details)
- **Does NOT enforce** hard blocking based on component serials (Stage 1 only)
- **Does NOT support** Classic line (Hatthasilpa only for now)

**Stage 1 Focus:** Capture & Expose only - no enforcement/blocking  
**Stage 2 (Future):** Will add enforcement (component matching validation, blocking)

---

## 3. Scope

### In Scope (Stage 1)

**Hatthasilpa Line Only:**
- ✅ Component serial binding for Hatthasilpa jobs
- ✅ Read APIs (trace_api, dag_token_api, job details)
- ✅ Minimal UI (read-only list in job details or Work Queue)

**Data Model:**
- ✅ New table: `job_component_serial` to store component serial bindings
- Links: (tenant/org) + job/MO + component (bom line or product) + serial id/text

**API Exposure:**
- `trace_api.php` - Extend `serial_components` to include component tokens (Phase 3)
- `dag_token_api.php` - Add component serial data to token details (Phase 3)
- Job details APIs - Add component serial list (Phase 3)

### Out of Scope (Stage 1)

**Not Included:**
- ❌ Classic line support (Hatthasilpa only)
- ❌ Hard enforcement (no blocking based on component serials)
- ❌ PWA scan overhaul (no changes to scan UI)
- ❌ Full component model (no `product_component` table yet)
- ❌ Component matching validation at join nodes
- ❌ Full genealogy engine (basic queries only)

---

## 4. Discovery Findings

### Phase 1.1: Existing Code & Schema Scan

**Search Results:**
- ✅ `trace_api.php` has `serial_components` endpoint
- ✅ `getComponentsForSerial()` function exists
  - Currently queries `inventory_transaction_item` only
  - Does NOT query component tokens from `flow_token`
- ✅ `flow_token` table has `token_type` enum('batch','piece','component')
- ✅ `flow_token` has `serial_number` field (can store component serials)
- ✅ `flow_token` has `parent_token_id` (for split tokens)
- ✅ `flow_token` has `metadata` JSON field (can store component info temporarily)

**Missing Fields (from roadmap, not yet implemented):**
- ❌ `flow_token.component_code` - Component code (e.g., 'BODY', 'FLAP')
- ❌ `flow_token.id_component` - Foreign key to product_component
- ❌ `flow_token.root_serial` - Root serial (final product serial)
- ❌ `flow_token.root_token_id` - Root token (final product token)
- ❌ `product_component` table - Component master data

**Existing Tables:**
- ✅ `job_ticket_serial` - Tracks serials at job level
- ✅ `serial_registry` (core DB) - Master serial registry with `dag_token_id`
- ✅ `flow_token` - Token table with `token_type='component'` support
- ✅ `bom_line` - BOM lines (materials and sub-assemblies)

### Phase 1.2: Current Hatthasilpa Flow Mapping

**Job Creation Flow:**
1. `hatthasilpa_jobs_api.php` → `create` or `create_and_start` action
2. `JobCreationService::createFromBinding()` or `createFromBindingWithoutTokens()`
3. `GraphInstanceService::createInstance()` - Creates `job_graph_instance`
4. `TokenLifecycleService::spawnTokens()` - Spawns tokens at START node
5. Serial generation via `UnifiedSerialService` (if piece mode)

**Token Spawn Flow:**
1. `dag_token_api.php` → `token_spawn` action
2. `TokenLifecycleService::spawnTokens()` - Creates tokens
3. Serial assignment via `job_ticket_serial` table
4. Serial registration via `UnifiedSerialService::registerSerial()`

**Tracing Flow:**
1. `trace_api.php` → `serial_view` or `serial_components` action
2. `getComponentsForSerial()` - Currently queries `inventory_transaction_item` only
3. Returns component data from inventory transactions (not component tokens)

**Best Anchor Point:**
- **Chosen Approach:** New table `job_component_serial` for Stage 1
  - Pros: Normalized, queryable, supports multiple components per job
  - Cons: Requires new table and migration

---

## 5. Design

### 5.1 Data Model (Stage 1) ✅ Complete

**New Table: `job_component_serial`**

```sql
CREATE TABLE job_component_serial (
    id_binding INT PRIMARY KEY AUTO_INCREMENT,
    id_job_ticket INT NOT NULL COMMENT 'FK to job_ticket',
    id_instance INT NULL COMMENT 'FK to job_graph_instance (for quick lookup)',
    component_code VARCHAR(64) NULL COMMENT 'Component code (e.g., BODY, FLAP, STRAP) - from bom_line or product_component if exists',
    component_serial VARCHAR(100) NOT NULL COMMENT 'Component serial number',
    final_piece_serial VARCHAR(100) NULL COMMENT 'Final product serial (root serial)',
    id_component_token INT NULL COMMENT 'FK to flow_token.id_token (if component token exists)',
    id_final_token INT NULL COMMENT 'FK to flow_token.id_token (final piece token)',
    bom_line_id INT NULL COMMENT 'FK to bom_line.id_bom_line (if linked to BOM)',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL COMMENT 'id_member who created this binding',
    
    INDEX idx_job_ticket (id_job_ticket),
    INDEX idx_instance (id_instance),
    INDEX idx_component_serial (component_serial),
    INDEX idx_final_serial (final_piece_serial),
    INDEX idx_component_token (id_component_token),
    INDEX idx_final_token (id_final_token),
    INDEX idx_job_component (id_job_ticket, component_code),
    
    FOREIGN KEY (id_job_ticket) REFERENCES job_ticket(id_job_ticket) ON DELETE CASCADE,
    FOREIGN KEY (id_instance) REFERENCES job_graph_instance(id_instance) ON DELETE CASCADE,
    FOREIGN KEY (id_component_token) REFERENCES flow_token(id_token) ON DELETE SET NULL,
    FOREIGN KEY (id_final_token) REFERENCES flow_token(id_token) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Component serial bindings for Hatthasilpa jobs (Stage 1: Capture & Expose)';
```

**Design Notes:**
- `component_code` is nullable (may not have product_component table yet)
- `final_piece_serial` is nullable (may be set later when final piece is completed)
- `id_component_token` and `id_final_token` are nullable (tokens may not exist yet)
- Supports multiple components per job
- Supports multiple serials per component per job

**Migration File:**
- ✅ `database/tenant_migrations/2025_12_component_serial_binding.php`
- Uses idempotent helpers (`migration_create_table_if_missing`)
- Safe to run multiple times

### 5.2 Write Path (Stage 1 - Minimal) ✅ Complete

**Internal API Endpoint:**
- ✅ Created `source/hatthasilpa_component_api.php`
- Action: `bind_component_serial`
- Input: `job_ticket_id`, `component_code`, `component_serial`, `final_piece_serial` (optional), `id_component_token` (optional), `id_final_token` (optional), `bom_line_id` (optional)
- Behavior: INSERT into `job_component_serial` table
- Feature flag: `FF_HAT_COMPONENT_SERIAL_BINDING` (default: 0, disabled)

**API Endpoints:**
1. **`bind_component_serial`** - Create component serial binding
   - Validates feature flag
   - Validates job_ticket exists
   - Inserts binding record
   - Returns `id_binding`

2. **`get_component_serials`** - Get all bindings for a job
   - Queries `job_component_serial` by `job_ticket_id`
   - Returns array of bindings

**Feature Flag:**
- `FF_HAT_COMPONENT_SERIAL_BINDING` - Must be enabled in Core DB (`feature_flag_catalog` + `feature_flag_tenant`)
- Checked via `FeatureFlagService::getFlagValue()`
- Default: 0 (disabled)

### 5.3 Read Path & API Exposure (Phase 3 - Pending)

**Target APIs:**

1. **`trace_api.php` → `serial_components` endpoint**
   - Extend `getComponentsForSerial()` to also query `job_component_serial`
   - Merge results from `inventory_transaction_item` and `job_component_serial`
   - Add new fields: `component_code`, `component_serial`, `final_piece_serial`, `id_component_token`

2. **`dag_token_api.php` → Token details**
   - Add `component_serials` array to token response
   - Query `job_component_serial` where `id_component_token = token_id` or `id_final_token = token_id`

3. **Job Details APIs**
   - `hatthasilpa_jobs_api.php` → `get` action
   - Add `component_serials` array to job response
   - Query `job_component_serial` where `id_job_ticket = job_ticket_id`

**Response Format (Additive Only):**
```json
{
  "ok": true,
  "data": {
    // ... existing fields ...
    "component_serials": [
      {
        "component_code": "BODY",
        "component_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X-BODY",
        "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
        "id_component_token": 1234,
        "id_final_token": 5678
      }
    ]
  }
}
```

**Backward Compatibility:**
- If no component serials → `component_serials` is `null` or empty array `[]`
- Existing fields unchanged
- No breaking changes to existing JSON contract

### 5.4 Minimal UI (Phase 4 - Pending)

**Target UI Surface:**
- **Option A:** Job details drawer/panel in Hatthasilpa job ticket page
- **Option B:** Work Queue details panel (when viewing token details)
- **Option C:** Both (recommended for Stage 1)

**Display Format:**
- Simple read-only list: "Component X → Serial Y"
- Group by `component_code` if multiple components
- Show `final_piece_serial` if available

**No Editor UI Yet:**
- Stage 1 focuses on read-only display
- Write path via API only (internal or manual entry)

---

## 6. Constraints

### Must Not Break

- ✅ **No breaking changes** - Existing JSON contracts unchanged (additive only)
- ✅ **No enforcement** - Stage 1 does NOT block production based on component serials
- ✅ **No Classic line changes** - Hatthasilpa only for Stage 1
- ✅ **Backward compatible** - Jobs without component serials must still work
- ✅ **Fail-open behavior** - API errors don't break job creation or token spawn

### Must Follow

- ✅ **Use existing helpers** - `DatabaseHelper`, `TenantApiOutput`, `PermissionHelper`
- ✅ **Respect tenant boundaries** - All queries scoped to tenant DB
- ✅ **Use prepared statements** - No SQL injection vulnerabilities
- ✅ **Feature flag protection** - Write path must be feature-flagged
- ✅ **Log safely** - No sensitive data in logs

---

## 7. Implementation Plan

### Phase 1: Discovery ✅ Complete

- [x] Scan existing code & schema
- [x] Map current Hatthasilpa flow
- [x] Create task spec document

### Phase 2: Data Model & Storage ✅ Complete

- [x] Design `job_component_serial` table schema
- [x] Create migration file: `database/tenant_migrations/2025_12_component_serial_binding.php`
- [x] Implement write path (internal API endpoint)
- [x] Add feature flag: `FF_HAT_COMPONENT_SERIAL_BINDING`
- [x] Document schema in this task file

**Files Created:**
- ✅ `database/tenant_migrations/2025_12_component_serial_binding.php`
- ✅ `source/hatthasilpa_component_api.php`

### Phase 3: Read Path & API Exposure (Next)

- [ ] Extend `trace_api.php` → `getComponentsForSerial()` to query `job_component_serial`
- [ ] Extend `dag_token_api.php` → Add `component_serials` to token response
- [ ] Extend `hatthasilpa_jobs_api.php` → Add `component_serials` to job response
- [ ] Ensure backward compatibility (null/empty array when no data)

### Phase 4: Minimal UI (Pending)

- [ ] Add component serial list to job details drawer/panel
- [ ] Add component serial list to Work Queue details panel (optional)
- [ ] Display format: Simple read-only list grouped by component_code

### Phase 5: Tests & Docs (Pending)

- [ ] Add integration tests for component serial binding
- [ ] Test: Job with component serials → API returns them correctly
- [ ] Test: Job without component serials → API returns null/empty array
- [ ] Test: Tenant isolation (bindings don't leak across tenants)
- [ ] Update this task file with implementation status
- [ ] Update `TASK_INDEX.md`
- [ ] Update `IMPLEMENTATION_STATUS_SUMMARY.md`

---

## 8. Guardrails

### Must Not Regress

- ✅ **Existing serial tracking** - Must not break current serial registration
- ✅ **Token lifecycle** - Must not break spawn/split/join logic
- ✅ **Backward compatibility** - Existing jobs without component serials must still work
- ✅ **API contracts** - No breaking changes to existing JSON responses

### Design Principles

- **Additive only** - New fields only, no changes to existing fields
- **Fail-open** - Errors don't block production flows
- **Feature flag protected** - Write path requires feature flag
- **Hatthasilpa only** - Classic line not supported in Stage 1

---

## 9. Status

**Status:** 🟡 **IN PROGRESS** (Phase 2: Data Model & Storage Complete)

**Current Phase:** Phase 2 - Data Model & Storage ✅ Complete

**Next Steps:**
1. ✅ Phase 2 Complete: Migration and API endpoint created
2. Begin Phase 3: Read Path & API Exposure
3. Extend `trace_api.php` to query `job_component_serial`
4. Extend `dag_token_api.php` to include component serials
5. Extend `hatthasilpa_jobs_api.php` to include component serials

**Related Tasks:**
- DAG-5: Component Model & Serial Genealogy (Phase 4) - Full component model (PLANNED)
  - See [TASK_DAG_5_COMPONENT_MODEL.md](TASK_DAG_5_COMPONENT_MODEL.md)

**Documentation:**
- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Phase 4: Component Model section
- [BELLAVIER_DAG_RUNTIME_FLOW.md](../01-core/BELLAVIER_DAG_RUNTIME_FLOW.md) - Token lifecycle
- [task13.md](../../tasks/task13.md) - Original task specification

---

## 10. Example Scenarios

### Scenario 1: Job with Component Serials

**Job:** Hatthasilpa job for TOTE bag (serial: `MA01-HAT-DIAG-20251201-00001-A7F3-X`)

**Component Serials:**
- BODY: `MA01-HAT-DIAG-20251201-00001-A7F3-X-BODY`
- FLAP: `MA01-HAT-DIAG-20251201-00001-A7F3-X-FLAP`
- STRAP: `MA01-HAT-DIAG-20251201-00001-A7F3-X-STRAP`

**API Call (bind_component_serial):**
```json
POST hatthasilpa_component_api.php?action=bind_component_serial
{
  "job_ticket_id": 631,
  "component_code": "BODY",
  "component_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X-BODY",
  "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X"
}
```

**API Response (get_component_serials):**
```json
{
  "ok": true,
  "data": {
    "component_serials": [
      {
        "id_binding": 1,
        "component_code": "BODY",
        "component_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X-BODY",
        "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
        "id_component_token": 1234,
        "id_final_token": 5678
      },
      {
        "id_binding": 2,
        "component_code": "FLAP",
        "component_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X-FLAP",
        "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
        "id_component_token": 1235,
        "id_final_token": 5678
      }
    ]
  }
}
```

### Scenario 2: Job without Component Serials

**Job:** Hatthasilpa job without component serials (legacy job or simple product)

**API Response:**
```json
{
  "ok": true,
  "data": {
    "component_serials": []  // or null - backward compatible
  }
}
```

---

## 11. Files Created/Modified

### Phase 2: Data Model & Storage

**New Files:**
- ✅ `database/tenant_migrations/2025_12_component_serial_binding.php` - Migration file
- ✅ `source/hatthasilpa_component_api.php` - API endpoint for component serial binding
- ✅ `docs/dag/03-tasks/TASK_DAG_13_COMPONENT_SERIAL_BINDING.md` - This task summary document

**Modified Files:**
- None (Phase 2 only adds new files)

**Feature Flag:**
- `FF_HAT_COMPONENT_SERIAL_BINDING` - Must be added to Core DB `feature_flag_catalog` (default: 0)
- Can be enabled per tenant via `feature_flag_tenant` table

---

**Task Created:** December 2025  
**Status:** Phase 2 Complete (Data Model & Storage)  
**Next Phase:** Phase 3 - Read Path & API Exposure

