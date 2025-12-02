# Feature Flags - DAG Routing Graph Designer

**Date:** November 11, 2025  
**Status:** ✅ Complete  
**Purpose:** Document all feature flags for DAG Routing Graph Designer

---

## Overview

Feature flags allow gradual rollout and safe rollback of new features. All flags are stored in `routing_graph_feature_flag` table and can be set per-graph or globally.

---

## Feature Flags List

### **FF_DASHBOARD_ENABLED** (Phase 10 - T34)

**Type:** String (rollout phase)  
**Default:** `'admin'`  
**Scope:** Per-tenant (tenant_feature_flags table)  
**Purpose:** Gradual rollout control for Production Dashboard

**Values:**
- `'off'` - Disabled for all users
- `'admin'` - Admin role only (beta phase)
- `'manager'` - Admin + Production Manager roles (expanded beta)
- `'on'` - All users with `dashboard.production.view` permission

**Rollout Plan:**
1. **Week 1:** Admin-only beta (`'admin'`)
2. **Week 2:** Manager access (`'manager'`)
3. **Week 3+:** All users (`'on'`)

**Access Control:**
- Platform Super Admin: Always has access (bypass)
- Admin role: Access when flag = `'admin'`, `'manager'`, or `'on'`
- Production Manager role: Access when flag = `'manager'` or `'on'`
- All users: Access when flag = `'on'`

**Usage:**
```php
$featureFlagService = new FeatureFlagService($tenantDb);
$rolloutPhase = $featureFlagService->getFlag('FF_DASHBOARD_ENABLED', $tenantId);

// Check access
if ($rolloutPhase === 'off') {
    // Disabled
} elseif ($rolloutPhase === 'on') {
    // All users
} elseif ($rolloutPhase === 'admin') {
    // Admin only
} elseif ($rolloutPhase === 'manager') {
    // Admin + Manager
}
```

**Implementation:**
- `source/dashboard_api.php` - `checkDashboardAccess()` function
- `page/production_dashboard.php` - Feature flag check before page load
- `source/BGERP/Service/FeatureFlagService.php` - Added to DEFAULT_FLAGS

---

### **FF_TRACE_ENABLED** (Phase 11 - T40)

**Type:** String (rollout phase)  
**Default:** `'admin'`  
**Scope:** Per-tenant (tenant_feature_flags table)  
**Purpose:** Gradual rollout control for Product Traceability Dashboard

**Values:**
- `'off'` - Disabled for all users
- `'admin'` - Admin role only (beta phase)
- `'manager'` - Admin + Production Manager roles (expanded beta)
- `'on'` - All users with `trace.view` permission

**Rollout Plan:**
1. **Week 1:** Admin-only beta (`'admin'`)
2. **Week 2:** Manager access (`'manager'`)
3. **Week 3+:** All users (`'on'`)

**Access Control:**
- Platform Super Admin: Always has access (bypass)
- Admin role: Access when flag = `'admin'`, `'manager'`, or `'on'`
- Production Manager role: Access when flag = `'manager'` or `'on'`
- All users: Access when flag = `'on'`

**Usage:**
```php
$featureFlagService = new FeatureFlagService($tenantDb);
$rolloutPhase = $featureFlagService->getFlag('FF_TRACE_ENABLED', $tenantId);

// Check access
if ($rolloutPhase === 'off') {
    // Disabled
} elseif ($rolloutPhase === 'on') {
    // All users
} elseif ($rolloutPhase === 'admin') {
    // Admin only
} elseif ($rolloutPhase === 'manager') {
    // Admin + Manager
}
```

**Implementation:**
- `source/trace_api.php` - `checkTraceAccess()` function
- `page/product_traceability.php` - Feature flag check before page load
- `source/BGERP/Service/FeatureFlagService.php` - Added to DEFAULT_FLAGS

---

## Feature Flags List

### 1. **schema_validation_enabled**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Enable strict schema validation (Phase 3)

**When Enabled:**
- Validates all Phase 5 fields (split_policy, join_type, form_schema_json, etc.)
- Rejects graphs with missing required fields
- Enforces semantic rules (default edge, QC rework)

