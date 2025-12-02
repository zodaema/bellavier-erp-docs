# Task 14.1.9 — Routing V1 Cleanup Phase 1 (Freeze & Instrument)

## Context

หลังจาก:

- 14.1.3 — เพิ่ม `LegacyRoutingAdapter` (V2-first, V1 fallback)
- 14.1.4 — ให้ `DagExecutionService` เป็น execution core
- 14.1.7–14.1.8 — เคลียร์ dual-write ของ stock/material

ตอนนี้ฝั่ง **Routing** ยังมี “หาง” ของ V1 อยู่:

- ตาราง `routing`, `routing_step` ยังอยู่
- `LegacyRoutingAdapter` ยังคง fallback กลับไปใช้ V1 ได้
- Callers หลัก:
  - `hatthasilpa_job_ticket.php`
  - `pwa_scan_api.php`
  - (อาจมีจุดอื่นเล็กน้อย)

เป้าหมายของ Task 14.1.9 ยัง **ไม่ใช่การลบ V1** แต่คือ:

1. ทำให้ V1 อยู่ในสภาพ “แช่แข็ง” (read-only archive)
2. เพิ่มการ **log และ telemetry** ให้รู้แน่ ๆ ว่าตอนนี้ใครยังใช้ V1 อยู่บ้าง, ใช้เมื่อไร, โปรดักส์ไหน
3. ใส่ guard / feature flag ป้องกันไม่ให้ V1 ถูกเรียกใช้โดยไม่ตั้งใจ
4. เตรียมข้อมูลสำหรับ Phase ถัดไปที่จะลบ V1 ออกจาก production แบบปลอดภัย

---

## Goals

1. **Freeze Routing V1** ให้เป็น read-only archive:
   - ห้ามเขียน (เขียนก็ห้ามมี effect)
   - การอ่านผ่าน V1 มีการ log ชัดเจน

2. **Instrument LegacyRoutingAdapter**:
   - ทุกครั้งที่มีการ fallback ไป V1 → log record ลง DB + log file
   - เก็บข้อมูล:
     - tenant
     - product / mo / job_ticket context
     - caller (เช่น `hatthasilpa_job_ticket`, `pwa_scan_api`)
     - timestamp
     - routing_id / routing_code (ถ้ามี)

3. **Add Feature Flag**:
   - `FF_ALLOW_ROUTING_V1_FALLBACK`
   - ค่า default: เปิดใน DEV/STAGING, ปิดใน tenant ใหม่ / prod (config-based)

4. **Non-breaking**:
   - ถ้ามี tenant เก่าที่ยังใช้ routing V1 → ระบบต้องยังทำงานได้เหมือนเดิม (เมื่อ flag อนุญาต)
   - ถ้า flag ปิด → ต้อง fail แบบ controlled พร้อม error message ชัดเจน

---

## Non-Goals

- ไม่ลบตาราง `routing`, `routing_step`
- ไม่ลบไฟล์ `routing.php`
- ไม่ลบ `LegacyRoutingAdapter.php`
- ไม่เปลี่ยนโครงสร้าง response JSON ที่ UI ใช้อยู่
- ไม่แตะ Time Engine / Token Engine / dag execution core

---

## Files ที่เกี่ยวข้อง

**Core:**

- `source/BGERP/Helper/LegacyRoutingAdapter.php`
- `source/hatthasilpa_job_ticket.php`
- `source/pwa_scan_api.php`

**Config / Feature Flag:**

- ถ้ามี feature flag catalog:
  - `database/tenant_migrations/*feature_flag_catalog*.php`
  - หรือเพิ่ม migration ใหม่: `2025_12_routing_v1_feature_flag.php`
- ถ้ามี global config สำหรับ feature flags:
  - `config.php` หรือ helper ที่เกี่ยวข้อง

**Logging (ถ้ามี helper):**

