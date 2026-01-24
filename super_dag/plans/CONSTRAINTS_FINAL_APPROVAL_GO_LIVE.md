# Constraints System - Final Approval & Go-Live Playbook

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** 🟢 **APPROVED FOR IMPLEMENTATION**  
**Purpose:** Final approval and go-live playbook for Constraints UI enhancements  
**Scope:** Implementation of Step 4 UI changes following Step 5 Protocol

---

## 🟢 FINAL APPROVAL

### System Status (Constraints System)

| Component | Status | Document |
|-----------|--------|----------|
| **Contract** | ✅ Locked | `docs/contracts/products/constraints_contract_v1.md` |
| **Schema Versioning** | ✅ Locked | `docs/schema/SCHEMA_VERSIONING_POLICY.md` |
| **UI Anchors + Placement Rules** | ✅ Locked | `docs/ui/UI_LAYOUT_MAP.md`, `docs/ui/UI_PLACEMENT_RULES.md` |
| **Change Plan** | ✅ Clear | `docs/super_dag/plans/CONSTRAINTS_UI_CHANGE_PLAN_STEP4.md` |
| **Implementation Protocol** | ✅ Ready | `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md` |
| **PR Plans** | ✅ Ready | `docs/super_dag/plans/CONSTRAINTS_PR_PLANS.md` |

### Approval Decision

✅ **APPROVED FOR IMPLEMENTATION**

**Conditions:**
- Implementation must follow Step 5 Protocol strictly
- All mandatory gates must pass for every PR
- Feature flags must be used for gradual rollout
- No deviation from approved plan without re-approval

**Authority:** Enterprise Architecture Team  
**Date:** January 5, 2026

---

## ▶️ Go-Live Playbook (Implementation Order)

### Mandatory Implementation Sequence

**⚠️ CRITICAL: Do NOT skip or reorder items**

| Order | PR | Item | Risk | Estimated Time |
|-------|----|------|------|-----------------|
| **1** | PR #1 | A: Schema Version Badge | Low | 30 min |
| **2** | PR #2 | B: Field Ordering + Unknown Type | Low | 1 hour |
| **3** | PR #3 | D: Save Button Guard | Low | 1 hour |
| **4** | PR #4 | E: Unit Locked Display | Low | 30 min |
| **5** | PR #5 | C: Validation UX | Medium | 2-3 hours |

**Total Estimated Time:** 5-6 hours

### Rationale for Order

**A, B, D, E (Low Risk Stabilizers):**
- Minimal DOM manipulation
- Low interaction complexity
- Easy to test and verify
- Build confidence before complex changes

**C (High Interaction Complexity):**
- Multiple DOM manipulations
- Event handlers (click, scroll, focus)
- Browser compatibility concerns
- Edge cases (rapid clicks, viewport issues)
- **Must be done last** to ensure baseline is stable

---

## 🔒 Mandatory Gates (Every PR)

### Gate 1: Contract Tests (HARD BLOCK)

**Command:**
```bash
vendor/bin/phpunit --testsuite Contract
```

**Required Tests (All Must Pass):**
- ✅ `ProductApiConstraintsContractTest` (5 tests)
- ✅ `ProductApiSchemaVersionTest` (6 tests)
- ✅ `UiPlacementAnchorsTest` (13 tests) ⭐ **CRITICAL**

**Failure = BLOCK MERGE**

**Rationale:** Ensures API contracts and layout anchors remain intact.

---

### Gate 2: UI Anchor Integrity (HARD BLOCK)

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

### Gate 3: Immutable Anchors Protection (HARD BLOCK)

**Manual Review Checklist:**
- [ ] `#material-constraints-modal` - Not removed/renamed
- [ ] `#constraints-form` - Not removed/renamed
- [ ] `#constraints-fields-container` - Not removed/renamed ⭐
- [ ] `#btn-save-constraints` - Not removed/renamed
- [ ] `#constraints-errors` - Not removed/renamed
- [ ] `#constraints-errors-list` - Not removed/renamed

**Violation = BLOCK MERGE**

---

### Gate 4: Staging Screenshot/Video (SOFT GATE - Recommended)

