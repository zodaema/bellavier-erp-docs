# Task 10 — Behavior & Routing Validation Guards (Phase 2.5)

**Status:** PLANNED  
**Area:** `super_dag` (Behavior + DAG + Time Engine)  
**Depends on:** Task 5–9 (Behavior Exec, Time Engine Hook, DAG Execution Integration)  

---

## 1. Context

หลังจาก Task 5–9 เราได้สิ่งเหล่านี้แล้ว:

- Behavior layer (CUT / STITCH / EDGE / QC / HARDWARE_ASSEMBLY)
- Behavior UI + Execution (`behavior_ui_templates.js`, `behavior_execution.js`)
- Time Engine integration สำหรับ STITCH (`TokenWorkSessionService`)
- DAG Execution integration (`DagExecutionService`)
- Behavior → DAG routing:
  - `stitch_complete` → complete session + route ไป node ถัดไป
  - `qc_pass` / `qc_fail` / `qc_rework` → route ด้วย `DAGRoutingService`
- Event `BG:TokenRouted` + UI refresh ใน Work Queue / PWA Scan

**แต่ยังขาด “Guard Rails”** เพื่อกันกรณีผิดปกติ เช่น:

- Start ซ้อน, Pause/Resume ใน token ที่ผิดสถานะ
- Complete ใน node ผิด / behavior ไม่ตรง node
- Routing ไป node ถัดไปทั้งที่ DAG ผิด / token อยู่สถานะจบไปแล้ว
- Worker ไม่มีสิทธิ หรือ worker_id ไม่ตรงกับ session ที่เปิดอยู่

Task 10 คือการเพิ่ม **Validation & Safety Guards** รอบ Behavior + Routing  
เพื่อให้ระบบเริ่ม “จับผิด” และ “กันพัง” ได้ ก่อนวิ่งจริงในโรงงาน

---

## 2. Objectives

1. เพิ่ม **Behavior-level validation**:
   - ป้องกันการเรียก `stitch_start` / `stitch_pause` / `stitch_resume` / `stitch_complete` แบบผิดสถานะ
   - ป้องกัน `qc_pass` / `qc_fail` / `qc_rework` ใน context ที่ไม่ถูกต้อง
2. เพิ่ม **Routing-level validation**:
   - ป้องกัน `moveToNextNode()` ใน token/node ที่ไม่ควร move
   - ป้องกัน routing ซ้ำในงานที่ถูก complete แล้ว
3. สร้างมาตรฐาน **error code & message** สำหรับ behavior/routing:
   - เช่น `BEHAVIOR_INVALID_STATE`, `BEHAVIOR_WORKER_MISMATCH`, `DAG_NO_NEXT_NODE`
4. คงไว้ซึ่ง:
   - Backward compatibility ของ API/Response
   - ไม่แตะ Time Engine logic เดิม
   - ไม่แตะ Component Binding Logic (จะมาใน Task Components ภายหลัง)

---

## 3. Scope

### In Scope

- `BehaviorExecutionService` (STITCH + QC handlers)
- `DagExecutionService` (moveToNextNode, moveToNodeId)
- `dag_behavior_exec.php` (mapping error → JSON response)
- Minimal checks ใน Time Engine wrapper (`TokenWorkSessionService` wrapper) ถ้าจำเป็น

### Out of Scope (ห้ามแตะ)

- Database schema (ห้ามสร้าง/แก้ตารางใน Task นี้)
- Component Binding (จะทำใน DAG Components phase)
- QC business rules ลึก ๆ (ใช้แค่ guard พื้นฐาน)
- UI behavior templates (HTML/JS panel — Task 4+5 ทำแล้ว)

---

## 4. Affected Files

Candidate files (ให้ Agent ค้นหา/ใช้จริงตาม tree ปัจจุบัน):

- `source/BGERP/Dag/BehaviorExecutionService.php`
- `source/BGERP/Dag/DagExecutionService.php`
- `source/BGERP/Dag/TokenWorkSessionService.php` (wrapper ใน DAG namespace ถ้ามี)
- `source/dag_behavior_exec.php`

**Note:** ชื่อ class ที่แท้จริงให้อ่านจากโค้ดล่าสุดใน repo; ห้ามสมมติชื่อใหม่

---

## 5. Detailed Requirements

### 5.1 Behavior-level Validation (STITCH)

เพิ่ม validation layer ใน `BehaviorExecutionService::handleStitch()`:

1. **Validate token context ก่อนทำงาน**
   - ต้องมี `id_token` ใน payload
   - Token ต้องอยู่ใน node ที่:
     - มี `behavior_code` = `STITCH`  
     - หรืออย่างน้อย “ไม่ขัดแย้ง” ถ้าปัจจุบันเรายังไม่ได้ enforce behavior/node แบบ strict
   - ถ้า context ไม่พอ → error:
     - `ok: false`
     - `error: "BEHAVIOR_INVALID_CONTEXT"`
     - `app_code: "BEHAVIOR_400_INVALID_CONTEXT"`

