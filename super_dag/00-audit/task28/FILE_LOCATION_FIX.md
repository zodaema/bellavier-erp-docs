# Task 28.x - File Location Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (404 Not Found Error)

---

## Problem

Frontend was calling `source/dag_graph_api.php` but the file was located at `source/dag/dag_graph_api.php`, causing 404 Not Found errors.

**Error:**
```
http://localhost:8888/bellavier-group-erp/source/dag_graph_api.php?action=graph_get&id=1957
→ 404 Not Found
```

---

## Root Cause

**File Structure:**
- `dag_routing_api.php` → Located at `source/dag_routing_api.php` (root of source/)
- `dag_graph_api.php` → Was located at `source/dag/dag_graph_api.php` (subdirectory)

**Frontend Expectation:**
- All API files should be at `source/` level (consistent with `dag_routing_api.php`)

---

## Solution

**Action:** Copied `dag_graph_api.php` from `source/dag/` to `source/` and adjusted bootstrap path.

**Changes:**
1. Copied file: `source/dag/dag_graph_api.php` → `source/dag_graph_api.php`
2. Fixed bootstrap path: `require_once __DIR__ . '/_bootstrap.php'` → `require_once __DIR__ . '/dag/_bootstrap.php'`

**Result:**
- File now accessible at `source/dag_graph_api.php` (matches frontend expectation)
- Bootstrap path correctly points to `source/dag/_bootstrap.php`
- Syntax check passes

---

## File Locations (Final)

```
source/
├── dag_routing_api.php          ✅ (validate/publish operations)
├── dag_graph_api.php            ✅ (graph CRUD operations - NEW LOCATION)
└── dag/
    ├── _bootstrap.php           ✅ (shared bootstrap)
    ├── _helpers.php             ✅ (shared helpers)
    └── dag_graph_api.php        ⚠️ (original - can be removed if not needed)
```

**Note:** The original file at `source/dag/dag_graph_api.php` can be kept for reference or removed. The active file is now at `source/dag_graph_api.php`.

---

## Testing

✅ File accessible at correct path  
✅ Bootstrap path correct  
✅ Syntax check passes  
✅ Ready for integration testing

