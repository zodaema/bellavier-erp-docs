# Task 13.2 — RBAC (admin_rbac.php) Full Safety Sweep & DB Permission Fix

## Goal
ปิดช่องโหว่ทั้งหมดของระบบ RBAC ใน `admin_rbac.php` และจัดระบบ Permission ให้ปลอดภัยตามสถาปัตยกรรม Platform / Tenant ที่ถูกต้อง พร้อมป้องกันปัญหา Permission Leak ที่พบก่อนหน้า

---

# 🎯 Objectives

## 1. แก้ปัญหา `$db->prepare()` ที่ใช้ผิดประเภท
- `$db` เป็น `DatabaseHelper` ซึ่ง *ไม่มี* method `prepare()`
- ทุก query ใน `admin_rbac.php` ต้องใช้:
  - **Core DB:** `$coreDb->getCoreDb()->prepare()`
  - **Tenant DB:** `$tenantDb->getDb()->prepare()`

## 2. Standardize Database Source
กำหนดตายตัวว่า table ใดควรใช้ DB ไหน:

| Table | Database |
|-------|----------|
| `account`, `account_org`, `platform_user` | Core DB |
| `tenant_role`, `tenant_role_permission`, `tenant_user_role` | Tenant DB |

สร้าง helper เพื่อให้โค้ดอ่านง่ายขึ้น:

```php
function getCoreMysqli($coreDb) {
    return $coreDb->getCoreDb();
}
function getTenantMysqli($tenantDb) {
    return $tenantDb->getDb();
}
```

---

# 3. ป้องกัน Platform Permission หลุดเข้า Tenant
Permission ใดที่ขึ้นต้นด้วย:

- `platform.*`
- `serial.*`
- `migration.*`

**ห้ามปรากฏใน Tenant UI**  
**ห้าม assign ให้ Tenant role**

เพิ่ม filter:

```php
if ($scope === 'tenant' && RbacHelper::isPlatformPermission($row['code'])) {
    continue;
}
```

---

# 4. Protect “Owner” Role
เพิ่ม guard:

```php
if ($id_role == 1) {
    json_error('cannot_edit_owner_role', 403);
}
```

Owner role ห้ามถูกแก้ไขทุกกรณี

---

# 5. Refactor Legacy Function ensure_default_groups()
ของเดิม reference `$coreDb` โดยไม่มีอยู่จริงใน scope

**แก้เป็น dependency injection:**

```php
function ensure_default_groups($coreMysqli) {
    ...
}
```

---

# 6. เพิ่ม Helper สำหรับตรวจสอบ Platform Permission
ไฟล์ใหม่: `source/BGERP/Rbac/RbacHelper.php`

```php
namespace BGERP\Rbac;

class RbacHelper {
    public static function isPlatformPermission($code) {
        return str_starts_with($code, 'platform.')
            || str_starts_with($code, 'serial.')
            || str_starts_with($code, 'migration.');
    }
}
```

แล้วใน admin_rbac.php ใช้:

```php
use BGERP\Rbac\RbacHelper;
```

---

# 📦 Deliverables

### Code
- admin_rbac.php refactored + safety guards
- RbacHelper.php created
- DB access standardized

### Optional Migration (ถ้าตรวจพบข้อมูลผิดปกติ)
ไฟล์:

```
2025_12_rbac_cleanup_platform_permissions.php
```

ลบ platform permissions ออกจาก tenant DB หากพบ

---

# 🧪 QA Checklist

## API
- [ ] `/source/admin_rbac.php?action=groups` ทำงานปกติ
- [ ] `/source/admin_rbac.php?action=permissions` filter platform permission ออก
- [ ] Owner role ถูกป้องกันจากการแก้ไข

## DB
- [ ] ไม่มี `$db->prepare()` ที่ผิด scope เหลืออยู่
- [ ] Platform permissions ไม่หลุดกลับเข้า tenant

## UI
- [ ] หน้า admin_roles ไม่แสดง permission ที่ไม่ควรแสดง

---

# 🚀 Final Result
หลังทำ Task 13.2:

- RBAC เสถียร ปลอดภัย พร้อมใช้งานระดับ Production
- ไม่มี “Permission Leak” ที่อันตรายหลุดมาอีก
- โค้ดอ่านง่ายขึ้น และ maintain ได้ง่ายในระยะยาว
- รองรับ multi-tenant เต็มรูปแบบ

## DB Safety Sweep (Focus)

ใน Task 13.2 นี้ ให้โฟกัสเฉพาะเรื่อง Database Layer ตามกติกานี้:

### A. Rules

1. ห้ามใช้ `$db->prepare()` กับ `DatabaseHelper`
2. ทุก prepared statement ต้องใช้:
   - Core DB → `$coreDb = CoreApiBootstrap::getInstance()->getCoreDb();` + `$coreMysqli = $coreDb->getCoreDb();`
   - Tenant DB → `$tenantDb = TenantApiBootstrap::getInstance()->getTenantDb();` + `$tenantMysqli = $tenantDb->getDb();`
3. ตาราง core: `account`, `account_org`, `platform_user`, `permission`, `platform_roles`, `platform_role_permission`, `feature_flag_*`
4. ตาราง tenant: `tenant_role`, `tenant_role_permission`, `tenant_user_role`, และทุกตารางฝั่ง org (products, materials, dag_*, mo, ฯลฯ)


### B. สิ่งที่ต้องทำใน codebase

1. ค้นหาในโปรเจกต์:
   - `"$db->prepare("`
   - `"DatabaseHelper("`
   - `"->prepare("` ที่อยู่ใกล้กับ `DatabaseHelper`
2. สำหรับทุกที่ที่พบ:
   - ถ้า `$db` เป็น `DatabaseHelper` → แก้ให้ไปใช้ `$coreMysqli` หรือ `$tenantMysqli` ตามตารางที่ query
   - ถ้าใช้ connection global อื่น (เช่น `$connect`, `$mysqli`) → แก้ให้ใช้ `$coreDb->getCoreDb()` หรือ `$tenantDb->getDb()` แทน

3. ค้นหา:
   - `"new DatabaseHelper"`
   - `"DatabaseHelper::"`
   ตรวจว่ามีการเรียก `prepare()` หรือฟังก์ชัน low-level DB อื่น ๆ ผ่าน helper หรือไม่:
   - ถ้ามี → refactor ให้ไปใช้ mysqli ตรงจาก core/tenant แทน
   - ถ้าใช้ `fetchAll` / `fetchRow` ที่ส่ง mysqli เข้าไป → ปล่อยได้ ไม่ต้องแก้ (ตราบใดที่ส่ง connection ถูกตัว)

4. ค้นหา `mysqli_query`, `mysqli_prepare`, `mysqli_fetch_*`:
   - ตรวจว่าใช้ connection ที่ถูกต้อง (core vs tenant)
   - ถ้าพบการใช้ connection เก่า (`$connect`, `mysqli_connect` ตรง ๆ) → migrate มาใช้ `$coreDb->getCoreDb()` หรือ `$tenantDb->getDb()` เสมอ


### C. Definition of Done (DB Only)

- [ ] ใน `source/admin_rbac.php` ไม่มี `$db->prepare()` หรือการเรียก `prepare()` ผ่าน `DatabaseHelper` เหลืออยู่
- [ ] ทุกไฟล์ใน `source/` ที่ใช้ prepared statements ใช้ `$coreDb->getCoreDb()` หรือ `$tenantDb->getDb()` อย่างถูกต้อง
- [ ] ไม่เหลือจุดที่ใช้ connection เก่า (`$connect`, `mysqli_connect`) ในฟังก์ชันใหม่ ๆ (โดยเฉพาะ RBAC, platform/tenant bootstrap)
- [ ] `php -l` ผ่านทุกไฟล์ที่ถูกแก้
- [ ] การเรียก APIs ที่เกี่ยวข้อง (โดยเฉพาะ `admin_rbac.php`, `admin_roles.php`, และ RBAC endpoints อื่น ๆ) ยังทำงานได้ตามเดิม
