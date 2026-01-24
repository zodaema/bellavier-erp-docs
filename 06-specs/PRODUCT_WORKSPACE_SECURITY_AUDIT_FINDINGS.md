# Product Workspace: Security & Architecture Audit Findings

**Date:** 2026-01-07  
**Auditor:** CTO + AI Agent  
**Scope:** Product Workspace Modal vs Legacy Modal System  
**Status:** 🔴 CRITICAL ISSUES FOUND

---

## 🎯 Executive Summary

การ audit เปรียบเทียบระหว่าง **Product Workspace Modal** (ใหม่) กับ **Legacy Modal System** (เก่า) พบ **ความเสี่ยงเชิงระบบ 4 จุดสำคัญ** ที่ต้องแก้ไขก่อน Production:

| # | Issue | Severity | Impact |
|---|-------|----------|--------|
| 1 | API Endpoint Divergence | 🔴 Critical | Business logic แยกทาง |
| 2 | Missing Optimistic Locking | 🔴 Critical | Data integrity risk |
| 3 | Inconsistent Error Handling | 🟡 Medium | Support cost + UX |
| 4 | Missing CSRF Protection | 🟠 High | Security vulnerability |

---

## 📊 Detailed Findings

### 🔴 Finding 1: API Endpoint Divergence (Critical)

**Problem:** Workspace และ Legacy ใช้ API คนละตัวสำหรับ Graph Binding

| System | Endpoint | File |
|--------|----------|------|
| **Legacy Modal** | `product_api.php?action=bind_routing` | `product_graph_binding.js:1582` |
| **Workspace Modal** | `products.php?action=update_graph_binding` | `product_workspace.js:2152` |

**Evidence:**

```javascript
// Legacy (product_graph_binding.js:1582)
const formData = {
  action: 'bind_routing',
  id_product: currentProductId,
  id_graph: graphId,
  graph_version_id: parseInt(versionId, 10)
};
$.post(PRODUCT_API, formData, ...); // PRODUCT_API = product_api.php

// Workspace (product_workspace.js:2152)
const resp = await $.post(CONFIG.endpoint, {
  action: 'update_graph_binding',
  id_product: state.productId,
  id_graph: selectedGraphId,
  graph_version_pin: selectedVersion
}); // CONFIG.endpoint = products.php
```

**Risk Analysis:**

1. **Business Logic Drift**
   - Legacy มี validation: `DAG_BINDING_403_DRAFT_NOT_ALLOWED` (line 1595)
   - Workspace อาจไม่มี validation เดียวกัน
   - Future: การเพิ่ม rule ใหม่ต้องแก้ 2 ที่

2. **Audit Trail Inconsistency**
   - Log format อาจต่างกัน
   - Troubleshooting ยาก

3. **Cache/Event Handling**
   - ถ้ามี cache invalidation หรือ event trigger อาจไม่ sync

**Recommendation:** 🎯 **Priority 1**

Unify to single canonical endpoint: `product_api.php?action=bind_routing`

---

### 🔴 Finding 2: Missing Optimistic Locking (Critical)

**Problem:** Workspace ไม่มี `row_version` check สำหรับ concurrent updates

**Evidence:**

```javascript
// Legacy (product_graph_binding.js) - HAS version check
// (Implied from backend validation)

// Workspace (product_workspace.js:2152) - NO version check
const resp = await $.post(CONFIG.endpoint, {
  action: 'update_graph_binding',
  id_product: state.productId,
  id_graph: selectedGraphId,
  graph_version_pin: selectedVersion
  // ❌ Missing: row_version or binding_version
});
```

**Risk Scenario:**

```
Time  User A                    User B                    Database
────────────────────────────────────────────────────────────────────
T0    Load binding (Graph X)    Load binding (Graph X)    binding_id=1, id_graph=X
T1    Change to Graph Y         -                         -
T2    -                         Change to Graph Z         -
T3    Save (Graph Y)            -                         binding_id=1, id_graph=Y ✅
T4    -                         Save (Graph Z)            binding_id=1, id_graph=Z ✅
                                                          ❌ User A's change LOST!
```

**Impact:**

- Graph binding เป็น **critical state** (กระทบ production flow)
- Silent data loss = ไม่มี error แจ้งเตือน
- User A คิดว่า save Graph Y แล้ว แต่จริง ๆ เป็น Graph Z

**Current Schema:**

