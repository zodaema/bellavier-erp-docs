# 🔐 Permission Management Guide

**Approach:** Controlled Customization (แนวทาง 2)  
**Date:** January 27, 2025  
**Status:** ✅ Production Ready

---

## 🎯 Overview

ระบบ Permission ของ Bellavier Group ERP ใช้แนวทาง **Controlled Customization** คือ:

✅ **Permission Codes = Controlled** (เหมือนกันทุก tenant, sync จาก core DB)  
✅ **Permission Assignment = Customizable** (แต่ละ tenant กำหนด role ใดมีสิทธิ์อะไร)

---

## 🏗️ Architecture

### Permission Master List (Core DB)

```
Core DB: permission (93 permissions)
  ↓ (Read-Only Master)
  ├─ mo.view
  ├─ mo.create
  ├─ schedule.view
  ├─ schedule.edit
  └─ ... (รวม 93 permissions)
```

### Tenant Permission Assignment (Tenant DB)

```
Tenant DB (maison_atelier):
  ├─ permission (93 permissions) ← Synced from core
  ├─ tenant_role (7 roles)
  └─ tenant_role_permission ← Admin assigns here
       ├─ owner → all permissions
       ├─ admin → most permissions
       ├─ production_manager → production permissions
       └─ ...
```

---

## ✅ Benefits

### 1. **Consistency**
- Permission codes เหมือนกันทุก tenant
- Code ไม่พัง เพราะ permission.code guaranteed

### 2. **Flexibility**
- แต่ละ tenant กำหนดได้ว่า role ไหนมีสิทธิ์อะไร
- Tenant A: production_manager มี mo.create ✅
- Tenant B: production_manager ไม่มี mo.create ❌

### 3. **Feature Rollout**
```bash
# Developer เพิ่ม feature ใหม่
# เพิ่ม permissions ใน core DB

# Sync ทุก tenant
php tools/sync_permissions_to_tenants.php

# ✅ ทุก tenant ได้ permissions ใหม่อัตโนมัติ
# Admin แต่ละ tenant ไปติ๊กเพิ่ม
```

### 4. **Security**
- ❌ Tenant **ไม่สามารถ** สร้าง permission codes เอง
- ✅ Tenant **สามารถ** เลือกว่า role ไหนมีสิทธิ์อะไร

---

## 📋 How It Works

### การทำงานของระบบ

#### 1. **User เข้าหน้า (เช่น Production Schedule)**

```php
permission_allow_code($member, 'schedule.view')
  ↓
tenant_permission_allow_code() [Check tenant DB]
  ├─ Get user's role (from account_org → account_group)
  ├─ Map to tenant_role (by code)
  ├─ Check tenant_role_permission
  └─ Return TRUE/FALSE
```

#### 2. **Admin กำหนด Permissions**

1. Admin → Roles & Permissions
2. เลือก Role (เช่น Production Manager)
3. **เห็น permissions ทั้งหมด 93 ตัว** (synced from core)
4. ติ๊กเลือกที่ต้องการ
5. บันทึก → เข้า `tenant_role_permission` table

---

## 🛠️ Management Tasks

### Task 1: เพิ่ม Permissions ให้ Role

**ทำใน UI:**
1. เข้า **Admin → Roles & Permissions**
2. เลือก role ที่ต้องการ (เช่น owner, admin)
3. ติ๊ก permissions ที่ต้องการ
4. คลิก **"บันทึก"**

**ตัวอย่าง:**
```
Owner role → ควรมีทุก permissions ✅
Production Manager → mo.*, schedule.*, job_ticket.* ✅
Quality Manager → qc.*, mo.view ✅
Viewer → *.view เท่านั้น ✅
```

---

### Task 2: เพิ่ม Permission Codes ใหม่ (Developer)

**เมื่อเพิ่ม Feature ใหม่:**

#### Step 1: เพิ่มใน Core DB
```sql
-- เพิ่มใน core DB (bgerp.permission)
INSERT INTO permission (code, description) VALUES
('new_feature.view', 'View new feature'),
('new_feature.manage', 'Manage new feature');
```

#### Step 2: Sync ทุก Tenant
```bash
php tools/sync_permissions_to_tenants.php
```

**Output:**
```
✅ Syncing to: DEFAULT (Added: 2)
✅ Syncing to: maison_atelier (Added: 2)
🎉 All tenants synced!
```

#### Step 3: Admin แต่ละ Tenant
- ไป Admin → Roles & Permissions
- เลือก role
- เห็น permissions ใหม่
- ติ๊ก → บันทึก

---

### Task 3: เพิ่ม Tenant ใหม่

**Provision Process จะ sync permissions อัตโนมัติ:**

```bash
php tools/provision_tenant.php new_tenant_code
```

**จะทำ:**
1. สร้าง tenant database
2. Run tenant migrations
3. **Sync 93 permissions จาก core DB** ← อัตโนมัติ
4. สร้าง default roles (owner, admin, etc.)
5. พร้อมใช้งาน!

---

## 🔍 Troubleshooting

### ❓ Permissions ไม่แสดงในหน้า Admin

**สาเหตุ:** Tenant DB ยังไม่มี permissions

