# Task 24.6.6 – Integrate Hatthasilpa "View Job" with Job Ticket Offcanvas

## เป้าหมาย

ทำให้ปุ่ม **“ดูงาน / View (eye icon)”** ในหน้า **Hatthasilpa Jobs**  
เปิด **Job Ticket Offcanvas เดียวกันกับหน้า Job Ticket** (เหมือน MO ใช้)  
โดย:

- ใช้ `job_ticket.php + job_ticket.js` เป็น **single source of truth** สำหรับรายละเอียดงานทุก line
- **ห้าม** ให้ Hatthasilpa ใช้ lifecycle buttons จาก Job Ticket (start/pause/resume/complete/cancel/restore)  
  → Action lifecycle ของ Hatthasilpa ต้องใช้ `hatthasilpa_jobs_api.php` เหมือนเดิมเท่านั้น

---

## Scope

### In Scope

1. เชื่อมปุ่ม “ดูงาน” ในหน้า Hatthasilpa Jobs → เปิด Job Ticket offcanvas
2. ให้ Job Ticket offcanvas รู้จัก context ว่ามาจาก Hatthasilpa และ:
   - แสดงข้อมูลรายละเอียด / progress / tokens ได้ครบ
   - **ซ่อน** หรือ disable lifecycle buttons สำหรับ Hatthasilpa jobs
3. ไม่แก้ behaviour ของ API lifecycle:
   - `hatthasilpa_jobs_api.php` → `start_job`, `start_production`, `pause_job`, `cancel_job`, `restore_to_planned`, `complete_job`
   - `job_ticket.php` ยังใช้ lifecycle เฉพาะ Classic

### Out of Scope

- ไม่ยุ่ง logic การสร้าง/ยกเลิก/restore job ใน backend
- ไม่เปลี่ยน state-machine หรือ token rules ใด ๆ

---

## ไฟล์ที่คาดว่าจะต้องแก้

> ชื่อไฟล์อาจต่างเล็กน้อย ให้ search ก่อนแก้

1. `views/hatthasilpa_jobs.php`
2. `assets/javascripts/hatthasilpa/hatthasilpa_jobs.js`
3. `assets/javascripts/hatthasilpa/job_ticket.js`
4. (ถ้าจำเป็น) `source/hatthasilpa_jobs_api.php` – เฉพาะกรณี list ไม่ส่ง `id_job_ticket` มาให้ JS

---

## รายละเอียดงาน

### 1) Expose ฟังก์ชันเปิด Offcanvas ใน `job_ticket.js`

**เป้าหมาย:** ให้หน้าอื่น (MO, Hatthasilpa Jobs) สามารถเรียกเปิด Job Ticket offcanvas ได้ง่าย

