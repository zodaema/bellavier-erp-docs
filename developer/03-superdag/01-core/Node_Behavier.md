# Node Behavior & Node Modes (DAG Core)

> **Status:** Draft-Spec – used as the canonical logic reference for DAG, Work Centers, Time Engine, and Component Binding  
> **Scope:** ทั้ง Hatthasilpa line (work_queue) และ Classic line (PWA Scan)  

เอกสารนี้รวบรวม **Logic ที่เราคุยและตัดสินใจร่วมกัน** เกี่ยวกับพฤติกรรมของ Node, Work Center, Node Mode, Time Engine และ Component Serial Binding ให้เป็นมาตรฐานเดียวสำหรับ Bellavier Group ERP

---

## 1. Concept Overview

### 1.1 Entity หลักที่เกี่ยวข้อง

- **Product**
  - มี BOM (Bill of Materials) ระบุว่ากระเป๋า 1 ใบใช้ Component อะไรบ้าง, กี่ชิ้น
- **DAG (Routing Graph)**
  - เป็น “แผนการเดินทางของงาน” จาก Node แรกไป Node สุดท้าย
  - อธิบาย process flow แต่ **ไม่ระบุ BOM** (BOM อยู่ใน Product)
- **Node**
  - จุดปฏิบัติงานหนึ่ง ๆ ใน DAG (เช่น CUTTING, STITCHING, EDGE PAINT, QC)
  - ผูกกับ **Work Center** หนึ่งตัว
- **Work Center**
  - ใน DB: อยู่ใน `work_centers` table
  - มีฟิลด์ `node_mode` (Behavior Code) เป็น enum ที่ Framework กำหนด
  - สามารถมี `config_json` สำหรับ config เพิ่มเติม (เช่น default qty, require_quantity ฯลฯ)
  - Node ที่ผูกกับ Work Center จะ “รับ” node_mode จาก Work Center โดยอัตโนมัติ
- **Node Mode (Node Character)**
  - เป็น “ประเภทพฤติกรรม” ที่ Framework กำหนด เช่น:
    - `BATCH_QUANTITY`
    - `HAT_SINGLE`
    - `CLASSIC_SCAN`
    - `QC_SINGLE`
  - เป็น **enum ตายตัวใน PHP** ไม่ให้ user สร้างเอง
- **Token**
  - ตัวแทน “งาน 1 หน่วย” ใน DAG (เช่น กระเป๋า 1 ใบ)
  - เคลื่อนที่จาก Node → Node ตาม DAG
- **Batch Session**
  - ตัวแทนการทำงานแบบ Batch ที่ Node หนึ่ง ๆ (เช่น ตัดงาน 10 ใบพร้อมกัน)
  - มีจำนวนงาน (quantity) ผูกอยู่
- **Time Engine**
  - ระบบจับเวลา (start / pause / resume / complete) สำหรับ Token และ Batch Session
  - ใช้กับ Hatthasilpa line เป็นหลัก (work_queue)
- **Component Serial Binding**
  - การผูก Serial Number ของ Components (เช่น Shoulder Strap, Lock, Chain) เข้ากับ Serial หลักของกระเป๋า

---

### 1.2 Design Axioms (กติกาหลัก – ห้ามแก้ไขโดยไม่ประกาศเปลี่ยนรุ่น)

Axioms เหล่านี้คือ “กติกาหลัก” ของระบบ DAG + Work Center + Time Engine  
ถ้าใคร (หรือ AI Agent) จะเปลี่ยน **ต้องถือว่าเป็นการเปลี่ยนรุ่นของสถาปัตยกรรม** และต้องเขียน spec ใหม่แทน ไม่ใช่แก้เบี้ยว ๆ ในไฟล์นี้

**AXIOM A1 – Graph เป็นกลาง (Line-Neutral Graph)**  
- DAG Graph 1 ชุด **ใช้ได้ทั้ง Classic และ Hatthasilpa**  
- Graph **ไม่มี field หรือ flag `line_type`**  
- Designer ตอนวาดกราฟ **ไม่ต้องเลือก** ว่ากราฟนี้เป็นของ Classic หรือ Hatthasilpa  
- ความเป็น Classic/Hatthasilpa ถูกกำหนดที่ตอนสร้างงาน (MO / Hatthasilpa Job) เท่านั้น

