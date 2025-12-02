# 📊 API Compliance Audit Report

**Date:** November 8, 2025  
**Purpose:** Identify API files that don't meet Enterprise API standards  
**Standard Reference:** `docs/API_STRUCTURE_AUDIT.md`

---

## ✅ Files with FULL Compliance (15 files)

These files have:
- ✅ Comprehensive header documentation
- ✅ Correlation ID & AI Trace headers
- ✅ Switch-case routing (not if-elseif)
- ✅ Top-level try-catch blocks
- ✅ json_error() / json_success() responses
- ✅ Standardized error logging

1. `system_log.php` ✅ (just fixed)
2. `assignment_api.php` ✅
3. `exceptions_api.php` ✅
4. `tenant_users_api.php` ✅
5. `platform_health_api.php` ✅
6. `platform_dashboard_api.php` ✅
7. `platform_roles_api.php` ✅
8. `platform_tenant_owners_api.php` ✅
9. `platform_migration_api.php` ✅
10. `dag_token_api.php` ✅
11. `hatthasilpa_jobs_api.php` ✅
12. `pwa_scan_api.php` ✅
13. `token_management_api.php` ✅
14. `mo.php` ✅
15. `hatthasilpa_schedule.php` ✅
16. `assignment_plan_api.php` ✅
17. `team_api.php` ✅
18. `dag_routing_api.php` ✅

---

## ⚠️ Files MISSING Standards (6 files)

### 1. `notifications.php` 🔴 **CRITICAL**

**Missing:**
- ❌ No header documentation
- ❌ No Correlation ID header
- ❌ No AI Trace header
- ❌ Uses `if ($action ===)` instead of switch-case
- ❌ No top-level try-catch
- ❌ Uses `echo json_encode()` instead of `json_error()`/`json_success()`

**Current Structure:**
```php
if ($action === 'table') {
    // ...
} else if ($action === 'mark_read') {
    // ...
}
```

**Required Changes:**
- Add comprehensive header docblock
- Add Correlation ID & AI Trace headers
- Convert to switch-case routing
- Wrap in top-level try-catch
- Replace `echo json_encode()` with `json_error()`/`json_success()`

---

### 2. `bom.php` 🔴 **CRITICAL**

**Missing:**
- ❌ No header documentation
- ❌ No Correlation ID header
- ❌ No AI Trace header
- ❌ No top-level try-catch
- ❌ Uses `echo json_encode()` instead of `json_error()`/`json_success()`

**Current Structure:**
```php
if (!$member) { 
    http_response_code(401); 
    echo json_encode(['ok'=>false,'error'=>'unauthorized']); 
    exit; 
}
```

**Required Changes:**
- Add comprehensive header docblock
- Add Correlation ID & AI Trace headers
- Wrap in top-level try-catch
- Replace manual `http_response_code()` + `echo json_encode()` with `json_error()`/`json_success()`

---

### 3. `dashboard.php` 🔴 **CRITICAL**

**Missing:**
- ❌ No header documentation
- ❌ No Correlation ID header
- ❌ No AI Trace header
- ❌ No top-level try-catch
- ❌ Uses `echo json_encode()` instead of `json_error()`/`json_success()`

**Required Changes:**
- Add comprehensive header docblock
- Add Correlation ID & AI Trace headers
- Wrap in top-level try-catch
- Replace `echo json_encode()` with `json_error()`/`json_success()`

---

### 4. `materials.php` 🔴 **CRITICAL**

**Missing:**
- ❌ No header documentation
- ❌ No Correlation ID header
- ❌ No AI Trace header
- ❌ No top-level try-catch
- ❌ Uses `echo json_encode()` instead of `json_error()`/`json_success()`

**Current Structure:**
```php
if (!$member) { 
    http_response_code(401); 
    echo json_encode(['ok'=>false,'error'=>'unauthorized']); 
    exit; 
}
```

**Required Changes:**
- Add comprehensive header docblock
- Add Correlation ID & AI Trace headers
- Wrap in top-level try-catch
- Replace manual responses with `json_error()`/`json_success()`

---

### 5. `work_centers.php` 🔴 **CRITICAL**

**Missing:**
- ❌ No header documentation
- ❌ No Correlation ID header
- ❌ No AI Trace header
- ❌ No top-level try-catch
- ❌ Uses `echo json_encode()` instead of `json_error()`/`json_success()`

**Current Structure:**
```php
if (!$member) { 
    http_response_code(401); 
    echo json_encode(['ok'=>false,'error'=>'unauthorized']); 
    exit; 
}
```

**Required Changes:**
- Add comprehensive header docblock
- Add Correlation ID & AI Trace headers
- Wrap in top-level try-catch
- Replace manual responses with `json_error()`/`json_success()`

