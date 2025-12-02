# Task 13.21 Results — System Master Data Hardening (UOM / Work Center / Categories)

**Status:** 🟡 **IN PROGRESS** (Phase 0.3 & API Guard Complete, UI Updates Pending)  
**Date:** December 2025  
**Task:** [13.21.md](13.21.md)

---

## Summary

Task 13.21 aims to create a "Closed System Architecture" for Bellavier ERP to prevent users from modifying critical Master Data (UOM, Work Center, Categories, Material Types, Warehouse Default) that could break the entire production system. This task implements System Default + Guard Layer similar to iOS / Hermès Atelier System.

**Current Status:**
- ✅ Phase 0.3: System Default Seed Migration (COMPLETED)
- ✅ Database Migration: Added is_system, locked columns (COMPLETED)
- ✅ API Guard Layer: COMPLETED
- ⏳ UI Updates: Pending
- ⏳ Behavior Engine Patch: Pending

---

## Phase 0.3: System Default Seed Migration (COMPLETED)

### Migration File

**File:** `database/tenant_migrations/2025_12_system_master_data_hardening.php`

**Features:**
- ✅ Idempotent: Safe to run multiple times
- ✅ Code-based: Uses code for identification, not id
- ✅ System flags: is_system=1, locked=1 for all system defaults
- ✅ Reserved ID range: 1-99 for system defaults

### Step 1: Add Columns

Added `is_system` and `locked` columns to:
- ✅ `unit_of_measure`
- ✅ `work_center`
- ✅ `warehouse`
- ✅ `warehouse_location`
- ✅ `product_category` (if exists)

**Column Definitions:**
```sql
`is_system` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'System default flag'
`locked` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Locked flag (prevents modification)'
```

### Step 2: System Default UOM

Seeded 7 system UOM units:
- ✅ `cm` - Centimeter
- ✅ `mm` - Millimeter
- ✅ `cm2` - Square Centimeter
- ✅ `square_meter` - Square Meter
- ✅ `sqft` - Square Foot
- ✅ `sheet` - Sheet
- ✅ `pcs` - Pieces

**Logic:**
- Checks if UOM exists by code
- If exists: Updates to `is_system=1, locked=1`
- If not exists: Inserts new with system flags

### Step 3: System Default Work Centers

Seeded 5 system work centers:
- ✅ `CUT` - Cutting
- ✅ `SEW` - Sewing
- ✅ `QC_INITIAL` - QC Initial
- ✅ `QC_FINAL` - QC Final
- ✅ `PACK` - Packing

**Logic:**
- Checks if work center exists by code
- If exists: Updates to `is_system=1, locked=1`
- If not exists: Inserts new with system flags

### Step 4: System Default Warehouse & Locations

Seeded:
- ✅ Warehouse: `MAIN` (Main Warehouse)
- ✅ Location: `RAW` (Raw Materials)
- ✅ Location: `WIP` (Work In Progress)
- ✅ Location: `FINISHED` (Finished Goods)

**Logic:**
- Creates/updates MAIN warehouse with system flags
- Creates/updates 3 system locations in MAIN warehouse

### Step 5: Reset AUTO_INCREMENT

**Policy:**
- ID 1-99: Reserved for System Default Master Data
- ID >= 100: User-created data

**Implementation:**
- Gets max ID from each table
- Sets AUTO_INCREMENT to max(100, max_id + 1)
- Ensures no ID conflicts

**Tables Reset:**
- ✅ `unit_of_measure`
- ✅ `work_center`
- ✅ `warehouse`
- ✅ `warehouse_location`

---

## Database Schema Changes

### New Columns Added

| Table | Column | Type | Default | Description |
|-------|--------|------|---------|-------------|
| `unit_of_measure` | `is_system` | TINYINT(1) | 0 | System default flag |
| `unit_of_measure` | `locked` | TINYINT(1) | 0 | Locked flag |
| `work_center` | `is_system` | TINYINT(1) | 0 | System default flag |
| `work_center` | `locked` | TINYINT(1) | 0 | Locked flag |
| `warehouse` | `is_system` | TINYINT(1) | 0 | System default flag |
| `warehouse` | `locked` | TINYINT(1) | 0 | Locked flag |
| `warehouse_location` | `is_system` | TINYINT(1) | 0 | System default flag |
| `warehouse_location` | `locked` | TINYINT(1) | 0 | Locked flag |
| `product_category` | `is_system` | TINYINT(1) | 0 | System default flag |
| `product_category` | `locked` | TINYINT(1) | 0 | Locked flag |
| `product_category` | `deleted_at` | DATETIME | NULL | Soft delete timestamp |

---

## System Defaults Seeded

### UOM (7 units)
1. `cm` - Centimeter
2. `mm` - Millimeter
3. `cm2` - Square Centimeter
4. `square_meter` - Square Meter
5. `sqft` - Square Foot
6. `sheet` - Sheet
7. `pcs` - Pieces

