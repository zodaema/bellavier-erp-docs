# Task 23.5 — Integrate ETA Engine with MO Lifecycle (MO Execution Flow Integration)

> Phase: 23 — MO Planning & ETA Intelligence  
> Focus: เชื่อม ETA Engine v1 เข้ากับ MO Lifecycle จริง (create → schedule → produce → complete)  
> Type: Backend Integration + Lifecycle Orchestration (no UI pixel workใน task นี้)

---

## 1. Context & Current State

### 1.1 สิ่งที่มีอยู่แล้ว (Baseline)

จาก Phase 22–23.4 เรามี component ต่อไปนี้อยู่แล้ว และถือว่าเป็น canonical:

1. **Canonical Timeline Layer (Phase 22.x)**  
   - `NodeBehaviorEngine.php` — แปลง node_mode/line_type → canonical events  
   - `TokenEventService.php` — persist canonical events → `token_event`  
   - `TimeEventReader.php` — อ่าน canonical timeline → duration, sessions, start/completed_at  
   - `LocalRepairEngine.php` + `TimelineReconstructionEngine.php` — self healing + repair  
   - `CanonicalEventIntegrityValidator.php` + tools (`dev_token_timeline.php`, `dag_validate_cli.php`) — integrity checks

2. **ETA / Simulation / Health Layer (Phase 23.1–23.4)**  
   - `MOCreateAssistService.php` — ช่วยแนะนำ routing + basic time estimation  
   - `MOLoadSimulationService.php` — simulation engine (station load, worker load, bottleneck detection)  
   - `MOLoadEtaService.php` — ETA engine v1 (node timeline, stage timeline, best/normal/worst)  
   - `MOEtaAuditService.php` — cross-check ETA vs simulation vs canonical  
   - `MOEtaCacheService.php` — ETA cache + signature binding (routing, engine_version, qty, etc.)  
   - `MOEtaHealthService.php` — ETA health validation + metrics aggregation  
   - `mo_eta_api.php` — ETA API (eta, audit, health-summary)  
   - Dev tools: `eta_audit.php`, `eta_monitor.php`, `eta_health_cron.php`

3. **MO Legacy Layer**  
   - `mo.php` — legacy MO creation/update API (classic/oem line)  
   - MO statuses (อย่างน้อย): `draft`, `scheduled`, `in_production`, `completed`, `cancelled` (แม้ naming จริงอาจต่างกันเล็กน้อย แต่มี concept นี้อยู่)

### 1.2 ช่องว่างปัจจุบัน

ตอนนี้ ETA/Simulation/Health:

- **ยังไม่ถูกผูกเข้ากับ MO lifecycle จริง** (create/update/status change) แบบเป็นระบบ  
- ใช้งานผ่าน API/Dev tools แบบ on-demand เป็นหลัก (`mo_eta_api`, `eta_audit`, `eta_monitor`)  
- ยังไม่มีการ update ETA/health แบบอัตโนมัติเมื่อ:
  - มีการเปลี่ยน qty / routing / product / schedule  
  - มี token ถูก complete และ canonical timeline เปลี่ยนจริง  
  - MO เปลี่ยน status (draft → scheduled → in_production → completed)

Task 23.5 คือการ “ต่อสาย” ทุกอย่างเข้าด้วยกันให้เป็น **Close Loop System** สำหรับ Bellavier ERP เท่านั้น (ไม่ต้องเปิด config ให้ user ปรับเอง).

---

## 2. Objective

เป้าหมายของ Task 23.5:

1. **ผูก ETA Engine + Cache + Health เข้ากับ MO lifecycle จริง**  
   - ตอนสร้าง MO ใหม่ → ควรมี ETA baseline  
   - ตอนแก้ไข MO (qty / routing / product / schedule) → ETA ต้องถูก invalidate/recompute อย่างมีระบบ  
   - ตอนเปลี่ยน status MO → ETA/health ต้องถูก lock/unlock ตาม logic ที่กำหนด

2. **สร้าง MO–ETA–Canonical Feedback Loop**  
   - เมื่อมี token ถูก complete → canonical timeline เปลี่ยน → health/ETA ต้องรับรู้ได้ (อย่างน้อยในระดับ alert/log)  
   - Drift ระหว่าง ETA กับ canonical ต้องถูกตรวจจับผ่าน `MOEtaHealthService` (แต่ไม่ block การผลิต)

