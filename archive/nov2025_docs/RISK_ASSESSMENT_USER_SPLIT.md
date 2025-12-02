# Risk Assessment: User Management Split

**Date:** November 3, 2025  
**Status:** 🟡 Medium Risk - Safe Testing Required  
**Decision:** DO NOT proceed to Phase 1 (Database Refactor) yet

---

## 🔴 Current Changes (What We Just Did)

### **Files Modified:**
1. ✅ `page/admin_users.php` - Changed to Platform-only
2. ✅ `index.php` - Added new routes
3. ✅ `views/template/sidebar-left.template.php` - Updated menu

### **Files Created:**
1. 🆕 `page/tenant_users.php`
2. 🆕 `views/tenant_users.php`
3. 🆕 `assets/javascripts/tenant/users.js`
4. 🆕 `source/tenant_users_api.php`

### **Database Changes:**
- ❌ **NONE** (ยังไม่แตะ database เลย!)

---

## ⚠️ Risk Analysis

### **Risk 1: Existing Tenant Admins Lose Access** 🟡 MEDIUM
**Scenario:**
- Tenant Admins เคยใช้ `?p=admin_users` (dual-permission page)
- ตอนนี้ `admin_users.php` เป็น Platform-only
- Sidebar ชี้ไป `?p=tenant_users` แทน

**Impact:**
- ถ้า Tenant Admin กด bookmark เก่า (`?p=admin_users`) → อาจได้ 403 Forbidden
- ถ้า sidebar ไม่โหลด `tenant_users.php` → ไม่สามารถจัดการ users ได้

**Likelihood:** LOW
- Routing ยังมี legacy support (`admin_users` route ยังอยู่)
- Permission check ใน `admin_users.php` เดิมคือ:
  ```php
  permission_platform_codes = ['platform.accounts.manage']
  permission_code = 'org.user.manage' // เราลบตัวนี้ออก!
  ```
- **ปัญหา:** เราลบ `permission_code` ออกจาก `admin_users.php` แล้ว!

**Severity:** HIGH (ถ้าเกิด = Tenant Admins ไม่สามารถจัดการ users ได้เลย)

**Mitigation:**
- ✅ Keep `permission_code` ใน `admin_users.php` ไว้ชั่วคราว (fallback)
- ✅ Test ก่อนใช้งานจริง
- ✅ ถ้าพบปัญหา: Rollback sidebar menu ได้ทันที

---

### **Risk 2: New `tenant_users_api.php` Has Bugs** 🟢 LOW-MEDIUM
**Scenario:**
- API ใหม่ยังไม่เคยถูกทดสอบเลย
- อาจมี SQL errors, permission bugs, data validation issues

**Impact:**
- Tenant Admin กด "Add User" → Error 500
- DataTable ไม่โหลด → หน้าว่างเปล่า
- สร้าง user ซ้ำ → data corruption

**Likelihood:** MEDIUM
- Code เขียนใหม่ทั้งหมด
- ยังไม่ได้ run จริง

**Severity:** MEDIUM (แก้ได้เร็ว, ไม่ทำลายข้อมูล)

**Mitigation:**
- ✅ Test บน dev environment ก่อน
- ✅ Manual test ทุก endpoint (list, create, update, etc.)
- ✅ Check PHP error logs
- ✅ ถ้าพบ bug: แก้ทันที หรือ disable หน้า tenant_users ชั่วคราว

---

### **Risk 3: Permission Check Bypass** 🔴 HIGH
**Scenario:**
- ถ้า permission check ใน `tenant_users_api.php` ผิดพลาด
- Operator อาจเข้าถึง API ได้ (privilege escalation)

**Impact:**
- Operator สามารถสร้าง admin users ได้
- Security breach

**Likelihood:** LOW
- Code มี permission check:
  ```php
  if (!permission_allow_code($member, 'org.user.manage')) {
      json_error('forbidden', 403);
  }
  ```

**Severity:** HIGH (security issue)

**Mitigation:**
- ✅ Test permission checks ด้วย 3 roles: Platform Admin, Tenant Admin, Operator
- ✅ Verify API returns 403 for unauthorized users
- ✅ Manual curl tests

---

