# Task 10.2 – People Monitor Workload, Current Work & Realtime Timer

**Area:** manager_assignment → People tab (“People Monitor”)  
**Goal:** ทำให้หน้าจอนี้เป็น “จอผู้จัดการ” ที่ดูแล้วรู้ทันทีว่าแต่ละคน
- ว่างแค่ไหน (Workload จริง ๆ)
- กำลังทำงานอะไรอยู่ (Current Work)
- ใช้เวลาบนงานที่กำลังทำอยู่เท่าไร (Realtime work timer)

**Very important UI rule**

- ห้ามแก้ layout / โครงตาราง / visual design หลัก  
- อนุญาตให้:
  - เพิ่ม tooltip
  - เพิ่มข้อความเล็ก (sub-text) ใน cell เดิม
  - เพิ่ม badge/label เพิ่มเติมในคอลัมน์เดิม  
- ห้ามสร้างหน้าใหม่ / กล่องใหม่ / restructure UI

---

## 1. วิเคราะห์สถานะปัจจุบัน (Context)

From existing behaviour:

- Column **Status**:
  - แสดง badge เช่น `Available`, `Assigned` ฯลฯ
- Column **Workload**:
  - ปัจจุบันดูเหมือนนับ “จำนวน token ที่มี session active/paused”  
  - admin มี 2 งาน paused → Workload = 2 (ค่อนข้างตรง)
  - แต่ operator1 แสดง `27 tokens` ทั้ง ๆ ที่ตอนนี้ assign แค่ 1 token และยังไม่เริ่ม → ตัวเลขนี้ “ไม่ใช่ภาพ workload ปัจจุบัน” (น่าจะนับทุกงานที่เคยเกี่ยวข้อง)
- Column **Current Work**:
  - แสดงรหัส job ล่าสุดที่เคยทำ เช่น `ATELIER-2025...`
  - แต่กรณี paused ก็ยังแสดงเหมือนกำลังทำอยู่ ทำให้ manager เข้าใจผิด

---

## 2. นิยามใหม่ที่ต้องการ

### 2.1 Workload (ต่อคน)

**Definition:**

> Workload = จำนวนงานที่ “ยังไม่จบ” ที่อยู่ในความรับผิดชอบของ operator คนนั้นตอนนี้

นับจาก token ที่:
- ยังไม่ `completed`
- ยังไม่ `scrapped`

ให้แตกเป็น 3 ประเภทใน backend:

- `active_count` – token ที่มี work_session status = `active` (กำลังทำ)
- `paused_count` – token ที่ work_session status = `paused` (หยุดงานไว้)
- `assigned_ready_count` – token ที่ assign ให้คนนี้ แต่ยังไม่ start (ไม่มี session หรือ session ไม่ active/paused)

รวมเป็น:

- `workload_total = active_count + paused_count + assigned_ready_count`

**Frontend display:**

- Pill หลักยังคงรูปแบบเดิม เช่น `2 tokens`
  - แต่ใช้ค่าจาก `workload_total`
