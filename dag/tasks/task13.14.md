Task 13.14 — BOM-based CUT Input & Overcut Classification Dialog

Status: PLANNED
Relates to:
	•	13.12 — Leather Sheet Usage Binding
	•	13.13 — Auto Material SKU Detection

⸻

1. Objective (เป้าหมาย)

เปลี่ยนการบันทึกงาน CUT จากการให้ช่าง “กรอกพื้นที่หนัง (cm²)”
มาเป็นการให้ช่าง กรอกจำนวนชิ้นที่ตัดจริงตาม BOM แล้วให้ระบบ:
	1.	คำนวณการใช้หนัง (พื้นที่) อัตโนมัติจาก BOM
	2.	ตรวจจับกรณี “ตัดเกินจากแผน” ต่อชิ้นส่วน
	3.	เปิด popup แยกเฉพาะชิ้นส่วนที่เกินให้ช่างระบุว่า:
	•	ตัดเกิน (ชิ้นดี เก็บไว้ใช้ต่อ)
	•	ตัดเสีย (Scrap)
	4.	ใส่ limit ว่าตัวเลข “ตัดเกิน + ตัดเสีย” ห้ามเกินจำนวนที่เกินจริง (diff)

เป้าหมายคือ:
	•	ลดภาระคิดของช่าง (ไม่ต้องยุ่งกับ cm²)
	•	ได้ข้อมูลการใช้หนัง + scrap แบบละเอียด
	•	ยังไม่บังคับเรื่อง leather sheet (13.12 ยังใช้เป็น optional layer อยู่ได้เหมือนเดิม)

BOM Source of Truth

- ระบบมีโครงสร้าง BOM อยู่แล้ว (ตามหน้าจอรายละเอียด BOM ใน ERP ปัจจุบัน)
- Task นี้ **ห้ามสร้าง BOM ชุดใหม่หรือโครงสร้างซ้ำซ้อน** เพิ่ม
- แหล่งข้อมูล BOM ทั้งหมด (qty_plan, area_per_piece, bom_line_id ฯลฯ) ต้องอ้างอิงจาก BOM เดิมเพียงชุดเดียว (shared กับ BOM modal ที่ใช้อยู่แล้ว)
- ไม่จำเป็นต้องใช้ทุกบรรทัดใน BOM ทั้งหมด ในบริบท CUT ให้ดึงเฉพาะบรรทัดที่เกี่ยวกับชิ้นส่วนที่ต้องตัดจริง (เช่น material group = leather หรือมี flag is_cut_leather = 1 ตามที่ระบบมีอยู่แล้ว)

⸻

2. Scope

In Scope
	1.	หน้า CUT Behavior หลัก
	•	ดึง BOM ของ Product/Token มาแสดงเป็นตาราง
	•	ให้ช่างกรอก “จำนวนที่ตัดจริง (qty_actual)” ต่อชิ้นส่วน
	2.	Overcut Popup
	•	แสดงเฉพาะชิ้นส่วนที่ qty_actual > qty_plan
	•	UI เป็นตารางแบบที่ผู้ใช้กำหนด:

ชิ้นส่วน   |     ตัดเกิน (ชิ้นดี)    |   ตัดเสีย
BODY      |     ___ (+ / -)        |   ___ (+ / -)
...


	•	มี limit: ตัดเกิน + ตัดเสีย ≤ diff (diff = qty_actual - qty_plan)

	3.	Backend Logic
	•	คำนวณ qty_plan, qty_actual, qty_scrap, qty_extra_good ต่อชิ้นส่วน
	•	แปลงเป็นพื้นที่ usage ตาม BOM (ใช้ area_per_piece)
	•	เตรียมข้อมูลให้ระบบ material / leather usage เอาไปใช้ต่อ

Out of Scope (เก็บไป Task ต่อไป)
	•	การ reconcile ตรง ๆ กับ leather_sheet_usage_log แบบ 1:1
	•	การบังคับว่าต้องบันทึก CUT BOM input ก่อน complete
	•	Dashboard วิเคราะห์ scrap/extra ทั้งโรงงาน

⸻

3. UX Flow (ฝั่งช่าง CUT)

3.1 หน้า CUT Panel (Step 1 — กรอกผลการตัด)

บน CUT behavior panel เพิ่ม section ใหม่:

“ผลการตัดตาม BOM” (Cut Result)

ดึง BOM ที่ active ของ product/token มาแสดงเป็นตาราง เช่น:

