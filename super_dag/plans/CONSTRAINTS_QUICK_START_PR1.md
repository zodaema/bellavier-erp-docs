# Quick Start Guide - PR #1: Schema Version Badge

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** 🚀 **READY TO START**  
**Purpose:** Quick reference for implementing PR #1 (Schema Version Badge)  
**Estimated Time:** 30 minutes

---

## 🎯 PR #1 Overview

**Item:** A: Schema Version Badge  
**Risk Level:** Low  
**Files to Modify:** 2 files
- `views/products.php` (add badge HTML)
- `assets/javascripts/products/product_components.js` (set badge value)

**Feature Flag:** `constraints_ui_schema_badge`

---

## ✅ Pre-Implementation Checklist

Before starting implementation:

- [ ] Read `CONSTRAINTS_PR_PLANS.md` - PR #1 section
- [ ] Read `CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md`
- [ ] Read `UI_LAYOUT_MAP.md` - Contextual Info region
- [ ] Confirm feature flag system available
- [ ] Have staging environment ready for testing

---

## 🔧 Implementation Steps

### Step 1: Add Badge HTML (views/products.php)

**Location:** Within `#constraints-contextual-info` region  
**Line:** After line 722 (after computed qty preview row)

**Code to Add:**
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

---

### Step 2: Add JavaScript Logic (product_components.js)

**Location:** In `openConstraintsModal()` function  
**Line:** After line ~1080 (after updating contextual badges)

**Code to Add:**
```javascript
// Item A: Schema Version Badge
const showSchemaBadge = window.__FEATURE_FLAGS__?.constraints_ui_schema_badge || false;

if (showSchemaBadge) {
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

---

### Step 3: Create Feature Flag

**Backend (if needed):**
```sql
-- Insert into feature_flag_catalog
INSERT INTO feature_flag_catalog (feature_key, display_name, description, default_value)
VALUES (
  'constraints_ui_schema_badge',
  'Constraints UI: Schema Version Badge',
  'Show schema version badge in Constraints Editor Modal',
  0
) ON DUPLICATE KEY UPDATE updated_at = NOW();
```

**Or use admin interface if available.**

---

## 🧪 Testing Checklist

### Before Opening PR

- [ ] **Contract Tests Pass:**
  ```bash
  vendor/bin/phpunit --testsuite Contract
  ```
  Must show: `OK (24 tests, 351 assertions)`

- [ ] **UI Anchor Tests Pass:**
  ```bash
  vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php
  ```
  All 13 tests must pass

- [ ] **Immutable Anchors Check:**
  - [ ] `#material-constraints-modal` - Not touched
  - [ ] `#constraints-form` - Not touched
  - [ ] `#constraints-fields-container` - Not touched
  - [ ] `#btn-save-constraints` - Not touched
  - [ ] `#constraints-errors` - Not touched
  - [ ] `#constraints-errors-list` - Not touched

- [ ] **Manual Testing:**
  - [ ] Open Constraints modal
  - [ ] With flag enabled: Badge shows "v1"
  - [ ] With flag disabled: Badge hidden
  - [ ] Badge positioned correctly (right-aligned)
  - [ ] No console errors
  - [ ] No layout drift

- [ ] **Screenshot/Video:**
  - [ ] Screenshot with flag enabled (badge visible)
  - [ ] Screenshot with flag disabled (badge hidden)
  - [ ] Or short video (30-60 seconds) showing toggle

---

## 📝 PR Description Template

```markdown
## PR #1: Schema Version Badge (Item A)

**Item:** A: Schema Version Badge  
**Risk Level:** Low  
**Feature Flag:** `constraints_ui_schema_badge`

### Changes
- Added schema version badge to `#constraints-contextual-info` region
- Badge displays version from `meta.schema_version` API response
- Badge hidden when feature flag disabled

### Files Modified
- `views/products.php` (add badge HTML)
- `assets/javascripts/products/product_components.js` (set badge value)

### Testing
- ✅ Contract tests pass: `vendor/bin/phpunit --testsuite Contract`
- ✅ UI anchor tests pass: `vendor/bin/phpunit tests/Contract/UiPlacementAnchorsTest.php`
- ✅ Immutable anchors untouched
- ✅ Manual testing completed
- ✅ Screenshots attached

### Related Documents
- Step 4 Plan: `docs/super_dag/plans/CONSTRAINTS_UI_CHANGE_PLAN_STEP4.md`
- PR Plans: `docs/super_dag/plans/CONSTRAINTS_PR_PLANS.md`
- Implementation Protocol: `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md`
```

---

## 🚨 Critical Reminders

**DO:**
- ✅ Only modify 2 files specified
- ✅ Only add badge to `#constraints-contextual-info` region
- ✅ Use feature flag check
- ✅ Run tests before opening PR
- ✅ Attach screenshots/video

**DON'T:**
- ❌ Modify immutable anchors
- ❌ Add inline styles (except `display: none`)
- ❌ Combine with other items
- ❌ Skip feature flag check
- ❌ Skip tests

---

## 🔄 Post-Merge Checklist

After PR #1 is merged:

1. **Open Feature Flag in Staging:**
   ```sql
   -- Enable for staging
   INSERT INTO feature_flag_tenant (feature_key, tenant_scope, value)
   VALUES ('constraints_ui_schema_badge', 'STAGING', 1)
   ON DUPLICATE KEY UPDATE value = 1;
   ```

2. **QA Testing:**
   - [ ] Badge shows "v1" when API returns `meta.schema_version = "products.constraints.v1"`
   - [ ] Badge hidden when feature flag disabled
   - [ ] Badge hidden when API doesn't return schema_version
   - [ ] Badge positioned correctly (right-aligned)
   - [ ] No console errors
   - [ ] No layout drift

3. **Kill Switch Test:**
   - [ ] Disable feature flag
   - [ ] Verify badge hidden
   - [ ] Verify old behavior restored
   - [ ] No errors in console

4. **Ready for PR #2:**
   - [ ] All QA tests pass
   - [ ] Kill switch verified
   - [ ] No issues found

---

## 📚 Related Documents

- **PR Plans:** `docs/super_dag/plans/CONSTRAINTS_PR_PLANS.md`
- **Implementation Protocol:** `docs/super_dag/plans/CONSTRAINTS_IMPLEMENTATION_PROTOCOL_STEP5.md`
- **Go-Live Playbook:** `docs/super_dag/plans/CONSTRAINTS_FINAL_APPROVAL_GO_LIVE.md`
- **Layout Map:** `docs/ui/UI_LAYOUT_MAP.md`

---

## 🎯 QA Focus Points (Quick Reference)

**Critical Tests:**
1. ✅ Badge shows `products.constraints.v1` correctly (both success/error responses)
2. ✅ Toggle flag off → UI reverts immediately
3. ✅ No console errors / layout drift

**Quick Test:**
```javascript
// In browser console (with modal open)
// Check badge exists
$('#constraints-schema-version-badge').length // Should be 1

// Check badge text
$('#constraints-schema-version-badge').text() // Should be "v1"

// Toggle flag (if possible)
// Verify badge shows/hides
```

---

**Status:** 🚀 **READY TO START**  
**Next:** Implement PR #1 following this guide  
**After PR #1:** Move to PR #2 (Field Ordering)
