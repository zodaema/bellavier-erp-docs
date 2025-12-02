# Task 13.12 Results — Leather Sheet Binding UX + API for CUT Behavior

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [13.12.md](13.12.md)

---

## Summary

Task 13.12 successfully implemented the Leather Sheet Usage Binding system for CUT behavior, allowing workers to select and record leather sheets used during cutting operations. The system provides full traceability from GRN → Sheet → Token usage while maintaining a simple, warehouse-friendly UX.

---

## Deliverables

### 1. Database Layer

**File:** `database/tenant_migrations/2025_12_leather_sheet_usage.php`

**New Table: `leather_sheet_usage_log`**
- `id_usage` (PK, AUTO_INCREMENT)
- `id_sheet` (FK → `leather_sheet.id_sheet`)
- `token_id` (FK → `flow_token.id_token`)
- `used_area` (DECIMAL(8,2)) — Area used in sq.ft
- `used_by` (INT, FK → `account.id_member`)
- `note` (TEXT, nullable)
- `created_at`, `updated_at`

**Indexes:**
- `idx_sheet_token` (id_sheet, token_id)
- `idx_token` (token_id)
- `idx_sheet` (id_sheet)
- `idx_used_by` (used_by)
- `idx_created_at` (created_at)

**Foreign Keys:**
- `fk_usage_sheet` → `leather_sheet(id_sheet)` ON DELETE RESTRICT
- `fk_usage_token` → `flow_token(id_token)` ON DELETE RESTRICT

**Safety:**
- ✅ Idempotent migration
- ✅ No changes to existing `leather_sheet` structure
- ✅ No changes to GRN structure

---

### 2. API Endpoint

**File:** `source/leather_sheet_api.php`

**Actions Implemented:**

#### a) `list_available_sheets`
- **Input:** `material_sku` (required), `search` (optional)
- **Output:** List of available sheets with:
  - `id_sheet`, `sheet_code`, `grn_number`
  - `area_original`, `area_used`, `area_remaining`
- **Logic:**
  - Calculates remaining area = `area_original - SUM(usage_log.used_area)`
  - Filters: `remaining_area > 0`, `status = 'active'`, `sku_material` matches
  - Supports search by sheet_code or GRN number
- **Permission:** `leather.sheet.view`

#### b) `bind_sheet_usage`
- **Input:** `token_id`, `sheet_id`, `used_area`, `note` (optional)
- **Output:** Usage record with `area_remaining_after`
- **Logic:**
  - Validates token exists and is active
  - Validates sheet exists
  - Soft check: Warns if `used_area > remaining` but allows (soft warning)
  - Inserts usage log in transaction
- **Permission:** `leather.sheet.use`
- **Error Codes:**
  - `LEATHER_SHEET_404_TOKEN_NOT_FOUND`
  - `LEATHER_SHEET_404_SHEET_NOT_FOUND`
  - `LEATHER_SHEET_400_INVALID_AREA`

#### c) `list_sheet_usage_by_token`
- **Input:** `token_id`
- **Output:** List of all usage logs for the token
- **Fields:** `id_usage`, `sheet_code`, `used_area`, `used_by_name`, `created_at`, `note`
- **Permission:** `leather.sheet.view`

#### d) `unbind_sheet_usage`
- **Input:** `usage_id`
- **Output:** Success message
- **Logic:**
  - Only allows deletion if token is not `completed` or `scrapped`
  - Deletes usage log record
- **Permission:** `leather.sheet.use`
- **Error Codes:**
  - `LEATHER_SHEET_404_USAGE_NOT_FOUND`
  - `LEATHER_SHEET_403_TOKEN_COMPLETED`

**API Features:**
- ✅ Uses `TenantApiBootstrap` and `TenantApiOutput`
- ✅ Rate limiting (60 requests per 60 seconds)
- ✅ Comprehensive error handling
- ✅ Transaction safety for `bind_sheet_usage`
- ✅ Standardized error codes with `app_code`

---

### 3. CUT Behavior UI Integration

**File:** `assets/javascripts/dag/behavior_ui_templates.js`

**CUT Template Updates:**
- Added "Leather Sheets Used" section
- Table displaying:
  - Sheet Code
  - Used Area (sq.ft)
  - Time (created_at)
  - User (used_by_name)
  - Actions (delete button)
- "เลือก Leather Sheet" button
- Empty state message when no sheets selected

**File:** `assets/javascripts/dag/behavior_execution.js`

