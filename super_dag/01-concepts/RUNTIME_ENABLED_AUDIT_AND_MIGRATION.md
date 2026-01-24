# Runtime Enabled Audit & Migration Plan

**Date:** 2025-12-12  
**Purpose:** Audit `RUNTIME_ENABLED` feature flag usage and plan migration to align with Graph Versioning architecture

---

## Executive Summary

**Current State:**
- `RUNTIME_ENABLED` is a **feature flag** (not a database field)
- Stored in `routing_graph_feature_flag` table with `flag_key = 'RUNTIME_ENABLED'`
- **Used only for:** Blocking `graph_runtime` API action (viewing graph in runtime mode)
- **NOT used for:** Job creation blocking, token execution, or live mutation

**Decision:**
- ✅ **Repurpose** (not delete) - Convert to "Allow New Jobs" at Published Version level
- ❌ **Do NOT delete** - Still has active usage in `graph_runtime` action

---

## 1. Current Usage Audit

### 1.1 Database Schema

**Table:** `routing_graph_feature_flag`
```sql
-- Feature flag storage
SELECT id_graph, flag_key, flag_value 
FROM routing_graph_feature_flag 
WHERE flag_key = 'RUNTIME_ENABLED';
```

**Note:** No `runtime_enabled` field in `routing_graph` table (uses feature flag instead)

### 1.2 Backend Usage

#### ✅ Active Usage (Must Keep)

**File:** `source/dag_routing_api.php`
- **Function:** `isGraphRuntimeEnabled($db, $graphId)` (lines 1103-1113)
- **Action:** `graph_runtime` (lines 4810-4858)
- **Purpose:** Blocks viewing graph in runtime mode if flag is 'off'
- **Impact:** Medium (affects runtime viewer, not job creation)

```php
// Check feature flag
if (!isGraphRuntimeEnabled($db, $graphId)) {
    json_error('runtime_disabled', 403, [
        'app_code' => 'DAG_ROUTING_403_RUNTIME_DISABLED',
        'message' => 'Graph runtime is disabled. Enable via feature flag.'
    ]);
}
```

#### ❌ NOT Used For (Critical Finding)

**Job Creation:**
- `JobCreationService::createDAGJob()` - **NO runtime check**
- `classic_api.php` action `ticket_create_from_graph` - **NO runtime check**
- `hatthasilpa_jobs_api.php` action `create` - **NO runtime check**

**Token Execution:**
- `TokenLifecycleService` - **NO runtime check**
- Token routing/assignment - **NO runtime check**

**Live Mutation:**
- System uses **snapshot from job creation** (not live graph)
- No dynamic graph reading during execution

### 1.3 Frontend Usage

**File:** `assets/javascripts/dag/graph_designer.js`
- **Lines 9426-9436:** Badge display "Runtime: ON/OFF"
- **Purpose:** Visual indicator only

**File:** `assets/javascripts/dag/modules/EventManager.js`
- **Lines 260-292:** `handleToggleRuntime()` function
- **Purpose:** Toggle feature flag via API

**File:** `assets/javascripts/dag/graph_sidebar.js`
- **Lines 433-434:** Badge display in sidebar
- **Purpose:** Visual indicator only

### 1.4 Metadata Repository

**File:** `source/dag/Graph/Repository/GraphMetadataRepository.php`
- **Lines 140-156:** Loads `runtime_enabled` from feature flags
- **Purpose:** Populate metadata for graph list/display

**File:** `source/dag/Graph/Service/GraphService.php`
- **Lines 407, 415:** Sets `runtime_enabled` in graph response
- **Purpose:** Include in API response

---

## 2. Analysis: What Does "Runtime" Mean?

### 2.1 Current Meaning (Actual Usage)

**Based on code audit:**
- **Meaning:** "Allow viewing graph in runtime mode" (via `graph_runtime` API)
- **NOT:** "Allow creating jobs" (no check in job creation)
- **NOT:** "Use live graph during execution" (uses snapshot)

