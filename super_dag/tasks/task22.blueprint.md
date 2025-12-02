

# Phase 22 – Canonical Self-Healing System (Blueprint)

**Status:** BLUEPRINT  
**Date:** 2025-01-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  

**Scope of Phase 22:**  
เปลี่ยน Canonical Events + Timeline + Integrity Layer ที่สร้างไว้ใน Phase 21 (21.1–21.8) ให้กลายเป็น  
“ระบบซ่อมตัวเอง” (Self-Healing DAG + Time Engine) ที่ **แก้ปัญหาเชิงข้อมูลอย่างมีวินัย** โดยไม่ทำลาย Logic Framework และ Close System ที่วางไว้

> Phase 21 = “เห็นและเข้าใจความจริงอย่างละเอียด”  
> Phase 22 = “เข้าไปปรับความจริงให้ตรงกับ Logic โดยไม่ทำพัง”

---

## 1. เป้าหมายหลักของ Phase 22

1. **สร้าง Self-Healing Layer** ที่ทำงานบน Canonical Events / Timeline:
   - ซ่อม event ที่หาย / ผิด  
   - ซ่อม sessions ที่ขัดกัน  
   - ซ่อม timeline ให้สมเหตุสมผล  
   - ทำทั้งหมดนี้แบบ **ควบคุมได้, traceable, reversible**

2. **ยกระดับ Canonical Events ให้เป็น Source of Truth สำหรับเวลา (Time)**
   - ทำให้เวลาใน `flow_token` และระบบ reporting **ซิงค์กับ canonical timeline**  
   - ลดการพึ่ง field legacy ที่ไม่ยึดตาม events

3. **วาง Framework สำหรับ SLA, Throughput, Productivity, และ Root Cause Analysis**
   - เมื่อ Self-Healing เสร็จ → ขยายต่อไปยัง SLA Engine, Work Center Performance, Craftsman Time Analysis ฯลฯ

---

## 2. ขอบเขตของ Phase 22 (High-Level)

Phase 22 แบ่งเป็น 4 Layer:

1. **L1: Local Repair** – ซ่อมทีละ token/node  
2. **L2: Timeline Reconstruction** – สร้าง timeline/เวลาใหม่จากพฤติกรรมจริง  
3. **L3: Batch Repair & Governance** – ซ่อมทีละกลุ่ม / ทั้งระบบภายใต้กติกาชัดเจน  
4. **L4: SLA & Metrics Foundation** – ใช้ข้อมูลที่ซ่อมแล้วเพื่อคำนวณ SLA/Lead Time อย่างน่าเชื่อถือ

---

## 3. พื้นฐานที่มีอยู่แล้วจาก Phase 21

### 3.1 Canonical Layer พร้อมใช้

จาก Task 21.1–21.5 เรามีแล้ว:

- `NodeBehaviorEngine` + Internal Registry  
- Canonical Events Pipeline:
  - Behavior → canonical_events → `token_event`  
- `TokenEventService` – persist events  
- `TimeEventReader` – อ่าน events → timeline + sessions  
- `TokenLifecycleService` – sync เวลาเข้า `flow_token` (หลัง flag)

### 3.2 Integrity & Observability Layer

จาก Task 21.6–21.8:

- Dev Timeline Debugger: `/tools/dev_token_timeline.php`  
- `CanonicalEventIntegrityValidator` – 10+ rules  
- `BulkIntegrityValidator` – validate แบบ batch  
- CLI Tools: `dag_validate_cli.php`  
- Dev Timeline Report: `/tools/dev_timeline_report.php`

**สรุป:**  
Phase 21 = มองเห็นปัญหา, ตรวจเจอ pattern, สแกนทั้งระบบ, แต่ยัง **ไม่ซ่อม**

---

## 4. หลักการ (Principles) ของ Phase 22

1. **Logic > Data**  
   - Data (events) สามารถผิดได้  
   - Logic/กติกา = แหล่งอ้างอิงในการซ่อม  
   - Self-Healing ต้อง align กับ Axioms จาก `Node_Behavier.md` + `time_model.md`

2. **No Silent Mutation**  
   - การซ่อมทุกครั้งต้อง:
     - ถูกบันทึกเป็น “Repair Event” / “Audit Trail” แยกจาก canonical event ปกติ  
     - สามารถย้อนดูที่มาได้ว่าซ่อมอะไร, เพราะอะไร, เมื่อไร, โดยใคร/engine ตัวไหน

3. **Repair is Layered & Scoped**  
   - ไม่ซ่อมทุกอย่างในครั้งเดียว  
   - ซ่อมตามลำดับชั้น:
     - L1: missing event/small fix  
     - L2: session/timeline  
     - L3: batch  
   - มีเงื่อนไขชัด: “อะไรซ่อมได้, อะไรห้ามยุ่ง, อะไรต้อง escalate”