2. **Prevent conflicting sessions**
   - ก่อน `stitch_start`:
     - ถ้ามี active session เดิมของ worker เดียวกันและ token เดียวกัน → return error:
       - `error: "BEHAVIOR_SESSION_ALREADY_ACTIVE"`
   - ก่อน `stitch_resume`:
     - ถ้าไม่มี paused session ที่ผูกกับ worker นี้ → return error:
       - `error: "BEHAVIOR_NO_PAUSED_SESSION"`

3. **Token status guards**
   - ห้าม STITCH action ใด ๆ กับ token ที่:
     - สถานะ “completed” หรือ “cancelled”
   - ถ้าเจอ → return:
     - `error: "BEHAVIOR_TOKEN_CLOSED"`
     - `app_code: "BEHAVIOR_409_TOKEN_CLOSED"`

4. **Worker ownership check (ถ้าข้อมูลมีอยู่ใน table session)**
   - ถ้ามี session ที่เปิดโดย worker A แต่ worker B พยายาม resume/pause/complete:
     - return error:
       - `error: "BEHAVIOR_WORKER_MISMATCH"`
       - `app_code: "BEHAVIOR_403_WORKER_MISMATCH"`

> **Important:**  
> ถ้า data model ปัจจุบันยังไม่มี concept “owner” ของ session ให้ใส่ TODO + ทำ check เท่าที่มีได้ โดยไม่เปลี่ยน schema

---

### 5.2 Behavior-level Validation (QC_SINGLE / QC_FINAL)

ใน `BehaviorExecutionService::handleQc()`:

1. **Require qc_result / action ที่ชัดเจน**
   - ถ้า action = `qc_pass` → ต้อง map ไปได้ว่าเป็น pass path
   - ถ้า action = `qc_fail` / `qc_rework` → ต้อง map ไป rework path
   - ถ้า action ไม่อยู่ใน set ที่รองรับ → return:
     - `error: "BEHAVIOR_QC_UNKNOWN_ACTION"`
     - `app_code: "BEHAVIOR_400_QC_UNKNOWN_ACTION"`

2. **Prevent QC on closed tokens**
   - ห้าม QC action ใน token สถานะ “completed/cancelled”
   - Response:
     - `error: "BEHAVIOR_TOKEN_CLOSED"`
     - `app_code: "BEHAVIOR_409_TOKEN_CLOSED"`

3. **Prevent duplicate QC pass**
   - ถ้า token/node นี้ถูก mark ว่า QC ผ่านไปแล้ว (ถ้าระบบมี flag บอก):
     - การกด `qc_pass` ซ้ำควรถูกกันไว้ (หรือน้อยที่สุด log warning)
   - ถ้าไม่มีข้อมูลพอ → ใส่ TODO + log warning

---

### 5.3 Routing-level Validation (DagExecutionService)

ใน `DagExecutionService` (เช่น `moveToNextNode()` / `moveToNodeId()`):

1. **Validate token state ก่อน route**
   - Token ต้อง:
     - อยู่ใน node ปัจจุบัน ที่ตรงกับ context
     - ไม่อยู่สถานะปิด (`completed`, `cancelled`)
   - ถ้าถูกปิดไปแล้ว → return error object ภายใน service:
     - e.g. throw หรือ return result array เช่น:
       ```php
       return [
         'ok' => false,
         'error' => 'DAG_TOKEN_CLOSED',
         'app_code' => 'DAG_409_TOKEN_CLOSED',
       ];
       ```

2. **Validate DAG next node**
   - ถ้า `moveToNextNode()` แล้วหา next node ไม่ได้:
     - ต้อง distinguish:
       - เคส “จริงๆ คืองานจบแล้ว” (end node) → `completed: true`
       - เคส “graph ผิด” (ไม่มี next แต่ไม่ใช่ end node) → error:
         - `error: "DAG_NO_NEXT_NODE"`
         - `app_code: "DAG_500_NO_NEXT_NODE"`
   - ห้ามเงียบ ๆ route ไปที่ไหนสักที่แบบเดาสุ่ม

3. **Error contract ระหว่าง DagExecutionService ↔ BehaviorExecutionService**
   - BehaviorExecutionService เรียก DagExecutionService:
     - ถ้า routing error:
       - ให้ BehaviorExecutionService:
         - log error
         - คืนผลลัพธ์แบบ:
           ```php
           [
             'ok' => true,                // session/behavior success
             'effect' => 'stitch_completed_but_not_routed',
             'routing' => [
               'moved' => false,
               'error' => 'DAG_NO_NEXT_NODE',
               'app_code' => 'DAG_500_NO_NEXT_NODE',
             ],
           ]
           ```
       - **ห้าม** ทำให้ behavior action fail ทั้งก้อน (session ต้อง complete อยู่ดี)

