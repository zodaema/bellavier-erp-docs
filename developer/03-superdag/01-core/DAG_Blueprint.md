

# DAG Core Blueprint v1.0  
**Bellavier Group ERP – Atelier & Classic Production Engine**

This document defines the canonical foundational model of the Bellavier DAG Engine.  
It reflects all real-world atelier behaviors, batch logic, component flow, human errors, and production patterns discovered up to Nov 2025.  
This blueprint is the *source of truth* for all future DAG / Token Engine / Time Engine / Work Center designs.

---

# 1. Production Reality Model  
The system must support three real production flows:

## 1.1 Batch Flow  
Used in: Cutting, Skiving, Certain Prep  
Characteristics:  
- One worker processes many pieces at once  
- Single time duration produces multiple outputs  
- Yield may be lower/higher than target quantity  
- Loss, waste, mismatch is normal  
- Some components may need re-cutting  
  
System Requirements:  
- Batch Session  
- Volume input  
- Yield tracking  
- Batch → Token Split logic  

---

## 1.2 Single-Piece Handcraft (Hatthasilpa Flow)  
Used in: Hand-stitching, painting, assembly  
Characteristics:  
- One worker = one piece  
- Time-based workflow  
- Pause/Resume errors are common  
- Multi-worker contribution may happen  

System Requirements:  
- Continuous Time Engine  
- Auto error correction  
- Worker attribution  
- Rework loops  

---

## 1.3 Classic Line (Scan-Based Flow)  
Used in: OEM, Classic mass production  
Characteristics:  
- Station → Station  
- Driven by scan events  
- No constant time tracking  
- Needs safe-scan, reverse scan handling  

System Requirements:  
- Scan Engine  
- Missing scan recovery  
- Invalid sequence protection  

---

# 2. Component Reality Model  

## 2.1 Components Are Not Equal  
Component types:  
- With Serial (hardware, straps, metal sets)  
- Without Serial (lining, internal panels)  
- Disposable  
- Reusable metal parts  

System Requirements:  
- Component Type System  
- Component Serial Binding  
- Component Replacement Tracking  

## 2.2 Components Do NOT bind at Cutting  
Reasons:  
- Cutting is batch  
- Items get mixed  
- QC happens before assembly  
- Serial must match final assembly sequence  

System Requirements:  
- Binding occurs at Assembly node or QC pre-check  
- Late binding support  

## 2.3 Component Stock Movement Model  

Component lifecycle must track stock changes precisely.

### Flow
1. **component_stock_in** — initial receiving  
2. **component_stock_out (picking)** — issued before assembly  
3. **component_consumption** — consumed when bound to token  
4. **component_scrap** — defect, broken hardware, or mismatched component  

### Notes
- Binding does NOT equal stock out (picking event is separate)  
- Scrap events must decrease stock and log cause  
- Enables full traceability & cost accuracy  

---

# 3. Work Center Behavior Engine  

Work Center is not just a “name.”  
Each center has *structured behavior*:

### Behavior Attributes  
- requires_qty: boolean  
- supports_batch: boolean  
- supports_single: boolean  
- supports_scan: boolean  
- supports_time_engine: boolean  
- supports_component_binding: boolean  
- supports_qc: boolean  
- output_type: token | component-set | batch  
- paint_rounds: number (optional)  
- max_workers: number  

Examples:  
CUT: `{requires_qty: true, supports_batch: true}`  
EDGE PAINT: `{paint_rounds: 3}`  
ASSEMBLY: `{supports_component_binding: true}`  
QC: `{supports_qc: true}`  

## 3.1 Work Center Capacity Model  
Real factories operate under capacity constraints. Each Work Center must define:

### Capacity Attributes
- **max_tokens**: maximum number of active tokens a worker or work center can handle  
- **max_batch_size**: limit for batch-oriented nodes  
- **concurrent_workers**: how many workers can operate at this station simultaneously  
- **queue_limit**: optional limit for excessive workload  
- **machine_capacity**: if machines are used, defines cycle time and throughput  