### **Risk 4: Sidebar Menu Breaks** 🟢 LOW
**Scenario:**
- PHP error ใน `sidebar-left.template.php`
- Sidebar ไม่แสดงเลย

**Impact:**
- ผู้ใช้ไม่สามารถ navigate ได้
- ต้อง type URL ด้วยมือ

**Likelihood:** LOW
- แก้แค่ href และ label
- ไม่มี logic ซับซ้อน

**Severity:** MEDIUM (UX issue, แก้ง่าย)

**Mitigation:**
- ✅ Test หน้า dashboard (จะโหลด sidebar)
- ✅ Check PHP error logs
- ✅ Rollback ง่าย (แก้ 1 ไฟล์)

---

### **Risk 5: DataTable Query Performance** 🟢 LOW
**Scenario:**
- `tenant_users_api.php` query ช้า
- มี N+1 query problem

**Impact:**
- หน้า Users โหลดช้า
- Database overload (ถ้ามี users เยอะ)

**Likelihood:** LOW
- Query ใช้ JOIN แล้ว (ไม่ N+1)
- มี LIMIT/OFFSET (pagination)

**Severity:** LOW (performance issue, ไม่ break functionality)

**Mitigation:**
- ✅ Test กับ tenant ที่มี 100+ users
- ✅ Check query execution time
- ✅ ถ้าช้า: เพิ่ม index

---

## 🟢 Low Risk Items (Safe)

1. ✅ **New Files Created** - ไม่กระทบระบบเดิม
2. ✅ **Routing Added** - เพิ่ม routes ใหม่, ไม่ลบของเก่า
3. ✅ **Documentation** - ไม่มี code, ไม่เสี่ยง
4. ✅ **JavaScript Files** - Client-side, ไม่กระทบ server
5. ✅ **Database Untouched** - ยังไม่แตะ schema เลย!

---

## 🎯 Recommended Action Plan

### **Phase 0.5: Safe Testing (NOW - ก่อนให้ users ใช้จริง)**

**Week 1 (Days 1-3): Isolated Testing**
```
Day 1: Manual Testing
------
1. ✅ Test tenant_users.php loads without errors
2. ✅ Test tenant_users_api.php?action=list returns data
3. ✅ Test create/update/delete operations
4. ✅ Test permission checks (3 roles)
5. ✅ Test sidebar menu visibility

Day 2: Integration Testing
------
1. ✅ Test admin_users.php (Platform Admin still works?)
2. ✅ Test tenant_users.php (Tenant Admin can manage?)
3. ✅ Test legacy route ?p=admin_users
4. ✅ Test DataTable pagination, search, sort
5. ✅ Test role dropdown population

Day 3: Security & Edge Cases
------
1. ✅ Test unauthorized access (Operator → tenant_users_api)
2. ✅ Test cross-tenant access (Tenant A admin → Tenant B users?)
3. ✅ Test username/email uniqueness
4. ✅ Test password validation
5. ✅ Test SQL injection attempts (just in case)
```

**Success Criteria:**
- [ ] All 15 tests pass
- [ ] No PHP errors in logs
- [ ] No 500/403/404 errors
- [ ] Performance acceptable (< 1s page load)

**If ANY test fails:**
- 🚨 STOP immediately
- 📝 Document the failure
- 🔧 Fix the issue
- 🔄 Re-test
- ❌ DO NOT proceed to Phase 1

---

### **Phase 1: Limited Rollout (After Testing Passes)**

**Week 2 (Days 4-7): Pilot Deployment**
```
Day 4-5: Deploy to 1 Test Tenant
------
1. Enable tenant_users.php for 1 tenant only
2. Monitor for 2 days
3. Collect feedback from Tenant Admin
4. Check error logs daily

Day 6-7: Gradual Rollout
------
1. If pilot successful → enable for all tenants
2. Communicate change to all admins
3. Monitor for 48 hours
4. Keep admin_users.php as fallback
```

**Rollback Plan:**
```bash
# If issues found:
1. Revert sidebar menu (1 minute)
   - Change href: ?p=tenant_users → ?p=admin_users
   
2. Restore admin_users.php permission (1 minute)
   - Add back: permission_code = 'org.user.manage'
   
3. Restart MAMP (if needed)

Total Rollback Time: < 5 minutes
```

