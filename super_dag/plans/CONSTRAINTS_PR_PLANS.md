# Constraints UI Enhancement - PR Plans

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** 📋 **PR PLANS - READY FOR IMPLEMENTATION**  
**Purpose:** Detailed PR plans for each UI enhancement item  
**Scope:** 5 PRs for Constraints Editor Modal enhancements

---

## 📋 Overview

This document provides **detailed patch plans** for each PR, following the implementation order defined in Step 5 Protocol.

**Implementation Order:**
1. PR #1: Schema Version Badge (Item A)
2. PR #2: Field Ordering (Item B)
3. PR #3: Save Button Guard (Item D)
4. PR #4: Unit Locked Display (Item E)
5. PR #5: Validation UX (Item C)

---

## 🔧 PR #1: Schema Version Badge (Item A)

### Files to Modify

1. **`views/products.php`**
   - Location: Within `#constraints-contextual-info` region
   - Line: After line 722 (after computed qty preview row)

2. **`assets/javascripts/products/product_components.js`**
   - Location: In `openConstraintsModal()` function
   - Line: After line ~1080 (after updating contextual badges)

### Changes

#### 1. HTML Template (`views/products.php`)

**Add after computed qty preview row:**
```html
<!-- Schema version badge (Item A) -->
<div class="row g-2 mt-2" id="constraints-schema-version-row" style="display: none;">
  <div class="col-md-12 text-end">
    <small class="text-muted">
      <span data-i18n="product.component.material.constraints.schema_version">Schema:</span>
      <span id="constraints-schema-version-badge" class="badge bg-secondary ms-1">v1</span>
    </small>
  </div>
</div>
```

**Note:** Initially hidden (`display: none`), shown via JavaScript when feature flag enabled.

#### 2. JavaScript (`product_components.js`)

**In `openConstraintsModal()` function, after updating contextual badges:**

```javascript
// Item A: Schema Version Badge
if (window.__FEATURE_FLAGS__?.constraints_ui_schema_badge || 
    (window.FeatureFlags && window.FeatureFlags.isEnabled('constraints_ui_schema_badge', false))) {
  
  // Load schema version from list_role_fields API
  try {
    const fieldsResp = await $.ajax({
      url: PRODUCT_API,
      method: 'POST',
      data: { action: 'list_role_fields', role_code: roleCode }
    });
    
    if (fieldsResp.ok && fieldsResp.meta?.schema_version) {
      const schemaVersion = fieldsResp.meta.schema_version;
      // Extract version number: "products.constraints.v1" -> "v1"
      const versionMatch = schemaVersion.match(/v(\d+)$/);
      const versionNumber = versionMatch ? versionMatch[1] : '?';
      
      $('#constraints-schema-version-badge').text('v' + versionNumber);
      $('#constraints-schema-version-row').show();
    } else {
      $('#constraints-schema-version-row').hide();
    }
  } catch (err) {
    console.warn('[ProductComponents] Failed to load schema version:', err);
    $('#constraints-schema-version-row').hide();
  }
} else {
  $('#constraints-schema-version-row').hide();
}
```

### Testing Checklist

- [ ] Badge shows "v1" when API returns `meta.schema_version = "products.constraints.v1"`
- [ ] Badge hidden when feature flag disabled
- [ ] Badge hidden when API doesn't return schema_version
- [ ] Badge positioned correctly (right-aligned in contextual info)

### Risk Assessment

**Risk Level:** Low  
**Impact:** Cosmetic only, read-only display  
**Breaking Changes:** None

---

## 🔧 PR #2: Field Ordering + Unknown Type (Item B)

### Files to Modify

1. **`assets/javascripts/products/product_components.js`**
   - Location: `loadAndRenderConstraintFields()` function
   - Line: ~1109-1232

### Changes

#### JavaScript (`product_components.js`)

**In `loadAndRenderConstraintFields()` function, after receiving API response:**

