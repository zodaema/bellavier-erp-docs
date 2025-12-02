# 🧙‍♂️ Apply Serial System Migration via UI - Step by Step Guide

**Purpose:** คู่มือการ apply tenant DB migration `2025_11_serial_system_integration.php` ผ่าน Migration Wizard UI  
**Last Updated:** November 9, 2025  
**Target Tenants:** `maison_atelier`, `default` (หรือ tenants อื่นๆ ที่มีอยู่)

---

## 📋 Prerequisites

### **1. Access Requirements**
- ✅ Platform Super Admin role (`platform_super_admin`)
- ✅ Login ด้วยบัญชี Platform Super Admin

### **2. Migration File**
- ✅ `database/tenant_migrations/2025_11_serial_system_integration.php` ต้องมีอยู่
- ✅ Migration file syntax ถูกต้อง (ไม่มี PHP errors)

### **3. Database**
- ✅ Core DB (`bgerp`) ต้องเชื่อมต่อได้
- ✅ Tenant DBs (`bgerp_t_maison_atelier`, `bgerp_t_default`) ต้องเชื่อมต่อได้

---

## 🚀 Step-by-Step Instructions

### **Step 1: เข้าสู่ระบบ**

1. Login ด้วยบัญชี Platform Super Admin
2. ตรวจสอบว่าเห็นเมนู **Platform Console** ใน sidebar

---

### **Step 2: เปิด Migration Wizard**

1. ไปที่ Sidebar → **Platform Console** → **Migration Wizard**
2. หรือเข้าผ่าน URL: `index.php?p=platform_migration_wizard`
3. หน้า Migration Wizard จะแสดงขึ้นมา

---

### **Step 3: เลือก Migration File**

1. ระบบจะโหลดรายการ migration files อัตโนมัติ
2. หา migration file: **`2025_11_serial_system_integration.php`**
3. คลิกที่ migration file เพื่อเลือก
4. ตรวจสอบข้อมูลที่แสดง:
   - ✅ File name: `2025_11_serial_system_integration.php`
   - ✅ File size: ~X KB
   - ✅ Syntax: ✅ Valid (ถ้ามี warnings จะแสดง badge สีเหลือง)
5. คลิกปุ่ม **"ยืนยันและไปขั้นตอนถัดไป"**

**Expected Result:**
- Migration file ถูกเลือก (highlighted)
- ปุ่ม "ยืนยันและไปขั้นตอนถัดไป" แสดงขึ้นมา
- Summary panel แสดง migration file ที่เลือก

---

### **Step 4: เลือก Tenants**

1. ระบบจะแสดงรายการ tenants ที่มีอยู่
2. เลือก tenants ที่ต้องการ apply migration:
   - ✅ `maison_atelier` (Maison Atelier)
   - ✅ `default` (Default Tenant)
   - หรือ tenants อื่นๆ ที่ต้องการ
3. สามารถเลือกหลาย tenants พร้อมกันได้
4. คลิกปุ่ม **"Select All"** ถ้าต้องการเลือกทั้งหมด
5. คลิกปุ่ม **"Next: Test Migration"** เพื่อไปขั้นตอนถัดไป

**Expected Result:**
- Tenants ที่เลือกถูกติ๊ก (checked)
- Summary panel แสดงจำนวน tenants ที่เลือก
- ปุ่ม "Next: Test Migration" พร้อมใช้งาน

---

### **Step 5: Test Migration (Dry Run)**

1. ระบบจะแสดงหน้า "Test Migration"
2. คลิกปุ่ม **"Test Migration"** เพื่อทดสอบ migration ก่อน deploy จริง
3. ระบบจะรัน migration ในโหมด dry-run (ไม่ commit changes)
4. รอผลลัพธ์ (อาจใช้เวลา 10-30 วินาที)

**Expected Result:**
- ✅ Test Results แสดง:
  - Status: ✅ Success หรือ ⚠️ Warning
  - Output: แสดง log ของ migration execution
  - Execution time: เวลาที่ใช้
