# Constraints Implementation Protocol - Step 5

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** 📋 **PROTOCOL - MANDATORY FOR IMPLEMENTATION**  
**Purpose:** Define implementation order, guardrails, and PR checklist for UI changes  
**Scope:** Constraints Editor Modal UI enhancements (Step 4 plan items)

---

## 📋 Overview

This protocol defines the **mandatory implementation order** and **guardrails** for implementing UI changes defined in Step 4. This ensures minimal risk and maintains system integrity.

**Core Principle:**
> "Low risk first, high value first, complex last" — Implement changes in order of increasing risk and complexity.

---

## 📁 Files That Control Constraints Modal

**HTML Template:**
- `views/products.php` (lines 685-758)
  - Contains: Modal HTML structure, regions, anchors

**JavaScript Controller:**
- `assets/javascripts/products/product_components.js` (~1500 lines)
  - Key functions:
    - `openConstraintsModal(materialIndex)` - line ~1028
    - `loadAndRenderConstraintFields(roleCode, existingConstraints, materialUom, basisType)` - line ~1109
    - `updateComputedQtyPreview(materialUom, basisType)` - line ~1237
    - `handleConstraintsFormSubmit(e)` - line ~1151

**API Endpoints:**
- `source/product_api.php`
  - `list_role_fields` - Returns field definitions
  - `list_material_roles` - Returns role definitions
  - `add_component_material` (component_save) - Saves constraints

**Feature Flag System:**
- Backend: `source/BGERP/Service/FeatureFlagService.php`
- Frontend: `assets/javascripts/core/FeatureFlags.js` (optional, can use `window.__FEATURE_FLAGS__`)

---

## 🎯 Implementation Order (Risk-Based)

### Priority Order (Low Risk → High Risk)

| Priority | Item | Risk Level | Value | Complexity | Estimated Effort |
|----------|------|-----------|-------|------------|------------------|
| **1** | **A: Schema Version Badge** | Low | Medium | Low | 30 min |
| **2** | **B: Field Ordering + Unknown Type** | Low | High | Low | 1 hour |
| **3** | **D: Save Button Guard** | Low | High | Low | 1 hour |
| **4** | **E: Unit Locked Display** | Low | Medium | Low | 30 min |
| **5** | **C: Validation UX** | Medium | High | High | 2-3 hours |

**Total Estimated Time:** 5-6 hours

### Rationale

1. **A: Schema Version Badge** (Lowest Risk)
   - Touch: Only `#constraints-contextual-info` region
   - Impact: Read-only display, no interaction
   - Risk: Minimal (cosmetic only)

2. **B: Field Ordering** (Low Risk, High Value)
   - Touch: `loadAndRenderConstraintFields()` function only
   - Impact: Forward compatibility, predictable order
   - Risk: Low (defensive coding, fallback handling)

3. **D: Save Button Guard** (Low Risk, High Value)
   - Touch: Button behavior only (no structure change)
   - Impact: Prevents invalid submissions
   - Risk: Low (enhancement to existing logic)

4. **E: Unit Locked Display** (Low Risk, Cosmetic)
   - Touch: Styling/content only
   - Impact: User clarity
   - Risk: Minimal (visual only)

5. **C: Validation UX** (Highest Risk)
   - Touch: Multiple regions, DOM manipulation, event handlers
   - Impact: Complex interaction (click-to-focus, scroll, inline messages)
   - Risk: Medium (edge cases, browser compatibility)
   - **Reason for Last:** Most complex, most interaction points, highest chance of UX drift

---

## 🔒 Mandatory Guardrails (Every PR)

### Gate 1: Contract Tests Must Pass

**Command:**
```bash
vendor/bin/phpunit --testsuite Contract
```

**Required Tests:**
- ✅ `ProductApiConstraintsContractTest` (5 tests)
- ✅ `ProductApiSchemaVersionTest` (6 tests)
- ✅ `UiPlacementAnchorsTest` (13 tests)

**Failure = BLOCK MERGE**

**Rationale:** Ensures API contracts and layout anchors remain intact.

---

### Gate 2: UI Anchor Integrity

**Test:**
```bash
vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php
```

**Required:**
- All 13 anchor tests must pass
- No immutable anchors removed/renamed

**Failure = BLOCK MERGE**

**Rationale:** Prevents UI drift and breaking changes.

---

### Gate 3: Immutable Anchors Protection

**Manual Review Checklist:**
- [ ] `#material-constraints-modal` - Not removed/renamed
- [ ] `#constraints-form` - Not removed/renamed
- [ ] `#constraints-fields-container` - Not removed/renamed ⭐
- [ ] `#btn-save-constraints` - Not removed/renamed
- [ ] `#constraints-errors` - Not removed/renamed
- [ ] `#constraints-errors-list` - Not removed/renamed

