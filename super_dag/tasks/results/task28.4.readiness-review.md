# Task 28.5 Readiness Review

**Date:** December 12, 2025  
**Reviewer:** AI Assistant  
**Purpose:** Comprehensive readiness check before implementing Task 28.5 (GraphVersionService::publish())

---

## ✅ **Dependencies Status**

### Task 28.4: Database Schema Updates
**Status:** ✅ **COMPLETE**

- [x] Schema migration script created: `database/tenant_migrations/2025_12_graph_versioning_schema.php`
- [x] New fields added:
  - `status` (VARCHAR(20) NULL) - published/retired
  - `allow_new_jobs` (TINYINT(1) NOT NULL DEFAULT 1)
  - `config_json` (JSON NULL)
- [x] Indexes added:
  - `idx_status` - Single column
  - `idx_graph_status` - Composite (id_graph, status)
  - `idx_allow_new_jobs` - Single column
- [x] Schema documentation updated
- [x] Migration script is idempotent and backward compatible

**Ready for Task 28.5:** ✅ Yes

---

## 🔍 **Current Implementation Analysis**

### 1. Existing Publish Logic

**Location:** `source/dag_routing_api.php` (lines 2791-3161)  
**Action:** `case 'graph_publish'`

#### Current Flow:
1. ✅ Validation (schema check, request validation)
2. ✅ Graph existence check
3. ✅ ETag/optimistic locking check
4. ✅ Load from draft OR live graph
5. ✅ Graph validation (GraphValidationEngine)
6. ⚠️ **Create version snapshot** (line 3039-3053)
   - Uses old schema (no `status`, `allow_new_jobs`, `config_json`)
   - Version string format: `"{integer}.0"` (e.g., "2.0")
7. ⚠️ **Update routing_graph** (line 3059-3075)
   - Sets `status = 'published'`
   - Updates `version` (INT) field
   - Bumps `row_version`
8. ✅ Mark draft as discarded (line 3099-3106)
9. ✅ Audit logging
10. ✅ Metrics tracking

#### Issues Found:

**Issue 1: Missing New Schema Fields**
```php
// Current code (line 3039-3053):
INSERT INTO routing_graph_version 
(id_graph, version, payload_json, metadata_json, published_at, published_by)
VALUES (?, ?, ?, ?, NOW(), ?)
```
**Problem:** Doesn't set `status`, `allow_new_jobs`, or `config_json`

**Fix Needed:**
```php
INSERT INTO routing_graph_version 
(id_graph, version, payload_json, metadata_json, published_at, published_by, status, allow_new_jobs, config_json)
VALUES (?, ?, ?, ?, NOW(), ?, 'published', 1, ?)
```

**Issue 2: Version String Generation**
```php
// Current code (line 3034-3036):
$currentVersion = (int)($graph['version'] ?? 1);
$newVersion = $currentVersion + 1;
$versionString = (string)$newVersion . '.0';
```
**Problem:** Uses `routing_graph.version` (INT) field, but should use MAX from `routing_graph_version` for better accuracy

**Fix Needed:**
```php
// Get latest version from routing_graph_version (more accurate)
$latestVersion = $db->fetchOne("
    SELECT version FROM routing_graph_version 
    WHERE id_graph = ? 
    ORDER BY published_at DESC LIMIT 1
", [$graphId], 'i');

// Parse version string (e.g., "2.0" -> 2, "3.1" -> 3)
$versionParts = explode('.', $latestVersion['version'] ?? '1.0');
$currentMajor = (int)($versionParts[0] ?? 1);
$newVersionString = ($currentMajor + 1) . '.0';
```

**Issue 3: No New Draft Creation**
**Problem:** Task 28.5 spec requires "Auto-create new draft after publish" but current code doesn't do this.

**Fix Needed:** After successful publish, create new active draft from published version.

---

### 2. GraphVersionService Current State

**Location:** `source/dag/Graph/Service/GraphVersionService.php`

**Status:**
- ✅ Class exists
- ✅ Constructor ready
- ✅ `publish()` method signature defined (stub only)
- ✅ `compareVersions()` implemented (good reference)
- ✅ `listVersions()` implemented (good reference)

**Ready for Implementation:** ✅ Yes

---

### 3. Dependencies Check

#### Required Services/Repositories:

1. **GraphRepository** ✅
   - Location: `source/dag/Graph/Repository/GraphRepository.php`
   - Methods available: `findById()`, `findNodes()`, `findEdges()`
   - Status: ✅ Ready

2. **GraphDraftService** ✅
   - Location: `source/dag/Graph/Service/GraphDraftService.php`
   - Methods: Should have draft creation methods
   - Status: Need to check for `createDraft()` method

3. **GraphValidationEngine** ✅
   - Used in current publish logic (line 2990)
   - Status: ✅ Available

4. **DatabaseHelper** ✅
   - Used by GraphVersionService constructor
   - Status: ✅ Available

#### Potential Missing Dependencies:

