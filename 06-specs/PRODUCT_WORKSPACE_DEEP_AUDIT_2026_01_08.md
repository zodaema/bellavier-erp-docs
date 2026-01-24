# 🔍 Product Workspace Deep Security & Quality Audit
## Date: 2026-01-08
## Scope: Pre-Phase 4 Comprehensive Review

**Audited Components:**
- `assets/javascripts/products/product_workspace.js` (3,337 lines)
- `source/products.php` (3,250 lines)
- `source/product_api.php` (5,355 lines)
- `source/BGERP/Service/SecurityService.php` (330 lines)
- Related API endpoints and services

---

## 🎯 Executive Summary

**Overall Status:** ⚠️ **MEDIUM RISK** - Critical issues found requiring immediate attention

**Risk Distribution:**
- 🔴 **CRITICAL (P0):** 3 issues
- 🟠 **HIGH (P1):** 5 issues
- 🟡 **MEDIUM (P2):** 7 issues
- 🟢 **LOW (P3):** 4 issues

**Total Issues:** 19

---

## 🔴 CRITICAL ISSUES (P0) - Fix Before Phase 4

### P0-1: Race Condition in Concurrent Save Operations

**Location:** `product_workspace.js` - `handleSaveGeneral()` (Line ~1082)

**Issue:**
```javascript
async function handleSaveGeneral() {
  // Collect data
  const data = {
    action: 'update',
    id_product: state.productId,
    name: $('#workspace_name').val(),
    // ...
  };
  
  const resp = await $.post(CONFIG.endpoint, data);
  
  if (!resp?.ok) {
    const handled = await handleApiError(resp, 'general_save');
    if (handled) {
      return; // ❌ Button re-enabled in finally, allows re-submission
    }
    throw new Error(resp?.error || 'Save failed');
  }
}
```

**Problem:**
1. User clicks "Save" rapidly
2. First request still pending
3. Second request sent with same data
4. Both requests may succeed → duplicate updates
5. No optimistic locking for `product` table (only `product_graph_binding` has `row_version`)

**Attack Vector:**
- Malicious user can send 10 concurrent requests
- Each increments a counter or modifies state
- Final state is unpredictable

**Impact:**
- Data corruption
- Lost updates
- Inconsistent state

**Fix Required:**
```javascript
async function handleSaveGeneral() {
  // Prevent double-click
  if (state.isSaving) {
    console.warn('[ProductWorkspace] Save already in progress');
    return;
  }
  state.isSaving = true;
  
  try {
    // ... existing code ...
  } finally {
    state.isSaving = false;
    $('#btnSaveGeneral').prop('disabled', false);
  }
}
```

---

### P0-2: Missing Row Version for Product Table

**Location:** `database/` - Schema definition

**Issue:**
- `product_graph_binding` has `row_version` (Job A) ✅
- `product` table has **NO** `row_version` ❌

**Problem:**
1. User A loads product (name: "Shirt V1")
2. User B loads same product (name: "Shirt V1")
3. User A saves (name: "Shirt V2")
4. User B saves (name: "Shirt V3") ← Overwrites A's change silently
5. User A's change is lost forever

**Impact:**
- Lost updates (last write wins)
- No conflict detection
- Silent data loss

**Fix Required:**
```sql
-- Migration: 2026_01_product_row_version.php
ALTER TABLE product 
  ADD COLUMN row_version INT NOT NULL DEFAULT 1,
  ADD COLUMN updated_at DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP;
```

```php
// products.php - handleUpdate
$stmt = $tenantDb->prepare("
  UPDATE product 
  SET name = ?, 
      description = ?, 
      row_version = row_version + 1,
      updated_at = NOW()
  WHERE id_product = ? 
    AND row_version = ?
");
$stmt->bind_param('ssii', $name, $desc, $productId, $rowVersion);
$stmt->execute();

if ($stmt->affected_rows === 0) {
  json_error('Product was modified by another user', 409, [
    'app_code' => 'PROD_409_CONFLICT'
  ]);
}
```

---

### P0-3: XSS Vulnerability in Error Message Display

**Location:** `product_workspace.js` - `handleApiError()` (Line ~248)