### Purpose
This capacity model is used during MO creation and job dispatching to:
- prevent overload  
- estimate timeline  
- assign workers correctly  
- ensure realistic rending of factory throughput  

---

# 4. Node Model  

A Node has two dimensions:

### 4.1 Node Behavior  
“What this node *does*”  
CUT, SKIVE, EDGE-PAINT, STITCH, ASSEMBLE, QC, PACK  

Determines required actions:
- CUT → qty  
- EDGE PAINT → rounds  
- ASSEMBLY → component binding  
- QC → pass/fail codes  

### 4.2 Node Execution Mode  
“How the worker executes it”  
- BATCH  
- HAT_SINGLE  
- CLASSIC_SCAN  
- QC_SINGLE  

Behavior + Mode = Complete Node Definition  

---

# 5. Token Engine 2.0 Model  

Token must support all real production cases:

### 5.1 Core  
- token_id  
- job_ticket_id  
- node_id  
- worker(s)  
- start_time / end_time  
- status (active, paused, completed, rework)  

### 5.2 Batch & Split  
- batch_session_id  
- split into N tokens  
- propagate metadata  

### 5.3 Time Engine Integration  
- auto resume  
- error detection  
- drift correction  

### 5.4 Component Integration  
- component bindings  
- replacement tracking  
- mismatch error detection  

### 5.5 Rework Logic  
- fail → rework node creation  
- rework loop counter  
- scrap scenario  

---

# 5.1 Worker Skill Model  

Workers differ in specialization. Token routing must reflect real skill constraints.

### Skill Attributes
- **skill_type**: cutting, stitching, edge-paint, assembly, QC  
- **skill_level**: 1–5 (or free-form)  
- **certifications**: e.g., “edge paint level 3”  
- **can_handle_batch**: boolean  
- **can_handle_hat_single**: boolean  

### System Requirements
- Token dispatch must consider skill requirements of nodes  
- Designer may tag nodes with required skill_type + skill_level  
- System prevents assignment of unqualified workers  
- Enables future auto-routing / ML prediction  

---

# 6. Error Reality Model  
The ERP must anticipate >50 real-world errors.

### Categories:  
#### Batch Errors  
- incomplete qty  
- mismatch between expected vs actual  

#### Worker Errors  
- forgot start  
- forgot pause  
- start multiple tokens  
- wrong worker  

#### QC Errors  
- failed inspection  
- defect classification  
- mis-binded components  

#### Component Errors  
- serial mismatch  
- missing component  
- wrong batch  

#### Scan Errors  
- reverse scan  
- missing scan  
- invalid node sequence  

System Requirements:  
- Auto-detection  
- Auto-recovery  
- Token correction tools  
- Error logs  

---

# 7. DAG Designer Requirements  

DAG Designer must allow:  
- Behavior selection  
- Execution mode selection  
- Work Center assignment  
- Component requirements  
- QC handling  
- Batch flags  
- Node-level metadata rules  

Designer does NOT determine handcraft vs batch.  
This is determined by MO or job ticket.

---

# 8. Materialization Rules (During MO Creation)

When a user creates MO (Classic) or Hatthasilpa Job:  
System must derive:

- token model  
- batch session needs  
- execution modes  
- component worklist  
- serial generation plan  
- QC routing  
- timeline estimate  

All derived from:  
- DAG Graph  
- Work Center Behavior  
- BOM  
- Production mode (HAT vs CLASSIC)  

---

# 9. Major Design Principles  

1. **Workers make mistakes — system must self-heal.**  
2. **Batch is first-class citizen.**  
3. **Components bind late, not early.**  
4. **Nodes have behavior + mode (two axes).**  
5. **Token Engine is the universal ledger of work.**  
6. **DAG Designer must remain neutral and reusable.**  
7. **Hatthasilpa ≠ Classic — same graph, different execution model.**  