**AXIOM A2 – Work Center คือคนกำหนด Node Mode (Behavior Code)**  
- ตาราง `work_centers` ต้องมีฟิลด์ `node_mode` (enum) เสมอ  
- Node ในกราฟ **ต้องไม่ได้กำหนด node_mode เอง** แต่ “รับ” จาก Work Center ที่ผูกอยู่  
- Work Center CRUD คือที่เดียวที่ให้ตั้งค่า `node_mode` ได้ (ผ่านการเลือกจาก enum)

**AXIOM A3 – Runtime ตีความจาก (node_mode + line_type)**  
- Execution จริง (UI, Time Engine, Scan Flow ฯลฯ) = ฟังก์ชันของคู่:
  - `workCenter.node_mode`
  - `job.line_type` (`classic` หรือ `hatthasilpa`)
- ห้ามใช้ “ชื่อ Work Center” หรือ “ชื่อกราฟ” เป็นตัวเขียน if/else behavior โดยตรง  
  (ต้อง map ผ่าน `node_mode` เสมอ)

**AXIOM A4 – Designer เป็นกลางในแง่ Behavior**  
- ในหน้าจอ DAG Designer:
  - Designer เลือก Node + Work Center เท่านั้น
  - ไม่ให้เลือก/แก้ `node_mode` ที่ระดับ Node
- ถ้าต้องการ behavior ใหม่ → เพิ่ม enum ใหม่ใน NodeMode + ให้ Work Center ใช้ enum นั้น

**AXIOM A5 – BOM / Product แยกจาก Graph**  
- Product + BOM บอกว่า “หนึ่งใบใช้ components อะไรบ้าง”  
- DAG Graph บอกว่า “งานเดิน Node ใดบ้าง”  
- ห้ามยัดข้อมูล BOM ลงใน Graph โดยตรง ให้เชื่อมผ่าน Job Ticket / Component Binding ตาม spec

---

## 2. Philosophy: Node Mode ถูกกำหนดอัตโนมัติที่ runtime จาก MO/Job ไม่ใช่สิ่งที่ผู้ใช้เลือกใน Designer

### 2.1 ทำไม Node Mode ต้องอยู่ใน PHP (Framework Layer)

- Node Mode กำหนด:
  - รูปแบบ UI ที่จะให้ช่างใช้งาน (work_queue / PWA)
  - การสร้าง / แบ่ง Token / Batch Session
  - วิธีการคำนวณเวลาใน Time Engine
  - วิธีการเชื่อมกับ Component Binding / Traceability
- ถ้าให้ผู้ใช้สร้าง Mode เองผ่าน CRUD:
  - จะควบคุมเวลา, trace, และความถูกต้องไม่ได้
  - เสี่ยงให้ DAG “พังระดับ design” (เช่น ไม่มีเวลา, ไม่มี qty แต่ทำงานแบบ batch)
- ดังนั้น:
  - **Node Mode = Framework-level concept**  
  - กำหนดไว้ใน PHP เป็น enum ที่ชัดเจน  
  - Work Center เลือกใช้จากรายการ Mode ที่มีให้ (ผ่าน Work Center CRUD) และ Node ที่ผูกกับ Work Center จะได้ node_mode จาก Work Center เสมอ – Designer ไม่กำหนด node_mode โดยตรง

### 2.2 สิ่งที่ผู้ใช้ปรับได้

- เลือก `node_mode` ให้แต่ละ Work Center จาก enum ที่ Framework กำหนด (ผ่าน Work Center CRUD – ไม่พิมพ์เอง)
- กำหนด **config / parameter** เพิ่มเติมของ Work Center ผ่าน `config_json` (เช่น require_quantity, default_quantity, max_quantity, time_behavior ฯลฯ)
- ใน DAG Graph (Designer): เลือก Node แล้วผูก Work Center ให้แต่ละ Node (Node Mode ของ Node จะมาจาก Work Center ที่เลือก ไม่ได้เลือกใน Designer ตรง ๆ)

### 2.3 One Graph, Two Lines (Classic & Hatthasilpa)

