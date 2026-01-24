# UI Layout Map - Constraints Editor Modal

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** ✅ **LOCKED - Layout Specification**  
**Purpose:** Define deterministic regions and anchors for Constraints Editor Modal  
**Scope:** Material Constraints Editor (`#material-constraints-modal`)

---

## 📋 Overview

This document maps the Constraints Editor Modal into **deterministic regions** with specific selectors/anchors. These regions serve as **layout anchors** that must not be removed or renamed without explicit approval and version bump.

**Core Principle:**
> "Layout anchors are immutable" — Regions and their selectors must remain stable to prevent UI drift and enable safe UI changes.

---

## 🎯 Modal Root

### Selector
```css
#material-constraints-modal
```

### Location
- **File:** `views/products.php`
- **Lines:** 686-758
- **Type:** Bootstrap 5 Modal

### Structure
```html
<div class="modal fade" id="material-constraints-modal" tabindex="-1" aria-hidden="true" data-bs-backdrop="static" data-bs-keyboard="false">
  <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
    <div class="modal-content">
      <!-- Regions below -->
    </div>
  </div>
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (static structure)
- **JavaScript Control:** `assets/javascripts/products/product_components.js`
  - Function: `openConstraintsModal(materialIndex)` - line 1028
  - Variable: `constraintsModalInstance` - Bootstrap Modal instance

### Allowed Mutations
- ✅ Change modal size classes (`modal-lg` → `modal-xl`)
- ✅ Change backdrop/keyboard behavior (with approval)
- ❌ **FORBIDDEN:** Remove or rename `id="material-constraints-modal"`
- ❌ **FORBIDDEN:** Change modal structure (modal-dialog → modal-content hierarchy)

---

## 📍 Region 1: Modal Header

### Selector
```css
#material-constraints-modal .modal-header
```

### Sub-selectors
- **Title:** `#constraints-modal-title`
- **Close Button:** `.btn-close` (within `.modal-header`)

### Location
- **File:** `views/products.php`
- **Lines:** 689-692

### Structure
```html
<div class="modal-header">
  <h6 class="modal-title" id="constraints-modal-title">...</h6>
  <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (static)
- **JavaScript:** No direct manipulation (Bootstrap handles close)

### Allowed Mutations
- ✅ Change title text (via translation)
- ✅ Change title tag (`h6` → `h5`)
- ✅ Add/remove icons in title
- ❌ **FORBIDDEN:** Remove `id="constraints-modal-title"`
- ❌ **FORBIDDEN:** Remove close button or change `data-bs-dismiss` attribute

---

## 📍 Region 2: Contextual Information Display

### Selector
```css
#constraints-contextual-info
```

### Sub-selectors
- **Material Name:** `#constraints-material-name-display`
- **Role Display:** `#constraints-role-display`
- **UoM Display:** `#constraints-uom-display`
- **Basis Badge:** `#constraints-basis-badge`
- **Computed Qty Preview:** `#constraints-computed-qty-preview`
- **Qty Status:** `#constraints-qty-status`

### Location
- **File:** `views/products.php`
- **Lines:** 699-723

### Structure
```html
<div class="alert alert-info mb-3" id="constraints-contextual-info">
  <div class="row g-2">
    <!-- Material, Role, UoM badges -->
  </div>
  <div class="row g-2 mt-2">
    <!-- Computed qty preview -->
  </div>
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (static structure)
- **JavaScript:** `assets/javascripts/products/product_components.js`
  - Function: `openConstraintsModal()` - updates display values (lines 1076-1080)
  - Function: `updateComputedQtyPreview()` - updates computed qty (line 1237)

### Allowed Mutations
- ✅ Change alert class (`alert-info` → `alert-primary`)
- ✅ Add/remove contextual badges
- ✅ Change layout (row/column structure)
- ❌ **FORBIDDEN:** Remove `id="constraints-contextual-info"`
- ❌ **FORBIDDEN:** Remove required sub-selectors (material-name-display, role-display, uom-display, computed-qty-preview)

---

## 📍 Region 3: Unit Locked Display

### Selector
```css
#constraints-unit-locked-display
```

### Location
- **File:** `views/products.php`
- **Lines:** 726-730

### Structure
```html
<div class="mb-3">
  <label class="form-label">Input Unit (Locked)</label>
  <input type="text" class="form-control" id="constraints-unit-locked-display" value="mm" readonly>
  <small class="text-muted">Width and length are in mm...</small>
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (static)
- **JavaScript:** No direct manipulation (read-only display)