---

# 10. Parallel Node Support  

Some production tasks can occur simultaneously:
- drying after edge-paint  
- pre-assembly prep  
- machine-aided steps that run concurrently  

### Requirements
- DAG must allow parallel branches  
- Token system must track independent timelines  
- Final merge node must validate completion of all parallel tasks  

# 11. Machine Step Support  

In preparation for machinery integration:
- log machine usage  
- machine calibration cycles  
- cycle time modeling  
- safety interlocks for scan-based stations  

---

# 12. Future Extensions  
- Multi-worker attribution scoring  
- Skill-based routing  
- Machine learning for workload prediction  
- Cost calculation per node  
- Forensic Traceability for brand certification  

---

เหตุการณ์

🔥 PART 1 — เหตุการณ์จริงในโรงงานหัตถศิลป์ที่ต้องคิด (ครบทุกมุม 50+ ข้อ)

แบ่งเป็นหมวดเพื่อให้คุณจัดการได้ง่าย

⸻

1) เหตุการณ์ด้านงาน Batch (Cutting, Prep, Skiving)

A. ขณะตัดงาน
	•	ช่างตั้งใจตัด 20 ชุด → แต่ตัดจริง 18 เพราะหนังไม่พอ
	•	ตัดอยู่ 10 นาที → ไฟดับ → มาอีกวันค่อยตัดต่อ
	•	ช่างลืมกด Pause → เวลาไหลไป 3 ชม.
	•	ตัดผิดแบบ → ต้องทิ้ง 3 ชิ้น ไม่สามารถใช้ในใบถัดไป
	•	ตัดใบ 1–5 ใช้หนังแผ่น A → ใบ 6–10 ใช้หนังแผ่น B (ซีเรียลต้นทางต่างกัน)
	•	หนังมีตำหนิ → ต้องเลือกตัดชิ้นใหม่ (“rework ของ component”)

B. หลังตัดเสร็จ
	•	ตัดมากกว่าที่ต้องการ (เกิน 2 ชิ้น) → กลายเป็น stock components?
	•	ตัดน้อยกว่าที่ต้องการ → ต้องกลับมาที่ Node นี้อีก
	•	บางชิ้นต้อง “แยกชิ้นพิเศษ” เช่น ลิ้น, กระดุม, หูหิ้ว → ต้องนับเป็น component ชนิดอื่น
	•	เกิดงาน “ชิ้นหาย” ระหว่างเดินจาก CUT → EDGE PAINT

⸻

2) เหตุการณ์ด้านการเย็บ (Hatthasilpa Single Work)

A. ระหว่างเย็บ 1 ใบ
	•	ช่างลืมกด Start → ทำงานไปแล้ว 20 นาที → เวลาไม่ถูกบันทึก
	•	ช่างกด Pause แต่ไปทำงานใบอื่นก่อน → เวลาไม่ตรงจริง
	•	เย็บผิด → ต้อง “rework node” และให้เวลา rework แยกจากเวลาเย็บปกติ
	•	เย็บอยู่ดีๆ แต่ช่างต้องไปช่วยงานอื่น → กระทบเวลา
	•	ช่างเย็บช้าเพราะสุขภาพไม่ดีวันนี้ → เวลาผันผวน
	•	ช่างเย็บแบบลัดขั้นตอน ทำก่อนหลังผิดลำดับ DAG

B. หลังเย็บเสร็จ
	•	งานตก (drop) → ขอบถลอก ต้องส่งกลับ Node ต้นทาง
	•	งานลืมส่งต่อ → เวลาค้างอยู่ใน Node
	•	เย็บผิดสีด้าย → ต้องย้อมใหม่ หรือใช้เวลาลอกด้ายเดิมก่อนเย็บใหม่

⸻

3) เหตุการณ์ด้านการทาสีขอบ (Edge Paint)