```sql
-- product_graph_binding table (checked via grep)
CREATE TABLE product_graph_binding (
  id_binding INT PRIMARY KEY,
  id_product INT,
  id_graph INT,
  graph_version_pin INT NULL,
  is_active TINYINT DEFAULT 1,
  created_at DATETIME,
  updated_at DATETIME
  -- ❌ NO row_version column
);
```

**Recommendation:** 🎯 **Priority 1**

Add `row_version` to `product_graph_binding` table + implement optimistic locking

---

### 🟡 Finding 3: Inconsistent Error Handling (Medium)

**Problem:** Legacy มี app_code mapping แต่ Workspace throw generic error

**Evidence:**

```javascript
// Legacy (product_graph_binding.js:1595-1602) - HAS app_code mapping
if (resp?.app_code === 'DAG_BINDING_403_DRAFT_NOT_ALLOWED') {
  notifyError(t('product_graph.draft_not_allowed', 
    'Draft versions cannot be bound to products. Please select a published version.'));
} else if (resp?.meta?.errors && resp.meta.errors.length > 0) {
  const errorMsg = resp.meta.errors.join('; ');
  notifyError(errorMsg);
} else {
  notifyError(resp?.error || t('product_graph.save_error', 'Failed to save binding'));
}

// Workspace (product_workspace.js) - NO app_code mapping
// (Checked: no app_code handling found in handleConfirmGraphPicker)
```

**Impact:**

1. **User Experience**
   - Legacy: "Draft versions cannot be bound" (ชัดเจน)
   - Workspace: "Unknown error" (งง)

2. **Support Cost**
   - User ติดต่อ support บ่อยขึ้น
   - Support ต้อง debug ให้ทุกครั้ง

3. **Developer Experience**
   - ไม่มี app_code = debug ยาก
   - ไม่รู้ว่า error มาจาก validation ไหน

**Recommendation:** 🎯 **Priority 2**

Copy app_code mapping from Legacy to Workspace

---

### 🟠 Finding 4: Missing CSRF Protection (High)

**Problem:** POST requests ใช้ cookie-based auth แต่ไม่มี CSRF token

**Evidence:**

```javascript
// Both Legacy and Workspace - NO CSRF token
$.post(endpoint, {
  action: 'bind_routing', // or 'update_graph_binding'
  id_product: productId,
  id_graph: graphId
  // ❌ Missing: csrf_token
});
```

**Attack Scenario:**

```html
<!-- Attacker's website: evil.com -->
<form action="https://erp.bellavier.com/source/product_api.php" method="POST">
  <input type="hidden" name="action" value="bind_routing">
  <input type="hidden" name="id_product" value="123">
  <input type="hidden" name="id_graph" value="999"> <!-- Malicious graph -->
  <input type="hidden" name="graph_version_id" value="1">
</form>
<script>document.forms[0].submit();</script>
```

**If user is logged in to ERP:**
1. Browser auto-sends session cookie
2. Request succeeds (no CSRF check)
3. Product 123 now bound to malicious graph 999

**Impact:**

- Backoffice system = high risk (users stay logged in)
- State-changing operations = must protect
- Compliance risk (if applicable)

**Recommendation:** 🎯 **Priority 3**

Implement CSRF protection (minimum: Origin/Referer check)

---

## 🔍 Additional Findings (Low Priority)

### Finding 5: Potential ID Duplication

**Status:** ✅ Already addressed in Phase 3

**Evidence:**

```html
<!-- Legacy (views/products.php:329) -->
<select id="graph-version-select" class="form-select">

<!-- Workspace (tab_production.php:178) -->
<select id="workspace-graph-version-select" class="form-select">
```

**Resolution:** Workspace uses prefixed IDs (`workspace-*`) to avoid conflicts ✅

---

### Finding 6: Structure Tab Not Disabled

**Status:** ⚠️ Needs verification

**Check:** Does Structure tab actually disable when production line = Hatthasilpa?

```bash
# Checked: No "disabled" attribute found in tab_structure.php
grep -i "disabled" source/components/product_workspace/tab_structure.php
# Result: No matches found
```

**Expected Behavior:**
- Hatthasilpa products: Structure tab should be **read-only** or **hidden**
- Classic products: Structure tab should be **editable**

**Recommendation:** 🎯 **Priority 4**

Verify and implement Structure tab disable logic if missing

---

## 📋 Remediation Plan

### Job A: Backend Security (Critical)

**Goal:** Add optimistic locking to prevent concurrent update conflicts