### Allowed Mutations
- ✅ Change label text
- ✅ Change input styling
- ✅ Hide/show this region (with approval)
- ❌ **FORBIDDEN:** Remove `id="constraints-unit-locked-display"` (if region exists)

---

## 📍 Region 4: Dynamic Fields Container ⭐ **CRITICAL**

### Selector
```css
#constraints-fields-container
```

### Location
- **File:** `views/products.php`
- **Lines:** 732-740

### Structure
```html
<div id="constraints-fields-container">
  <!-- Fields dynamically rendered here by loadAndRenderConstraintFields() -->
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (container only)
- **JavaScript:** `assets/javascripts/products/product_components.js`
  - Function: `loadAndRenderConstraintFields(roleCode, existingConstraints, materialUom, basisType)` - line 1109
  - **CRITICAL:** This function completely replaces container content via `$container.html(html)`

### Dynamic Field Structure
Fields are rendered with:
- **Class:** `constraint-field` (required for validation)
- **Class:** `constraint-compute-trigger` (required for qty preview)
- **Data Attributes:**
  - `data-field-key` - Field identifier (e.g., "width_mm")
  - `data-field-type` - Field type (number, select, text, boolean, json)

### Allowed Mutations
- ✅ Change field rendering logic (within `loadAndRenderConstraintFields()`)
- ✅ Add/remove field types
- ✅ Change field styling (Bootstrap classes)
- ✅ Add validation classes (`is-invalid`, `is-valid`)
- ❌ **FORBIDDEN:** Remove `id="constraints-fields-container"`
- ❌ **FORBIDDEN:** Append elements outside this container
- ❌ **FORBIDDEN:** Remove `constraint-field` class from rendered fields
- ❌ **FORBIDDEN:** Remove `data-field-key` attribute from rendered fields

### DOM Mutation Rules
- **Allowed:** Complete replacement of container content (`$container.html(html)`)
- **Allowed:** Adding/removing fields within container
- **Forbidden:** Appending to `body` or other containers outside modal
- **Forbidden:** Creating new root-level containers

---

## 📍 Region 5: Validation Feedback

### Selector
```css
#constraints-errors
```

### Sub-selectors
- **Error List:** `#constraints-errors-list`

### Location
- **File:** `views/products.php`
- **Lines:** 742-745

### Structure
```html
<div id="constraints-errors" class="alert alert-danger" style="display: none;">
  <strong>Validation Errors</strong>
  <ul id="constraints-errors-list" class="mb-0 mt-2"></ul>
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (static structure)
- **JavaScript:** `assets/javascripts/products/product_components.js`
  - Function: `updateComputedQtyPreview()` - shows/hides errors (lines 1299-1303, 1311)
  - Function: `handleConstraintsFormSubmit()` - shows API errors (if any)

### Allowed Mutations
- ✅ Change alert class (`alert-danger` → `alert-warning`)
- ✅ Change error list structure (ul → div)
- ✅ Add/remove error display formats
- ❌ **FORBIDDEN:** Remove `id="constraints-errors"`
- ❌ **FORBIDDEN:** Remove `id="constraints-errors-list"`

---

## 📍 Region 6: Modal Footer Actions

### Selector
```css
#material-constraints-modal .modal-footer
```

### Sub-selectors
- **Save Button:** `#btn-save-constraints`
- **Cancel Button:** `.btn-outline-dark` (within `.modal-footer`)

### Location
- **File:** `views/products.php`
- **Lines:** 747-754

### Structure
```html
<div class="modal-footer">
  <button type="button" class="btn btn-outline-dark" data-bs-dismiss="modal">Cancel</button>
  <button type="submit" class="btn btn-primary" id="btn-save-constraints">Save</button>
</div>
```

### Ownership
- **HTML Template:** `views/products.php` (static structure)
- **JavaScript:** `assets/javascripts/products/product_components.js`
  - Function: `updateComputedQtyPreview()` - enables/disables save button (lines 1283, 1290, 1309)
  - Function: `handleConstraintsFormSubmit()` - handles form submission (line 1151)

