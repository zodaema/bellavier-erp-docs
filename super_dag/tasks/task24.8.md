# Task 24.8 — Job Ticket Printable Work Card (A4)

## 0. Context

- Phase 23–24: MO + Job Ticket + ETA stack for Classic line เสร็จในระดับ backend แล้ว
- Classic line = สร้างงานจาก MO → Job Ticket เป็นตัวแทน “ชุดงาน” ที่ส่งเข้าไลน์จักร
- Hatthasilpa line = สร้างงานจาก Hatthasilpa Jobs → Job Ticket เป็น anchor เดียวกัน (ใช้ DAG + tokens)

ตอนนี้ **ช่างยังไม่มีกระดาษใบงาน (Work Card)** ที่ align กับ Job Ticket จริงในระบบ
Task นี้คือการสร้าง **หน้า A4 สำหรับพิมพ์ใบงาน** จาก Job Ticket + ปุ่ม Print ในหน้า Job Ticket

เป้าหมาย: ให้กระดาษใบงานหนึ่งใบ สามารถหมุนเวียนในงานจริงได้ตั้งแต่ต้นจนจบสายการผลิต โดย
- อ่านง่าย, เขียนด้วยปากกาได้, แสกนกลับมาดูข้อมูลในระบบได้ (ผ่าน QR / code)
- ไม่ต้องมีการ sync ข้อมูลกลับเข้าระบบอัตโนมัติใน Phase นี้ (อ่านอย่างเดียว / manual)

---

## 1. Goal

1. สร้าง **หน้า A4 Work Card** สำหรับ Job Ticket (เน้น Classic line เป็นหลัก แต่ Hatthasilpa ต้องไม่พัง)
2. เพิ่มปุ่ม **Print Work Card** ในหน้า Job Ticket (offcanvas) ที่เปิดหน้า A4 ในแท็บใหม่
3. Layout ต้อง **สะอาด / print-friendly** (ใช้ CSS print media, ไม่มีเมนู/ปุ่มเกะกะ)


---

## 2. Scope

### In Scope

1. สร้าง view ใหม่สำหรับ Job Ticket Print (A4 layout)
2. เชื่อมข้อมูลจาก Job Ticket + Product + MO + Routing Graph (เฉพาะ Classic)
3. ปุ่ม Print ใน offcanvas ของ Job Ticket (Classic และ Hatthasilpa – แต่ layoutต่างกัน)
4. Handling ของ Hatthasilpa ticket:
   - ใช้ layout simplified (ไม่ต้องแตก node จาก graph)
   - แต่ยังแสดงข้อมูลสำคัญ: product, qty, owner, note, ฯลฯ

### Out of Scope (Phase นี้)

1. OCR / การอ่านใบงานกลับเข้าระบบ
2. การบังคับช่างต้องเติมเวลา/ลงนามทุกช่อง (ยังเป็นวินัยการใช้ ไม่ใช่ logic ระบบ)
3. การอัปเดต canonical timeline จากใบงาน (จะทำใน Phase Node Behavior / Self-Healing ขั้นสูง)


---

## 3. UX / Layout Design (A4)

### 3.1 Entry point

- URL: `index.php?p=job_ticket_print&id={id_job_ticket}`
- Method: GET
- Auth: ใช้ session / permission ปัจจุบัน (เหมือนหน้าอื่น ๆ ใน BGERP)

### 3.2 Layout Overview

ใช้ HTML + CSS พื้นฐาน (ไม่ต้องใช้ JS บนหน้านี้ ยกเว้นกรณีเล็กน้อยสำหรับ auto-print หรือปิด margin) โดยเน้นให้:
- ใช้ `@media print` สำหรับซ่อน element ที่ไม่ต้องการเวลา print
- โครงสร้างหลัก: **Header**, **Job Summary**, **Operation Table**, **Checklist + Notes**

#### 3.2.1 Header Zone (ด้านบนสุด)

ข้อมูลที่ต้องแสดง:

- โลโก้เล็ก ๆ (ถ้ามี path ในระบบ; ถ้าไม่มีก็ใช้ชื่อบริษัทตัวอักษร)
- `Job Ticket Code` (code หลักของใบงาน)
- `Production Line / Type`  
  - แสดงเป็น: `Classic Line` หรือ `Hatthasilpa Line`
- วันที่สร้าง (จาก job_ticket.created_at หรือใกล้เคียง)
- `MO Code` (ถ้ามี binding กับ MO)
- QR Code / Code text:
  - อย่างน้อยต้องมี text: `JT-{id_job_ticket}` ชัดเจน
  - (ถ้าจะวาง QR ภายหลัง ให้กันพื้นที่ไว้ / สามารถใช้ placeholder div ได้)