**Violation = BLOCK MERGE**

**Rationale:** Immutable anchors are contract-level commitments.

---

### Gate 4: Staging Screenshot/Video (Recommended)

**Requirement:**
- Every PR must include screenshot or short video (30-60 seconds)
- Show: Modal open, changes visible, interaction working
- Format: PNG/MP4, attached to PR

**Rationale:** Visual verification prevents UI regressions.

---

## 🚩 Feature Flag Strategy

### Flag Name
```
constraints_ui_enhancements_v1
```

### Flag Structure

**Per-Item Flags (Recommended):**
- `constraints_ui_schema_badge` (Item A)
- `constraints_ui_field_ordering` (Item B)
- `constraints_ui_save_guard` (Item D)
- `constraints_ui_unit_display` (Item E)
- `constraints_ui_validation_ux` (Item C)

**Or Single Flag:**
- `constraints_ui_enhancements_v1` (all items together)

### Implementation Pattern

**Option 1: Using FeatureFlags Module (Recommended)**
```javascript
// In product_components.js - import FeatureFlags module
import { FeatureFlags } from '../core/FeatureFlags.js';

// Or if using global (non-module):
// const FeatureFlags = window.FeatureFlags || { isEnabled: () => false };

// Check flags
const FEATURES = {
  schemaBadge: FeatureFlags.isEnabled('constraints_ui_schema_badge', false),
  fieldOrdering: FeatureFlags.isEnabled('constraints_ui_field_ordering', false),
  saveGuard: FeatureFlags.isEnabled('constraints_ui_save_guard', false),
  unitDisplay: FeatureFlags.isEnabled('constraints_ui_unit_display', false),
  validationUx: FeatureFlags.isEnabled('constraints_ui_validation_ux', false),
};

// Usage
if (FEATURES.schemaBadge) {
  // Show schema version badge
}
```

**Option 2: Using window.__FEATURE_FLAGS__ (Fallback)**
```javascript
// In product_components.js - check window object
const FEATURES = {
  schemaBadge: window.__FEATURE_FLAGS__?.constraints_ui_schema_badge ?? false,
  fieldOrdering: window.__FEATURE_FLAGS__?.constraints_ui_field_ordering ?? false,
  saveGuard: window.__FEATURE_FLAGS__?.constraints_ui_save_guard ?? false,
  unitDisplay: window.__FEATURE_FLAGS__?.constraints_ui_unit_display ?? false,
  validationUx: window.__FEATURE_FLAGS__?.constraints_ui_validation_ux ?? false,
};
```

**Backend (PHP):**
```php
// In views/products.php or page definition
use BGERP\Service\FeatureFlagService;

$featureFlagService = new FeatureFlagService(core_db());
$org = resolve_current_org();
$tenantScope = $org['code'] ?? 'GLOBAL';

$flags = [
    'constraints_ui_schema_badge' => $featureFlagService->getFlag('constraints_ui_schema_badge', $tenantScope),
    'constraints_ui_field_ordering' => $featureFlagService->getFlag('constraints_ui_field_ordering', $tenantScope),
    // ... other flags
];

// Pass to frontend
echo '<script>window.__FEATURE_FLAGS__ = ' . json_encode($flags) . ';</script>';
```

### Rollout Strategy

**Phase 1: Internal/Staging**
- Enable: 100% for all items
- Duration: 1 week
- Monitor: Error rates, user feedback

**Phase 2: Production (Gradual)**
- Item A: 100% (low risk)
- Item B: 100% (low risk)
- Item D: 100% (low risk)
- Item E: 100% (low risk)
- Item C: 10% → 50% → 100% (higher risk)

**Kill Switch:**
- Disable flag → instant revert to old behavior
- No code rollback needed
- No database changes needed

---

## 📝 PR Implementation Plan

### PR #1: Schema Version Badge (Item A)

**Files to Modify:**
- `views/products.php` (add badge HTML in `#constraints-contextual-info`)
- `assets/javascripts/products/product_components.js` (set badge value in `openConstraintsModal()`)

**Changes:**
- Add schema version badge to `#constraints-contextual-info`
- Read from `response.meta.schema_version` (from `list_role_fields` API)
- Display as "v1" badge (extract version number from "products.constraints.v1")
- Feature flag: `constraints_ui_schema_badge` (default: false)

**Implementation Details:**
- Badge location: End of contextual info section, right-aligned
- Badge selector: `#constraints-schema-version-badge` (new ID)
- Data source: `response.meta.schema_version` from API (NOT `_debug`)

**Risk:** Low  
**Estimated Time:** 30 minutes