### Work Centers (5 centers)
1. `CUT` - Cutting
2. `SEW` - Sewing
3. `QC_INITIAL` - QC Initial
4. `QC_FINAL` - QC Final
5. `PACK` - Packing

### Warehouse & Locations
- Warehouse: `MAIN` - Main Warehouse
- Location: `RAW` - Raw Materials
- Location: `WIP` - Work In Progress
- Location: `FINISHED` - Finished Goods

---

## API Guard Layer (COMPLETED)

### Implementation Summary

Added guard layer to prevent modification/deletion of system master data in all master data APIs.

**APIs Updated:**
- ✅ `source/uom.php`
- ✅ `source/work_centers.php`
- ✅ `source/warehouses.php`
- ✅ `source/locations.php`

### Guard Logic

**Update Protection:**
- Checks `is_system` and `locked` flags before update
- Rejects update if `is_system=1` OR `locked=1`
- Prevents code change if `locked=1` (even if not system)
- Returns error: `master_data_locked` (403)

**Delete Protection:**
- Checks `is_system` and `locked` flags before delete
- Rejects delete if `is_system=1` OR `locked=1`
- Returns error: `master_data_locked` (403)

**List Enhancement:**
- Added `is_system` and `locked` columns to list queries
- Frontend can use these flags to show locked status

### Error Response Format

```json
{
  "ok": false,
  "error": "master_data_locked",
  "app_code": "UOM_403_SYSTEM_LOCKED",
  "message": "This is system master data and cannot be modified."
}
```

### Code Changes

**uom.php:**
- ✅ Guard check in `handleUpdate()` - prevents update of locked/system UOM
- ✅ Guard check in `handleDelete()` - prevents delete of locked/system UOM
- ✅ Added `is_system`, `locked` to list query

**work_centers.php:**
- ✅ Guard check in `case 'update'` - prevents update of locked/system work centers
- ✅ Guard check in `case 'delete'` - prevents delete of locked/system work centers
- ✅ Added `is_system`, `locked` to list query

**warehouses.php:**
- ✅ Guard check in `handleUpdate()` - prevents update of locked/system warehouses
- ✅ Guard check in `handleDelete()` - prevents delete of locked/system warehouses
- ✅ Added `is_system`, `locked` to list query

**locations.php:**
- ✅ Guard check in `handleUpdate()` - prevents update of locked/system locations
- ✅ Guard check in `handleDelete()` - prevents delete of locked/system locations
- ✅ Added `is_system`, `locked` to list query

## Pending Tasks

### Phase 0.4: Deprecate Legacy Seed Migrations
- [ ] Identify legacy seed migrations
- [ ] Mark as deprecated in documentation
- [ ] Remove seed logic from legacy migrations (keep schema only)

### UI Updates
- [ ] Add locked icon (🔒) for system data
- [ ] Disable Delete button for locked records
- [ ] Disable Edit Code for locked records
- [ ] Show warning message in edit modal
- [ ] Update list views to show locked status

**Files to Update:**
- `views/uom.php`
- `views/work_center.php`
- `views/warehouse.php`
- `assets/javascripts/uom/uom.js`
- `assets/javascripts/work_center/work_center.js`

### Behavior Engine Patch
- [ ] Update routing engine to use ID instead of code
- [ ] Update CUT engine to use ID instead of code
- [ ] Update Material Resolver to use ID instead of code
- [ ] Remove code-based logic from all engines

---

## Risk Mitigation

### Risk 1: Production Data Impact
**Status:** ✅ Mitigated
- Migration is idempotent (safe to run multiple times)
- Updates existing records instead of deleting
- Preserves all existing data

### Risk 2: AUTO_INCREMENT Conflicts
**Status:** ✅ Mitigated
- Checks max ID before resetting
- Sets AUTO_INCREMENT to safe value (max(100, max_id + 1))
- Reserved range 1-99 for system defaults

### Risk 3: Duplicate System Defaults
**Status:** ✅ Mitigated
- Checks by code before insert
- Updates existing records to system defaults
- Prevents duplicate codes

### Risk 4: Schema Differences
**Status:** ✅ Mitigated
- Checks table existence before operations
- Handles missing columns gracefully
- Defensive programming for optional tables

---

## Testing & Verification

### Migration Testing
- ✅ Syntax check: `php -l` passed
- ✅ Run migration on maison_atelier tenant (COMPLETED)
- ✅ Verify columns added (COMPLETED)
- ✅ Verify system defaults seeded (COMPLETED)
- ✅ Verify AUTO_INCREMENT reset (COMPLETED)

### Data Verification (maison_atelier tenant)