3. **คง principle ของ Close System & Fixed Logic**  
   - ไม่มีการเพิ่ม “setting” ให้ user เลือก logic เอง  
   - Logic framework ถูก design จากส่วนกลาง เพื่อใช้ภายในองค์กร Bellavier Group เท่านั้น

---

## 3. Scope & Non-Scope

### 3.1 In Scope

- เชื่อม `MOEtaCacheService` เข้ากับ MO creation / update / status change
- เพิ่ม hook บางจุดใน `mo.php` (legacy API) ให้เรียก ETA/Cache/Health ตามลำดับที่เหมาะสม
- เพิ่ม helper methods ใน `MOEtaHealthService` สำหรับตรวจ drift ในระดับ MO หลัง token completion
- ปรับ `MOCreateAssistService` ให้สามารถคืน ETA summary (ถ้า context พร้อม)
- สร้างเอกสาร `task23_5_results.md` สรุป implementation

### 3.2 Out of Scope (ใน Task นี้)

- ไม่ทำ UI pixel-level (เช่น ปรับหน้า MO list / MO detail ใน frontend) — แค่เตรียม data shape สำหรับนำไปใช้  
- ไม่เปลี่ยน structure ของตาราง MO (ไม่เพิ่ม column ใหม่ใน DB)  
- ไม่เปลี่ยน behavior ของ TokenLifecycleService ในส่วน non-ETA (เช่น routing/graph move)  
- ไม่ทำ “Auto-reschedule MO ทั้ง batch” — แค่ผูก ETA กับ MO เดี่ยวให้แน่นก่อน

---

## 4. Design Overview (High-Level)

### 4.1 Touchpoints ที่ต้อง Integrate

1. **MO Creation (Create)**  
   - เมื่อ MO ใหม่นั้น validated แล้ว และมี product + routing + qty ครบ
   - สร้าง ETA baseline (ผ่าน `MOEtaCacheService::getOrCompute`)
   - เก็บ ETA summary ไว้ใน response (ไม่จำเป็นต้อง persist ลง table MO ตอนนี้ — ใช้ cache + API พอ)

2. **MO Update (Update)**  
   - ถ้ามีการแก้ไข field สำคัญ: `product_id`, `id_routing_graph`, `qty`  
     → invalidate cache + compute ETA ใหม่ (optional immediate compute หรือ lazy compute ผ่าน API ก็ได้ แต่ต้องระบุ clearly)
   - ถ้าเปลี่ยน schedule date อย่างเดียว  
     → อนุญาตให้ shift ETA (ความหมายคือ baseline เหมือนเดิม แต่จุดเริ่มเลื่อน)

3. **MO Status Transition**  
   - `draft` → `scheduled`  
     → ETA ถูกถือว่าเป็น “baseline plan”  
   - `scheduled` → `in_production`  
     → lock baseline (ไม่ re-plan ง่าย ๆ)  
   - `in_production` → `completed` / `cancelled`  
     → finalize ETA สำหรับ historical analysis; health freeze

4. **Token Completion (Canonical Events)**  
   - หลัง `TokenLifecycleService::completeToken()` run เสร็จ (และ canonical events/TimeEventReader sync เสร็จ)  
   - เรียก health check บางตัวจาก `MOEtaHealthService` (non-blocking) เพื่อ log drift / problems ระดับ MO

### 4.2 Principle

- **Non-blocking**: หาก ETA/Health ล้มเหลว → ต้องไม่ block MO creation/update/production
- **Best-effort**: ETA/Health พยายามทำงานตามข้อมูลที่มี แต่ไม่บังคับว่า MO ต้องมี ETA เสมอ (เช่น กรณี routing ผิดปกติ)
- **Close System**: ไม่มี setting ให้ลูกค้าเปลี่ยน logic; logic ถูกผูกกับ code

---

## 5. Implementation Plan (Subtasks)

> หมายเหตุ: ตัวเลขย่อย (23.5.1, 23.5.2, …) เป็น logical grouping สำหรับเอกสาร/Agent ไม่ได้บังคับให้ต้องสร้างไฟล์ task ย่อยเพิ่ม

