# ERP Legacy Routing Documentation

**Generated:** 2025-12-09  
**Last Updated:** 2025-12-17  
**Purpose:** Documentation of legacy routing V1 tables and their read-only status

**Recent Updates:**
- **Task 17.2 (2025-12-17):** Legacy node types (`split`, `join`, `wait`) are now rejected in DAG Designer and API

---

## Routing V1 vs V2 Classification

### Routing V1 (Legacy) - DEPRECATED
- **Status:** ⚠️ **READ-ONLY** (All CREATE/UPDATE/DELETE operations disabled)
- **Tables:**
  - `routing` (Legacy routing table)
  - `routing_step` (Legacy routing steps)
  - `routing_template` (Legacy routing template - if exists)
  - `routing_template_step` (Legacy routing template steps - if exists)
- **Purpose:** Historical data only, no new data creation
- **Migration Path:** V1 → V2 (via DAG Designer)

### Routing V2 (Canonical) - ACTIVE
- **Status:** ✅ **CANONICAL** (Active use, full CRUD support)
- **Tables:**
  - `routing_graph` (DAG graph)
  - `routing_graph_version` (Graph versioning)
  - `routing_graph_var` (Graph variables)
  - `routing_graph_favorite` (User favorites)
  - `routing_graph_feature_flag` (Feature flags)
  - `routing_node` (Graph nodes)
  - `routing_edge` (Graph edges)
  - `routing_set` (Routing set)
  - `routing_step` (Routing step - used by V2)
  - `routing_audit_log` (Audit log)
- **Purpose:** Current production system (DAG-based routing)
- **API:** `source/dag_routing_api.php` (Graph Designer)

---

## Legacy Routing V1 Tables

### routing (V1 Legacy)
- **Status:** ⚠️ **READ-ONLY**
- **Columns:**
  - `id_routing` (Primary Key)
  - `id_product` (FK to product)
  - `name`, `description`, `notes`
  - `created_at`, `updated_at`
- **Usage:** Historical records only
- **Action Required:** No new records should be created

### routing_step (V1 Legacy)
- **Status:** ⚠️ **READ-ONLY**
- **Columns:**
  - `id_step` (Primary Key)
  - `id_routing` (FK to routing)
  - `seq`, `sequence_no` (Sequence numbers)
  - `step_name`, `step_code`, `notes`
  - `id_work_center` (FK to work_center)
  - `std_time_min` (Standard time in minutes)
  - `yield_pct` (Yield percentage)
  - `instructions` (Step instructions)
  - `created_at`, `updated_at`
- **Usage:** Historical records only
- **Action Required:** No new records should be created

### routing_template (V1 Legacy - if exists)
- **Status:** ⚠️ **READ-ONLY** (if exists)
- **Columns:** (if table exists)
  - `id_template` (Primary Key)
  - `name`, `description`
  - Other template columns
- **Usage:** Historical records only

### routing_template_step (V1 Legacy - if exists)
- **Status:** ⚠️ **READ-ONLY** (if exists)
- **Columns:** (if table exists)
  - `id_template_step` (Primary Key)
  - `id_template` (FK to routing_template)
  - Step-related columns
- **Usage:** Historical records only

---

## Legacy Routing API

### source/routing.php
- **Status:** ⚠️ **READ-ONLY MODE** (Deprecated)
- **Permission:** `routing.view`, `routing.manage`
- **Actions:**
  - ✅ `products`: List products (READ)
  - ✅ `list`: List routings (READ)
  - ❌ `create`: **DISABLED** (returns 410 error - use DAG Designer)
  - ❌ `delete`: **DISABLED** (returns 410 error)
  - ✅ `work_centers`: List work centers (READ)
  - ✅ `steps`: List steps for routing (READ)
  - ❌ `add_step`: **DISABLED** (returns 410 error - use DAG Designer)
  - ✅ `get_step`: Get single step (READ)
  - ❌ `update_step`: **DISABLED** (returns 410 error)
- **Error Response (for disabled actions):**
  ```json
  {
    "ok": false,
    "error": "Legacy Routing V1 is deprecated. Please use DAG Designer (super_dag) to create new routings.",
    "app_code": "ROUTING_410_DEPRECATED",
    "message": "Legacy Routing V1 is read-only. Use DAG Designer for new routing creation.",
    "redirect_url": "/dag_designer.php"
  }
  ```
- **Notes:**
  - All CREATE/UPDATE/DELETE operations return HTTP 410 (Gone)
  - Only READ operations allowed
  - Redirects users to DAG Designer for new routing creation

---

## Legacy Routing Adapter

### source/BGERP/Helper/LegacyRoutingAdapter.php
- **Status:** ✅ **ACTIVE** (Backward compatibility layer)
- **Purpose:** Converts V1 routing to V2 format for display
- **Method:**
  - `getRoutingStepsForProduct()`: Main adapter method
    - **Strategy:** Try V2 first (`product_graph_binding` → `routing_graph` → `routing_node`)
    - **Fallback:** V1 (`routing` → `routing_step`) if V2 not found
    - **Returns:** Normalized format compatible with both V1 and V2