1. ใน `assets/javascripts/hatthasilpa/job_ticket.js`:
   - หา logic ที่ใช้ตอนกด view job ในหน้า Job Ticket (เช่น `loadTicketDetail(id)` + เปิด offcanvas)
   - สร้างฟังก์ชัน helper ระดับ global เช่น:

   ```js
   function openJobTicketOffcanvas(ticketId, options) {
       // options.production_type อาจเป็น 'classic' หรือ 'hatthasilpa'
       // 1) เปิด offcanvas
       // 2) call loadTicketDetail(ticketId)
       // 3) ถ้ามี options.production_type === 'hatthasilpa'
       //    ให้ mark state ไว้ (เช่น window.currentTicketProductionType)
       //    เพื่อใช้ตัดสินใจซ่อนปุ่ม lifecycle
   }

   // export ไว้ global
   window.openJobTicketOffcanvas = openJobTicketOffcanvas;

	2.	ตรวจสอบให้แน่ใจว่า loadTicketDetail() ทำงานได้ปกติเมื่อถูกเรียกจากที่อื่น (ไม่มี dependency กับ DataTable ภายในหน้า job_ticket เท่านั้น)

⸻

2) ซ่อน lifecycle buttons สำหรับ Hatthasilpa ใน Offcanvas

ส่วนนี้บางส่วนอาจมีแล้วใน Task ก่อนหน้า ให้ตรวจสอบและ “ทำให้แน่ใจ” ว่าทำงานครบ

	1.	ใน job_ticket.js:
	•	เมื่อโหลด detail เสร็จ เราจะรู้ production_type จาก API (classic / hatthasilpa)
	•	ถ้า production_type === 'hatthasilpa' ให้:
	•	ซ่อน container ปุ่ม lifecycle ทั้งชุด (start/pause/resume/complete/cancel/restore)
เช่น $('#ticket-lifecycle-buttons').hide();
	•	ถ้าเคยใช้ flag อื่นมาก่อน (เช่น line_type, routing_mode) ให้ใช้ consistent
	•	ถ้า production_type === 'classic' → แสดงปุ่มตาม state-machine ปกติ
	2.	ถ้ายังไม่มี container แยกปุ่ม lifecycle ใน views/job_ticket.php ให้ confirm ว่ามี id/class ที่ JS ใช้ได้ชัดเจน
(อย่าเปลี่ยน layout เดิมมากเกินจำเป็น)

⸻

3) Hook ปุ่ม “View” ในหน้า Hatthasilpa Jobs
	1.	ใน source/hatthasilpa_jobs_api.php action list ให้ตรวจสอบว่า:
	•	response ของแต่ละ row มี id_job_ticket ใน field ชัดเจน เช่น id_job_ticket
	•	ถ้าไม่มี ให้ SELECT เพิ่มและ map เข้า JSON
	2.	ใน views/hatthasilpa_jobs.php ตรวจว่า:
	•	DataTable หรือ HTML row มี data-attribute หรือ cell ที่เก็บ id_job_ticket
ถ้าไม่มี ให้เพิ่มใน column ที่ซ่อน หรือ data-id-job-ticket บน <tr> หรือปุ่ม eye icon
	3.	ใน assets/javascripts/hatthasilpa/hatthasilpa_jobs.js:
	•	ผูก click handler กับปุ่ม eye icon ในคอลัมน์ Actions
ตัวอย่างเช่น (ปรับตาม structure เดิม):

$('#hatthasilpa_jobs_table').on('click', '.btn-view-job', function (e) {
    e.preventDefault();
    const rowData = table.row($(this).closest('tr')).data();
    const ticketId = rowData.id_job_ticket; // หรือดึงจาก data-attr
    if (!ticketId) {
        console.warn('No id_job_ticket found for this row');
        return;
    }
    if (typeof window.openJobTicketOffcanvas === 'function') {
        window.openJobTicketOffcanvas(ticketId, {
            production_type: 'hatthasilpa',
            source: 'hatthasilpa_jobs'
        });
    }
});


	4.	อย่าเปลี่ยน behaviour ของปุ่มอื่นในคอลัมน์ Actions:
	•	ปุ่ม settings / plan / share / delete ให้ทำงานเดิม
	•	Lifecycle ของ Hatthasilpa jobs (start/pause/cancel/restore) ยังใช้ modal/flow เดิมในหน้านี้ ไม่ย้ายไป offcanvas

⸻

Acceptance Criteria
	1.	จากหน้า Hatthasilpa Jobs:
	•	กดปุ่ม eye → Offcanvas Job Ticket เปิดขึ้น
	•	แสดงรายละเอียด ticket ถูกต้อง (code, job name, product, qty, progress ฯลฯ)
	•	ค่า production_type แสดง/ตีความเป็น hatthasilpa ถูกต้อง (ถ้ามีใน UI)
	2.	ใน Offcanvas (เมื่อเปิดจาก Hatthasilpa Jobs):
	•	ไม่แสดง ปุ่ม lifecycle ของ Job Ticket (start / pause / resume / complete / cancel / restore)
	•	Progress / Node / Tokens / Logs section (ถ้ามี) แสดงได้ตามปกติ (read-only)
	3.	ใน Offcanvas (เมื่อเปิดจาก Job Ticket สำหรับ Classic):
	•	ปุ่ม lifecycle ยังทำงานเหมือนเดิม (ไม่มี regression)
	4.	Hatthasilpa Jobs:
	•	เมื่อเพิ่งสร้าง job ใหม่ด้วย create → status = planned
	•	กด “Start Job” / “Start Production” → status เปลี่ยนเป็น in_progress และ token ถูก spawn ตามเดิม
	•	ปุ่ม “View” แสดงสภาพ token / progress ที่สอดคล้องกับสถานะใน Work Queue
	5.	ไม่มี Error ใหม่ใน:
	•	PHP error log
	•	Browser console (JS)

⸻

Checklist ก่อนจบ Task
	•	ทดสอบเปิด Classic job จากหน้า Job Ticket → lifecycle ปกติ
	•	ทดสอบเปิด Hatthasilpa job จากหน้า Hatthasilpa → offcanvas read-only, ไม่มี lifecycle buttons
	•	ทดสอบสร้าง Hatthasilpa job → Planned → Start → In Progress → View
	•	Commit message แนะนำ:
feat(hatthasilpa): link jobs view to shared job ticket offcanvas

เอาไฟล์ด้านบนไปวางเป็น `task24_6_6.md` แล้วให้ Agent รันตามนี้ได้เลยครับ ✅
# Task 24.6.6 – Hatthasilpa View + Creation Status Hardening

## เป้าหมายหลัก (ต้องทำให้ได้ก่อน)

1. **Lock Spec การสร้าง Hatthasilpa Job**
   - เมื่อสร้าง Hatthasilpa Job ใหม่ผ่าน `hatthasilpa_jobs_api.php` action `create`:
     - สถานะเริ่มต้น **ต้องเป็น** `planned` เสมอ
     - **ห้าม** auto-set เป็น `in_progress` ในทุกกรณี
     - **ห้าม** spawn tokens ใด ๆ ตอน `create` (ต้องรอให้ user กด Start ด้วย action เฉพาะ)
   - Logic ใด ๆ ที่ทำให้ job ใหม่กลายเป็น `in_progress` ทันทีหลัง create ต้องถูกลบ/ปิดทิ้ง

2. **ใช้ความสามารถเดิมของระบบในการเปิด Job Ticket Offcanvas จาก URL**
   - ระบบปัจจุบันรองรับการเปิด offcanvas ของ Job Ticket ผ่าน URL:
     - ตัวอย่าง: `index.php?p=job_ticket&amp;id=778`
   - หน้านี้ต้องใช้ความสามารถเดิมให้เต็มที่ โดยไม่จำเป็นต้องสร้าง JS helper ซับซ้อนเกินไป

---

## Scope

### In Scope

1. ปรับให้ `hatthasilpa_jobs_api.php` action `create`:
   - ignore ค่า `status` ที่ส่งมาจาก frontend (ถ้ามี)
   - บังคับให้บันทึก `status = 'planned'` เท่านั้น
   - confirm ว่าไม่มีการเรียก `start_job` / `start_production` / spawn token ต่อจาก `create`

2. ตรวจสอบ flow หลังสร้าง Hatthasilpa Job:
   - หน้า Hatthasilpa Jobs แสดง status เป็น `Planned`
   - หลัง user กดปุ่ม Start/Begin/Start Production เท่านั้น job จึงเปลี่ยนเป็น `In Progress` และค่อย spawn tokens

3. เชื่อมปุ่ม “ดูงาน / View (eye icon)” ในหน้า Hatthasilpa Jobs:
   - ให้เปิดหน้า `index.php?p=job_ticket&amp;id={id_job_ticket}` โดยตรง
   - ใช้ behaviour เดิมของหน้า `job_ticket.php` ในการเปิด offcanvas ตาม `id` ที่ส่งไป

4. เมื่อเปิด Job Ticket จาก URL ดังกล่าว:
   - ถ้า ticket เป็น Hatthasilpa:
     - ให้ Job Ticket Offcanvas แสดงข้อมูล detail/progress/tokens ได้ตามปกติ (read-only)
     - lifecycle buttons ที่เป็นของ Classic (start/pause/resume/complete/cancel/restore) **ต้องถูกซ่อน** หรือ disabled
   - ถ้า ticket เป็น Classic:
     - behaviour ต้องเหมือนเดิม (ยังใช้ lifecycle buttons ได้ปกติ)

### Out of Scope

- ไม่เปลี่ยน state machine หลักของ Hatthasilpa job (start/pause/cancel/restore) ใน `hatthasilpa_jobs_api.php`
- ไม่แก้ logic ของ Classic Job Ticket lifecycle ใน `job_ticket.php`
- ไม่ออกแบบ UI ใหม่ทั้งหน้า job_ticket หรือ hatthasilpa_jobs (ปรับเท่าที่จำเป็นเพื่อให้ flow ทำงานได้ตาม spec)

---

## รายละเอียดงาน

### 1) Hard-lock การสร้าง Hatthasilpa Job ให้เป็น `planned`

**ไฟล์หลัก:** `source/hatthasilpa_jobs_api.php`

1. หา action `create` (หรือชื่อใกล้เคียง) ที่ใช้สร้าง Hatthasilpa Job
2. ตรวจสอบจุดที่กำหนดค่า `status` ตอน insert:
   - ถ้ามีการอ่าน status จาก `$_POST` หรือ payload ให้ **ไม่ใช้ค่าเหล่านั้น**
   - force ให้ใช้ค่าเดียว เช่น:

   ```php
   $status = 'planned';
   ```

3. ตรวจสอบ function/logic ต่อเนื่องจาก `create`:
   - ห้ามมีการเรียก function ใด ๆ ที่ทำให้:
     - status เปลี่ยนเป็น `in_progress` ทันที
     - spawn/allocate tokens ให้ instance ทันทีหลัง create
   - ถ้าพบ logic ลักษณะนี้ ให้ลบ/คอมเมนต์ออก พร้อม comment ว่า:
     - `// NOTE: Task 24.6.6 – creation must stay in 'planned' until user explicitly starts the job.`

