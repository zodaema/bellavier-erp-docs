
1) Work Center Behavior Spec (ตัวอย่างสเปกจับต้องได้)

จุดประสงค์: ให้คุณเห็นว่า
“ถ้าเหตุการณ์ X เกิดในโรงงาน → Work Center ไหน → หน้าจอไหน → ฟอร์มอะไร → Token/เวลา/Component ถูกบันทึกอย่างไร”

1.1 Concept
	•	Work Center = “พื้นที่ทำงานจริง” เช่น CUT, EDGE, STITCH, QC_FINAL
	•	Work Center Behavior = กฎที่บอกว่า Work Center นี้:
	•	เป็น batch หรือ single?
	•	ต้องกรอกจำนวนชิ้นไหม?
	•	ใช้เวลาแบบไหน? (ต่อ batch / ต่อใบ)
	•	อนุญาตให้ bind component ไหม?
	•	มี edge-case พิเศษอะไร (เช่น ต้องรอแห้ง, มีหลายรอบ)?

DAG Designer จะ “เลือก Work Center” เป็นหลัก
แล้ว “Behavior” จะทำให้ UI และ Time/Token/Component ทำงานถูกแบบอัตโนมัติ

⸻

1.2 Data Model (ตรึงโครงให้ dev/AI เขียนโค้ดได้เลย)

จะเก็บ Behavior แยกตาราง เพื่อไม่ไปทำให้ work_centers ปัจจุบันพัง

Table: work_center_behavior

Field	Type	Description
id_behavior	int PK	primary key
code	varchar(50)	เช่น CUT, EDGE, STITCH, QC_FINAL
name	varchar(100)	ชื่อภาษาอังกฤษ
description	text	อธิบาย behavior
is_hatthasilpa_supported	tinyint(1)	ใช้ใน Hatthasilpa ได้ไหม
is_classic_supported	tinyint(1)	ใช้ใน Classic/PWA ได้ไหม
execution_mode	enum	BATCH, SINGLE, MIXED
time_tracking_mode	enum	PER_BATCH, PER_PIECE, NO_TIME
requires_quantity_input	tinyint(1)	ต้องมี input “จำนวนชิ้น/ชุด” ก่อน start ไหม
allows_component_binding	tinyint(1)	Node นี้ bind component ได้ไหม
allows_defect_capture	tinyint(1)	Node นี้ capture defect code ได้ไหม
supports_multiple_passes	tinyint(1)	ใช้กับ EDGE (หลายรอบ)
ui_template_code	varchar(50)	ใช้เลือก Template UI เช่น CUT_DIALOG, EDGE_DIALOG, QC_PANEL
default_expected_duration	int (sec)	เวลามาตรฐานโดยประมาณ (ใช้เทียบ performance)
created_at / updated_at	datetime	มาตรฐาน

Table: work_center_behavior_map

ใช้ map จาก work_center ปัจจุบันไป behavior

Field	Type	Description
id_work_center	int FK	อ้างถึง work_centers ปัจจุบัน
id_behavior	int FK	อ้างถึง behavior
override_settings	json	future override เป็น JSON ถ้าต้องการ custom บางโรงงาน


⸻

1.3 Behavior Preset ตัวอย่าง (CUT / EDGE / STITCH / QC)

CUT (ตัดหนัง – Batch)

code: CUT
execution_mode: BATCH
time_tracking_mode: PER_BATCH
requires_quantity_input: 1
allows_component_binding: 0 (component serial ยังไม่เกิด แค่เตรียมชิ้นส่วน)
allows_defect_capture: 1 (เช่น CUT02 – ขอบเบี้ยว)
supports_multiple_passes: 0
ui_template_code: CUT_DIALOG
default_expected_duration: 1800 (30 นาที ต่อ batch)

EDGE (ทาสีขอบ – Mixed)