ชิ้นส่วน (Component)	ตาม BOM (qty_plan)	พื้นที่ต่อชิ้น (cm²)	จำนวนที่ตัดจริง (qty_actual)
BODY	2	105	[   2   ]
SIDE	4	22	[   4   ]
STRAP	1	48	[   1   ]

	•	ค่าเริ่มต้นของ qty_actual = qty_plan (ช่างไม่ต้องกรอกอะไรถ้าตัดตรงตามแผน)
	•	ช่างเปลี่ยนตัวเลขเฉพาะเคสที่:
	•	ตัดไม่ครบ (actual < plan)
	•	ตัดเกิน (actual > plan)

ปุ่มหลัก:
	•	[บันทึกผลการตัด CUT]

เมื่อกด:
	1.	JS ส่ง qty_actual ทั้งชุดไป backend
	2.	backend เปรียบเทียบกับ BOM → คำนวณ diff ต่อ component

⸻

3.2 Popup “ตัดเกิน / ตัดเสีย” (Step 2 — เฉพาะกรณีมีเกิน)

สำหรับแต่ละชิ้นส่วนที่ qty_actual > qty_plan:
	•	คำนวณ diff = qty_actual - qty_plan
	•	แสดงเป็นแถวใน popup หนึ่งอัน:

ตัวอย่าง popup:

พบชิ้นส่วนที่ตัดเกินจากแผน
กรุณาระบุว่าเป็นชิ้นดีที่เกิน หรือชิ้นที่ตัดเสีย

ชิ้นส่วน   |   ตัดเกิน (ชิ้นดี)      |   ตัดเสีย
---------------------------------------------------------
BODY       |   [-]  0  [+]            |   [-]  1  [+]
STRAP      |   [-]  1  [+]            |   [-]  0  [+]
---------------------------------------------------------
[ยกเลิก]                               [ยืนยันบันทึก]

กติกา:
	•	มีแถวเฉพาะ component ที่ diff > 0 เท่านั้น
	•	แต่ละ cell มี input แบบ “ตัวเลข + ปุ่ม + / -”
	•	สำหรับแต่ละ component:
	•	diff = qty_actual - qty_plan
	•	ตัวแปร:
	•	extra_good = ตัดเกินดี (เก็บไว้ใช้ต่อ)
	•	scrap = ตัดเสีย
	•	เงื่อนไข:
	•	0 ≤ extra_good ≤ diff
	•	0 ≤ scrap ≤ diff
	•	extra_good + scrap ≤ diff
(version แรก: บังคับให้ = diff ก็ได้ เพื่อความชัด)

ค่าเริ่มต้น (แนะนำ):
	•	default เป็น scrap = diff, extra_good = 0
= สมมติว่าที่เกินทั้งหมดเพราะตัดเสีย
	•	ช่างสามารถกด +/– เพื่อเปลี่ยนเป็นชิ้นดีเก็บไว้ได้

เมื่อกด [ยืนยันบันทึก]:
	•	JS ตรวจว่า extra_good + scrap == diff ทุกแถว
	•	ส่งข้อมูล (ต่อ component) กลับไป backend

⸻

4. Backend Design

4.1 Data Model (แนวคิด)

ต่อ component หนึ่งตัวใน CUT หนึ่งครั้ง เราต้องได้:
	•	token_id
	•	bom_line_id
	•	qty_plan (จาก BOM)
	•	qty_actual (ช่างกรอก)
	•	qty_scrap (จาก popup)
	•	qty_extra_good (จาก popup)
	•	area_per_piece (จาก BOM)
	•	area_planned = qty_plan * area_per_piece
	•	area_used = qty_actual * area_per_piece
	•	(optional) area_scrap, area_extra ถ้าจะเก็บแยก

หมายเหตุเรื่อง BOM:

- โครงสร้าง BOM หลัก (header / detail / cost) ใช้ **ตารางเดิมที่มีอยู่แล้วในระบบ** เท่านั้น (ตัวเดียวกับที่ BOM modal ใช้)
- ไม่อนุญาตให้สร้างตาราง BOM เพิ่มหรือ copy โครงสร้าง BOM มาอีกชุดใน Task นี้

สำหรับการบันทึกผลการตัด ให้เพิ่มเพียงตาราง log ใหม่ 1 ตาราง เช่น `leather_cut_bom_log` โดยอ้างอิง `bom_line_id` จาก BOM เดิม:

ตารางตัวอย่าง (concept):

leather_cut_bom_log
- id
- token_id
- bom_line_id
- qty_plan
- qty_actual
- qty_scrap
- qty_extra_good
- area_per_piece
- area_planned
- area_used
- created_at
- created_by

หมายเหตุ: Task 13.14 เน้น logic + UX
Migration จริงสามารถเขียนทีหลังให้สอดคล้องกับ schema ปัจจุบัน

⸻

4.2 API / Endpoint

เสนอสร้าง endpoint ใหม่สำหรับ CUT BOM เช่น:

ข้อกำหนดสำคัญ: ฟังก์ชันที่ใช้ดึง BOM (`load_cut_bom_for_token`) ต้อง reuse query / service เดียวกับ BOM modal ที่มีอยู่แล้วให้มากที่สุด ห้ามเขียน logic BOM ซ้ำอีกชุด (BOM มี source of truth เดียว)

Actions หลัก:
	1.	load_cut_bom_for_token
	•	Input: token_id
	•	Output:
	•	BOM lines ที่เกี่ยวกับ CUT ขั้นตอนนี้:
	•	bom_line_id, component_name, qty_plan, area_per_piece
	•	ถ้ามี qty_actual ที่เคยกรอก → preload กลับไปให้ UI
	2.	save_cut_actual_qty
	•	Input:
	•	token_id
	•	Array ของ {bom_line_id, qty_plan, qty_actual}
	•	Logic:
	•	ตรวจความถูกต้อง
	•	คำนวณ diff per component
	•	ถ้าไม่มี diff > 0:
	•	คำนวณ area_used จาก qty_actual
	•	บันทึกลง leather_cut_bom_log
	•	ส่ง ok: true, overcut: false กลับไป
	•	ถ้ามี diff > 0:
	•	ไม่ commit final log ก่อน
	•	ส่ง response:
	•	ok: true
	•	overcut: true
	•	array components ที่ diff > 0:
	•	bom_line_id, component_name, diff
	3.	save_overcut_classification
	•	Input:
	•	token_id
	•	Array ของ {bom_line_id, diff, extra_good, scrap}
	•	Logic:
	•	Validate: extra_good + scrap == diff ต่อแถว
	•	ดึง qty_plan, qty_actual, area_per_piece จาก context ก่อนหน้า / DB
	•	คำนวณ area_used, area_planned
	•	บันทึก log สุดท้ายลง leather_cut_bom_log

ใน 13.14 นี้ยังไม่จำเป็นต้อง bind เข้ากับ leather_sheet_usage_log
แค่ให้ข้อมูลพร้อมสำหรับการใช้ใน Task ถัดไปและ super_dag

⸻

4.3 Idempotency & Update Behavior

- การบันทึกผล CUT ต่อ token + behavior ต้องเป็น **idempotent**:
  - ถ้าผู้ใช้เปิด CUT panel เดิมแล้วบันทึกผลการตัดใหม่อีกครั้ง ให้ถือว่าเป็นการ *แก้ไขชุดเดิม* ไม่ใช่การสร้าง log ซ้ำซ้อน
- แนวทางที่ยอมรับได้:
  - ลบหรือ mark obsolete log เดิมของ token/behavior นั้นแล้วเขียนแถวใหม่ลง `leather_cut_bom_log`
  - หรือใช้รูปแบบ UPDATE แถวเดิม (ถ้า schema ปัจจุบันเอื้อ)
- หลีกเลี่ยงการสร้างหลายแถวที่มี `token_id` + `bom_line_id` ซ้ำกันโดยไม่มี mechanism ชัดเจนว่าอันไหนคือค่าล่าสุด
- ถ้ามี error กลางทางระหว่าง `save_cut_actual_qty` กับ `save_overcut_classification`:
  - ต้อง rollback หรืออยู่ในสถานะที่สามารถเรียกบันทึกซ้ำได้โดยไม่ทำให้ข้อมูลซ้ำหรือเพี้ยน (เช่น ใช้ transaction เดียว หรือมี flag บอก state ชัดเจน)

⸻

5. Frontend Changes (JS / Template)

5.1 CUT Panel — BOM Table

File: คาดว่าเกี่ยวกับ:
	•	assets/javascripts/dag/behavior_execution.js
	•	assets/javascripts/dag/behavior_ui_templates.js

สิ่งที่ต้องเพิ่ม:
	1.	Template ตาราง BOM:

<table class="table table-sm" id="cut-bom-table">
  <thead>
    <tr>
      <th>ชิ้นส่วน</th>
      <th>ตาม BOM</th>
      <th>พื้นที่/ชิ้น (cm²)</th>
      <th>จำนวนที่ตัดจริง</th>
    </tr>
  </thead>
  <tbody>
    <!-- เติมด้วย JS จาก load_cut_bom_for_token -->
  </tbody>
</table>
<button id="btn-save-cut-result" class="btn btn-primary btn-sm">
  บันทึกผลการตัด
</button>

	2.	JS:
	•	loadCutBomForToken(tokenId) → call API → render rows
	•	collectCutActualQty() → อ่านค่าจากช่อง input
	•	saveCutResult() → ส่งไป save_cut_actual_qty

ถ้า response:
	•	overcut: false → แสดง success, จบ
	•	overcut: true → เปิด popup ตามข้อ 5.2

⸻