**PR Checklist:**
- [ ] Contract tests pass
- [ ] UI anchor tests pass
- [ ] Immutable anchors untouched
- [ ] Screenshot attached
- [ ] Feature flag implemented (if using)
- [ ] Badge shows correct version from API
- [ ] Badge hidden when feature flag disabled

---

### PR #2: Field Ordering + Unknown Type (Item B)

**Files to Modify:**
- `assets/javascripts/products/product_components.js` (update `loadAndRenderConstraintFields()` function, line ~1109)

**Changes:**
- Sort fields by `display_order` before rendering (defensive sort)
- Handle unknown `field_type` with safe fallback (render as text input)
- Log warning for unknown types (console.warn, dev-only)
- Feature flag: `constraints_ui_field_ordering` (default: false)

**Implementation Details:**
- Sort: `resp.fields.sort((a, b) => (a.display_order || 0) - (b.display_order || 0))`
- Unknown type handling: Check if `field_type` in known types array, else render as text
- Known types: `['number', 'select', 'text', 'boolean', 'json']`

**Risk:** Low  
**Estimated Time:** 1 hour

**PR Checklist:**
- [ ] Contract tests pass
- [ ] UI anchor tests pass
- [ ] Immutable anchors untouched
- [ ] Tested with unknown field type (mock API response)
- [ ] Fields render in `display_order` sequence
- [ ] Screenshot attached
- [ ] Feature flag implemented (if using)

---

### PR #3: Save Button Guard (Item D)

**Files to Modify:**
- `assets/javascripts/products/product_components.js` (update `handleConstraintsFormSubmit()` line ~1151 and `updateComputedQtyPreview()` line ~1237)

**Changes:**
- Enhanced disable conditions (required fields incomplete, local validation errors)
- Loading state during API call (show "Saving..." text, disable button)
- Prevent double-submit (disable button immediately on click)
- Feature flag: `constraints_ui_save_guard` (default: false)

**Implementation Details:**
- Disable conditions: Check `isComplete` (from `updateComputedQtyPreview`) + local validation errors
- Loading state: Change button text to "Saving..." and disable
- Double-submit: Set flag `isSubmitting = true` at start, clear on completion/error

**Risk:** Low  
**Estimated Time:** 1 hour

**PR Checklist:**
- [ ] Contract tests pass
- [ ] UI anchor tests pass
- [ ] Immutable anchors untouched
- [ ] Tested double-submit prevention (rapid clicks)
- [ ] Tested loading state (button disabled during API call)
- [ ] Screenshot/video attached
- [ ] Feature flag implemented (if using)

---

### PR #4: Unit Locked Display (Item E)

**Files to Modify:**
- `views/products.php` (enhance unit display HTML, line ~726-730)

**Changes:**
- Add lock icon/indicator (Feather icon: `fe-lock`)
- Enhanced help text (clarify which fields use which units)
- Consistent null handling (show "—" if unit is null)
- Feature flag: `constraints_ui_unit_display` (default: false)

**Implementation Details:**
- Icon: `<i class="fe fe-lock ms-1 text-muted" title="Unit cannot be changed"></i>`
- Badge: Add "Locked" badge in input-group-text
- Help text: "Width, length, and thickness are always in mm. This cannot be changed."

**Risk:** Low  
**Estimated Time:** 30 minutes

**PR Checklist:**
- [ ] Contract tests pass
- [ ] UI anchor tests pass
- [ ] Immutable anchors untouched
- [ ] Lock icon visible
- [ ] Help text clear
- [ ] Screenshot attached
- [ ] Feature flag implemented (if using)

---

### PR #5: Validation UX (Item C)

**Files to Modify:**
- `assets/javascripts/products/product_components.js` (update `updateComputedQtyPreview()` line ~1237 and error handling)

**Changes:**
- Enhanced error list (clickable items with click handlers)
- Field-level inline error messages (within field container, using `invalid-feedback` class)
- Click-to-focus functionality (scroll to field + focus)
- Scroll to field on error click (smooth scroll)
- Feature flag: `constraints_ui_validation_ux` (default: false)

**Implementation Details:**
- Error list: Make `<li>` items clickable with `cursor: pointer` and click handler
- Inline messages: Append `<div class="invalid-feedback">Error message</div>` below field
- Click handler: `$field[0].scrollIntoView({ behavior: 'smooth', block: 'center' })` + `$field.focus()`
- Error source: Both server (`response.invalid_fields`) and client (local validation)

**Risk:** Medium  
**Estimated Time:** 2-3 hours

**PR Checklist:**
- [ ] Contract tests pass
- [ ] UI anchor tests pass
- [ ] Immutable anchors untouched
- [ ] Tested click-to-focus (error item → field focused)
- [ ] Tested scroll behavior (smooth scroll works)
- [ ] Tested browser compatibility (Chrome, Firefox, Safari, Edge)
- [ ] Tested with server errors (`invalid_fields`)
- [ ] Tested with client errors (required fields)
- [ ] Screenshot/video attached
- [ ] Feature flag implemented (if using)