- `source/helper/LogHelper.php` (หรือ class log ตัวหลักที่ใช้อยู่ในโปรเจกต์)

**Docs:**

- `docs/dag/task_index.md`
- `docs/migration/migration_integrity_map.md` (อัปเดต mapping ฝั่ง routing)

---

## Detailed Plan

### 1) เพิ่ม Feature Flag: `FF_ALLOW_ROUTING_V1_FALLBACK`

**Migration ใหม่** (ถ้าใช้ feature_flag_catalog):

- สร้างไฟล์: `database/tenant_migrations/2025_12_routing_v1_feature_flag.php`
  - Insert row:
    - `code` = `FF_ALLOW_ROUTING_V1_FALLBACK`
    - `description` = "Allow fallback to legacy routing V1 tables"
    - `default_value` = 1 (DEV / STAGING)
  - Idempotent (`INSERT IGNORE` หรือ `ON DUPLICATE KEY UPDATE`)

**Helper (ถ้ามี):**

- เพิ่มใน feature flag helper:
  - method `isRoutingV1FallbackAllowed(): bool`
  - ใช้ config/DB flag ตามมาตรฐานระบบของเรา

---

### 2) ปรับ `LegacyRoutingAdapter` ให้มี 2 mode

ไฟล์: `source/BGERP/Helper/LegacyRoutingAdapter.php`

**เพิ่ม:**

- property:
  - `private bool $allowFallback;`
- constructor รองรับการรับ flag หรืออ่านจาก feature flag helper
- method ใหม่:
  - `private function logFallbackUsage(array $context): void`
    - ใช้ `LogHelper` หรือ DB log table (ง่ายสุดตอนนี้: LogHelper + prefix ชัดเจนเช่น `[LegacyRoutingFallback] ...`)

**Behavior:**

1. ทุกเมธอดหลักของ adapter (เช่น `getRoutingForProduct`, `getStepsForProduct` ฯลฯ):

   - ลองใช้ V2 ตามเดิม:
     ```php
     $v2 = $this->loadFromV2(...);
     if ($v2 !== null) {
         return $v2;
     }
     ```

   - ถ้า V2 ไม่มี:
     - ถ้า `$this->allowFallback === false`:
       - return `null` หรือ throw exception ที่แปลงเป็น error JSON ที่ API ได้
       - ห้าม silently ไปใช้ V1
     - ถ้า `$this->allowFallback === true`:
       - ก่อน query V1 ให้เรียก `logFallbackUsage([...context...])`
       - แล้วค่อย query จาก V1

2. `logFallbackUsage()`:
   - Parameters:
     - `caller` (string)
     - `tenant_code`
     - `product_id`, `mo_id`, `job_ticket_id` (ถ้ามี)
     - `routing_id` (ถ้าทราบหลัง query)
   - ลง log ผ่าน `LogHelper::info(...)` หรือ `error(...)` พร้อม JSON context

---

### 3) อัปเดต Callers ให้ส่ง context + caller id

ไฟล์: `source/hatthasilpa_job_ticket.php`

- ทุกจุดที่สร้าง `LegacyRoutingAdapter`:
  - เพิ่ม param `caller = 'hatthasilpa_job_ticket'`
  - ส่ง context เช่น:
    - `job_ticket_id`
    - `product_id`
    - `mo_id` ถ้ามีอยู่แล้วใน scope

ไฟล์: `source/pwa_scan_api.php`

- ทุกจุดที่เรียก adapter:
  - ส่ง `caller = 'pwa_scan_api'`
  - context:
    - `token_id`
    - `product_id`
    - `mo_id` (ถ้ามี)
    - `node_id` (optional)

**แนวคิด:** ไม่ต้องทำให้เป็น generic สุดโต่ง แต่ให้ log พอที่จะตามรอยได้ว่ามี tenant/production case ไหนยังพึ่ง V1 routing อยู่

---

### 4) Error Contract เมื่อ fallback ถูกปิด