**Tasks:**

1. **Migration: Add row_version to product_graph_binding**
   ```sql
   ALTER TABLE product_graph_binding 
   ADD COLUMN row_version INT NOT NULL DEFAULT 1;
   ```

2. **Update bind_routing handler**
   ```php
   // Check row_version
   if ($existingBinding && $rowVersion !== null) {
       if ($existingBinding['row_version'] != $rowVersion) {
           json_error(
               translate('binding.error.conflict', 'Binding was modified by another user'),
               409,
               ['app_code' => 'BINDING_409_CONFLICT']
           );
       }
   }
   
   // Update with version bump
   UPDATE product_graph_binding 
   SET id_graph = ?, 
       graph_version_pin = ?,
       row_version = row_version + 1,
       updated_at = NOW()
   WHERE id_binding = ? AND row_version = ?
   ```

3. **Return new row_version in response**
   ```php
   json_success([
       'binding' => [
           'id_binding' => $idBinding,
           'row_version' => $newRowVersion, // ← Add this
           // ... other fields
       ]
   ]);
   ```

4. **Add tests**
   - Test concurrent update (should return 409)
   - Test normal update (should succeed)

**Estimated Time:** 2 hours

---

### Job B: API Unification (Critical)

**Goal:** Force both Legacy and Workspace to use same endpoint

**Tasks:**

1. **Make products.php?action=update_graph_binding a wrapper**
   ```php
   case 'update_graph_binding':
       // Validate input
       $idProduct = (int)($_POST['id_product'] ?? 0);
       $idGraph = (int)($_POST['id_graph'] ?? 0);
       $graphVersionPin = $_POST['graph_version_pin'] ?? null;
       $rowVersion = isset($_POST['row_version']) ? (int)$_POST['row_version'] : null;
       
       // Convert graph_version_pin to graph_version_id if needed
       $graphVersionId = null;
       if ($graphVersionPin !== null) {
           // Resolve version ID from pin
           $version = db_fetch_one($tenantDb, 
               "SELECT id_version FROM routing_graph_version 
                WHERE id_graph = ? AND version = ?", 
               [$idGraph, $graphVersionPin]);
           $graphVersionId = $version ? $version['id_version'] : null;
       }
       
       // Call canonical handler (from product_api.php)
       require_once __DIR__ . '/product_api_handlers.php';
       handleBindRouting($db, $member, [
           'id_product' => $idProduct,
           'id_graph' => $idGraph,
           'graph_version_id' => $graphVersionId,
           'row_version' => $rowVersion
       ]);
       break;
   ```

2. **Update Workspace JS to send row_version**
   ```javascript
   // product_workspace.js
   const resp = await $.post(CONFIG.endpoint, {
       action: 'update_graph_binding',
       id_product: state.productId,
       id_graph: selectedGraphId,
       graph_version_pin: selectedVersion,
       row_version: productionState.currentBinding?.row_version || null // ← Add this
   });
   ```

3. **Update state after successful save**
   ```javascript
   if (resp?.ok) {
       // Update local state with new row_version
       productionState.currentBinding = resp.binding;
       // ...
   }
   ```

**Estimated Time:** 1.5 hours

---

### Job C: Error Handling Consistency (Medium)

**Goal:** Add app_code mapping to Workspace

**Tasks:**

1. **Add app_code handler to Workspace**
   ```javascript
   // product_workspace.js - handleConfirmGraphPicker
   if (resp?.ok) {
       // ... success handling
   } else {
       // Map app_code to user-friendly messages
       const errorMessages = {
           'DAG_BINDING_403_DRAFT_NOT_ALLOWED': t('product_graph.draft_not_allowed', 
               'Draft versions cannot be bound to products. Please select a published version.'),
           'GRAPH_400_NO_STABLE': t('product_graph.no_stable_version', 
               'Selected graph has no stable version'),
           'PROD_400_BINDING_VALID': t('product_graph.binding_invalid', 
               'Invalid binding configuration'),
           'BINDING_409_CONFLICT': t('product_graph.binding_conflict', 
               'Binding was modified by another user. Please reload and try again.')
       };
       
       const message = errorMessages[resp?.app_code] || resp?.error || 
           t('workspace.production.save_error', 'Failed to save graph binding');
       
       await Swal.fire({
           title: t('common.error', 'Error'),
           text: message,
           icon: 'error'
       });
   }
   ```