แนวคิดสำคัญของระบบนี้คือ **“One Graph, Two Lines”**:

- ใช้ DAG Graph ชุดเดียว (flow เหมือนกัน)  
  - เช่น CUT → EDGE → STITCH → QC → PACK
- แต่เวลารันจริง:
  - ถ้ามาจากหน้า **MO** → job.line_type = `classic`
  - ถ้ามาจากหน้า **Hatthasilpa Job** → job.line_type = `hatthasilpa`

จากนั้น runtime จะใช้:

```text
(workCenter.node_mode, job.line_type)  --->  execution_mode จริง
```

ตัวอย่าง (เพียงเพื่ออธิบายแนวคิด ไม่ใช่ enum จริงทั้งหมด):

| workCenter.node_mode | job.line_type   | execution_mode (ตัวอย่าง)        |
|----------------------|-----------------|-----------------------------------|
| BATCH_QUANTITY       | hatthasilpa     | HAT_BATCH_QUANTITY + Time Engine |
| HAT_SINGLE           | hatthasilpa     | HAT_SINGLE                        |
| HAT_SINGLE           | classic         | CLASSIC_SINGLE                    |
| CLASSIC_SCAN         | classic         | CLASSIC_SCAN (PWA)                |
| QC_SINGLE            | hatthasilpa     | HAT_QC_SINGLE                     |
| QC_SINGLE            | classic         | CLASSIC_QC_SINGLE                 |

จุดสำคัญคือ:

- Designer ไม่ต้องสร้างกราฟสองชุด (Classic vs Hatthasilpa) ถ้าไม่จำเป็น  
- Graph อยู่กลาง, Work Center fix behavior, Runtime cast ตาม line_type  
- ถ้าวันหนึ่งต้องทำกราฟเฉพาะทางสำหรับ line ใด line หนึ่ง  
  ก็ให้ถือว่าเป็น “อีก routing หนึ่ง” แต่ **หลักการ One Graph, Two Lines ยังใช้ได้กับกราฟชุดอื่น**

---

## 3. Node Mode Catalog (ปัจจุบัน + ออกแบบไว้แล้ว)

> ⚠️ Important: Node Modes are *not* chosenใน DAG Designer.  
> Designer เลือก Work Center ให้ Node เท่านั้น และ Node จะได้ node_mode มาจาก Work Center ที่ผูกอยู่  
> Runtime ใช้ `node_mode` (จาก Work Center) + `line_type` (จาก MO / Hatthasilpa Job) เพื่อกำหนด execution ที่แท้จริง (UI, Time Engine, Token behavior ฯลฯ)

> หมายเหตุ: บาง Mode ยังอยู่ในสถานะ “Design / Planned” แต่ถือเป็นมาตรฐานที่ทุกคนต้องอ้างอิง

### 3.1 BATCH_QUANTITY (Cutting / Prep)

**Use Case:**
- ขั้นตอนที่ทำงานแบบ Batch เช่น CUTTING, SKIVING, PREP COMPONENTS
- ช่างตัดชิ้นส่วนสำหรับกระเป๋า 10 ใบในครั้งเดียว

**Behavior:**
- เมื่อเริ่มงาน:
  - System ถามจำนวน (qty) เช่น “ตัดกี่ชุด?”  
  - สร้าง `batch_session` + ผูกกับ Token / job_ticket
- Time Engine:
  - จับเวลาทั้ง batch (start → pause/resume → complete)
  - เวลา batch นี้จะถูกกระจายลงไปยัง token (ต่อใบ) ตาม rule
- Token:
  - การ “แตกตัวเป็นหลาย Token” ที่ Node ถัดไป (เช่น จาก batch ไปที่ `HAT_SINGLE`)  
  - เกิดขึ้นตอน Move Node:
    - Node A = `BATCH_QUANTITY`
    - Node B = `HAT_SINGLE`
    - เมื่อส่งงานไป Node B → ระบบสร้าง Token 10 ตัว (1 ต่อกระเป๋า 1 ใบ) ตาม qty

**Config Examples (ใน Work Center `config_json`):**
```json
{
  "require_quantity": true,
  "default_quantity": 10,
  "max_quantity": 50,
  "time_distribution": "even"  // future use
}
```

