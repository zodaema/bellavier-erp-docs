# Task 26.6 — Product Delete + Dependency Guard + “Where Used” Report

## Executive Summary
This task introduces a **safe, enterprise‑grade product deletion workflow**.  
Products in Bellavier ERP must **never** be deleted blindly because they are referenced across MO, Job Tickets, Inventory, Routing Bindings, etc.  
Therefore, we implement:

1. **Dependency Scanner** — Detect all references before delete  
2. **Deletion Validation Layer** — Block delete if used anywhere  
3. **Soft Delete (is_deleted)** — For audit + recovery  
4. **Where Used Report (UI + API)** — Show all references before deletion  
5. **Admin‑only Delete Action** — With confirmation + irreversible warning  
6. **Frontend Integration** — “Delete Product” button → modal → dependency listing

---

## 1. Database Migration — Soft Delete Column
Create migration:

### `2025_12_product_soft_delete.php`
Add:

```
ALTER TABLE product
  ADD COLUMN is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  ADD INDEX idx_deleted (is_deleted);
```

No hard delete in DB.

---

## 2. Backend — ProductDependencyScanner Service

Create file:
`source/BGERP/Product/ProductDependencyScanner.php`

### Responsibilities:
- Scan all modules that reference a given product:
  - MO (`mo.id_product`)
  - Job Tickets (`job_ticket.id_product`)
  - Hatthasilpa Jobs (`hatthasilpa_jobs.id_product`)
  - Inventory movements
  - Graph bindings
  - Pricing / BOM (future‑safe)
- Return structured report:

```
{
  "has_dependency": true,
  "mo_count": 12,
  "job_ticket_count": 4,
  "hatthasilpa_job_count": 1,
  "inventory_refs": 8,
  "graph_bindings": 1,
  "details": {
     "mo_ids": [...],
     "job_ticket_ids": [...],
     ...
  }
}
```

---

## 3. Backend — Delete Guard Logic (Hard‑Block)

Modify `product_api.php`:

### New endpoint:
`action=delete`

Steps:

1. Validate CSRF, permissions, admin role  
2. Call `ProductDependencyScanner`  
3. If `has_dependency = true`, return error:

```
{
  "ok": false,
  "error_code": "PRODUCT_CANNOT_DELETE_IN_USE",
  "message": "This product is referenced by existing MO, job tickets, or inventory records."
}
```

4. If no dependency → soft delete:
```
UPDATE product SET is_deleted = 1, is_active = 0 WHERE id_product = ?
```

5. Log deletion event into `audit_log`

---

## 4. Backend — Where Used API

Add to `product_api.php`:

```
action=where_used
```

Returns dependency report from scanner.

Used for frontend modal visibility.

---

## 5. Frontend — Delete Product UX

Modify:

- `views/products.php`
- `assets/javascripts/products/products.js`

### New UI workflow:

1. User clicks **Delete…** on product row  
2. Modal opens:  
   - Load `/product_api.php?action=where_used&id=X`  
   - If references exist → show listing + **block delete**  
   - If no references → show red warning:  
     “This action cannot be undone. Confirm delete?”  
3. Button: **Confirm Delete**  
   - Calls `/product_api.php?action=delete`  
   - On success → remove row + show success toast

### Display rules:
- Draft products can be deleted only if never used  
- Published products usually have dependencies → deletion rejected  
- Deleted products disappear from product list  
- Filtering updated to hide deleted items

---

## 6. UI Changes — Product List

Add badge if soft‑deleted:

But hide by default using filter:
`WHERE is_deleted = 0`

This protects the UI from unexpected ghost products.

---

## 7. Security & Guardrail Notes

- Delete is **admin‑only**
- Soft delete ensures audit traceability
- Dependency check prevents data corruption
- Use internal guardrails described in internal_policy_engineering_standards.md:
  - no silent failing  
  - no destructive operations without audit  
  - return structured error codes  
  - i18n ready messages  
  - consistent naming conventions  

---

## 8. Deliverables Recap

### New Files
- `source/BGERP/Product/ProductDependencyScanner.php`
- Migration: `2025_12_product_soft_delete.php`

### Modified Files
- `source/product_api.php`
- `views/products.php`
- `assets/javascripts/products/products.js`
- Documentation index

---

## 9. Acceptance Criteria

| Requirement | Status |
|------------|--------|
| Cannot delete referenced products | ✅ |
| Where-used report implemented | ✅ |
| Soft delete column exists | ✅ |
| Admin-only delete | ✅ |
| UX modal flow correct | ✅ |
| All changes documented | ✅ |

---

### Implementation Precision Addendum (Required Before Sending to Cursor)
To ensure Cursor implements Task 26.6 with full accuracy and avoids ambiguity, the following clarifications are added:

#### 1. Switch–Case Placement in `product_api.php`
All new actions must be added inside the main `switch ($action)` block in `product_api.php`, as top-level cases:

```php
case 'delete':
    // delete logic
    break;

case 'where_used':
    // where-used logic
    break;
```

This prevents accidental placement outside the dispatcher.

#### 2. Modal Identifier for Delete Workflow
Frontend must use a single modal:

```
#modal-product-delete
```

All JS (products.js) must reference this ID when opening the where‑used report modal and triggering confirm-delete flow.

#### 3. Enforce `is_deleted = 0` at Product List Query Source
In `source/products.php` under the default list action, ensure the SQL explicitly includes:

```
WHERE p.is_deleted = 0
```

Cursor must patch this in the main product listing query rather than relying on frontend filtering.

#### 4. Maintain Compliance with Engineering Guardrail Policies
All actions written for this task must comply with:

```
docs/system_policies/internal_policy_engineering_standards.md
docs/system_policies/internal_policy_api_standards.md
docs/system_policies/internal_policy_security_standards.md
```

Cursor must follow naming rules, structured error response standards, and avoid inline UI text not processed through i18n.

---

Task 26.6 is now ready for implementation by Cursor.