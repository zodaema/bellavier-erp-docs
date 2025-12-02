# 📋 API Standards Migration Plan (Phase 4-6)

**Version:** 1.0  
**Date:** November 8, 2025, 01:15 ICT  
**Purpose:** แผนการปรับปรุง API files ที่เหลือให้เป็นไปตามมาตรฐาน Enterprise (Phase 1-3)  
**Status:** 📋 **PLANNING**  
**Reference:** `docs/API_STRUCTURE_AUDIT.md` (v2.4 - Phase 1-3 Complete Edition)

---

## 📊 Executive Summary

| Metric | Value |
|--------|-------|
| **APIs Already Migrated** | ✅ **8 files** (100% compliance) |
| **APIs Pending Migration** | ⚠️ **10 files** (various compliance levels) |
| **Estimated Time** | **6-8 hours** (Phase 4-6) |
| **Risk Level** | 🟢 **LOW** (non-breaking changes) |
| **Priority** | 🟡 **MEDIUM** (improve consistency, not critical) |

---

## 📋 Inventory: APIs Pending Migration

### **Phase 1-3 Complete (8 files)** ✅

| API File | Status | Score |
|----------|--------|-------|
| `assignment_api.php` | ✅ Complete | 100% |
| `token_management_api.php` | ✅ Complete | 100% |
| `pwa_scan_api.php` | ✅ Complete | 100% |
| `hatthasilpa_jobs_api.php` | ✅ Complete | 100% |
| `team_api.php` | ✅ Complete | 100% |
| `dag_routing_api.php` | ✅ Complete | 100% |
| `assignment_plan_api.php` | ✅ Complete | 100% |
| `dag_token_api.php` | ✅ Complete | 100% |

### **Pending Migration (10 files)** ⚠️

| API File | Routing | Error Format | Try-Catch | Doc | Log | Score | Priority |
|----------|---------|--------------|-----------|-----|-----|-------|----------|
| `exceptions_api.php` | ✅ | ❌ | ⚠️ | ❌ | ❌ | **40%** | 🟡 Medium |
| `platform_tenant_owners_api.php` | ✅ | ❌ | ❌ | ❌ | ❌ | **20%** | 🟡 Medium |
| `tenant_users_api.php` | ✅ | ✅ | ❌ | ❌ | ❌ | **40%** | 🟡 Medium |
| `platform_dashboard_api.php` | ✅ | ❌ | ⚠️ | ❌ | ❌ | **30%** | 🟡 Medium |
| `platform_roles_api.php` | ✅ | ❌ | ❌ | ❌ | ❌ | **20%** | 🟡 Medium |
| `platform_migration_api.php` | ✅ | ❌ | ⚠️ | ❌ | ❌ | **30%** | 🟡 Medium |
| `platform_health_api.php` | ✅ | ❌ | ⚠️ | ❌ | ❌ | **30%** | 🟡 Medium |
| `hatthasilpa_job_ticket.php` | ✅ | ✅ | ❌ | ❌ | ❌ | **40%** | 🔴 High |
| `mo.php` | ✅ | ❌ | ❌ | ❌ | ❌ | **20%** | 🔴 High |
| `hatthasilpa_schedule.php` | ✅ | ⚠️ | ❌ | ❌ | ❌ | **30%** | 🔴 High |

**Legend:**
- ✅ = Meets standard
- ⚠️ = Partial (needs improvement)
- ❌ = Missing

**Priority Legend:**
- 🔴 High = Production-critical APIs (used daily)
- 🟡 Medium = Platform/admin APIs (less frequent)

---

## 🎯 Migration Phases

### **Phase 4: Production APIs** (2-3 hours) 🔴 **HIGH PRIORITY**

**Target:** APIs ที่ใช้ใน production workflow ทุกวัน

**Files:**
1. `hatthasilpa_job_ticket.php` - Job ticket CRUD (production-critical)
2. `mo.php` - Manufacturing Order operations (production-critical)
3. `hatthasilpa_schedule.php` - Production scheduling (production-critical)

**Tasks:**
- ✅ Convert error responses → `json_error()`/`json_success()` (if needed)
- ✅ Add top-level try-catch blocks
- ✅ Add comprehensive header documentation
- ✅ Add Correlation ID and AI Trace headers
- ✅ Standardize error logging format
- ✅ Remove duplicate `json_error()`/`json_success()` functions (if local)