---

### 3.2 HAT_SINGLE (Hatthasilpa – Single Piece Work)

**Use Case:**
- งานเย็บหัตถศิลป์ (Hand Stitching) ที่ทำทีละใบ  
- ใช้ใน Work Queue (Hatthasilpa line)

**Behavior:**
- 1 Token = 1 ใบงาน  
- Time Engine:
  - จับเวลาต่อ Token: `start` / `pause` / `resume` / `complete`
  - ไม่มีการใส่ qty เพิ่มเติม เพราะคือ 1:1
- UI (Work Queue):
  - แสดงใบงานทีละใบ
  - กด start/pause/resume/complete ได้ตามปกติ
- Component Binding:
  - Node ที่เป็น `HAT_SINGLE` ตอนท้าย ๆ อาจเป็นจุด bind components กับ bag serial ได้ (ขึ้นกับ design)

---

### 3.3 CLASSIC_SCAN (Classic Line – PWA Scan)

**Use Case:**
- สายการผลิต Classic / OEM ที่ไม่ได้ใช้งาน work_queue  
- ทุกอย่างขับเคลื่อนผ่าน PWA + QR Scan

**Behavior:**
- Worker ใช้ PWA Scan:
  - Scan Token / Serial → งานขยับ Node ตาม DAG
- Time Engine:
  - อาจบันทึก time per scan (enter/exit)  
  - แต่ *ไม่ได้* ใช้ start/pause/resume แบบ Hatthasilpa
- Node Mode นี้:
  - เชื่อมกับ `pwa_scan_api.php` และ logic เฉพาะ Classic line

---

### 3.4 QC_SINGLE (Quality Control per Piece)

**Use Case:**
- QC ใบต่อใบ ทั้ง Hatthasilpa และ Classic ได้
- ใช้เมื่อต้องการผล PASS / FAIL + Reason

**Behavior:**
- 1 Token = 1 ใบงาน
- Node UI:
  - ต้องให้กรอกผล QC:
    - PASS / FAIL
    - อาจมี reason, defect_code
- Time Engine:
  - จับเวลา QC ต่อใบได้ (ถ้าต้องการ)
- Component Binding:
  - ใช้จุดนี้เพื่อตรวจสอบว่าชิ้นส่วนประกอบครบหรือไม่ (optional)

---


---

## 3.9 Canonical Event Integration (Task 21.2+ – Required by Core Principles 13–15)

**Status:** ✅ **IMPLEMENTED** (Task 21.2-21.8 completed)

Node Behavior ต้องสื่อสารกับระบบผ่าน "Canonical Events" เท่านั้น เพื่อให้ Time Engine, Token Engine, Component Binding และ Routing มีข้อมูลที่เป็นมาตรฐานกลางร่วมกัน

**Implementation:**
- `NodeBehaviorEngine::executeBehavior()` generates canonical events
- `TokenEventService::persistEvent()` persists events to `token_event` table
- `TimeEventReader::getTimelineForToken()` syncs timeline to `flow_token`
- All time operations use `TimeHelper` (canonical timezone: Asia/Bangkok)

### Canonical Events ที่เกี่ยวกับ Node Behavior

- **TOKEN_CREATE** – เกิดตอน spawn token/batch ครั้งแรก
- **TOKEN_SPLIT / TOKEN_MERGE** – สำหรับ transition แบบ Batch → Single หรือกรณีพิเศษ
- **NODE_START** – เริ่มทำงานของ Token หรือ Batch Session
- **NODE_PAUSE / NODE_RESUME** – ใช้เฉพาะ Hatthasilpa line (work_queue)
- **NODE_COMPLETE** – ทำ Node เสร็จสมบูรณ์
- **NODE_CANCEL** – ยกเลิก Token หรือ Flow (เช่น QC Reject/Discard)
- **OVERRIDE_ROUTE** – การเปลี่ยนเส้นทางแบบ Supervisor
- **COMP_BIND / COMP_UNBIND** – การผูก/ถอด Component Serial ตาม Node Mode
- **INVENTORY_MOVE** – (future use) เคลื่อนไหน inventory ที่ผูกกับ node

### กติกา