4. **Only Completed Tokens are Eligible (ในช่วงแรก)**  
   - Phase 22 เริ่มจากซ่อมเฉพาะ token/node ที่อยู่ในสถานะ “จบแล้ว”  
   - ห้ามซ่อม token ที่กำลัง PROCESSING อยู่ เพื่อเลี่ยง race condition

5. **Validate–Then–Commit**  
   - ทุกครั้งที่ซ่อม:
     - generate repair plan → apply → re-run validator → ถ้าผ่าน → commit  
     - ถ้าไม่ผ่าน → rollback / mark “UNREPAIRABLE”

6. **Feature-Flag Controlled**  
   - Self-Healing ต้องถูกควบคุมผ่าน feature flag แยกจาก `NODE_BEHAVIOR_EXPERIMENTAL`  
   - เปิดใช้ทีละ environment / tenant / work center ได้

---

## 5. แบ่ง Phase 22 เป็น Sub-Tasks (Draft Roadmap)

### 22.1 – Local Repair Engine v1 (Missing / Minimal Events)

**เป้าหมาย:**  
สร้างระบบที่สามารถซ่อม “เคสพื้นฐานที่ชัดเจน” ได้ เช่น:

- COMPLETE มี แต่ START ไม่มี → เติม START ย้อนหลัง  
- มี NODE_COMPLETE แต่ไม่มี timeline (duration, sessions) → สร้าง session สั้น ๆ ตั้งต้น  
- PAUSE / RESUME ขาดฝั่งหนึ่งใน pattern ง่าย ๆ

**Output:**  
- `LocalRepairEngine` class  
- Repair rules กับ mapping ปัญหา → action  
- `repair_plan` structure (จะเก็บใน audit table)

---

### 22.2 – Repair Event Model & Audit Trail

**เป้าหมาย:**  
วางโครงสร้าง “Repair Events” ให้ชัด:

- ตารางใหม่: `token_repair_log` (หรือคล้ายกัน)  
- บันทึก:
  - token_id, node_id  
  - repair_type (MISSING_START, SESSION_FIX, TIMELINE_REWRITE, …)  
  - before/after snapshot (สั้น ๆ + reference)  
  - canonical_event_ids ที่ถูกแตะ  
  - เวลา / ผู้กระทำ (ระบบ/คน)  

**Output:**  
- Schema audit  
- Service สำหรับเขียน/อ่าน repair log  
- เชื่อมเข้ากับ LocalRepairEngine

---

### 22.3 – Timeline Reconstruction v1

**เป้าหมาย:**  
ใช้ canonical events ที่มี + heuristic + config เพื่อ reconstruct timeline เมื่อตรวจพบว่า:

- sessions gap แปลก  
- เวลาขาด/สลับ  
- duration ไม่สมเหตุสมผล (เช่น นาน 0ms หรือ 48 ชม. ทั้งที่เป็นงานเล็ก)

**แนวทาง:**  
- ใช้ `TimeEventReader` + rule เพิ่มเติม เพื่อเสนอ “alternative timeline”  
- เก็บเป็น “proposed timeline” ก่อน commit  
- commit เฉพาะกรณีที่ผ่าน validator รอบสอง

---

### 22.4 – Batch Repair Tools (CLI + Dev)

**เป้าหมาย:**  
ใช้ BulkIntegrityValidator + LocalRepairEngine + TimelineRebuilder เพื่อซ่อม:

- tokens ที่ผิดภายในช่วงเวลา (เช่น 24 ชม. ที่ผ่านมา)  
- tokens ใน range / work_center / job_type เฉพาะ

**แนวทาง:**  
- CLI command เช่น:
  - `dag_repair_cli.php`  
  - `repair-latest --hours=24`  
  - `repair-range --from=1000 --to=2000`  
- แสดง summary:
  - repair สำเร็จ / ล้มเหลว  
  - ปัญหาที่ซ่อมได้ / ซ่อมไม่ได้

---

### 22.5 – Canonical Time as Primary Source (Selective Promotion)

**เป้าหมาย:**  
ทำให้ `flow_token` และ reporting บางส่วนใช้ canonical timeline เป็น source of truth:

- ใน dev/staging → ใช้ canonical → sync ลง `flow_token`  
- ใน production → เริ่มจาก:
  - Hatthasilpa line ก่อน  
  - Work center แรก ๆ ที่ควบคุมง่าย

**แนวทาง:**  
- Feature flag ใหม่ เช่น `TIME_CANONICAL_PRIMARY`  
- ถ้า flag เปิด:
  - `flow_token` อ่านจาก canonical timeline  
- ถ้า flag ปิด:
  - ใช้ logic legacy เป็นหลัก

---

### 22.6 – SLA & Lead Time Foundation

**เป้าหมาย:**  
ใช้ timeline ที่ “ผ่านการซ่อมแล้ว” เป็นฐานสร้าง:

- Node-level SLA (เช่น เย็บมือควรไม่เกิน X นาที)  
- Job-level SLA (MTO vs OEM)  
- Work center lead time distribution

**แนวทาง:**  
- เพิ่ม service / view สำหรับ node lead time distribution  
- ยังเป็น dev-only / internal use ก่อน

---

## 6. Safety Model (สำคัญมาก)

1. **Repair only “Closed Context”**  
   - token ที่ status = COMPLETE / CANCELLED  
   - job_ticket ไม่ถูกแก้แล้ว  
   - ไม่ยุ่ง flow ที่กำลัง active

2. **All Repair Actions = Append-Only**  
   - canonical events เดิมไม่ถูกลบ, แต่ “ปิดทับด้วย repair events”  
   - ทำให้ย้อน reconstruct history ได้ว่าอะไรเกิดขึ้นจริงก่อนซ่อม

3. **Manual Override ยังเป็นไปได้**  
   - Platform Super Admin สามารถ mark token ว่า:
     - DO_NOT_REPAIR  
     - FORCE_REPAIR  
   - เพื่อควบคุม edge cases

4. **Two-Step: Propose → Apply**  
   - Engine เสนอ repair_plan ก่อน  
   - dev/architect หรือ auto-policy → ตัดสินใจ apply/ignore

---

## 7. Feature Flags ใน Phase 22

เสนอ flag ใหม่ (ชื่อจริงอาจถูกปรับให้ตรงกับระบบ):

- `CANONICAL_SELF_HEALING_LOCAL`  
  - เปิด LocalRepairEngine เฉพาะเคส basic  
- `CANONICAL_SELF_HEALING_BATCH`  
  - เปิดการ repair ผ่าน CLI / batch  
- `TIME_CANONICAL_PRIMARY`  
  - ใช้ canonical time เป็น source ของ `flow_token`/report บางส่วน

แต่ละ flag:

- default = OFF  
- เปิดเฉพาะ dev/staging ก่อน  
- production rollout ต้องมี runbook

---

## 8. Interaction ระหว่าง Behavior Engine vs Repair Engine

1. **Behavior Engine = Producer (truth from operations)**  
2. **Integrity Validator = Judge (ตรวจว่าผิดจากกติกาไหม)**  
3. **Repair Engine = Surgeon (ผ่าตัดแก้เล็กน้อยตามคำวินิจฉัย)**  

ลำดับ:

1. Behavior สร้าง canonical events  
2. Integrity Validator ตรวจ  
3. ถ้าผิด → เสนอ repair_plan  
4. ถ้าอนุมัติ → Repair Engine สร้าง repair events / ปรับ timeline  
5. Validator ตรวจอีกครั้ง  
6. ถ้าผ่าน → sync canonical → flow_token / reporting  

**ห้าม** ให้ Repair Engine สร้าง behavior ใหม่เอง (เช่น ย้อนสร้างการ scan)  
มันมีสิทธิ์แค่ “เรียบเรียงความจริงที่มีอยู่แล้ว” + เติมส่วนที่หายไปตาม rule ที่กำหนด

---

## 9. ผลลัพธ์ที่คาดหวังเมื่อ Phase 22 เสร็จ

1. Canonical Events Pipeline:
   - มีระบบตรวจจับปัญหา (21.x)  
   - มีระบบซ่อมปัญหา (22.x)  
   - มี audit trail ว่าซ่อมอะไร, เมื่อไร, ทำไม

2. เวลาในระบบ:
   - สะท้อน reality ของงานช่างอย่างน่าเชื่อถือ  
   - ใช้ต่อยอด SLA, lead time, capacity planning ได้

3. ระบบ ERP:
   - แข็งแรงพอที่จะรองรับสถานการณ์ไม่ปกติ (ไฟดับ, network drop, คนลืม scan)  
   - ไม่ต้องพึ่งแค่ discipline ของคน แต่มี “second layer of truth” ช่วยเก็บและซ่อม

---

## 10. Next Steps หลัง Blueprint

1. สร้างไฟล์:
   - `task22_1.md` – Local Repair Engine v1  
   - `task22_2.md` – Repair Event & Audit Trail  
   - `task22_3.md` – Timeline Reconstruction v1  
   - `task22_4.md` – Batch Repair Tools  
   - `task22_5.md` – Canonical Time as Primary Source  
   - `task22_6.md` – SLA & Lead Time Foundation

2. เริ่มจาก 22.1 → 22.2 → 22.3 เป็นแกน  
   - 22.4–22.6 คือ layer เสริมและ consumer ของ Self-Healing Core

3. ทุก Task ต้องอ้างอิง Blueprint นี้  
   - หากมีการเปลี่ยนกติกาในอนาคต ให้แก้ที่ blueprint ก่อนเสมอ