**Issue:**
```javascript
if (appCode === 'PROD_400_VALIDATION') {
  const errors = resp?.meta?.errors || [];
  const errorList = errors.map(err => {
    const fieldLabel = err.field || 'Unknown field';
    const message = err.message || 'Validation failed';
    // ❌ No HTML escaping!
    return `<li class="text-danger mb-2"><strong>${fieldLabel}:</strong> ${message}</li>`;
  }).join('');
  
  await Swal.fire({
    html: `
      <p class="text-muted mb-3">กรุณาแก้ไขข้อผิดพลาดต่อไปนี้:</p>
      <ul class="list-unstyled text-start">${errorList}</ul>
    `
  });
}
```

**Attack Vector:**
1. Attacker sends malicious product name: `<img src=x onerror=alert(document.cookie)>`
2. Backend validation fails with error: `Field 'name' contains invalid characters: <img src=x onerror=alert(document.cookie)>`
3. Error message displayed in SweetAlert **without escaping**
4. XSS executed in user's browser

**Impact:**
- Session hijacking
- Cookie theft
- Malicious redirects
- DOM manipulation

**Fix Required:**
```javascript
// Add at top of file
function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// In handleApiError
const errorList = errors.map(err => {
  const fieldLabel = escapeHtml(err.field || 'Unknown field');
  const message = escapeHtml(err.message || 'Validation failed');
  return `<li class="text-danger mb-2"><strong>${fieldLabel}:</strong> ${message}</li>`;
}).join('');
```

**Note:** `escapeHtml` function exists in code (Line ~225) but **not used consistently**.

---

## 🟠 HIGH PRIORITY ISSUES (P1)

### P1-1: Incomplete CSRF Protection

**Location:** `source/BGERP/Service/SecurityService.php` - `validateOriginReferer()`

**Issue:**
```php
public static function validateOriginReferer(): bool {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? null;
    $referer = $_SERVER['HTTP_REFERER'] ?? null;
    
    // ❌ No check for completely missing headers!
    if (!$origin && !$referer) {
        // Older browsers or privacy extensions might not send these
        // Current code: returns false (blocks request)
        // Should: have a policy decision
    }
    
    // Current implementation blocks if both missing
    // This is GOOD for security but MAY cause false positives
}
```

**Problem:**
- Some legitimate users (privacy-focused browsers, VPNs, corporate proxies) might have both headers stripped
- Current implementation: **blocks all requests without Origin/Referer**
- This is **secure by default** but may impact UX

**Recommendation:**
- **Keep current behavior** (secure by default)
- Add **monitoring/logging** for blocked legitimate users
- Consider **allowlist** for known-safe user agents
- Document this behavior in API docs

**Status:** ✅ **ACCEPTABLE** - Current implementation is secure, but needs documentation

---

### P1-2: Missing Input Length Validation

**Location:** `product_workspace.js` - `handleSaveGeneral()` (Line ~1092)

**Issue:**
```javascript
const data = {
  action: 'update',
  id_product: state.productId,
  name: $('#workspace_name').val(), // ❌ No length check
  description: $('#workspace_description').val(), // ❌ Could be 1MB of text
  // ...
};
```

**Problem:**
1. User enters 10,000 character product name
2. Request sent to server
3. MySQL rejects (VARCHAR(255) limit)
4. Error returned to user after wasted request

**Impact:**
- Wasted bandwidth
- Poor UX (slow feedback)
- Server resource waste

**Fix Required:**
```javascript
// Collect data
const name = $('#workspace_name').val()?.trim();
const description = $('#workspace_description').val()?.trim();

// Frontend validation
const errors = [];
if (!name || name.length === 0) {
  errors.push('Product name is required');
}
if (name && name.length > 255) {
  errors.push('Product name must be 255 characters or less');
}
if (description && description.length > 5000) {
  errors.push('Description must be 5000 characters or less');
}

if (errors.length > 0) {
  await Swal.fire({
    title: 'Validation Error',
    html: '<ul>' + errors.map(e => `<li>${escapeHtml(e)}</li>`).join('') + '</ul>',
    icon: 'warning'
  });
  return;
}

const data = {
  action: 'update',
  id_product: state.productId,
  name,
  description,
  // ...
};
```

---

### P1-3: Readiness Check Race Condition

**Location:** `product_workspace.js` - `loadReadiness()` (Line ~387)

