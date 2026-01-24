# UI Placement Rules - Constraints Editor Modal

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** ✅ **LOCKED - Rulebook**  
**Purpose:** Define placement rules for UI changes in Constraints Editor Modal  
**Scope:** Material Constraints Editor (`#material-constraints-modal`)

---

## 📋 Overview

This document defines **deterministic rules** for placing UI elements in the Constraints Editor Modal. These rules enable **PR review automation** and prevent UI drift.

**Core Principle:**
> "Every UI change must be verifiable" — Rules must be specific enough to pass/fail PR checks automatically.

---

## 🎯 Placement Matrix

### Rule 1: New Control Placement by Type

| Control Type | Allowed Region | Forbidden Regions | Notes |
|-------------|---------------|------------------|-------|
| **Form Field** (input, select, textarea) | `#constraints-fields-container` only | All other regions | Must have `constraint-field` class |
| **Validation Message** | `#constraints-errors-list` (within `#constraints-errors`) | Inline in fields | Use error list, not inline |
| **Contextual Badge** | `#constraints-contextual-info` | All other regions | Material/Role/UoM info only |
| **Action Button** | `.modal-footer` | All other regions | Save/Cancel only |
| **Help Text** | Within field container (in `#constraints-fields-container`) | Outside fields container | Use `<small class="text-muted">` |
| **Loading Indicator** | `#constraints-fields-container` (temporary) | All other regions | Only during field load |

### Rule 2: Dynamic Field Ordering

**Requirement:** Fields must be ordered by `display_order` from API response.

**Implementation:**
- API: `list_role_fields` returns fields sorted by `display_order ASC`
- JavaScript: `loadAndRenderConstraintFields()` renders fields in API order
- **Rule:** Do NOT reorder fields manually — use `display_order` from API

**Violation Example:**
```javascript
// ❌ WRONG: Manual reordering
resp.fields.sort((a, b) => a.field_key.localeCompare(b.field_key)); // FORBIDDEN

// ✅ CORRECT: Use API order
resp.fields.forEach(field => { /* render in order */ });
```

### Rule 3: Responsive Behavior

**Modal Size:**
- Current: `modal-lg` (Bootstrap 5)
- **Rule:** Modal width/scroll behavior must not change without:
  1. Explicit approval token
  2. Responsive design justification
  3. Update to `UI_LAYOUT_MAP.md`

**Allowed Changes:**
- ✅ Change `modal-lg` → `modal-xl` (with approval)
- ✅ Change `modal-dialog-scrollable` behavior (with approval)
- ❌ **FORBIDDEN:** Remove `modal-dialog-centered` without justification
- ❌ **FORBIDDEN:** Change `data-bs-backdrop="static"` without approval

---

## 🔒 DOM Mutation Rules

### Rule 4: Container Hierarchy

**Allowed DOM Mutations:**

1. **Within `#constraints-fields-container`:**
   - ✅ Complete replacement: `$container.html(html)`
   - ✅ Append fields: `$container.append(fieldHtml)`
   - ✅ Remove fields: `$container.find('.field-to-remove').remove()`
   - ✅ Update field values: `$container.find('[data-field-key="..."]').val(newValue)`

2. **Within `#constraints-errors-list`:**
   - ✅ Append error items: `$errorList.append('<li>Error message</li>')`
   - ✅ Clear errors: `$errorList.empty()`

3. **Within `#constraints-contextual-info`:**
   - ✅ Update display values: `$('#constraints-material-name-display').text(name)`
   - ✅ Update badges: `$('#constraints-uom-display').text(uom)`

**Forbidden DOM Mutations:**

1. **Appending to `body` directly:**
   ```javascript
   // ❌ FORBIDDEN
   $('body').append('<div id="new-container">...</div>');
   ```

2. **Creating new root-level containers:**
   ```javascript
   // ❌ FORBIDDEN
   $('#material-constraints-modal').after('<div id="new-modal">...</div>');
   ```

