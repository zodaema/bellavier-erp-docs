# Task 29.2 Results: Revision Invariants Validation

**Status:** ✅ **COMPLETE (Implemented & Enforced)**  
**Date:** January 11, 2026  

---

## What Was Implemented

### 1) Invariant Set (Current Schema)
Implemented invariants based on actual current `product` schema:
- `sku`
- `default_uom`
- `default_uom_code`

> Note: Fields like `material_category`, `inventory_accounting_method`, `traceability_level` are documented in `task29.2` but are **not present** in current `product` schema, so they are not enforced yet.

### 2) Service-Side Invariants Validation (Revision Creation)
`source/BGERP/Product/ProductRevisionService.php`
- Enforced invariant validation by ensuring `derived_from_revision_id` is never “accidentally null” when product already has an active revision.
- If active revision exists and caller doesn't pass `derived_from_revision_id`, service auto-uses the active revision, then validates invariants against its snapshot.
- Violations raise `InvariantViolationException` with stable app_code `PRD_400_INVARIANT_VIOLATION`.

### 3) Product-Level Invariant Changes Are Now Blocked (After Revisions Exist)
`source/product_api.php` (`handleUpdateCoreFields`)
- If product has any `product_revision` records, changing `sku` or `default_uom_code` is blocked.
- Returns HTTP `409` with `app_code=PRD_409_INVARIANT_LOCKED`.

---

## Files Changed
- `source/BGERP/Product/ProductRevisionService.php`
- `source/product_api.php`

---

## Test Results

```
vendor/bin/phpunit -v tests/Unit/ProductRevisionServiceTest.php
OK (20 tests, 89 assertions)
```

