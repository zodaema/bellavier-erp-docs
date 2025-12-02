# Task 24.4.1 — Fix Job Ticket Creation Defaults (Classic Line + DAG)

## Objective
แก้ปัญหาการสร้าง Job Ticket ใหม่ที่ยัง fallback ไปใช้ค่าเริ่มต้นแบบ Legacy (production_type = hatthasilpa, routing_mode = linear) โดยบังคับให้ Job Ticket ที่สร้างจาก MO เป็น **Classic Line + DAG Mode** ตามแนวคิดล่าสุดของระบบ และเตรียมฐานให้ Lifecycle v2 จาก Task 24.4 ทำงานกับ Classic Line ได้ถูกต้อง

---

## 1. Scope

### 1.1 ครอบคลุม
- การสร้าง Job Ticket จากหน้า / API ที่ผูกกับ MO (Classic Line เท่านั้น)
- การกำหนดค่า `production_type` และ `routing_mode` ที่ถูกต้อง
- การส่งค่าจาก JS/Frontend ให้สอดคล้อง
- การกันไม่ให้ Job Ticket ของ Classic ถูกสร้างเป็น Hatthasilpa โดยไม่ได้ตั้งใจ

### 1.2 ไม่ครอบคลุม
- ไม่แตะ Hatthasilpa Job Ticket (สร้างจาก flow ของ Hatthasilpa เท่านั้น)
- ไม่เปลี่ยนแปลง Node Behavior Engine, Canonical, Repair Engine
- ไม่แตะ PWA / Scan Terminal (Phase PWA จะทำแยก)
- ไม่เปลี่ยน schema database

---

## 2. Business Rules (Truth ใหม่)

1. Job Ticket ที่สร้างจาก MO (ผ่านหน้า MO / job_ticket.php) = **Classic Line เท่านั้น**
2. Classic Line ใช้ **DAG Mode** สำหรับ routing/token (เมื่อมี graph ผูกกับ product/MO)
3. Hatthasilpa Line จะมี flow การสร้าง Job Ticket แยกต่างหาก (ไม่ผ่าน MO create ตัวนี้)
4. Legacy default เดิม (hatthasilpa + linear) ถือว่า **ผิดบริบท Bellavier ERP รุ่นใหม่** สำหรับ MO-origin tickets

---

## 3. Backend Changes — `source/job_ticket.php`

### 3.1 Identify Entry Points for Creation
- ค้นหา handler สำหรับสร้าง Job Ticket เช่น:
  - `handleCreate()`
  - หรือ action อื่นที่ใช้สำหรับสร้าง/clone ticket จาก MO

### 3.2 บังคับค่า Default สำหรับ MO-origin Job Tickets

กรณีสร้าง Job Ticket จาก MO:
- บังคับให้ใช้:
  - `production_type = 'classic'`
  - `routing_mode = 'dag'` (ถ้ามี routing_graph)

Pseudo-code แนวทาง:

```php
// ภายใน handleCreate() หรือจุดที่ map จาก MO → job_ticket payload

if ($source === 'mo' || isset($payload['id_mo'])) {
    $payload['production_type'] = 'classic';

    // ถ้ามี graph binding → บังคับเป็น dag
    if (!empty($payload['id_routing_graph'])) {
        $payload['routing_mode'] = 'dag';
    } else {
        // fallback: ถ้ายังไม่มี graph → อาจใช้ 'linear' ชั่วคราวได้
        // แต่ต้องไม่ทำให้ production_type กลายเป็น hatthasilpa
        if (empty($payload['routing_mode'])) {
            $payload['routing_mode'] = 'linear';
        }
    }
}
```

### 3.3 ห้าม fallback ไปยัง hatthasilpa โดยอัตโนมัติ
- ถ้า logic เดิมมีการตั้งค่า default ประมาณ:
  - ถ้าไม่ส่ง production_type มา → ตั้งเป็น `hatthasilpa`
