# 📊 Serial Number System - Current Status

**Last Updated:** November 9, 2025  
**Status:** ✅ **Core Complete** | 🟡 **Validate Phase** | 🔴 **Harden Phase Pending**

**See Also:**
- `SERIAL_SYSTEM_READINESS.md` - Detailed readiness assessment (3-layer structure)
- `SERIAL_VALIDATION_TEST_PLAN.md` - Comprehensive validation test plan

---

## ✅ สิ่งที่เสร็จแล้ว (Completed)

### **1. Core Infrastructure**
- ✅ `UnifiedSerialService` - Service สำหรับ generate/verify/link serials
- ✅ `SerialManagementService` - Service สำหรับจัดการ pre-generated serials
- ✅ Database Schema:
  - ✅ `serial_registry` table (Core DB)
  - ✅ `serial_seq_daily` table (Core DB)
  - ✅ `job_ticket_serial` table (Tenant DB) - มีอยู่แล้ว
- ✅ Database Migrations:
  - ✅ `0002_serial_registry_system.php` (Core DB)
  - ✅ `2025_11_serial_system_integration.php` (Tenant DB)

### **2. Integration Points**
- ✅ `hatthasilpa_job_ticket.php` - ใช้ `UnifiedSerialService` สำหรับ pre-generation
- ✅ `dag_token_api.php` - ใช้ `getUnspawnedSerials()` และ dual-link (`markAsSpawned()` + `linkDagToken()`)
- ✅ `mo.php` - ใช้ `UnifiedSerialService` สำหรับ OEM serial generation

### **3. Security & Configuration**
- ✅ Serial Salt Management UI (Platform Console)
- ✅ Salt storage (`storage/secrets/serial_salts.php`)
- ✅ Salt reading logic (secrets file → env vars → config.local.php)
- ✅ Documentation:
  - ✅ `SERIAL_SALT_UI_GUIDE.md`
  - ✅ `SERIAL_SALT_AFTER_GENERATE.md`
  - ✅ `SERIAL_SALT_SETUP.md`

---

## 🟡 สิ่งที่ยังไม่เสร็จ (Pending)

### **1. Database Migrations - ต้อง Apply**
- ⚠️ Core DB Migration (`0002_serial_registry_system.php`) - ต้องรัน
- ⚠️ Tenant DB Migration (`2025_11_serial_system_integration.php`) - ต้องรันสำหรับทุก tenant
- ⚠️ ตรวจสอบว่า `organization.org_serial_code` ถูกตั้งค่าแล้วหรือยัง

### **2. Testing**
- ⚠️ Smoke Tests - ต้องรันทดสอบ:
  - ✅ HAT serial generation
  - ✅ OEM serial generation
  - ✅ Serial verification
  - ⚠️ Dual-link (Tenant + Core DB)
  - ⚠️ Context validation (HAT/OEM mismatch)
  - ⚠️ Partial spawn (spawn บางส่วน)
  - ⚠️ No-duplicate on spawn

### **3. Feature Flags**
- ⚠️ Feature flags ยังไม่ implement:
  - `FF_SERIAL_STD_HAT` - Enable standardized HAT serials
  - `FF_SERIAL_STD_OEM` - Enable standardized OEM serials
  - `FF_VERIFY_PUBLIC_MODE` - Public verify API mode

### **4. Background Jobs**
- ⚠️ Consistency Checker - ยังไม่ implement:
  - Hourly job เพื่อตรวจสอบ missing links
  - Fix `job_ticket_serial.spawned_token_id` ที่หาย
  - Fix `serial_registry.dag_token_id` ที่หาย
  - Quarantine invalid serials
- ⚠️ Outbox Worker - ยังไม่ implement:
  - Retry failed Core DB links (`serial_link_outbox`)
  - Exponential backoff (1m, 5m, 15m, 1h, 6h)
  - Max 10 retries → Mark `dead` and alert

### **5. Public Verify API**
- ⚠️ Public verify endpoint - ยังไม่ implement:
  - `/api/public/serial/verify/{serial_code}`
  - Privacy modes (minimal/standard/internal)
  - No PII exposure

---

## 🚀 Next Steps (ลำดับความสำคัญ)

### **Phase 1: Database Setup (ทำก่อน)**
1. ✅ Apply Core DB migration (`0002_serial_registry_system.php`)
2. ✅ Apply Tenant DB migration (`2025_11_serial_system_integration.php`) สำหรับทุก tenant
3. ✅ ตั้งค่า `org_serial_code` สำหรับทุก tenant ใน `organization` table
4. ✅ ตรวจสอบว่า salt environment variables ถูกตั้งค่าแล้ว