**Requirement:**
- Every PR must include screenshot or short video (30-60 seconds)
- Show: Modal open, changes visible, interaction working
- Format: PNG/MP4, attached to PR description

**Rationale:** Visual verification prevents UI regressions.

**Note:** Not a hard block, but strongly recommended.

---

## 🚩 Feature Flag Rules (MANDATORY)

### Rule 1: One Flag Per PR

**Forbidden:**
- ❌ Opening multiple flags in single PR
- ❌ Combining items without separate flags

**Required:**
- ✅ Each PR opens exactly one feature flag
- ✅ Flag name matches item (e.g., `constraints_ui_schema_badge` for Item A)

### Rule 2: Flag Opening Order (Staging)

**Sequence:**
1. PR #1 → Open `constraints_ui_schema_badge`
2. PR #2 → Open `constraints_ui_field_ordering`
3. PR #3 → Open `constraints_ui_save_guard`
4. PR #4 → Open `constraints_ui_unit_display`
5. PR #5 → Open `constraints_ui_validation_ux`

**Minimum QA:**
- At least 1 round of manual QA per item
- Test with flag enabled and disabled
- Verify kill switch works

### Rule 3: Kill Switch Requirement

**Mandatory:**
- Every feature flag must have kill switch capability
- Disabling flag must revert to old behavior instantly
- No code rollback needed when disabling flag

**Testing:**
- Test kill switch in staging before production
- Verify old behavior restored when flag disabled

---

## 🧪 Post-Merge Checklist (Per PR)

### After Merge, Before Production Deploy

**For Each PR:**

1. **Open Feature Flag in Staging:**
   - Enable flag for staging environment
   - Verify flag is active

2. **Manual QA (4 Critical Test Cases):**

   **Test Case 1: Schema Version Mismatch**
   - [ ] Mock API response with `meta.schema_version = "products.constraints.v2"`
   - [ ] Verify: Warning shown in contextual info
   - [ ] Verify: Save button disabled
   - [ ] Verify: User cannot submit

   **Test Case 2: Unknown Field Type**
   - [ ] Mock API response with unknown `field_type` (e.g., "custom_type")
   - [ ] Verify: Field renders as text input (safe fallback)
   - [ ] Verify: No UI breakage
   - [ ] Verify: Console warning logged (dev-only)

   **Test Case 3: Invalid Fields Display**
   - [ ] Submit form with missing required fields
   - [ ] Verify: Error summary shown in `#constraints-errors-list`
   - [ ] Verify: Error items are clickable
   - [ ] Verify: Clicking error scrolls to field
   - [ ] Verify: Field highlighted with `is-invalid` class
   - [ ] Verify: Inline error message shown below field

   **Test Case 4: Double Submit Prevention**
   - [ ] Click Save button rapidly (double-click)
   - [ ] Verify: Only one API request sent
   - [ ] Verify: Button disabled during request
   - [ ] Verify: Loading state shown ("Saving..." text)

3. **Kill Switch Test:**
   - [ ] Disable feature flag
   - [ ] Verify: Old behavior restored
   - [ ] Verify: No errors in console
   - [ ] Verify: Modal still functional

4. **Browser Compatibility:**
   - [ ] Test in Chrome
   - [ ] Test in Firefox
   - [ ] Test in Safari
   - [ ] Test in Edge (if applicable)

---

## 📌 Definition of Done (Implementation Phase)

### Constraints UI Implementation is "Complete" When:

**Code Complete:**
- [ ] PR #1 merged (Schema Version Badge)
- [ ] PR #2 merged (Field Ordering)
- [ ] PR #3 merged (Save Button Guard)
- [ ] PR #4 merged (Unit Locked Display)
- [ ] PR #5 merged (Validation UX)

**Tests Pass:**
- [ ] `vendor/bin/phpunit --testsuite Contract` - All passing
- [ ] `UiPlacementAnchorsTest` - All passing
- [ ] No immutable anchors removed/renamed

**Feature Flags:**
- [ ] All 5 flags created in `feature_flag_catalog`
- [ ] All flags enabled in staging
- [ ] All flags tested with kill switch
- [ ] Production rollout plan approved