**Estimated Time:** 2-3 hours  
**Risk:** 🟢 LOW (non-breaking changes)  
**Impact:** 🔴 HIGH (improves production API reliability)

---

### **Phase 5: Platform Admin APIs** (2-3 hours) 🟡 **MEDIUM PRIORITY**

**Target:** Platform administration APIs (less frequent usage)

**Files:**
1. `platform_tenant_owners_api.php` - Tenant owner management
2. `platform_roles_api.php` - Platform role management
3. `platform_dashboard_api.php` - Platform dashboard stats
4. `platform_migration_api.php` - Migration management
5. `platform_health_api.php` - Health check diagnostics

**Tasks:**
- ✅ Replace `http_response_code()` + `echo json_encode()` → `json_error()`/`json_success()`
- ✅ Add top-level try-catch blocks (if missing)
- ✅ Add comprehensive header documentation
- ✅ Add Correlation ID and AI Trace headers
- ✅ Standardize error logging format

**Estimated Time:** 2-3 hours  
**Risk:** 🟢 LOW (admin-only APIs)  
**Impact:** 🟡 MEDIUM (improves admin tool reliability)

---

### **Phase 6: Tenant Management APIs** (1-2 hours) 🟡 **MEDIUM PRIORITY**

**Target:** Tenant-level user and exception management

**Files:**
1. `tenant_users_api.php` - Tenant user management
2. `exceptions_api.php` - Production exceptions board

**Tasks:**
- ✅ Replace `echo json_encode()` → `json_error()`/`json_success()` (if needed)
- ✅ Add top-level try-catch blocks (if missing)
- ✅ Add comprehensive header documentation
- ✅ Add Correlation ID and AI Trace headers
- ✅ Standardize error logging format

**Estimated Time:** 1-2 hours  
**Risk:** 🟢 LOW (tenant-scoped APIs)  
**Impact:** 🟡 MEDIUM (improves tenant management reliability)

---

## 📋 Detailed File Assessment

### **Phase 4: Production APIs**

#### **1. `hatthasilpa_job_ticket.php`** 🔴 HIGH PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ✅ Uses `json_error()`/`json_success()` (global functions)
- ❌ No top-level try-catch
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Add comprehensive header documentation
2. Add top-level try-catch block
3. Add Correlation ID and AI Trace headers
4. Standardize error logging format

**Estimated Time:** 45 minutes

---

#### **2. `mo.php`** 🔴 HIGH PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `http_response_code()` + `echo json_encode()`
- ❌ No top-level try-catch
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Replace manual error responses → `json_error()`/`json_success()`
2. Add comprehensive header documentation
3. Add top-level try-catch block
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 45 minutes

---

#### **3. `hatthasilpa_schedule.php`** 🔴 HIGH PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ⚠️ Has local `json_error()`/`json_success()` functions (should use global)
- ❌ No top-level try-catch
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Remove local `json_error()`/`json_success()` functions (use global from `global_function.php`)
2. Add comprehensive header documentation
3. Add top-level try-catch block
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 45 minutes

---

### **Phase 5: Platform Admin APIs**

#### **4. `platform_tenant_owners_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `http_response_code()` + `echo json_encode()`
- ❌ No top-level try-catch
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Replace manual error responses → `json_error()`/`json_success()`
2. Add comprehensive header documentation
3. Add top-level try-catch block
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 30 minutes

---

#### **5. `platform_roles_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `http_response_code()` + `echo json_encode()`
- ❌ No top-level try-catch
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Replace manual error responses → `json_error()`/`json_success()`
2. Add comprehensive header documentation
3. Add top-level try-catch block
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 30 minutes

---

#### **6. `platform_dashboard_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `http_response_code()` + `echo json_encode()`
- ⚠️ Has try-catch but uses `Exception` instead of `\Throwable`
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Replace manual error responses → `json_error()`/`json_success()`
2. Update try-catch to use `\Throwable`
3. Add comprehensive header documentation
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 30 minutes

---