Edge Paint มีปัญหาเยอะที่สุดในของจริง เช่น:
	•	ต้องทา 2–3 รอบ แต่ Worker ลืมว่าถึงรอบไหนแล้ว
	•	งานต้อง “รอแห้ง” 10–20 นาที แต่ช่างลืมจับเวลา
	•	ทาผิดสี → งานเสียหาย, ต้องกลับไป Node เย็บ
	•	บางงานแห้งเร็วกว่างานอื่น → กระบวนการไม่ได้เป็น batch จริงๆ
	•	มี “Edge Paint Specialist” → แผนการจัดคิวคนอาจซับซ้อน

⸻

4) เหตุการณ์ด้านประกอบอะไหล่ (Hardware Assembly)
	•	Hardware หาย หรือจำนวนไม่พอ
	•	ผิดรุ่น เช่น Strap Gold → Body Black Hardware mismatch
	•	ช่างนำอะไหล่ผิดล็อตมาใช้ → Serial ไม่ตรง
	•	ช่างประกอบจุดผิด ทำให้ชิ้นงาน “ต้องเปลี่ยนฝา” หรือเปลี่ยนห่วงใหม่
	•	ขณะประกอบพบว่า “Hole” ไม่ตรงตำแหน่ง → ต้องย้อนกลับไป STITCH

⸻

5) เหตุการณ์ด้าน QC (ดีที่สุดสำหรับตั้ง Logic)

QC เป็น Node ที่แตกแขนงเยอะที่สุด:

A. QC รันเดียว
	•	PASS → ไปต่อ
	•	FAIL → Rework (ย้อน Node)
	•	FAIL ด้วยเหตุผลหนัก → ทิ้งงาน, ล้าง Serial

B. Multi-level QC
	•	QC 1 → QC 2 → QC Final
แต่ใบที่ fail ใน QC 2 อาจต้องกลับไป QC 1 ใหม่หรือกลับไปเย็บ

C. QC ต้องมี “Defect Code”

เช่น
	•	EP01 – สีขอบไม่เรียบ
	•	SEW05 – ด้ายหลุด
	•	CUT02 – ขอบหนังเบี้ยว

D. QC ชิ้นส่วน (component level QC)

เมื่อเราเริ่มมี component serial ต้อง QC component ก่อนประกอบด้วย

⸻

6) เหตุการณ์ด้าน Token Engine / Batch→Single Transition
	•	Batch CUT 20 ใบ → จริงๆ เหลือ 17 (ต้อง split/merge tokens)
	•	Single 1 ใบ → ต้องแตกย่อยตาม component (ไม่ใช่ token จริง แต่เป็น shadow-child)
	•	งานจาก Batch ต้องกระจายให้ช่างหลายคนเย็บ → Token distribution by skill
	•	Token merge (rare) เช่น เอาสายเก่ามาใช้ซ้ำ ใน limited cases

⸻

7) เหตุการณ์ด้าน Time Engine (ทุกปัญหาที่เกิดได้จริง)

A. เวลาไม่เดิน
	•	ช่างไม่อยู่หน้าเว็บ
	•	JS หยุดทำงาน
	•	Session หมดอายุ
	•	Internet หาย → Resume แล้วเวลาขาดช่วง
	•	Time Engine drift ถ้าเปิด tab ไว้ข้ามวัน

B. ช่างสลับงานกลางคัน
	•	Start งาน A → ไปทำงาน B → กลับมางาน A แต่ลืม Pause
	•	Start 2 ใบในเวลาเดียวกัน (ผิด Logic)

C. งานเกินเวลา (over limit)
	•	Node ระบุเวลามาตรฐาน 30 นาที แต่ช่างใช้ 3 ชั่วโมง
→ ต้องอธิบายเวลานั้นใน backend / report

⸻

8) เหตุการณ์ด้าน PWA Classic Line (Scan)
	•	Worker scan serial ผิด
	•	Scan ไม่ติด → QR ลอก → ต้องมี manual fallback
	•	Scan node-out แต่ลืม scan node-in ของ Node ต่อไป
	•	Worker ย้ายงานผิด Node

