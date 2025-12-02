# UOM & Work Center Hardening (Task 15.8)

**Status:** ✅ Completed  
**Date:** 2025-12-15  
**Task:** docs/dag/tasks/task15.8.md

---

## Overview

This document describes the hardening of **Unit of Measure (UOM)** and **Work Center** master data to prevent accidental corruption of core system units used by Leather GRN, CUT Node, stock, and production workflows.

---

## System UOM Codes

The following UOM codes are marked as **system** (`is_system=1, locked=1`):

| Code | Name | Description | Used By |
|------|------|-------------|---------|
| `pcs` | Piece | ชิ้นงาน | Products, stock |
| `mm` | Millimeter | มิลลิเมตร | Leather measurements |
| `m` | Meter | เมตร | Length measurements |
| `sqft` | Square Foot | ตารางฟุต | Leather area |
| `yard` | Yard | หลา | Leather length |
| `cm` | Centimeter | เซนติเมตร | Measurements |
| `m2` | Square Meter | ตารางเมตร | Area measurements |
| `sheet` | Sheet | แผ่น | Leather sheets |
| `gram` | Gram | | Weight |
| `kg` | Kilogram | | Weight |
| `ml` | Milliliter | | Volume |
| `liter` | Liter | | Volume |
| `cm2` | Square Centimeter | ตารางเซนติเมตร | Area |

**Total:** 13 system UOM codes

---

## System Work Center Codes

The following Work Center codes are marked as **system** (`is_system=1, locked=1`):

| Code | Name | Description | Used By |
|------|------|-------------|---------|
| `CUT` | Cutting | Cutting work center | Leather CUT behavior |
| `SKIV` | Skiving | Trim & Skiving Leather | Production |
| `EDG` | Edging | Edge finish & polishing | Production |
| `GLUE` | Gluing | Gluing | Production |
| `ASSEMBLY` | Assembly | Final assembly bench | Production |
| `SEW` | Sewing | Sewing work center | Production |
| `HW` | Hardware | Hardware, ZIP, Screw | Production |
| `PACK` | Packing | Packing work center | Production |
| `QC_INITIAL` | QC Initial | Initial quality control | QC workflows |
| `QC_FINAL` | QC Final | Final quality control | QC workflows |

**Total:** 10 system Work Center codes

---

## Protection Rules

### System Rows Cannot Be:
- ❌ **Deleted** - System UOM/Work Center cannot be deleted
- ❌ **Code Changed** - Core field `code` is immutable for system rows
- ❌ **Type/Base Ratio Changed** - (UOM only) Core fields are locked

### System Rows Can Be:
- ✅ **Name/Description Updated** - Display fields can be localized
- ✅ **Viewed** - All read operations are allowed

### Locked (Non-System) Rows:
- ❌ Cannot be deleted
- ❌ Code cannot be changed
- ✅ Name/description can be updated

---

## Implementation Details

### Database Level

**Migration:** `database/tenant_migrations/2025_12_15_08_harden_uom_and_work_center.php`

- Marks system UOM rows from canonical template list
- Marks system Work Center rows from canonical template list
- Sets `is_system=1, locked=1, is_active=1` for all system rows

### API Level

**UOM API:** `source/uom.php`
- `handleCreate()` - New UOM always has `is_system=0`
- `handleUpdate()` - Blocks code change for system UOM
- `handleDelete()` - Blocks deletion of system UOM

**Work Center API:** `source/work_centers.php`
- `create` - New Work Center always has `is_system=0`
- `update` - Blocks code change for system Work Center
- `delete` - Blocks deletion of system Work Center

### UI Level

**UOM Screen:** `views/uom.php` + `assets/javascripts/uom/uom.js`
- Shows "🔒 System" badge for system UOM
- Disables delete button for system UOM
- Locks code field (readonly) when editing system UOM

**Work Center Screen:** `views/work_centers.php` + `assets/javascripts/work_centers/work_centers.js`
- Shows "🔒 System" badge for system Work Center
- Disables delete button for system Work Center
- Locks code field (readonly) when editing system Work Center

---

## Cross-Tenant Reference Strategy

### UOM Reference
- **Within tenant:** Use `id_unit` (FK) - OK
- **Cross-tenant / Seed / Template:** Use `uom_code` (business key) - **REQUIRED**
- **Never assume:** `id_unit` values match across tenants

### Work Center Reference
- **Within tenant:** Use `id_work_center` (FK) - OK
- **Cross-tenant / Seed / Graph binding:** Use `code` (business key) - **REQUIRED**
- **Never assume:** `id_work_center` values match across tenants

---

## Guardrails for Leather/CUT/GRN Usage

### Leather GRN (`source/leather_grn.php`)
- ✅ Uses `uom_code` for material UOM reference
- ✅ Uses `code` for work center reference (if applicable)

### Leather CUT BOM (`source/leather_cut_bom_api.php`)
- ✅ Uses `uom_code` for BOM line UOM reference
- ✅ Uses `code` for work center reference (CUT behavior)

### Leather Sheet (`source/leather_sheet_api.php`)
- ✅ Uses `uom_code` for sheet UOM reference

### DAG Routing (`source/dag_routing_api.php`)
- ✅ Uses `code` for work center reference in routing nodes
- ✅ Never uses `id_work_center` for cross-tenant operations

---

## Error Messages

### UOM Errors
- `UOM_403_SYSTEM_DELETE` - System UOM cannot be deleted
- `UOM_403_SYSTEM_CODE_LOCKED` - System UOM code cannot be changed
- `UOM_403_CODE_LOCKED` - UOM code cannot be changed for locked records

### Work Center Errors
- `WKC_403_SYSTEM_DELETE` - System Work Center cannot be deleted
- `WKC_403_SYSTEM_CODE_LOCKED` - System Work Center code cannot be changed
- `WKC_403_CODE_LOCKED` - Work Center code cannot be changed for locked records

---

## Migration Instructions

1. **Run migration:**
   ```bash
   php source/bootstrap_migrations.php --tenant=<tenant_code>
   ```

2. **Verify system rows:**
   ```sql
   SELECT code, name, is_system, locked FROM unit_of_measure WHERE is_system = 1;
   SELECT code, name, is_system, locked FROM work_center WHERE is_system = 1;
   ```

3. **Test UI:**
   - Open UOM management screen
   - Verify system UOM shows "🔒 System" badge
   - Verify delete button is disabled for system UOM
   - Try editing system UOM - code field should be readonly
   - Repeat for Work Center screen

---

## Notes

- **System rows** are identified by `is_system=1`
- **Locked rows** are identified by `locked=1` (can be non-system)
- **Cross-tenant logic** must reference UOM/Work Center by code, not id
- **Seed data** from `0002_seed_data.php` defines canonical system rows
- **Template tenant** (`bgerp_t_maison_atelier`) is the source of truth

---

**Last Updated:** 2025-12-15  
**Maintained By:** Bellavier Group ERP Engineering Team