- **Mapping:**
  - V2 `routing_node` → V1 `routing_step` format
  - `id_node` → `id_step`
  - `node_name` → `step_name`
  - `sequence_no` → `seq`
  - `estimated_minutes` → `std_time_min`
  - `node_params` → `instructions` (extracted from JSON)
- **Safety:**
  - ✅ READ-ONLY (no writes to legacy tables)
  - ✅ Fail-safe (returns null if no routing found)
  - ✅ Backward compatible (supports both V1 and V2)
- **Used By:**
  - `source/hatthasilpa_job_ticket.php` (Line 1177-1216)
  - `source/pwa_scan_api.php` (Line 1120-1170)
- **Action Required:** Keep until all callers migrate to V2

---

## Files Still Using Legacy Routing

### 1. source/routing.php
- **Status:** ⚠️ Still exists, marked as deprecated
- **Usage:** READ operations only (CREATE/UPDATE/DELETE disabled in Task 14.1.3)
- **Action Required:** Delete file after confirming no UI/API calls it

### 2. source/BGERP/Helper/LegacyRoutingAdapter.php
- **Status:** ✅ Still in use (backward compatibility)
- **Used By:**
  - `source/hatthasilpa_job_ticket.php`
  - `source/pwa_scan_api.php`
- **Action Required:** Remove adapter after migrating all callers to V2

### 3. Direct SQL Queries
- **Location:** `source/routing.php`
- **Tables:** `routing`, `routing_step`
- **Usage:** READ queries only (no writes)
- **Action Required:** Keep for historical data access

---

## Migration Confirmation

### ✅ CONFIRMED: V1 is READ-ONLY

**Source:** `source/routing.php` header comments:
```php
/**
 * Routing API (Legacy V1 - DEPRECATED)
 * 
 * ⚠️ DEPRECATED: This API is for Legacy Routing V1 (routing, routing_step tables)
 * 
 * **Status:** READ-ONLY MODE
 * - All CREATE/UPDATE/DELETE operations are DISABLED
 * - Only READ operations are allowed for historical records
 * - New routing creation should use DAG Designer (super_dag)
 * 
 * **Migration:** Task 14.1.3 - Routing V1 → V2 Migration
 * - Use `dag_routing_api.php` for new routing management
 * - Use `routing_graph`, `routing_node`, `routing_edge` tables (V2)
 */
```

### ✅ CONFIRMED: V2 is CANONICAL

**Source:** `source/dag_routing_api.php` header comments:
```php
/**
 * DAG Routing API
 * 
 * Purpose: Manage routing graphs, nodes, edges for DAG-based production workflows
 * 
 * @permission dag.routing.manage
 * @status CANONICAL_V2
 */
```

**Evidence:**
- 485+ references to V2 tables across 45 files
- Active use in production (Hatthasilpa, Classic modes)
- Full CRUD support for graphs, nodes, edges
- Versioning and draft layer support
- Subgraph governance

---

## Legacy Routing vs DAG Routing Comparison

| Aspect | V1 (Legacy) | V2 (DAG) |
|--------|-------------|----------|
| **Tables** | `routing`, `routing_step` | `routing_graph`, `routing_node`, `routing_edge` |
| **Structure** | Linear sequence | DAG (Directed Acyclic Graph) |
| **API** | `source/routing.php` | `source/dag_routing_api.php` |
| **Status** | READ-ONLY | CANONICAL (Full CRUD) |
| **Versioning** | ❌ No | ✅ Yes (`routing_graph_version`) |
| **Draft Layer** | ❌ No | ✅ Yes (unpublished changes) |
| **Subgraphs** | ❌ No | ✅ Yes (parent-child relationships) |
| **Conditional Edges** | ❌ No | ✅ Yes (QC pass/fail routing) |
| **Rework Loops** | ❌ No | ✅ Yes (rework edge type) |
| **Parallel Execution** | ❌ No | ✅ Yes (Task 17: `is_parallel_split`, `is_merge_node`) |
| **Machine Binding** | ❌ No | ✅ Yes (Task 18: `machine_binding_mode`, `machine_codes`) |
| **Behavior Binding** | ❌ No | ✅ Yes (Task 15: `behavior_code`, `behavior_version`) |
| **Execution Mode** | ❌ No | ✅ Yes (Task 16: `execution_mode`, `derived_node_type`) |
| **UI** | Legacy UI (deprecated) | DAG Designer (`routing_graph_designer.php`) |

---

## Code Usage Analysis

### V1 (Legacy) Usage
- **Status:** ⚠️ **READ-ONLY** references only
- **Files:**
  - `source/routing.php`: Multiple READ queries
  - `source/BGERP/Helper/LegacyRoutingAdapter.php`: READ queries with V2 fallback
