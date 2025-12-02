

# Task 13.22 — UI Locking Layer for System Master Data  
**Phase 0.4 of System Master Data Hardening**

---

## 🎯 Objective  
Implement UI-side protections and visual indicators for **System Master Data** (UOM, Work Centers, Warehouses, Locations) to ensure that users cannot accidentally modify or delete system-locked data.  
This complements the API Guard Layer (Task 13.21) and provides a clean, predictable, iOS‑like restricted environment.

---

## ✅ Scope  
UI Updates for the following pages:

- `/p=uom`
- `/p=work_centers`
- `/p=warehouses`
- `/p=locations`

---

## 🧩 Requirements

### 1. List Page Enhancements  
For each table:

#### ✔ Show lock icon  
- If `is_system = 1` OR `locked = 1`  
  → Display 🔒 next to the "code" column  
  → Row style remains the same (no color change in this phase)

#### ✔ Disable action buttons  
- Buttons "Edit" and "Delete" must be disabled:
  - Add `disabled` attribute in HTML
  - Add CSS class `disabled-action`
  - Add Tooltip:
    - TH: `"ไม่สามารถแก้ไขข้อมูลระบบได้"`
    - EN: `"System data cannot be modified."`

#### ✔ JS Prevention  
Even if someone removes the `disabled` attribute from DOM:  
- `onclick` handlers must check `row.locked` before opening modal  
- If locked → show SweetAlert error and abort

---

### 2. Edit Modal Enhancements  

If `locked=1`:

#### ✔ Lock the "code" field  
- `readonly`
- light gray background  
- Tooltip: `"System fields cannot be edited"`  

#### ✔ Show system badge inside modal  
A light-colored badge at the top:
> **🔒 System Master Data**  
> This record is part of Bellavier System Defaults and cannot be modified.

#### ✔ Disable “Save” button entirely  
- `disabled`
- Tooltip identical to list page

---

### 3. Create Modal  
- Unaffected.  
- Only user-created master data is created here.

---

## 🛡 Additional Guards (UI Side)

### A. JS Guard Layer  
Add JS function:

```
function enforceSystemLock(row) {
    if (row.locked == 1 || row.is_system == 1) {
        Swal.fire({
            icon: 'error',
            title: 'System Locked',
            text: 'This is system master data and cannot be modified.',
        });
        return false;
    }
    return true;
}
```

Use this guard in:
- `onEditClick(row)`
- `onDeleteClick(row)`
- `openEditModal(row)`

### B. DataTables Integration  
Ensure API response includes:

```
is_system: 1/0,
locked: 1/0
```

---

## 🧪 Acceptance Criteria

### ✔ UI Behavior
- System rows show 🔒  
- Buttons disabled  
- Tooltip appears  
- Attempting to click Edit/Delete shows error popup  
- System items cannot be opened in Edit modal  
- Modal Save disabled for system items  

### ✔ Safety  
- Impossible for user to modify system master data from UI  
- API Guard still blocks hidden/hacked requests  
- UI never lies about lock status  

---

## 📌 Notes
- Do NOT remove legacy user-created items (we preserve them).
- UI must recognize system seed even after AUTO_INCREMENT changes.
- Only Phase 0.4 — next phases will add full redesign with grouping + filters.

---

## 🚀 Ready for Implementation  
This task prepares all master data UI for the Full Material Pipeline (13.23–13.29).  
After Task 13.22, the entire system behaves like a locked, stable ERP platform similar to iOS core settings.