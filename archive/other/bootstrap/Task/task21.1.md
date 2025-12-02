Task 21.1 — SQL Cleanup (Fix DAG_500_PREPARE)

Purpose  
- Remove ALL legacy SQL blocks injected inside SQL strings during Task 21.  
- Ensure `$tenantDb->prepare($sql)` never fails due to invalid syntax.  
- Zero logic changes. Only cleanup.  
- Designed so Cursor Agent can fix all target files in ONE run.

---

## 🔥 RULES FOR AGENT (APPLY TO ENTIRE PROJECT)

When scanning project files:

### 1) Identify legacy markers INSIDE SQL strings:
Search for:
- `LEGACY-BLOCK-START (Task21 backup)`
- `LEGACY-BLOCK-END`
- Any `// ...` comments INSIDE SQL

These MUST be removed entirely.

### 2) DO NOT delete:
- Any line containing `--` (MySQL comment)
- Any new optimized JOIN/CASE block created in Task 21  
(Keep everything without `//` exactly as is.)

### 3) SQL string safety rule:
**Inside any `$sql = " ... "` block:  
→ Only SQL allowed.  
→ No PHP comments (`//`) allowed.  
→ No leftover commented subqueries.**

---

## 🔧 TARGET FILES (Agent must scan completely)

### Required:
1. `source/dag_token_api.php`
2. `source/trace_api.php`
3. `source/dag_routing_api.php`

### Optional (scan but fix only if markers exist):
- ANY other file containing:
  - `LEGACY-BLOCK-START (Task21 backup)`
  - or `DAG_500_PREPARE`

---

## ✔️ CLEANUP PATTERNS AGENT MUST EXECUTE

### Pattern A — Correlated subquery leftovers

Remove this WHOLE block:

```sql
// LEGACY-BLOCK-START (Task21 backup)
// CASE ...
// END as xxx
// LEGACY-BLOCK-END
```

Replace with NOTHING (just delete block).

---

### Pattern B — Legacy LEFT JOIN backup

Remove:

```sql
// LEGACY-BLOCK-START (Task21 backup)
// LEFT JOIN (SELECT ...)
// LEGACY-BLOCK-END
```

Do not touch the new optimized LEFT JOIN.

---

### Pattern C — Queue position

Delete:

```sql
// LEGACY-BLOCK-START...
// CASE WHEN t.status...
// LEGACY-BLOCK-END
```

Final should only be:

```sql
NULL as queue_position
```

---

## 📌 AFTER CLEANUP (AGENT VALIDATION STEPS)

### Agent must run:

1) Syntax checks:
```
php -l source/dag_token_api.php
php -l source/trace_api.php
php -l source/dag_routing_api.php
```

2) Ensure NO SQL string contains:
- `//`
- `LEGACY-BLOCK-START`
- `LEGACY-BLOCK-END`

3) Ensure optimized SQL is untouched:
- Only old backup blocks removed.

---

## 🎯 Final Criteria

Task 21.1 is COMPLETE when:

- All SQL prepares succeed
- No DAG_500_PREPARE errors
- All Task 21 optimized queries remain functioning
- No residue comments inside SQL strings
- No business logic changed

---

## ✅ IMPLEMENTATION STATUS

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Agent:** Cursor AI

### Files Modified

1. **source/dag_token_api.php**
   - Removed legacy block for `queue_position` (lines 1774-1785)
   - Removed legacy block for `assignment_log` LEFT JOIN (lines 1800-1809)
   - Total: 2 legacy blocks removed

2. **source/trace_api.php**
   - Removed legacy block for `has_rework` subquery (lines 1883-1893)
   - Total: 1 legacy block removed

3. **source/dag_routing_api.php**
   - Removed legacy block for `where_used` correlated subqueries (lines 6469-6478)
   - Total: 1 legacy block removed

### Validation Results

✅ **Syntax Checks:**
```bash
php -l source/dag_token_api.php  # ✅ No syntax errors
php -l source/trace_api.php       # ✅ No syntax errors
php -l source/dag_routing_api.php # ✅ No syntax errors
```

✅ **Legacy Marker Scan:**
- No `LEGACY-BLOCK-START` markers found
- No `LEGACY-BLOCK-END` markers found
- No PHP comments (`//`) inside SQL strings

✅ **Optimized SQL Preserved:**
- All Task 21 optimized LEFT JOINs remain intact
- All Task 21 optimized aggregations remain intact
- All Task 21 PHP post-processing logic remains intact

### Changes Summary

**Total Legacy Blocks Removed:** 4 blocks
- 2 from `dag_token_api.php` (queue_position, assignment_log)
- 1 from `trace_api.php` (has_rework)
- 1 from `dag_routing_api.php` (where_used)

**SQL String Safety:**
- ✅ All SQL strings contain only valid SQL syntax
- ✅ No PHP comments (`//`) in SQL strings
- ✅ Only MySQL comments (`--`) remain (correct)

**Business Logic:**
- ✅ Zero logic changes
- ✅ All optimized queries from Task 21 remain functional
- ✅ No breaking changes

### Notes

- All legacy blocks were PHP comments (`//`) that were accidentally left inside SQL strings during Task 21
- These blocks would cause `DAG_500_PREPARE` errors when `$tenantDb->prepare($sql)` is called
- Cleanup was surgical: only legacy markers removed, optimized code untouched