3. **Removing immutable anchors:**
   ```javascript
   // ❌ FORBIDDEN
   $('#constraints-fields-container').remove();
   $('#btn-save-constraints').remove();
   ```

4. **Moving regions outside modal:**
   ```javascript
   // ❌ FORBIDDEN
   $('#constraints-fields-container').appendTo('body');
   ```

### Rule 5: Dynamic Element Requirements

**All dynamically rendered fields MUST have:**

1. **Required Classes:**
   - `constraint-field` - For validation and field identification
   - `constraint-compute-trigger` - For qty preview computation (if applicable)

2. **Required Data Attributes:**
   - `data-field-key` - Field identifier (e.g., "width_mm", "length_mm")
   - `data-field-type` - Field type ("number", "select", "text", "boolean", "json")

3. **Required Structure:**
   ```html
   <div class="mb-3">
     <label class="form-label">Field Label <span class="text-danger">*</span></label>
     <input type="number" 
            class="form-control constraint-field constraint-compute-trigger"
            data-field-key="width_mm"
            data-field-type="number"
            required>
     <small class="text-muted">Unit (mm)</small>
   </div>
   ```

**Violation Example:**
```html
<!-- ❌ WRONG: Missing required classes/attributes -->
<input type="number" class="form-control" name="width">

<!-- ✅ CORRECT: Has all required classes/attributes -->
<input type="number" 
       class="form-control constraint-field constraint-compute-trigger"
       data-field-key="width_mm"
       data-field-type="number">
```

---

## 🎨 Styling Rules

### Rule 6: No Inline Styles

**Forbidden:**
```html
<!-- ❌ FORBIDDEN -->
<div style="color: red; margin: 10px;">Content</div>
```

**Allowed:**
```html
<!-- ✅ CORRECT: Use Bootstrap classes -->
<div class="text-danger mb-3">Content</div>
```

**Exception:** Only allowed for dynamic display control:
```html
<!-- ✅ ALLOWED: Dynamic visibility -->
<div id="constraints-errors" style="display: none;">...</div>
```

### Rule 7: No Unscoped Global CSS

**Forbidden:**
```css
/* ❌ FORBIDDEN: Global selector without namespace */
.btn { color: red; }
.form-control { border: 2px solid blue; }
```

**Allowed:**
```css
/* ✅ CORRECT: Scoped to modal */
#material-constraints-modal .custom-button { color: red; }
#constraints-fields-container .custom-field { border: 1px solid gray; }
```

**Token/Namespace Pattern:**
- Use modal ID as namespace: `#material-constraints-modal .custom-class`
- Use region ID as namespace: `#constraints-fields-container .custom-class`
- Use utility classes from Bootstrap 5

### Rule 8: Use Existing Tokens/Utilities

**Preferred Order:**
1. **Bootstrap 5 utility classes** (first choice)
   - `mb-3`, `mt-2`, `text-danger`, `bg-primary`, etc.
2. **Existing custom classes** (if available)
   - Check `assets/stylesheets/` for existing classes
3. **Scoped custom classes** (last resort)
   - Must be scoped: `#material-constraints-modal .custom-class`
   - Must be documented in this file

**Example:**
```html
<!-- ✅ CORRECT: Bootstrap utilities -->
<div class="alert alert-danger mb-3">
  <span class="text-danger fw-bold">Error</span>
</div>

<!-- ❌ WRONG: Custom inline style -->
<div style="background: red; padding: 10px;">
  <span style="color: white; font-weight: bold;">Error</span>
</div>
```

---

## 📋 Contract-to-UI Rules

### Rule 9: No Dependency on `_debug`

**Forbidden:**
```javascript
// ❌ FORBIDDEN: UI must not depend on _debug
if (response._debug && response._debug.db_name) {
  console.log('DB:', response._debug.db_name);
}
```

**Reason:** `_debug` is DEV-ONLY and non-contract. UI code must work in production.

**Allowed:**
```javascript
// ✅ CORRECT: Use contract fields only
if (response.ok && response.fields) {
  renderFields(response.fields);
}
```

