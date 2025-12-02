# Testing User Management Split - Platform vs. Tenant

**Created:** November 3, 2025  
**Purpose:** Verify correct separation of Platform Accounts and Tenant Users

---

## 🧪 Test Scenarios

### **Test 1: Platform Admin Access**

**Login as:** admin (Platform Admin)

**Expected Results:**
- ✅ Can access `?p=platform_accounts` (Platform Accounts page)
- ✅ Sidebar shows "Platform Console → Platform Accounts"
- ✅ Can see/manage ALL accounts across all tenants
- ❌ Should NOT see "Administration → Users" (tenant-level)
- ❓ Can access `?p=tenant_users`? (Should be denied - no org.user.manage)

**Verification Steps:**
```bash
1. Login as admin (username: admin, password: iydgtv)
2. Navigate to Platform Console → Platform Accounts
3. Verify: Can see users from all tenants
4. Try to access: ?p=tenant_users
5. Expected: 403 Forbidden or permission denied
```

---

### **Test 2: Tenant Admin Access**

**Login as:** Tenant Admin (e.g., supervisor or admin role in tenant)

**Expected Results:**
- ✅ Can access `?p=tenant_users` (Tenant Users page)
- ✅ Sidebar shows "Administration → Users"
- ✅ Can see/manage ONLY users in their organization
- ❌ Should NOT see "Platform Console → Platform Accounts"
- ❓ Can access `?p=platform_accounts`? (Should be denied - no platform.accounts.manage)

**Verification Steps:**
```bash
1. Login as tenant admin (need to check existing accounts)
2. Navigate to Administration → Users
3. Verify: Can only see users in current tenant
4. Try to access: ?p=platform_accounts
5. Expected: 403 Forbidden or permission denied
```

---

### **Test 3: Regular Operator Access**

**Login as:** Operator (no admin permissions)

**Expected Results:**
- ❌ Should NOT see "Platform Console" in sidebar
- ❌ Should NOT see "Administration → Users" in sidebar
- ❌ Cannot access `?p=platform_accounts` (403)
- ❌ Cannot access `?p=tenant_users` (403)

**Verification Steps:**
```bash
1. Login as operator (create test account if needed)
2. Check sidebar: No "Platform Console" section
3. Check sidebar: No "Users" menu item in Administration
4. Try URL: ?p=platform_accounts → 403 Forbidden
5. Try URL: ?p=tenant_users → 403 Forbidden
```

---

### **Test 4: Create User (Platform Admin)**

**Goal:** Create a Platform Owner account

**Steps:**
1. Login as Platform Admin
2. Go to Platform Console → Platform Accounts
3. Click "Add" button
4. Fill form:
   - Username: `platform_test_user`
   - Email: `platform@test.com`
   - Name: `Platform Test User`
   - Password: `Test123456`
   - Role: (Platform role - TBD)
5. Save

**Expected:**
- ✅ User created in `bgerp.account`
- ✅ User has platform access
- ✅ User can access Platform Console

---

### **Test 5: Create User (Tenant Admin)**

**Goal:** Create a Tenant User account

**Steps:**
1. Login as Tenant Admin
2. Go to Administration → Users
3. Click "Add User" button
4. Fill form:
   - Username: `tenant_test_operator`
   - Email: `operator@test.com`
   - Name: `Test Operator`
   - Password: `Test123456`
   - Role: `Operator` (from tenant_role dropdown)
5. Save

**Expected:**
- ✅ User created in `bgerp.account` (currently - will migrate later)
- ✅ User added to `account_org` with current org
- ✅ User can login to tenant
- ❌ User CANNOT access Platform Console

---

### **Test 6: DataTable Filtering (Tenant Users)**

**Goal:** Verify users are filtered by organization

**Steps:**
1. Login as Tenant Admin for Org A
2. Go to Administration → Users
3. Note user count
4. Logout, login as Tenant Admin for Org B
5. Go to Administration → Users
6. Note user count

**Expected:**
- ✅ Org A admin sees only Org A users
- ✅ Org B admin sees only Org B users
- ✅ No overlap between organizations
- ✅ User counts are different

---

### **Test 7: API Permission Check**

**Goal:** Verify API endpoints enforce permissions

**Test API:** `source/tenant_users_api.php?action=list`

**Scenario A:** Tenant Admin
```bash
curl -X POST 'http://localhost:8888/bellavier-group-erp/source/tenant_users_api.php' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Cookie: PHPSESSID=xxx' \
  -d 'action=list'
  
Expected: {"ok": true, "data": [...]}
```

**Scenario B:** Operator (no permission)
```bash
curl -X POST 'http://localhost:8888/bellavier-group-erp/source/tenant_users_api.php' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Cookie: PHPSESSID=yyy' \
  -d 'action=list'
  
Expected: {"ok": false, "error": "forbidden - tenant admin permission required"}
```

---

### **Test 8: Sidebar Menu Visibility**

**Goal:** Verify correct menu items show for each role

**Matrix:**

| Role | Platform Console | Platform Accounts | Administration | Tenant Users |
|------|------------------|-------------------|----------------|--------------|
| Platform Admin | ✅ Visible | ✅ Visible | ❌ Hidden | ❌ Hidden |
| Tenant Admin | ❌ Hidden | ❌ Hidden | ✅ Visible | ✅ Visible |
| Operator | ❌ Hidden | ❌ Hidden | ❌ Hidden | ❌ Hidden |

---

### **Test 9: Legacy Route Support**

**Goal:** Verify old `admin_users` route still works

**Steps:**
1. Login as Platform Admin
2. Navigate to: `?p=admin_users` (old route)
3. Expected: Redirects to Platform Accounts page
4. Verify: Same functionality as `?p=platform_accounts`

---

### **Test 10: Role Dropdown Population**

**Goal:** Verify tenant_users.php loads correct roles

**Steps:**
1. Login as Tenant Admin
2. Go to Administration → Users
3. Click "Add User"
4. Check "Role" dropdown

**Expected:**
- ✅ Shows roles from `tenant_role` table:
  - admin
  - supervisor
  - operator
  - qc_inspector
  - viewer
- ❌ Does NOT show platform roles

---

## 📊 Test Results Log

| Test # | Date | Tester | Result | Notes |
|--------|------|--------|--------|-------|
| 1 | TBD | - | ⏳ Pending | Platform Admin access |
| 2 | TBD | - | ⏳ Pending | Tenant Admin access |
| 3 | TBD | - | ⏳ Pending | Operator restrictions |
| 4 | TBD | - | ⏳ Pending | Create Platform Owner |
| 5 | TBD | - | ⏳ Pending | Create Tenant User |
| 6 | TBD | - | ⏳ Pending | DataTable filtering |
| 7 | TBD | - | ⏳ Pending | API permission check |
| 8 | TBD | - | ⏳ Pending | Sidebar visibility |
| 9 | TBD | - | ⏳ Pending | Legacy route support |
| 10 | TBD | - | ⏳ Pending | Role dropdown |

---

## 🐛 Issues Found

| Issue # | Test | Description | Severity | Status |
|---------|------|-------------|----------|--------|
| (none yet) | - | - | - | - |

---

## ✅ Sign-Off

- [ ] All tests passed
- [ ] No critical issues found
- [ ] Permission model verified
- [ ] Ready for Refactor Phase 1

**Tested By:** _______________  
**Date:** _______________  
**Approved By:** _______________  
**Date:** _______________  

