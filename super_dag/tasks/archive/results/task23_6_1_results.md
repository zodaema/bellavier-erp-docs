# Task 23.6.1 Results — MO UI: Edit & Update Integration

**Status:** ✅ Completed  
**Date:** November 28, 2025  
**Category:** SuperDAG / MO Planning / Frontend Integration

**⚠️ IMPORTANT:** This task implements the frontend UI layer for MO editing, connecting to the backend `handleUpdate()` function from Task 23.6.

---

## 1. Executive Summary

Task 23.6.1 successfully implemented:

- **Edit Button** - Added "Edit" button to MO list table (DataTables)
- **Edit Modal** - Created Bootstrap modal for editing MO fields
- **JavaScript Handlers** - Implemented click handler and form submission
- **Data Binding** - Populates modal from DataTables row data
- **API Integration** - Connects to `source/mo.php?action=update`
- **Translation Support** - Added English and Thai translations

**Key Achievements:**
- ✅ Added Edit button to MO list (conditional on status and permission)
- ✅ Created `#moEditModal` Bootstrap modal with all editable fields
- ✅ Implemented data binding from DataTables row to modal form
- ✅ Connected form submission to `mo.php?action=update`
- ✅ Enhanced `handleList()` to return additional fields for editing
- ✅ Added translation keys for all new UI elements

---

## 2. Implementation Details

### 2.1 Edit Button in MO List (`assets/javascripts/mo/mo.js`)

**Location:** DataTables action column render function

**Features:**
- Shows Edit button for MOs that can be edited (not done/completed/cancelled)
- Requires `mo.update` permission
- Button class: `btn-mo-edit`
- Data attribute: `data-id-mo` with MO ID
- Icon: `fe fe-edit`

**Code:**
```javascript
// Edit button: Task 23.6.1 - Show for MOs that can be edited
if (canDo('mo.update') && status !== 'done' && status !== 'completed' && status !== 'cancelled') {
  buttons.push(`<button class="btn btn-sm btn-outline-primary btn-mo-edit" data-id-mo="${row.id_mo}">
    <i class="fe fe-edit me-1"></i>${t('mo.action.edit', 'Edit')}
  </button>`);
}
```

### 2.2 Edit Modal (`views/mo.php`)

**Modal ID:** `moEditModal`  
**Form ID:** `moEditForm`

**Fields:**
- Hidden: `id_mo` (MO ID)
- Read-only: Product (display only, cannot be changed)
- Editable:
  - Quantity (`qty`) - Required, min 0.01
  - UoM (`uom_code`)
  - Due Date (`due_date`)
  - Scheduled Start Date (`scheduled_start_date`)
  - Scheduled End Date (`scheduled_end_date`)
  - Notes (`notes`)
  - Description (`description`)

**UI Features:**
- Bootstrap 5 modal with `modal-lg` size
- Error/Success message areas
- Form validation (HTML5 + JavaScript)
- Responsive layout (row/col structure)

### 2.3 JavaScript Handlers (`assets/javascripts/mo/mo.js`)

**1. Edit Button Click Handler:**
```javascript
$(document).on('click', '.btn-mo-edit', function () {
  const moId = $(this).data('id-mo');
  const table = $('#tbl-mo').DataTable();
  const rowData = table.row($(this).closest('tr')).data();
  
  // Populate modal fields from rowData
  // Show modal
});
```

**Features:**
- Reads MO ID from button data attribute
- Gets row data from DataTables
- Populates all modal fields
- Clears error/success messages
- Shows Bootstrap modal

**2. Form Submit Handler:**
```javascript
$('#moEditForm').on('submit', function (e) {
  e.preventDefault();
  
  // Build formData
  // Validate qty > 0
  // POST to mo.php?action=update
  // Handle success/error
  // Reload DataTable
  // Close modal after delay
});
```

**Features:**
- Prevents default form submission
- Validates quantity > 0
- Sends POST request to `source/mo.php?action=update`
- Shows success/error messages in modal
- Reloads DataTable without full page refresh
- Closes modal after 800ms delay on success

### 2.4 Backend Enhancement (`source/mo.php`)

**Enhanced `handleList()` Function:**

**Added Fields to SELECT:**
- `m.due_date`
- `m.scheduled_start_date`
- `m.scheduled_end_date`
- `m.notes`
- `m.description`

**Added Fields to Response:**
- `uom_code` (for editing)
- `due_date`
- `scheduled_start_date`
- `scheduled_end_date`
- `notes`
- `description`

**Purpose:** Provide all necessary data for Edit modal without additional API call.

### 2.5 Translation Keys

