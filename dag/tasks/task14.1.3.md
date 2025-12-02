

# Task 14.1.3 — Routing V1 Migration (Legacy → Routing V2)

## Objective
Migrate all legacy routing V1 logic, queries, and data dependencies to Routing V2 (super_dag) while keeping the system operational and backward compatible.

This task finalizes the cleanup of the routing pipeline so Task 14.2 (Master Schema V2) can proceed safely without breaking Job Tickets, PWA Scan, or Work Queue.

---

## 🟥 Scope of Work (Migration Targets)

### 1. `source/hatthasilpa_job_ticket.php`
- Remove all direct queries to legacy `routing` tables.
- Replace with new V2 routing lookup from:
  - `dag_routing_api.php`
  - `DagExecutionService`
  - `super_dag` metadata tables
- Map legacy fields (`step_name`, `work_center_id`, `seq`) to V2 node properties.
- Ensure Job Ticket UI still shows:
  - Node name
  - Sequence
  - Work center
  - Behavior code
  - Component requirements (if any)

### 2. `source/routing.php` (Legacy Routing UI)
- Mark UI as deprecated.
- Disable creation/modification actions.
- Allow **read-only mode** for historical record only.
- Add banner: “Legacy Routing V1 — Read Only”
- Redirect new routing creation to **DAG Designer (super_dag)**.

### 3. `source/pwa_scan_api.php`
- Replace all lookups relying on:
  - `routing`
  - `routing_step`
  - `workflow_next_step`
- Use:
  - Token's current node from V2 engine
  - Node info from super_dag repository
- Ensure PWA scan continues to support:
  - Current node info
  - Work center
  - Behavior panel injection
  - Next node preview (if any)

---

## 🟦 Additional Requirements

### 🔹 Backward Compatibility
- No breaking changes allowed.
- If old routes exist, system must translate them to V2 equivalents.
- Use fallback adapter:
  - `LegacyRoutingAdapter.php` (READ ONLY)
  - Converts V1 → V2 temporary metadata
  - Remove after all tenants fully migrated.

### 🔹 Safety Guards
- No writes allowed to legacy routing tables.
- Ensure queries fail-safe if legacy data missing.
- Unit-test coverage added for:
  - Routing V2 transitions
  - Node metadata mapping
  - PWA scan token movement

---

## 🟩 Acceptance Criteria

### ✔ Routing functions correctly using V2 only
No remaining logic depends on:
- `routing`
- `routing_step`
- `workflow_next_step`

### ✔ PWA Scan still works normally
- Token movement correct  
- Behavior panel loads correctly  
- Next node calculation correct  

### ✔ Job Ticket uses V2 routing
- Node list loads from V2  
- Behaviors and requirements show correctly  

### ✔ Legacy routing UI disabled safely
- Visible but read-only  
- Warning banner shown  

### ✔ No system-wide breakage
- Work Queue unaffected  
- DAG Designer unaffected  
- Component pipeline unaffected  

---

## 🟧 Deliverables

1. Updated PHP files:
   - `hatthasilpa_job_ticket.php`
   - `routing.php`
   - `pwa_scan_api.php`
   - New: `LegacyRoutingAdapter.php`

2. Updated docs:
   - `task14.1.3_results.md`
   - Updated `task_index.md`

---

## Status
**READY FOR IMPLEMENTATION by AI Agent via Cursor (14.1.3 EXECUTION STAGE)**