1. Node Behavior **ห้ามแก้ DB ตรง ๆ**
   - ต้องสร้าง canonical events ให้ Token Engine/Execution Layer จัดการต่อ
   - **Task 21.2+:** `NodeBehaviorEngine::executeBehavior()` generates canonical events automatically
   - **Task 21.3+:** `TokenEventService::persistEvent()` persists events to `token_event` table

2. Node Behavior **ต้องคืนผลลัพธ์เป็น canonical effects**
   เช่น:
   ```json
   {
     "effects": [
       { "event": "NODE_START" },
       { "event": "COMP_BIND", "component": "strap", "serial": "ST-3321-A" }
     ]
   }
   ```

3. UI ห้ามเป็น source-of-truth
   - UI ทำแค่ส่ง intent → Behavior Engine → แปลงเป็น canonical events

4. สถานะเวลา/การจับเวลา **ต้อง sync กับ canonical events**
   - **Task 21.5:** `TimeEventReader::getTimelineForToken()` syncs timeline to `flow_token` (start_at, completed_at, actual_duration_ms)
   - **Task 20.2.2:** All time operations use `TimeHelper` (canonical timezone: Asia/Bangkok)
   - start_at = จาก NODE_START
   - completed_at = จาก NODE_COMPLETE
   - duration = NODE_START → NODE_COMPLETE

### เป้าหมาย
- ทำให้ Node Behavior, Time Engine, Execution Model, และ Component Binding พูด “ภาษาเดียวกัน”
- ป้องกันไม่ให้เกิด behavior พิเศษจากการแก้ UI/Script โดยไม่ผ่าน canonical layer

---

Work Center **เก็บ `node_mode` โดยตรง** (Behavior Code) + อาจมี `config_json` สำหรับ config เพิ่มเติม.  
Node ใน DAG จะ “รับ” node_mode จาก Work Center ที่ผูกอยู่  
ตอน runtime ระบบใช้คู่ `node_mode` + `line_type` ของงาน เพื่อแปลงเป็น execution mode จริง (UI, Time Engine, Scan/Queue ฯลฯ) โดยมี logic ลักษณะนี้:

```text
execution_mode = resolveExecutionMode(
  workCenter.node_mode,
  job.line_type   // classic | hatthasilpa
)
```

เช่น QUANTITY_NODE + hatthasilpa → BATCH_QUANTITY + Time Engine  
SINGLE_NODE + hatthasilpa → HAT_SINGLE  
SINGLE_NODE + classic → CLASSIC_SINGLE  
SCAN_NODE + classic → CLASSIC_SCAN

### 4.1 Execution Context: Classic vs Hatthasilpa

- Classic line:
  - สร้างงานจากหน้า **MO (Manufacturing Order)**
  - ใช้ PWA Scan เป็นหลัก
- Hatthasilpa line:
  - สร้างงานจากหน้า **Hatthasilpa Job**
  - ใช้ work_queue + Time Engine เป็นหลัก

ทั้งสองแบบจะถูก normalize ผ่าน **Job Ticket** กลางก่อนส่งเข้า DAG / Token Engine

Runtime execution mapping จะดูจาก:  
- `node_mode` ของ Work Center ที่ Node นั้นผูกอยู่  
- `line_type` ของ job (classic / hatthasilpa)  
- routing/template (ในกรณีที่ต้องใช้ rule เพิ่มเติม)

### 4.2 Anti-patterns (สิ่งที่ห้ามทำ)

เพื่อกันไม่ให้ Logic กลายเป็น “สปาเก็ตตี้” ต้อง **ห้ามทำสิ่งต่อไปนี้**:

1. **ให้ Designer เลือก node_mode ที่ระดับ Node โดยตรง**  
   - Node ห้ามมี field `node_mode` ของตัวเอง  
   - ถ้าพบว่า Node มี node_mode แยกจาก Work Center ให้ถือว่าเป็น bug ของสเปก

2. **เปลี่ยนพฤติกรรมด้วยการเช็คชื่อ Work Center / ชื่อกราฟ**  
   - ห้ามเขียนโค้ดลักษณะ:
     - `if ($workCenterName === 'โต๊ะเย็บหัตถศิลป์') { ... }`  
     - `if ($graphName === 'Hatthasilpa Flow') { ... }`
   - ให้เปลี่ยนไปใช้:
     - `if ($nodeMode === NodeMode::HAT_SINGLE) { ... }`