4. ทดสอบด้วยการสร้าง Hatthasilpa Job ใหม่:
   - ตรวจใน DB ว่า status = `planned`
   - ตรวจว่า table token/instance ยังไม่ถูกสร้างบรรทัดใหม่จาก job นี้

---

### 2) ใช้ URL เดิมในการเปิด Job Ticket Offcanvas

**ความสามารถเดิมของระบบ:**

- สามารถเปิด Job Ticket page ด้วย:
  - `index.php?p=job_ticket&amp;id={job_ticket_id}`
- เมื่อหน้า `job_ticket.php` ถูกโหลดพร้อม `id`:
  - JS ฝั่งหน้า Job Ticket จะโหลดรายละเอียดของ ticket ตาม id
  - และเปิด offcanvas ให้โดยอัตโนมัติ (pattern เดิมของ MO)

**สิ่งที่ต้องทำ:**

#### A. ให้ Hatthasilpa Jobs รู้จัก `id_job_ticket`

- ใน `source/hatthasilpa_jobs_api.php` action `list`:
  1. ตรวจสอบว่ามีการ SELECT column `id_job_ticket` แล้วหรือยัง
  2. ถ้ายังไม่มี ให้ JOIN/SELECT เพิ่ม field นี้ และ map เข้า JSON response แต่ละ row