**When Disabled:**
- Allows backward compatibility with old graphs
- Skips schema validation checks
- Still validates structure (START/END, cycles)

**API:**
```php
// Get flag
GET /source/dag_routing_api.php?action=graph_flag_get&id_graph=123&flag_key=schema_validation_enabled

// Set flag
POST /source/dag_routing_api.php
{
    "action": "graph_flag_set",
    "id_graph": 123,
    "flag_key": "schema_validation_enabled",
    "flag_value": true
}
```

---

### 2. **protect_purge_edges**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Prevent accidental deletion of all edges

**When Enabled:**
- Requires `confirm_purge=1` to delete all edges
- Prevents auto-save from accidentally purging edges
- Shows warning dialog before purge

**When Disabled:**
- Allows deletion without confirmation
- ⚠️ **Dangerous:** Can cause data loss

**API:** Same as above

---

### 3. **draft_soft_validate_on_save**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Soft validation for draft graphs (Phase 3)

**When Enabled:**
- Collects validation errors as warnings (not blocking)
- Allows saving incomplete graphs
- Still blocks publish if errors exist

**When Disabled:**
- Hard validation (blocks save if errors)
- ⚠️ **Strict:** May prevent saving work-in-progress graphs

**API:** Same as above

---

### 4. **enforce_if_match**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Enforce ETag/If-Match header for concurrency control

**When Enabled:**
- Requires `If-Match` header for save/publish operations
- Returns 409 Conflict if ETag mismatch
- Prevents concurrent modification conflicts

**When Disabled:**
- Allows save without ETag check
- ⚠️ **Risky:** May cause data loss in concurrent scenarios

**API:** Same as above

---

### 5. **audit_logging_enabled**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Enable audit logging (R8: Audit Trail)

**When Enabled:**
- Logs all save/publish operations to `routing_audit_log`
- Records before/after state hashes
- Tracks who, when, what changed

**When Disabled:**
- Skips audit logging
- Reduces database writes (performance optimization)

**API:** Same as above

---

### 6. **enable_advanced_nodes**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Global (can be per-graph)  
**Purpose:** Enable advanced node types (split, join, qc, decision)

**When Enabled:**
- Shows split/join/qc/decision nodes in palette
- Allows creating parallel workflows
- Enables Phase 5 features

**When Disabled:**
- Hides advanced nodes from palette
- Only allows basic nodes (start, operation, end)
- Backward compatibility mode

**API:** Same as above (set `id_graph=0` for global)

---

### 7. **enable_join_quorum**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Enable N_OF_M join with quorum

**When Enabled:**
- Allows setting `join_quorum` for N_OF_M joins
- Validates quorum value (1 ≤ quorum ≤ incoming edges)
- Enables partial completion scenarios

**When Disabled:**
- Only allows AND/OR joins
- Ignores `join_quorum` field

**API:** Same as above

---

### 8. **enable_subgraph**

**Type:** Boolean  
**Default:** `false`  
**Scope:** Per-graph  
**Purpose:** Enable subgraph nodes (call activity)

**When Enabled:**
- Allows creating subgraph nodes
- Validates subgraph_ref_version (must be published)
- Enables nested graph workflows

**When Disabled:**
- Hides subgraph node from palette
- Blocks subgraph creation

**API:** Same as above

**Note:** Currently disabled by default (future enhancement)

---

### 9. **enable_graph_simulate**

**Type:** Boolean  
**Default:** `true`  
**Scope:** Per-graph  
**Purpose:** Enable graph simulation feature

**When Enabled:**
- Shows "Simulate" button in toolbar
- Allows running `graph_simulate` API
- Shows critical path and bottlenecks

**When Disabled:**
- Hides simulate button
- Blocks simulation API calls

**API:** Same as above

---

## Default Values

| Flag | Default | Can Override |
|------|---------|--------------|
| `schema_validation_enabled` | `true` | ✅ Yes |
| `protect_purge_edges` | `true` | ✅ Yes |
| `draft_soft_validate_on_save` | `true` | ✅ Yes |
| `enforce_if_match` | `true` | ✅ Yes |
| `audit_logging_enabled` | `true` | ✅ Yes |
| `enable_advanced_nodes` | `true` | ✅ Yes |
| `enable_join_quorum` | `true` | ✅ Yes |
| `enable_subgraph` | `false` | ✅ Yes |
| `enable_graph_simulate` | `true` | ✅ Yes |