code: EDGE
execution_mode: MIXED   (batch ทาทีละหลายใบ แต่เวลาต้องผูกกับใบ/รอบได้)
time_tracking_mode: PER_BATCH
requires_quantity_input: 1 (วันนี้ทาขอบกี่ใบ/กี่ชิ้น)
allows_component_binding: 0 (ใช้ตอนนี้ยังไม่ bind serial components)
allows_defect_capture: 1 (EP01 – สีไม่เรียบ)
supports_multiple_passes: 1 (รอบที่ 1,2,3)
ui_template_code: EDGE_DIALOG
default_expected_duration: 900 (15 นาที ต่อรอบ)

STITCH (เย็บ – Hatthasilpa Single)

code: STITCH
execution_mode: SINGLE
time_tracking_mode: PER_PIECE
requires_quantity_input: 0
allows_component_binding: 0 (ยังไม่ binding component ที่นี่)
allows_defect_capture: 1 (SEW05 – ด้ายหลุด ฯลฯ)
supports_multiple_passes: 0
ui_template_code: HAT_SINGLE_TIMER
default_expected_duration: 3600 (60 นาที ต่อใบ)

QC_FINAL

code: QC_FINAL
execution_mode: SINGLE
time_tracking_mode: PER_PIECE
requires_quantity_input: 0
allows_component_binding: 1 (ตรวจ completeness ของ component binding)
allows_defect_capture: 1
supports_multiple_passes: 0
ui_template_code: QC_PANEL
default_expected_duration: 300 (5 นาที ต่อใบ)


⸻

1.4 Mapping ไป “หน้าไหนในโปรแกรม”

จุดนี้คือสิ่งที่คุณอยากเห็นที่สุด: เหตุการณ์ → ไปจบตรงไหนใน UI

กรณี 1 — CUT 20 ชุดแต่หนังตัดจริงได้ 18
	1.	MO Screen / Hatthasilpa Job Ticket
	•	Planner สร้าง MO: 10 ใบ → ระบบรู้ว่าต้องการชิ้นตัด X ชิ้นต่อใบ → Total = 10 * X
	•	DAG กำหนดว่า Node แรกใช้ Work Center = CUT
	2.	Work Queue – CUT Node
	•	ระบบดึง behavior CUT:
	•	execution_mode = BATCH → UI แสดง dialog “เริ่ม batch การตัด”
	•	requires_quantity_input = 1 → ให้ช่างกรอก “ตั้งใจตัด = 20 ชุด”
	•	ช่างกด Start → Time Engine จับเวลารวม batch (ไม่ลงรายละเอียดใบไหน)
	3.	เมื่อเสร็จงาน
	•	ช่างกรอก “ตัดได้จริง = 18 ชุด” ใน dialog ปิดงาน
	•	ระบบ:
	•	สร้าง/อัปเดต batch token ว่า
	•	planned_qty = 20
	•	actual_qty = 18
	•	scrap_qty = 2
	•	mark 2 ชุดที่หายไปเป็น scrap reason (เช่น CUT02 – หนังไม่พอ/เสียหาย)
	4.	ผลลัพธ์ที่คุณจะเห็นในระบบ
	•	ใน MO → แสดง status: CUT Completed (18/20) + scrap 2
	•	ในรายงานประสิทธิภาพ CUT → เห็นทันทีว่า batch นี้มี scrap rate 10%
	•	Token Engine → รู้ว่า step ต่อไป (STITCH) มี input ได้สูงสุด 18 ใบ (แม้ MO เดิมตั้งใจ 10 ใบ คุณอาจ split MO หรือเก็บส่วนเกินเป็น stock component)