5.2 Overcut Popup — ตาราง “ตัดเกิน / ตัดเสีย”

JS เตรียม data:

[
  { bom_line_id: 10, component_name: 'BODY', diff: 1 },
  { bom_line_id: 12, component_name: 'STRAP', diff: 1 }
]

Template (concept):

<div id="overcut-modal" style="display:none">
  <p>พบชิ้นส่วนที่ตัดเกินจากแผน กรุณาระบุว่าเป็นชิ้นดีหรือชิ้นเสีย</p>
  <table class="table table-sm">
    <thead>
      <tr>
        <th>ชิ้นส่วน</th>
        <th>ตัดเกิน (ชิ้นดี)</th>
        <th>ตัดเสีย</th>
      </tr>
    </thead>
    <tbody id="overcut-rows">
      <!-- JS เติมทีหลัง -->
    </tbody>
  </table>
  <button id="btn-overcut-cancel" class="btn btn-secondary btn-sm">ยกเลิก</button>
  <button id="btn-overcut-confirm" class="btn btn-primary btn-sm">ยืนยันบันทึก</button>
</div>

ในแต่ละ row:

<tr data-bom-line-id="10" data-diff="1">
  <td>BODY</td>
  <td>
    <button class="btn btn-xs btn-light btn-extra-dec">-</button>
    <span class="extra-value">0</span>
    <button class="btn btn-xs btn-light btn-extra-inc">+</button>
  </td>
  <td>
    <button class="btn btn-xs btn-light btn-scrap-dec">-</button>
    <span class="scrap-value">1</span>
    <button class="btn btn-xs btn-light btn-scrap-inc">+</button>
  </td>
</tr>

JS logic:
	•	อ่าน diff จาก data-diff
	•	บังคับเงื่อนไข:
	•	เวลา inc → เช็คว่า extra + scrap < diff ก่อนเพิ่ม
	•	เวลา dec → ไม่ให้ต่ำกว่า 0
	•	ก่อนส่งข้อมูล:
	•	validate ว่า extra + scrap == diff ทุกแถว

ส่งไป save_overcut_classification เป็น array:

[
  { "bom_line_id": 10, "diff": 1, "extra_good": 0, "scrap": 1 },
  { "bom_line_id": 12, "diff": 1, "extra_good": 1, "scrap": 0 }
]


⸻

6. Acceptance Criteria

Functional
	1.	ช่างเปิด CUT Panel สำหรับ token ที่มี BOM:
	•	เห็นตาราง BOM-based input พร้อม qty_plan/area_per_piece/input qty_actual
	•	ค่า default ของ qty_actual = qty_plan
	2.	ช่างกรอกค่า qty_actual แล้วกดบันทึก:
	•	ถ้า qty_actual == qty_plan ทุกแถว →
	•	ระบบบันทึกผล CUT สำเร็จ
	•	ไม่มี popup overcut
	•	ถ้ามีบางแถว qty_actual > qty_plan →
	•	ระบบเปิด popup “ตัดเกิน / ตัดเสีย”
	•	แสดงเฉพาะแถวที่ diff > 0
	•	ช่างสามารถปรับค่าด้วยปุ่ม +/– ทั้งสองฝั่ง
	•	ระบบบังคับไม่ให้รวมเกิน diff
	•	เมื่อยืนยัน → บันทึกค่า qty_scrap/qty_extra_good ถูกต้อง
	3.	ค่าที่บันทึกได้ต่อ component:
	•	มี qty_plan, qty_actual, qty_scrap, qty_extra_good
	•	ถูกคำนวณพื้นที่การใช้หนังพื้นที่รวม (area_used) จาก BOM
	4. กรณี token ที่ไม่มี BOM (หรือ BOM ไม่มีบรรทัดที่เกี่ยวกับ CUT/leather) ระบบต้องไม่ error แต่แสดงข้อความว่า "ไม่มี BOM สำหรับขั้นตอนนี้" และไม่แสดงตาราง CUT BOM
	5. เมื่อบันทึกผลการตัดของ token เดิมซ้ำ ระบบต้องไม่สร้าง log ซ้ำซ้อนสำหรับ bom_line_id เดิมโดยไม่มีการลบ/แก้ไขของเก่า (พฤติกรรมต้องเป็นแบบ idempotent ตามข้อ 4.3)

Non-Functional
	•	UX ของ popup ไม่เกิน 1–2 คลิกต่อแถว
	•	ถ้าไม่เกิน BOM → ไม่มี popup ใด ๆ ขวาง
	•	ไม่ทำให้ flow ของ 13.12–13.13 พัง
	•	leather_sheet_api ยังใช้ได้เหมือนเดิม
	•	MaterialResolver ยังทำงานตามปกติ

⸻