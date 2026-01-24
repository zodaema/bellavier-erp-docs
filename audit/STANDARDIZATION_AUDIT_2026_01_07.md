# 🔍 Standardization Audit — APIs & Frontend (RBAC / CSRF / Enterprise Patterns)

**Date:** 2026-01-07  
**Scope:** `source/**` (PHP endpoints) + `assets/javascripts/**` (frontend JS)  
**Goal:** ระบุ “ไฟล์ที่ควรยกระดับให้เข้ามาตรฐานปัจจุบัน” เช่น Bootstrap/RBAC/CSRF/RateLimit/Validation/JSON format/i18n/UX patterns  
**Output:** รายการไฟล์ + ความเสี่ยง + แนวทางแก้แบบ staged (P0/P1/P2)

> หมายเหตุ: Audit นี้ใช้ **heuristics จากการสแกนโค้ด** (ไม่ใช่ static analysis เต็มรูปแบบ)  
> บางไฟล์อาจถูก flag เกินจริง (false positive) — ต้องมี “manual confirm” ก่อนลงมือแก้จริงทีละไฟล์

---

## 1) นิยาม “มาตรฐานปัจจุบัน” (Current Standard)

### 1.1 Backend API (PHP)
มาตรฐาน Enterprise สำหรับ endpoint ที่เข้าถึงได้ (reachable):
- **Bootstrap**: `TenantApiBootstrap::init()` หรือ `CoreApiBootstrap::init()`
- **RBAC**: `must_allow_code($member, 'perm.code')` (หรือ helper ที่เทียบเท่า)
- **Rate limit**: `RateLimiter::check($member, ...)`
- **Validation**: `RequestValidator::make($data, $rules)`
- **CSRF**: `validateCsrfToken(...)` สำหรับ state‑changing operations (POST/PUT/DELETE/สร้าง/แก้/ลบ/อัปโหลด)
- **Standard JSON**: `json_success/json_error` หรือ `JsonResponse`/`TenantApiOutput` (รูปแบบ `{ok: true|false}`)
- **Idempotency**: `Idempotency::guard/store` สำหรับ create
- **ETag/If‑Match**: สำหรับ update ที่ต้องกัน concurrent write

### 1.2 Frontend JS
- **No `alert()` / `confirm()`**: ใช้ `Swal.fire()` หรือ notification helpers
- **Response contract**: ใช้ `response.ok` (ไม่ใช้ `response.success`)
- **XSS safety**: หลีกเลี่ยง `.html()/innerHTML/insertAdjacentHTML` กับข้อมูลที่มาจากผู้ใช้/จาก API หากไม่ escape
- **i18n**: UI text ใช้ `t(key, fallback)` (fallback เป็น English)

---

## 2) สรุปผลการสแกน (Summary)

### 2.1 PHP Endpoints
- **Flagged:** 74 ไฟล์  
- **P0:** 10 (เสี่ยงสูง/ควรจัดก่อน)  
- **P1:** 60 (ต้องยกระดับมาตรฐานใน roadmap)  
- **P2:** 4 (ตามเก็บ/ลด debt)

### 2.2 Frontend JS
- **Flagged:** 64 ไฟล์  
- **P1:** 30 (มี `alert/confirm` หรือ contract ผิด)  
- **P2:** 34 (พบ “HTML injection sinks” ต้อง review/escape)

---

## 3) P0 — ต้องจัดก่อน (Security/Consistency Breakers)

> P0 หมายถึง: reachable endpoint ที่หลุดมาตรฐานสำคัญหลายข้อ หรือมี surface ที่ audit ชอบจับ (public/upload/auth)

### 3.1 รายการไฟล์ (P0)
- `source/media/ci_media.php`
  - **Gap:** ไม่มี bootstrap/rate limit/validator/RBAC/CSRF + response format ไม่ใช่ `{ok:...}` + upload surface
  - **แนวทางแก้:** ย้ายเข้า “API template” (หรือสร้าง wrapper ใหม่) แล้วคุม auth + permission + CSRF + file type/size allowlist

- `source/api/public/serial_verify_api.php`
  - **Gap:** ไม่ใช้ bootstrap/rate limit/validator/RBAC/standard JSON (manual json_encode)
  - **แนวทางแก้:** ทำเป็น public API แบบมี rate limit (IP‑based) + standard JSON + strict input validation

- `source/dag_graph_api.php` และ `source/dag/dag_graph_api.php`
  - **Gap:** missing bootstrap/RBAC/CSRF (ตาม heuristic)
  - **แนวทางแก้:** ยืนยันว่าใช้งานตัวไหนเป็น canonical แล้วค่อย refactor ให้เข้ามาตรฐานเดียว

