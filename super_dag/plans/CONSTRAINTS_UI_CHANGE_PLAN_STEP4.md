# Constraints UI Change Plan - Step 4

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** 📋 **PLAN ONLY - NOT IMPLEMENTED**  
**Purpose:** Define UI changes for Constraints Editor Modal with minimal-diff approach  
**Scope:** Material Constraints Editor (`#material-constraints-modal`)

---

## 📋 Overview

This document defines the **UI change plan** for the Constraints Editor Modal. This is a **planning document only** — no UI code will be implemented in Step 4.

**Core Principle:**
> "Minimal-diff, deterministic placement, zero drift" — All changes must respect Layout Map regions and immutable anchors.

---

## 🎯 Goals (What & Why)

### Primary Goals

1. **Reduce Cognitive Load**
   - Faster constraint input/editing
   - Clear visual hierarchy
   - Reduced decision fatigue

2. **Reduce Error Rate**
   - Actionable validation feedback
   - Field-level error highlighting
   - Clear error messages

3. **Maintain Deterministic Placement**
   - Follow Layout Map regions
   - Respect immutable anchors
   - Prevent UI drift

4. **No Backend Coupling**
   - Use Contract v1 only
   - Use schema_version v1
   - No dependency on `_debug`

---

## 🔒 Allowed UI Surface

### Regions That Can Be Modified

Changes are **allowed only within** these mapped regions:

1. **Contextual Information** (`#constraints-contextual-info`)
2. **Unit Locked Display** (`#constraints-unit-locked-display`)
3. **Dynamic Fields Container** (`#constraints-fields-container`) ⭐
4. **Validation Feedback** (`#constraints-errors`, `#constraints-errors-list`)
5. **Modal Footer Actions** (`#btn-save-constraints` - behavior only, not structure)

### Immutable Anchors (FORBIDDEN to Change)

These selectors **must never be removed or renamed**:

- `#material-constraints-modal` - Modal root
- `#constraints-form` - Form container
- `#constraints-fields-container` - Dynamic fields container ⭐
- `#btn-save-constraints` - Save button
- `#constraints-errors` - Error container
- `#constraints-errors-list` - Error list

**Breaking Change Rule:**
If any anchor must be renamed, it requires:
1. Schema version bump (v1 → v2)
2. Migration plan
3. Update to Layout Map

---

## 📝 UI Changes Plan

### Change A: Schema Version Badge (Read-only)

**Region:** Contextual Information (`#constraints-contextual-info`)

**Placement:**
- Location: End of contextual info section, right-aligned
- Container: Within `#constraints-contextual-info` div
- Position: After computed qty preview row

**Implementation:**
```html
<!-- Add to #constraints-contextual-info, after computed qty row -->
<div class="row g-2 mt-2">
  <div class="col-md-12 text-end">
    <small class="text-muted">
      <span data-i18n="product.component.material.constraints.schema_version">Schema:</span>
      <span id="constraints-schema-version-badge" class="badge bg-secondary ms-1">v1</span>
    </small>
  </div>
</div>
```

**Data Source:**
- From API response: `response.meta.schema_version`
- Format: `"products.constraints.v1"` → Display as `"v1"`
- **Rule:** Must NOT depend on `_debug` field

**JavaScript:**
```javascript
// In openConstraintsModal() or after API response
const schemaVersion = response.meta?.schema_version || 'unknown';
const versionNumber = schemaVersion.match(/v(\d+)$/)?.[1] || '?';
$('#constraints-schema-version-badge').text('v' + versionNumber);
```

**Value:**
- Support/dev can see UI consumes v1
- Reduces bug hunting time
- Prevents version mismatch issues

**Anchors Touched:**
- ✅ `#constraints-contextual-info` (allowed - within region)
- ❌ No immutable anchors touched

---

### Change B: Dynamic Fields Rendering (Predictable Order)

**Region:** Dynamic Fields Container (`#constraints-fields-container`)

**Current State:**
- Fields rendered by `loadAndRenderConstraintFields()`
- Order: From API response (should be `display_order ASC`)

**Change:**
1. **Explicit Ordering:**
   - Ensure fields are sorted by `display_order` before rendering
   - Add validation that API returns sorted fields

2. **Unknown Field Type Handling:**
   - If `field_type` is unknown → render as text input (safe fallback)
   - Show warning in console (dev-only)
   - Do NOT break UI or hide field

