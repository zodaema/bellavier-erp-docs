# Task 29.3 Results: Atomic Revision Creation

**Status:** ✅ **COMPLETE (Implemented & Hardened)**  
**Date:** January 11, 2026  

---

## What Was Implemented

### 1) Atomic Draft Revision Creation (All-or-Nothing)
`source/BGERP/Product/ProductRevisionService.php`
- `createRevision()` runs inside a single transaction.
- Any failure rolls back, preventing partial `product_revision` rows.

### 2) Pre-Transaction Guards (Determinism / Policy)
- Invariants are validated *before* the transaction is opened (via invariant validation against derived-from revision).
- If product already has an active revision and caller did not provide `derived_from_revision_id`, service auto-selects the active revision to close policy gaps.

### 3) Explicit Graph Version Capture (Hatthasilpa Only)
`source/BGERP/Product/ProductRevisionService.php`
- For `production_line=hatthasilpa`, draft revision creation now captures a concrete `graph_version_id` if not supplied.
- Resolution is performed via `GraphVersionResolver`, ensuring we store a pinned FK (not a vague “active graph” reference).
- Classic line remains relaxed (no graph required).

---

## Files Changed
- `source/BGERP/Product/ProductRevisionService.php`

---

## Test Results

```
vendor/bin/phpunit -v tests/Unit/ProductRevisionServiceTest.php
OK (20 tests, 89 assertions)
```