```javascript
// Item B: Field Ordering + Unknown Type Handling
if (!resp.ok || !resp.fields) {
  console.error('[ProductComponents] API response invalid:', resp);
  $container.html('<div class="alert alert-warning">Failed to load fields: Invalid API response</div>');
  return;
}

// Defensive sort by display_order (Item B)
const sortedFields = [...resp.fields].sort((a, b) => {
  const orderA = a.display_order ?? 999;
  const orderB = b.display_order ?? 999;
  return orderA - orderB;
});

// Known field types
const KNOWN_FIELD_TYPES = ['number', 'select', 'text', 'boolean', 'json'];

// Render fields
let html = '';
sortedFields.forEach(field => {
  const value = constraints[field.field_key] ?? '';
  const required = field.required ? ' <span class="text-danger">*</span>' : '';
  
  // Item B: Handle unknown field types
  const fieldType = field.field_type || 'text';
  const isKnownType = KNOWN_FIELD_TYPES.includes(fieldType);
  
  if (!isKnownType) {
    console.warn('[ProductComponents] Unknown field_type:', fieldType, 'for field:', field.field_key);
    // Render as text input (safe fallback)
  }
  
  html += '<div class="mb-3">';
  html += `<label class="form-label">${escapeHtml(field.field_label_en || field.field_key)}${required}</label>`;
  
  // Render based on type (with fallback for unknown types)
  if (!isKnownType || fieldType === 'text') {
    // Unknown type or text: render as text input
    html += `<input type="text" class="form-control constraint-field constraint-compute-trigger" data-field-key="${escapeHtml(field.field_key)}" data-field-type="text" value="${escapeHtml(value)}" ${field.required ? 'required' : ''}>`;
  } else {
    // Known types: use existing switch logic
    switch (fieldType) {
      case 'number':
        // ... existing number rendering ...
        break;
      case 'select':
        // ... existing select rendering ...
        break;
      // ... other known types ...
    }
  }
  
  html += '</div>';
});
```

### Testing Checklist

- [ ] Fields render in `display_order` sequence
- [ ] Unknown field type renders as text input (no breakage)
- [ ] Console warning logged for unknown types (dev-only)
- [ ] Known field types render correctly (no regression)

### Risk Assessment

**Risk Level:** Low  
**Impact:** Forward compatibility, predictable ordering  
**Breaking Changes:** None (defensive coding)

---

## 🔧 PR #3: Save Button Guard (Item D)

### Files to Modify

1. **`assets/javascripts/products/product_components.js`**
   - Location: `handleConstraintsFormSubmit()` and `updateComputedQtyPreview()` functions
   - Lines: ~1151 (form submit), ~1237 (qty preview)

### Changes

#### JavaScript (`product_components.js`)

**1. Add submission guard flag at top of file:**
```javascript
let isConstraintsSubmitting = false; // Item D: Prevent double-submit
```

**2. In `handleConstraintsFormSubmit()` function:**

```javascript
// Item D: Save Button Guard
async function handleConstraintsFormSubmit(e) {
  e.preventDefault();
  
  // Prevent double-submit
  if (isConstraintsSubmitting) {
    console.warn('[ProductComponents] Form submission already in progress');
    return;
  }
  
  const $saveBtn = $('#btn-save-constraints');
  const $btnText = $saveBtn.find('span:last');
  const originalText = $btnText.text();
  
  // Disable button and show loading state
  isConstraintsSubmitting = true;
  $saveBtn.prop('disabled', true);
  $btnText.text(t('common.saving', 'Saving...'));
  
  try {
    // ... existing form submission logic ...
    
    // On success/error, re-enable button
    $saveBtn.prop('disabled', false);
    $btnText.text(originalText);
    isConstraintsSubmitting = false;
  } catch (err) {
    // On error, re-enable button
    $saveBtn.prop('disabled', false);
    $btnText.text(originalText);
    isConstraintsSubmitting = false;
    throw err;
  }
}
```

**3. In `updateComputedQtyPreview()` function, enhance disable logic:**

```javascript
// Item D: Enhanced disable conditions
const $saveBtn = $('#btn-save-constraints');

// Check for local validation errors (type mismatches, etc.)
const hasLocalValidationErrors = () => {
  let hasErrors = false;
  $('.constraint-field').each(function() {
    const $field = $(this);
    const fieldType = $field.data('field-type');
    const value = $field.val();
    
    if (fieldType === 'number' && value && isNaN(parseFloat(value))) {
      hasErrors = true;
      return false; // break
    }
    // Add more validation checks as needed
  });
  return hasErrors;
};

if (!isComplete || hasLocalValidationErrors() || isConstraintsSubmitting) {
  $saveBtn.prop('disabled', true).addClass('disabled');
} else {
  $saveBtn.prop('disabled', false).removeClass('disabled');
}
```

