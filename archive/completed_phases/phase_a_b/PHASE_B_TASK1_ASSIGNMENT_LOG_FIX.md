# Phase B - Task 1: Assignment Log bind_param Fix

**Date:** 2025-11-13  
**Status:** ✅ COMPLETED  
**Phase:** B (Runtime Routing Engine Hardening)  
**Priority:** Critical (P0) - Causes runtime failures

---

## Problem Summary

### Bug Description
The `assignment_log` INSERT statements had a **bind_param mismatch** where 8 placeholders were provided but only 7 type specifiers, causing MySQL binding errors at runtime.

**Pattern:**
```php
// ❌ WRONG: 8 params but only 7 types
$stmt->bind_param('iisissi',  // Only 7 characters
    $tokenId,                  // 1: i
    $nodeId,                   // 2: i
    $assignedToType,           // 3: s
    $assignedToId,             // 4: i
    $method,                   // 5: s
    $reasonJson,               // 6: s
    $queueReason,              // 7: s
    $estimatedWaitMinutes      // 8: ??? (missing type!)
);
```

### Impact
- ❌ Runtime failures when logging assignments
- ❌ Silent failures (no assignment logs created)
- ❌ Unable to track token assignment history
- ❌ Debugging difficulties for routing issues

---

## Root Cause

The INSERT statement for `assignment_log` includes **8 columns** (excluding auto-generated and default columns):

```sql
INSERT INTO assignment_log 
(token_id, node_id, assigned_to_type, assigned_to_id, method, reason_json, queue_reason, estimated_wait_minutes, created_by)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
```

**Column count:** 8 placeholders (created_by = NULL, not counted in bind)

**Expected types:**
1. `token_id` → `i` (integer)
2. `node_id` → `i` (integer)
3. `assigned_to_type` → `s` (string/ENUM)
4. `assigned_to_id` → `i` (integer)
5. `method` → `s` (string)
6. `reason_json` → `s` (string/JSON)
7. `queue_reason` → `s` (string, nullable)
8. `estimated_wait_minutes` → `i` (integer, nullable)

**Correct type string:** `'iisisssi'` (8 characters)

---

## Files Fixed

### 1. TokenLifecycleService.php

**File:** `/source/BGERP/Service/TokenLifecycleService.php`  
**Line:** 843

**Before:**
```php
$stmt->bind_param('iisissi',  // ❌ Only 7 types
    $tokenId, 
    $nodeId, 
    $assignedToType, 
    $assignedToId, 
    $method, 
    $reasonJson,
    $queueReason,
    $estimatedWaitMinutes  // Missing type!
);
```

**After:**
```php
// ✅ FIXED: bind_param type string corrected (was 'iisissi' with 8 params)
// Params: token_id(i), node_id(i), assigned_to_type(s), assigned_to_id(i), 
//         method(s), reason_json(s), queue_reason(s), estimated_wait_minutes(i)
$stmt->bind_param('iisisssi',  // ✅ 8 types
    $tokenId, 
    $nodeId, 
    $assignedToType, 
    $assignedToId, 
    $method, 
    $reasonJson,
    $queueReason,
    $estimatedWaitMinutes
);
```

---

### 2. DAGRoutingService.php

**File:** `/source/BGERP/Service/DAGRoutingService.php`  
**Line:** 1136

**Before:**
```php
$stmt->bind_param('iisissi',  // ❌ Only 7 types
    $tokenId, 
    $nodeId, 
    $assignedToType, 
    $assignedToId, 
    $method, 
    $reasonJson,
    $queueReason,
    $estimatedWaitMinutes  // Missing type!
);
```

**After:**
```php
// ✅ FIXED: bind_param type string corrected (was 'iisissi' with 8 params)
// Params: token_id(i), node_id(i), assigned_to_type(s), assigned_to_id(i), 
//         method(s), reason_json(s), queue_reason(s), estimated_wait_minutes(i)
$stmt->bind_param('iisisssi',  // ✅ 8 types
    $tokenId, 
    $nodeId, 
    $assignedToType, 
    $assignedToId, 
    $method, 
    $reasonJson,
    $queueReason,
    $estimatedWaitMinutes
);
```