3. **ผูก Line Type เข้าไปใน Graph**  
   - Graph ไม่ควรมี field `line_type`  
   - ถ้าอยากรู้ว่าเป็น Classic หรือ Hatthasilpa ให้ถามจาก job / MO / Hatthasilpa Job เท่านั้น

4. **ให้ Work Center ไม่มี node_mode**  
   - ตาราง `work_centers` ต้องมี `node_mode` เสมอ  
   - ถ้า migration ใหม่ใด ๆ ลบ field นี้ทิ้ง ให้ถือว่า “พังสถาปัตย์” ทันที

5. **ซ่อน Logic Node Mode ไว้ใน config_json แบบ dynamic เกินไป**  
   - `config_json` ใช้เก็บ parameter เพิ่มเติม แต่ “ชนิดพฤติกรรมหลัก” ต้องอยู่ใน enum `node_mode`  
   - ถ้าเริ่มมี pattern ว่าเปลี่ยน behavior ด้วยการเปลี่ยน config_json โดยไม่ผ่าน enum ให้หยุดและออกแบบ Mode ใหม่แทน

---

## 5. Node + Product + BOM + Components – ทำงานร่วมกันอย่างไร

### 5.1 Product + BOM

- Product:
  - มี BOM ระบุว่า:
    - Body Leather กี่ชิ้น
    - Lining กี่ชิ้น
    - Strap กี่เส้น
    - Hardware ใดบ้าง
- BOM บอกว่า: “กระเป๋า 1 ใบ ประกอบด้วยอะไรบ้าง”

### 5.2 DAG Graph (Node Flow)

- DAG บอกลำดับขั้นตอน:
  - CUT → EDGE PAINT → STITCH → ASSEMBLY → QC → PACKING
- DAG ไม่ระบุ BOM แต่เป็น “เส้นทาง work”

### 5.3 Components & Component Serial Binding

- Components Serial ไม่จำเป็นต้อง “เกิดตั้งแต่ตัด”
- แนวคิด:
  - Component บางตัวอาจมี Serial ของตัวเอง (เช่น Shoulder Strap, Lock, Chain)
  - การผูก Component เข้ากับ Bag Serial ควรเกิด:
    - ใน Node ที่ assembly ใกล้จบ หรือบาง Node ที่กำหนดเฉพาะ
- component binding API (จาก Task 13):
  - แยกเป็น API ที่ผูก:
    - `job_ticket` (หรือ bag serial)
    - component_type / component_code
    - component_serial_list
  - ผูกไว้ใน component binding table แยกจาก token หลัก

---

## 6. Execution Semantics ตาม Node Mode

### 6.1 BATCH_QUANTITY → HAT_SINGLE (ตัวอย่างสำคัญ)

กรณี: ทำ Hatthasilpa 10 ใบ

1. **ที่ Node CUT (BATCH_QUANTITY):**
   - Worker เลือก job_ticket ที่มี 10 ใบ
   - Worker กด Start → ระบบถามจำนวน: ใส่ 10
   - ระบบสร้าง `batch_session` สำหรับ Node นี้ (qty = 10)
   - เมื่อจบ → mark ว่า “ตัดครบ 10 ใบ”

2. **Move ไป Node STITCH (HAT_SINGLE):**
   - ตอนระบบสร้างงานให้ช่างเย็บ:
     - ระบบต้อง “แตก token” เป็น 10 Token
     - แต่ละ Token แทนกระเป๋า 1 ใบ
   - Time Engine:
     - จับเวลาต่อใบผ่าน work_queue (HAT_SINGLE)

> ตรงนี้คือจุดที่ “แตก Batch → Single Tokens” ตาม Node Mode transition  
> logic นี้จะไปผูกกับ Time Engine & Token Engine ต่อภายหลัง

---

### 6.2 CLASSIC_SCAN Transitions

