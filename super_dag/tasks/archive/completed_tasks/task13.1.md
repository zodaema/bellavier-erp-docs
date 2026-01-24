# Task 13.1 — DAG Supervisor Sessions Permission Setup  
_(Prompt สำหรับ AI Agent — ใช้รันงานนี้แบบอัตโนมัติ)_

## 🎯 Objective  
เพิ่ม permission code ใหม่ให้กับระบบสำหรับหน้า **DAG Supervisor Sessions** เพื่อให้สอดคล้องกับระบบ permission ของ Bellavier Group ERP และรองรับการขยายสิทธิ์ในอนาคต

Permission ใหม่:  
- **`DAG_SUPERVISOR_SESSIONS`**

## 📌 สิ่งที่ Agent ต้องทำ
ทำทั้งหมดนี้แบบ **idempotent**, ปลอดภัย, และไม่กระทบฟีเจอร์อื่น

---

## ✅ Step 1 — Create Migration File  
สร้างไฟล์:

```
database/core_migrations/2025_12_dag_supervisor_sessions_permission.php
```

### เนื้อหา migration (Agent ต้องสร้างจริง)
- เพิ่ม permission code ใหม่ใน permission catalog  
- ผูก permission code เข้ากับ roles ต่อไปนี้:
  - `PLATFORM_ADMIN`
  - `TENANT_ADMIN`

### Rule  
- ใช้ SQL แบบ `ON DUPLICATE KEY UPDATE`
- Migration ต้องรันได้หลายครั้งโดยไม่ error
- ห้ามแตะตารางอื่นที่ไม่เกี่ยวข้อง

---

## ✅ Step 2 — Update Permission Reference Documentation  
แก้ไขไฟล์:

- `docs/developer/permission_reference.md`  
(ถ้าไม่มี Agent ต้องสร้างใหม่)

เพิ่ม section:

```
### DAG_SUPERVISOR_SESSIONS
- Description: Access to DAG Supervisor Sessions dashboard & override actions
- Default Roles: PLATFORM_ADMIN, TENANT_ADMIN
- Category: DAG / Supervisor Tools
```

---

## ✅ Step 3 — Update task_index.md  
ในไฟล์ `docs/super_dag/task_index.md`:

เพิ่ม task:

```
### Task 13.1 — Supervisor Permission Code Setup
Status: IN PROGRESS → COMPLETED เมื่อ Agent ทำงานเสร็จ
```

---

## ✅ Step 4 — (Optional but Recommended)  
ใน `source/dag_supervisor_sessions.php`:

เพิ่มการตรวจสิทธิ์แบบ hybrid:

```
$hasCode = member_has_permission($member, 'DAG_SUPERVISOR_SESSIONS');

if (!$isPlatformAdmin && !$isTenantAdmin && !$hasCode) {
    TenantApiOutput::error('forbidden', 403, [
        'app_code' => 'SUPERVISOR_403_FORBIDDEN',
        'message' => 'Supervisor or admin permission required'
    ]);
}
```

**Agent ต้องเพิ่มโดยไม่ลบ logic เดิม และต้อง wrap ด้วย function_exists เพื่อ fail-safe**

---

## 🧪 Step 5 — Self Test Script  
ให้ Agent เขียน test script เพิ่มใน:

```
tests/Integration/SuperDag/SupervisorPermissionTest.php
```

Test ที่ต้องมี:

1. PLATFORM_ADMIN → access allowed  
2. TENANT_ADMIN → access allowed  
3. USER มี permission `DAG_SUPERVISOR_SESSIONS` → allowed  
4. USER ปกติ → 403  
5. Permission missing → fallback ไป role admin  

Test ต้องใช้ bootstrap เดิมของระบบ และผ่าน psr-4 autoload

---

## 🎉 Definition of Done (ที่ Agent ต้องตรวจให้ครบ)

- Migration ถูกสร้างและ syntax ผ่าน  
- รัน migration แล้วเห็น permission ใน DB  
- task_index.md อัปเดต  
- supervisor endpoint รองรับ permission code  
- test suite ผ่าน 100%  
- ไม่มี breaking changes  
- ไม่มีผลกระทบกับ work queue / PWA / behavior engine  

---

## 📝 หมายเหตุสำคัญ  
- ห้ามเปลี่ยนฟังก์ชันตรวจ role เดิม (`is_platform_administrator`, `is_tenant_administrator`)  
- Permission code อันนี้เป็น **view/manage all supervisor actions** ยังไม่แตกย่อย  
- ภายหลังอาจสร้าง:
  - `DAG_SUPERVISOR_SESSIONS_VIEW`
  - `DAG_SUPERVISOR_SESSIONS_MANAGE`
  แต่ยังไม่ใช่ตอนนี้

---

## ✔ Prompt สำเร็จรูปที่ Agent ต้องใช้

> “Implement Task 13.1 ตามรายละเอียดในไฟล์ task13.1.md — สร้าง migration, อัปเดตเอกสาร, เพิ่ม hybrid permission guard ใน endpoint, และเขียน integration tests — แบบ idempotent, ไม่แตะ logic อื่น และต้อง backward compatible 100%”