**English (`lang/en.php`):**
- `mo.action.edit` => 'Edit'
- `mo.action.save_changes` => 'Save changes'
- `mo.modal.edit_title` => 'Edit Manufacturing Order'
- `mo.toast.updated` => 'MO updated successfully'
- `mo.error.row_not_found` => 'Row data not found'
- `mo.error.qty_required` => 'Quantity must be greater than 0'
- `mo.form.product_readonly` => 'Product cannot be changed after MO creation'
- `mo.form.notes` => 'Notes'
- `mo.form.description` => 'Description'

**Thai (`lang/th.php`):**
- `mo.action.edit` => 'แก้ไข'
- `mo.action.save_changes` => 'บันทึกการเปลี่ยนแปลง'
- `mo.modal.edit_title` => 'แก้ไขใบสั่งการผลิต'
- `mo.toast.updated` => 'อัปเดตใบสั่งการผลิตเรียบร้อย'
- `mo.error.row_not_found` => 'ไม่พบข้อมูลแถว'
- `mo.error.qty_required` => 'จำนวนต้องมากกว่า 0'
- `mo.form.product_readonly` => 'ไม่สามารถเปลี่ยนสินค้าหลังจากสร้าง MO แล้ว'
- `mo.form.notes` => 'หมายเหตุ'
- `mo.form.description` => 'รายละเอียด'

---

## 3. User Flow

### 3.1 Edit MO Flow

```
1. User views MO list
   ↓
2. User clicks "Edit" button on a MO row
   ↓
3. Modal opens with current MO data populated
   ↓
4. User modifies fields (qty, dates, notes, etc.)
   ↓
5. User clicks "Save changes"
   ↓
6. JavaScript validates (qty > 0)
   ↓
7. POST to mo.php?action=update
   ↓
8. Backend processes:
   - Detects ETA-sensitive field changes
   - Updates MO in transaction
   - Invalidates ETA cache (if needed)
   - Recomputes ETA (best-effort)
   - Logs to MOEtaHealthService
   ↓
9. Response returned to frontend
   ↓
10. On success:
    - Show success message in modal
    - Reload DataTable
    - Close modal after 800ms
    - Show toast notification
```

### 3.2 Error Handling Flow

```
Form Submit
   ↓
Validation (qty > 0)
   ├─ Fail → Show error in modal, don't submit
   └─ Pass → Continue
   ↓
POST to API
   ├─ Success → Show success, reload table, close modal
   └─ Error → Show error message in modal, keep modal open
```

---

## 4. Files Modified

### 4.1 `assets/javascripts/mo/mo.js`
- **Added:** Edit button in action column render function
- **Added:** `.btn-mo-edit` click handler (~30 lines)
- **Added:** `#moEditForm` submit handler (~40 lines)
- **Lines Added:** ~70 lines

### 4.2 `views/mo.php`
- **Added:** `#moEditModal` Bootstrap modal (~80 lines)
- **Fields:** All editable MO fields
- **Layout:** Responsive row/col structure

### 4.3 `source/mo.php`
- **Modified:** `handleList()` function
- **Added:** Additional fields to SELECT query
- **Added:** Additional fields to response mapping
- **Lines Modified:** ~15 lines

### 4.4 `lang/en.php`
- **Added:** 8 new translation keys for Edit UI
- **Lines Added:** ~8 lines

### 4.5 `lang/th.php`
- **Added:** 8 new translation keys for Edit UI (Thai)
- **Lines Added:** ~8 lines

---

## 5. Design Decisions

### 5.1 Product Field Read-Only

**Decision:** Product field is read-only in Edit modal.

**Rationale:**
- Product change would require routing graph re-evaluation
- Product change is a major structural change
- Better UX: Create new MO for different product
- Prevents accidental product changes

**Implementation:**
```html
<input type="text" class="form-control" id="moEditProduct" disabled>
<small class="form-text text-muted">Product cannot be changed after MO creation</small>
```

### 5.2 Data Binding from DataTables

**Decision:** Use DataTables row data directly instead of separate API call.

**Rationale:**
- Faster (no additional API call)
- Simpler implementation
- Data already available in list response
- Task 23.6.1 requirement: "use data from list"

**Limitation:**
- If list doesn't include all fields, they won't be populated
- Solution: Enhanced `handleList()` to include all necessary fields

### 5.3 Modal Close Delay

**Decision:** Close modal 800ms after successful update.

**Rationale:**
- Gives user time to see success message
- Better UX than immediate close
- Allows user to read confirmation

**Implementation:**
```javascript
setTimeout(() => {
  const modal = bootstrap.Modal.getInstance(modalEl);
  if (modal) modal.hide();
}, 800);
```