#### 3.2.2 Product / Order Summary Block

แสดงในกล่องแยกต่างหาก (สองคอลัมน์หรือบล็อกเรียง)

- Product code (SKU)
- Product name (TH/EN ตามที่มี)
- สี / วัสดุ (color name, material type ถ้ามีใน product)
- จำนวนที่ต้องผลิต (Target Qty) + หน่วย (ชิ้น)
- Job Owner (สำหรับ Classic ถ้า job_ticket มี owner):
  - ถ้าไม่มี ให้เว้นช่องว่างไว้ให้เขียนปากกา

#### 3.2.3 Operation Table (Core ของใบงาน)

**Classic Line:**
- ดึง routing จาก graph instance ที่ผูกกับ job_ticket (ผ่าน instance_id / routing binding)
- สร้างตาราง operation ตามลำดับขั้นตอนหลัก (node-level list)

คอลัมน์ที่ต้องมี:

| Step | Operation / Work Center | ผู้รับผิดชอบ | เวลาเริ่ม | เวลาเสร็จ | จำนวนที่ทำ | ลายเซ็น |
|------|--------------------------|--------------|-----------|-----------|-------------|---------|

รายละเอียด:
- `Step`: running number 1..N ตามลำดับ graph ที่เหมาะสม (ใช้ลำดับ logical – ไม่ต้อง render DAG เป็น complex graph แค่ลิสต์เรียงตาม routing)
- `Operation / Work Center`: 
  - ชื่อ node หรือชื่อ work_center ที่ผูกกับ node นั้น
- `ผู้รับผิดชอบ`: ช่องว่างให้ช่างเขียนชื่อ / รหัส
- `เวลาเริ่ม / เวลาเสร็จ`: ช่องให้เขียนเวลาโดยประมาณ
- `จำนวนที่ทำ`: ช่องให้เขียนจำนวนชิ้นที่ทำใน step นั้น (ใช้ตอน batch / partial)
- `ลายเซ็น`: ช่องเซ็นย่อ ๆ

**Hatthasilpa Line:**
- ถ้ายังไม่มีการ map node → operation ที่เหมาะสม ให้ใช้ **fixed template 5–7 แถว** เช่น:

| Step | Operation                 | ผู้รับผิดชอบ | เวลาเริ่ม | เวลาเสร็จ | หมายเหตุ |
|------|---------------------------|--------------|-----------|-----------|-----------|
| 1    | เตรียมชิ้นงาน / วัตถุดิบ |              |           |           |           |
| 2    | ประกอบโครงสร้างหลัก      |              |           |           |           |
| 3    | เย็บ / ขึ้นรูปหลัก         |              |           |           |           |
| 4    | เก็บงาน / ตรวจสอบ         |              |           |           |           |
| 5    | QC สุดท้าย / ทำความสะอาด |              |           |           |           |

(ให้ Agent render table นี้เมื่อ `production_type = hatthasilpa` และไม่มี routing graph ที่เหมาะสม)

#### 3.2.4 Checklist & Notes Section

ด้านล่างของหน้า:

1. **Checklist** (checkbox ให้ช่างติ๊ก)
   - [ ] QC ผ่าน
   - [ ] บรรจุหีบห่อเรียบร้อย
   - [ ] แนบอุปกรณ์ครบ (ถ้ามี)
   - [ ] ทำความสะอาดผิวงานแล้ว

2. **Notes / Remark**
   - กล่องสี่เหลี่ยมใหญ่ ๆ ให้เขียนหมายเหตุ เช่น งานแก้ไข, ข้อผิดพลาด, defect

---

## 4. Backend / Data Flow

### 4.1 Routing

- Classic line:
  - ใช้ instance_id / graph binding เดิมที่ Job Ticket ถืออยู่
  - ดึง node list ผ่าน service ที่มีอยู่แล้ว (เช่น RoutingGraphHelper / GraphInstanceService)
  - ถ้าดึงไม่ได้ ให้ fallback เป็น Hatthasilpa-like simplified table แต่ต้อง log warning ใน PHP log

- Hatthasilpa line:
  - ถ้ายังไม่มี node mapping ที่เหมาะ ให้ใช้ fixed table ตามด้านบน (manual steps)

### 4.2 Data source ที่ต้องใช้

ใน `job_ticket_print.php` ให้โหลดข้อมูลจาก:

1. `job_ticket` (ผ่าน existing model / helper function เช่นใน `job_ticket.php`)  
   - id_job_ticket, ticket_code, production_type, created_at, id_mo, target_qty, job_owner_id ฯลฯ
