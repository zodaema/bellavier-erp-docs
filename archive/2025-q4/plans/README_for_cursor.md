
# 🧭 Bellavier ERP — Atelier Extension Integration Guide (for Cursor)

**Objective:**  
Integrate the new *Atelier Add-Ons* modules into the existing ERP **without modifying any working core logic**.  
These add-ons extend the ERP with modules for **Job Ticket, WIP, ECO, QC Evidence, Costing, Label, and PWA**, working as modular attachments.

---

## 🔧 Recent Code Refactoring (October 2025)

### **Inventory Transaction Refactoring**

All inventory transaction endpoints (GRN, Issue, Adjust, Transfer) have been refactored to use a centralized **`InventoryHelper`** class for improved maintainability, security, and consistency.

**Benefits:**
- ✅ **Eliminated Code Duplication:** ~120 lines of duplicate UoM logic removed
- ✅ **Security Improvements:** All queries use prepared statements (no more `real_escape_string`)
- ✅ **Race Condition Fix:** Transaction codes now use microsecond resolution
- ✅ **Consistent Error Handling:** Standardized JSON responses across all endpoints
- ✅ **Better Testability:** Helper methods can be unit tested

**New File:**
```php
source/utils/InventoryHelper.php
```

**Key Methods:**
- `resolveUom(string $sku, int $providedUom): ?int` - Resolve UoM from SKU
- `convertToBaseUom(string $sku, float $qty, int $fromUom): array` - UoM conversion
- `generateTxnCode(string $prefix): string` - Unique transaction code (microsecond resolution)
- `validateTransactionInput(array $data, array $required): array` - Input validation
- `jsonResponse(bool $success, $data, ?int $httpCode): void` - Standard API response

**Affected Files:**
- `source/grn.php` - ✅ Refactored
- `source/issue.php` - ✅ Refactored  
- `source/adjust.php` - ✅ Refactored
- `source/transfer.php` - ✅ Refactored

**Backward Compatibility:**
- All endpoints maintain the same API contracts
- Old `txn_code`, `txn_type`, `txn_date` columns still populated for compatibility
- Frontend JavaScript requires no changes

**Testing:**
Run `php tools/test_refactored_inventory.php` to verify:
- ✅ Transaction code uniqueness
- ✅ UoM resolution accuracy
- ✅ Input validation
- ✅ Security (no SQL injection risks)

---

## 📦 Folder Structure (within `/plans`)

```
/plans/
├── README_for_cursor.md          (✅ Active integration guide)
├── future_features_plan.md        (✅ Consolidated future features plan)
│
├── label_templates.html           (📋 Reference - Label templates)
├── tools_process_wip_queue.php    (📋 Tools - PWA queue processor)
├── page_atelier_wip_mobile.php    (📋 Reference - Mobile WIP page)
├── assets_js_atelier_wip_pwa.js   (📋 Reference - PWA assets)
├── service-worker.js              (📋 Reference - PWA service worker)
└── tests_Feature_AddonsEndpoints.test.php (📋 Tests - Future features)
```

**Note:** All old SQL migration files and individual plan files have been consolidated or removed. See `future_features_plan.md` for all future feature plans.

---

## 🧩 Integration Principles

1. **Do not modify ERP core tables.**
   - New tables are defined in `0013_erp_addons.sql`.
   - Existing tables (`product`, `route`, `atelier_wip_log`) only receive optional columns via `ALTER TABLE ... IF NOT EXISTS`.
   - Safe to run multiple times.

2. **Enable Modular Features via Config:**
   Add flags in `config.php`:
   ```php
   define('FEATURE_ATELIER', true);
   define('FEATURE_OFFLINE_WIP', true);
   define('FEATURE_ECO', true);
   define('FEATURE_QC_ADV', true);
   ```

3. **Do not merge add-on PHP logic into existing controllers.**
   - Use a new file `source/api_addons.php` for API endpoints.
   - Follow specs from `api_addons_spec.md`.

4. **Keep database tenant-safe:**
   - Use `$pdo = db_connect_tenant();`
   - Never query global DB directly.

---

## ⚙️ Setup Order

1. **Run Migration:**
   ```bash
   mysql < 0013_erp_addons.sql
   ```

2. **Seed Data:**
   ```bash
   mysql < seed_addons_basics.sql
   mysql < seed_station_templates.sql
   mysql < seed_defect_codes.sql
   mysql < seed_permissions.sql
   ```

3. **Place Scripts:**
   - `/tools/process_wip_queue.php`
   - `/page/atelier_wip_mobile.php`
   - `/assets/js/atelier_wip_pwa.js`
   - `/service-worker.js`
   - `/templates/label_templates.html`