### 5.4 Status-Based Edit Button Visibility

**Decision:** Hide Edit button for done/completed/cancelled MOs.

**Rationale:**
- Matches backend validation (`handleUpdate()` rejects done/cancelled)
- Prevents user confusion
- Clear UX: Can't edit finalized MOs

**Implementation:**
```javascript
if (canDo('mo.update') && status !== 'done' && status !== 'completed' && status !== 'cancelled') {
  // Show Edit button
}
```

---

## 6. Testing Scenarios

### 6.1 Normal Edit Flow

**Test:**
1. Open MO list page
2. Click Edit button on a draft/planned MO
3. Change qty from 10 to 20
4. Click Save changes

**Expected:**
- ✅ Modal opens with current data
- ✅ Form submits successfully
- ✅ Success message appears
- ✅ DataTable refreshes
- ✅ Qty shows as 20
- ✅ Modal closes after 800ms
- ✅ Toast notification appears

### 6.2 Edit Notes Only

**Test:**
1. Edit MO: Change notes only
2. Save

**Expected:**
- ✅ MO updates successfully
- ✅ Notes field updated
- ✅ ETA cache NOT invalidated (notes is not ETA-sensitive)
- ✅ No ETA recompute triggered

### 6.3 Edit ETA-Sensitive Field

**Test:**
1. Edit MO: Change qty from 10 to 20
2. Save

**Expected:**
- ✅ MO updates successfully
- ✅ ETA cache invalidated
- ✅ ETA recomputed (best-effort)
- ✅ `MOEtaHealthService::onMoUpdated()` called
- ✅ Health log entry created

### 6.4 Edit Disabled for Finalized MO

**Test:**
1. Try to edit MO with status = 'done' or 'cancelled'

**Expected:**
- ✅ Edit button NOT visible
- ✅ (If somehow accessed) Backend returns error

### 6.5 Validation Error

**Test:**
1. Edit MO: Set qty to 0 or negative
2. Try to save

**Expected:**
- ✅ Frontend validation prevents submission
- ✅ Error message shown in modal
- ✅ Modal stays open
- ✅ No API call made

### 6.6 Backend Error

**Test:**
1. Edit MO: Try to edit MO in invalid status (simulate)
2. Save

**Expected:**
- ✅ Backend returns error
- ✅ Error message shown in `#moEditError`
- ✅ Modal stays open
- ✅ DataTable NOT refreshed

---

## 7. Code Statistics

- **Files Modified:** 5
- **Lines Added:** ~180
- **Lines Modified:** ~15
- **New UI Components:** 1 (Edit Modal)
- **New JavaScript Handlers:** 2 (click, submit)
- **Translation Keys Added:** 8 (English + Thai)

---

## 8. Known Limitations

1. **No Routing Graph Edit:** Routing graph cannot be changed via Edit modal (would require complex validation).

2. **No Real-time ETA Preview:** Edit modal doesn't show ETA preview (Task 23.6.1 scope: UI only).

3. **No Field-Level Validation:** Only basic qty validation. Backend handles full validation.

4. **No Change History:** Edit history not tracked in UI (only in health log).

5. **No Bulk Edit:** Only single MO edit supported.

---

## 9. Future Enhancements

1. **ETA Preview in Modal:** Show ETA preview when ETA-sensitive fields change.

2. **Change Diff Display:** Show what changed before saving.

3. **Field-Level Validation:** Real-time validation feedback.

4. **Routing Graph Edit:** Allow routing graph change with validation.

5. **Edit History:** Display edit history in MO detail view.

---

## 10. Integration with Task 23.6

Task 23.6.1 connects seamlessly with Task 23.6 backend:

- **Frontend:** User edits MO via modal
- **Backend:** `handleUpdate()` processes update
- **ETA Cache:** Automatically invalidated if ETA-sensitive fields change
- **Health Service:** Update events logged automatically
- **Non-Blocking:** ETA failures don't block MO update

**Result:** Complete end-to-end MO edit functionality with ETA cache consistency.

---

## 11. Conclusion

Task 23.6.1 successfully implements the frontend UI layer for MO editing:

- ✅ Edit button in MO list (status and permission aware)
- ✅ Bootstrap modal for editing MO fields
- ✅ Data binding from DataTables to modal
- ✅ Form submission to `mo.php?action=update`
- ✅ Success/error handling
- ✅ DataTable refresh after update
- ✅ Translation support (English + Thai)
- ✅ Integration with Task 23.6 backend

**Result:** Users can now edit MO records through the UI, with automatic ETA cache management handled by the backend.