2. **Add translations**
   ```php
   // lang/th.php
   'product_graph.binding_conflict' => 'การผูก Graph ถูกแก้ไขโดยผู้ใช้อื่น กรุณาโหลดใหม่และลองอีกครั้ง',
   
   // lang/en.php
   'product_graph.binding_conflict' => 'Binding was modified by another user. Please reload and try again.',
   ```

**Estimated Time:** 1 hour

---

### Job D: CSRF Protection (High)

**Goal:** Implement basic CSRF protection

**Tasks:**

1. **Add Origin/Referer check (minimum)**
   ```php
   // source/security_helpers.php
   function check_csrf_origin(): bool {
       $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
       $referer = $_SERVER['HTTP_REFERER'] ?? '';
       $host = $_SERVER['HTTP_HOST'] ?? '';
       
       // Check if request comes from same domain
       if ($origin && parse_url($origin, PHP_URL_HOST) === $host) {
           return true;
       }
       
       if ($referer && parse_url($referer, PHP_URL_HOST) === $host) {
           return true;
       }
       
       return false;
   }
   
   // In API files (product_api.php, products.php)
   if ($_SERVER['REQUEST_METHOD'] === 'POST') {
       if (!check_csrf_origin()) {
           json_error('Invalid request origin', 403, ['app_code' => 'CSRF_403_INVALID_ORIGIN']);
       }
   }
   ```

2. **Future: Add CSRF token (Phase 4)**
   - Generate token on login
   - Include in all forms
   - Validate on POST

**Estimated Time:** 30 minutes (Origin check only)

---

## 📊 Priority Matrix

| Job | Priority | Risk Mitigation | Estimated Time |
|-----|----------|-----------------|----------------|
| **Job A** (Optimistic Locking) | 🔴 P1 | Data integrity | 2 hours |
| **Job B** (API Unification) | 🔴 P1 | Logic consistency | 1.5 hours |
| **Job C** (Error Handling) | 🟡 P2 | UX + Support cost | 1 hour |
| **Job D** (CSRF Protection) | 🟠 P3 | Security | 30 minutes |
| **Total** | | | **5 hours** |

---

## ✅ Acceptance Criteria

### Job A (Optimistic Locking)

- [ ] Migration adds `row_version` column to `product_graph_binding`
- [ ] Backend checks `row_version` on UPDATE
- [ ] Backend returns 409 + `BINDING_409_CONFLICT` on conflict
- [ ] Backend returns new `row_version` in success response
- [ ] Tests: Concurrent update returns 409
- [ ] Tests: Normal update succeeds with new `row_version`

### Job B (API Unification)

- [ ] `products.php?action=update_graph_binding` calls same handler as `product_api.php?action=bind_routing`
- [ ] Workspace JS sends `row_version` in request
- [ ] Workspace JS updates local state with new `row_version` after save
- [ ] Legacy modal still works (no regression)
- [ ] Both UIs enforce same validation rules

### Job C (Error Handling)

- [ ] Workspace maps all app_codes from Legacy
- [ ] User sees friendly error messages (not "Unknown error")
- [ ] Translations added for all error messages
- [ ] Console logs app_code for debugging

### Job D (CSRF Protection)

- [ ] Origin/Referer check implemented
- [ ] POST requests from external domains return 403
- [ ] POST requests from same domain succeed
- [ ] Error message: "Invalid request origin"

---

## 🚨 Rollout Strategy

### Phase 1: Backend Security (Week 1)
- Deploy Job A (Optimistic Locking)
- Monitor for 409 errors (indicates concurrent updates)
- Fix any issues before proceeding

### Phase 2: API Unification (Week 1)
- Deploy Job B (API Unification)
- Test both Legacy and Workspace
- Verify no regression

### Phase 3: UX Improvements (Week 2)
- Deploy Job C (Error Handling)
- Deploy Job D (CSRF Protection)
- User acceptance testing

---

## 📞 Stakeholder Sign-Off Required

| Role | Approval | Date |
|------|----------|------|
| CTO | ⏳ Pending | - |
| Lead Developer | ⏳ Pending | - |
| Security Team | ⏳ Pending | - |

---

**Report Status:** 🔴 **CRITICAL ISSUES IDENTIFIED**  
**Action Required:** Implement Jobs A-D before Production deployment  
**Next Review:** After Job A completion

---

*Report Generated: 2026-01-07*  
*Auditor: CTO + AI Agent*  
*Next Update: After remediation*