- ✅ ไม่มี errors (ถ้ามี error จะแสดงสีแดง)
- ✅ Summary แสดง:
  - Tables created: `serial_link_outbox`, `token_spawn_log`, `serial_quarantine`
  - Indexes added: `uniq_ticket_seq`, `idx_ticket_unspawned`
  - Constraints added: `uniq_ticket_seq`

**⚠️ ถ้ามี Errors:**
- ตรวจสอบ error message
- ตรวจสอบว่า migration file syntax ถูกต้อง
- ตรวจสอบว่า database connection ทำงานได้
- แก้ไขปัญหาแล้วลองใหม่

---

### **Step 6: Deploy Migration**

1. หลังจาก test migration สำเร็จแล้ว
2. คลิกปุ่ม **"Deploy Migration"** เพื่อ deploy จริง
3. ระบบจะแสดง confirmation dialog:
   - แสดง migration file ที่จะ deploy
   - แสดง tenants ที่จะ deploy ไป
   - แสดง warning ว่า migration จะถูก apply จริง
4. คลิก **"Yes, Deploy"** เพื่อยืนยัน

**Expected Result:**
- ✅ Deployment progress แสดง:
  - Tenant 1: `maison_atelier` → ✅ Success
  - Tenant 2: `default` → ✅ Success
- ✅ Deployment Results แสดง:
  - Total tenants: 2
  - Success: 2
  - Failed: 0
  - Execution time: X seconds
- ✅ Logs แสดง:
  - Migration execution output สำหรับแต่ละ tenant
  - Tables created
  - Indexes added
  - Constraints added

---

### **Step 7: ตรวจสอบผลลัพธ์**

1. คลิกปุ่ม **"View Migration Status"** เพื่อดูสถานะ migration
2. เลือก tenant ที่ต้องการตรวจสอบ
3. ตรวจสอบว่า migration ถูกบันทึกใน `tenant_migrations` table:
   ```sql
   SELECT * FROM tenant_migrations 
   WHERE migration = '2025_11_serial_system_integration.php'
   ORDER BY executed_at DESC;
   ```
4. ตรวจสอบว่า tables ถูกสร้างแล้ว:
   ```sql
   -- สำหรับแต่ละ tenant DB
   SHOW TABLES LIKE 'serial_%';
   SHOW TABLES LIKE 'token_spawn_log';
   ```
5. ตรวจสอบว่า indexes ถูกสร้างแล้ว:
   ```sql
   SHOW INDEXES FROM job_ticket_serial WHERE Key_name IN ('uniq_ticket_seq', 'idx_ticket_unspawned');
   ```

**Expected Result:**
- ✅ Migration ถูกบันทึกใน `tenant_migrations` table
- ✅ Tables ถูกสร้าง: `serial_link_outbox`, `token_spawn_log`, `serial_quarantine`
- ✅ Indexes ถูกสร้าง: `uniq_ticket_seq`, `idx_ticket_unspawned`
- ✅ Constraints ถูกสร้าง: `uniq_ticket_seq`

---

## 🔍 Verification Checklist

### **สำหรับ Tenant: `maison_atelier`**

- [ ] Migration ถูกบันทึกใน `bgerp_t_maison_atelier.tenant_migrations`
- [ ] Table `serial_link_outbox` ถูกสร้าง
- [ ] Table `token_spawn_log` ถูกสร้าง
- [ ] Table `serial_quarantine` ถูกสร้าง
- [ ] Index `uniq_ticket_seq` ถูกสร้างใน `job_ticket_serial`
- [ ] Index `idx_ticket_unspawned` ถูกสร้างใน `job_ticket_serial`
- [ ] Constraint `uniq_ticket_seq` ทำงาน (ทดสอบ insert duplicate)

### **สำหรับ Tenant: `default`**

- [ ] Migration ถูกบันทึกใน `bgerp_t_default.tenant_migrations`
- [ ] Table `serial_link_outbox` ถูกสร้าง
- [ ] Table `token_spawn_log` ถูกสร้าง
- [ ] Table `serial_quarantine` ถูกสร้าง
- [ ] Index `uniq_ticket_seq` ถูกสร้างใน `job_ticket_serial`
- [ ] Index `idx_ticket_unspawned` ถูกสร้างใน `job_ticket_serial`
- [ ] Constraint `uniq_ticket_seq` ทำงาน (ทดสอบ insert duplicate)

