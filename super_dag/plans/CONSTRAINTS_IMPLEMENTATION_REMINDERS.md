# Implementation Reminders - Constraints UI Enhancements

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** 📋 **ACTIVE REMINDERS**  
**Purpose:** Critical reminders during implementation phase

---

## 🔒 Mandatory Rules (Never Violate)

### Rule 1: One Item Per PR

**FORBIDDEN:**
- ❌ Combining multiple items in single PR
- ❌ Opening multiple feature flags in single PR
- ❌ Implementing items out of order

**REQUIRED:**
- ✅ Each PR implements exactly one item
- ✅ Each PR opens exactly one feature flag
- ✅ Follow order: A → B → D → E → C

---

### Rule 2: Tests Must Pass (HARD BLOCK)

**Before Every PR Merge:**

```bash
# Must pass - HARD BLOCK
vendor/bin/phpunit --testsuite Contract
```

**Required:**
- ✅ All 24 tests pass
- ✅ All 351 assertions pass
- ✅ `UiPlacementAnchorsTest` - All 13 tests pass ⭐ **CRITICAL**

**Failure = BLOCK MERGE**

---

### Rule 3: Immutable Anchors (NEVER TOUCH)

**These selectors must NEVER be removed or renamed:**

- `#material-constraints-modal` - Modal root
- `#constraints-form` - Form container
- `#constraints-fields-container` - Dynamic fields container ⭐
- `#btn-save-constraints` - Save button
- `#constraints-errors` - Error container
- `#constraints-errors-list` - Error list

**Violation = BLOCK MERGE**

---

### Rule 4: Kill Switch Required

**Every Feature Flag Must:**
- ✅ Have kill switch capability
- ✅ Revert to old behavior when disabled
- ✅ Be tested before production

**Test Kill Switch:**
1. Enable flag → verify new behavior
2. Disable flag → verify old behavior restored
3. No errors in console
4. No layout drift

---

## 🧪 QA Focus Points (Every PR)

### Critical Test Cases

**Test Case 1: Schema Version Mismatch** (PR #1, #2, #3, #4, #5)
- Mock API with `meta.schema_version = "products.constraints.v2"`
- Verify: Warning shown (if applicable)
- Verify: Save button disabled (if applicable)
- Verify: User cannot submit

**Test Case 2: Unknown Field Type** (PR #2)
- Mock API with unknown `field_type` (e.g., "custom_type")
- Verify: Field renders as text input (safe fallback)
- Verify: No UI breakage
- Verify: Console warning logged (dev-only)

**Test Case 3: Invalid Fields Display** (PR #5)
- Submit form with missing required fields
- Verify: Error summary shown
- Verify: Error items clickable
- Verify: Clicking error scrolls to field
- Verify: Field highlighted
- Verify: Inline error message shown

**Test Case 4: Double Submit Prevention** (PR #3)
- Click Save button rapidly (double-click)
- Verify: Only one API request sent
- Verify: Button disabled during request
- Verify: Loading state shown

---

## 📋 PR Checklist Template

Copy this for every PR:

### Pre-Implementation
- [ ] Read PR plan document
- [ ] Read Implementation Protocol
- [ ] Read Layout Map (relevant regions)
- [ ] Confirm feature flag available

### Implementation
- [ ] Follow PR plan exactly
- [ ] Only modify specified files/lines
- [ ] Respect immutable anchors
- [ ] Add feature flag check

### Testing
- [ ] Run: `vendor/bin/phpunit --testsuite Contract`
- [ ] Run: `vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php`
- [ ] Manual testing in browser
- [ ] Test with feature flag enabled/disabled
- [ ] Screenshot/video attached

### Code Quality
- [ ] No inline styles (except dynamic `display`)
- [ ] No unscoped global CSS
- [ ] Uses Bootstrap 5 utilities
- [ ] Code comments added

### Documentation
- [ ] PR description references Step 4 plan
- [ ] PR description references Step 5 protocol
- [ ] Changes documented in PR description

---

## 🚨 Common Mistakes to Avoid

### Mistake 1: Combining Items
**Wrong:** Implementing A + B in single PR  
**Right:** One PR per item (A, then B, then D, etc.)

### Mistake 2: Skipping Tests
**Wrong:** "Tests will pass, let's merge"  
**Right:** Run tests, verify all pass, then merge

### Mistake 3: Touching Immutable Anchors
**Wrong:** Renaming `#constraints-fields-container` for convenience  
**Right:** Never touch immutable anchors, work within them

### Mistake 4: No Feature Flag
**Wrong:** Implementing without feature flag  
**Right:** Always use feature flag, test kill switch

### Mistake 5: Skipping QA
**Wrong:** "It works on my machine"  
**Right:** Full QA checklist, test all 4 critical cases

---

## 📊 Progress Tracking

### Implementation Status

| PR | Item | Status | Feature Flag | Staging | Production |
|----|------|--------|--------------|---------|------------|
| #1 | A: Schema Badge | ⏳ Pending | `constraints_ui_schema_badge` | - | - |
| #2 | B: Field Ordering | ⏳ Pending | `constraints_ui_field_ordering` | - | - |
| #3 | D: Save Guard | ⏳ Pending | `constraints_ui_save_guard` | - | - |
| #4 | E: Unit Display | ⏳ Pending | `constraints_ui_unit_display` | - | - |
| #5 | C: Validation UX | ⏳ Pending | `constraints_ui_validation_ux` | - | - |

**Update this table as you progress.**

---

## 🎯 Quick Reference

### Test Commands

```bash
# All contract tests
vendor/bin/phpunit --testsuite Contract

# UI anchors only
vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php

# Specific test
vendor/bin/phpunit tests/Contract/ProductApiConstraintsContractTest.php
```

### Files to Modify

- **HTML:** `views/products.php` (lines 685-758)
- **JavaScript:** `assets/javascripts/products/product_components.js` (~1500 lines)

### Key Functions

- `openConstraintsModal(materialIndex)` - line ~1028
- `loadAndRenderConstraintFields(...)` - line ~1109
- `updateComputedQtyPreview(...)` - line ~1237
- `handleConstraintsFormSubmit(e)` - line ~1151

---

## 📚 Related Documents

- **Quick Start PR #1:** `docs/super_dag/plans/CONSTRAINTS_QUICK_START_PR1.md`
- **PR Plans:** `docs/super_dag/plans/CONSTRAINTS_PR_PLANS.md`
- **Implementation Protocol:** `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md`
- **Go-Live Playbook:** `docs/super_dag/plans/CONSTRAINTS_FINAL_APPROVAL_GO_LIVE.md`
- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`
- **Placement Rules:** `docs/ui/UI_PLACEMENT_RULES.md`

---

**Status:** 📋 **ACTIVE - REFER DURING IMPLEMENTATION**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team