### 5.1 Subtask 23.5.1 — Wire ETA into MO Creation & Update

#### 5.1.1 แก้ `MOCreateAssistService.php`

- เพิ่ม method ใหม่ (หรือขยาย method ที่มีอยู่) สำหรับ build ETA preview เมื่อข้อมูลพร้อม เช่น:
  - `buildCreatePreview()` (ถ้ามีแล้ว ให้ขยาย)
  - เพิ่ม field `eta_preview` ใน response (ไม่ต้อง persist DB)

**Logic โดยสรุป:**

- ถ้า:
  - product_id มีค่า
  - routing binding ชัดเจน (`id_routing_graph` หรือ equivalent)
  - qty > 0
- ให้เรียก `MOEtaCacheService` ในโหมด “preview” (ยังไม่ต้องผูกกับ MO จริงถ้ายังไม่มี id_mo)  
  - กรณี create preview: อาจใช้ signature ชั่วคราว (เช่น product_id + routing_id + qty + org_id)  
  - กรณีมี id_mo อยู่แล้ว: สามารถใช้ path ปกติของ cache ได้ (แต่ในขั้นนี้เน้น preview response มากกว่า)

**ETA Preview Response Shape (ตัวอย่าง):**

```json
{
  "eta_preview": {
    "best": "2025-11-30T10:00:00+07:00",
    "normal": "2025-11-30T16:00:00+07:00",
    "worst": "2025-12-01T12:00:00+07:00",
    "risk_level": "yellow",
    "stages": [
      {
        "stage_no": 1,
        "name": "Cutting",
        "eta_normal": "...",
        "risk_factor": 0.8
      }
    ]
  }
}
```

> จุดสำคัญ: ไม่ต้อง push ETA preview ลง DB — แค่ใช้ค่าใน cache + response พอ

#### 5.1.2 แก้ `mo.php` (legacy MO API)

เพิ่ม integration logic ต่อไปนี้ (pseudo-flow):

- หลังจาก MO ถูก create/update สำเร็จ (มี id_mo แน่นอนแล้ว):
  - ตรวจว่า MO นี้เป็น line type/classic ที่ ETA support
  - ตรวจ field ที่เปลี่ยนแปลง:
    - ถ้าเป็น create ใหม่ → เรียก `MOEtaCacheService::getOrCompute()` เพื่อสร้าง ETA baseline ทันที (หรืออย่างน้อย pre-warm cache)
    - ถ้าเป็น update:
      - ถ้า `qty`, `product_id`, `id_routing_graph` เปลี่ยน → `MOEtaCacheService::invalidate($id_mo);` แล้ว optionally `getOrCompute()` ใหม่
      - ถ้าเปลี่ยนแค่ schedule date → ไม่ต้อง invalidate; แค่ใช้ existing ETA + ให้ frontend ไป shift presentation เองใน phase UI

- ใน response ของ `mo.php` (create/update)  
  - optional: ถ้าเรียก ETA แล้ว ให้แนบ ETA summary (best/normal/worst) ไปใน payload ด้วยเพื่อความพร้อมในอนาคต

> ข้อกำหนดสำคัญ:  
> - ETA/Cache ไม่ควร throw fatal error; ให้ catch + log แล้วปล่อยให้ MO ดำเนินต่อได้ปกติ  
> - logic ทั้งหมดต้องอยู่ “หลัง” การ validate/create/update MO จริงเสมอ

---

### 5.2 Subtask 23.5.2 — Status-Aware ETA Lifecycle

#### 5.2.1 ระบุตำแหน่งการเปลี่ยน status ใน `mo.php`

- หา logic ที่เปลี่ยน `status` ของ MO (เช่น confirm, release, complete, cancel)
- สร้าง helper (ภายในไฟล์หรือ service แยก ถ้ามี) เช่น `handleMoStatusTransition($oldStatus, $newStatus, $moRow)`

#### 5.2.2 เพิ่ม logic ต่อไปนี้ใน status transition

เมื่อ status เปลี่ยน:

1. `draft → scheduled`
   - ไม่มี action บังคับ แต่สามารถ:
     - ถ้า ETA ยังไม่มี → precompute ผ่าน cache (optional)