- Classic line ใช้ PWA:
  - ทุก Node ที่มี `node_mode = CLASSIC_SCAN`:
    - Worker scan QR / Serial
    - ระบบย้าย Node ของ Token นั้น ๆ ไป Node ถัดไป
  - Time:
    - สามารถ log enter/exit timestamp
    - ไม่ใช้ start/pause/resume

---

## 7. Time Engine Integration (ภาพรวม)

> รายละเอียดเชิงลึกของ Time Engine อยู่ใน `/docs/time_engine/`  
> ตรงนี้เป็นเพียง high-level ว่ามันสัมพันธ์กับ Node Mode อย่างไร

### 7.1 Hatthasilpa Line (work_queue)

- Node Modes ถูกกำหนดที่ระดับ Work Center (ผ่าน `node_mode` enum)
- Designer เป็นกลางในแง่ที่ “ไม่เลือก node_mode ในกราฟ” แต่เลือก Work Center ให้ Node
- ตอนสร้าง Hatthasilpa Job ระบบจะรู้ว่า line_type = hatthasilpa และใช้คู่ `work_center.node_mode` + `line_type` เพื่อเลือก execution mode ของ Time Engine (เช่น HAT_SINGLE, BATCH_QUANTITY, QC_SINGLE)

### 7.2 Classic Line (PWA Scan)

- ใช้ Node Modes:
  - `CLASSIC_SCAN`
  - (optional) QC Modes เฉพาะ Classic
- Time Engine:
  - log enter/exit ผ่าน Scan time
  - ใช้คำนวณ lead time / throughput

---

## 8. DAG Designer – จะเชื่อม Node Mode อย่างไร

### 8.1 ปัจจุบัน

- DAG Designer ให้เลือก Node + ผูก Work Center
- Work Center ตอนนี้มีฟิลด์ `node_mode` เป็นหลัก และอาจมี `config_json` สำหรับ config เพิ่มเติม (ถ้าทำ migration แล้ว)

### 8.2 เป้าหมาย

1. เพิ่ม `config_json` ใน Work Center เพื่อเก็บ **config เพิ่มเติม** ของ node_mode นั้น ๆ (เช่น require_quantity, default_batch_quantity, max_batch_quantity ฯลฯ)
2. DAG Designer:
   - เมื่อเลือก Work Center ให้ Node:
     - อ่าน `node_mode` จาก Work Center
     - แสดง metadata / icon / hint ว่า Node นี้มี behavior แบบใด (เช่น Batch, Single, Scan, QC ฯลฯ)
3. Runtime:
   - work_queue / PWA ใช้คู่ `node_mode` (จาก Work Center) + `line_type` (จาก job/MO) เพื่อตัดสินใจว่าจะให้ UI / Time Engine / Scan Flow ทำงานอย่างไร

---

## 9. Backward Compatibility & Migration

- Work Center ที่มีอยู่เดิม:
  - ต้องมี default `node_mode` กำหนดให้ (เช่น HAT_SINGLE หรือ CLASSIC_SCAN) เมื่อทำ migration
- Node ใน DAG เดิม:
  - การผูก node → work_center จะเป็นตัวกำหนด node_mode โดยอัตโนมัติ
- Time Engine / Token Engine:
  - ต้องพร้อมรองรับ transition จาก:
    - Batch → Single
    - Single → QC
    - Scan → Scan

---

## 10. Implementation Checklist (สำหรับ Task ต่อ ๆ ไป)

> ใช้ส่วนนี้เป็น reference เวลาสั่ง AI Agent / Developer ให้ทำงาน

1. **Define Node Mode Enum (PHP)**
   - Location: `source/BGERP/DAG/NodeMode.php` (หรือไฟล์ที่กำหนด)
   - Enum values ที่ต้องมีอย่างน้อย:
     - `BATCH_QUANTITY`
     - `HAT_SINGLE`
     - `CLASSIC_SCAN`
     - `QC_SINGLE`

2. Runtime must determine execution mode (batch / single / scan / QC) from the combination of Work Center `node_mode` and MO/Job context (`line_type`). DAG Designer remains neutral in the sense that it does not choose node_mode directly – it only binds Nodes to Work Centers.