⸻

9) เหตุการณ์ด้าน Component Serial Binding

ปัญหาที่เจอบ่อยที่สุดใน luxury brand:
	•	รายการ component ไม่ครบ
	•	Component Serial ไม่ตรงล็อต (ปนกัน)
	•	Component ถูกเปลี่ยนหลัง QC แล้ว (“swap problem”)
	•	Worker ผูก serial ผิด (ควร bind Node-level UI)
	•	บาง component bind ที่ Node A บาง component bind ที่ Node B → ต้อง support multi-binding points
	•	Component serial เกิดหลังจากประกอบบางขั้นตอน ไม่ได้เกิดตอน CUT

⸻

10) เหตุการณ์เกี่ยวกับ MO & Job Execution
	•	งานเร่งด่วน → ต้อง override DAG step
	•	เปลี่ยนแผนกระบวนการกลางทาง (DAG v2)
	•	Worker transfer งานผิด MO
	•	MO 10 ใบ → split เป็น 7 + 3 เพราะหนังไม่พอ
	•	Rework ไม่ควรสร้าง Serial ใหม่ (มิฉะนั้น trace พัง)

⸻

⚡ PART 2 — จากเหตุการณ์ทั้งหมดนี้ ต้องกลับไปปรับ Logic อะไร?

ผมจะสรุปให้เป็น แผนสำคัญ 8 หมวด ที่ต้องรีบ implement:

⸻

1) Work Center Behavior ต้องเป็นแกนหลัก

CUT / EDGE / ASSEMBLY / QC / GENERIC → มี behavior ของมันเอง
และ behavior dictates:
	•	UI
	•	Required fields
	•	Batch / Single
	•	Time Engine pattern
	•	Component binding permission

→ อันนี้เราต้องทำก่อน Node Mode เสียอีก

⸻

2) Node Mode ควรเป็นเรื่องของ “Time & Execution Behavior” เท่านั้น

เช่น:
	•	BATCH_QUANTITY
	•	HAT_SINGLE
	•	CLASSIC_SCAN
	•	QC_SINGLE

แต่ Node Mode ไม่ควรบอกว่า Node คือ CUT หรือ EDGE หรือ STITCH
→ นั่นควรไปอยู่ใน Work Center Behavior

⸻

3) Token Engine ต้องรองรับ Batch→Single Split, Single→QC Transition

ตอนนี้ยังไม่มีระบบ:
	•	split token จาก batch session
	•	merge / clone token
	•	track component-level progress

ต้องทำก่อนเริ่ม build DAG จริงในโรงงาน

⸻

4) Time Engine ต้องรองรับ “fail-proof” และ “offline-safe”

ต้องมี:
	•	recovery state
	•	drift correction
	•	pre-pause
	•	conflict check (1 คน ห้ามมี 2 งาน active)

⸻

5) Component Serial Binding ต้องผูกกับ Node Behavior

เช่น:
	•	HARDWARE_ASSEMBLY → bind hardware components
	•	EDGE → bind edge paint batch id
	•	QC_FINAL → verify binding completeness
	•	PACKING → print serial kit

⸻

6) QC ต้องเป็นระบบ 2 ชั้นอย่างน้อย
	•	QC Single (ใบต่อใบ)
	•	QC Repair (ย้อนกลับ)
	•	QC Final (ก่อนออกโรงงาน)

⸻

7) PWA Scan Flow ต้องรองรับ incomplete scan / error recovery

อย่างเช่น:
	•	LOST NODE
	•	MISSING SCAN
	•	REVERSE SCAN

⸻

8) DAG Designer ต้องเป็นกลาง และให้ Work Center Behavior เป็นตัวบอกความจริง

ไม่เช่นนั้น Designer จะซับซ้อนเหมือน SAP (ซึ่งเราไม่ต้องการ)

⸻

# End of DAG Core Blueprint v1.0