**CUT Handler Updates:**
- **`loadSheetUsages()`:** Fetches existing usage logs for token
- **`renderSheetUsageList()`:** Renders usage table
- **`openSheetSelectionModal()`:** Opens sheet selection (simplified MVP with prompts)
- **`deleteUsage()`:** Deletes usage log (with confirmation)
- **Soft Warning on Complete:** Shows warning if no sheet usage recorded, but allows completion

**UX Flow:**
1. Worker opens CUT behavior panel
2. Clicks "เลือก Leather Sheet"
3. Enters Material SKU (prompt)
4. Selects sheet from list
5. Enters used area
6. Usage appears in table
7. Can delete usage before complete
8. On complete: Soft warning if no usage, but allows proceed

**Limitations (MVP):**
- Sheet selection uses simple prompts (not full modal)
- Material SKU must be entered manually
- No advanced search/filter in selection

---

### 4. Permissions

**File:** `database/tenant_migrations/2025_12_leather_sheet_usage_permissions.php`

**New Permissions:**
- `leather.sheet.view` — View leather sheet usage logs and available sheets
- `leather.sheet.use` — Bind leather sheet usage to tokens (CUT behavior)

**Auto-Assignment:**
- Both permissions assigned to `admin` role (tenant admin)

---

### 5. Backend Integration (BehaviorExecutionService)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Current State:**
- `handleCutComplete()` does not enforce sheet usage requirement
- Returns success even if no sheet usage recorded
- Can be extended in future to include usage data in response

**Future Enhancement (Not in Task 13.12):**
- Add `sheet_usage` field to `handleCutComplete()` response
- Optional: Auto-fetch usage logs and include in response

---

## Technical Implementation

### Remaining Area Calculation

```sql
SELECT 
    ls.area_sqft AS area_original,
    COALESCE(SUM(usg.used_area), 0) AS area_used,
    (ls.area_sqft - COALESCE(SUM(usg.used_area), 0)) AS area_remaining_calculated
FROM leather_sheet ls
LEFT JOIN leather_sheet_usage_log usg ON usg.id_sheet = ls.id_sheet
WHERE ls.id_sheet = ?
GROUP BY ls.id_sheet, ls.area_sqft
HAVING area_remaining_calculated > 0
```

**Key Points:**
- Uses `LEFT JOIN` to include sheets with no usage
- `COALESCE(SUM(...), 0)` handles NULL case
- `HAVING` clause filters only sheets with remaining area > 0

### Transaction Safety

```php
$tenantDb->begin_transaction();
try {
    // Insert usage log
    $stmt = $tenantDb->prepare("INSERT INTO leather_sheet_usage_log ...");
    $stmt->execute();
    
    $tenantDb->commit();
} catch (\Exception $e) {
    $tenantDb->rollback();
    throw $e;
}
```

**Benefits:**
- Atomic operation
- Rollback on any error
- Prevents partial data

---

## User Experience Flow

### Scenario: Worker Cuts 5 Pieces Using 2 Leather Sheets

```
1. Worker opens CUT behavior panel for token #123
   ↓
2. Clicks "เลือก Leather Sheet"
   ↓
3. Enters Material SKU: "MAT-SAFF-001"
   ↓
4. System shows available sheets:
   - MAT-SAFF-20251120-001 (เหลือ 12.5 sq.ft)
   - MAT-SAFF-20251120-002 (เหลือ 15.0 sq.ft)
   ↓
5. Worker selects sheet #1, enters used_area: 3.5 sq.ft
   ↓
6. Usage appears in table:
   - Sheet Code: MAT-SAFF-20251120-001
   - Used Area: 3.50 sq.ft
   - Time: 2025-11-20 14:30
   - User: Somchai
   ↓
7. Worker selects sheet #2, enters used_area: 2.0 sq.ft
   ↓
8. Table now shows 2 rows
   ↓
9. Worker clicks "Complete Cutting"
   ↓
10. System routes token to STITCH node
    ↓
11. Usage logs remain in database for traceability
```

---

## Safety & Compatibility

### No Breaking Changes:
- ✅ No changes to `leather_sheet` table structure
- ✅ No changes to GRN flow
- ✅ No changes to CUT behavior execution logic
- ✅ Soft warning only (does not block completion)

### Data Integrity:
- ✅ Foreign key constraints ensure referential integrity
- ✅ Transaction safety for usage binding
- ✅ Soft validation (warns but allows over-usage)
- ✅ Deletion protection for completed tokens