### Rule 10: Forward-Compatible Field Handling

**Requirement:** UI must treat unknown fields as optional.

**Implementation:**
```javascript
// ✅ CORRECT: Handle unknown fields gracefully
resp.fields.forEach(field => {
  // Render all fields, even if field_type is unknown
  if (['number', 'select', 'text', 'boolean'].includes(field.field_type)) {
    renderField(field);
  } else {
    // Unknown type: render as text input (forward compatible)
    renderFieldAsText(field);
  }
});
```

**Violation:**
```javascript
// ❌ WRONG: Breaks on unknown field types
resp.fields.forEach(field => {
  switch (field.field_type) {
    case 'number': renderNumber(field); break;
    case 'select': renderSelect(field); break;
    // Missing default case - breaks on new field types
  }
});
```

### Rule 11: Schema Version Awareness

**Requirement:** UI must handle schema version changes gracefully.

**Current:** `meta.schema_version = "products.constraints.v1"`

**Rule:**
- UI may check schema version for compatibility
- UI must not break if schema version is missing (backward compatible)
- UI must not break on future schema versions (forward compatible)

**Example:**
```javascript
// ✅ CORRECT: Graceful version handling
const schemaVersion = response.meta?.schema_version;
if (schemaVersion && schemaVersion.startsWith('products.constraints.v2')) {
  // Handle v2-specific features
} else {
  // Default to v1 behavior (backward compatible)
}
```

---

## ✅ PR Review Checklist

Use this checklist to verify PR compliance:

### Placement Checks
- [ ] New form fields are in `#constraints-fields-container` only
- [ ] New buttons are in `.modal-footer` only
- [ ] New validation messages are in `#constraints-errors-list` only
- [ ] Fields are ordered by `display_order` from API (not manually sorted)

### DOM Mutation Checks
- [ ] No elements appended to `body` directly
- [ ] No new root-level containers created
- [ ] Immutable anchors not removed/renamed
- [ ] Dynamic fields have required classes (`constraint-field`, `constraint-compute-trigger`)
- [ ] Dynamic fields have required data attributes (`data-field-key`, `data-field-type`)

### Styling Checks
- [ ] No inline styles (except dynamic `display: none/block`)
- [ ] No unscoped global CSS selectors
- [ ] Uses Bootstrap 5 utility classes where possible
- [ ] Custom classes are scoped to modal/region

### Contract Checks
- [ ] No dependency on `_debug` field
- [ ] Unknown fields handled gracefully (forward compatible)
- [ ] Schema version changes handled gracefully

---

## 🚨 Violation Examples

### Example 1: Wrong Region Placement
```javascript
// ❌ VIOLATION: Field outside allowed region
$('#constraints-contextual-info').append('<input type="number" class="form-control">');

// ✅ CORRECT: Field in correct region
$('#constraints-fields-container').append('<input type="number" class="form-control constraint-field" data-field-key="width_mm" data-field-type="number">');
```

### Example 2: Missing Required Attributes
```html
<!-- ❌ VIOLATION: Missing constraint-field class and data attributes -->
<input type="number" class="form-control" name="width">

<!-- ✅ CORRECT: Has all required classes/attributes -->
<input type="number" 
       class="form-control constraint-field constraint-compute-trigger"
       data-field-key="width_mm"
       data-field-type="number">
```

### Example 3: Inline Styles
```html
<!-- ❌ VIOLATION: Inline styles -->
<div style="color: red; margin: 10px;">Error</div>

<!-- ✅ CORRECT: Bootstrap utilities -->
<div class="text-danger mb-3">Error</div>
```

---

## 📚 Related Documents

- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`
- **Contract Spec:** `docs/contracts/products/constraints_contract_v1.md`
- **Baseline Audit:** `docs/super_dag/00-audit/CONSTRAINTS_UI_CHANGE_BASELINE.md`

---

**Status:** ✅ **LOCKED v1.0**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team