**Issue:**
```javascript
async function loadReadiness() {
  if (!state.productId) return;
  
  state.readiness.isLoading = true; // ❌ No guard against concurrent calls
  
  try {
    const resp = await $.getJSON(CONFIG.productApiEndpoint, {
      action: 'get_product_readiness',
      id_product: state.productId
    });
    
    if (resp?.ok && resp.readiness) {
      state.readiness = {
        ready: resp.readiness.ready || false,
        checks: resp.readiness.checks || {},
        failed: resp.readiness.failed || [],
        // ...
      };
    }
  } finally {
    state.readiness.isLoading = false;
  }
}
```

**Problem:**
1. User saves Structure → `loadReadiness()` called
2. User quickly saves Production → `loadReadiness()` called again
3. Both requests pending
4. Response order is unpredictable
5. Final state may be from older request

**Impact:**
- Stale readiness data displayed
- User sees incorrect "ready" status
- May allow publishing unready product (if client-side check only)

**Fix Required:**
```javascript
let readinessRequestToken = 0;

async function loadReadiness() {
  if (!state.productId) return;
  
  // Cancel previous request
  const currentToken = ++readinessRequestToken;
  
  state.readiness.isLoading = true;
  
  try {
    const resp = await $.getJSON(CONFIG.productApiEndpoint, {
      action: 'get_product_readiness',
      id_product: state.productId
    });
    
    // Ignore stale response
    if (currentToken !== readinessRequestToken) {
      console.log('[ProductWorkspace] Ignoring stale readiness response');
      return;
    }
    
    if (resp?.ok && resp.readiness) {
      state.readiness = {
        ready: resp.readiness.ready || false,
        checks: resp.readiness.checks || {},
        failed: resp.readiness.failed || [],
        // ...
      };
    }
  } finally {
    if (currentToken === readinessRequestToken) {
      state.readiness.isLoading = false;
    }
  }
}
```

---

### P1-4: Missing Error Handling in Asset Operations

**Location:** `product_workspace.js` - Asset tab handlers

**Issue:**
- `handleAssetUpload` - ❌ No error handling for large files
- `handleSetPrimaryAsset` - ❌ No error handling for 409 conflicts
- `handleDeleteAsset` - ❌ No confirmation dialog

**Problem:**
1. User uploads 50MB image (max is 5MB)
2. No frontend validation
3. Request sent → server rejects → generic error
4. User confused

**Fix Required:**
```javascript
async function handleAssetUpload(e) {
  const files = e.target.files;
  if (!files || files.length === 0) return;
  
  // Frontend validation
  const maxSize = 5 * 1024 * 1024; // 5MB
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
  
  const file = files[0];
  
  if (file.size > maxSize) {
    await Swal.fire({
      title: 'File Too Large',
      text: `Maximum file size is 5MB. Your file is ${(file.size / 1024 / 1024).toFixed(2)}MB.`,
      icon: 'error'
    });
    return;
  }
  
  if (!allowedTypes.includes(file.type)) {
    await Swal.fire({
      title: 'Invalid File Type',
      text: 'Only JPEG, PNG, and WebP images are allowed.',
      icon: 'error'
    });
    return;
  }
  
  // ... proceed with upload
}
```

---

### P1-5: No Idle Session Timeout Warning

**Location:** `product_workspace.js` - No session management

**Issue:**
- User opens workspace
- Edits form for 2 hours
- Session expires (typical timeout: 30-60 minutes)
- User clicks "Save"
- Gets 401 Unauthorized
- **All changes lost**

**Impact:**
- Poor UX
- Data loss
- User frustration

**Fix Required:**
```javascript
// Session activity tracking
let lastActivity = Date.now();
let sessionWarningShown = false;

function resetActivityTimer() {
  lastActivity = Date.now();
  sessionWarningShown = false;
}

// Monitor user activity
$(document).on('mousemove keydown click', resetActivityTimer);

// Check session status every 5 minutes
setInterval(async () => {
  const idleTime = Date.now() - lastActivity;
  const warningThreshold = 25 * 60 * 1000; // 25 minutes
  const sessionTimeout = 30 * 60 * 1000; // 30 minutes
  
  if (idleTime > warningThreshold && !sessionWarningShown) {
    sessionWarningShown = true;
    const result = await Swal.fire({
      title: 'Session Expiring Soon',
      text: 'Your session will expire in 5 minutes. Save your work now.',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Save Now',
      cancelButtonText: 'Continue Editing'
    });
    
    if (result.isConfirmed) {
      handleSaveGeneral();
    }
  }
  
  if (idleTime > sessionTimeout) {
    await Swal.fire({
      title: 'Session Expired',
      text: 'Your session has expired. Please log in again.',
      icon: 'error',
      allowOutsideClick: false
    });
    window.location.href = 'index.php?p=login';
  }
}, 5 * 60 * 1000); // Check every 5 minutes
```

