# Task 13.10 Results — Unified Leather GRN Flow (One-Entry Point)

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [13.10.md](13.10.md)

---

## Summary

Task 13.10 successfully implemented a unified Leather GRN (Goods Receipt Note) flow that allows warehouse staff to receive leather sheets in a single entry point, eliminating the need to manually create Material Lots and Leather Sheets separately. The system creates both `material_lot` (GRN header) and `leather_sheet` records in one atomic transaction.

---

## Deliverables

### 1. Database Migration

**File:** `database/tenant_migrations/2025_12_leather_grn_unified_flow.php`

**Changes:**
- Added `is_leather_grn` flag to `material_lot` table (TINYINT(1), default 0)
- Added `id_lot` FK column to `leather_sheet` table (INT NULL, FK to `material_lot.id_material_lot`)
- Added foreign key constraint `fk_leather_sheet_lot`
- Added indexes:
  - `idx_leather_sheet_lot_sku_status` on `leather_sheet` (sku_material, id_lot, status)
  - `idx_material_lot_sku_leather_grn` on `material_lot` (id_stock_item, is_leather_grn)

**Migration Features:**
- Idempotent (uses `migration_add_column_if_missing`, `migration_add_index_if_missing`)
- Checks for existing FK constraints before adding
- Backward compatible (allows NULL id_lot for existing sheets)

---

### 2. Permission Migration

**File:** `database/tenant_migrations/2025_12_leather_grn_permission.php`

**Changes:**
- Created new permission: `leather_grn.manage`
- Auto-assigned to `admin` role (TENANT_ADMIN)
- Idempotent permission creation and assignment

---

### 3. API Endpoint

**File:** `source/leather_grn.php`

**Actions Implemented:**

1. **`init` (GET)**
   - Returns leather materials (filtered by material_type containing 'leather')
   - Returns default values (grades, locations, thickness defaults)
   - Permission: `leather_grn.manage`

2. **`save` (POST)**
   - Accepts GRN header + sheets array
   - Validates input (material SKU, sheet codes, areas)
   - Auto-generates GRN number if not provided (format: `GRN-YYYYMMDD-NNNN`)
   - Creates `material_lot` with `is_leather_grn = 1`
   - Creates `leather_sheet` records linked via `id_lot`
   - All operations in single transaction (rollback on error)
   - Returns created lot, sheets, and summary
   - Permission: `leather_grn.manage`

3. **`list` (GET)**
   - Lists GRN records (material_lot with is_leather_grn = 1)
   - Includes sheet count per GRN
   - Uses SSDT for server-side DataTable support
   - Permission: `leather_grn.manage`

**API Features:**
- Uses `TenantApiBootstrap` and `TenantApiOutput`
- Rate limiting (60 requests per 60 seconds)
- Comprehensive input validation
- Transaction-safe operations
- Error handling with clear messages

---

### 4. Frontend - Page Definition

**File:** `page/leather_grn.php`

**Features:**
- Page name: "Leather GRN"
- Permission: `leather_grn.manage`
- Loads required CSS/JS libraries (DataTables, SweetAlert2, Toastr, Flatpickr)
- Custom JS: `assets/javascripts/materials/leather_grn.js`

---

### 5. Frontend - View Template

**File:** `views/leather_grn.php`

**UI Sections:**

**A. GRN Header Form:**
- GRN Number (optional, auto-generate)
- Material SKU (select2 dropdown, filtered to leather materials)
- Supplier Name
- Invoice Number
- Received Date (default: today)
- Grade (A/B/C/D dropdown)
- Thickness (mm)
- Location
- Notes
- Total Sheets (with "Generate Rows" button)

**B. Leather Sheets Table:**
- Dynamic rows (generated based on total_sheets)
- Columns: No., Sheet Code, Area (sq.ft), Weight (kg), Actions
- Auto-generated sheet codes: `{SKU}-{GRN}-{NNN}`
- "Fill All with Area" button for bulk entry
- Delete row functionality

**C. Actions:**
- Clear Form button
- Save GRN button (with confirmation dialog)

**Features:**
- Auto-generates sheet codes when material selected
- Validates all inputs before submission
- Shows success/error notifications
- Clears form after successful save

---

### 6. Frontend - JavaScript Logic

**File:** `assets/javascripts/materials/leather_grn.js`

**Functions:**

1. **`initPage()`**
   - Loads initial data (materials, defaults)
   - Binds event handlers
   - Generates initial sheet rows

2. **`generateSheetRows(count)`**
   - Creates dynamic table rows for sheets
   - Auto-generates sheet codes
   - Updates total_sheets field

3. **`updateSheetCodes(sku)`**
   - Updates all sheet codes when material changes
   - Format: `{SKU}-{GRN}-{NNN}`

4. **`collectFormData()`**
   - Gathers header and sheets data
   - Validates required fields

5. **`validateForm()`**
   - Validates material SKU
   - Validates sheet codes and areas
   - Checks total_sheets matches row count

6. **`saveGRN()`**
   - Shows confirmation dialog
   - Sends AJAX POST to API
   - Handles success/error responses
   - Clears form on success

7. **`clearForm()`**
   - Resets all form fields
   - Regenerates default rows

**Event Handlers:**
- Generate Rows button
- Fill All Area button
- Save GRN button
- Clear Form button
- Material SKU change (updates sheet codes)
- Delete row buttons

---

### 7. Sidebar Menu Integration

**File:** `views/template/sidebar-left.template.php`

**Changes:**
- Added "Leather GRN" menu item under Inventory (Stores) > Masters
- Icon: `ri-scissors-cut-line`
- Permission: `leather_grn.manage`
- Position: After "Materials", before "Warehouses"