**QA Complete:**
- [ ] All 4 critical test cases passed (per PR)
- [ ] Browser compatibility verified
- [ ] Manual QA checklist completed
- [ ] No regression issues found

**Documentation:**
- [ ] Code comments added for complex logic
- [ ] Feature flag usage documented
- [ ] Any deviations from plan documented

**Production Ready:**
- [ ] Staging validation complete
- [ ] Production rollout plan approved
- [ ] Monitoring/metrics in place (if available)
- [ ] Rollback plan verified

---

## 🚀 Production Rollout Strategy

### Phase 1: Staging (100%)

**Duration:** 1-2 weeks  
**Scope:** All items enabled  
**Monitoring:** Error rates, user feedback

### Phase 2: Production (Gradual)

**Item A, B, D, E (Low Risk):**
- Enable: 100% immediately
- Monitor: 1 week

**Item C (Medium Risk):**
- Phase 1: 10% of tenants (1 week)
- Phase 2: 50% of tenants (1 week)
- Phase 3: 100% of tenants

### Rollback Procedure

**If Issues Detected:**

1. **Immediate:**
   - Disable affected feature flag(s)
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

| PR | Item | Status | PR # | Feature Flag | Staging | Production |
|----|------|--------|------|--------------|---------|------------|
| #1 | A: Schema Badge | ⏳ Pending | - | `constraints_ui_schema_badge` | - | - |
| #2 | B: Field Ordering | ⏳ Pending | - | `constraints_ui_field_ordering` | - | - |
| #3 | D: Save Guard | ⏳ Pending | - | `constraints_ui_save_guard` | - | - |
| #4 | E: Unit Display | ⏳ Pending | - | `constraints_ui_unit_display` | - | - |
| #5 | C: Validation UX | ⏳ Pending | - | `constraints_ui_validation_ux` | - | - |

**Legend:**
- ⏳ Pending
- 🔄 In Progress
- ✅ Complete
- ❌ Blocked

---

## 🎯 Quick Reference

### Files to Modify

- **HTML:** `views/products.php` (lines 685-758)
- **JavaScript:** `assets/javascripts/products/product_components.js` (~1500 lines)

### Key Functions

- `openConstraintsModal(materialIndex)` - line ~1028
- `loadAndRenderConstraintFields(...)` - line ~1109
- `updateComputedQtyPreview(...)` - line ~1237
- `handleConstraintsFormSubmit(e)` - line ~1151

### Immutable Anchors (Never Touch)

- `#material-constraints-modal`
- `#constraints-form`
- `#constraints-fields-container` ⭐
- `#btn-save-constraints`
- `#constraints-errors`
- `#constraints-errors-list`

### Test Commands

```bash
# All contract tests
vendor/bin/phpunit --testsuite Contract

# UI anchors only
vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php

# Specific test
vendor/bin/phpunit tests/Contract/ProductApiConstraintsContractTest.php
```

---

## 📚 Related Documents

- **Implementation Protocol:** `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md`
- **PR Plans:** `docs/super_dag/plans/CONSTRAINTS_PR_PLANS.md`
- **UI Change Plan:** `docs/super_dag/plans/CONSTRAINTS_UI_CHANGE_PLAN_STEP4.md`
- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`
- **Placement Rules:** `docs/ui/UI_PLACEMENT_RULES.md`
- **Contract Spec:** `docs/contracts/products/constraints_contract_v1.md`
- **Schema Versioning:** `docs/schema/SCHEMA_VERSIONING_POLICY.md`

---

## ✅ Approval Sign-Off

**Status:** 🟢 **APPROVED FOR IMPLEMENTATION**

**Approved By:** Enterprise Architecture Team  
**Date:** January 5, 2026  
**Conditions:** Must follow Step 5 Protocol strictly

**Next Action:** Begin PR #1 (Schema Version Badge)

**Quick Start:** See `docs/super_dag/plans/CONSTRAINTS_QUICK_START_PR1.md`  
**Reminders:** See `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_REMINDERS.md`

---

**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team

