# Step B: Lock Legacy Out - Implementation Results

**Date:** 2026-01-13  
**Status:** ✅ **COMPLETED**  
**Objective:** Isolate Legacy CUT UI from Enterprise CUT UI in Work Queue Modal

---

## Implementation Summary

### Enterprise Context Definition

```javascript
const isEnterpriseContext = !!(
  baseContext && 
  baseContext.source_page === 'work_queue' && 
  baseContext.isModal === true
);
```

**Enterprise Context = Work Queue Modal Only**

---

## Legacy Blocks Isolated

### 1. Legacy Form Block (qty_produced, qty_scrapped)
- **Selector:** `#cut-qty-produced` → `.closest('.row.g-3')`
- **Action:** `.remove()` (removed from DOM, not hidden)
- **Location:** `behavior_ui_templates.js` lines 129-142

### 2. Legacy BOM Section
- **Selector:** `.cut-bom-section`
- **Action:** `.remove()` (removed from DOM, not hidden)
- **Location:** `behavior_ui_templates.js` lines 435-464

### 3. Legacy Leather Sheets Section
- **Selector:** `.leather-sheets-section`
- **Action:** `.remove()` (removed from DOM, not hidden)
- **Location:** `behavior_ui_templates.js` lines 467-520+

### 4. Legacy Title
- **Selector:** `h6` (first, if text matches "Cut")
- **Action:** `.remove()` (removed from DOM, not hidden)
- **Location:** `behavior_ui_templates.js` line 126

---

## Implementation Details

### Files Modified

1. **`assets/javascripts/dag/behavior_execution.js`** (lines 640-710)
   - Added Enterprise Context detection
   - Added DOM removal logic (not hide)
   - Added CSS guard injection
   - Added `data-cut-ui-mode` attribute marking

### Code Changes

```javascript
// ✅ Step B: Lock Legacy Out (Enterprise CUT in Work Queue Modal)
const isEnterpriseContext = !!(baseContext && baseContext.source_page === 'work_queue' && baseContext.isModal);

if (isEnterpriseContext) {
    // Mark panel with Enterprise mode
    $panel.attr('data-cut-ui-mode', 'ENTERPRISE');
    
    // Remove legacy DOM nodes (not hide) - prevents flash
    $legacyFormRow.remove();
    $legacyBomSection.remove();
    $legacyLeatherSection.remove();
    $legacyTitle.remove();
    
    // Add CSS guard (prevent any legacy flash)
    // Injects CSS rule scoped to #workModal
}
```

---

## CSS Guard

**Purpose:** Prevent legacy blocks from appearing even for 1 frame during render.

**Implementation:**
- Injected as `<style id="cut-enterprise-css-guard">` in `<head>`
- Scoped to `#workModal [data-cut-ui-mode="ENTERPRISE"]`
- Multiple CSS properties to ensure complete hiding:
  - `display: none !important`
  - `visibility: hidden !important`
  - `opacity: 0 !important`
  - `height: 0 !important`
  - `overflow: hidden !important`

**Selectors Guarded:**
- `.row.g-3:has(#cut-qty-produced)`
- `.cut-bom-section`
- `.leather-sheets-section`

---

## Debug Marking

**Attribute:** `data-cut-ui-mode`
- **Value:** `"ENTERPRISE"` (in Work Queue modal)
- **Value:** `"LEGACY"` (in non-modal contexts)

**Usage:**
```javascript
// Check mode
const mode = $panel.attr('data-cut-ui-mode');
console.log('CUT UI Mode:', mode);
```

---

## Non-Modal Safety

**Preserved Legacy Functionality:**
- Legacy pages (non-modal) remain functional
- `job_ticket` context remains functional
- `pwa_scan` (non-modal) remains functional

**How:**
- Enterprise isolation only applies when `isEnterpriseContext === true`
- Legacy mode is marked but not removed in non-Enterprise contexts

---

## Acceptance Tests

### Test 1: Legacy Blocks Never Appear in Work Queue Modal
- ✅ **Expected:** No legacy form, BOM section, or leather section visible
- ✅ **Expected:** No flash/flicker during modal open
- ✅ **Expected:** DOM inspection shows legacy nodes removed (not just hidden)

### Test 2: Save & End Session → Return Step1
- ✅ **Expected:** No legacy flash during phase transition
- ✅ **Expected:** Only Enterprise Phase 1/2/3 blocks visible

### Test 3: Non-Modal Pages Remain Functional
- ✅ **Expected:** Legacy pages (if any) still work
- ✅ **Expected:** `job_ticket` context still works

---

## Verification Steps

### Console Verification
```javascript
// In Work Queue Modal, after CUT panel loads:
const $panel = $('#workModalBehaviorForm');
console.log('CUT UI Mode:', $panel.attr('data-cut-ui-mode')); // Should be "ENTERPRISE"

// Check legacy blocks are removed (not just hidden)
console.log('Legacy form exists:', $('#cut-qty-produced').length); // Should be 0
console.log('Legacy BOM exists:', $('.cut-bom-section').length); // Should be 0
console.log('Legacy leather exists:', $('.leather-sheets-section').length); // Should be 0
```

### DOM Inspection
1. Open Work Queue Modal with CUT behavior
2. Inspect `#workModalBehaviorForm`
3. Verify:
   - `data-cut-ui-mode="ENTERPRISE"` attribute exists
   - No `.row.g-3` containing `#cut-qty-produced`
   - No `.cut-bom-section` element
   - No `.leather-sheets-section` element
   - No legacy `h6` title

### Network/Performance
- No additional network requests (CSS guard is inline)
- No performance impact (DOM removal is synchronous)

---

## Known Limitations

1. **Template Still Contains Legacy:** Template still includes legacy blocks (for non-Enterprise contexts). This is intentional to preserve legacy functionality.

2. **CSS Guard Scope:** CSS guard is scoped to `#workModal` only. If modal ID changes, CSS guard must be updated.

3. **Legacy Title Detection:** Legacy title removal uses text matching (`=== tt('cut.title', 'Cut')`). If translation changes, this may need adjustment.

---

## Next Steps

After Step B completion:
- ✅ Legacy blocks isolated in Enterprise context
- ✅ No flash/flicker during render
- ✅ DOM is clean (legacy removed, not hidden)
- ✅ Ready for Step C: Controller Implementation

**Step C Prerequisites Met:**
- UI boundary is clean
- No contamination between Enterprise and Legacy
- Deterministic rendering possible

---

## References

- `docs/super_dag/tasks/CUT_UI_STATE_MODEL.md` - UI State Model (Legacy Isolation section)
- `docs/super_dag/tasks/archive/task31/task31_CUT_UX_REDESIGN_OPTION_A.md` - Original UX design

---

**Status:** ✅ **COMPLETED**  
**Next:** Step C - Controller Implementation