#### B. อัปเดตปุ่ม View ใน `views/hatthasilpa_jobs.php`

- หา column Actions และปุ่ม eye icon (View)
- ปรับให้:
  - มี `<a>` หรือ `<button>` ที่มีลิงก์ไป `index.php?p=job_ticket&amp;id={id_job_ticket}`
  - เช่น:

  ```php
  &lt;a href="index.php?p=job_ticket&amp;id=&lt;?= (int)$row['id_job_ticket'] ?&gt;" class="btn btn-sm btn-outline-primary btn-view-job" title="ดู Job Ticket"&gt;
      &lt;i class="fa fa-eye"&gt;&lt;/i&gt;
  &lt;/a&gt;
  ```

- ถ้าใช้ DataTable และ render ด้วย JS:
  - ให้ส่ง `id_job_ticket` ใน JSON และใช้ JS สร้าง URL นี้ตอน render

---

### 3) ซ่อน lifecycle buttons สำหรับ Hatthasilpa ใน Offcanvas

**ไฟล์หลัก:** `views/job_ticket.php`, `assets/javascripts/hatthasilpa/job_ticket.js`

1. ใน `job_ticket.php`:
   - Make sure container ของ lifecycle buttons มี id ที่แน่นอน เช่น `id="ticket-lifecycle-buttons"` (ถ้ายังไม่มี)