**Columns Added:**
- ✅ `unit_of_measure.is_system` - EXISTS
- ✅ `unit_of_measure.locked` - EXISTS
- ✅ `work_center.is_system` - EXISTS
- ✅ `work_center.locked` - EXISTS
- ✅ `warehouse.is_system` - EXISTS
- ✅ `warehouse.locked` - EXISTS
- ✅ `warehouse_location.is_system` - EXISTS
- ✅ `warehouse_location.locked` - EXISTS

**System UOM (7 units, all locked=1):**
- ✅ cm - Centimeter
- ✅ cm2 - Square Centimeter
- ✅ mm - Millimeter
- ✅ pcs - Pieces
- ✅ sheet - Sheet
- ✅ sqft - Square Foot
- ✅ square_meter - Square Meter

**System Work Centers (5 centers, all locked=1):**
- ✅ CUT - Cutting
- ✅ SEW - Sewing
- ✅ QC_INITIAL - QC Initial
- ✅ QC_FINAL - QC Final
- ✅ PACK - Packing

**System Warehouse:**
- ✅ MAIN - Main Warehouse (locked=1)

**System Locations (3 locations, all locked=1):**
- ✅ MAIN:RAW - Raw Materials
- ✅ MAIN:WIP - Work In Progress
- ✅ MAIN:FINISHED - Finished Goods

**AUTO_INCREMENT Status:**
- ✅ `unit_of_measure`: 100
- ✅ `work_center`: 100
- ✅ `warehouse`: 100
- ✅ `warehouse_location`: 100

**Migration Tracking:**
- ✅ Migration recorded in `tenant_migrations` table
- ✅ Execution time: 2025-11-21 14:23:02

---

## Files Created/Modified

### Created:
1. `database/tenant_migrations/2025_12_system_master_data_hardening.php`
   - System default seed migration
   - Adds is_system, locked columns
   - Seeds system defaults
   - Resets AUTO_INCREMENT

2. `docs/dag/tasks/task13.21_results.md`
   - This file

### Modified:
1. `source/uom.php`
   - Added guard checks in handleUpdate() and handleDelete()
   - Added is_system, locked to list query

2. `source/work_centers.php`
   - Added guard checks in case 'update' and case 'delete'
   - Added is_system, locked to list query

3. `source/warehouses.php`
   - Added guard checks in handleUpdate() and handleDelete()
   - Added is_system, locked to list query

4. `source/locations.php`
   - Added guard checks in handleUpdate() and handleDelete()
   - Added is_system, locked to list query

---

## Migration Execution Results

### Execution Summary

**Tenant:** maison_atelier  
**Migration:** 2025_12_system_master_data_hardening.php  
**Status:** ✅ **SUCCESS**  
**Executed At:** 2025-11-21 14:23:02

**Results:**
- ✅ All columns added successfully
- ✅ All system defaults seeded successfully
- ✅ AUTO_INCREMENT reset successfully
- ✅ All system data marked with is_system=1, locked=1
- ✅ Migration tracked in tenant_migrations table

### Verification Commands

```bash
# Check columns
SHOW COLUMNS FROM unit_of_measure LIKE 'is_system';
SHOW COLUMNS FROM work_center LIKE 'is_system';

# Check system defaults
SELECT code, name, is_system, locked FROM unit_of_measure WHERE is_system = 1;
SELECT code, name, is_system, locked FROM work_center WHERE is_system = 1;
SELECT code, name, is_system, locked FROM warehouse WHERE is_system = 1;
SELECT code, name, is_system, locked FROM warehouse_location WHERE is_system = 1;

# Check AUTO_INCREMENT
SHOW TABLE STATUS LIKE 'unit_of_measure';
SHOW TABLE STATUS LIKE 'work_center';
```

## Next Steps

1. ✅ **Run Migration:** COMPLETED for maison_atelier
2. ✅ **Verify Results:** COMPLETED - All checks passed
3. ⏳ **Run for Other Tenants:**
   ```bash
   php source/bootstrap_migrations.php --tenant=DEFAULT
   ```

4. ⏳ **Implement API Guard Layer:**
   - Add validation in master data APIs
   - Reject modifications to system data

5. ⏳ **Update UI:**
   - Add locked indicators
   - Disable edit/delete for system data

6. ⏳ **Update Behavior Engines:**
   - Switch from code-based to ID-based logic

---

## Notes

- **Idempotency:** Migration is safe to run multiple times. It checks existence before insert/update.

- **Code-Based:** Uses code for identification, not ID. This ensures consistency across tenants.

- **System Flags:** All system defaults marked with `is_system=1, locked=1` to prevent modification.

- **Reserved Range:** ID 1-99 reserved for system defaults. User data starts from ID 100.

- **Backward Compatible:** Existing data preserved. Migration updates existing records to system defaults.

---

**Task 13.21 Status:** 🟡 **IN PROGRESS**

**Phase 0.3 Complete** ✅  
**API Guard & UI Updates Pending** ⏳