**Conclusion:** Current usage is **misleading** - name suggests execution control, but only controls viewing.

### 2.2 Intended Meaning (Based on Architecture)

**According to AI analysis, "Runtime ON/OFF" typically means one of:**
1. ✅ **Execution enabled/disabled** (intended but NOT implemented)
2. ❌ **Live runtime mutation** (dangerous, not used)
3. ❌ **Feature flag** (current usage, but misleading name)

---

## 3. Migration Plan

### 3.1 Phase 1: Repurpose to "Allow New Jobs" (Recommended)

**Goal:** Convert `RUNTIME_ENABLED` to "Allow New Jobs" at Published Version level

#### Step 1: Create New Field in `routing_graph_version` Table

```sql
ALTER TABLE routing_graph_version 
ADD COLUMN allow_new_jobs TINYINT(1) DEFAULT 1 
COMMENT 'Allow creating new jobs with this version (0=disabled, 1=enabled)';
```

#### Step 2: Migrate Existing Feature Flags

```sql
-- Migrate existing RUNTIME_ENABLED flags to version level
-- Default: Published versions = enabled, Draft = disabled
INSERT INTO routing_graph_version (id_graph, version_number, allow_new_jobs, ...)
SELECT 
    rg.id_graph,
    1 as version_number,  -- Assume v1 for existing published graphs
    CASE 
        WHEN f.flag_value = 'on' THEN 1 
        ELSE 1  -- Default to enabled if no flag exists
    END as allow_new_jobs,
    ...
FROM routing_graph rg
LEFT JOIN routing_graph_feature_flag f 
    ON rg.id_graph = f.id_graph 
    AND f.flag_key = 'RUNTIME_ENABLED'
WHERE rg.status = 'published';
```

#### Step 3: Add Guard Check in Job Creation

**File:** `source/BGERP/Service/JobCreationService.php`

```php
// Add after line 79 (after $graphId assignment)
// Check if graph version allows new jobs
$graphVersion = $this->getGraphVersionForJob($graphId, $params['graph_version_id'] ?? null);
if (!$graphVersion || !($graphVersion['allow_new_jobs'] ?? true)) {
    throw new \Exception('Graph version does not allow new jobs. Version may be disabled or retired.');
}
```

#### Step 4: Update UI Labels

**File:** `assets/javascripts/dag/modules/EventManager.js`
- Change: "Toggle Runtime" → "Allow New Jobs"
- Change: "Runtime: ON/OFF" → "New Jobs: Enabled/Disabled"

**File:** `assets/javascripts/dag/graph_designer.js`
- Change badge: "Runtime: ON" → "New Jobs: Enabled"
- Change badge: "Runtime: OFF" → "New Jobs: Disabled"

#### Step 5: Deprecate Old Feature Flag (Keep for Backward Compatibility)

```php
// In isGraphRuntimeEnabled() - add deprecation warning
function isGraphRuntimeEnabled($db, $graphId): bool {
    // DEPRECATED: Use routing_graph_version.allow_new_jobs instead
    error_log("[DEPRECATED] isGraphRuntimeEnabled() called. Migrate to version-level allow_new_jobs.");
    
    // Fallback to feature flag for backward compatibility
    $flag = $db->fetchOne("...");
    return ($flag && ($flag['flag_value'] ?? 'off') === 'on');
}
```

### 3.2 Phase 2: Remove Legacy Feature Flag (After Migration Complete)

**Timeline:** After all job creation paths use version-level check

1. Remove `RUNTIME_ENABLED` from `routing_graph_feature_flag` table
2. Remove `isGraphRuntimeEnabled()` function
3. Remove UI toggle button (or repurpose to version-level toggle)
4. Update documentation

---

## 4. Implementation Checklist

### 4.1 Database Changes

- [ ] Add `allow_new_jobs` column to `routing_graph_version` table
- [ ] Create migration script to copy existing flags
- [ ] Add index on `allow_new_jobs` for performance

### 4.2 Backend Changes