**แก้ไข:**
```bash
php tools/sync_permissions_to_tenants.php
```

---

### ❓ Permission ใหม่ไม่แสดง

**สาเหตุ:** เพิ่มใน core DB แล้ว แต่ยังไม่ sync

**แก้ไข:**
```bash
php tools/sync_permissions_to_tenants.php
```

---

### ❓ Tenant มี permissions ไม่ครบ

**ตรวจสอบ:**
```sql
-- Core DB
SELECT COUNT(*) FROM bgerp.permission;  -- ควรได้ 93+

-- Tenant DB
SELECT COUNT(*) FROM bgerp_t_maison_atelier.permission;  -- ควรเท่ากับ core
```

**แก้ไข:**
```bash
php tools/sync_permissions_to_tenants.php
```

---

## 🚨 Important Rules

### ✅ DO (ทำได้)

1. ✅ เพิ่ม permission codes ใน **core DB** (developer)
2. ✅ Run `sync_permissions_to_tenants.php` หลังเพิ่ม
3. ✅ Tenant admin ติ๊กเลือก permissions ให้ roles
4. ✅ แต่ละ tenant กำหนด role assignments ต่างกันได้

### ❌ DON'T (ห้ามทำ)

1. ❌ **ห้าม** สร้าง permission codes ใน tenant DB โดยตรง
2. ❌ **ห้าม** ลบ permissions ใน tenant DB
3. ❌ **ห้าม** แก้ permission.code ใน tenant DB
4. ❌ **ห้าม** bypass sync process

**เพราะ:** จะทำให้ permission codes ไม่ตรงกัน → code พัง!

---

## 📊 Current Status

### Permissions Count

| Database | Permissions | Synced |
|----------|-------------|--------|
| Core DB (master) | 93 | ✅ |
| DEFAULT tenant | 93 | ✅ |
| maison_atelier tenant | 93 | ✅ |

### Schedule Permissions

| Code | Description | Added |
|------|-------------|-------|
| `schedule.view` | View production schedule | ✅ |
| `schedule.edit` | Edit schedule dates | ✅ |
| `schedule.auto_arrange` | Use auto-arrange | ✅ |
| `schedule.config` | Configure settings | ✅ |

---

## 🔄 Workflow

### เมื่อพัฒนา Feature ใหม่

```
Developer
  ↓
1. เขียน code feature ใหม่
2. เพิ่ม permissions ใน core DB (via SQL/migration)
  ↓
DevOps/Admin
  ↓
3. Run: php tools/sync_permissions_to_tenants.php
  ↓
Tenant Admin
  ↓
4. เข้า Admin → Roles & Permissions
5. เห็น permissions ใหม่
6. เลือก roles → ติ๊ก → บันทึก
  ↓
Users
  ↓
7. เข้าใช้ feature ใหม่ได้ตาม permissions ที่ได้รับ
```

---

## 🎯 Best Practices

### สำหรับ Developer

1. **Permission Naming Convention:**
   ```
   {module}.{action}
   
   Examples:
   - mo.view
   - mo.create
   - schedule.view
   - schedule.edit
   ```

2. **เพิ่ม Permissions เป็นชุด:**
   ```sql
   -- ชุดสิทธิ์สำหรับ module ใหม่
   INSERT INTO permission (code, description) VALUES
   ('new_module.view', 'View new module'),
   ('new_module.create', 'Create items'),
   ('new_module.edit', 'Edit items'),
   ('new_module.delete', 'Delete items'),
   ('new_module.approve', 'Approve actions');
   ```

3. **Update Translation Keys:**
   ```php
   // lang/th.php, lang/en.php
   'permission.new_module.view' => 'ดูโมดูลใหม่',
   'permission.new_module.create' => 'สร้างรายการ',
   ```

4. **Run Sync:**
   ```bash
   php tools/sync_permissions_to_tenants.php
   ```

### สำหรับ Admin

1. **Default Assignments:**
   - **Owner:** ทุก permissions ✅
   - **Admin:** ส่วนใหญ่ ยกเว้น sensitive operations
   - **Manager:** เฉพาะ module ที่รับผิดชอบ
   - **Operator:** เฉพาะ actions ที่ต้องทำ
   - **Viewer:** เฉพาะ *.view

2. **Regular Review:**
   - ทบทวน permissions ทุก 3 เดือน
   - ลบ permissions ที่ไม่ใช้
   - เพิ่ม permissions ตามความต้องการใหม่

---

## 📚 Related Files

- **Sync Tool:** `tools/sync_permissions_to_tenants.php`
- **Migration:** `database/tenant_migrations/2025_01_schedule_system.php`
- **Permission Functions:** `source/permission.php`
- **Admin RBAC:** `source/admin_rbac.php`

---

## ✅ Summary

**Permission Management = Controlled Customization**

- 🔒 **Permission Codes:** Controlled by developer (master list)
- 🎨 **Permission Assignment:** Customizable by tenant admin
- 🔄 **Sync Process:** Automated via tool
- ✅ **Tenant Isolation:** Each tenant independent
- 🚀 **Scalable:** Ready for Maison-level growth

---

**🎉 Best of both worlds: Control + Flexibility!**