**Implementation:**
```javascript
// In loadAndRenderConstraintFields()
// 1. Sort by display_order (defensive)
resp.fields.sort((a, b) => (a.display_order || 0) - (b.display_order || 0));

// 2. Handle unknown field types
resp.fields.forEach(field => {
  const knownTypes = ['number', 'select', 'text', 'boolean', 'json'];
  if (!knownTypes.includes(field.field_type)) {
    console.warn('[ProductComponents] Unknown field_type:', field.field_type, 'for field:', field.field_key);
    // Render as text input (forward compatible)
    renderFieldAsText(field);
  } else {
    renderFieldByType(field);
  }
});
```

**Value:**
- Forward compatibility (new field types don't break UI)
- Predictable field order
- Reduced layout drift

**Anchors Touched:**
- ✅ `#constraints-fields-container` (allowed - content only, not structure)
- ❌ No immutable anchors touched

---

### Change C: Validation Feedback UX (Field-scoped + Summary)

**Region:** Validation Feedback (`#constraints-errors`, `#constraints-errors-list`)

**Current State:**
- Errors shown in `#constraints-errors-list` as list
- Fields highlighted with `is-invalid` class

**Changes:**

1. **Enhanced Summary List:**
   - Keep existing `#constraints-errors-list` structure
   - Make error items clickable (scroll to field)
   - Add field key to error message

2. **Field-level Inline Messages:**
   - Add error message below each invalid field
   - Must be within `#constraints-fields-container` (under field's parent div)
   - Use Bootstrap `invalid-feedback` class

3. **Click-to-Focus:**
   - When clicking error in list → scroll/focus to field
   - Use `scrollIntoView()` or jQuery `scrollTop()`

**Implementation:**
```javascript
// 1. Enhanced error list (in updateComputedQtyPreview or validation handler)
missingFields.forEach(fieldKey => {
  const $field = $(`.constraint-field[data-field-key="${fieldKey}"]`);
  const fieldLabel = $field.closest('.mb-3').find('label').text() || fieldKey;
  
  // Add to error list with click handler
  const $errorItem = $('<li>')
    .text(`${fieldLabel}: Required field missing`)
    .css('cursor', 'pointer')
    .on('click', () => {
      $field[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
      $field.focus();
    });
  $errorList.append($errorItem);
  
  // Add inline error message (within field container)
  $field.closest('.mb-3').append(
    '<div class="invalid-feedback">This field is required</div>'
  );
});
```

**Data Sources:**
- Server: `response.invalid_fields` (from API error response)
- Client: Local validation (required fields, type checks)

**Value:**
- Reduces "trial and error" behavior
- Faster error correction
- Clear actionable feedback

**Anchors Touched:**
- ✅ `#constraints-errors-list` (allowed - content only)
- ✅ `#constraints-fields-container` (allowed - add inline messages within fields)
- ❌ No immutable anchors removed/renamed

---

### Change D: Save Button Behavior (Guardrail)

**Region:** Footer Actions (`#btn-save-constraints`)

**Current State:**
- Button disabled when constraints incomplete (in `updateComputedQtyPreview()`)

**Changes:**

1. **Enhanced Disable Conditions:**
   - Required fields incomplete (existing)
   - Local validation errors (type mismatches, out-of-range)
   - API request in progress (prevent double-submit)

2. **Loading State:**
   - Show spinner/loading text during API call
   - Disable button during request
   - Do NOT change button position/structure

**Implementation:**
```javascript
// In handleConstraintsFormSubmit()
$('#btn-save-constraints').prop('disabled', true);
const $btnText = $('#btn-save-constraints span:last');
const originalText = $btnText.text();
$btnText.text(t('common.saving', 'Saving...'));

try {
  const response = await $.ajax({ /* ... */ });
  // Handle success/error
} finally {
  $('#btn-save-constraints').prop('disabled', false);
  $btnText.text(originalText);
}

// In updateComputedQtyPreview() - enhanced disable logic
if (!isComplete || hasLocalValidationErrors()) {
  $saveBtn.prop('disabled', true).addClass('disabled');
} else {
  $saveBtn.prop('disabled', false).removeClass('disabled');
}
```

**Value:**
- Reduces request noise (no invalid submissions)
- Prevents race conditions
- Better user feedback

**Anchors Touched:**
- ✅ `#btn-save-constraints` (allowed - behavior only, not structure)
- ❌ No immutable anchors removed/renamed

---

### Change E: Unit Locked Display (Consistency)

**Region:** Unit Locked Display (`#constraints-unit-locked-display`)

**Current State:**
- Read-only input showing "mm"
- Help text explaining unit lock

**Changes:**

1. **Clearer Visual Indication:**
   - Add icon/indicator that unit is locked
   - Show "Locked" badge or icon
   - Consistent null/empty handling (show "—" if unit is null)

2. **Enhanced Help Text:**
   - Clarify which fields use which units
   - Show unit mapping (width/length = mm, etc.)

**Implementation:**
```html
<!-- Enhanced unit locked display -->
<div class="mb-3">
  <label class="form-label">
    Input Unit (Locked)
    <i class="fe fe-lock ms-1 text-muted" title="Unit cannot be changed"></i>
  </label>
  <div class="input-group">
    <input type="text" class="form-control" id="constraints-unit-locked-display" value="mm" readonly>
    <span class="input-group-text">
      <span class="badge bg-secondary">Locked</span>
    </span>
  </div>
  <small class="text-muted">
    Width, length, and thickness are always in mm. This cannot be changed.
  </small>
</div>
```

**Value:**
- Reduces unit confusion
- Prevents wrong unit input
- Clearer constraints understanding

**Anchors Touched:**
- ✅ `#constraints-unit-locked-display` (allowed - styling/content only)
- ❌ No immutable anchors removed/renamed

---

## 🔒 API/Contract Compatibility

### Must Keep (v1 Contract)

**Data Sources (Allowed):**
- `response.ok` - Success/failure
- `response.meta.schema_version` - Schema version
- `response.fields[]` - Field definitions (from `list_role_fields`)
- `response.roles[]` - Role definitions (from `list_material_roles`)
- `response.invalid_fields` - Validation errors (from error responses)

**Forbidden Dependencies:**
- ❌ `response._debug` - DEV-ONLY, non-contract
- ❌ Any fields not in Contract v1 spec

### Schema Version Guard

**Requirement:** Check schema version before rendering.

**Implementation:**
```javascript
// In openConstraintsModal() or after API response
const schemaVersion = response.meta?.schema_version;
if (!schemaVersion || !schemaVersion.startsWith('products.constraints.v1')) {
  // Show warning in contextual info
  $('#constraints-contextual-info').prepend(
    '<div class="alert alert-warning">⚠️ Schema version mismatch. UI may not work correctly.</div>'
  );
  // Block save
  $('#btn-save-constraints').prop('disabled', true);
} else {
  // Normal flow
}
```

**Value:**
- Prevents version mismatch bugs
- Runtime guard aligned with Step 2
- Clear user feedback on version issues

---

## 🎨 Styling & DOM Rules

### Rules (from UI_PLACEMENT_RULES.md)

1. **No Inline Styles:**
   - ❌ Forbidden: `<div style="color: red;">`
   - ✅ Allowed: `<div class="text-danger">` (Bootstrap utility)

2. **No Unscoped Global CSS:**
   - ❌ Forbidden: `.btn { color: red; }`
   - ✅ Allowed: `#material-constraints-modal .custom-btn { color: red; }`

3. **Container Hierarchy:**
   - New elements must be within mapped regions
   - Cannot append to `body` directly
   - Cannot create new root-level containers

4. **Class Naming:**
   - Use Bootstrap 5 utilities first
   - Custom classes must be scoped: `#material-constraints-modal .custom-class`
   - Document new classes in this plan

### New Classes (If Needed)

If new custom classes are required, document here:

- `constraints-schema-badge` - For schema version badge (scoped to `#constraints-contextual-info`)
- `constraints-field-error` - For field-level error messages (scoped to `#constraints-fields-container`)

---

## ✅ Test/Verification Plan

### Must-Pass Tests (Existing)

**Before Implementation:**
```bash
vendor/bin/phpunit --testsuite Contract
```

**Required Tests:**
- ✅ `ProductApiConstraintsContractTest` - Contract v1 compliance
- ✅ `ProductApiSchemaVersionTest` - Schema version presence
- ✅ `UiPlacementAnchorsTest` - Layout anchors exist ⭐ **CRITICAL**

**All tests must pass before UI changes.**

### Additional Tests (Step 4 - Add Before Implementation)

#### Test 1: Field Ordering Verification

**Purpose:** Ensure fields render in `display_order` sequence.

**Implementation:**
```php
// tests/Contract/UiFieldOrderingTest.php (new)
public function testFieldsRenderedInDisplayOrder(): void
{
    // Mock API response with fields in random order
    $fields = [
        ['field_key' => 'width_mm', 'display_order' => 5],
        ['field_key' => 'length_mm', 'display_order' => 6],
        ['field_key' => 'piece_count', 'display_order' => 7],
    ];
    
    // Shuffle to test ordering
    shuffle($fields);
    
    // Assert that renderer sorts by display_order
    // (This would require JS test infrastructure or string-based check)
}
```

**Note:** If JS test infrastructure is not available, use string-based smoke test:
- Check that `loadAndRenderConstraintFields()` function exists
- Check that function uses `display_order` in code

#### Test 2: Schema Version Guard

**Purpose:** Verify schema version check prevents invalid submissions.

**Implementation:**
```php
// tests/Contract/UiSchemaVersionGuardTest.php (new)
public function testSchemaVersionGuardBlocksInvalidVersion(): void
{
    // Test that UI shows warning when schema_version !== v1
    // Test that save button is disabled when version mismatch
    // (Requires JS test infrastructure or manual verification checklist)
}
```

#### Test 3: Anchor Integrity (Enhanced)

**Purpose:** Verify new elements don't break anchors.

**Update:** `UiPlacementAnchorsTest.php`
- Add test: New elements are within allowed regions
- Add test: No new root-level containers created
- Add test: Immutable anchors still exist after changes

### Golden UI State Fixture (Optional)

**Purpose:** Capture expected UI state for regression testing.

**Implementation:**
- Create `tests/fixtures/ui/constraints_modal_state_v1.json`
- Contains: Field count, anchor positions, expected structure
- Use for visual regression or structure validation

---

## 🚀 Rollout Strategy

### Feature Flag Approach

**If feature flag system exists:**
- Feature flag: `constraints_ui_v2` (or similar)
- Default: `false` (old behavior)
- Enable per tenant or globally

**Rollout Phases:**

1. **Internal/Staging:**
   - Enable: 100%
   - Duration: 1-2 weeks
   - Monitor: Error rates, user feedback

2. **Production (Gradual):**
   - Phase 1: 10% of tenants (1 week)
   - Phase 2: 50% of tenants (1 week)
   - Phase 3: 100% of tenants

3. **Kill Switch:**
   - If issues detected → disable feature flag
   - Revert to old behavior (no API changes needed)
   - Investigate and fix before re-enabling

### Telemetry (If Available)

**Metrics to Monitor:**
- Error submission rate (should decrease)
- Time to complete constraints (should decrease)
- User feedback scores
- API error rates (should not increase)

### Rollback Plan

**If rollback needed:**
1. Disable feature flag (instant)
2. No database changes required
3. No API changes required
4. UI reverts to old behavior

---

## 📊 Change Summary Matrix

| Change | Region | Anchors Touched | Risk Level | Value |
|--------|--------|----------------|-----------|-------|
| A: Schema Version Badge | `#constraints-contextual-info` | None (immutable) | Low | Medium |
| B: Field Ordering | `#constraints-fields-container` | None (content only) | Low | High |
| C: Validation UX | `#constraints-errors-list`, `#constraints-fields-container` | None (content only) | Medium | High |
| D: Save Button Guard | `#btn-save-constraints` | None (behavior only) | Low | High |
| E: Unit Display | `#constraints-unit-locked-display` | None (styling only) | Low | Medium |

**Overall Risk:** Low-Medium (all changes within allowed regions)

---

## ✅ Definition of Done (DoD)

Step 4 is **complete** when:

- [x] ✅ This plan document exists (`CONSTRAINTS_UI_CHANGE_PLAN_STEP4.md`)
- [x] ✅ All UI changes documented by region
- [x] ✅ Selectors/anchors that will be touched are identified
- [x] ✅ Immutable anchors are clearly marked as forbidden
- [x] ✅ Test plan defined (existing + new tests)
- [x] ✅ Rollout strategy defined
- [x] ✅ API/Contract compatibility verified (v1 only)
- [x] ✅ Styling rules compliance verified

**Note:** Step 4 does NOT include UI code implementation. Implementation happens in a separate step after plan approval.

---

## 📚 Related Documents

- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`
- **Placement Rules:** `docs/ui/UI_PLACEMENT_RULES.md`
- **Contract Spec:** `docs/contracts/products/constraints_contract_v1.md`
- **Schema Versioning:** `docs/schema/SCHEMA_VERSIONING_POLICY.md`
- **Baseline Audit:** `docs/super_dag/00-audit/CONSTRAINTS_UI_CHANGE_BASELINE.md`
- **Enterprise Plan:** `docs/super_dag/plans/CONSTRAINTS_ENTERPRISE_GRADE_PLAN.md`

---

## 🎯 Next Steps (After Step 4 Approval)

1. **Review & Approval:**
   - Review this plan with team
   - Get approval for changes
   - Verify test infrastructure availability

2. **Implementation:**
   - Implement changes one by one (A → E)
   - Run tests after each change
   - Verify anchors still pass

3. **Testing:**
   - Run all Contract tests
   - Manual testing in staging
   - User acceptance testing

4. **Rollout:**
   - Enable feature flag in staging
   - Gradual production rollout
   - Monitor metrics

---

**Status:** 📋 **PLAN COMPLETE - READY FOR REVIEW**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team