- **GraphDraftService::createDraft()** - Need to verify if exists
- **Transaction management** - Need DatabaseTransaction service?

---

## 🎯 **Task 28.5 Requirements**

From `task28_GRAPH_VERSIONING_IMPLEMENTATION.md`:

**What:**
- [ ] Implement `publish()` method in `GraphVersionService`
- [ ] Create immutable snapshot in `routing_graph_version`
- [ ] Auto-increment version number
- [ ] Auto-create new draft after publish
- [ ] Update graph status to 'published'
- [ ] Add transaction safety

**Acceptance Criteria:**
- [ ] Publish creates immutable snapshot
- [ ] Version number auto-increments
- [ ] New draft created automatically
- [ ] Transaction rollback on failure
- [ ] Audit log entry created
- [ ] Uses new schema fields (`status`, `allow_new_jobs`, `config_json`)

---

## ⚠️ **Potential Spaghetti Code Issues**

### 1. Version Numbering Logic Duplication

**Problem:** Current logic in `dag_routing_api.php` uses `routing_graph.version` (INT), but version strings are stored in `routing_graph_version.version` (VARCHAR).

**Risk:** If logic is duplicated instead of centralized, inconsistencies may occur.

**Solution:** Centralize version numbering in `GraphVersionService::publish()`.

---

### 2. Draft Management Scattered

**Problem:** Draft discard logic is in `dag_routing_api.php`, draft creation might be elsewhere.

**Risk:** Draft lifecycle management is not centralized.

**Solution:** Use `GraphDraftService` for all draft operations.

---

### 3. Graph Status Updates Duplicated

**Problem:** `routing_graph.status` and `routing_graph_version.status` are separate fields.

**Risk:** Confusion between graph-level status and version-level status.

**Solution:** 
- Graph-level `status` = overall state (draft/published)
- Version-level `status` = version state (published/retired)

Ensure both are updated correctly.

---

### 4. Transaction Management

**Problem:** Current code uses `$db->beginTransaction()` directly in API file.

**Risk:** Transaction management scattered across API files.

**Solution:** Use `DatabaseTransaction` service for better error handling.

---

## 📋 **Implementation Checklist**

### Pre-Implementation:

- [ ] Verify `GraphDraftService::createDraft()` exists or needs to be created
- [ ] Verify `DatabaseTransaction` service usage pattern
- [ ] Review `GraphSaveEngine` for draft creation patterns
- [ ] Check if `config_json` needs to be populated from graph-level config

### Implementation Steps:

1. [ ] Implement `GraphVersionService::publish()` core logic
2. [ ] Add version string generation (use MAX from routing_graph_version)
3. [ ] Add new schema fields (status, allow_new_jobs, config_json)
4. [ ] Add transaction wrapping
5. [ ] Add draft creation after publish
6. [ ] Add error handling and rollback
7. [ ] Update `dag_routing_api.php` to use GraphVersionService
8. [ ] Add unit tests

### Post-Implementation:

- [ ] Test with existing graphs
- [ ] Test with draft graphs
- [ ] Test transaction rollback
- [ ] Verify new draft creation
- [ ] Verify schema fields populated correctly

---

## 🔧 **Recommended Implementation Approach**

### Option A: Refactor Existing Code (Recommended)

**Steps:**
1. Extract publish logic from `dag_routing_api.php` to `GraphVersionService::publish()`
2. Update logic to use new schema fields
3. Add draft creation
4. Update API endpoint to call service method

**Benefits:**
- Centralized business logic
- Easier to test
- Reusable

### Option B: Implement from Scratch

**Steps:**
1. Implement `GraphVersionService::publish()` from scratch
2. Keep old API logic temporarily
3. Migrate API endpoint after testing

**Benefits:**
- Clean implementation
- No legacy code baggage

**Recommended:** Option A (refactor existing code) - less risk, maintains backward compatibility

---

## ✅ **Readiness Conclusion**

**Overall Status:** ✅ **READY** with minor concerns

**Blockers:** None

**Concerns:**
1. Need to verify `GraphDraftService::createDraft()` method
2. Need to decide on `config_json` population logic
3. Need to ensure version string generation is consistent

**Recommendations:**
1. Verify draft service methods before starting
2. Start with Option A (refactor) approach
3. Add comprehensive error handling
4. Test thoroughly with existing data

---

## 📝 **Next Steps**

1. **Verify Dependencies:**
   ```bash
   # Check GraphDraftService methods
   grep -r "createDraft\|create.*draft" source/dag/Graph/Service/
   ```

2. **Start Implementation:**
   - Begin with `GraphVersionService::publish()` method
   - Follow existing patterns from `compareVersions()` and `listVersions()`
   - Use transaction management from current publish logic

3. **Testing Plan:**
   - Test with existing published graphs
   - Test with draft graphs
   - Test transaction rollback scenarios
   - Verify new schema fields

**Ready to proceed:** ✅ Yes