กรณี 2 — ช่างลืมกด Pause ตอนเย็บ (STITCH – Hatthasilpa)
	1.	Work Queue – STITCH Node
	•	behavior = STITCH (SINGLE, PER_PIECE)
	•	ช่างกด Start ใบที่ 1 → Token A ถูก mark RUNNING + time engine start
	2.	ช่างลืม Pause → ไปทำงานอื่น
	•	Time Engine fail-safe (จาก spec time engine ที่เราจะล็อกในไฟล์แยก) จะ:
	•	ถ้าระยะเวลานานเกิน threshold (เช่น 3 ชม. จาก expected 1 ชม.)
	•	Mark state เป็น “OVER_LIMIT” และให้ alert ใน backend / report
	•	ยังคงเก็บเวลาไว้ แต่ flag ว่า “ต้อง review” (ไม่ถือว่า defect โดยอัตโนมัติ)
	3.	ใน UI
	•	หน้า Work Queue ของ Supervisor จะเห็น Token A = “Running (Over Limit)”
	•	Supervisor สามารถ:
	•	ปรับเวลา (manual correction)
	•	หรือเพิ่ม comment: “ลืมกด Pause ไปช่วยงานอื่น”

จุดสำคัญคือ Behavior ของ STITCH บอกว่า:
	•	นี่คือ single-piece work
	•	เวลา = ต่อใบ
	•	ตัว Time Engine จะใช้ expected_duration จาก behavior เพื่อรู้ว่า “อะไรคือ over limit”

⸻

1.5 Bridge ไปส่วนอื่น (Token / Time / Component / QC)

Behavior spec นี้ ไม่ต้องแก้ DAG Designer ให้ซับซ้อน
แต่จะไป control:
	•	Token Engine
	•	ถ้า execution_mode = BATCH → Token รุ่น batch
	•	ถ้า SINGLE → Token ต่อยอดไปที่การ assign ให้ช่างแบบใบต่อใบ
	•	Time Engine
	•	time_tracking_mode = PER_BATCH/PER_PIECE บอกว่า เวลาให้เก็บที่ level ไหน
	•	default_expected_duration ใช้เพื่อตรวจ over-limit
	•	Component Binding
	•	allows_component_binding = 1 เฉพาะบาง Work Center เช่น HARDWARE_ASSEMBLY, PACKING, QC_FINAL
	•	QC
	•	allows_defect_capture = 1 → UI แสดง defect panel เมื่อปิดงาน node นี้

⸻

2) Leather Stock Reality – ปัญหาที่ยากที่สุดของโรงงานหนัง

จุดประสงค์: บันทึก "ความเป็นจริง" ของสต็อกหนัง ที่ไม่มี ERP ไหนในโลกแก้ได้ 100% แต่เราต้องทำให้ระบบเข้าใจโลกจริงให้มากที่สุด และเตือนมนุษย์ได้ก่อนตัดสินใจผิด

แนวคิดหลัก:
- สต็อกหนังในระบบ (เช่น 25.34 ตราฟุต) ไม่ได้บอกคุณภาพและ "สภาพจริง" ของหนังในชั้นวาง
- หนังที่เหลืออยู่ อาจเป็น:
  - แผ่นใหญ่ 1 แผ่น (ตัดได้หลายใบ)
  - เศษหลายชิ้นรวมกัน (ปะปนทั้งดี/เสีย, เล็ก/ใหญ่)
  - หนังที่มีตำหนิ (ใช้งานเฉพาะบางชิ้นได้)
- ผลคือ: ระบบบอกว่า "ตัวเลขเพียงพอ" แต่ในความจริง "ตัดใบใหญ่ไม่ได้" หรือ "ตัดได้แต่คุณภาพไม่ผ่านมาตรฐานแบรนด์หรู"

2.1 Reality Check – สิ่งที่ตัวเลข BOM มองไม่เห็น

ตัวเลขใน BOM + Stock ปกติจะคิดแบบนี้:
- 1 ใบใช้หนัง 4.5 ตราฟุต → ผลิต 10 ใบ = ต้องใช้ 45 ตราฟุต
- ถ้าในระบบมีสต็อกหนัง 60 ตราฟุต → ERP ทุกตัวจะบอกว่า "เพียงพอ" และอนุญาตให้สร้าง MO