---

## 🐛 Troubleshooting

### **ปัญหา: Migration file ไม่แสดงในรายการ**

**สาเหตุ:**
- Migration file ไม่มีใน `database/tenant_migrations/`
- Migration file มี syntax error

**แก้ไข:**
```bash
# ตรวจสอบว่าไฟล์มีอยู่
ls -la database/tenant_migrations/2025_11_serial_system_integration.php

# ตรวจสอบ syntax
php -l database/tenant_migrations/2025_11_serial_system_integration.php
```

---

### **ปัญหา: Test Migration ล้มเหลว**

**สาเหตุ:**
- Database connection error
- Migration file มี syntax error
- Table หรือ index มีอยู่แล้ว (idempotent check failed)

**แก้ไข:**
1. ตรวจสอบ error message ใน Test Results
2. ตรวจสอบ database connection
3. ตรวจสอบ migration file syntax
4. ตรวจสอบว่า migration helpers ถูก load แล้ว

---

### **ปัญหา: Deploy ล้มเหลวสำหรับบาง tenant**

**สาเหตุ:**
- Database connection error สำหรับ tenant นั้น
- Migration execution error
- Transaction rollback

**แก้ไข:**
1. ตรวจสอบ error message ใน Deployment Results
2. ตรวจสอบ database connection สำหรับ tenant ที่ล้มเหลว
3. Deploy ใหม่สำหรับ tenant ที่ล้มเหลว (migration เป็น idempotent)

---

### **ปัญหา: Migration ถูก apply ซ้ำ**

**สาเหตุ:**
- Migration ถูก deploy หลายครั้ง

**แก้ไข:**
- Migration เป็น idempotent (safe to run multiple times)
- ระบบจะตรวจสอบ `tenant_migrations` table และ skip ถ้า apply แล้ว
- ไม่ต้องกังวลถ้า run ซ้ำ

---

## 📊 Expected Migration Output

### **Console Output (จาก Test/Deploy):**

```
=== Serial System Integration (Tenant DB) ===
[1/5] Adding unique constraint on job_ticket_serial...
  ✓ Unique constraint added
[2/5] Adding index for unspawned serials lookup...
  ✓ Index added
[3/5] Creating serial_link_outbox table...
  ✓ serial_link_outbox
[4/5] Creating token_spawn_log table...
  ✓ token_spawn_log
[5/5] Creating serial_quarantine table...
  ✓ serial_quarantine

=== Serial System Integration Complete ===
Changes applied:
  - job_ticket_serial: Unique constraint + index
  - serial_link_outbox: Created
  - token_spawn_log: Created
  - serial_quarantine: Created
```

---

## ✅ Success Criteria

### **Migration สำเร็จเมื่อ:**

1. ✅ Test Migration ผ่าน (ไม่มี errors)
2. ✅ Deploy Migration สำเร็จสำหรับทุก tenant ที่เลือก
3. ✅ Migration ถูกบันทึกใน `tenant_migrations` table
4. ✅ Tables ถูกสร้างครบ (3 tables)
5. ✅ Indexes ถูกสร้างครบ (2 indexes)
6. ✅ Constraints ทำงานถูกต้อง

---

## 🔗 Related Documents

- `MIGRATION_WIZARD_GUIDE.md` - คู่มือ Migration Wizard แบบละเอียด
- `SERIAL_SYSTEM_READINESS.md` - Readiness assessment
- `SERIAL_VALIDATION_TEST_PLAN.md` - Validation test plan

---

## 📝 Notes

- ✅ Migration เป็น **idempotent** (safe to run multiple times)
- ✅ Migration จะ skip ถ้า apply แล้ว (ตรวจสอบจาก `tenant_migrations` table)
- ✅ Migration จะไม่ลบข้อมูลเดิม (only adds tables/indexes/constraints)
- ✅ Migration ใช้ `migration_helpers.php` เพื่อความปลอดภัย

---

**Status:** ✅ **Ready to Execute**  
**Last Updated:** November 9, 2025