### **Phase 2: Testing (ทำต่อ)**
1. ✅ Run smoke tests (`tests/manual/test_serial_number_system.php`)
2. ✅ Test HAT serial generation และ verification
3. ✅ Test OEM serial generation และ verification
4. ✅ Test dual-link (Tenant + Core DB)
5. ✅ Test context validation (HAT/OEM mismatch)
6. ✅ Test partial spawn
7. ✅ Test no-duplicate on spawn

### **Phase 3: Feature Flags (ทำต่อ)**
1. ⚠️ Implement feature flag system (`tenant_feature_flags` table)
2. ⚠️ Add feature flag checks ใน integration points
3. ⚠️ Enable flags per tenant (gradual rollout)

### **Phase 4: Background Jobs (ทำต่อ)**
1. ⚠️ Implement Consistency Checker (hourly cron)
2. ⚠️ Implement Outbox Worker (retry failed links)
3. ⚠️ Set up monitoring และ alerting

### **Phase 5: Public Verify API (ทำต่อ)**
1. ⚠️ Implement public verify endpoint
2. ⚠️ Implement privacy modes
3. ⚠️ Add rate limiting และ security

---

## 📋 Immediate Action Items (ทำทันที)

### **1. Apply Database Migrations**
```bash
# Core DB
php source/bootstrap_migrations.php

# Tenant DB (ทุก tenant)
php source/bootstrap_migrations.php --all-tenants
# หรือ
php source/bootstrap_migrations.php --tenant=maison_atelier
php source/bootstrap_migrations.php --tenant=default
```

### **2. Set org_serial_code for All Tenants**
```sql
-- ตรวจสอบ tenant ที่มีอยู่
SELECT id_org, code, name FROM bgerp.organization WHERE status=1;

-- ตั้งค่า org_serial_code (ถ้ายังไม่มี)
UPDATE bgerp.organization SET org_serial_code='MAIS' WHERE id_org=2;
UPDATE bgerp.organization SET org_serial_code='DEFA' WHERE id_org=1;
```

### **3. Run Smoke Tests**
```bash
php tests/manual/test_serial_number_system.php
```

### **4. Verify Salt Configuration**
```bash
# ตรวจสอบว่า salt ถูกอ่านได้
php -r "
require 'config.php';
echo 'HAT Salt: ' . (getenv('SERIAL_SECRET_SALT_HAT') ?: 'NOT SET') . PHP_EOL;
echo 'OEM Salt: ' . (getenv('SERIAL_SECRET_SALT_OEM') ?: 'NOT SET') . PHP_EOL;
"
```

---

## 🔍 Verification Checklist

### **Database**
- [ ] `serial_registry` table exists (Core DB)
- [ ] `serial_seq_daily` table exists (Core DB)
- [ ] `serial_link_outbox` table exists (Tenant DB)
- [ ] `token_spawn_log` table exists (Tenant DB)
- [ ] `serial_quarantine` table exists (Tenant DB)
- [ ] `job_ticket_serial` has `uniq_ticket_seq` constraint
- [ ] `job_ticket_serial` has `idx_ticket_unspawned` index
- [ ] `organization.org_serial_code` set for all tenants

### **Services**
- [ ] `UnifiedSerialService` can generate HAT serials
- [ ] `UnifiedSerialService` can generate OEM serials
- [ ] `UnifiedSerialService` can verify serials
- [ ] `UnifiedSerialService` can link DAG tokens
- [ ] `SerialManagementService` can get unspawned serials
- [ ] `SerialManagementService` can mark serials as spawned

### **Integration**
- [ ] `hatthasilpa_job_ticket.php` pre-generates serials correctly
- [ ] `dag_token_api.php` reuses pre-generated serials
- [ ] `dag_token_api.php` performs dual-link correctly
- [ ] `mo.php` generates standardized OEM serials

### **Security**
- [ ] Salt values are stored securely
- [ ] Salt values are not committed to Git
- [ ] Salt values can be read by PHP
- [ ] Salt rotation works correctly

---

## 📚 Related Documents

- `SERIAL_PREP_CHECKLIST.md` - Pre-implementation checklist
- `SERIAL_NUMBER_INTEGRATION_ANALYSIS.md` - Integration analysis
- `SERIAL_NUMBER_SYSTEM_CONTEXT.md` - System context
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide

---

**Status:** 🟡 **Partially Complete**  
**Next Priority:** Apply database migrations and run smoke tests

