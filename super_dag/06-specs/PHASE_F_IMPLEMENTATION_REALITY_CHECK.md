# Phase F Implementation - Reality Check Notes

**Date:** 2026-01-03  
**Purpose:** Document existing UI structure before Phase F implementation

---

## ✅ Constraints Modal Location

**HTML Template:**
- File: `views/products.php`
- Lines: 685-729
- Modal ID: `material-constraints-modal`
- Form ID: `constraints-form`
- Container: `#constraints-fields-container` (dynamic fields rendered here)

**JavaScript Functions:**
- File: `assets/javascripts/products/product_components.js`
- `openConstraintsModal(materialIndex)` - line 1013
- `loadAndRenderConstraintFields(roleCode, existingConstraints)` - line 1056
- `handleConstraintsFormSubmit(e)` - line 1151

---

## ✅ qty_required Field Location

**In Materials Table Row:**
- File: `assets/javascripts/products/product_components.js`
- Line: 667
- Current: `<input type="number" class="form-control form-control-sm material-qty" value="${material.qty_required}" step="0.01" min="0.01" required>`
- Location: Inside `createMaterialRow()` function
- **Action Required:** Make read-only when constraints_json exists

---

## ✅ constraints_json Storage

- Stored in: `tempMaterials[index].constraints_json`
- Loaded in: `loadAndRenderConstraintFields()` - parses JSON and renders fields dynamically
- Saved in: `handleConstraintsFormSubmit()` - builds object from form fields, sends to API

---

## ✅ Material Default UoM Code

- Available as: `material.default_uom_code` or `m.default_uom_code`
- Displayed in: Table row `<span class="material-uom-display">` (line 670)
- Loaded from: Material options with `data-uom` attribute (line 634)
- **Action Required:** Show in constraints modal as read-only badge

---

## Files to Modify

1. **`assets/javascripts/products/product_components.js`**
   - `loadAndRenderConstraintFields()` - Add unit_locked, width, length, thickness_mm, piece_count, waste_factor_percent fields
   - `createMaterialRow()` - Make qty_required read-only when constraints exist
   - `openConstraintsModal()` - Show material name, UoM, basis_type badges
   - `handleConstraintsFormSubmit()` - Add computed qty preview, validation blocking

2. **`views/products.php`**
   - `#material-constraints-modal` - Add contextual display section (material name, UoM, basis_type)

3. **`source/product_api.php`**
   - `handleAddComponentMaterial()` - Already computes qty, but need to enforce incomplete rejection
   - `handleUpdateComponentMaterial()` - Already computes qty, but need to enforce incomplete rejection, add override_mode support

4. **`source/BGERP/Service/ProductComponentService.php`**
   - `addMaterial()` - Already computes, may need constraint completeness check
   - `updateMaterial()` - Already computes, may need constraint completeness check

5. **New Files:**
   - `docs/super_dag/06-specs/PHASE_F_QTY_REQUIRED_USAGE_AUDIT.md` - Audit report
   - Test files (TBD)

---

## Current Constraints Field System

- Fields are **dynamically rendered** from `material_role_field` table
- Uses `list_role_fields` API endpoint
- Renders based on `field_type`: number, text, boolean, select, json

**Challenge:** Must add specific fields (width, length, piece_count, etc.) that may not exist in role fields table yet. Need to ensure these fields are available OR add them to the dynamic rendering system.

---

## Next Steps

1. Update `loadAndRenderConstraintFields()` to include required fields
2. Add contextual badges to modal
3. Make qty_required read-only in table row
4. Add computed qty preview in modal
5. Add validation blocking logic
6. Update server-side enforcement
7. Create audit report
8. Add override_mode support
9. Write tests