- `source/defect_catalog_api.php`
  - **Gap:** missing bootstrap/validator/CSRF (ตาม heuristic)
  - **แนวทางแก้:** ปรับให้ใช้ bootstrap + RequestValidator + CSRF สำหรับ create/update/delete

- `source/job_ticket_dag.php`
  - **Gap:** missing bootstrap/rate limit/validator/CSRF (ตาม heuristic)
  - **แนวทางแก้:** ปรับตาม template และบังคับ validation/CSRF บน state‑changing actions

- `source/export_csv.php`, `source/notifications.php`, `source/system_log.php`, `source/member.php`, `source/profile.php`
  - **Gap:** missing bootstrap/RBAC/CSRF/standard JSON (บางไฟล์)
  - **แนวทางแก้:** จัดเป็นชุด “legacy/admin hardening” ตามมาตรฐานเดียวกับ enterprise audit

---

## 4) P1 — ยกระดับมาตรฐาน (ควรทำใน Q1–Q2)

> P1 ส่วนใหญ่คือ “ขาด CSRF coverage สำหรับ state‑changing actions” หรือ “ขาด validator/rbac ในบางไฟล์”

### 4.1 กลุ่ม A — Missing CSRF for state‑changing operations (flagged)
ไฟล์ตัวอย่าง (จำนวนมาก):
- `source/products.php`, `source/product_api.php`
- `source/dag_token_api.php`, `source/dag_routing_api.php`
- `source/assignment_api.php`, `source/team_api.php`
- `source/materials.php`, `source/grn.php`, `source/issue.php`, `source/transfer.php`, `source/adjust.php`, ฯลฯ

**แนวทางแก้มาตรฐาน:**
- ระบุ action ที่เป็น state‑changing ให้ชัด (create/update/delete/publish/upload)
- บังคับ CSRF token เฉพาะ action เหล่านั้น (อย่าใส่กับ read‑only)
- เพิ่ม test/checklist ให้ enforce “ทุก state‑changing ต้องมี CSRF”

### 4.2 กลุ่ม B — Missing Validator/RBAC/RateLimit ในบาง endpoints (flagged)
ตัวอย่าง:
- `source/pwa_scan_api.php` (missing validator + CSRF ตาม heuristic)
- `source/trace_api.php` (missing validator + CSRF)
- `source/exceptions_api.php` (missing validator + RBAC)
- `source/platform_*_api.php` บางไฟล์ (missing validator/RBAC)

**แนวทางแก้มาตรฐาน:**
- ย้าย input ทั้งหมดเข้า `RequestValidator::make()`
- ตรวจ permission ทุก action ที่แก้ข้อมูล (RBAC)
- ตรวจ rate limit ให้ครบทุก endpoint ที่ reachable

---

## 5) P2 — Debt reduction (ตามเก็บ)

ไฟล์ที่ถูก flag เช่น:
- `source/admin_feature_flags_api.php` (missing rbac)
- `source/dag_supervisor_sessions.php` (missing rbac)
- `source/dashboard_qc_metrics.php` (missing rbac)
- `source/sales_report.php` (missing rbac)

---

## 6) Frontend JS Audit

### 6.1 P1 — ใช้ `alert()`/`confirm()` หรือ contract ผิด
ตัวอย่างไฟล์:
- `assets/javascripts/login/login.js` (alert)
- `assets/javascripts/materials/materials.js`, `assets/javascripts/warehouses/warehouses.js`, `assets/javascripts/product_categories/product_categories.js`, ฯลฯ
- `assets/javascripts/dag/graph_designer.js` (confirm)

**แนวทางแก้:**
- แทนที่ด้วย `Swal.fire()` + `notifySuccess/notifyError`
- คุมข้อความผ่าน `t(key, fallback)`

### 6.2 P2 — พบ HTML injection sinks (`.html()/innerHTML/...`)
ตัวอย่างไฟล์:
- `assets/javascripts/products/product_workspace.js` (ใหญ่/ซับซ้อน — ต้อง review จุดที่ inject HTML)
- `assets/javascripts/token/management.js`, `assets/javascripts/trace/*.js`, `assets/javascripts/dag/*.js`, ฯลฯ

**แนวทางแก้ (แนว audit‑ready):**
- แยก “trusted HTML template” vs “user/API data”
- สำหรับ data ให้ใช้ `.text()`/`textContent` หรือ helper `escapeHtml()` ก่อนนำไปประกอบเป็น HTML
- ถ้าจำเป็นต้องใช้ HTML ให้ทำ whitelist + sanitize

