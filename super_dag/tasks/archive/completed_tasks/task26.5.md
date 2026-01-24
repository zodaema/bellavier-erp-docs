# Task 26.5 — Product State Guarding & Cross‑Module Enforcement

**Status:** Planned  
**Owner:** System Architecture / Product Module  
**Scope:** Prevent invalid product usage across all modules (MO, Hatthasilpa Jobs, Job Tickets, Routing Binding)

---

## 🎯 Objective

Ensure that **only Published & Active products** can be used across the entire ERP.  
This task introduces a consistent “Product State Guard” enforced at **Backend + API + UI**.

This eliminates silent errors, accidental usage of unfinished product records, and prevents corrupted state in MO / Jobs / Tickets.

---

## ✅ Requirements

### 1. Backend Enforcement (Hard Guard)
Every place where a product can be referenced must enforce:

- `is_draft = 0`
- `is_active = 1`

If not valid → reject request with proper `app_code`.

Modules affected:

| Module | File | Notes |
|--------|-------|--------|
| Manufacturing Order | `source/mo.php` | Block create/plan/update if product is Draft/Inactive |
| Hatthasilpa Jobs | `source/hatthasilpa_jobs_api.php` | Block job creation or duplication |
| Job Ticket (Classic) | `source/job_ticket.php` | Block job creation via MO |
| ETA / Simulation | `MO*Services` | Do not compute ETA for draft/invalid products |
| Product API | `product_api.php` | Add `validate_product_state()` helper |

### Error Examples

| Condition | app_code | message |
|-----------|----------|---------|
| Draft Product | `PRD_400_DRAFT_NOT_ALLOWED` | Product is still in draft and cannot be used. |
| Inactive Product | `PRD_400_INACTIVE_PRODUCT` | Product is inactive. Activate it before use. |
| Missing | `PRD_404_NOT_FOUND` | Product does not exist. |

---

## 2. UI Enforcement (Soft Guard)

### Screens affected:
- MO Create Modal
- Hatthasilpa Job Create Modal
- Job Ticket Create Dialog (Classic)
- Product Selector components

### Rules:
- Only show products where: `is_draft = 0 AND is_active = 1`
- Draft/Inactive items **never appear** in dropdowns.
- If accessed via URL (direct ID):  
  → Show red banner:  
  “This product is not published or has been deactivated.”

### Product List UI:

Badges shown inside SKU row:

- `Draft` (yellow)
- `Inactive` (gray)

No duplicated column for state.

---

## 3. API-Level Helpers

New helper function inside `product_api.php` or new service class:

```
validate_product_state($product): array|true
```

Returns:

```
[
  "ok" => false,
  "app_code" => "PRD_400_DRAFT_NOT_ALLOWED",
  "message" => "This product is still in draft."
]
```

Used by all API entry points.

---

## 4. Cross‑Module Cleanup

### Remove remaining Classic DAG binding code (if any)
- Ensure Classic products never expose “Graph Binding tab”
- Ensure Hatthasilpa products always expose graph binding

### Sync with ProductMetadataResolver
- Must return:
```
supports_graph = ($production_line === 'hatthasilpa')
```
- **Must also enforce product state inside metadata payload:**  
  ProductMetadataResolver MUST always include:

```
state: {
  is_draft: (int) $product['is_draft'],
  is_active: (int) $product['is_active'],
  is_usable: ($product['is_draft'] == 0 && $product['is_active'] == 1)
}
```

And if `is_usable` is false:

- Do NOT return routing metadata  
- Do NOT return graph binding metadata  
- UI must treat product as non‑selectable / read‑only  
- Tabs related to routing/graph MUST be hidden or disabled

---

## 5. Compatibility Audit

Run a search for:
- `production_line`
- `is_draft`
- `is_active`
- Any usage of deprecated `production_lines` column

Ensure consistent usage across all modules.

---

## 🧪 Testing Plan

### Positive Cases
- Create MO using Published+Active → OK  
- Create Hatthasilpa Job with Published+Active → OK  
- Product list shows all states correctly

### Negative Cases
- Attempt MO with draft product → Blocked  
- Attempt Hatthasilpa Job with inactive product → Blocked  
- Attempt to bind graph on Classic → Blocked  
- Attempt to use deleted/removed product → Blocked  

---

## 📦 Deliverables

- Updated backend guards in all relevant API files  
- Updated UI filtering  
- Updated ProductMetadataResolver  
- Comprehensive error codes  
- Updated documentation  

---

## 📘 Notes

For coding rules, developer must follow:

- `docs/policies/ai_agent_guardrail.md`
- `docs/policies/engineering_standards.md`
- `docs/policies/security_review.md`

These guardrails MUST be applied during implementation.

---

## Next Task → 26.6
**Implement Product Delete + Hard Dependency Validation**

- Soft delete using `is_active = 0`
- Prevent delete if product is referenced by MO / Jobs / Tickets / Inventory
- Provide “Where Used” report

