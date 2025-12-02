# Investigation Report: Node Plan Assignment Persistence Failure

**Date:** December 2025  
**Issue:** `AssignmentEngine` logs "Assignment created via node_plan" but no `token_assignment` row is inserted into database.

---

## Executive Summary

**Root Cause Identified:** The `insertAssignmentWithMethod()` method (and `insertAssignment()`) are missing the required `id_node` column in their INSERT statements. The `token_assignment` table schema requires `id_node` (NOT NULL), but the INSERT statements omit this column, causing silent SQL failures.

**Additional Issues Found:**
1. No error checking after `prepare()` - if prepare fails, code continues and crashes on `bind_param()`
2. No error checking after `execute()` - if execute fails, code continues silently
3. Nested transaction issue - `assignOne()` starts its own transaction inside `handleTokenSpawn()`'s transaction

---

## STEP 1 — Verify where AssignmentEngine writes data

### Location: `source/BGERP/Service/AssignmentEngine.php`

**Method Chain:**
1. `assignOne()` (line 66) → calls `applyNodePlanAssignment()` (line 538)
2. `applyNodePlanAssignment()` (line 1250) → calls `insertAssignmentWithMethod()` (line 1291)
3. `insertAssignmentWithMethod()` (line 1109) → executes INSERT statement (line 1148-1168)
4. `logAssignmentToAssignmentLog()` (line 1302) → logs to `assignment_log` table

### Findings:

**1. Database Connection:**
- ✅ `insertAssignmentWithMethod()` uses `$db` parameter (tenant DB)
- ✅ `applyNodePlanAssignment()` receives `$db` from `assignOne()`
- ✅ `assignOne()` receives `$db` from `autoAssignOnSpawn()`
- ✅ `autoAssignOnSpawn()` receives `$db->getTenantDb()` from `dag_token_api.php`

**2. SQL Statement Analysis:**

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Lines:** 1148-1161

```php
$stmt = $db->prepare("
    INSERT INTO token_assignment (
        id_token, 
        assigned_to_user_id, 
        assigned_by_user_id,
        status, 
        assignment_method,
        assigned_at, 
        pinned_by, 
        pinned_at,
        pin_reason
    )
    VALUES (?, ?, ?, 'assigned', ?, NOW(), ?, IF(?, NOW(), NULL), ?)
");
```

**Schema Requirement (from `database/backups/current_schema_maison_atelier.sql`):**

```sql
CREATE TABLE `token_assignment` (
  `id_assignment` int(11) NOT NULL AUTO_INCREMENT,
  `id_token` int(11) NOT NULL COMMENT 'FK to flow_token.id_token',
  `id_node` int(11) NOT NULL COMMENT 'FK to routing_node.id_node',  -- ⚠️ REQUIRED, NOT NULL
  ...
```

**❌ CRITICAL ISSUE:** The INSERT statement is **missing `id_node`**, which is a **required NOT NULL column** in the schema.

**3. Error Handling:**

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Lines:** 1148-1168

```php
$stmt = $db->prepare("...");  // ❌ NO CHECK if $stmt is false
$stmt->bind_param('iiisiiis', ...);  // ❌ Will crash if prepare() failed
$stmt->execute();  // ❌ NO CHECK if execute() returns false
$stmt->close();  // ❌ Will crash if $stmt is false
```