---

## 7) แผนแก้แบบ staged (แนะนำ)

### Stage 0 — Confirm reachability (1–2 วัน)
- ทำ inventory ว่า endpoint ไหน “ถูกเรียกจริง” จากหน้าไหน/JS ไหน
- ตัด scope: ภายในเท่านั้น vs public/partner/customer

### Stage 1 — P0 fixes (1–2 สัปดาห์)
- Harden upload/public/auth‑adjacent endpoints ให้เข้า template + security controls
- เพิ่ม tests/checks กัน regression

### Stage 2 — CSRF coverage expansion (2–4 สัปดาห์)
- ทำ policy + implementation pattern + rollout ทีละชุดไฟล์ (ไม่ refactor ใหญ่)

### Stage 3 — JS UX & XSS hardening (ต่อเนื่อง)
- ลบ alert/confirm ทั้งหมด
- ตรวจและทำ safe rendering ในจุด HTML injection sinks

---

## 8) การเชื่อมกับ Roadmap

Roadmap canonical: `docs/ROADMAP_LUXURY_WORLD_CLASS.md`  
- Epic F1 (Uniform security posture) ควรอ้างอิง audit นี้เป็น “source of work”

---

## 9) Implementation Tasks (Low risk → High risk)

เป้าหมายของชุดงานนี้คือ “ทำให้ทุกไฟล์ใช้มาตรฐานเดียวกัน” โดย **เริ่มจากงานที่ไม่กระทบ behavior มาก** แล้วค่อยไล่ไปยังงานที่มีโอกาสแตก/ต้องเทสหนัก

> นิยามความเสี่ยง:
> - **Low risk**: เปลี่ยนเฉพาะ UI/ข้อความ/โค้ด helper แบบ additive ไม่แตะการอนุมัติสิทธิ์หรือ contract ของ API เดิม
> - **Medium risk**: เพิ่มการตรวจ (CSRF/RBAC/validation) เฉพาะบาง action/บาง endpoint และมี rollback plan
> - **High risk**: แตะ orchestrator/flow หลัก, เปลี่ยน response contract, หรือ migrate legacy endpoint ใหญ่

### 9.0 Foundation (DONE ✅) — ทำให้ “ต้นแบบเดียว” ครบก่อน
งานนี้ทำเสร็จแล้วเพื่อป้องกันสปาเกตตี้:
- ✅ `source/api_template.php` (canonical tenant API template): output enforcement + trace wrappers + CSRF pattern
- ✅ `source/security_api.php` (central CSRF token endpoint): `action=csrf_token&scope=...`
- ✅ `assets/javascripts/global_script.js`: `BG.api.request()` ใส่ correlation id + แนบ CSRF header + retry once

**DoD:**
- `php -l source/api_template.php` และ `php -l source/security_api.php` ผ่าน
- ไม่มี lints ใหม่ในไฟล์ที่แก้

---

### 9.1 LOW RISK — Frontend UX consistency (No alert/confirm)
**Goal:** ทำให้ UI ไม่ใช้ `alert()/confirm()` (ย้ายไป Swal/toast) โดยไม่แตะ backend

**Tasks:**
- แทนที่ `alert()` / `confirm()` ในไฟล์ JS ที่ถูก flag เป็น P1
  - ตัวอย่าง: `assets/javascripts/adjust/adjust.js`, `assets/javascripts/materials/materials.js`, `assets/javascripts/warehouses/warehouses.js`, `assets/javascripts/bom/bom.js`, ฯลฯ

**DoD (ขั้นต่ำ):**
- ไม่มี `alert(` / `confirm(` ในไฟล์ที่แก้
- Smoke test 3 flows ต่อโมดูล (create/update/delete หรือ action สำคัญ)

**Risk notes:** ต่ำมาก (กระทบ UX/การยืนยันเท่านั้น)

---

### 9.2 LOW RISK — Frontend adopts centralized API client (opt-in)
**Goal:** เริ่มให้หน้าใหม่/หน้าที่แก้บ่อย ใช้ `BG.api.request()` แทน `$.ajax/$.post`

**Tasks:**
- เลือก 1–3 หน้าที่ traffic ต่ำ (เช่น admin/tool pages) แล้วเปลี่ยนเฉพาะ state-changing calls ให้เรียก:
  - `BG.api.request({ url, method:'POST', data:{...} })`
- ไม่ต้องแก้ทุกหน้าในครั้งเดียว