### Backward Compatibility:
- ✅ CUT behavior works without sheet usage (soft warning)
- ✅ Existing tokens unaffected
- ✅ No migration required for existing data

---

## Testing & Verification

### Syntax Checks
✅ All PHP files pass `php -l`:
- `source/leather_sheet_api.php`
- `database/tenant_migrations/2025_12_leather_sheet_usage.php`
- `database/tenant_migrations/2025_12_leather_sheet_usage_permissions.php`

### Manual Test Cases

**Test 1: List Available Sheets**
- ✅ Filter by material_sku
- ✅ Search by sheet_code
- ✅ Calculate remaining area correctly
- ✅ Only show sheets with remaining > 0

**Test 2: Bind Sheet Usage**
- ✅ Valid token + sheet + area → Success
- ✅ Invalid token → 404 error
- ✅ Invalid sheet → 404 error
- ✅ Area > remaining → Warning but allows
- ✅ Transaction rollback on error

**Test 3: List Usage by Token**
- ✅ Returns all usages for token
- ✅ Includes sheet_code, used_area, user, time
- ✅ Ordered by created_at DESC

**Test 4: Unbind Usage**
- ✅ Delete usage for active token → Success
- ✅ Delete usage for completed token → 403 error
- ✅ Invalid usage_id → 404 error

**Test 5: CUT Behavior UI**
- ✅ Panel shows usage table
- ✅ "เลือก Leather Sheet" button works
- ✅ Usage list updates after binding
- ✅ Delete button works
- ✅ Soft warning on complete if no usage

---

## Acceptance Criteria Status

- ✅ Worker can select Leather Sheet from CUT panel
- ✅ Worker can enter used_area and save
- ✅ Usage logs stored in `leather_sheet_usage_log` with token, sheet, worker
- ✅ Remaining area calculated correctly in `list_available_sheets`
- ✅ CUT complete works without usage (soft warning only)
- ✅ CUT panel displays list of used sheets
- ✅ Supervisor can query usage via API (no UI yet)
- ✅ No changes to GRN / leather_sheet structure
- ✅ No impact on Standard GRN or Material system
- ✅ All syntax checks pass

---

## Files Created/Modified

### Created:
1. `database/tenant_migrations/2025_12_leather_sheet_usage.php`
2. `database/tenant_migrations/2025_12_leather_sheet_usage_permissions.php`
3. `source/leather_sheet_api.php`
4. `docs/dag/tasks/task13.12_results.md`

### Modified:
1. `assets/javascripts/dag/behavior_ui_templates.js`
   - Updated CUT template with Leather Sheets Used section

2. `assets/javascripts/dag/behavior_execution.js`
   - Added CUT handler logic for sheet selection, usage list, delete

---

## Known Limitations (MVP)

1. **Sheet Selection UI:**
   - Uses simple prompts instead of full modal
   - No advanced search/filter
   - Material SKU must be entered manually

2. **Material SKU Detection:**
   - Not automatically detected from token/product
   - Worker must know Material SKU

3. **Usage Validation:**
   - Soft warning only (does not block)
   - No enforcement of completeness

4. **Supervisor UI:**
   - API exists but no dedicated UI page
   - Can be accessed via API calls

---

## Future Enhancements

1. **Enhanced Sheet Selection Modal:**
   - Full modal with DataTable
   - Search by sheet_code, GRN, batch
   - Visual indicators for remaining area
   - Multi-select support

2. **Auto Material SKU Detection:**
   - Extract from token → product → BOM → material
   - Pre-fill Material SKU in selection

3. **Usage Enforcement (Optional):**
   - Hard block if no usage recorded
   - Configurable per work center

4. **Supervisor UI:**
   - Dedicated page for viewing usage
   - Filters by token, sheet, date range
   - Export to CSV

5. **Batch Usage:**
   - Record multiple sheets at once
   - Bulk operations

---

## Notes

- **Soft Warning Approach:** Task 13.12 intentionally uses soft warnings to allow flexibility. Hard enforcement can be added in future tasks if needed.
- **MVP UI:** Sheet selection uses prompts for MVP. Full modal can be implemented in future tasks.
- **Traceability:** All usage is logged with token, sheet, worker, and timestamp for full audit trail.
- **Performance:** Queries use indexes for fast lookups. Remaining area calculation is efficient with GROUP BY and HAVING.

---

**Task 13.12 Complete** ✅

**Leather Sheet Usage Binding: Connected GRN → CUT → Token**