---

### 3. assignment_api.php (Already Correct)

**File:** `/source/assignment_api.php`  
**Line:** 1010

**Status:** ✅ Already correct (7 params with 7 types)

This INSERT uses **different columns** (no `queue_reason`, `estimated_wait_minutes`):

```sql
INSERT INTO assignment_log 
(token_id, node_id, assigned_to_type, assigned_to_id, method, reason_json, created_by)
VALUES (?, ?, ?, ?, ?, ?, ?)
```

**Current (Correct):**
```php
// ✅ CORRECT: 7 params with 7 types
// Params: token_id(i), node_id(i), assigned_to_type(s), assigned_to_id(i),
//         method(s), reason_json(s), created_by(i)
$stmt->bind_param('iisissi',  // ✅ 7 types for 7 params
    $tokenId, 
    $nodeId, 
    $assignedToType, 
    $assignedToId, 
    $method, 
    $reasonJson,
    $member['id_member']
);
```

---

## Testing

### Manual Test
```php
// Test assignment logging
$tokenId = 1001;
$nodeId = 501;
$assignedToType = 'operator';
$assignedToId = 25;
$method = 'AUTO_ASSIGN';
$reasonJson = '{"rule":"team_preference"}';
$queueReason = null;
$estimatedWaitMinutes = null;

// This should now work without errors
$stmt->bind_param('iisisssi', 
    $tokenId, $nodeId, $assignedToType, $assignedToId,
    $method, $reasonJson, $queueReason, $estimatedWaitMinutes
);
$stmt->execute();

// Verify log created
$result = $db->query("SELECT * FROM assignment_log WHERE token_id = 1001");
assert($result->num_rows === 1); // ✅ Log created successfully
```

### Runtime Test
1. Create a token
2. Route to an operation node
3. Trigger auto-assignment
4. Check `assignment_log` table

**Expected:**
- ✅ No bind_param errors
- ✅ Assignment log record created
- ✅ All 8 columns populated correctly

---

## Type String Reference

For future reference, here's the mapping:

| MySQL Type | bind_param Code | Example |
|------------|----------------|---------|
| INT, TINYINT, BIGINT | `i` | `$tokenId` |
| VARCHAR, TEXT, ENUM | `s` | `$method` |
| DOUBLE, FLOAT | `d` | `$price` |
| BLOB | `b` | `$binaryData` |

**Common mistakes:**
- ❌ Counting placeholders wrong
- ❌ Missing types for NULL-able parameters
- ❌ Using wrong type (e.g., `i` for ENUM)

---

## Impact Assessment

### Before Fix
```
Token routing → Assignment → Log insertion
                              ↓
                           ❌ bind_param error
                              ↓
                           Silent failure
                              ↓
                           No assignment history
```

### After Fix
```
Token routing → Assignment → Log insertion
                              ↓
                           ✅ Correct binding
                              ↓
                           Assignment logged
                              ↓
                           Full traceability ✅
```

---

## Related Issues

This fix is part of **Phase B — Runtime Routing Engine Hardening**:

1. ✅ **Task 1: Assignment Log bug** (This document)
2. ⏳ Task 2: Define token_assignment.status meanings
3. ⏳ Task 3: Fix concurrency_limit logic
4. ⏳ Task 4: Queue position improvements

---

## Verification Checklist

- [x] Fixed TokenLifecycleService.php (line 843)
- [x] Fixed DAGRoutingService.php (line 1136)
- [x] Verified assignment_api.php (already correct)
- [x] Added explanatory comments
- [x] Type string matches parameter count
- [x] All 8 parameters mapped correctly
- [x] No runtime errors expected

---

## Notes for Future Development

1. **Always verify bind_param type string length matches parameter count**
2. **Add unit tests for INSERT statements with many parameters**
3. **Consider using named parameters (PDO) for better clarity**
4. **Add static analysis to detect bind_param mismatches**

---

**Completed by:** AI Agent (Droid)  
**Date:** 2025-11-13  
**Session:** Phase B - Runtime Engine Hardening  
**Impact:** High (Fixes critical runtime bug)
