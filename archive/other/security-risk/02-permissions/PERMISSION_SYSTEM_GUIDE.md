# Permission System Guide

**Last Updated:** November 3, 2025

## 🎯 **Overview**

Bellavier ERP ใช้ระบบ multi-tenant permission ที่ซับซ้อน โดยแบ่งเป็น:
- **Core DB (`bgerp`):** Platform-level permissions
- **Tenant DB (`bgerp_t_xxx`):** Organization-specific permissions

---

## ⚠️ **สำคัญ: ใช้ Permissions ที่มีอยู่แล้วให้มากที่สุด!**

**หลักการ:**
- ❌ **อย่า**สร้าง permission ใหม่ถ้าไม่จำเป็น
- ✅ **ใช้** permission ที่มีอยู่แล้วที่ครอบคลุมฟีเจอร์ได้
- ✅ **รวม** features ที่เกี่ยวข้องกันให้ใช้ permission เดียวกัน

**ตัวอย่าง:**
```php
// ❌ ไม่แนะนำ: สร้าง permission ใหม่
$page_detail['permission_code'] = 'atelier.work.queue.view'; // ต้อง maintain ใน 2 DBs!

// ✅ แนะนำ: ใช้ permission ที่มีอยู่
$page_detail['permission_code'] = 'atelier.job.ticket'; // Work Queue เป็นส่วนหนึ่งของ Job Ticket Management
```

---

## 🏗️ **สถาปัตยกรรม Multi-Tenant Permission**

### **1. Core DB (`bgerp`):**
```sql
permission (id_permission, code, description)
account_group (id_group, group_name)  -- ⚠️ Will be removed Nov 4, 2025
permission_allow (id_group, id_permission, allow)
```

**ใช้สำหรับ:** Platform admin, cross-tenant permissions (legacy system)

**⚠️ Schema Change (November 4, 2025):**
- `account_group` table will be removed
- `account_org.id_group` → `account_org.role_code` (VARCHAR)
- Owner bypass check will use `role_code = 'owner'` (no JOIN needed)

### **2. Tenant DB (`bgerp_t_xxx`):**
```sql
permission (id_permission, code, description)
tenant_role (id_tenant_role, code, name)
tenant_role_permission (id_tenant_role, id_permission, allow)
```

**ใช้สำหรับ:** Organization-specific permissions (modern system)

---

## ❌ **ปัญหาที่พบและวิธีแก้**

### **Problem 1: Connection Pooling + Transaction Snapshot**

**ปัญหา:**
- `tenant_db()` return **cached connection** ที่มี REPEATABLE-READ transaction snapshot เก่า
- Permission ใหม่ที่เพิ่งสร้างจะไม่ปรากฏใน query ถัดไป

**สาเหตุ:**
```php
// config.php
function tenant_db(?string $orgCode = null): mysqli {
    static $tenantCache = []; // ← Connection pooling!
    
    if (isset($tenantCache[$code])) {
        return $tenantCache[$code]; // ← Return cached connection!
    }
}
```

**วิธีแก้:**
1. **Option A (แนะนำ):** ใช้ permissions ที่มีอยู่แล้ว - ไม่ต้องสร้างใหม่
2. **Option B:** สร้าง fresh connection ด้วย `mysqli_connect_with_fallback($dbName)` แทน `tenant_db()`
3. **Option C:** Clear transaction snapshot ด้วย `$db->commit()` ก่อน query

### **Problem 2: Statement Leak**

**ปัญหา:**
- Prepared statement ที่ไม่ `store_result()` และ `free_result()` อย่างถูกต้องจะทำให้ query ถัดไปได้ result ไม่ครบ

**วิธีแก้:**
```php
// ✅ ถูกต้อง
$stmt = $db->prepare("SELECT ...");
$stmt->bind_param(...);
$stmt->execute();
$stmt->store_result(); // CRITICAL!
$stmt->bind_result(...);
if ($stmt->fetch()) {
    $copy = $variable; // Copy before close
    $stmt->free_result(); // CRITICAL!
    $stmt->close();
    // Use $copy here
}
```

### **Problem 3: Cross-DB Permission Complexity**

**ปัญหา:**
- Permission system มี 2 layers (Core + Tenant)
- ต้องสร้าง permission ใน 2 ที่
- ต้อง sync ระหว่าง 2 DBs

**วิธีแก้:**
- **ลดการสร้าง permissions ใหม่!**
- Reuse existing permissions
- Group related features under one permission

---

## 📋 **Existing Permissions (Reuse These!)**

### **Manufacturing/Atelier:**
- `atelier.job.ticket` - จัดการใบงาน Atelier และ WIP logs
  - ✅ ครอบคลุม: Job Tickets, WIP Logs, **Work Queue**, Tasks
- `atelier.job.wip.scan` - บันทึก WIP ผ่าน mobile app
  - ✅ ครอบคลุม: PWA Scan Station, Mobile WIP
- `atelier.dashboard.view` - ดูแดชบอร์ด Atelier
- `atelier.qc.checklist` - บันทึก QC checklist
- `atelier.material.lot` - จัดการ material lots
- `atelier.purchase.rfq` - จัดการ RFQ

### **Inventory:**
- `inventory.view` - ดูสต็อก
- `inventory.adjust` - ปรับสต็อก
- `inventory.transfer` - โอนสต็อก
- `inventory.issue` - เบิกวัตถุดิบ
- `inventory.receive` - รับวัตถุดิบ