2. `mo` (ถ้ามี id_mo):
   - mo_code, due_date ฯลฯ
3. `product` (ผ่าน id_product จาก job_ticket หรือ mo):
   - sku, name_en/name_th, color, material, etc.
4. Routing / Graph instance (Classic):
   - node list (id, name, work_center, sequence_index)


---

## 5. Integration Points

### 5.1 New View: job_ticket_print.php

- Location: `views/job_ticket_print.php`
- Pattern:
  - ตรวจ `$_GET['id']` → cast int → load job_ticket
  - ถ้าไม่พบ → แสดง error message เรียบง่าย หรือ 404-like page (ในสไตล์ระบบ)
  - Render layout A4 ตาม spec ด้านบน
- ใช้ CSS inline หรือ include CSS เฉพาะ (ไม่ต้องดึง Bootstrap เต็มเวอร์ชันก็ได้ ถ้าทำให้ print หนาไป)
- ใส่ `@media print { ... }` เพื่อซ่อน element ที่ไม่ต้องพิมพ์ (เช่นปุ่ม "Print" ถ้ามี)

### 5.2 ปุ่ม Print ใน Job Ticket Offcanvas

**ไฟล์:** `views/job_ticket.php` + `assets/javascripts/hatthasilpa/job_ticket.js`

1. เพิ่มปุ่มใน header หรือ action area ของ offcanvas (สำหรับทุก production_type):

   ```html
   <button type="button" class="btn btn-outline-secondary btn-sm" id="btn-print-job-ticket">
       <i class="fa fa-print"></i> Print Work Card
   </button>
   ```

2. JS: ใน `job_ticket.js` (หรือไฟล์ JS ที่รับผิดชอบ offcanvas นี้):

   - เมื่อ load detail สำเร็จ ให้เก็บ `ticket_id` ไว้ในตัวแปร (ถ้ายังไม่ได้ทำ)
   - ผูก event:

   ```js
   $('#btn-print-job-ticket').on('click', function() {
       const ticketId = currentTicketId; // หรือค่าที่ใช้ในระบบ
       if (!ticketId) return;
       const url = 'index.php?p=job_ticket_print&id=' + encodeURIComponent(ticketId);
       window.open(url, '_blank');
   });
   ```

3. Behaviour:
   - เปิดใน tab/window ใหม่ (ให้ browser standard print dialog ทำงานตามปกติเมื่อ user กด Ctrl+P)


---

## 6. Files to Touch

1. **New**
   - `views/job_ticket_print.php` — A4 layout

2. **Existing**
   - `views/job_ticket.php` — เพิ่มปุ่ม Print ใน offcanvas
   - `assets/javascripts/hatthasilpa/job_ticket.js` — เพิ่ม handler สำหรับปุ่ม Print
   - (optional) helper/service ที่ใช้ดึง routing graph ถ้ายังไม่มี function ที่ใช้ซ้ำได้


---

## 7. Acceptance Criteria

- ✅ เปิดหน้า `index.php?p=job_ticket_print&id=XXX` แล้วเห็นหน้า A4 ที่จัด layout เรียบร้อย ไม่หลุดขอบกระดาษ
- ✅ ข้อมูล Job Ticket / Product / MO ถูกต้อง (ตรวจ cross-check จาก DB)
- ✅ Classic line: ตาราง Operation แสดง step ตาม node ใน routing graph
- ✅ Hatthasilpa line: ถ้าไม่มี routing → แสดง simplified manual table ตาม spec
- ✅ จากหน้า Job Ticket offcanvas กดปุ่ม Print แล้วเปิดแท็บใหม่ไปยังหน้า print ถูกต้อง ไม่มี JS error
- ✅ หน้าพิมพ์ไม่มีปุ่ม UI หรือ element ที่ไม่จำเป็นปรากฎในผล print จริง (เช็กผ่าน Print Preview)


---

## 8. Notes for Future Phases

- ใน Phase Node Behavior / Time Tracking ขั้นสูง สามารถใช้โครงสร้างตารางนี้เป็นฐานสำหรับ
  - ให้ช่างบันทึกเวลาเริ่ม–จบ per step → manual input / scan กลับเข้าระบบ
  - เปรียบเทียบกับ canonical timeline (token events) เพื่อตรวจ deviation
- ถ้าจะเพิ่ม QR Code จริงในอนาคต ให้สร้าง helper function เช่น `renderJobTicketQr($ticketId)` แล้วใช้ library QR code ใน layer ที่เหมาะสม


## Status

- ✅ **COMPLETED** (2025-11-29)
- See: [task24_8_results.md](results/task24_8_results.md)
