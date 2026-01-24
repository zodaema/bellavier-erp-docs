# Task 26.2 — Product → MO Integration (Phase 2)

**Status:** Planned  
**Owner:** Bellavier ERP Core  
**Last Updated:** 2025-12-01

---

## 1. Executive Summary

### Guardrail Reference
All implementation work in this task must comply with established engineering guardrails. Instead of repeating them here, developers must refer to the following policy documents:
- docs/developer/01-policy/DEVELOPER_POLICY.md
- docs/developer/02-quick-start/AI_QUICK_START.md
- docs/developer/02-quick-start/GLOBAL_HELPERS.md
- docs/developer/02-quick-start/QUICK_START.md

Key expectations from these documents that apply to this task:
- All new UI strings must use the shared i18n helper (default text in English, no hard‑coded Thai in PHP/JS).
- No emojis or decorative icons in code strings (only in mock copy or docs if really needed).
- Follow the shared error/JSON response helpers instead of ad‑hoc `echo`/`die`.
- Follow the existing JS/CSS structure for this module instead of inventing a new pattern.

These guardrails apply to backend, frontend, API design, naming conventions, i18n, and security practices.

This task connects the newly‑refactored Product Module (Phase 2) to the MO Module.  
The objective is to make Products usable operationally and remove all remaining legacy logic.

This task ensures:

- MO Creation uses Product Metadata (production_line, routing_mode, binding)
- Classic vs Hatthasilpa behavior is enforced consistently
- Draft Products are hidden from MO
- Product summary panel appears in MO (create & edit)
- Routing suggestions and ETA preview respect Product rules

This is the final step before integrating Product → Inventory (Task 27).

---

## 2. Objectives

### **2.1 Functional**
- Use ProductMetadataResolver in MO creation & update
- Prevent invalid line combinations (e.g., Classic MO cannot choose DAG routing)
- Auto-fill MO fields using product metadata:
  - production_line
  - routing_mode (Hatthasilpa only)
  - default routing binding (if any)
- Hide draft products from selection
- Display “Product Summary Panel” in MO modal/editor
- Support duplication paths (from Product → MO → JobTicket)

### **2.2 Technical**
- Remove legacy product lookup functions
- Remove legacy routing template selection
- Replace direct SQL with ProductMetadataResolver service calls
- Update MO API (`source/mo.php`)
  - handleCreate
  - handleEdit
  - handlePlan
- Update MO Assist API (`mo_assist_api.php`)

---

## 3. Detailed Work Items


### **3.1 MO Frontend (views/mo.php & JS)**
- Replace product dropdown data source → use `product_api.php?action=list_mo_candidates`
- Add Product Summary Panel:
  - Product name / code
  - Production line badge
  - Leather type / color (when available)
  - Routing binding (Hatthasilpa only)
- Auto-fill production_line + routing_mode when product selected
- Remove:
  - Template selector
  - Default mode selector
  - Graph version selector

### **3.1.1 Add “Publish Product” Support**
- Add a new button in Product Module UI: **Publish Product**
- Only visible when `is_draft = 1`
- Once published:  
  - `is_draft` becomes `0`  
  - Product becomes selectable in MO  
- Prevent unpublishing to maintain historical consistency  
- Ensure API endpoint exists: `product_api.php?action=publish`
- Add validation to block MO creation if product is draft (safety check)

### **3.2 MO Backend (`source/mo.php`)**

#### **Create / Edit**
- Validate:
  - product_id exists
  - product is not draft
  - production_line compatibility
- Auto-fill:
  - production_line
  - routing_mode
  - id_routing_graph (Hatthasilpa only)

#### **Plan**
- Use production_line to determine:
  - Classic → NO DAG tokens
  - Hatthasilpa → generate DAG tokens
- Remove legacy template injection

### **3.3 MO Assist API**
- Replace routing lookup logic → use ProductMetadataResolver
- Suggest correct routing mode:
  - Classic → none
  - Hatthasilpa → dag
- Return product metadata in preview response

### **3.4 Product API (`product_api.php`)**
Add endpoint:

```
?action=list_mo_candidates
```

Returns:
- Only non‑draft products
- Sorted by production_line then name
- With metadata & badges

### **3.5 Cleanup**
- Remove:
  - `getTemplatesForProduct`
  - `get_graph_for_product_legacy`
  - Any “mode_selection” HTML
- Delete unused JS functions in product_graph_binding.js

---

## 4. Acceptance Criteria

- [ ] MO Create modal responds instantly after product select
- [ ] Product Summary Panel displays correctly
- [ ] Draft products never appear in MO
- [ ] Classic MO never requires routing
- [ ] Hatthasilpa MO always binds to routing graph
- [ ] Job Tickets created from MO show correct production_line
- [ ] Legacy template UI fully removed

---

## 5. Files to Modify

### **Backend**
- `source/mo.php`
- `source/mo_assist_api.php`
- `source/product_api.php`
- `source/BGERP/Product/ProductMetadataResolver.php`

### **Frontend**
- `views/mo.php`
- `assets/javascripts/mo.js`
- `assets/javascripts/products/product_graph_binding.js` (cleanup)

### **Documentation**
- `docs/super_dag/task_index.md`
- `docs/super_dag/tasks/results/task26_2_results.md` (to be created)

---

## 6. Next Task

**Task 26.3 — Product → Job Ticket Integration (Phase 3)**  
Make Job Ticket display product metadata consistently, including production line, leather type, and routing info.