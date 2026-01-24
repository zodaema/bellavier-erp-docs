# Implementation Checklist (MUST DO EVERY TIME)

**Purpose:** เอกสารหน้าเดียวจบสำหรับทีมและ AI Agent เพื่อทำให้การ Implement ใหม่ “เป็นมาตรฐานเดียวกันทุกครั้ง”  
**Scope:** PHP APIs, Frontend JS, security (CSRF/Rate limit), database semantics, testing & smoke checks  
**Source of truth (code):**
- Backend API template: `source/api_template.php`
- CSRF token endpoint: `source/security_api.php`
- Frontend standards: `assets/javascripts/global_script.js` (`BG.api`, `BG.ui`)

---

## Pre-flight (ก่อนแตะโค้ด)

- **อ่านอย่างน้อย**
  - `docs/developer/01-policy/DEVELOPER_POLICY.md`
  - `docs/developer/02-quick-start/AI_QUICK_START.md`
- **ห้ามสร้างซ้ำ**
  - ค้นหาไฟล์/ฟังก์ชัน/endpoint ที่คล้ายกันก่อน (`grep`, `glob_file_search`)
- **กำหนดขอบเขต**
  - งานนี้แตะ “tenant API” หรือ “core/platform API” หรือ “frontend only”
- **ตั้งมาตรฐานตอบกลับ**
  - JSON ต้องเป็น `{ ok: true/false }` และใช้ `json_success()` / `json_error()` เท่านั้น

---

## Backend API (PHP) – มาตรฐานขั้นต่ำที่ต้องมี

### 1) เลือก bootstrap ให้ถูก (สำคัญ)

- **Tenant-scoped API** (ส่วนใหญ่ของหน้าในระบบ): ใช้ `TenantApiBootstrap::init()`
  - คืนค่า: `[$org, $db]` โดย `$db` คือ `BGERP\Helper\DatabaseHelper`
- **Core/Platform API**: ใช้ `CoreApiBootstrap::init([...])`
  - คืนค่า: `[$member, $coreDb, $tenantDb, $org, $cid]`

### 2) Security rails ที่ต้องทำทุกครั้ง

- **Maintenance mode**
  - ต้องถูก block เมื่อมีไฟล์ `storage/maintenance.flag` (503 + Retry-After)
- **Rate limiting**
  - ต้องมี `RateLimiter::check(...)` หลัง auth
- **CSRF**
  - สำหรับ state-changing actions (create/update/delete/save/upload/ฯลฯ) ต้อง validate CSRF token
  - Token source: `source/security_api.php?action=csrf_token&scope={scope}`

### 3) Request validation

- ทุก input จาก user ต้องผ่าน `RequestValidator::make($data, $rules)`
- ห้ามเช็ค `isset()/trim()` แบบ manual กระจัดกระจาย (ทำให้ error format ไม่มาตรฐาน)

### 4) Database rules (Zero tolerance)

- **Prepared statements เท่านั้น**
- **Tenant isolation**
  - ใช้ tenant db ที่ได้จาก bootstrap เท่านั้น (ห้าม cross-tenant)

### 5) `DatabaseHelper::execute()` semantics (กัน bug “กดบันทึกทั้งที่ไม่เปลี่ยนค่าแล้ว error”)

`DatabaseHelper::execute()` จะคืนค่า:
- `false` = DB error
- `0,1,2,...` = affected rows (0 คือ “no-op / ไม่ได้เปลี่ยนแปลง”)

**Rule:** ห้ามเขียน `if (!$ok)` เพราะ `0` จะถูกมองเป็น error  
ให้ใช้:
- `if ($ok === false) { /* error */ }`

### 6) Error handling & logging

- ต้องมี try/catch ระดับบนสุด (top-level)
- log ต้องมี correlation id รูปแบบประมาณ:
  - `[CID:{cid}][{File}][User:{id}][Action:{action}] ...`
- ห้าม silent catch

---

## Frontend (JS) – มาตรฐานเดียวกันทุกไฟล์

### 1) ห้ามใช้ browser native dialogs

- ❌ `alert()`, `confirm()`, `prompt()`
- ✅ ใช้:
  - `BG.ui.toastSuccess()`, `BG.ui.toastError()`, `BG.ui.toastInfo()`
  - `await BG.ui.confirmDialog({...})`

### 2) ห้ามยิง API แบบกระจัดกระจาย

- ✅ ใช้ `BG.api.request({ url, method, data, scope? })`
  - ใส่ `X-Correlation-Id` อัตโนมัติ
  - ใส่ `X-CSRF-Token` อัตโนมัติใน request ที่เป็น state-changing
  - normalize error ให้เป็น `{ ok:false, error, app_code, meta }`

### 3) i18n ใน UI

- ข้อความที่เห็นใน UI ต้องใช้ `t('key', 'English fallback')`
- ห้าม hardcode ข้อความภาษาไทยใน JS/PHP

### 4) “No-op / No changes” UX มาตรฐาน

บาง endpoint จงใจตอบกลับ “no changes” (เช่น `MO_400_NO_CHANGES`) เพื่อกัน write โดยไม่จำเป็น

**Rule (Frontend):**
- ถ้า `resp.ok === false` แต่เป็น `app_code` ที่จัดเป็น non-fatal → แสดงเป็น **info** และไม่ทำให้ flow พัง
- ตัวอย่าง: `MO_400_NO_CHANGES` → toast info + ปิด modal (ถ้าอยู่ใน modal)

> รายการ non-fatal app_codes ให้เพิ่มใน `assets/javascripts/global_script.js` (`NON_FATAL_APP_CODES`)

### 5) Upload / FormData

ถ้าต้องใช้ `$.ajax` แบบ `FormData`:
- ขอ token ก่อนด้วย `await BG.api.getCsrfToken(scope)` และส่ง header `X-CSRF-Token`

---

## Testing (ห้ามข้ามเมื่อแตะ backend/service)

### Minimum local checks

- **PHPUnit**
  - `vendor/bin/phpunit`
- **Smoke test (manual)**
  - เปิดหน้าเป้าหมาย → เปิด F12 (Console/Network)
  - ทดสอบ action ที่แก้:
    - click ครั้งแรกต้องไม่ fail (เช่น CSRF token fetch)
    - save แบบ “ไม่เปลี่ยนค่า” ต้องไม่เป็น error ที่ทำให้ UX พัง
    - modal ต้องปิด/รีเฟรช state ตามที่คาด

---

## Definition of Done (DoD) – งานถือว่า “จบ” เมื่อ

- **Backend**
  - มี bootstrap + rate limit + validation + CSRF (สำหรับ state-changing)
  - ไม่มี `if (!$ok)` กับผลลัพธ์ `DatabaseHelper::execute()`
  - error format มาตรฐาน `{ ok:false, error, app_code }`
- **Frontend**
  - ใช้ `BG.api.request()` สำหรับ call ที่เป็นมาตรฐาน
  - ไม่มี `alert/confirm`
  - no-op ถูกจัดการเป็น info (ถ้าเป็น intentional app_code)
- **Tests**
  - ผ่าน `vendor/bin/phpunit` และ smoke test จุดหลักแล้ว


