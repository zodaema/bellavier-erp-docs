# 🔐 Permission System - อธิบายแบบง่ายสุด

**คำถาม:** ระบบใช้ Core DB หรือ Tenant DB?  
**คำตอบ:** **ใช้ทั้ง 2 แต่แยกหน้าที่กันชัดเจน** ✅

---

## 📊 แบ่งหน้าที่แบบนี้:

### 🏛️ **CORE DB** (ฐานข้อมูลกลาง)

**ใช้เก็บ:**
1. ✅ **Users (account)** - username, password
2. ✅ **Organizations** - มี tenant อะไรบ้าง
3. ✅ **User-Org-Role mapping** - user คนนี้อยู่ org ไหน role อะไร
4. ✅ **Permission Master List** - รายการ permissions ทั้งหมด (93 ตัว)

**ทำอะไร:**
- ตอบคำถาม: "User นี้ login ได้ไหม?"
- ตอบคำถาม: "User นี้อยู่ org ไหน? เป็น role อะไร?"
- เก็บ "สูตร permission" (permission codes)

**แก้ไขโดย:** Developer เท่านั้น

---

### 🏢 **TENANT DB** (ฐานข้อมูลแต่ละองค์กร)

**ใช้เก็บ:**
1. ✅ **Permissions (copy จาก core)** - รายการ permissions ที่ใช้ได้
2. ✅ **Tenant Roles** - บทบาทในองค์กร
3. ✅ **Role-Permission Assignment** - role ไหนมี permission อะไร ← **นี่แหละที่ Admin กำหนด!**
4. ✅ **ข้อมูลทั้งหมดของ tenant** - MO, Job Tickets, Products, etc.

**ทำอะไร:**
- ตอบคำถาม: "Role production_manager มี permission schedule.view ไหม?"
- ตอบคำถาม: "แสดง permissions อะไรในหน้า Admin บ้าง?"

**แก้ไขโดย:** Admin ของแต่ละ tenant

---

## 🔄 **ตัวอย่างการทำงานจริง**

### Scenario: User เข้าหน้า Production Schedule

```
1. User login → Core DB check username/password ✅

2. System ถาม: "User นี้อยู่ org ไหน?"
   → Core DB: account_org table
   → ตอบ: maison_atelier, role = owner

3. System ถาม: "Role owner มี permission schedule.view ไหม?"
   → Tenant DB (maison_atelier): 
      - หา tenant_role ที่ code = 'owner'
      - เช็ค tenant_role_permission
      - ตอบ: มี! ✅

4. Allow access ✅
```

---

### Scenario: Admin กำหนด Permissions

```
Admin เข้า: Admin → Roles & Permissions

1. Click role "production_manager"

2. System ทำอะไร?
   
   Step 1: หา account_group ใน Core DB
      → id_group = 3, group_name = "production_manager"
   
   Step 2: หา tenant_role ที่ match ใน Tenant DB
      → tenant_role: code = "production_manager", id = 10
   
   Step 3: Load permissions จาก Tenant DB
      → SELECT * FROM permission (93 rows)
      → LEFT JOIN tenant_role_permission
      → แสดง 93 permissions พร้อม checkbox

3. Admin ติ๊กเลือก permissions

4. Click "บันทึก"
   
   → บันทึกลง: Tenant DB
   → ตาราง: tenant_role_permission
   → บันทึก: id_tenant_role=10, id_permission=X, allow=1

5. เสร็จ! ✅
```

---

## 📋 **ตารางสรุป**

| สิ่งที่ต้องการทำ | Database ที่ใช้ | ตาราง | ใครแก้ |
|-------------------|-----------------|-------|--------|
| เพิ่ม user ใหม่ | Core DB | `account` | Admin |
| Assign user ให้ org | Core DB | `account_org` | Admin |
| เพิ่ม permission code ใหม่ | Core DB → sync → Tenant DB | `permission` | Developer |
| กำหนดว่า role ไหนมี permission อะไร | **Tenant DB** ← นี่! | `tenant_role_permission` | **Admin** |
| Check ว่า user มีสิทธิ์ไหม | Tenant DB | `tenant_role_permission` | System |

---

## ✅ **คำตอบชัดๆ**

### คำถาม: "Admin กำหนด permission ใน DB ไหน?"

**คำตอบ:** 

```
✅ TENANT DB (tenant_role_permission table)
```

**ทำไม?**
- เพื่อให้แต่ละ tenant กำหนดได้อิสระ
- Tenant A: production_manager มี mo.create ✅
- Tenant B: production_manager ไม่มี mo.create ❌

---

### คำถาม: "แล้ว Core DB ใช้ทำอะไร?"

**คำตอบ:**

```
1. เก็บ Permission Master List (93 permissions)
2. เก็บ User accounts
3. เก็บ User-Org-Role mapping
```

**แต่:**
- ❌ Core DB **ไม่ได้** กำหนดว่า role ไหนมี permission อะไร
- ✅ Tenant DB **ถึงจะ** กำหนด (tenant_role_permission)

---

## 🔄 **Data Flow แบบง่ายสุด**

```
Developer:
  เพิ่ม permission codes ใน Core DB (เช่น schedule.view)
    ↓
  Run: php tools/sync_permissions_to_tenants.php
    ↓
  Permission codes ถูก copy ไป Tenant DB ทุก tenant
    ↓
Admin (แต่ละ tenant):
  เข้า Admin → Roles & Permissions
    ↓
  เลือก role (เช่น production_manager)
    ↓
  ติ๊ก permissions ที่ต้องการ (จาก 93 ตัว)
    ↓
  บันทึกลง: Tenant DB (tenant_role_permission)
    ↓
User:
  เข้าใช้งาน
    ↓
  System เช็ค: Tenant DB (tenant_role_permission)
    ↓
  Allow/Deny
```

---

## 🎯 **สรุปสุดท้าย**

**Admin กำหนด permissions ใน:**
### → **TENANT DB** ✅

**แต่ permission codes มาจากไหน:**
### → **CORE DB** (sync ไป tenant)

**ทำไมต้องมี 2 DB:**
### → เพื่อ **tenant isolation** (แต่ละองค์กรอิสระ)

---

**เข้าใจแล้วไหมครับ?** หรือต้องการให้ผมอธิบายเพิ่มเติมส่วนไหนครับ? 🙏