---

## Usage Examples

### Enable Feature for Specific Graph

```php
// Via API
POST /source/dag_routing_api.php
{
    "action": "graph_flag_set",
    "id_graph": 123,
    "flag_key": "enable_subgraph",
    "flag_value": true
}
```

### Disable Feature Globally

```php
// Set for all graphs (id_graph = 0)
POST /source/dag_routing_api.php
{
    "action": "graph_flag_set",
    "id_graph": 0,
    "flag_key": "enable_subgraph",
    "flag_value": false
}
```

### Get All Flags for Graph

```php
GET /source/dag_routing_api.php?action=graph_flag_get&id_graph=123
```

**Response:**
```json
{
    "ok": true,
    "flags": {
        "schema_validation_enabled": true,
        "protect_purge_edges": true,
        "draft_soft_validate_on_save": true,
        "enforce_if_match": true,
        "audit_logging_enabled": true,
        "enable_advanced_nodes": true,
        "enable_join_quorum": true,
        "enable_subgraph": false,
        "enable_graph_simulate": true
    }
}
```

---

## Rollback Procedure

### If Feature Causes Issues

1. **Disable Feature:**
   ```php
   POST /source/dag_routing_api.php
   {
       "action": "graph_flag_set",
       "id_graph": 123,
       "flag_key": "problematic_flag",
       "flag_value": false
   }
   ```

2. **Verify Behavior:**
   - Test affected functionality
   - Check logs for errors
   - Monitor metrics

3. **Fix Issue:**
   - Debug root cause
   - Apply fix
   - Re-enable feature

4. **Re-enable Feature:**
   ```php
   POST /source/dag_routing_api.php
   {
       "action": "graph_flag_set",
       "id_graph": 123,
       "flag_key": "problematic_flag",
       "flag_value": true
   }
   ```

---

## Migration Notes

### From Old System

If migrating from old system without feature flags:

1. **Set Defaults:**
   ```sql
   INSERT INTO routing_graph_feature_flag (id_graph, flag_key, flag_value)
   SELECT id_graph, 'schema_validation_enabled', true FROM routing_graph;
   -- Repeat for other flags
   ```

2. **Verify:**
   ```sql
   SELECT id_graph, flag_key, flag_value 
   FROM routing_graph_feature_flag 
   WHERE id_graph = 123;
   ```

---

## Best Practices

1. **Test Before Enabling:**
   - Enable on test graph first
   - Verify behavior
   - Then enable on production graphs

2. **Monitor After Enabling:**
   - Check error logs
   - Monitor performance metrics
   - Watch for user complaints

3. **Document Changes:**
   - Record flag changes in changelog
   - Update user documentation
   - Notify team members

4. **Use Gradual Rollout:**
   - Enable for 1 graph first
   - Then 10% of graphs
   - Then 50%
   - Finally 100%

---

## Troubleshooting

### Flag Not Taking Effect

1. **Check Flag Value:**
   ```sql
   SELECT * FROM routing_graph_feature_flag 
   WHERE id_graph = 123 AND flag_key = 'flag_name';
   ```

2. **Check API Response:**
   ```bash
   curl "http://localhost/source/dag_routing_api.php?action=graph_flag_get&id_graph=123"
   ```

3. **Check Code Logic:**
   - Verify flag is checked in code
   - Check default value fallback
   - Review flag precedence

### Flag Conflicts

If multiple flags conflict:

1. **Priority Order:**
   - Per-graph flags override global flags
   - Explicit flags override defaults
   - Hard-coded defaults are last resort

2. **Resolution:**
   - Review flag logic
   - Update precedence rules
   - Document conflicts

---

## Related Documentation

- `FULL_DAG_DESIGNER_ROADMAP.md` - Complete roadmap
- `CURRENT_STATUS.md` - Current implementation status
- `REMAINING_TASKS.md` - Remaining tasks

---

**Last Updated:** November 11, 2025  
**Next Review:** February 11, 2026 (Quarterly)