---

## Data Flow

### Create GRN Flow:

```
1. User opens Leather GRN page
   ↓
2. Selects material SKU (leather materials only)
   ↓
3. Fills GRN header (supplier, invoice, date, etc.)
   ↓
4. Sets total_sheets → Clicks "Generate Rows"
   ↓
5. System generates N rows with auto-generated sheet codes
   ↓
6. User fills area (and optionally weight) for each sheet
   ↓
7. Clicks "Save GRN"
   ↓
8. JavaScript validates form
   ↓
9. API receives POST with header + sheets array
   ↓
10. API validates input
    ↓
11. API generates GRN number (if not provided)
    ↓
12. Transaction begins:
    a. INSERT material_lot (is_leather_grn = 1)
    b. For each sheet: INSERT leather_sheet (id_lot = material_lot.id)
    ↓
13. Transaction commits
    ↓
14. API returns success with lot, sheets, summary
    ↓
15. UI shows success message, clears form
```

---

## Database Schema Changes

### material_lot Table:
- **New Column:** `is_leather_grn` TINYINT(1) NOT NULL DEFAULT 0
  - Flags lots created via Leather GRN flow
  - Allows filtering GRN records

### leather_sheet Table:
- **New Column:** `id_lot` INT NULL
  - Foreign key to `material_lot.id_material_lot`
  - Links sheets to their GRN lot
  - NULL allowed for backward compatibility

### Indexes Added:
- `idx_leather_sheet_lot_sku_status` on `leather_sheet` (sku_material, id_lot, status)
- `idx_material_lot_sku_leather_grn` on `material_lot` (id_stock_item, is_leather_grn)

---

## Validation Rules

**Header Validation:**
- Material SKU: Required, must be leather material
- Total Sheets: Required, must match number of sheet rows

**Sheet Validation:**
- Sheet Code: Required, unique per GRN
- Area (sq.ft): Required, must be > 0
- Weight (kg): Optional

**API Validation:**
- Material must exist and be leather type
- Sheet count must match total_sheets
- All sheet codes must be unique
- All areas must be > 0

---

## Error Handling

**Client-Side:**
- Form validation before submission
- Clear error messages
- Toast notifications for errors

**Server-Side:**
- Input validation with specific error codes
- Transaction rollback on any error
- Detailed error messages returned to client

**Error Codes:**
- `LEATHER_GRN_400_MISSING_HEADER`
- `LEATHER_GRN_400_MISSING_SKU`
- `LEATHER_GRN_400_INVALID_MATERIAL`
- `LEATHER_GRN_400_MISSING_SHEETS`
- `LEATHER_GRN_400_SHEET_COUNT_MISMATCH`
- `LEATHER_GRN_400_MISSING_SHEET_CODE`
- `LEATHER_GRN_400_INVALID_AREA`
- `LEATHER_GRN_403_PERMISSION_DENIED`
- `LEATHER_GRN_500_SERVER_ERROR`

---

## Testing & Verification

### Syntax Checks
✅ All PHP files pass `php -l`:
- `database/tenant_migrations/2025_12_leather_grn_unified_flow.php`
- `database/tenant_migrations/2025_12_leather_grn_permission.php`
- `source/leather_grn.php`
- `page/leather_grn.php`
- `views/leather_grn.php`

### Integration Points
✅ Menu item appears in sidebar (with permission check)
✅ Page loads correctly
✅ Material dropdown filters leather materials
✅ Sheet rows generate correctly
✅ Form validation works
✅ API creates lot + sheets in transaction
✅ Success/error notifications display
✅ Form clears after successful save

---

## Acceptance Criteria Status

- ✅ Leather GRN page works (creates lot + sheets)
- ✅ DB schema changes are idempotent, no data loss
- ✅ Permission `leather_grn.manage` works, assigned to admin role
- ✅ No impact on existing flow (Materials / Lots / Components / super_dag)
- ✅ Transaction safety (all or nothing)
- ✅ Auto-generate GRN numbers
- ✅ Link sheets to lot via id_lot FK
- ✅ Filter leather materials correctly

---

## Files Created/Modified

### Created:
1. `database/tenant_migrations/2025_12_leather_grn_unified_flow.php`
2. `database/tenant_migrations/2025_12_leather_grn_permission.php`
3. `source/leather_grn.php`
4. `page/leather_grn.php`
5. `views/leather_grn.php`
6. `assets/javascripts/materials/leather_grn.js`
7. `docs/dag/tasks/task13.10_results.md`

### Modified:
1. `views/template/sidebar-left.template.php` (added menu item)

---

## Notes

- **Unified Flow:** Single entry point eliminates duplicate data entry
- **Transaction Safety:** All operations in one transaction (rollback on error)
- **Backward Compatible:** Existing Material Lots modal still works
- **Auto-Generation:** GRN numbers and sheet codes auto-generated
- **Material Filtering:** Only leather materials shown in dropdown
- **Permission Model:** Uses `leather_grn.manage` permission
- **Future Integration:** Ready for CUT behavior to select sheets from GRN

---

## Next Steps (Future Tasks)

- **CUT Behavior Integration:** Add sheet selector dropdown in CUT behavior UI (Task 13.11+)
- **GRN History View:** Enhanced list view with filters and search
- **Edit GRN:** Allow editing GRN after creation (with audit trail)
- **Bulk Operations:** Import sheets from CSV/Excel
- **Stock Movement:** Integrate with Kardex/GL posting

---

**Task 13.10 Complete** ✅

**Unified Leather GRN Flow: Operational**