### Testing Checklist

- [ ] Button disabled when required fields incomplete
- [ ] Button disabled when local validation errors exist
- [ ] Button disabled during API call (loading state)
- [ ] Button shows "Saving..." text during submission
- [ ] Double-click prevented (no duplicate submissions)
- [ ] Button re-enabled after success/error

### Risk Assessment

**Risk Level:** Low  
**Impact:** Prevents invalid submissions, better UX  
**Breaking Changes:** None (enhancement only)

---

## 🔧 PR #4: Unit Locked Display (Item E)

### Files to Modify

1. **`views/products.php`**
   - Location: Unit locked display section
   - Line: ~726-730

### Changes

#### HTML Template (`views/products.php`)

**Replace existing unit locked display:**

```html
<!-- Phase F: Unit locked display (read-only) - Enhanced (Item E) -->
<div class="mb-3">
  <label class="form-label">
    <span data-i18n="product.component.material.constraints.unit_locked"><?php echo translate('product.component.material.constraints.unit_locked', 'Input Unit (Locked)'); ?></span>
    <i class="fe fe-lock ms-1 text-muted" title="<?php echo translate('product.component.material.constraints.unit_locked_tooltip', 'Unit cannot be changed'); ?>"></i>
  </label>
  <div class="input-group">
    <input type="text" class="form-control" id="constraints-unit-locked-display" value="mm" readonly>
    <span class="input-group-text">
      <span class="badge bg-secondary"><?php echo translate('common.locked', 'Locked'); ?></span>
    </span>
  </div>
  <small class="text-muted" data-i18n="product.component.material.constraints.unit_locked_note">
    <?php echo translate('product.component.material.constraints.unit_locked_note', 'Width, length, and thickness are always in mm. This cannot be changed.'); ?>
  </small>
</div>
```

**Note:** Feature flag check can be done in JavaScript if needed, but this is mostly cosmetic.

### Testing Checklist

- [ ] Lock icon visible
- [ ] "Locked" badge visible
- [ ] Help text clear and helpful
- [ ] Input is read-only (cannot be edited)
- [ ] Styling consistent with Bootstrap 5

### Risk Assessment

**Risk Level:** Low  
**Impact:** Visual clarity only  
**Breaking Changes:** None

---

## 🔧 PR #5: Validation UX (Item C)

### Files to Modify

1. **`assets/javascripts/products/product_components.js`**
   - Location: `updateComputedQtyPreview()` and error handling
   - Lines: ~1237 (qty preview), error display logic

### Changes

#### JavaScript (`product_components.js`)

**1. Enhanced error list with click handlers:**

```javascript
// Item C: Enhanced Validation UX
function updateComputedQtyPreview(materialUom, basisType) {
  // ... existing validation logic ...
  
  if (!isComplete) {
    // ... existing error display ...
    
    // Item C: Enhanced error list with click handlers
    const $errorList = $('#constraints-errors-list');
    $errorList.empty();
    
    missingFields.forEach(fieldKey => {
      const $field = $(`.constraint-field[data-field-key="${fieldKey}"]`);
      const $fieldContainer = $field.closest('.mb-3');
      const fieldLabel = $fieldContainer.find('label').text().replace(/\s*\*$/, '') || fieldKey;
      
      // Create clickable error item
      const $errorItem = $('<li>')
        .css('cursor', 'pointer')
        .text(`${fieldLabel}: ${t('product.component.material.constraints.field_required', 'Required field missing')}`)
        .on('click', function() {
          // Scroll to field
          const fieldElement = $field[0];
          if (fieldElement) {
            fieldElement.scrollIntoView({ 
              behavior: 'smooth', 
              block: 'center' 
            });
            // Focus field after scroll
            setTimeout(() => {
              $field.focus();
            }, 300);
          }
        });
      
      $errorList.append($errorItem);
      
      // Item C: Add inline error message below field
      $fieldContainer.find('.invalid-feedback').remove(); // Remove existing
      $fieldContainer.append(
        `<div class="invalid-feedback">${t('product.component.material.constraints.field_required', 'This field is required')}</div>`
      );
    });
    
    // Show error container
    $('#constraints-errors').show();
    
    return;
  }
  
  // Clear errors when complete
  $('#constraints-errors').hide();
  $('.invalid-feedback').remove();
  $('.constraint-field').removeClass('is-invalid');
}
```