### **QC:**
- `qc.inspect` - ตรวจสอบคุณภาพ
- `qc.fail.manage` - จัดการ QC fail
- `qc.rework.manage` - มอบหมายและอัพเดตงานแก้ไข

---

## ✅ **Best Practices**

### **1. Permission Reuse**
```php
// ✅ GOOD: Reuse existing permission
$page_detail['permission_code'] = 'atelier.job.ticket';
// New feature is part of Job Ticket Management

// ❌ BAD: Create new permission
$page_detail['permission_code'] = 'atelier.work.queue.view';
// Need to maintain in 2 DBs, create migrations, assign to roles, etc.
```

### **2. Migration for New Permissions (Only if absolutely necessary)**

If you MUST create a new permission:

```php
// database/migrations/000X_new_permission.php (Core DB)
migration_insert_if_not_exists(
    $db,
    'permission',
    ['code' => 'module.action', 'description' => 'Description'],
    ['code' => 'module.action']
);

// Assign to groups
$groups = ['owner', 'admin', 'manager'];
foreach ($groups as $groupName) {
    // Get group ID and create permission_allow entry
}
```

```php
// database/tenant_migrations/00XX_new_permission.php (Tenant DB)
migration_insert_if_not_exists(
    $db,
    'permission',
    ['code' => 'module.action', 'description' => 'คำอธิบาย (ไทย)'],
    ['code' => 'module.action']
);

// Assign to tenant roles
$roles = ['owner', 'admin', 'artisan_operator'];
foreach ($roles as $roleCode) {
    // Get role ID and create tenant_role_permission entry
}
```

### **3. Testing Permissions**
```bash
# Check permission in database
mysql -u root -proot bgerp_t_default -e "
SELECT * FROM permission WHERE code = 'module.action'
"

# Check role assignments
mysql -u root -proot bgerp_t_default -e "
SELECT 
    tr.code,
    p.code,
    trp.allow
FROM tenant_role_permission trp
JOIN tenant_role tr ON tr.id_tenant_role = trp.id_tenant_role
JOIN permission p ON p.id_permission = trp.id_permission
WHERE p.code = 'module.action'
"
```

---

## 🔍 **Troubleshooting**

### **Issue: Permission ใหม่ไม่ปรากฏใน admin_roles**

**Symptoms:**
- Database มี permission แล้ว
- API returns น้อยกว่า database (เช่น DB มี 90 แต่ API ได้ 89)

**Root Causes:**
1. Connection pooling + REPEATABLE-READ snapshot
2. Statement leak from previous queries
3. Permission ถูกลบ/สร้างใหม่ ทำให้ ID เปลี่ยน แต่ tenant_role_permission ยังชี้ ID เก่า

**Solutions:**
1. **Preferred:** ใช้ permission ที่มีอยู่แล้ว!
2. Hard refresh browser (Ctrl+Shift+R)
3. Restart MAMP PHP-FPM
4. Check และแก้ orphan foreign keys ใน tenant_role_permission

---

## 🔐 **Owner Bypass Mechanism**

### **Current Implementation (Before Nov 4, 2025):**
```php
// source/permission.php - tenant_permission_allow_code()
// Check if user is owner via account_group JOIN
$stmt = $coreDb->prepare("
    SELECT ag.group_name 
    FROM account_org ao 
    JOIN account_group ag ON ag.id_group = ao.id_group 
    WHERE ao.id_member = ? AND ao.id_org = ? 
    LIMIT 1
");
if ($stmt->fetch() && strtolower($group_name) === 'owner') {
    return true; // Owner bypasses ALL permissions
}
```

**Problem:**
- Requires JOIN with `account_group` table
- Slower query (2 tables)
- Unnecessary table dependency

### **After Refactor (November 4, 2025):**
```php
// source/permission.php - tenant_permission_allow_code()
// Check if user is owner via role_code (direct)
$stmt = $coreDb->prepare("
    SELECT role_code 
    FROM account_org 
    WHERE id_member = ? AND id_org = ? 
    LIMIT 1
");
if ($stmt->fetch() && strtolower($role_code) === 'owner') {
    return true; // Owner bypasses ALL permissions
}
```

**Benefits:**
- ✅ No JOIN needed (faster query)
- ✅ Direct column access (simpler code)
- ✅ `account_group` table removed (cleaner schema)

**Migration:**
- `account_org.id_group` → `account_org.role_code`
- Values: `'owner'`, `'admin'`, `'member'`
- Index: `idx_account_org_role` (performance)

---

## 📌 **Summary**

**เรียนรู้จากปัญหา Work Queue Permission:**

1. ✅ **ใช้ `atelier.job.ticket` แทน `atelier.work.queue.view`**
2. ✅ Work Queue เป็นส่วนหนึ่งของ Job Ticket Management อยู่แล้ว
3. ✅ ไม่ต้อง maintain permission ใหม่ใน 2 DBs
4. ✅ ไม่มีปัญหา connection pooling, transaction snapshot, statement leak

**Golden Rule:**
> "สร้าง permission ใหม่เฉพาะเมื่อ**จำเป็นจริงๆ** และฟีเจอร์นั้น**ไม่สามารถ**จัดอยู่ใต้ permission ที่มีอยู่แล้ว"

---

**Related Docs:**
- `.cursorrules` (Migration rules)
- `AI_IMPLEMENTATION_WORKFLOW.md` (Database changes)
- `DOCUMENTATION_INDEX.md` (Full documentation index)
- `DATABASE_SCHEMA_REFERENCE.md` (account_org structure - updated Nov 4, 2025)