#### **7. `platform_migration_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `http_response_code()` + `echo json_encode()`
- ⚠️ Has try-catch but uses `Exception` instead of `\Throwable`
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Replace manual error responses → `json_error()`/`json_success()`
2. Update try-catch to use `\Throwable`
3. Add comprehensive header documentation
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 30 minutes

---

#### **8. `platform_health_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `http_response_code()` + `echo json_encode()`
- ⚠️ Has try-catch but uses `Exception` instead of `\Throwable`
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ⚠️ Has error logging but not standardized format

**Required Changes:**
1. Replace manual error responses → `json_error()`/`json_success()`
2. Update try-catch to use `\Throwable`
3. Add comprehensive header documentation
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 30 minutes

---

### **Phase 6: Tenant Management APIs**

#### **9. `tenant_users_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ✅ Uses `json_error()`/`json_success()` (global functions)
- ❌ No top-level try-catch
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Add comprehensive header documentation
2. Add top-level try-catch block
3. Add Correlation ID and AI Trace headers
4. Standardize error logging format

**Estimated Time:** 30 minutes

---

#### **10. `exceptions_api.php`** 🟡 MEDIUM PRIORITY

**Current Status:**
- ✅ Uses `switch ($action)`
- ❌ Uses `echo json_encode()` directly
- ⚠️ Has try-catch but not top-level (only around switch)
- ❌ No header documentation
- ❌ No Correlation ID/AI Trace headers
- ❌ No standardized error logging

**Required Changes:**
1. Replace `echo json_encode()` → `json_error()`/`json_success()`
2. Ensure top-level try-catch wraps entire switch
3. Add comprehensive header documentation
4. Add Correlation ID and AI Trace headers
5. Standardize error logging format

**Estimated Time:** 30 minutes

---

## 📊 Migration Summary

| Phase | Files | Priority | Estimated Time | Risk |
|-------|-------|----------|----------------|------|
| **Phase 4** | 3 files | 🔴 High | 2-3 hours | 🟢 Low |
| **Phase 5** | 5 files | 🟡 Medium | 2-3 hours | 🟢 Low |
| **Phase 6** | 2 files | 🟡 Medium | 1-2 hours | 🟢 Low |
| **Total** | **10 files** | - | **6-8 hours** | 🟢 Low |

---

## ✅ Success Criteria

**Phase 4-6 Complete เมื่อ:**
- ✅ All 10 APIs use `switch ($action)` routing
- ✅ All 10 APIs use `json_error()`/`json_success()` only
- ✅ All 10 APIs have top-level try-catch blocks
- ✅ All 10 APIs have comprehensive header documentation
- ✅ All 10 APIs have standardized error logging
- ✅ All 10 APIs include Correlation ID and AI Trace headers
- ✅ All 10 APIs pass compliance test (100% score)

---

## 🧪 Testing Plan

**After Each Phase:**
1. ✅ Syntax check: `php -l source/{file}.php`
2. ✅ Compliance test: `php tools/test_api_standards.php`
3. ✅ Browser testing: Test key endpoints manually
4. ✅ Error log verification: Check for standardized format

**After All Phases:**
1. ✅ Full compliance test: All 18 APIs (8 + 10) at 100%
2. ✅ Integration testing: Test critical workflows
3. ✅ Documentation update: Update API_STRUCTURE_AUDIT.md

---

## 📝 Notes

**Non-Breaking Changes:**
- All changes are additive (adding headers, documentation, error handling)
- No changes to API response format (still `{ok: true/false}`)
- No changes to business logic
- No database schema changes

**Backward Compatibility:**
- All APIs remain backward compatible
- Frontend code requires no changes
- Existing integrations continue to work

**Future Enhancements:**
- Phase 7: Request Validation Layer (RequestValidator helper)
- Phase 8: API Capability Manifest updates
- Phase 9: Additional security hardening

---

## 📚 References

- **API Standard Playbook:** `docs/API_STRUCTURE_AUDIT.md` (v2.4)
- **Compliance Test:** `tools/test_api_standards.php`
- **Global Functions:** `source/global_function.php` (json_error, json_success)
- **Standard Template:** See `docs/API_STRUCTURE_AUDIT.md` → Recommended Standard Template

---

**Last Updated:** November 8, 2025, 01:15 ICT  
**Status:** 📋 **READY FOR IMPLEMENTATION**