---

## ✅ Definition of Done (Implementation Phase)

### All Items Complete When:

**Code Complete:**
- [ ] Items A, B, D, E, C implemented
- [ ] All code follows Placement Rules
- [ ] All code follows Styling Rules
- [ ] Feature flags implemented (if using)

**Tests Pass:**
- [ ] `vendor/bin/phpunit --testsuite Contract` - All passing
- [ ] `UiPlacementAnchorsTest` - All passing
- [ ] No immutable anchors removed/renamed

**Manual QA Checklist:**
- [ ] **Schema Version Mismatch:**
  - [ ] When `meta.schema_version !== "products.constraints.v1"` → warning shown
  - [ ] Save button disabled when version mismatch
  - [ ] Warning visible in contextual info

- [ ] **Unknown Field Type:**
  - [ ] Unknown `field_type` renders as text input (safe fallback)
  - [ ] No UI breakage with unknown types
  - [ ] Console warning logged (dev-only)

- [ ] **Invalid Fields Display:**
  - [ ] `invalid_fields` from API shows in error list
  - [ ] Error items are clickable
  - [ ] Clicking error scrolls to field
  - [ ] Field highlighted with `is-invalid` class
  - [ ] Inline error message shown below field

- [ ] **Double Submit Prevention:**
  - [ ] Save button disabled during API call
  - [ ] Loading state shown during request
  - [ ] Cannot submit twice in quick succession

- [ ] **Field Ordering:**
  - [ ] Fields render in `display_order` sequence
  - [ ] Order matches API response order

- [ ] **Unit Display:**
  - [ ] Unit locked indicator visible
  - [ ] Help text clear and helpful
  - [ ] Null unit shows "—" consistently

**Documentation:**
- [ ] Code comments added for complex logic
- [ ] Feature flag usage documented (if using)
- [ ] Any new classes documented in Placement Rules

**Rollout:**
- [ ] Feature flag enabled in staging
- [ ] Manual testing completed in staging
- [ ] Production rollout plan approved

---

## 🚨 Risk Mitigation

### High-Risk Scenarios

1. **Anchor Drift:**
   - **Mitigation:** `UiPlacementAnchorsTest` must pass
   - **Detection:** Automated test failure

2. **Contract Break:**
   - **Mitigation:** Contract tests must pass
   - **Detection:** Automated test failure

3. **Browser Compatibility:**
   - **Mitigation:** Test in Chrome, Firefox, Safari
   - **Detection:** Manual QA

4. **Feature Flag Issues:**
   - **Mitigation:** Kill switch capability
   - **Detection:** Monitoring + user feedback

### Rollback Procedure

**If Issues Detected:**

1. **Immediate:**
   - Disable feature flag(s)
   - System reverts to old behavior
   - No code rollback needed

2. **Investigation:**
   - Review error logs
   - Check test results
   - Identify root cause

3. **Fix:**
   - Fix issue in separate PR
   - Re-enable feature flag after fix verified

---

## 📊 Progress Tracking

### Implementation Status

| Item | Status | PR # | Feature Flag | Notes |
|------|--------|------|--------------|-------|
| A: Schema Badge | ⏳ Pending | - | - | - |
| B: Field Ordering | ⏳ Pending | - | - | - |
| D: Save Guard | ⏳ Pending | - | - | - |
| E: Unit Display | ⏳ Pending | - | - | - |
| C: Validation UX | ⏳ Pending | - | - | - |

**Legend:**
- ⏳ Pending
- 🔄 In Progress
- ✅ Complete
- ❌ Blocked

---

## 📚 Related Documents

- **UI Change Plan:** `docs/super_dag/plans/CONSTRAINTS_UI_CHANGE_PLAN_STEP4.md`
- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`
- **Placement Rules:** `docs/ui/UI_PLACEMENT_RULES.md`
- **Contract Spec:** `docs/contracts/products/constraints_contract_v1.md`
- **Schema Versioning:** `docs/schema/SCHEMA_VERSIONING_POLICY.md`

---

## 🎯 Next Steps

1. **Review Protocol:**
   - Review this protocol with team
   - Confirm feature flag system availability
   - Confirm test infrastructure

2. **Start Implementation:**
   - Begin with PR #1 (Item A: Schema Badge)
   - Follow PR checklist strictly
   - Run tests after each change

3. **Iterate:**
   - Complete items in order (A → B → D → E → C)
   - Don't skip items
   - Don't combine items in single PR (unless approved)

---

**Status:** 📋 **PROTOCOL READY - AWAITING IMPLEMENTATION**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team

