# Task 24.6.4 — Classic Line Hardening, Ticket Creation Fix, DAG Binding, Legacy Ticket Migration

## 🎯 GOAL
ทำให้ Job Ticket ที่สร้างจากหน้า UI (Classic Line) **ถูกต้อง 100% ทุกใบ**  
ไม่มี Hybrid, ไม่มี Linear, ไม่มี Manual Production Mode ให้เลือก  
และต้อง **ผูก DAG Instance (flow_graph_instance)** ตั้งแต่ตอนสร้าง Ticket ทันที

---

## ❗ งานหลักของ Task 24.6.4 (ต้องทำครบทั้ง 3 ข้อ)

### (1) Auto-determine `line_type` & `routing_mode` ตอนสร้าง Ticket  
**ห้าม** ให้ผู้ใช้เลือกโหมดผลิตเองอีก  
เพราะ:
- Job Ticket จากหน้านี้ = Classic Line เท่านั้น
- Hatthasilpa Ticket สร้างอัตโนมัติจากระบบอีกหน้า

📌 กติกาใหม่:
- ทุก Ticket ที่สร้างจากหน้านี้ตั้งค่าดังนี้อัตโนมัติ:
  - `line_type = 'classic'`
  - `routing_mode = 'dag'`
- ลบ select “โหมดผลิต: รายชิ้น / Batch” ออกจาก Modal

📌 แก้ไขไฟล์:
- `views/job_ticket.php`
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `source/job_ticket.php` (create action)

---

### (2) Classic Ticket ต้องมี **DAG Token Binding** ทันที ตอนสร้าง

ตอนนี้ระบบยัง **ไม่ bind graph_instance** ตอนสร้าง Job Ticket  
ทำให้:
- line_type ถูกต้องก็จริง  
- แต่ยัง “Start” ไม่ได้ เพราะไม่มี token group  
- ผู้ใช้จึงโดน error: *“this action is only available for Classic line tickets”*

📌 แผนงาน:
ตอน create ticket:
1. Fetch active routing graph จาก product → `routing_graph_id`
2. ใช้ service:
   - `GraphInstanceService::createInstanceForTicket($ticketId, $routingGraphId)`
3. Generate token group จำนวน “ตาม planned_qty”  
4. Link tokens → job_ticket_id

📌 แก้ไขไฟล์:
- `source/job_ticket.php`
- อาจต้องเรียกใช้ service: `FlowGraphInstanceService`, `TokenLifecycleService`

---

### (3) Migrate tickets เก่าให้เป็น Classic ที่ถูกต้อง  
เพื่อให้ “Start/Resume/Complete” ใช้งานได้ ไม่ error อีก

📌 Migration rule:
สำหรับ tickets ที่ยังเหลือใน table:
- ถ้า `created_from = 'mo'` → ถือว่าเป็น Classic Line
- Set:
  - `line_type = 'classic'`
  - `routing_mode = 'dag'`
- ตรวจสอบว่ามี graph_instance ผูกหรือยัง  
  - ถ้าไม่มี → generate ใหม่

📌 สิ่งต้องทำ:
- เพิ่ม CLI tool: `tools/job_ticket_migrate_classic.php`
- หรือเพิ่ม admin endpoint (dev only)

---

## 🧩 รายละเอียดงานที่จะเขียนให้ AI Agent ทำ

### 1) UI Cleanup
- ลบ select โหมดผลิต
- ซ่อน/ลบทุก logic ที่อ่านค่าจาก field นี้
- ปรับ Create Modal → แสดง routing info จาก assist API เท่านั้น

### 2) Backend Create Action Fix
- ลบอ่านค่าจาก client สำหรับ line type / routing mode
- บังคับค่าดังนี้:
```php
$data['line_type'] = 'classic';
$data['routing_mode'] = 'dag';
```
- หลัง insert Ticket → generate DAG instance + tokens

### 3) Ensure Start Action Works
- Start ต้องเจอ token group เสมอ
- ถ้าไม่มี token ผูกอยู่ → ห้ามปล่อยผ่าน ต้องถือว่า bug

### 4) Migrate Existing Tickets
ทำ script:
- scan job_ticket where routing_mode != 'dag'
- update fields
- generate instance + tokens ถ้ายังไม่มี

### 5) Hybrid Hygiene
- ตัด Hybrid ออกจาก dropdown UI
- comment ใน code ว่า “HYBRID RESERVED — NOT IN USE IN V1”
- ห้าม hybrid ปรากฎใน payload ของ Ticket ใด ๆ

---

## ✔ Acceptance Criteria

- ผู้ใช้ “สร้าง Job Ticket” จากหน้านี้ → ได้เฉพาะ Classic แบบ DAG  
- Modal ไม่มีตัวเลือกโหมดผลิต  
- Create Ticket แล้วทำได้ทันที: Start / Pause / Resume / Complete  
- Ticket เก่าหลัง migration กด Start ได้ ไม่ error  
- ไม่มี Hybrid ปรากฏใน UI/API  
- ทุก Ticket มี graph_instance_id + tokens ตั้งแต่เกิด  

---

## 🗂 Files to Modify (expected)

- `views/job_ticket.php`
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `source/job_ticket.php`
- (new) `tools/job_ticket_migrate_classic.php`
- documentation: `task24_6_4_results.md`

---

## 📌 หมายเหตุสำคัญ
ตอนเขียน prompt ให้ Agent โปรดเน้นว่า:

**"Task 24.6.4 ต้องแก้ 3 เรื่องใหญ่พร้อมกัน  
(1) auto line_type & routing_mode  
(2) DAG instance binding  
(3) legacy ticket migration  
ต้องไม่แยกเป็นหลาย task"**

---

## Status

- ✅ **COMPLETED** (2025-11-29)
- See: [task24_6_4_results.md](results/task24_6_4_results.md)