2. `scheduled → in_production`
   - ถือว่า ETA baseline ถูก “ยึด” เป็นแผนเริ่มผลิต
   - ไม่ต้อง invalidate ETA โดยอัตโนมัติเมื่อ status นี้เกิดขึ้น
   - Health/monitoring จะใช้ ETA นี้เป็น baseline ในการวัด drift

3. `in_production → completed`
   - ปล่อยให้ `MOEtaHealthService` + cron ทำหน้าที่ finalize health summary
   - optional: mark ในผลลัพธ์ว่า MO นี้ “ETA_FINALIZED = true” ใน log หรือ summary

4. `* → cancelled`
   - `MOEtaCacheService::invalidate($id_mo)`
   - สร้าง health alert ความหมาย “MO_CANCELLED” เพื่อใช้วิเคราะห์ภายหลัง

> สำคัญ: อย่าให้ status transition logic บังคับให้ ETA/Health ต้อง success — health เป็นระบบสังเกตการณ์ ไม่ใช่ระบบบังคับยุติการเปลี่ยนสถานะ

---

### 5.3 Subtask 23.5.3 — Drift Feedback on Token Completion

#### 5.3.1 แก้ `TokenLifecycleService.php`

ใน `completeToken()` (ซึ่งตอนนี้เชื่อมกับ NodeBehaviorEngine + TokenEventService + TimeEventReader แล้ว):

- หลังจาก canonical events ถูก persist และ `TimeEventReader` sync ค่าลง `flow_token` แล้ว (section ที่อัปเดต `start_at`, `completed_at`, `actual_duration_ms`)
- ให้เพิ่ม logic “best-effort” สำหรับส่งสัญญาณไปยัง MO-level health เช่น:

```php
try {
    /** @var MOEtaHealthService $etaHealth */
    $etaHealth = $this->container->get(MOEtaHealthService::class);
    $etaHealth->onTokenCompleted($tokenId);
} catch (\Throwable $e) {
    // log-only, absolutely non-blocking
}
```

#### 5.3.2 เพิ่ม method ใหม่ใน `MOEtaHealthService.php`

ตัวอย่าง signature:

```php
public function onTokenCompleted(int $tokenId): void
```

Responsibilities (ระดับ minimal ใน Task 23.5):

- Resolve token → instance → MO (ถ้ามี)
- หากหา MO ไม่เจอ → return เงียบ ๆ
- ตรวจว่า MO นี้มี ETA cached อยู่หรือไม่ (optional; ถ้าไม่มี → skip)
- ทำอย่างใดอย่างหนึ่งต่อไปนี้ (ขึ้นกับการ design ภายใน service):
  - mark flag internal ว่า “MO นี้มี canonical updated หลัง ETA baseline”  
  - หรือ trigger validation แบบเบา ๆ เช่นคำนวณ drift เฉพาะ node/stage ที่เกี่ยวข้องและ log ลง `mo_eta_health_log` (ถ้า implementation พร้อม)

> ใน Task 23.5 ไม่ต้องพยายาม implement drift model ที่ซับซ้อน — แค่ทำ plumbing ให้เรียบร้อย และ ensure ว่า call path นี้ “ปลอดภัย” และ “ไม่ block”

---

### 5.4 Subtask 23.5.4 — Documentation & Dev Notes

สร้างไฟล์:

- `docs/super_dag/tasks/results/task23_5_results.md`

ให้มีเนื้อหาขั้นต่ำ:

- Overview ของสิ่งที่ทำใน 23.5 (เชื่อม MO lifecycle ↔ ETA/Cache/Health)
- รายละเอียดไฟล์ที่แก้ (mo.php, MOCreateAssistService.php, TokenLifecycleService.php, MOEtaCacheService.php, MOEtaHealthService.php)
- Design decisions สำคัญ (non-blocking, status-aware, close loop)
- Test cases ที่รันแล้ว (TC23.5-A ถึง TC23.5-G หรือมากกว่านั้น)

---

## 6. Acceptance Criteria

Task 23.5 จะถือว่าสำเร็จเมื่อ:

1. **MO Creation/Update**
   - สร้าง MO ใหม่ (classic/oem) ที่มี product + routing + qty → สามารถเรียก ETA ผ่าน cache ได้สำเร็จ (ผ่าน `MOEtaCacheService`)  
   - เมื่อ qty หรือ routing เปลี่ยน → cache ถูก invalidate ตามคาด และ ETA ใหม่ถูกสร้างได้โดยไม่มี error
   - ถ้า ETA/Cache ล้มเหลว → MO ยังสร้าง/แก้ไขได้ และ error ถูก log โดยไม่มี fatal

2. **Status Integration**
   - ปรับ status MO แล้ว ไม่มี error จาก ETA/Health มาบล็อก flow  
   - เมื่อ MO ถูก cancel → cache invalidated

3. **Token Completion Feedback**
   - เมื่อ token ถูก complete → `onTokenCompleted()` ถูกเรียก (ตรวจผ่าน log)  
   - ไม่มีกรณีที่ token completion ล้มเหลวเพราะ health/ETA

4. **Safety & Non-Regression**
   - Syntax check ผ่านทั้งหมด  
   - ไม่มี breaking change กับ API อื่นที่ใช้ `mo.php` และ ETA API  
   - Tools เดิม (`eta_audit`, `eta_monitor`, `mo_eta_api`) ยังทำงานปกติ

---

## 7. Developer Prompt (for Agent)

ให้ใช้ข้อความนี้เป็น prompt หลักใน Cursor/Agent เมื่อ implement Task 23.5:

```text
You are implementing Task 23.5 — Integrate ETA Engine with MO Lifecycle.

Follow the specification in docs/super_dag/tasks/task23.5.md precisely.

Goals:
- Wire MOEtaCacheService into MO creation and update lifecycle
- Wire MOEtaHealthService into token completion lifecycle (best-effort, non-blocking)
- Make ETA lifecycle aware of MO status transitions
- Do NOT break existing APIs

Steps:
1) Update MOCreateAssistService.php
   - Extend preview/build methods to optionally include an eta_preview block in the response when product, routing, and qty are available.
   - Use MOEtaCacheService or a light-weight ETA call as appropriate (no DB schema changes).

2) Update mo.php (legacy MO API)
   - After successful MO create/update, based on what fields changed, call MOEtaCacheService::invalidate($moId) and/or getOrCompute(...) to pre-warm ETA cache.
   - Ensure this logic is non-blocking: catch all exceptions, log them, but never prevent MO operations.
   - (Optional) Return a compact ETA summary in the response payload if available (best/normal/worst).

3) Update TokenLifecycleService.php
   - In completeToken(), after canonical events and TimeEventReader sync are done, call a new MOEtaHealthService::onTokenCompleted($tokenId) method inside a try/catch that swallows all errors.
   - Do NOT change existing behavior for token completion, status, or routing.

4) Update MOEtaHealthService.php
   - Add public method onTokenCompleted(int $tokenId): void.
   - Implement minimal logic: resolve token → find linked MO (if any) → if MO has ETA cache, optionally perform a light-weight drift/health check and log into mo_eta_health_log (or mark internal state). Keep it best-effort and non-blocking.

5) (If needed) Update MOEtaCacheService.php
   - Only if a small helper is needed for MO-based cache invalidation or light-weight ETA summary access. Do not redesign the service.

6) Create docs/super_dag/tasks/results/task23_5_results.md
   - Summarize all changes, files touched, and key design decisions, plus the main test cases you executed.

Constraints:
- Do not introduce new DB tables or columns in this task.
- Do not change existing API contracts in a breaking way.
- All new logic must be defensive: catch exceptions, log, and never block MO or token completion.
- Keep the system aligned with the Close System principle: no new user-facing settings for ETA.

After changes:
- Run PHP syntax checks on all modified files.
- Ensure mo_eta_api, eta_audit.php, eta_monitor.php, and eta_health_cron.php still work.
```

---

## 8. Notes

- Task 23.5 เป็น “จุดเชื่อม” สำคัญระหว่างโลก Planning (ETA/Simulation) กับโลก Execution (MO + Tokens + Canonical)  
- การ implement ต้องเน้น “ปลอดภัยก่อนแม่นยำ” — Health/ETA เป็นระบบมอนิเตอร์/ช่วยตัดสินใจ ไม่ใช่ระบบบังคับให้ production หยุด

