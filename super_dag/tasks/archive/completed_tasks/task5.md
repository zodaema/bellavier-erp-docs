# super_dag – Task 5  
## Behavior Execution Spine (Stub Endpoint + Handler Wiring)

**Status:** PLANNED  
**Owner:** AI Agent (Cursor / GPT 5.1)  
**Depends on:**  
- Task 1 – Work Center Behavior Registry  
- Task 2 – Behavior Binding UI  
- Task 3 – Behavior Metadata on Tokens / Routing  
- Task 4 – Behavior UI Templates

---

## 1. เป้าหมายของ Task นี้

สร้าง “กระดูกสันหลัง” การทำงานของ Behavior ดังนี้:

1. มี **จุดกลางฝั่ง JS** สำหรับสั่ง “execute behavior” จากทุกหน้า (Work Queue, PWA Scan, Job Ticket)
2. มี **Stub Endpoint ฝั่ง PHP** รับ payload จาก behavior (ยังไม่เปลี่ยน Token / Time / DAG จริง แค่ log และตอบ `{ok: true}`)
3. ผูกปุ่มใน Behavior Panels (CUT / STITCH / EDGE / HARDWARE_ASSEMBLY / QC_SINGLE / QC_FINAL) เข้ากับ Execution Spine เดียวกัน
4. ยัง **ไม่แตะ Time Engine / Token Engine / DAG Execution Logic**  
   → ภายหลังจะมี Task แยกสำหรับแต่ละ behavior

ผลลัพธ์หลังจบ Task 5:

- ทุก behavior panel ที่มีปุ่ม action จะยิง request ไป endpoint กลางพร้อม payload ที่ออกแบบมาแล้ว
- Log สามารถใช้เป็น reference สำหรับ Task ถัดไป (Time Engine, Batch Engine, QC Engine ฯลฯ)
- ระบบเดิมยังใช้ได้ 100% ไม่มีผลกับงาน Production ปัจจุบัน

---

## 2. ขอบเขต (Scope)

### 2.1 ฝั่ง Backend (PHP)

- สร้าง **Tenant API Stub**:
  - `source/dag_behavior_exec.php`

คุณสมบัติ:

- ใช้ **Tenant Bootstrap + TenantApiOutput** ตามมาตรฐานปัจจุบัน
  - `TenantApiBootstrap::init()` (ถ้ามี)
  - `TenantApiOutput::startOutputBuffer()`
- รองรับ **method: POST** เท่านั้น
- รับ JSON payload จาก `php://input`
- Validate ขั้นต่ำ:
  - `behavior_code` (string, required)
  - `source_page` (string, required: `'work_queue' | 'pwa_scan' | 'job_ticket'`)
  - `action` (string, required)
  - `context` (object, optional)
  - `form_data` (object, optional)
- Log แบบ Safe (ไม่ log อะไรที่เป็น secret):
  - แนะนำใช้ `LogHelper::info('dag_behavior_exec', $safePayload);`