3. **Update Work Center CRUD**
   - ให้เลือก `node_mode` จาก list (enum ที่ Framework กำหนด ไม่ให้พิมพ์เอง)
   - อนุญาตให้กรอก/แก้ไข `config_json` เพื่อกำหนด config เพิ่มเติมของ Work Center เช่น:
     - `require_quantity`, `default_batch_quantity`, `max_batch_quantity`
     - flag logic เพิ่มเติมที่ node_mode นั้นรองรับ

4. **Update DAG Designer**
   - เวลาเลือก Work Center ให้ Node:
     - อ่าน `node_mode` ของ Work Center แล้วแสดง icon / summary ให้ Designer เข้าใจว่า Node นี้เป็น Batch / Single / Scan / QC
   - Optional: เพิ่ม validation/คำเตือนถ้า routing ใช้ Work Center ที่ node_mode ไม่เหมาะสมกับ line/concept ของกราฟ (ถ้ามี rule เพิ่มเติมในอนาคต)

5. **Wire Node Mode → Runtime**
   - work_queue:
     - ถ้า `HAT_SINGLE` → ใช้ Time Engine single token
     - ถ้า `BATCH_QUANTITY` → ใช้ batch_session + qty
   - PWA:
     - ถ้า `CLASSIC_SCAN` → ใช้ scan-based flow

6. **Component Binding Integration**
   - กำหนด Node หรือ Node Mode ที่อนุญาตให้ bind component serial
   - อ้างอิงจาก API ที่ออกแบบใน Task 13.x

---

## 11. Guidelines สำหรับ AI Agent / Developer

ส่วนนี้เขียนไว้สำหรับทุกคน (รวมถึง AI Agent) ที่จะมาแก้สเปก / เขียนโค้ดจากไฟล์นี้ในอนาคต

1. **อย่าเปลี่ยน Axioms เงียบ ๆ**  
   - ถ้าแนวคิดใหม่ไปชนกับข้อใดข้อหนึ่งใน `1.2 Design Axioms`  
     ให้ถือว่าเป็น “การเปลี่ยนสถาปัตย์” ไม่ใช่ patch เล็ก ๆ  
     ต้อง:
     - สร้าง section ใหม่ เช่น `## X. New Architecture Proposal`  
     - อธิบายเหตุผล, trade-off, แผน migration  
     - ไม่เขียนทับของเดิมโดยไม่บอก

2. **ใช้ `node_mode` เป็นแหล่งความจริงเรื่องพฤติกรรม Node**  
   - เวลาเขียนโค้ดให้ถามว่า Node ทำงานแบบไหน → ให้ดู `node_mode`  
   - หลีกเลี่ยงการใช้ชื่อ Work Center / ชื่อ Node / ชื่อ Graph เป็นตัวกำหนดพฤติกรรม

3. **Classic vs Hatthasilpa = เรื่องของ Job Context ไม่ใช่ Graph**  
   - ห้ามผูก line_type ลงในโครงสร้าง Graph  
   - ใช้ `job.line_type` (หรือ equivalent) ใน runtime เท่านั้น

4. **ถ้าต้องการเพิ่ม Node Mode ใหม่**  
   - แก้ enum NodeMode ใน PHP  
   - อัปเดตตาราง Node Mode Catalog ในข้อ 3  
   - อัปเดต Work Center CRUD ให้เลือกค่าใหม่ได้  
   - เขียนผลกระทบต่อ Time Engine / UI ไว้ในสเปก

5. **แยก “สิ่งที่ใช้อยู่จริง” ออกจาก “แนวคิดในอนาคต” ให้ชัด**  
   - ถ้ามีไอเดียใหม่ (เช่น อยากให้ระบบเดา node_mode จาก capabilities)  
     ให้เขียนไว้ใน section ใหม่ที่ติดป้ายชัดเจนเช่น:  
     `> Status: FUTURE IDEA (ยังไม่ implement)`  
     ห้ามเอามาปนกับ spec หลักในข้อ 1–10 โดยไม่เขียนสถานะให้ชัดเจน

การทำตาม Guideline เหล่านี้จะช่วยให้สถาปัตย์ของ DAG / Work Center / Time Engine  
เติบโตได้โดยไม่กลายเป็น “สปาเก็ตตี้โค้ด” และลดความเสี่ยงที่จะไปหักหลังระบบ Traceability ในอนาคต