---

## 🟡 MEDIUM PRIORITY ISSUES (P2)

### P2-1: Inefficient Readiness Polling

**Location:** `product_workspace.js` - Config (Line ~21)

**Issue:**
```javascript
const CONFIG = {
  endpoint: 'source/products.php',
  productApiEndpoint: 'source/product_api.php',
  modalId: '#productWorkspaceModal',
  pollInterval: 30000, // ❌ 30 seconds - inefficient
};
```

**Problem:**
- Readiness check polls every 30 seconds
- Even when modal is inactive
- Even when no changes
- Wastes server resources

**Fix Required:**
```javascript
// Only poll when:
// 1. Modal is visible
// 2. Product has been modified recently
// 3. Readiness is not already "ready"

function startReadinessPoll() {
  if (state.readiness.ready) {
    return; // Already ready, no need to poll
  }
  
  if (!$(CONFIG.modalId).is(':visible')) {
    return; // Modal hidden, don't poll
  }
  
  state.statusPollTimer = setInterval(async () => {
    if (!$(CONFIG.modalId).is(':visible')) {
      stopReadinessPoll();
      return;
    }
    
    await loadReadiness();
    
    if (state.readiness.ready) {
      stopReadinessPoll(); // Stop when ready
    }
  }, 30000);
}

function stopReadinessPoll() {
  if (state.statusPollTimer) {
    clearInterval(state.statusPollTimer);
    state.statusPollTimer = null;
  }
}
```

---

### P2-2: Missing Retry Logic for Failed API Calls

**Location:** All `$.post` / `$.getJSON` calls

**Issue:**
```javascript
const resp = await $.post(CONFIG.endpoint, data);

if (!resp?.ok) {
  throw new Error(resp?.error || 'Save failed');
}
```

**Problem:**
- Network hiccup → request fails
- No automatic retry
- User must manually retry
- Poor mobile UX

**Fix Required:**
```javascript
async function apiCallWithRetry(url, data, maxRetries = 2) {
  for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
    try {
      const resp = await $.post(url, data);
      return resp;
    } catch (err) {
      if (attempt === maxRetries + 1) {
        throw err; // Final attempt failed
      }
      
      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      console.log(`[ProductWorkspace] Retry ${attempt}/${maxRetries}`);
    }
  }
}

// Usage
const resp = await apiCallWithRetry(CONFIG.endpoint, data);
```

---

### P2-3: No Request Cancellation on Modal Close

**Location:** `product_workspace.js` - `handleClose()` (Line ~695)

**Issue:**
```javascript
async function handleClose() {
  if (isWorkspaceDirty()) {
    const result = await Swal.fire({
      title: 'Unsaved Changes',
      text: 'You have unsaved changes. Close anyway?',
      showCancelButton: true
    });
    
    if (!result.isConfirmed) return;
  }
  
  $(CONFIG.modalId).modal('hide');
  resetState();
  // ❌ No cancellation of pending requests!
}
```

**Problem:**
1. User clicks "Save"
2. Request pending
3. User clicks "Close" immediately
4. Modal closes, state resets
5. Save response comes back → updates stale state
6. **State corruption**

**Fix Required:**
```javascript
// Track active requests
const activeRequests = new Set();

function registerRequest(xhr) {
  activeRequests.add(xhr);
  xhr.always(() => activeRequests.delete(xhr));
}

async function handleClose() {
  if (isWorkspaceDirty()) {
    const result = await Swal.fire({
      title: 'Unsaved Changes',
      text: 'You have unsaved changes. Close anyway?',
      showCancelButton: true
    });
    
    if (!result.isConfirmed) return;
  }
  
  // Cancel all pending requests
  activeRequests.forEach(xhr => {
    if (xhr && typeof xhr.abort === 'function') {
      xhr.abort();
    }
  });
  activeRequests.clear();
  
  $(CONFIG.modalId).modal('hide');
  resetState();
}
```

---

### P2-4: SKU Auto-Generation Logic Ambiguity

**Location:** `product_workspace.js` - `handleSaveGeneral()` (Line ~1103)