### Allowed Mutations
- ✅ Change button text (via translation)
- ✅ Change button classes (`btn-primary` → `btn-success`)
- ✅ Add/remove buttons (with approval)
- ✅ Change button order
- ❌ **FORBIDDEN:** Remove `id="btn-save-constraints"`
- ❌ **FORBIDDEN:** Remove cancel button or change `data-bs-dismiss` attribute
- ❌ **FORBIDDEN:** Remove form submission handler

---

## 📍 Region 7: Form Container

### Selector
```css
#constraints-form
```

### Location
- **File:** `views/products.php`
- **Lines:** 693-755

### Structure
```html
<form id="constraints-form" class="needs-validation" novalidate>
  <!-- Contains all body regions (2-5) and footer (6) -->
</form>
```

### Ownership
- **HTML Template:** `views/products.php` (static structure)
- **JavaScript:** `assets/javascripts/products/product_components.js`
  - Function: `handleConstraintsFormSubmit()` - handles form submit event (line 1151)

### Allowed Mutations
- ✅ Change form classes
- ✅ Add/remove form attributes
- ❌ **FORBIDDEN:** Remove `id="constraints-form"`
- ❌ **FORBIDDEN:** Remove form submission handler

---

## 📍 Hidden Inputs

### Selectors
- **Material ID:** `#constraints-material-id`
- **Role Code:** `#constraints-role-code`

### Location
- **File:** `views/products.php`
- **Lines:** 695-696

### Structure
```html
<input type="hidden" id="constraints-material-id" name="material_id">
<input type="hidden" id="constraints-role-code" name="role_code">
```

### Ownership
- **HTML Template:** `views/products.php` (static)
- **JavaScript:** `assets/javascripts/products/product_components.js`
  - Function: `openConstraintsModal()` - sets values (lines 1049-1051)

### Allowed Mutations
- ✅ Change input names (if API contract allows)
- ❌ **FORBIDDEN:** Remove these hidden inputs (required for form submission)

---

## 🔒 Immutable Anchors (Must Never Change)

These selectors are **critical anchors** that must remain stable:

1. `#material-constraints-modal` - Modal root
2. `#constraints-form` - Form container
3. `#constraints-fields-container` - Dynamic fields container ⭐
4. `#btn-save-constraints` - Save button
5. `#constraints-errors` - Error container
6. `#constraints-errors-list` - Error list

**Breaking Change Rule:**
If any of these anchors must be renamed, it requires:
1. Schema version bump (v1 → v2)
2. Migration plan for existing UI code
3. Update to this layout map document

---

## 📊 Region Ownership Matrix

| Region | HTML Owner | JS Owner | Mutation Frequency |
|--------|-----------|----------|-------------------|
| Modal Root | `views/products.php` | `product_components.js` | Static |
| Header | `views/products.php` | Bootstrap | Static |
| Contextual Info | `views/products.php` | `openConstraintsModal()` | Dynamic (on open) |
| Unit Locked | `views/products.php` | None | Static |
| **Dynamic Fields** | `views/products.php` | `loadAndRenderConstraintFields()` | **High (on role change)** |
| Validation Errors | `views/products.php` | `updateComputedQtyPreview()` | Dynamic (on validation) |
| Footer Actions | `views/products.php` | `updateComputedQtyPreview()` | Dynamic (on validation) |
| Form Container | `views/products.php` | `handleConstraintsFormSubmit()` | Static |

---

## 🎯 Usage in Step 4 (UI Changes)

When making UI changes in Step 4:

1. **Reference this map** to identify target regions
2. **Respect ownership** - only modify regions you own
3. **Maintain anchors** - never remove/rename immutable anchors
4. **Document changes** - update this map if adding new regions

---

## 📚 Related Documents

- **Placement Rules:** `docs/ui/UI_PLACEMENT_RULES.md`
- **Baseline Audit:** `docs/super_dag/00-audit/CONSTRAINTS_UI_CHANGE_BASELINE.md`
- **Contract Spec:** `docs/contracts/products/constraints_contract_v1.md`

---

**Status:** ✅ **LOCKED v1.0**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team