2. ใน `job_ticket.js`:
   - หลังจากโหลดข้อมูล ticket แล้ว (ใน `loadTicketDetail()` หรือ callback ที่ใช้งาน):
     - อ่านค่าประเภทงานจาก response เช่น `production_type` หรือ `line_type`
     - ถ้าเป็น Hatthasilpa (`production_type === 'hatthasilpa'`):
       - ซ่อน container ปุ่มทั้งหมด เช่น:

       ```js
       $('#ticket-lifecycle-buttons').hide();
       ```

     - ถ้าเป็น Classic:
       - แสดง container ปุ่ม และใช้ state-machine logic ตามเดิม

3. อย่าลืม handle case ที่เปิดด้วย URL:
   - เมื่อเปิด `index.php?p=job_ticket&amp;id=...` โดยตรง:
     - JS ต้องอ่าน `id` จาก query string (ถ้าระบบทำอยู่แล้ว ให้คง logic เดิม)
     - ใช้ flow เดิมในการเปิด offcanvas

---

## Acceptance Criteria

1. **Creation Status Lock**
   - สร้าง Hatthasilpa Job ใหม่ → DB บันทึก status = `planned`
   - ไม่มี token/instance ใหม่ถูกสร้างจาก job นี้จนกว่าจะมีการกด Start

2. **Start Flow**
   - จากหน้า Hatthasilpa Jobs:
     - Job ใหม่: `Planned`
     - กดปุ่ม Start / Start Production บน job นั้น:
       - status เปลี่ยนเป็น `In Progress`
       - token ถูก spawn ถูกต้อง
     - กด Cancel / Restore ยังใช้ flow เดิม ไม่มี regression

3. **View Job Ticket จาก Hatthasilpa Jobs**
   - กดปุ่ม eye จาก Hatthasilpa Jobs:
     - Browser ไปที่ `index.php?p=job_ticket&amp;id={id_job_ticket}`
     - Offcanvas Job Ticket เปิดพร้อมรายละเอียด ticket
   - ถ้า ticket นี้เป็น Hatthasilpa:
     - lifecycle buttons ทั้งหมดถูกซ่อน หรือ disabled
   - ถ้า ticket นี้เป็น Classic:
     - lifecycle buttons ทำงานได้ปกติ

4. **ไม่มี Error ใหม่**
   - ไม่มี PHP warning/notice/error ใน log จากการสร้าง/เปิด job
   - ไม่มี JS error ใน browser console เวลา:
     - เปิดหน้า Hatthasilpa Jobs
     - คลิก View → เปิด Job Ticket
     - สร้าง Hatthasilpa Jobs ใหม่และเริ่มงาน

---

## Checklist ก่อนจบ Task

- [ ] สร้าง Hatthasilpa Job ใหม่ → ตรวจใน DB ว่า status = `planned` และไม่มี token/instance เกิดขึ้น
- [ ] กด Start จาก Hatthasilpa Jobs → status = `in_progress` + spawn tokens ตามคาด
- [ ] กด View จาก Hatthasilpa Jobs → เปิด `job_ticket` page + offcanvas แสดงข้อมูลถูกต้อง
- [ ] ตรวจว่า Classic Job Ticket ยังใช้ lifecycle buttons ได้ตามเดิม
- [ ] ตรวจ log PHP และ browser console ว่าไม่มี error ใหม่
- [ ] Commit message แนะนำ:  
  `fix(hatthasilpa): lock creation status to planned and reuse job ticket offcanvas`

---

## Status

- ✅ **COMPLETED** (2025-11-29)
- See: [task24_6_5_results.md](results/task24_6_5_results.md)