- [ ] Add `allow_new_jobs` check in `JobCreationService::createDAGJob()`
- [ ] Add `allow_new_jobs` check in `classic_api.php` (if needed)
- [ ] Add `allow_new_jobs` check in `hatthasilpa_jobs_api.php` (if needed)
- [ ] Update `GraphVersionService::publish()` to set `allow_new_jobs = 1` by default
- [ ] Add deprecation warning to `isGraphRuntimeEnabled()`
- [ ] Update `GraphMetadataRepository` to load `allow_new_jobs` from version

### 4.3 Frontend Changes

- [ ] Rename "Runtime" to "Allow New Jobs" in UI
- [ ] Update badge labels
- [ ] Move toggle to Version Bar (version-level, not graph-level)
- [ ] Update tooltips and help text

### 4.4 Testing

- [ ] Test: Job creation blocked when `allow_new_jobs = 0`
- [ ] Test: Existing jobs continue running (not affected)
- [ ] Test: Migration script preserves existing behavior
- [ ] Test: UI toggle updates version-level flag
- [ ] Test: Backward compatibility (old feature flag still works during transition)

---

## 5. Decision Matrix

| Scenario | Current Behavior | Recommended Behavior |
|----------|------------------|----------------------|
| **Draft Graph** | Runtime flag exists | ❌ **Remove** - Drafts cannot be used for jobs anyway |
| **Published v1** | Runtime flag = 'on' | ✅ **Migrate** - Set `allow_new_jobs = 1` |
| **Published v1** | Runtime flag = 'off' | ✅ **Migrate** - Set `allow_new_jobs = 0` |
| **Retired Version** | Runtime flag exists | ✅ **Default** - Set `allow_new_jobs = 0` (retired = disabled) |
| **New Published Version** | No flag | ✅ **Default** - Set `allow_new_jobs = 1` (enabled by default) |

---

## 6. Risk Assessment

### 6.1 Low Risk (Safe to Proceed)

- ✅ Feature flag is **NOT** used in job creation (no breaking change)
- ✅ Only affects `graph_runtime` API (viewing, not execution)
- ✅ Migration can be done incrementally

### 6.2 Medium Risk (Requires Care)

- ⚠️ UI changes may confuse users (need clear messaging)
- ⚠️ Migration script must handle edge cases (missing flags, multiple versions)

### 6.3 High Risk (Requires Testing)

- 🔴 Job creation blocking is **new behavior** (must test thoroughly)
- 🔴 Version-level toggle is **new concept** (must update UX)

---

## 7. Alternative: Keep Feature Flag (Not Recommended)

**If migration is too risky, alternative:**
- Keep `RUNTIME_ENABLED` feature flag for `graph_runtime` API
- Add **separate** `allow_new_jobs` field for job creation
- **Problem:** Two flags doing similar things = confusion

**Recommendation:** Proceed with migration (Phase 1) for clarity.

---

## 8. References

- **Graph Versioning Concept:** `docs/super_dag/01-concepts/GRAPH_VERSIONING_AND_PRODUCT_BINDING.md`
- **Current Feature Flag Implementation:** `source/dag_routing_api.php` (lines 1103-1113)
- **Job Creation Service:** `source/BGERP/Service/JobCreationService.php`

---

## 9. Summary

**Current State:**
- `RUNTIME_ENABLED` = Feature flag for viewing graph (misleading name)
- **NOT** used for job creation blocking
- **NOT** used for execution control

**Recommended Action:**
1. ✅ **Repurpose** to "Allow New Jobs" at Published Version level
2. ✅ **Migrate** existing flags to `routing_graph_version.allow_new_jobs`
3. ✅ **Add guard check** in job creation
4. ✅ **Update UI** labels and move toggle to Version Bar
5. ✅ **Deprecate** old feature flag (keep for backward compatibility)

**Timeline:** Phase 1 (Repurpose) = 1-2 weeks, Phase 2 (Remove) = After migration complete

**Status:** ✅ **READY FOR IMPLEMENTATION**