**2. Handle server-side errors (from API response):**

```javascript
// In handleConstraintsFormSubmit() error handling
if (!response.ok && response.invalid_fields) {
  // Item C: Display server errors with click handlers
  const $errorList = $('#constraints-errors-list');
  $errorList.empty();
  
  Object.keys(response.invalid_fields).forEach(fieldKey => {
    const errorMessage = response.invalid_fields[fieldKey];
    const $field = $(`.constraint-field[data-field-key="${fieldKey}"]`);
    const $fieldContainer = $field.closest('.mb-3');
    
    // Add to error list (clickable)
    const $errorItem = $('<li>')
      .css('cursor', 'pointer')
      .text(`${fieldKey}: ${errorMessage}`)
      .on('click', function() {
        $field[0]?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        setTimeout(() => $field.focus(), 300);
      });
    $errorList.append($errorItem);
    
    // Add inline error message
    $fieldContainer.find('.invalid-feedback').remove();
    $fieldContainer.append(`<div class="invalid-feedback">${errorMessage}</div>`);
    $field.addClass('is-invalid');
  });
  
  $('#constraints-errors').show();
}
```

### Testing Checklist

- [ ] Error list items are clickable
- [ ] Clicking error scrolls to field (smooth scroll)
- [ ] Field receives focus after scroll
- [ ] Inline error messages appear below fields
- [ ] Server errors (`invalid_fields`) display correctly
- [ ] Client errors (required fields) display correctly
- [ ] Errors clear when fields are corrected
- [ ] Works in Chrome, Firefox, Safari, Edge

### Risk Assessment

**Risk Level:** Medium  
**Impact:** Complex interaction, multiple DOM manipulations  
**Breaking Changes:** None (enhancement only)

**Edge Cases to Test:**
- Rapid clicking on error items
- Fields outside viewport (scroll behavior)
- Multiple errors at once
- Browser compatibility (scrollIntoView support)

---

## 📊 PR Summary

| PR | Item | Files | Risk | Time | Feature Flag |
|----|------|-------|------|------|--------------|
| #1 | A: Schema Badge | 2 files | Low | 30 min | `constraints_ui_schema_badge` |
| #2 | B: Field Ordering | 1 file | Low | 1 hour | `constraints_ui_field_ordering` |
| #3 | D: Save Guard | 1 file | Low | 1 hour | `constraints_ui_save_guard` |
| #4 | E: Unit Display | 1 file | Low | 30 min | `constraints_ui_unit_display` |
| #5 | C: Validation UX | 1 file | Medium | 2-3 hours | `constraints_ui_validation_ux` |

**Total:** 5 PRs, ~5-6 hours implementation time

---

## ✅ PR Checklist Template

Copy this checklist for each PR:

### Pre-Implementation
- [ ] Read Step 4 Plan document
- [ ] Read Step 5 Protocol document
- [ ] Read Layout Map and Placement Rules
- [ ] Confirm feature flag system available

### Implementation
- [ ] Follow PR plan exactly
- [ ] Only modify specified files/lines
- [ ] Respect immutable anchors
- [ ] Add feature flag check (if using)

### Testing
- [ ] Run: `vendor/bin/phpunit --testsuite Contract`
- [ ] Run: `vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php`
- [ ] Manual testing in browser
- [ ] Test with feature flag enabled/disabled
- [ ] Screenshot/video attached to PR

### Code Quality
- [ ] No inline styles (except dynamic `display`)
- [ ] No unscoped global CSS
- [ ] Uses Bootstrap 5 utilities
- [ ] Code comments added for complex logic

### Documentation
- [ ] PR description references Step 4 plan
- [ ] PR description references Step 5 protocol
- [ ] Changes documented in PR description

---

## 📚 Related Documents

- **Implementation Protocol:** `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md`
- **UI Change Plan:** `docs/super_dag/plans/CONSTRAINTS_UI_CHANGE_PLAN_STEP4.md`
- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`
- **Placement Rules:** `docs/ui/UI_PLACEMENT_RULES.md`

---

**Status:** 📋 **PR PLANS READY - AWAITING IMPLEMENTATION**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team
