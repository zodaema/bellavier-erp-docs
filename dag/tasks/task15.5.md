
# Task 15.5 — Hard Transition (Remove ID Usage)

## Objective
Complete the hard transition from ID‑based references to CODE‑based references for:
- Work Centers  
- Units of Measure (UOM)

This task ensures the system no longer depends on auto‑increment IDs that can differ between tenants or installations.

---

## Scope

### 1. API Layer — Hard Switch
- Remove all uses of `id_work_center` from API request handling.
- Remove all uses of `id_uom` from API request handling.
- Require `work_center_code` and `uom_code` exclusively.
- Add transitional error messages if ID is still submitted.
- ทุก API ที่ต้อง resolve work center หรือ UOM:
  - **ต้องใช้** `WorkCenterService::resolveByCode()` / `UOMService::resolveByCode()`
  - ห้ามเขียน SQL ใหม่เองสำหรับแปลง code → id

### 2. Database Write Path — Hard Switch
- All writes must insert/update using `*_code` columns only.
- Remove ID fallback paths in:
  - `products.php`
  - `materials.php`
  - `mo.php`
  - `bom.php`
  - `dag_behavior_exec.php`
  - `dag_routing_api.php`
  - `component_binding.php`
  - etc.

### 3. Routing Layer
- `routing_node.work_center_code` becomes the *only* reference.
- `work_center_id` usage removed from:
  - DAG Designer save API
  - routing persistence logic
  - routing graph execution (DagExecutionService)
  > Note:
> - ใน Task 15.5 ให้ลบการใช้ `id_work_center` เฉพาะใน **โค้ดแอป** (PHP, JS) เท่านั้น
> - คอลัมน์ `id_work_center` ใน DB ยังอยู่จนกว่าจะถึง Task 15.6
> - DagExecutionService, LegacyRoutingAdapter ฯลฯ ต้องใช้ `work_center_code` เป็น source of truth

### 4. JS Layer
- Forms must submit `*_code` only.
- Dropdown value must be CODE.
- Any JS file reading `.data('id')` must be converted to `.data('code')`.

### 5. Clean Validation
- API returns error:
  - `WORK_CENTER_ID_DEPRECATED`
  - `UOM_ID_DEPRECATED`
- Guidance included: "Use work_center_code instead."
## Deprecated ID Handling

ถ้า client ยังส่ง `id_work_center` หรือ `id_uom` มา:

- API ต้องตอบ HTTP 400
- JSON format:

```json
{
  "ok": false,
  "error": {
    "code": "WORK_CENTER_ID_DEPRECATED",
    "message": "id_work_center is deprecated. Use work_center_code instead.",
    "hint": "ส่ง work_center_code ตามที่ได้จาก /work_centers?action=list"
  }
}

และเขียนคู่ของ `UOM_ID_DEPRECATED` ให้เหมือนกัน

---

### 4) เพิ่ม “Static Scan Check” เป็น Acceptance Criteria

เพื่อให้รู้แน่ ๆ ว่าไม่มี id_* โผล่ในโค้ดอีกแล้ว (ยกเว้น migration / schema):

```md
### Additional Acceptance Criteria

- รัน static scan แล้วต้องไม่พบ pattern ต่อไปนี้ใน **PHP/JS non-migration files**:
  - `id_work_center`
  - `id_uom`
- ยกเว้น:
  - ไฟล์ migration ใน `database/*`
  - ไฟล์ SQL dump / docs

---

## Target Files (Must be updated in this task)

### API (PHP)
- `source/products.php`
- `source/materials.php`
- `source/mo.php`
- `source/bom.php`
- `source/dag_behavior_exec.php`
- `source/dag_routing_api.php`
- `source/component_binding.php`
- `source/hatthasilpa_job_ticket.php` (ถ้ามี work_center / uom)
- `source/work_centers.php`
- `source/uom.php`

### JS (Frontend)
- `assets/javascripts/products/products.js`
- `assets/javascripts/materials/materials.js`
- `assets/javascripts/mo/mo.js`
- `assets/javascripts/bom/bom.js`
- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `assets/javascripts/pwa_scan/work_queue.js`
- `assets/javascripts/pwa_scan/pwa_scan.js`
---

## Acceptance Criteria

### Must‑Have
- System runs end‑to‑end **without using any ID** for:
  - Work Center
  - Unit of Measure
- All tables consistently store and serve `*_code`.

### Must Not
- No API accepts `id_*` even if still present in DB.
- No JS forms submit `id_*`.
- No SQL queries reference `id_work_center` or `id_uom` except migration helpers.

---

## Deliverables

1. **API Cleanup Patch**  
   Full list of affected files + code migrations.

2. **JS Cleanup Patch**  
   Full list of affected files + code migrations.

3. **Routing Layer Cleanup**  
   - Remove ID paths.
   - Rewrite caller logic.

4. **Testing Document**  
   - Unit tests for service resolution by CODE.
   - Integration tests for all major modules.
   - PWA scan flow tests.

5. **Final Migration Plan**  
   Prepare for Task 15.6 (DROP ID columns).

---

## Guardrails (Must NOT change)

- ห้ามแก้ไข **schema** ของตารางต่อไปนี้ใน Task 15.5:
  - `work_center`
  - `unit_of_measure`
- ห้าม DROP หรือ MODIFY columns ใด ๆ (เช่น `id_work_center`, `id_uom`)  
  → การ DROP จะทำใน Task 15.6 เท่านั้น
- ห้ามแก้ไข migrations ใด ๆ ย้อนหลัง
- ห้ามแตะ code ที่เกี่ยวกับ:
  - Leather GRN core logic (`leather_grn.php`) ยกเว้นเรื่อง UOM ตาม spec นี้เท่านั้น
  - Stock ledger / accounting logic
- ห้ามเพิ่ม FK ใหม่ใน Task นี้
---

## Notes

- This task **must be completed before** Task 15.6 which will drop all ID columns from the affected tables.
- After completion, system becomes tenant‑safe with fully deterministic references across the entire DAG system.