แต่ในโรงงานจริง ปัญหาคือ:
- 60 ตราฟุตนั้น อาจประกอบด้วย:
  - แผ่นดีขนาดใหญ่ 30 ตราฟุต (ตัดใบใหญ่ได้)
  - เศษเล็ก ๆ 30 ตราฟุต (ตัดได้แต่ชิ้นเล็ก, ใช้เฉพาะ parts บางส่วน)
- ถ้า Design ต้องการ Panel ใหญ่ (เช่น หน้า/หลังใบ, ชิ้นพื้นใหญ่)
  → เศษเล็ก 30 ตราฟุตนั้น แทบไม่มีค่าในการผลิต Job นี้เลย
- สรุป: ระบบคิดว่า "มี 60" แต่ความจริง "ใช้ได้จริงแค่ 30" สำหรับ Job นี้

2.2 ประเภทของสต็อกหนัง (ในโลกจริง)

เพื่อให้ ERP เข้าใกล้ความจริงมากขึ้น เราควรยอมรับว่า หนัง 1 หน่วยในระบบ ไม่ใช่ตัวเลขลอย ๆ แต่มีลักษณะทางกายภาพ:

อย่างน้อยควรแยกความจริงออกเป็น 4 มิติ:
1) ขนาดชิ้น (Piece Size)
   - แผ่นเต็ม (Full hide / side)
   - ชิ้นใหญ่ (Panel-size)
   - ชิ้นกลาง
   - เศษเล็ก (Offcut)

2) คุณภาพ/โซน (Quality Zone)
   - พื้นที่ดี (Prime zone)
   - พื้นที่มีเส้นเลือด/ตำหนิ (Secondary)
   - พื้นที่ต้องหลบ (Reject zone)

3) รูปทรง (Shape)
   - แผ่นยาว, แผ่นสั้น, ชิ้นโค้ง, ชิ้นที่ถูกเจาะรูไปแล้ว ฯลฯ

4) ประวัติการใช้งาน (History)
   - เคยถูกใช้ตัด Job อะไรมาก่อน
   - เป็นเศษจากงาน Hatthasilpa หรือ Classic
   - เก็บไว้นานแค่ไหน (เก่าจนสี/สัมผัสเริ่มเปลี่ยนหรือยัง)

ระบบที่มองแค่ "จำนวนรวม" จะไม่มีทางรู้ว่า 25.34 ตราฟุต นั้นอยู่ในมิติไหนบ้าง

2.3 ภาพปัญหาที่พี่แป๋วพูดถึง (ระดับยากสุด)

สิ่งที่โรงงานเจอจริง ๆ คือ:
- ยิ่งผลิตนาน วันหนึ่งเศษจะยิ่งพอก → ตัวเลขในสต็อกจะดู "เยอะ" ขึ้นเรื่อย ๆ
- แต่พอ Planner กดสร้าง MO ใหม่
  → ERP บอก OK (มีสต็อกพอ)
  → แต่พอเข้าหน้างาน CUT จริง ๆ ช่างพบว่า "ตัดไม่ได้" เพราะไม่มีแผ่นใหญ่พอ

ผลลัพธ์คือ:
- แผนการผลิตพัง → ต้องเลื่อนส่งของ
- ต้องไล่หาหนังล็อตใหม่แบบกระชั้นชิด → ต้นทุนสูงขึ้น
- เศษหนังเก่าก็ยังคงพอกอยู่อย่างนั้น (ไม่เคยถูกใช้แก้ปัญหาอย่างแท้จริง)

2.4 แนวทางที่ ERP ระดับ Bellavier ควรทำ

ยอมรับความจริงข้อแรก: "ไม่มีระบบไหน solve 100%" แต่เราทำได้ดีกว่าระบบทั่วไปมาก ถ้าออกแบบมุมมองและ Workflow ให้ถูก