**Issue:**
```javascript
// SKU: Only send if user explicitly changed it (otherwise backend auto-generates)
const skuValue = $('#workspace_sku').val()?.trim();
if (skuValue) {
  data.sku = skuValue;
}
```

**Problem:**
- What if user **clears** the SKU field intentionally?
- Current code: Don't send SKU → backend auto-generates new one
- Expected: Clear SKU → Error "SKU is required"
- **Ambiguous behavior**

**Fix Required:**
```javascript
// SKU handling:
// 1. If user never touched SKU field → Don't send (let backend auto-generate)
// 2. If user entered SKU → Send it (use user's value)
// 3. If user cleared SKU → Send empty string (backend should error)

const skuValue = $('#workspace_sku').val();
const skuTouched = $('#workspace_sku').data('touched'); // Track if user edited

if (skuTouched) {
  data.sku = skuValue?.trim() || ''; // Send even if empty
} else {
  // Don't include SKU in payload (backend auto-generates)
}

// Track field changes
$('#workspace_sku').on('input', function() {
  $(this).data('touched', true);
});
```

---

### P2-5: Graph Visualization Memory Leak

**Location:** `product_workspace.js` - Graph rendering code

**Issue:**
- Cytoscape.js instances not properly destroyed
- Each tab switch creates new instance
- Old instances not garbage collected
- Memory leak over time

**Fix Required:**
```javascript
let cytoscapeInstance = null;

function renderGraphVisualization(graphData) {
  // Destroy old instance first
  if (cytoscapeInstance) {
    cytoscapeInstance.destroy();
    cytoscapeInstance = null;
  }
  
  cytoscapeInstance = cytoscape({
    container: document.getElementById('graph-canvas'),
    elements: graphData,
    // ... options
  });
}

// Cleanup on modal close
function resetState() {
  if (cytoscapeInstance) {
    cytoscapeInstance.destroy();
    cytoscapeInstance = null;
  }
  
  // ... other cleanup
}
```

---

### P2-6: Inconsistent Error App Code Naming

**Location:** Multiple files

**Issue:**
- `PROD_400_VALIDATION` (products.php)
- `BINDING_409_CONFLICT` (product_api.php)
- `UOM_ID_DEPRECATED` (UoM service)
- `SEC_403_INVALID_ORIGIN` (SecurityService)

**Problem:**
- No consistent naming convention
- Prefix varies: `PROD_`, `BINDING_`, `UOM_`, `SEC_`
- HTTP code position varies: `PROD_400_`, `_409_`, `_ID_`
- Hard to grep for all errors

**Recommendation:**
```
Standard Format: {MODULE}_{HTTP_CODE}_{SPECIFIC_ERROR}

Examples:
- PROD_400_VALIDATION
- PROD_409_CONFLICT
- PROD_403_FORBIDDEN
- UOM_400_ID_DEPRECATED
- SEC_403_INVALID_ORIGIN
- GRAPH_400_NOT_PUBLISHED
```

**Fix Required:**
```javascript
// Centralized app_code registry
const APP_CODES = {
  // Product module
  PROD_400_VALIDATION: 'PROD_400_VALIDATION',
  PROD_409_CONFLICT: 'PROD_409_CONFLICT',
  PROD_403_FORBIDDEN: 'PROD_403_FORBIDDEN',
  
  // Graph binding module
  GRAPH_400_NOT_PUBLISHED: 'GRAPH_400_NOT_PUBLISHED',
  GRAPH_409_CONFLICT: 'GRAPH_409_CONFLICT',
  
  // UoM module
  UOM_400_DEPRECATED: 'UOM_400_DEPRECATED',
  
  // Security module
  SEC_403_INVALID_ORIGIN: 'SEC_403_INVALID_ORIGIN',
  SEC_403_CSRF: 'SEC_403_CSRF',
};

// Usage
if (appCode === APP_CODES.PROD_409_CONFLICT) {
  // handle conflict
}
```

---

### P2-7: No Bulk Operation Support

**Location:** Entire workspace module

**Issue:**
- User must open workspace for each product individually
- No bulk edit support (e.g., change 10 products to same category)
- No bulk asset upload
- No bulk publish

**Impact:**
- Poor UX for large catalogs
- Time-consuming operations
- Increased error rate

**Recommendation:**
- Add "Bulk Edit" mode in Phase 5+
- Not critical for Phase 4

---

## 🟢 LOW PRIORITY ISSUES (P3)