- **Action Required:** Keep for historical data access only

### V2 (DAG) Usage
- **Status:** ✅ **ACTIVE USE** - 485+ references across 45 files
- **Key Files:**
  - `source/dag_routing_api.php`: 150+ references
  - `source/dag_token_api.php`: 47+ references
  - `source/BGERP/Service/DAGValidationService.php`: 50+ references
  - `source/BGERP/Service/DAGRoutingService.php`: 19+ references
  - `source/BGERP/Service/RoutingSetService.php`: 26+ references
  - `source/hatthasilpa_job_ticket.php`: 20+ references
  - `source/products.php`: 27+ references
  - `source/mo.php`: 21+ references
- **Action Required:** Continue using V2 for all new development

---

## Migration Path

### From V1 to V2

**Step 1:** Create routing graph in DAG Designer
- UI: `page/routing_graph_designer.php`
- API: `dag_routing_api.php?action=graph_create`

**Step 2:** Design graph structure
- Add nodes (operation, QC, system nodes)
- Add edges (normal, conditional, rework)
- Configure node parameters

**Step 3:** Publish graph
- API: `dag_routing_api.php?action=graph_publish`
- Creates versioned graph ready for production

**Step 4:** Bind product to graph
- Create `product_graph_binding` record
- Links product to routing graph

**Step 5:** Use V2 routing in jobs
- Hatthasilpa jobs: Automatically use V2 via binding
- Classic jobs: Select V2 graph from dropdown

---

## Backward Compatibility

### LegacyRoutingAdapter Strategy

**Priority Order:**
1. **V2 First:** Try `product_graph_binding` → `routing_graph` → `routing_node`
2. **V1 Fallback:** If V2 not found, use `routing` → `routing_step`
3. **Normalized Output:** Returns format compatible with both V1 and V2

**Benefits:**
- ✅ Existing V1 data still accessible
- ✅ Gradual migration path
- ✅ No breaking changes for existing callers
- ✅ New products automatically use V2

---

## Summary

### ✅ CONFIRMED: Legacy Routing Status

1. **V1 Tables (`routing`, `routing_step`):**
   - ✅ **READ-ONLY** - All writes disabled
   - ✅ Historical data only
   - ✅ Backward compatibility via adapter

2. **V2 Tables (`routing_graph`, `routing_node`, `routing_edge`):**
   - ✅ **CANONICAL** - Active production system
   - ✅ Full CRUD support
   - ✅ Versioning and draft layer
   - ✅ DAG-based routing
   - ✅ **Task 15:** Behavior binding (`behavior_code`, `behavior_version`)
   - ✅ **Task 16:** Execution mode binding (`execution_mode`, `derived_node_type`)
   - ✅ **Task 17:** Parallel/merge support (`is_parallel_split`, `is_merge_node`, `merge_mode`)
   - ✅ **Task 17.2:** Validation layer (rejects legacy node types: `split`, `join`, `wait`)
   - ✅ **Task 18:** Machine cycle awareness (`machine_binding_mode`, `machine_codes`)

3. **API Status:**
   - `source/routing.php`: ⚠️ **READ-ONLY** (deprecated)
   - `source/dag_routing_api.php`: ✅ **CANONICAL** (active)
     - **Task 17.2:** Rejects legacy node types (`split`, `join`, `wait`) in `node_create` and `node_update`
     - **Task 17.2:** Validates multi outgoing edge intent and merge node topology

4. **UI Status:**
   - Legacy routing UI: ⚠️ **DEPRECATED** (read-only display)
   - DAG Designer (`routing_graph_designer.php`): ✅ **CANONICAL** (active)
     - **Task 17.2:** Legacy node types (`split`, `join`, `wait`) hidden from UI
     - **Task 17.2:** Validation prevents ambiguous graphs (multi outgoing edge must specify Parallel or Decision intent)

5. **Migration:**
   - V1 → V2 migration path exists
   - `LegacyRoutingAdapter` provides backward compatibility
   - All new development must use V2
   - **Task 17.2:** Legacy node types cannot be created (use Parallel Split or Merge nodes instead)

---

## Recommendations

1. **For New Development:**
   - ✅ Always use V2 (DAG Designer, `dag_routing_api.php`)
   - ❌ Never create new V1 routing records

2. **For Legacy Data:**
   - ✅ Keep V1 tables for historical access
   - ✅ Use `LegacyRoutingAdapter` for backward compatibility
   - ⚠️ Plan migration of remaining V1 data to V2

3. **For UI:**
   - ✅ Use DAG Designer for all new routing creation
   - ⚠️ Legacy routing UI can remain for read-only display
   - ⚠️ Plan deprecation of legacy routing UI

4. **For Code Cleanup:**
   - ⚠️ Remove `LegacyRoutingAdapter` after all callers migrate to V2
   - ⚠️ Delete `source/routing.php` after confirming no usage
   - ⚠️ Archive V1 tables after full migration complete