สิ่งที่ควรเกิดขึ้นใน Blueprint:

1) สร้างมุมมอง "Leather Reality View" แยกจาก Stock ปกติ
   - ใน /super_dag หรือ /hatthasilpa module ควรมีหน้า/รายงานที่:
     - แสดงจำนวนหนังตาม "ขนาดชิ้น" ไม่ใช่แค่ตัวเลข
     - แยกเป็น: Full Hide / Panel-size / Medium / Small Offcuts
     - highlight ว่า สำหรับ Product X (ที่ต้องใช้ Panel ใหญ่) ในโรงงานตอนนี้ "มี panel พอไหม" แยกจาก "มีหนังรวมพอไหม"

2) เชื่อม BOM กับข้อจำกัดชิ้นใหญ่ (Panel Constraint)
   - ที่ระดับ Product BOM เราอาจเพิ่ม meta:
     - requires_panel_parts = 1
     - min_panel_size_for_front_cm = W x H
   - เวลา Planner กดสร้าง MO:
     - System ไม่ดูแค่ total sq.ft. แต่ถามว่า "ในสต็อกตอนนี้ มีชิ้นที่ใหญ่กว่าขนาดที่ต้องใช้ กี่ชิ้น?"

3) ให้ช่าง CUT บันทึก "Residual Pattern" ทุกครั้งที่ตัด
   - เมื่อจบ Node CUT (Batch):
     - นอกจากบันทึก planned_qty / actual_qty / scrap_qty
     - ให้ช่างเลือกได้คร่าว ๆ ว่าเศษที่เหลือเป็นประเภทไหน:
       - ตัดแล้วเหลือ: 1 แผ่นใหญ่ + เศษเล็ก
       - หรือเหลือ: เศษเล็กทั้งหมด
   - ไม่ต้องแม่นเป็นมิลลิเมตร แต่เพียงพอให้ระบบเรียนรู้ว่า "หน้างานเหลือ panel พอไหมในอนาคต"

4) ทำ Warning Level ให้ Planner
   - เมื่อ Planner เปิดหน้าจอสร้าง MO สำหรับ Product ที่ต้องใช้ Panel ใหญ่
   - ระบบควรแสดงเตือน เช่น:
     - "Stock ตัวเลขเพียงพอ แต่ panel-size balance ต่ำ (เสี่ยงตัดไม่ได้)"
     - หรือ "Offcut ratio สูงผิดปกติ → แนะนำให้รัน MO สำหรับสินค้าที่ใช้เศษ"

5) ออกแบบ Product Line สำหรับใช้เศษโดยเฉพาะ
   - ERP ไม่ได้ต้องแก้ปัญหาการตัดทุกใบให้ได้
   - แต่ควรช่วย Owner มองเห็นว่า:
     - ตอนนี้เศษขนาดเล็กสะสมเยอะมาก → ควรออก Product Line ที่ใช้เศษเป็นหลัก (เช่น Card Holder, Key Charm ฯลฯ)
   - เชื่อมกับโมดูล Product/Design ว่า:
     - มีสินค้าประเภทใดบ้างที่สามารถใช้ offcuts เป็นวัตถุดิบหลัก

2.5 บทสรุปแนวคิด (สำหรับอนาคตของ Blueprint)

- เราไม่บอกว่า Bellavier ERP จะคำนวณได้ 100% ว่าหนังเหลือแบบไหน
- แต่เราบอกได้ว่า:
  - ระบบจะไม่หลอกคุณด้วยตัวเลขรวมแบบ ERP ทั่วไป
  - จะเตือนคุณเมื่อ "สต็อกตัวเลขดูสวย แต่สภาพจริงเสี่ยงมาก"
  - จะช่วยให้คุณใช้เศษให้เกิดมูลค่ามากที่สุด ผ่าน Product Line ที่ออกแบบมารองรับ