- ตอบกลับ:
  ```json
  { "ok": true, "data": { "received": true } }

	•	error path → ใช้ TenantApiOutput::error() และ format JSON มาตรฐาน

สำคัญ: Task นี้ยัง ห้าม:
	•	เปลี่ยน Token status
	•	เปลี่ยน Time tracking
	•	เปลี่ยน DAG state

⸻

2.2 ฝั่ง Frontend – Execution Spine (JS กลาง)

2.2.1 สร้างไฟล์ใหม่
ไฟล์ใหม่:
	•	assets/javascripts/dag/behavior_execution.js

หน้าที่ไฟล์นี้:
	•	สร้าง Global Object:

(function(window) {
  'use strict';

  window.BGBehaviorExec = {
    debug: false, // สามารถเปิดตอน dev

    /**
     * สร้าง payload กลางสำหรับ behavior execution
     * @param {Object} baseContext - ข้อมูลพื้นฐาน (token, node, behavior, source_page ฯลฯ)
     * @param {String} action - เชิงสัญญะ เช่น 'stitch_start', 'cut_save_batch'
     * @param {Object} formData - ค่าจากฟอร์มใน panel
     * @returns {Object} payload
     */
    buildPayload: function(baseContext, action, formData) { ... },

    /**
     * ยิงไปที่ PHP endpoint
     * @param {Object} payload
     * @param {Function} [onSuccess]
     * @param {Function} [onError]
     */
    send: function(payload, onSuccess, onError) { ... }
  };

})(window);

รายละเอียดที่ต้องทำ:
	•	buildPayload(baseContext, action, formData):
	•	รวมข้อมูลเป็น:

{
  behavior_code: baseContext.behavior_code,   // เช่น 'STITCH'
  source_page: baseContext.source_page,       // 'work_queue', 'pwa_scan', 'job_ticket'
  action: action,                             // เช่น 'stitch_start', 'qc_pass'
  context: {
    token_id: baseContext.token_id || null,
    node_id: baseContext.node_id || null,
    work_center_id: baseContext.work_center_id || null,
    mo_id: baseContext.mo_id || null,
    job_ticket_id: baseContext.job_ticket_id || null,
    extra: baseContext.extra || null
  },
  form_data: formData || {}
}


	•	send(payload, onSuccess, onError):
	•	ใช้ $.ajax หรือ $.post (ตาม convention ปัจจุบัน) → source/dag_behavior_exec.php
	•	method: POST
	•	contentType: application/json
	•	data: JSON.stringify(payload)
	•	ถ้า BGBehaviorExec.debug === true ให้ console.log('[BGBehaviorExec] payload', payload, response);
	•	success: ถ้า response && response.ok ให้เรียก onSuccess (ถ้ามี)
	•	error path: log error, เรียก onError ถ้ามี, อาจโชว์ toaster (SweetAlert/Toastr ตามที่ใช้ในโปรเจกต์)

⸻

2.3 ฝั่ง Frontend – เชื่อมกับ BGBehaviorUI (Handlers)

เรามีไฟล์:
	•	assets/javascripts/dag/behavior_ui_templates.js

ตอนนี้มี BGBehaviorUI.registerTemplate(...) ครบแล้ว และ handlers registry ว่างอยู่

ใน Task 5 ต้อง:
	1.	สร้าง handler สำหรับแต่ละ behavior ในไฟล์ใหม่ behavior_execution.js
	2.	ให้ handler มีรูปแบบ:

BGBehaviorUI.registerHandler('STITCH', {
  /**
   * @param {jQuery} $panel - root element ของ behavior panel (instance นั้น ๆ)
   * @param {Object} baseContext - context จากหน้าที่เรียก (token_id, node_id, source_page, ฯลฯ)
   */
  init: function($panel, baseContext) {
    // bind ปุ่มใน panel นี้
  }
});

สำคัญ:
ไม่แก้โครงสร้าง HTML ใหญ่ใน behavior_ui_templates.js นอกจากเพิ่ม class / data-attribute ที่จำเป็น

2.3.1 Behavior → Action Mapping (Task 5 Stub)
STITCH (Hatthasilpa Single):

ใน init($panel, baseContext):
	•	ปุ่ม #btn-stitch-start → action: 'stitch_start'
	•	ปุ่ม #btn-stitch-pause → action: 'stitch_pause'
	•	ปุ่ม #btn-stitch-resume → action: 'stitch_resume'

form data ควรอ่านจาก:
	•	#stitch-pause-reason
	•	#stitch-notes

แล้วเรียก:

BGBehaviorExec.send(
  BGBehaviorExec.buildPayload(baseContext, 'stitch_start', formData),
  function(res) { /* optional: show success toast */ },
  function(err) { /* optional: show error toast */ }
);

CUT (Batch):
	•	ไม่มีปุ่มใน template ตอนนี้ → ใน Task 5:
	•	ยังไม่ต้องเพิ่มปุ่มใหม่ก็ได้
	•	หรือเพิ่มปุ่มเดียว: Save Batch Result → action 'cut_save_batch'
	•	form data:
	•	#cut-qty-produced → qty_produced
	•	#cut-qty-scrapped → qty_scrapped
	•	#cut-reason → reason
	•	#cut-leather-lot → leather_lot

EDGE:
	•	เพิ่มปุ่ม Update Edge Step (ถ้ายังไม่มี ให้เพิ่มปุ่มหนึ่งใน panel)
	•	action: 'edge_update'
	•	form data:
	•	#edge-coat-round → coat_round
	•	input[name="dry_status"]:checked → dry_status
	•	#edge-defect-fix → defect_fix

HARDWARE_ASSEMBLY:
	•	เพิ่มปุ่ม Save Hardware (หรือชื่อที่เหมาะสม)
	•	action: 'hardware_save'
	•	form data:
	•	#hardware-serial → hardware_serial
	•	#hardware-lot-check (checkbox) → hardware_lot_check
	•	#hardware-mismatch (checkbox) → hardware_mismatch

QC_SINGLE / QC_FINAL:
	•	ปุ่ม #btn-qc-send-back → action: 'qc_send_back'
	•	ปุ่ม #btn-qc-mark-pass → action: 'qc_pass'
	•	form data:
	•	#qc-defect-code → defect_code
	•	#qc-defect-reason → defect_reason

⸻

2.4 ฝั่ง Frontend – ให้แต่ละหน้าเรียก handler.init(…)

ไฟล์ที่ต้องแก้:
	•	assets/javascripts/pwa_scan/pwa_scan.js
	•	assets/javascripts/pwa_scan/work_queue.js
	•	assets/javascripts/hatthasilpa/job_ticket.js

แนวคิดเหมือนกันทุกหน้า:

หลังจาก render behavior panel แล้ว (โดยใช้ getBehaviorTemplate(...)):

const templateHtml = getBehaviorTemplate(behavior, true);
const $panel = $(templateHtml);
// append $panel เข้า container

const handler = window.BGBehaviorUI.getHandler(behavior.code);
if (handler && typeof handler.init === 'function') {
  const baseContext = {
    source_page: 'work_queue', // หรือ 'pwa_scan' / 'job_ticket'
    behavior_code: behavior.code,
    token_id: token.id_token || token.token_id,
    node_id: behavior.node_id || node.id_node,
    work_center_id: behavior.work_center_id || null,
    mo_id: token.mo_id || null,
    job_ticket_id: token.job_ticket_id || null,
    extra: {
      // ใส่ context เพิ่มเติมที่อาจมีประโยชน์ เช่น product, model, ฯลฯ
    }
  };
  handler.init($panel, baseContext);
}

ให้ทำ pattern นี้กับทั้ง:
	•	Work Queue view (token cards)
	•	PWA Scan token view
	•	Hatthasilpa Job Ticket routing steps (ถ้ามี behavior panel)

⸻

2.5 รวม JS เข้าหน้าเว็บ

ไฟล์:
	•	page/pwa_scan.php
	•	page/work_queue.php
	•	page/hatthasilpa_job_ticket.php

ให้แน่ใจว่าโหลด JS ตามลำดับ:
	1.	jQuery
	2.	utilities / core
	3.	behavior_ui_templates.js
	4.	ใหม่: behavior_execution.js
	5.	page-specific JS (pwa_scan.js, work_queue.js, job_ticket.js)

ตรวจดูว่าไม่มีการโหลดซ้ำ และ path ถูกต้อง

⸻

3. ข้อจำกัด / ห้ามทำใน Task 5
	•	❌ ห้ามแก้ Time Engine logic (start/pause/resume calculation)
	•	❌ ห้ามแก้ Token Engine (assign, complete, requeue)
	•	❌ ห้ามแก้ DAG execution routing
	•	❌ ห้ามเปลี่ยน structure หลักของ Behavior Panels (HTML layout) นอกจาก:
	•	เพิ่มปุ่ม
	•	เพิ่ม data-attribute หรือ id ที่จำเป็น

Task 5 = “สายส่งข้อมูล” เท่านั้น
ทุก behavior ที่กดปุ่ม ต้องส่ง payload เข้า endpoint กลาง → log → ตอบ ok

⸻

4. Acceptance Criteria

Backend
	•	php -l source/dag_behavior_exec.php ผ่าน
	•	เรียก curl -X POST source/dag_behavior_exec.php ด้วย payload ตัวอย่าง → ได้ { "ok": true, ... }
	•	Log ถูกเขียน (ถ้าเปิด logging)

Frontend
	•	เปิดหน้า:
	•	Work Queue
	•	PWA Scan
	•	Hatthasilpa Job Ticket

สำหรับ token/step ที่มี behavior:
	•	Panel แสดงเหมือนเดิม (UI ไม่พัง)
	•	เมื่อกดปุ่มใน panel:
	•	ไม่มี JS error ใน Console
	•	Network tab แสดง request ไปที่ dag_behavior_exec.php
	•	Payload มี field:
	•	behavior_code
	•	source_page
	•	action
	•	context (มี token_id / node_id อย่างน้อย 1 ค่า)
	•	form_data (ถ้ากรอกในฟอร์ม)
	•	Response เป็น {ok: true}

Safety
	•	ถ้า endpoint ล่ม / network error:
	•	UI แสดง error (toaster หรือ alert)
	•	หน้าจอไม่ค้าง ไม่ reload เอง
	•	ถ้า behavior ไม่มี handler:
	•	Panel ยัง render ได้
	•	ไม่มี JS error (แค่ไม่ทำอะไรเมื่อกดปุ่ม)

Documentation
	•	docs/super_dag/tasks/task5_results.md (ให้ Agent สร้างหลังทำเสร็จ)
ระบุ:
	•	ไฟล์ที่แก้ไข
	•	ตัวอย่าง payload
	•	ผลการทดสอบ manual (อย่างน้อย 1 หน้า)