ถ้า `FF_ALLOW_ROUTING_V1_FALLBACK = 0`:

- ให้ adapter:
  - ไม่ query V1
  - คืน `null` หรือ throw `RoutingV1DisabledException`
- ให้ API layer (hatthasilpa_job_ticket / pwa_scan_api):

  - จับ error แล้วคืน JSON ประมาณ:

    ```json
    {
      "ok": false,
      "error": "ROUTING_V1_DISABLED",
      "message": "Routing V1 ถูกปิดใช้งานสำหรับ tenant นี้ โปรดสร้าง DAG Routing ใหม่",
      "hint": "กรุณาให้ supervisor หรือ admin ตรวจสอบ routing configuration"
    }
    ```

- ห้าม “เงียบ” หรือส่ง array ว่างแบบไม่มีคำอธิบาย  
- จุดนี้ยังไม่ต้อง UI สวยมาก แต่ต้อง “ไม่หลอก” ผู้ใช้

---

### 5) Documentation & Tracking

**อัปเดต:**

- `docs/dag/task_index.md`
  - เพิ่ม Task 14.1.9 ในรายการ active/completed (แล้วแต่สถานะ)

- `docs/migration/migration_integrity_map.md`
  - แก้ Section: Routing
    - เพิ่ม row: `FF_ALLOW_ROUTING_V1_FALLBACK`
    - เพิ่ม note ว่า V1 ยังอยู่ใน mode: `ARCHIVE+INSTRUMENTED`

- สร้าง `docs/dag/tasks/task14.1.9_results.md` หลังรันและทดสอบเสร็จ:
  - บันทึก:
    - ค่า default ของ flag ในแต่ละ environment (dev/staging/prod)
    - sample ของ fallback logs ที่บันทึกได้
    - tenant/product ที่ยังใช้ V1 อยู่ (ถ้ามี)

---

## Definition of Done

1. ✅ `LegacyRoutingAdapter`:
   - รองรับ feature flag
   - log ทุกครั้งที่ fallback ไป V1
   - ไม่ fallback ถ้า flag ปิด

2. ✅ Callers (`hatthasilpa_job_ticket.php`, `pwa_scan_api.php`):
   - ส่ง caller id + context ให้ adapter
   - จัดการ error `ROUTING_V1_DISABLED` ได้แบบ controlled

3. ✅ Feature Flag:
   - มี migration/definition ที่ชัดเจน
   - อ่านจาก code ได้จริง (ไม่ใช่ hard-code)

4. ✅ Safety:
   - DEV/STAGING: เปิด fallback, เช็คว่า log ถูกยิง
   - Tenant ใหม่ (หรือ environment ที่ตั้งใจ): สามารถปิด fallback ได้ และ error message ชัด

5. ✅ Docs:
   - task14.1.9.md (ไฟล์นี้)
   - task14.1.9_results.md (สรุปผลหลังทำ)
   - migration_integrity_map.md อัปเดต routing section

---

## Test Plan (สรุปสั้น ๆ)

1. **Case A: V2 มี routing ครบ**
   - Expect: ไม่แตะ V1, ไม่มี log fallback, behavior เหมือนเดิม

2. **Case B: V2 ไม่มี routing, flag = ON**
   - Expect: fallback ไป V1
   - มี log `[LegacyRoutingFallback]` พร้อม context
   - UI ใช้งานได้เหมือนเดิม

3. **Case C: V2 ไม่มี routing, flag = OFF**
   - Expect: ไม่ access V1
   - API คืน `ROUTING_V1_DISABLED`
   - UI แสดง error ชัดเจน (หรืออย่างน้อยไม่พังเงียบ)

4. **Case D: Tenant ใหม่ที่ไม่มี routing V1 เลย**
   - Expect: ไม่มี log fallback เกิดขึ้น
   - ใช้ DAG routing ล้วน ๆ