- เพิ่ม tooltip หรือ sub-text เล็กใน cell เดิม เช่น:

  ```text
  2 tokens
  1 active · 1 paused · 0 assigned

	•	รูปแบบแนะนำ:
	•	บรรทัดบน: เหมือนเดิม (เลข + “tokens”)
	•	บรรทัดล่าง (ตัวเล็กสีเทา): ${active_count} active · ${paused_count} paused · ${assigned_ready_count} assigned

อย่าขยาย column หรือเปลี่ยน layout ของ row
ใช้ <small class="text-muted d-block">…</small> ใต้ตัวเลขเดิมก็เพียงพอ

⸻

2.2 Status (ต่อคน)

ปรับ mapping ให้สะท้อน “สภาพการทำงาน” จากข้อมูล workload ใหม่:

Logic แนะนำ:
	•	ถ้า active_count > 0
	•	แสดง Busy หรือ badge สีเดิมแต่ข้อความ
	•	else if paused_count > 0
	•	แสดง Assigned หรือ Paused ตาม style เดิม (เลือกข้อความที่อ่านง่าย)
	•	else if assigned_ready_count > 0
	•	แสดง Assigned
	•	else
	•	แสดง Available

จุดสำคัญคือ: คนที่มีงาน paused 2 งาน ไม่ควรถูกมองว่า “Available 100%”

กรณีที่มี operator availability flag จาก Task 10
	•	ถ้า availability = off (ไม่ว่าง / ออฟไลน์) ให้ overlay state นี้ใน Status (เช่น tooltip “Not available (manual override)”)
	•	แต่ priority ให้สภาพงานเป็นหลัก เช่น Busy (Not Available) ถ้าจำเป็น

⸻

2.3 Current Work (ต่อคน)

ต้องแสดง “งานหลัก” ที่เกี่ยวข้องกับ operator คนนี้ตอนนี้ โดยพิจารณาจาก:
	•	active tokens
	•	paused tokens
	•	assigned-ready tokens

Backend selection rule:

สำหรับ operator แต่ละคน ให้คำนวณ:
	1.	ถ้ามี active tokens:
	•	เลือกตัวที่ “สำคัญที่สุด” เช่น:
	•	active ล่าสุด (start_time ใหม่สุด)
	•	หรือ ที่ priority สูงสุด ถ้ามีข้อมูล
	•	ส่งกลับเป็น:
	•	current_work_ticket_code (เช่น ATELIER-2025…)
	•	current_work_state = 'active'
	2.	ถ้าไม่มี active แต่มี paused tokens:
	•	เลือก paused ล่าสุด / priority สูงสุด
	•	current_work_state = 'paused'
	3.	ถ้าไม่มี active/paused แต่มี assigned_ready tokens:
	•	เลือกตัวถัดไปในคิว
	•	current_work_state = 'ready'
	4.	ถ้าไม่มีอะไรเลย:
	•	current_work_ticket_code = null
	•	current_work_state = 'none'

Frontend display:

ใน Column Current Work:
	•	ถ้า state = 'active':
	•	แสดง: ATELIER-2025… (กำลังทำ) หรือ (In progress) ภาษาอังกฤษ
	•	ถ้า state = 'paused':
	•	แสดง: ATELIER-2025… (หยุดไว้)
	•	ถ้า state = 'ready':
	•	แสดง: Next: ATELIER-2025…
	•	ถ้า state = 'none':
	•	แสดง: - หรือ No current work

ใช้ข้อความเสริมใน <small> ไม่ต้องเปลี่ยนโครงตาราง

⸻

2.4 Realtime Work Timer per Operator

Goal: Manager เห็น “เวลาที่กำลังทำงาน” ของแต่ละคนแบบ realtime (คล้าย timer ในหน้า work_queue ของ operator)

ความหมายของเวลาใน People Monitor:
	•	ให้แสดง เวลาที่ operator ใช้กับ “current active work”
(เฉพาะกรณีที่มี token active อย่างน้อยหนึ่งตัว)
	•	ถ้าไม่มี active (มีแต่ paused / assigned) → ไม่ต้องนับถอยไป–มา
แสดง “หยุด” หรือไม่แสดง timer ก็ได้

Backend fields per operator:

สำหรับ operator ที่มีอย่างน้อยหนึ่ง active token:
	•	ส่งคืนอย่างน้อย 1 ตัวแปร:
	•	current_active_started_at (ISO datetime string)
	•	คือเวลาที่เริ่ม session ครั้งนี้ (ไม่รวม paused time ถ้าคุณหักแล้วใน field อื่น)
	•	หรือ ส่ง current_active_work_seconds แทนก็ได้ถ้าสะดวก
	•	ถ้ามี active หลาย token:
	•	เลือก token ตาม rule ในข้อ 2.3 (current_work)
	•	ใช้เวลา session ของ token ตัวนั้น

Frontend implementation idea:
	1.	ใน People table row แต่ละแถว (ของ operator):
	•	เพิ่ม <span class="operator-work-timer" data-started="...">
ใน column Current Work หรือ Status ก็ได้ แต่ อยู่ใน cell เดิม เช่น:

ATELIER-2025… (กำลังทำ)
<small class="text-success d-block">
  <i class="ri-time-line"></i> <span class="operator-work-timer" data-started="2025-11-18T10:40:00+07:00">0:00</span>
</small>


	•	เฉพาะเมื่อ current_work_state = 'active' เท่านั้น

	2.	เพิ่ม JS ในหน้า People Monitor:
	•	ใช้ pattern คล้าย updateAllTimers() จาก work_queue.js
	•	ตั้ง setInterval(updateOperatorTimers, 1000);
	•	ใน updateOperatorTimers:
	•	loop ทุก .operator-work-timer
	•	ดึงค่า data-started
	•	คำนวณ now - started_at (ถ้ามี field pause ให้ลบออกตาม design backend)
	•	แปลงเป็น mm:ss หรือ hh:mm:ss
	•	ใส่ลงใน text() ของ span
	3.	การ refresh หน้า People:
	•	หน้านี้มี auto-refresh ทุก 30 วินาทีอยู่แล้ว (ดูจาก “Auto-refresh every 30 seconds” ใน UI)
	•	เวลามีการ reload data:
	•	ให้แทนที่ row ทั้งหมดตามแบบเดิม
	•	timers ใหม่จะเริ่มนับจากค่าที่คำนวณใหม่ → ขยับไม่เกิน ±1s จากข้อมูลจริง (เพียงพอสำหรับ Manager view)
	4.	กรณีไม่มี active:
	•	ไม่ต้องใส่ span .operator-work-timer
	•	หรือแสดงข้อความเล็ก: หยุด: 12:34 แบบ static ถ้า backend ให้ paused_work_seconds มา (optional)

⸻

3. Implementation Checklist

3.1 Backend – People Monitor Data Provider

Locate:
	•	PHP endpoint / service ที่ใช้ส่งข้อมูลให้ People tab
(ค้นหาข้อความ People Monitor หรือคอลัมน์ Member / Teams / Status / Workload / Current Work)

Changes:
	1.	ปรับ query / aggregation:
	•	Join กับ token / work_session table เพื่อคำนวณ:
	•	active_count
	•	paused_count
	•	assigned_ready_count
	•	Filter เฉพาะ token ที่ยังไม่ completed / scrapped ในการนับ workload
	2.	เพิ่มฟิลด์ใน response:
	•	workload_total
	•	workload_active
	•	workload_paused
	•	workload_assigned_ready
	•	current_work_ticket_code
	•	current_work_state (active|paused|ready|none)
	•	ถ้ามี active:
	•	current_active_started_at (และ/หรือ current_active_work_seconds)
	3.	ใช้ข้อมูลข้างบน map ไปยัง:
	•	Status badge (Available/Assigned/Busy)
	•	Workload total + breakdown
	•	Current Work text
	•	Timer data attribute

⸻

3.2 Frontend – People tab JS

Locate:
	•	JS ที่ใช้ render ตาราง People Monitor
(ค้นหา text People Monitor, หรือ selectors ของ table นี้)

Changes:
	1.	ใช้ฟิลด์ workload ใหม่:
	•	พิมพ์เลขหลักจาก workload_total
	•	เพิ่ม sub-text:

`${active} active · ${paused} paused · ${assigned} assigned`


	2.	ใช้ current_work_ticket_code + current_work_state:
	•	active → ATELIER-… (กำลังทำ)
	•	paused → ATELIER-… (หยุดไว้)
	•	ready → Next: ATELIER-…
	•	none → -
	3.	Realtime timer:
	•	ถ้า current_work_state === 'active' และมี current_active_started_at:
	•	สร้าง <span class="operator-work-timer" data-started="...">0:00</span>
	•	เรียก initOperatorTimers() หนึ่งครั้งหลัง render
	•	เพิ่ม setInterval(updateOperatorTimers, 1000); เหมือน pattern ใน work_queue.js (แต่ใช้ selector .operator-work-timer)
	4.	ระวัง:
	•	อย่าเปลี่ยน HTML structure หลักของตาราง
	•	เพิ่ม element ภายใน <td> เดิมเท่านั้น
	•	อย่าลืมเคลียร์ interval เมื่อเปลี่ยนหน้า (ถ้ามี SPA behaviour)

⸻

4. Acceptance Criteria
	1.	Workload ถูกต้อง
	•	Operator ที่มี 1 token assign แต่ยังไม่เริ่ม:
	•	Workload = 1, breakdown = 0 active · 0 paused · 1 assigned
	•	Operator ที่มี 2 งาน paused:
	•	Workload breakdown = 0 active · 2 paused · 0 assigned
	2.	Status สื่อความถูกต้อง
	•	ถ้ามี active/paused > 0 → ไม่แสดงเป็น “Available” ล้วน ๆ
	•	Operator ที่ไม่มีงานเลย → Available
	3.	Current Work มีความหมาย
	•	ถ้ามี active → แสดงงาน active ล่าสุด พร้อม state (กำลังทำ)
	•	ถ้าหยุดไว้ → แสดง (หยุดไว้)
	•	ถ้าว่าง → - หรือ No current work
	4.	Realtime Timer ต่อคน
	•	ถ้ามี active:
	•	ในแถวของ operator นั้นต้องมีตัวเลขเวลาเดินขึ้นทุกวินาที
	•	ถ้า pause หรือจบงาน:
	•	หลัง refresh รอบถัดไป timer ต้องหาย / เปลี่ยนสถานะตามจริง
	•	Auto-refresh ทุก 30 วินาทีไม่ทำให้ UI กระพริบผิดปกติ
	5.	No layout / design regression
	•	โครง People Monitor UI เหมือนเดิม
	•	เพิ่มแต่ข้อความเล็ก / tooltip / icon timer เท่านั้น