### P3-1: Missing Accessibility (A11y) Features

**Location:** Entire UI

**Issues:**
- No keyboard navigation
- No ARIA labels
- No screen reader support
- No focus management

**Fix Required:**
```html
<!-- Add ARIA labels -->
<button id="btnSaveGeneral" 
        class="btn btn-primary" 
        aria-label="Save product changes">
  <i class="fe fe-save me-1" aria-hidden="true"></i> Save
</button>

<!-- Add keyboard shortcuts -->
<div class="modal-header">
  <h5 class="modal-title">
    Product Workspace
    <small class="text-muted ms-2">(Ctrl+S to save, Esc to close)</small>
  </h5>
</div>
```

---

### P3-2: No Audit Trail Visualization

**Location:** Workspace UI

**Issue:**
- Product changes are logged (backend)
- No UI to view change history
- User can't see "who changed what when"

**Recommendation:**
- Add "History" tab in Phase 5+
- Show timeline of changes
- Link to revision system

---

### P3-3: No Offline Support

**Location:** Entire workspace

**Issue:**
- No Service Worker
- No offline fallback
- No "reconnecting" UI

**Recommendation:**
- Not critical for Phase 4
- Consider Progressive Web App (PWA) in future

---

### P3-4: Missing Analytics/Telemetry

**Location:** Entire workspace

**Issue:**
- No usage tracking
- No error analytics
- No performance monitoring

**Recommendation:**
```javascript
// Add basic telemetry
function trackEvent(category, action, label, value) {
  if (typeof gtag !== 'undefined') {
    gtag('event', action, {
      event_category: category,
      event_label: label,
      value: value
    });
  }
  
  // Also log to backend
  $.post('source/telemetry_api.php', {
    action: 'log_event',
    category,
    action,
    label,
    value,
    timestamp: Date.now()
  }).catch(() => {}); // Silent fail
}

// Usage
trackEvent('Workspace', 'Open', state.productId);
trackEvent('Workspace', 'Save', 'General', Date.now() - openTime);
trackEvent('Workspace', 'Error', appCode);
```

---

## 📊 Summary & Recommendations

### Immediate Action Required (Before Phase 4):

1. **P0-1: Add save operation lock** → 30 minutes
2. **P0-2: Add row_version to product table** → 2 hours
3. **P0-3: Fix XSS in error display** → 30 minutes
4. **P1-3: Fix readiness race condition** → 1 hour
5. **P1-4: Add asset upload validation** → 1 hour

**Total Effort:** ~5 hours

---

### Can Defer to Phase 5:

- P1-5: Session timeout warning (nice-to-have)
- P2-x: Performance optimizations
- P3-x: UX enhancements

---

### Security Posture:

✅ **STRONG:**
- Authentication present
- CSRF protection enabled
- Rate limiting active
- Input validation present

⚠️ **NEEDS IMPROVEMENT:**
- Optimistic locking incomplete
- XSS risk in error display
- Race conditions in async operations

---

### Quality Posture:

✅ **GOOD:**
- Error handling comprehensive
- Code documentation present
- Consistent patterns used

⚠️ **NEEDS IMPROVEMENT:**
- Frontend validation incomplete
- Request cancellation missing
- Memory management needs attention

---

## 🎯 Final Verdict

**Recommendation:** Fix P0 and P1-3, P1-4 issues **before Phase 4**.

**Rationale:**
- P0 issues are **security/data integrity risks**
- P1-3, P1-4 are **high probability bugs** in production
- Other issues can be addressed post-Phase 4

**Estimated Risk if Deployed As-Is:** **MEDIUM-HIGH**
- Data loss likely (P0-1, P0-2)
- XSS possible (P0-3)
- Race conditions probable (P1-3)

---

## ✅ Acceptance Criteria for Phase 4

Before proceeding to Phase 4, verify:

- [ ] P0-1: Save operation lock implemented and tested
- [ ] P0-2: product.row_version migration created and applied
- [ ] P0-3: XSS vulnerability fixed (escapeHtml used everywhere)
- [ ] P1-3: Readiness race condition fixed (request token pattern)
- [ ] P1-4: Asset upload validation added (file size, type)
- [ ] All 5 fixes tested manually
- [ ] No regressions in existing functionality
- [ ] Documentation updated

---

**Audit Completed:** 2026-01-08
**Auditor:** AI Development Agent
**Next Review:** After Phase 4 completion