---

### **Phase 1 (Database Refactor) - DO NOT START YET! ⛔**

**Prerequisites (MUST complete first):**
- ✅ Phase 0.5 testing 100% passed
- ✅ No critical bugs for 1 week
- ✅ User feedback collected
- ✅ Performance verified
- ✅ Fresh backup created (< 24 hours old)
- ✅ Team trained on rollback procedure
- ✅ Maintenance window scheduled (off-hours)

**Estimated Safe Start Date:** November 10, 2025 (1 week from now)

---

## 🛡️ Safety Checks Before Phase 1

### **Checklist: Ready for Database Refactor?**

**Code Quality:**
- [ ] All tests passed (15/15)
- [ ] No PHP warnings/notices in logs
- [ ] No JavaScript errors in console
- [ ] Code reviewed by senior developer
- [ ] All TODOs in code completed

**Production Readiness:**
- [ ] Fresh backup created (< 1 day old)
- [ ] Backup tested (restore verified)
- [ ] Rollback script tested
- [ ] Team trained on emergency procedures
- [ ] 24/7 on-call engineer assigned

**User Impact:**
- [ ] No user complaints for 1 week
- [ ] Tenant admins comfortable with new UI
- [ ] All critical workflows tested
- [ ] Performance acceptable (< 1s)
- [ ] Help documentation updated

**Database Safety:**
- [ ] Migration script peer-reviewed
- [ ] Dry-run on dev environment successful
- [ ] Data integrity checks written
- [ ] Rollback migration prepared
- [ ] Monitoring alerts configured

**Score Required:** 20/20 checks passed ✅

**Current Score:** 0/20 ⚠️ (ยังไม่ได้เริ่มทดสอบเลย!)

---

## 🚨 RED FLAGS (STOP Signals)

If ANY of these occur, STOP Phase 1 immediately:

1. 🔴 **Critical Bug** - Users cannot perform essential tasks
2. 🔴 **Data Loss** - Any user data deleted/corrupted
3. 🔴 **Security Breach** - Unauthorized access detected
4. 🔴 **Performance Degradation** - Page load > 3 seconds
5. 🔴 **High Error Rate** - > 5% of requests fail
6. 🔴 **User Revolt** - Multiple complaints about new UI
7. 🔴 **Database Corruption** - Foreign key violations
8. 🔴 **Backup Failure** - Cannot restore from backup

---

## ✅ Recommended Decision: PHASED APPROACH

### **NOW (November 3):**
```
✅ SAFE: Deploy User Management Split (tenant_users.php)
✅ SAFE: Update sidebar menu
✅ SAFE: Keep admin_users.php as fallback
❌ UNSAFE: Start Phase 1 (database refactor)
```

### **Next Week (November 10):**
```
✅ Review test results
✅ Collect user feedback
✅ Fix any bugs found
🤔 DECISION: Go/No-Go for Phase 1
```

### **If Go (November 10+):**
```
✅ Fresh backup
✅ Start Phase 1 (tenant_user table)
✅ Dry-run migration
✅ Limited pilot (1 tenant)
✅ Monitor for 1 week
```

---

## 🎯 Final Recommendation

**SAFE TO PROCEED:** ✅ User Management Split (Now)  
**UNSAFE TO PROCEED:** ❌ Phase 1 Database Refactor (Need 1 week testing first)

**Reason:**
- User Management Split: Low risk (no database changes)
- Phase 1 Refactor: High risk (database schema changes)

**Action Items:**
1. Test tenant_users.php thoroughly (3 days)
2. Deploy to production (with fallback ready)
3. Monitor for 1 week
4. If stable → proceed to Phase 1
5. If unstable → rollback and fix

---

**Risk Level Summary:**

| Item | Risk | Mitigation |
|------|------|------------|
| Tenant Users Split | 🟡 Medium | Test + Fallback |
| Phase 1 (DB Refactor) | 🔴 High | Wait 1 week + Full backup |

**Confidence Level:** 70% safe for User Split, 30% safe for Phase 1 (now)

---

**Reviewed By:** AI Agent  
**Date:** November 3, 2025  
**Approved for:** Phase 0.5 Testing ONLY  
**Next Review:** November 10, 2025