4. **Validate Flow:**
   - Visit `/page/atelier_wip_mobile.php`
   - Scan example: `BGERP|TICKET|123|TOKEN|STC|EVENT|scan_in`
   - Confirm entry in `atelier_wip_scan_queue`
   - Run `tools/process_wip_queue.php` → should insert into `atelier_wip_log`

---

## 🧠 Cursor Development Instructions

### Primary Files to Read:
- `erp_addons_plan.md` → Overview & Architecture
- `api_addons_spec.md` → Endpoint Specification
- `label_templates.html` → Render variables for QR/Label printing

### Cursor Tasks:
1. Implement missing endpoints in `/source/api_addons.php`
   - Follow structure and field validation from `api_addons_spec.md`
2. Ensure permission mapping per `seed_permissions.sql`
3. Keep logic isolated:
   - New class namespace examples: `AtelierECO`, `AtelierWIP`, `AtelierQC`
4. Use the seed data as default for tests.

### Testing:
Run feature tests based on `tests/Feature/AddonsEndpoints.test.php` skeleton.

---

## 🔗 Core ERP Refactor Notes (Transactions Lookups)

To improve separation of concerns and consistency across Transactions pages (GRN, Adjust, Issue/Return, Transfer), shared lookup APIs were centralized.

### What changed
- Added `source/refs.php` as a centralized lookup endpoint.
- Updated front-end for Transactions pages to call `refs.php` instead of their page endpoints:
  - `assets/javascripts/grn/grn.js`
  - `assets/javascripts/adjust/adjust.js`
  - `assets/javascripts/issue/issue.js`
  - `assets/javascripts/transfer/transfer.js`
- Removed legacy lookup actions from page endpoints (`source/grn.php`, `source/adjust.php`, `source/issue.php`, `source/transfer.php`). These endpoints now focus on `list` and `create` only.

### API Reference — `source/refs.php`
- Auth: same session/tenant context as other endpoints.
- Permissions: enforced per resource.

Actions
- `GET refs.php?action=warehouses`
  - Perm: `warehouses.view`
  - Response: `{ ok: true, data: [{ id_warehouse, code, name }, ...] }`
- `GET refs.php?action=locations&id_warehouse=WH_ID`
  - Perm: `locations.view`
  - Response: `{ ok: true, data: [{ id_location, code, name }, ...] }`
- `GET refs.php?action=materials`
  - Perm: `materials.view`
  - Response: `{ ok: true, data: [{ sku, description }, ...] }`
- `GET refs.php?action=uom_by_sku&sku=SKU`
  - Perm: `materials.view`
  - Response: `{ ok: true, data: { id_unit, code, name } | null }`

### Front-end usage pattern
- Define `const REFS = 'source/refs.php';`
- Warehouses: `$.getJSON(REFS, { action: 'warehouses' })`
- Locations: `$.getJSON(REFS, { action: 'locations', id_warehouse })`
- Materials: `$.getJSON(REFS, { action: 'materials' })`
- UoM by SKU: `$.getJSON(REFS, { action: 'uom_by_sku', sku })`

### Backward-compatibility and cleanup
- Removed from the following endpoints: `uoms`, `warehouses`, `locations`, `materials`, `uom_by_sku`.
  - Files: `source/grn.php`, `source/adjust.php`, `source/issue.php`, `source/transfer.php`.
- No database schema changes required.

### QA checklist (manual)
- Open Add modal in GRN/Adjust/Issue/Transfer → Warehouses load; selecting a warehouse populates Locations.
- Materials dropdown lists `SKU - Description`.
- Changing SKU updates UoM display and hidden `id_uom`.
- Saving a record returns `{ ok: true }`, hides modal, and the DataTable refreshes with the new row.

---

## 🔄 Rollback (Safe Mode)
```bash
mysql < 0013_down.sql
```
Drops only newly added tables/columns — no impact to existing ERP.

---

## ✅ Validation Before Merge

| Checkpoint | Description |
|-------------|-------------|
| ✔ Migration | Runs clean on dev tenant |
| ✔ Seed | All data present |
| ✔ WIP Scanner | Records online/offline correctly |
| ✔ ECO Flow | Reach `effective` state |
| ✔ Label Render | Shows all variables |
| ✔ Queue Worker | No pending errors |
| ✔ Role Permission | Validated for artisan/qc/manager |

---

## 💡 Next Steps (Post Merge)

- Link Job Ticket ↔ ECO version control  
- Add Capacity Dashboard  
- Integrate QC Evidence viewer  
- Display Cost Variance in Management UI

---

**Maintainer:** Bellavier Group Atelier Engineering  
**Purpose:** Foundation for Maison-grade production traceability with modular ERP extension.