---

### 6. `qc_rework.php` 🟡 **PARTIAL**

**Has:**
- ✅ Switch-case routing
- ✅ Uses `json_error()`/`json_success()`

**Missing:**
- ❌ No header documentation
- ❌ No Correlation ID header
- ❌ No AI Trace header
- ❌ No top-level try-catch

**Required Changes:**
- Add comprehensive header docblock
- Add Correlation ID & AI Trace headers
- Wrap in top-level try-catch

---

## 🔍 Files to Verify

### `hatthasilpa_job_ticket.php` 🟡 **NEEDS REVIEW**

**Has:**
- ✅ Comprehensive header documentation
- ✅ Correlation ID & AI Trace headers
- ✅ Switch-case routing (main structure)
- ✅ Top-level try-catch
- ✅ Uses `json_error()`/`json_success()`

**Potential Issues:**
- ⚠️ Has some `if ($action ===)` checks inside switch cases (for validation logic)
  - Line 308: `if ($action === 'create' && ...)`
  - Line 313: `if ($action === 'update' && ...)`
  - Line 325: `if ($action === 'create')`

**Note:** These are validation checks within switch cases, not routing logic. This is acceptable.

**Status:** ✅ **COMPLIANT** (internal validation checks are OK)

---

## 📋 Summary

| Status | Count | Files |
|--------|-------|-------|
| ✅ **FULLY COMPLIANT** | 18 | All `*_api.php` files + `mo.php`, `hatthasilpa_schedule.php`, `hatthasilpa_job_ticket.php`, `system_log.php` |
| 🔴 **CRITICAL - Missing All** | 5 | `notifications.php`, `bom.php`, `dashboard.php`, `materials.php`, `work_centers.php` |
| 🟡 **PARTIAL - Missing Some** | 1 | `qc_rework.php` |

**Total Files:** 24 API files  
**Compliant:** 18 (75%)  
**Non-Compliant:** 6 (25%)

---

## 🎯 Priority Order for Migration

### **Priority 1: Critical APIs (Production-facing)**
1. `bom.php` - BOM management (production critical)
2. `dashboard.php` - Dashboard metrics (high visibility)
3. `materials.php` - Material management (production critical)
4. `work_centers.php` - Work center management (production critical)

### **Priority 2: User-facing APIs**
5. `notifications.php` - User notifications (high usage)
6. `qc_rework.php` - QC rework workflow (complete missing parts)

---

## 📝 Migration Checklist (Per File)

For each non-compliant file, ensure:

- [ ] **Header Documentation**
  - [ ] Comprehensive docblock with Purpose, Features
  - [ ] @package, @version, @lifecycle, @tenant_scope, @permission
  - [ ] CRITICAL INVARIANTS section
  - [ ] Multi-tenant Notes section

- [ ] **Correlation ID & AI Trace**
  - [ ] `$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));`
  - [ ] `header('X-Correlation-Id: ' . $cid);`
  - [ ] AI Trace metadata array
  - [ ] `header('X-AI-Trace: ' . json_encode($aiTrace));`

- [ ] **Switch-Case Routing**
  - [ ] Convert all `if ($action ===)` to `switch ($action)`
  - [ ] Add `default:` case for unknown actions
  - [ ] Remove `elseif` chains

- [ ] **Top-Level Try-Catch**
  - [ ] Wrap entire switch block in `try { ... } catch (\Throwable $e) { ... }`
  - [ ] Standardized error logging: `[CID:xxx][File][User][Action] Message`
  - [ ] Conditional stack trace in dev mode
  - [ ] Use `json_error('Internal server error', 500)` in catch

- [ ] **Standardized Responses**
  - [ ] Replace `echo json_encode(['ok'=>false])` with `json_error()`
  - [ ] Replace `echo json_encode(['ok'=>true])` with `json_success()`
  - [ ] Replace `http_response_code() + echo json_encode()` with `json_error()`/`json_success()`

- [ ] **Error Logging**
  - [ ] Use standardized format: `[CID:xxx][File][User:ID][Action:xxx] Message`
  - [ ] Include stack trace in development mode
  - [ ] Log via LogHelper where applicable

---

## 🚀 Next Steps

1. **Phase 1:** Migrate Priority 1 files (bom.php, dashboard.php, materials.php, work_centers.php)
2. **Phase 2:** Migrate Priority 2 files (notifications.php, qc_rework.php)
3. **Verification:** Run compliance check script to verify 100% compliance
4. **Documentation:** Update API_STRUCTURE_AUDIT.md with completion status

---

**Last Updated:** November 8, 2025