- ให้เปลี่ยนเป็น:
  - ถ้าเป็น MO-origin → default เป็น `classic`
  - ถ้าเป็น endpoint อื่นที่ชัดเจนว่าเป็น Hatthasilpa ค่อยเซ็ต `hatthasilpa` ชัดเจน (เช่น ผ่านไฟล์ hatthasilpa_job_ticket.php)

### 3.4 Logging (Optional)
- เพิ่ม log debug เมื่อมีการ override ค่า production_type/routing_mode จาก legacy default → classic/dag

---

## 4. Frontend / JS Changes — `assets/javascripts/hatthasilpa/job_ticket.js`

> หมายเหตุ: ถึงจะอยู่ใน path `hatthasilpa/` แต่ใช้เป็น JS หลักของหน้า Job Ticket ปัจจุบันอยู่แล้ว อย่าสับสนกับ Hatthasilpa Line จริง

### 4.1 ส่ง production_type / routing_mode ตอนสร้าง Ticket

เมื่อเรียก API create Job Ticket จากหน้า MO หรือหน้า Job Ticket:
- บังคับส่ง:
  - `production_type = 'classic'`
  - ถ้าหน้า UI สามารถรู้ว่ามี graph ผูกกับ product/MO อยู่แล้ว → ส่ง `routing_mode = 'dag'`

```javascript
// ตัวอย่างใน payload ที่ใช้ $.ajax หรือ fetch
const payload = {
  // ...ค่าที่มีอยู่แล้ว
  id_mo: moId,
  production_type: 'classic',
  routing_mode: hasRoutingGraph ? 'dag' : 'linear',
};
```

### 4.2 ไม่ต้องให้ user เลือกเองใน UI (ตอนนี้)
- ห้ามสร้าง dropdown ให้ user เลือก Classic / Hatthasilpa / routing mode เพราะขัดกับ principle ของ Close System
- ทั้งหมดให้ระบบ “ตัดสินใจให้” ตาม business rule ข้างบน

---

## 5. Consistency Checks

หลัง patch แล้วควรตรวจสอบด้วย SQL/Log ระดับง่ายๆ:

1. สร้าง MO ใหม่ → Plan → สร้าง Job Ticket
   - ตรวจดูใน `job_ticket` ว่า:
     - `production_type = 'classic'`
     - `routing_mode = 'dag'` (ถ้ามี graph)

2. ตรวจ Ticket เดิม (ก่อน patch) ว่า:
   - ไม่โดนแก้ย้อนหลัง
   - lifecycle v2 จาก Task 24.4 ยังทำงานเหมือนเดิม

3. ทดสอบ Start / Pause / Resume / Complete บน Ticket ที่สร้างหลัง patch
   - ตรวจการ spawn token / complete token ใน DAG mode
   - ตรวจ log / ETA hook ว่าไม่พัง

---

## 6. Acceptance Criteria

1. Job Ticket ที่สร้างจาก MO **ทั้งหมด** หลังจาก patch:
   - `production_type` เป็น `classic` เสมอ
   - ถ้ามี routing_graph ผูกอยู่ → `routing_mode = 'dag'`

2. ไม่มีการสร้าง Job Ticket จาก MO ที่ production_type = `hatthasilpa` โดยไม่ได้ตั้งใจอีกต่อไป

3. Lifecycle v2 (จาก Task 24.4) ทำงานได้ถูกต้องกับ Job Ticket ใหม่ (classic+dag)

4. ไม่มี schema change, ไม่มีผลข้างเคียงกับ Hatthasilpa Line

---

## 7. Notes for Agent

- อย่าแตะไฟล์/โค้ดที่เกี่ยวข้องกับ Hatthasilpa Jobs โดยตรง (เช่น `hatthasilpa_job_ticket.php`) ใน Task นี้
- แก้เฉพาะ flow ที่สร้าง Job Ticket จาก MO เท่านั้น
- อย่าสร้าง UI ใหม่ให้ user เลือก production_type / routing_mode
- ใส่ comment ใน code ที่เปลี่ยนว่า `// Task 24.4.1 — Force Classic Line for MO-origin tickets`
- รักษา backward compatibility กับตั๋วเก่าทั้งหมด


_End of Task 24.4.1 Specification_