เมื่อ Task 23.5 เสร็จสมบูรณ์ ระบบของ Bellavier ERP จะมี **Close Loop ETA System**:
- ETA คำนวณจาก historic canonical data  
- ถูกใช้จริงใน MO lifecycle  
- และถูกตรวจสอบ/ปรับด้วย canonical timeline ทุกครั้งที่มี token completion



## Dev Tools Index (index_dev.php)

To make it easier to discover and access all internal dev/diagnostic tools, create a `tools/index_dev.php` entry page with a simple HTML dashboard.

Create a file at `tools/index_dev.php` with the following contents:

```php
<?php
// tools/index_dev.php
// Internal Dev Tools Hub for Bellavier ERP
// NOTE: This file is intended for developers / platform admins only.
// Do NOT expose publicly without proper authentication.

require_once __DIR__ . '/../source/bootstrap.php';

// Optional: basic guard to avoid accidental exposure in production
if (defined('APP_ENV') && APP_ENV === 'production') {
    http_response_code(403);
    echo 'Forbidden';
    exit;
}

?><!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Bellavier ERP — Dev Tools Index</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<div class="container py-4">
    <h1 class="mb-4">Bellavier ERP — Dev Tools</h1>
    <p class="text-muted mb-4">
        Internal diagnostics and developer tools. For Bellavier Group developers and platform admins only.
    </p>

    <div class="row g-3">
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header">Canonical / DAG Diagnostics</div>
                <div class="card-body">
                    <ul class="list-unstyled mb-0">
                        <li><a href="dev_token_timeline.php" class="link-primary">Token Timeline Viewer</a></li>
                        <li><a href="dev_timeline_report.php" class="link-primary">Timeline Integrity Report</a></li>
                        <li><a href="dag_validate_cli.php" class="link-primary">DAG Validate CLI (web wrapper if added)</a></li>
                        <li><a href="dag_repair_test_suite.php" class="link-primary">Canonical Repair Test Suite</a></li>
                    </ul>
                </div>
            </div>
        </div>

        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header">ETA / Capacity / MO Tools</div>
                <div class="card-body">
                    <ul class="list-unstyled mb-0">
                        <li><a href="eta_monitor.php" class="link-primary">ETA Health Monitor</a></li>
                        <li><a href="eta_audit.php" class="link-primary">ETA Audit (MO-level)</a></li>
                        <li><a href="mo_eta.php" class="link-primary">MO ETA API Test Page (if applicable)</a></li>
                        <li><a href="mo_load_sim.php" class="link-primary">MO Load Simulation Tool</a></li>
                    </ul>
                </div>
            </div>
        </div>

        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header">Serial / Registry Checks</div>
                <div class="card-body">
                    <ul class="list-unstyled mb-0">
                        <li><a href="serial_health_check.php" class="link-primary">Serial Health Check</a></li>
                        <li><a href="serial_registry_check.php" class="link-primary">Serial Registry Check</a></li>
                        <li><a href="smoke_test_serial_generation.php" class="link-primary">Serial Generation Smoke Test</a></li>
                    </ul>
                </div>
            </div>
        </div>

        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header">Admin / Maintenance Scripts</div>
                <div class="card-body">
                    <ul class="list-unstyled mb-0">
                        <li><a href="audit_operator_roles.php" class="link-primary">Audit Operator Roles</a></li>
                        <li><a href="run_core_migrations.php" class="link-primary">Run Core Migrations</a></li>
                        <li><a href="run_all_tenant_migrations.php" class="link-primary">Run All Tenant Migrations</a></li>
                        <li><a href="run_sample_seed.php" class="link-primary">Run Sample Seed</a></li>
                    </ul>
                    <p class="mt-2 mb-0 small text-muted">Some scripts may be CLI-only; links are for quick reference.</p>
                </div>
            </div>
        </div>
    </div>

    <hr class="my-4">
    <p class="small text-muted">
        Location: <code>tools/index_dev.php</code> — Internal use only. Protect via authentication / IP allowlist in production.
    </p>
</div>
</body>
</html>
```

This page provides a simple categorized index of existing dev tools under the `tools/` directory so developers do not need to remember individual URLs.