---

### 5.4 Error Codes & JSON Output

ใน `dag_behavior_exec.php`:

1. Standardize error response สำหรับ behavior errors:
   - ถ้า BehaviorExecutionService โยน exception หรือคืน error array:
     - Map เป็น HTTP 400/403/409/500 ตามประเภท
     - JSON format:
       ```json
       {
         "ok": false,
         "error": "BEHAVIOR_INVALID_STATE",
         "app_code": "BEHAVIOR_409_INVALID_STATE",
         "message": "Short human-readable message"
       }
       ```
   - `message` ให้เป็นข้อความย่อ ๆ (ภาษาอังกฤษ) สำหรับ dev

2. Preserve backward compatibility:
   - Response success case:
     - ต้องยังคง field:
       - `received`, `behavior_code`, `action`, `source_page`, `effect`, `log_id`, `session_id` (ถ้ามี)
       - `routing` (optional, additive)
   - Error case:
     - `ok: false` + `error` + `app_code` + `message`
     - ห้ามเปลี่ยน structure success case ที่ client ใช้อยู่แล้ว

---

## 6. Non-Goals / Safety Rails

- ❌ ไม่เปลี่ยน database schema
- ❌ ไม่เพิ่ม/ลบ column ใน `flow_token`, `token_work_session`, `dag_behavior_log`
- ❌ ไม่แตะ UI (HTML templates) ที่พึ่งทำใน Task 4–5  
  (ยกเว้นปรับข้อความ error ใน JS บางเล็กน้อย ถ้าจำเป็น)
- ❌ ไม่เพิ่ม feature ใหม่ให้ behavior (CUT/EDGE/HARDWARE_ASSEMBLY ยังเป็น log-only)
- ✅ ทำได้: เพิ่ม validation, error handling, logging, และปรับให้ Behavior+DagExecution แข็งแรงขึ้น

---

## 7. Acceptance Criteria

ให้ถือว่า Task 10 เสร็จเมื่อ:

1. **Behavior guards ทำงานจริง**
   - กด `stitch_start` ซ้อน session เดิม → ได้ error `BEHAVIOR_SESSION_ALREADY_ACTIVE`
   - กด `stitch_resume` โดยไม่มี paused session → error `BEHAVIOR_NO_PAUSED_SESSION`
   - กด `stitch_complete` บน token ปิดแล้ว → error `BEHAVIOR_TOKEN_CLOSED`
   - กด `qc_pass` บน token ปิดแล้ว → error `BEHAVIOR_TOKEN_CLOSED`

2. **Routing guards ทำงานจริง**
   - ถ้า next node หาไม่เจอ และ node ปัจจุบันไม่ใช่ end node:
     - routing.moved = false
     - routing.error = `DAG_NO_NEXT_NODE`
   - Behavior action (เช่น stitch_complete) ยัง `ok: true` และ session ถูก complete

3. **Error format standardized**
   - Error ทุกกรณีใน `dag_behavior_exec.php`:
     - มี `ok: false`
     - มี `error` + `app_code`
     - มี `message` (สั้น ๆ)

4. **Backward compatibility**
   - เคสที่ไม่ error: response success form ยังเหมือนเดิม (เพิ่มได้เฉพาะ field ใหม่แบบ optional)
   - UI เดิม (Work Queue, PWA Scan, Job Ticket) ยังทำงานได้ตามปกติ

5. **Documentation**
   - สร้าง `docs/super_dag/tasks/task10_results.md` สรุป:
     - สิ่งที่ validate เพิ่ม
     - Error codes ใหม่
     - ตัวอย่าง error response
   - อัปเดต `docs/super_dag/task_index.md`:
     - Task 10 = COMPLETED

---

## 8. Implementation Hints (สำหรับ AI Agent / Dev)

1. อ่านโค้ดจริงใน:
   - `BehaviorExecutionService`
   - `DagExecutionService`
   - `dag_behavior_exec.php`
2. สร้าง private helper methods เล็ก ๆ ใน service เช่น:
   - `assertTokenNotClosed($token)`
   - `assertSessionCanStart($token, $workerId)`
3. ใช้ pattern:
   - Service คืน array แบบ `['ok' => true/false, 'error' => ..., 'app_code' => ...]`
   - Endpoint แปลง array → HTTP JSON response
4. เพิ่ม log กรณี error สำคัญ (`error_log`) แต่ไม่ flood log

---

**Task 10 = Behavior & Routing Validation Guards**  
เป้าหมายคือทำให้ Behavior + DAG Routing “กันพัง” ได้ระดับหนึ่ง ก่อนเข้าสู่ Phase Batch–Single & Components Integration