**Issues:**
- No check if `prepare()` returns `false` (SQL syntax error, table doesn't exist, etc.)
- No check if `execute()` returns `false` (constraint violation, missing required column, etc.)
- If `prepare()` fails, `bind_param()` will throw "Call to a member function bind_param() on bool"
- If `execute()` fails, the error is silently ignored

---

## STEP 2 — Check for silent failures

### Helper Functions Used:

**File:** `source/global_function.php`  
**Lines:** 75-108

`db_fetch_one()` and `db_fetch_all()` **do check for prepare() failures**:
```php
$stmt = $db->prepare($sql);
if (!$stmt) {
    error_log("db_fetch_all prepare failed: " . $db->error);
    return [];
}
```

**However**, `insertAssignmentWithMethod()` **does NOT use these helpers** - it uses direct `mysqli` calls without error checking.

### Autocommit Status:

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Line:** 67

```php
private static function assignOne(\mysqli $db, int $tokenId, ?int $nodeId): void {
    $db->begin_transaction();  // ✅ Transaction started
    ...
    $db->commit();  // ✅ Committed on success
}
```

**Transaction Context:**
- `assignOne()` starts its own transaction (line 67)
- If INSERT fails, transaction should rollback (line 598: `$db->rollback()`)
- **BUT:** If `execute()` fails silently, no exception is thrown, so transaction commits anyway

---

## STEP 3 — Trace Transaction context

### Call Stack:

1. **`dag_token_api.php::handleTokenSpawn()`** (line 405)
   - Starts transaction: `$db->beginTransaction()` (line 482)
   - Calls: `AssignmentEngine::autoAssignOnSpawn($db->getTenantDb(), $tokenIds)` (line 714)
   - Commits: `$db->commit()` (line 776)

2. **`AssignmentEngine::autoAssignOnSpawn()`** (line 39)
   - Calls: `self::assignOne($db, (int)$id, null)` for each token (line 41)

3. **`AssignmentEngine::assignOne()`** (line 66)
   - Starts **nested transaction**: `$db->begin_transaction()` (line 67)
   - Calls: `self::applyNodePlanAssignment($db, $tokenId, $nodeId, $singleCandidate)` (line 538)
   - Commits: `$db->commit()` (line 547) **BEFORE** outer transaction commits

### Transaction Nesting Issue:

**Problem:** MySQL/MariaDB does **NOT support nested transactions**. When `assignOne()` calls `begin_transaction()`, it:
- If autocommit is ON: Creates a savepoint (if supported)
- If autocommit is OFF: Does nothing (transaction already active)

**In this case:**
- `handleTokenSpawn()` starts transaction (line 482)
- `assignOne()` calls `begin_transaction()` (line 67) - **does nothing** (transaction already active)
- `assignOne()` calls `commit()` (line 547) - **commits the outer transaction!**
- If later code in `handleTokenSpawn()` fails, the assignment is already committed

**However**, this is not the root cause - the assignment should still be inserted even with nested transactions.

---

## STEP 4 — Check DB routing / multi-tenant db resolution

### Database Connection Flow:

1. `dag_token_api.php::handleTokenSpawn()` (line 405)
   - Uses `$db` (DatabaseHelper instance)
   - Calls `$db->getTenantDb()` to get `mysqli` connection (line 714)

2. `AssignmentEngine::autoAssignOnSpawn()` (line 39)
   - Receives `\mysqli $db` (tenant DB connection)

3. `AssignmentEngine::assignOne()` (line 66)
   - Receives `\mysqli $db` (same tenant DB connection)

4. `AssignmentEngine::applyNodePlanAssignment()` (line 1250)
   - Receives `\mysqli $db` (same tenant DB connection)

5. `AssignmentEngine::insertAssignmentWithMethod()` (line 1109)
   - Receives `\mysqli $db` (same tenant DB connection)

**✅ Database routing is correct** - all methods use the same tenant DB connection.

---

## STEP 5 — Cross-check table name correctness

### Table Name:
- ✅ Code uses: `token_assignment` (correct)
- ✅ Schema has: `token_assignment` (matches)

### Column Names:

**Schema (from `database/backups/current_schema_maison_atelier.sql`):**
```sql
`id_token` int(11) NOT NULL
`id_node` int(11) NOT NULL  -- ⚠️ REQUIRED, NOT NULL
`assigned_to_user_id` int(11) NOT NULL
`assigned_by_user_id` int(11) NOT NULL  -- ⚠️ REQUIRED, NOT NULL (but INSERT allows NULL)
`status` enum(...) NOT NULL DEFAULT 'assigned'
`assignment_method` varchar(...)  -- ⚠️ Column may not exist (checked dynamically)
```

**INSERT Statement (line 1149-1160):**
```sql
INSERT INTO token_assignment (
    id_token,           ✅ Present
    assigned_to_user_id, ✅ Present
    assigned_by_user_id, ✅ Present (but can be NULL - schema requires NOT NULL)
    status,              ✅ Present
    assignment_method,   ✅ Present (if column exists)
    assigned_at,         ✅ Present
    pinned_by,           ✅ Present
    pinned_at,           ✅ Present
    pin_reason           ✅ Present
)
-- ❌ MISSING: id_node (REQUIRED, NOT NULL)
```

**❌ CRITICAL:** `id_node` is **missing** from the INSERT statement, but it's a **required NOT NULL column**.

### Primary Key:
- ✅ `id_assignment` is AUTO_INCREMENT (no issue)

### Triggers:
- ✅ No triggers found that would delete rows

---

## STEP 6 — Precise list of suspected root causes

### Root Cause #1: Missing `id_node` Column in INSERT (PRIMARY SUSPECT)

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Lines:** 1148-1161

**Issue:** The INSERT statement omits `id_node`, which is a **required NOT NULL column** in the `token_assignment` table schema.

**Evidence:**
- Schema: `id_node int(11) NOT NULL COMMENT 'FK to routing_node.id_node'`
- INSERT: Does not include `id_node` in column list
- Result: SQL error "Field 'id_node' doesn't have a default value" (or similar)

**Why it's silent:**
- No check after `prepare()` - if prepare fails, code continues
- No check after `execute()` - if execute fails, error is ignored
- Exception is caught by `applyNodePlanAssignment()`'s try-catch (line 1312), but only logs error and returns `false`

**Fix Required:**
- Add `id_node` to INSERT statement
- Pass `$nodeId` to `insertAssignmentWithMethod()` (currently not passed)
- Update `insertAssignment()` to also include `id_node`

---

### Root Cause #2: No Error Checking After `prepare()`

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Line:** 1148

**Issue:** If `prepare()` returns `false` (SQL syntax error, table doesn't exist, etc.), code continues and crashes on `bind_param()`.

**Evidence:**
```php
$stmt = $db->prepare("...");  // ❌ No check
$stmt->bind_param(...);  // ❌ Will crash if $stmt is false
```

**Impact:**
- If SQL has syntax error, `prepare()` returns `false`
- `bind_param()` throws "Call to a member function bind_param() on bool"
- Exception is caught, but assignment fails silently

**Fix Required:**
- Check if `$stmt` is `false` after `prepare()`
- Log error and return early if prepare fails

---

### Root Cause #3: No Error Checking After `execute()`

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Line:** 1167

**Issue:** If `execute()` returns `false` (constraint violation, missing column, etc.), error is silently ignored.

**Evidence:**
```php
$stmt->execute();  // ❌ No check if returns false
$stmt->close();  // Continues even if execute() failed
```

**Impact:**
- If INSERT fails (e.g., missing `id_node`), `execute()` returns `false`
- Code continues as if INSERT succeeded
- Transaction commits (no exception thrown)
- No row inserted, but log says "Assignment created via node_plan"

**Fix Required:**
- Check if `execute()` returns `false`
- Log error: `error_log("INSERT failed: " . $stmt->error)`
- Throw exception or return error status

---

### Root Cause #4: `assigned_by_user_id` NULL vs NOT NULL Mismatch

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Line:** 1152, 1166

**Issue:** Schema requires `assigned_by_user_id NOT NULL`, but INSERT allows `NULL` (for system assignments).

**Evidence:**
- Schema: `assigned_by_user_id int(11) NOT NULL`
- INSERT: `$assignedByUserId` can be `null` (line 1298: `null // assigned_by_user_id = NULL`)
- Bind: `bind_param('iiisiiis', ..., $assignedByUserId, ...)` where `$assignedByUserId` can be `null`

**Impact:**
- If `assigned_by_user_id` is `NULL`, INSERT will fail with "Field 'assigned_by_user_id' doesn't have a default value"
- Error is silently ignored (no check after `execute()`)

**Fix Required:**
- Use a system user ID (e.g., 0 or -1) instead of `NULL`
- Or update schema to allow `NULL` (if system assignments are intended)

---

### Root Cause #5: Nested Transaction Commit Timing

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Line:** 67, 547

**Issue:** `assignOne()` starts its own transaction and commits it before the outer transaction in `handleTokenSpawn()` completes.

**Evidence:**
- `handleTokenSpawn()`: `beginTransaction()` (line 482)
- `assignOne()`: `begin_transaction()` (line 67) - nested
- `assignOne()`: `commit()` (line 547) - commits outer transaction
- `handleTokenSpawn()`: `commit()` (line 776) - does nothing (already committed)

**Impact:**
- If assignment INSERT fails, `assignOne()` should rollback
- But if error is silent (no exception), transaction commits anyway
- Assignment appears committed but row doesn't exist

**Fix Required:**
- Remove nested transaction in `assignOne()` (use outer transaction)
- Or use savepoints if nested transactions are needed

---

## Summary of Evidence

### Confirmed Issues:

1. ✅ **Missing `id_node` in INSERT** - Schema requires it, INSERT omits it
2. ✅ **No error checking after `prepare()`** - Code continues if prepare fails
3. ✅ **No error checking after `execute()`** - Errors are silently ignored
4. ✅ **`assigned_by_user_id` NULL mismatch** - Schema requires NOT NULL, code passes NULL
5. ⚠️ **Nested transaction timing** - May cause issues but not primary cause

### Most Likely Root Cause:

**Root Cause #1: Missing `id_node` Column** is the **primary suspect** because:
- Schema clearly requires `id_node NOT NULL`
- INSERT statement clearly omits it
- This would cause `execute()` to fail with SQL error
- Error is silently ignored (no check after `execute()`)
- Log still says "Assignment created via node_plan" because exception is caught and logged, but `applyNodePlanAssignment()` returns `false` (line 1314), which should prevent the log... **unless the log is printed before checking the return value**

**Wait - let me check the log location again...**

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Lines:** 540-541

```php
if ($success) {
    error_log('[AssignmentEngine] Assignment created via node_plan');  // ⚠️ Log is INSIDE if ($success)
```

**This means:** If `applyNodePlanAssignment()` returns `false`, the log should NOT print. But user reports the log IS printing, which means `applyNodePlanAssignment()` is returning `true` even though the INSERT fails.

**This suggests:** The exception in `applyNodePlanAssignment()` (line 1312) is NOT being thrown, or the INSERT is succeeding in some way (perhaps a different code path).

**Let me check if there's a fallback path...**

**File:** `source/BGERP/Service/AssignmentEngine.php`  
**Line:** 1169-1171

```php
} else {
    // Fallback: use basic insertAssignment (without assignment_method/assigned_by)
    self::insertAssignment($db, $tokenId, $userId, $pinned, $assignmentMethod, $reason);
}
```

**Aha!** If `$hasMethodColumn` or `$hasAssignedByColumn` is `false`, it falls back to `insertAssignment()`, which also **omits `id_node`**.

**So both code paths have the same issue.**

---

## Recommended Investigation Steps

1. **Check MySQL error log** for SQL errors when assignment is attempted
2. **Add error logging** after `prepare()` and `execute()` to capture SQL errors
3. **Verify column existence** - check if `assignment_method` and `assigned_by_user_id` columns actually exist
4. **Check if `id_node` has a default value** - if it does, INSERT might succeed but with wrong value
5. **Add transaction logging** - log when transactions start/commit/rollback

---

## Files to Modify (When Fixing)

1. **`source/BGERP/Service/AssignmentEngine.php`**
   - Line 1109: `insertAssignmentWithMethod()` - Add `id_node` parameter and include in INSERT
   - Line 1060: `insertAssignment()` - Add `id_node` parameter and include in INSERT
   - Line 1148: Add error checking after `prepare()`
   - Line 1167: Add error checking after `execute()`
   - Line 1291: Pass `$nodeId` to `insertAssignmentWithMethod()`
   - Line 1171: Pass `$nodeId` to `insertAssignment()` (if fallback is used)

2. **All callers of `insertAssignmentWithMethod()` and `insertAssignment()`**
   - Ensure `$nodeId` is available and passed

---

**Investigation Complete**  
**Next Step:** Implement fixes based on root causes identified above.