สิ่งนี้คืออีกหนึ่ง "Reality Layer" ที่ถูกบันทึกไว้ใน REALITY_EVENT_IN_HOUSE.md
เพื่อเป็นเข็มทิศระยะยาวว่า วันหนึ่ง Bellavier ERP ต้องมองเห็นโลกจริงของหนัง มากกว่าระบบใด ๆ ในตลาด

---
2.6 Leather Steward Workflow & Reconciliation Logic (เพิ่มจากการวิเคราะห์ล่าสุด)

ปัญหาสต็อกหนังที่ตัวเลขสวยแต่ใช้จริงไม่ได้ → สามารถบรรเทาได้ด้วยการมี “Leather Steward” ผู้รับผิดชอบคัดแยกเศษหนังให้ ERP เข้าใจโลกจริงมากที่สุด

แนวคิดการแก้ปัญหา:

1) สร้างบทบาทใหม่: Leather Steward  
   - ทำหน้าที่รวบรวมเศษหนังทุกวัน  
   - คัดแยกตาม bucket ที่ ERP ระบุ  
   - กรอกข้อมูลเข้า ERP ผ่าน UI ที่ออกแบบเฉพาะ

2) ระบบ Bucket ที่ควรใช้  
   buckets:  
   - FULL_HIDE / BIG_PANEL → ใช้ตัด panel ใหญ่ได้  
   - MEDIUM_PARTS → ใช้ตัดชิ้นส่วนกลาง  
   - SMALL_OFFCUT → ใช้ทำ small goods  
   - SCRAP_OR_UNKNOWN → ส่วนที่ไม่สามารถจำแนกได้  

3) Reconciliation Logic (สำคัญที่สุด)  
   ให้ระบบคำนวณความจริงแบบนี้ทุกครั้งที่มีการคัดแยก:

   - T = จำนวน sq.ft ใน stock จากระบบ (ตัวเลข accounting)  
   - B_total = ผลรวม sq.ft ของทุก bucket ที่ Leather Steward คัด  
   - ถ้า B_total < T → ส่วนต่างคือ B_unknown  
     → ERP บันทึกเป็น SCRAP_OR_UNKNOWN อัตโนมัติ  
   - ถ้า B_total > T → เตือนว่า “คัดเกินกว่าตัวเลขจริง” ต้องตรวจสอบใหม่  

4) KPI ที่ ERP จะคำนวณจาก bucket  
   - panel_ratio = B_panel / T → ประเมินความสามารถในการผลิตใบใหญ่  
   - offcut_ratio = (B_medium + B_small) / T → ประเมินมูลค่าเศษ  
   - unknown_ratio = B_unknown / T → วัดความไม่แน่นอนของสต็อก  

   ใช้เพื่อแสดง Warning ให้ Planner เมื่อจะสร้าง MO เช่น:  
   - “ตัวเลขรวมเพียงพอ แต่ panel-grade ต่ำมาก → เสี่ยงตัดใบใหญ่ไม่ได้”  
   - “เศษสะสมสูง → แนะนำผลิต small goods”  

5) Output ที่ควรเกิดขึ้นในระบบ  
   - Leather Reality View (หน้าใหม่)  
     แสดง stock ตาม bucket แทนตัวเลขรวม  
   - Warning & Suggestions  
     ปรากฏในหน้า Planner ก่อนสร้าง MO  
   - Scrap Intelligence  
     วิเคราะห์ว่า unknown_ratio เพิ่มขึ้นเพราะ  
     • คัดไม่ละเอียด  
     • เศษล้นคลัง  
     • ลอตหนังมีคุณภาพไม่ดี  

บทสรุป:  
ระบบนี้ไม่ต้องการความแม่นระดับเซนติเมตร แต่ช่วยให้ ERP มองเห็น “ความจริง” ของหนังมากกว่า ERP ทั่วไปหลายเท่า และลดปัญหาผลิตไม่ได้จริงแม้ stock number ยังดูดีมากก็ตาม