**DoD:**
- ฟังก์ชันเดิมทำงานเหมือนเดิม
- Network tab เห็น `X-Correlation-Id` และ (สำหรับ POST) `X-CSRF-Token`

**Risk notes:** ต่ำ (เป็นการเปลี่ยน client wrapper เฉพาะจุด)

---

### 9.3 MEDIUM RISK — “CSRF soft rollout” (enforce เฉพาะ endpoint เล็กก่อน)
**Goal:** เปิด CSRF enforcement แบบ staged เพื่อลดการนั่งไล่เทสทุกหน้า

**Tasks:**
- เลือก endpoint ที่ไม่ใช่ core orchestration (ไม่ใช่ DAG start/spawn/route) ก่อน 1–2 ไฟล์
- เปิด CSRF check เฉพาะ action ที่เป็น state-changing (create/update/delete/publish/upload)
- ฝั่ง JS ให้เรียกผ่าน `BG.api.request()` (เพื่อแนบ CSRF header)

**DoD:**
- หน้าสำคัญของโมดูลนั้นผ่าน smoke test (happy path + invalid token 1 case)
- Error response เป็น `{ok:false, error:'invalid_csrf_token', app_code:'SEC_403_INVALID_CSRF'}`

**Rollback plan:**
- ถ้าเจอ break แบบกว้าง ให้ปิด CSRF enforcement เฉพาะไฟล์นั้น (temporary) แล้วแก้ client ก่อน

---

### 9.4 MEDIUM RISK — RBAC normalization (เติม permission ที่ขาด)
**Goal:** ไฟล์ที่ถูก flag ว่า missing RBAC ให้เข้าสู่ `must_allow_code()` ที่ชัดเจน

**Tasks:**
- เริ่มจาก P2 ก่อน (scope เล็ก): `source/sales_report.php`, `source/dashboard_qc_metrics.php`, `source/dag_supervisor_sessions.php`, `source/admin_feature_flags_api.php`
- ทำ permission mapping ให้ชัดว่า action ไหนเป็น view/manage

**DoD:**
- ผู้ใช้ role ที่ไม่มีสิทธิ์ถูกปฏิเสธด้วย 403 แบบมาตรฐาน
- ผู้ใช้ที่มีสิทธิ์ทำงานได้เหมือนเดิม

**Risk notes:** กลาง (อาจกระทบผู้ใช้บาง role)

---

### 9.5 HIGH RISK — CSRF enforcement บน endpoints หลัก (DAG / production)
**Goal:** ทำให้ core production endpoints เข้าสู่มาตรฐานเดียวกันโดยไม่ทำให้โรงงานหยุด

**Targets (ตัวอย่าง):**
- `source/dag_token_api.php`, `source/dag_routing_api.php`, `source/pwa_scan_api.php`, `source/job_ticket_dag.php`

**Tasks:**
- ทำทีละไฟล์ และ “ทีละ action” (เช่นเริ่มจาก start/pause/complete ก่อน)
- เพิ่ม integration tests ให้ครอบคลุม (idempotency + csrf + permission)
- ทำ rollout ด้วย feature flag/tenant gating (ถ้ามี) หรือเปิดเฉพาะผู้ดูแลก่อน

**DoD:**
- Integration tests + manual E2E (operator flows) ผ่าน
- มี monitoring/metric สำหรับ 403/409/429 spikes หลัง deploy

**Risk notes:** สูง (แตะเส้นเลือดใหญ่ของ runtime)

---

### 9.6 HIGH RISK — Legacy endpoint migration to standard (contract unification)
**Goal:** เอา legacy endpoint ที่ “reachable และเสี่ยง” เข้าสู่ template/standard JSON/RBAC/CSRF

**Targets (P0):**
- `source/media/ci_media.php` (upload surface + custom response format)
- `source/api/public/serial_verify_api.php` (public endpoint)
- `source/notifications.php`, `source/system_log.php`, ฯลฯ (ถ้าถูกใช้งานจริง)

**Tasks:**
- ทำ wrapper ใหม่ตาม `api_template.php` แล้วค่อย deprecate ของเดิมแบบ staged
- รักษา backward compatibility ด้วย alias parameters/response mapping ชั่วคราว

**DoD:**
- หน้า/โมดูลที่เรียก endpoint เดิมไม่พัง
- Response contract ใหม่ถูกใช้เป็นค่าเริ่มต้น และของเดิมถูก mark deprecated

**Risk notes:** สูงมาก (เปลี่ยน contract + surface ใหญ่ ต้องเทสจริง)


