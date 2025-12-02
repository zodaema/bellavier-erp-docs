# Bellavier Time Engine v2 – Hatthasilpa ERP Implementation

> **Document purpose**: บันทึกแนวคิดระยะยาว (Concept & Roadmap) สำหรับระบบจับเวลาใน Bellavier Group ERP / Hatthasilpa ก่อนเริ่มลงมือ Implement จริงในแต่ละ Task เพื่อป้องกันการลืม logic ใหญ่ และใช้เป็นกรอบอ้างอิงกลางให้ทุก Agent / Dev ในอนาคต

---

## 0. Philosophy – ทำไม “เวลา” คือหัวใจของ Bellavier ERP

สำหรับ Bellavier Group, ระบบ ERP ชุด Hatthasilpa ไม่ได้เป็นแค่ระบบจัดการงาน แต่เป็น **เครื่องมือวัดคุณภาพของหัตถศิลป์ (Hatthasilpa) และ Productivity ของ Atelier ทั้งระบบ**

"เวลา" จึงไม่ใช่แค่ตัวเลข แต่คือ:

1. **หลักฐานของความทุ่มเทและฝีมือ**  
   - งานเย็บมือ 1 ใบ, เวลา 4 ชั่วโมง กับ 40 ชั่วโมง มีความหมายต่อการเล่าเรื่อง (Narrative) ต่างกันมาก
2. **ฐานข้อมูลสำหรับตัดสินใจทางธุรกิจ**  
   - ใช้คำนวณต้นทุนแรงงานรายใบ, ประสิทธิภาพคน, Bottleneck, Capacity Planning
3. **เสาหลักของ Traceability**  
   - เมื่อผูกเวลาเข้ากับ Token / Serial / People → เรารู้ว่า ใครทำอะไร เมื่อไร นานเท่าไร ในแต่ละชิ้นงาน

ดังนั้น Time Engine v2 ต้องถูกออกแบบให้ **แม่นยำ, โปร่งใส, ขยายต่อได้** และอยู่ในระดับ **Professional / Enterprise** มากกว่าระบบจับเวลาทั่วไป

---

## 1. Design Goals & Principles

### 1.1 Design Goals

1. **Single Source of Truth**  
   Logic นับเวลาต้องอยู่ศูนย์กลาง (Time Engine Service) ไม่กระจายอยู่ใน SQL / Controller หลายที่

2. **Deterministic & Auditable**  
   ทุกวินาทีที่ถูกนับ ต้องย้อนกลับไปอธิบายได้ว่าเกิดจาก Session ไหน, เริ่มเมื่อไร, หยุดเมื่อไร, ผ่านกติกาอะไร

3. **Resilient ต่อ Real-world Problems**  
   เช่น ช่างลืมกดหยุด, แท็บปิดเอง, Tablet Sleep, ไฟดับ → เวลาไม่ควรผิดไปหลายชั่วโมงโดยไม่รู้ตัว

4. **Frontend-friendly (Drift-aware)**  
   เวลาในจอ Operator / Manager ต้องเดินลื่น, ไม่กระตุก, ไม่เพี้ยนจาก Server เกินที่ยอมรับได้

5. **Scalable**  
   รองรับจำนวน Session/Token หลักล้าน+ ต่อปี โดยไม่ทำให้ Work Queue ช้าจนใช้งานจริงไม่ได้

6. **Extensible for Future Analytics**  
   รองรับการแยกประเภทเวลา (Operator time, Machine time, Waiting time, Blocked time) ในอนาคต

---

## 2. ภาพรวมเฟสของ Time Engine v2

เพื่อไม่ให้ Refactor ครั้งเดียวใหญ่เกินไป แผนจะถูกแบ่งเป็นหลายเฟสต่อเนื่องกัน:

1. **Phase 0 – Current State (Baseline)**  
   บันทึกสถานะปัจจุบันก่อนปรับ
2. **Phase 1 – Core Engine (Backend)**  
   สร้าง Service กลางสำหรับคำนวณเวลาจาก token_work_session
3. **Phase 2 – Frontend Timer (Drift-corrected)**  
   ปรับ Work Queue ให้ใช้ Time DTO ใหม่ และแก้ logic timer ให้แม่นยำ/ลื่น
4. **Phase 3 – Auto Guard (Abandoned Session Protection)**  
   ป้องกันกรณีช่างลืมกด pause/complete, ปิดแท็บ, เครื่องดับ
5. **Phase 4 – Multi-surface Integration**  
   ให้ People Monitor, Trace Overview, Analytics ใช้ Time Engine ร่วมกัน
6. **Phase 5 – Advanced Analytics & Costing**  
   แปรข้อมูลเวลาไปเป็น Productivity, Cost per item, SLA, Capacity Planning

ด้านล่างคือรายละเอียดแต่ละเฟส

---

## 3. Phase 0 – Current State (Baseline)

**เป้าหมาย:** บันทึกสภาพปัจจุบันของระบบหน่วยเวลา ก่อนเริ่ม Refactor

### 3.1 แหล่งข้อมูลหลักตอนนี้

- ตาราง `token_work_session`  
  ใช้เก็บสถานะ session การทำงานต่อ token เช่น:
  - `status` = `active | paused | completed`
  - `work_seconds` = เวลาสะสม (base) ที่บันทึกไว้ใน DB
  - `started_at` / `resumed_at` = เวลาที่เริ่ม หรือกลับมาทำต่อ

- Work Queue API (เช่น `handleGetWorkQueue()` ใน `dag_token_api.php`):
  - ใช้ **SQL CASE + TIMESTAMPDIFF** คำนวณ `work_seconds_display` ทุกครั้ง

ตัวอย่าง logic ปัจจุบัน:

```sql
CASE 
    WHEN s.status = 'active' THEN 
        COALESCE(s.work_seconds, 0) 
        + TIMESTAMPDIFF(SECOND, COALESCE(s.resumed_at, s.started_at), NOW())
    WHEN s.status IN ('paused', 'completed') THEN 
        COALESCE(s.work_seconds, 0)
    ELSE 0
END as work_seconds_display
```

### 3.2 ปัญหาที่พบใน Phase 0

1. Logic เวลาอยู่ใน SQL → กระจาย, แก้ยาก, scale ไม่ดีเมื่อมีงานเยอะ
2. หลายหน้าจออาจต้องใช้เวลาคำนวณอีก → เสี่ยงที่แต่ละจุดคำนวณไม่ตรงกัน
3. Frontend ใช้ setInterval `+1 sec` แบบหยาบ ๆ โดยไม่รู้ server time → เกิด drift ระยะยาวได้
4. ยังไม่มีระบบ auto-guard ปิด session แปลก ๆ (ลืมกด pause, ปิดแท็บ ฯลฯ)
5. ไม่มีการแบ่งประเภทเวลา (Operator/Machine/Waiting/Blocked) – แต่ในอนาคตต้องรองรับ

Phase 0 = baseline ที่ต้อง "ย้าย" ความฉลาดไปอยู่ใน Engine กลาง

---

## 4. Phase 1 – Core Engine (Backend Time Service)

**เป้าหมาย:**
- สร้าง Service กลางสำหรับคำนวณเวลา session/token
- ให้ Work Queue (และภายหลังหน้าอื่น) ใช้ service เดียวกัน
- ลดความซับซ้อนใน SQL, ย้าย logic มาอยู่ใน PHP/Service Layer

### 4.1 WorkSessionTimeEngine

สร้าง class ใหม่ เช่น:

- Namespace: `BGERP\Service\TimeEngine`  
- ชื่อไฟล์: `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`

หน้าที่:

- รับข้อมูล 1 แถวของ session จาก `token_work_session`
- รับค่าเวลา `now` (injectable เพื่อรองรับ unit test)
- คืน Timer DTO ที่บอกสถานะและเวลาทั้งหมด

โครงคลาส (conceptual):

```php
class WorkSessionTimeEngine
{
    public function calculateTimer(array $sessionRow, \DateTimeImmutable $now = null): array
    {
        // อ่าน status, work_seconds, started_at, resumed_at
        // คำนวณ base + live_tail
        // คืนค่า Timer DTO ตามรูปแบบมาตรฐาน
    }
}
```

### 4.2 Timer DTO (มาตรฐาน)

ค่า Timer ที่ Engine ส่งออกควรอยู่ในรูปแบบเดียวกันทุกแห่ง:

```php
$timer = [
    'work_seconds'      => (int) 1234,   // วินาที ณ ตอนนี้
    'base_work_seconds' => (int) 1200,   // จาก DB
    'live_tail_seconds' => (int) 34,     // ส่วนเพิ่ม ณ ช่วง now
    'status'            => 'active',     // active|paused|completed|none|unknown
    'started_at'        => '2025-11-18T10:00:00+07:00',
    'resumed_at'        => '2025-11-18T10:20:00+07:00',
    'last_server_sync'  => '2025-11-18T10:25:30+07:00',
];
```

เหตุผลที่ต้องมี `last_server_sync`:
- ใช้เป็น anchor ให้ Frontend timer คำนวณ drift ได้อย่างแม่นยำใน Phase 2

### 4.3 Integration จุดแรก: Work Queue

ปรับ `handleGetWorkQueue()`:

1. ใน SQL: เลิกใช้ CASE `work_seconds_display`  
   → ดึง column ดิบ: `s.status`, `s.work_seconds`, `s.started_at`, `s.resumed_at`

2. หลัง fetch rows ใน PHP: loop ทุก row → เรียก `WorkSessionTimeEngine::calculateTimer()`  
   → ผูก `timer` DTO เข้าใน `token` object

3. Response JSON ของ Work Queue:

```json
{
  "nodes": [
    {
      "tokens": [
        {
          "id_token": 123,
          "serial_number": "...",
          "timer": {
            "work_seconds": 1234,
            "status": "active",
            "last_server_sync": "..."
          }
        }
      ]
    }
  ]
}
```

4. Unit Test:
- Unit test สำหรับ WorkSessionTimeEngine
- Integration test เบื้องต้นสำหรับ Work Queue ว่ามี field `timer` ใน token

Phase 1 จบเมื่อ:
- Work Queue เลิกพึ่ง SQL CASE เวลา
- Timer logic อยู่ใน Service กลางที่มี Unit Test ครอบ

---

## 5. Phase 2 – Frontend Timer (Drift-corrected & Smooth)

**เป้าหมาย:**
- ให้เวลาใน Work Queue แสดงแบบ realtime ลื่น ๆ
- ลดการกระพริบ / หายไปกลับมาใหม่หลัง refresh
- แก้ปัญหาเวลาเพี้ยนเมื่อแท็บเปิดค้างนาน ๆ หรือ sleep

### 5.1 Drift-corrected Timer Concept

ปัจจุบัน: 
- Frontend ใช้ setInterval(); แล้ว `seconds++` โดยตรง → ถ้า tab sleep หรือ throttled → เวลาเพี้ยน

เป้าหมายใหม่:

- ใช้ค่าจาก Timer DTO:
  - `work_seconds`
  - `last_server_sync`
- คำนวณใน JS ตามสูตร:

```js
const base = timer.work_seconds;
const serverSync = new Date(timer.last_server_sync).getTime();
const localNow = Date.now();
const driftSeconds = Math.max(0, Math.floor((localNow - serverSync) / 1000));
const displaySeconds = base + driftSeconds;
```

- แล้ว format เป็น `mm:ss` / `hh:mm:ss`
- ทุก 1 วินาที แค่ re-calc จาก clock ไม่ได้ `+1` ทื่อ ๆ

ผลลัพธ์:
- ถ้าแท็บ sleep แล้วกลับมา → timer จะ “กระโดด” ไปตำแหน่งถูกต้องทันที จาก base + drift

### 5.2 UI Smoothing

นอกจาก timer ยังมี UX ต้องปรับใน Work Queue:

- แยก **full refresh** กับ **silent refresh**
  - กดปุ่ม Refresh → แสดง spinner และโหลดใหม่เต็ม ๆ
  - Action เล็ก ๆ (start/pause/resume/complete) → ใช้ silent refresh (ไม่โชว์ spinnerใหญ่, รักษา scroll position)

- ไม่ render loading placeholder ทับ card ทั้งแถวทุกครั้ง → หลีกเลี่ยงอาการ “จอกระพริบ”

Phase 2 จบเมื่อ:
- Work Queue แสดงเวลาแบบ realtime ได้เรียบเนียน
- ไม่มีอาการกระพริบรุนแรงหลัง action เล็ก ๆ
- เวลาไม่เพี้ยนชัดเจนหลังปล่อยแท็บทิ้งหลายสิบนาที

---

## 6. Phase 3 – Auto Guard (Abandoned Session Protection)

**เป้าหมาย:**
- ป้องกันกรณี session ค้างทั้งคืนเพราะลืมกด pause/complete
- ทำให้ข้อมูลเวลาเชื่อถือได้ในมุม Accounting/Costing และ Productivity

### 6.1 ปัญหาในโลกจริงที่ต้องแก้

ตัวอย่าง:
- ช่างกด Start แล้วกลับบ้าน → Session active ยาว 16 ชม.
- Tablet แบตหมด / ปิดเครื่อง โดยไม่ได้กด pause
- Network หลุดตอนส่งคำสั่ง pause → DB ไม่ได้บันทึก

หากไม่มี Auto Guard → ข้อมูลจะเพี้ยนหนักมาก เช่น:
- งาน 1 ใบใช้เวลา 20 ชม. ทั้งที่จริงทำแค่ 45 นาที

### 6.2 แนวทาง Auto Guard

สร้างกลไกระดับระบบ:

1. **Cron / Background Worker** (เช่นทุก 5–15 นาที):
   - Scan `token_work_session` ที่เป็น `active` นานเกิน threshold เช่น 2–4 ชม.
   - ถ้าเกิน → auto-pause + เขียน log ว่า system ปิดให้

2. **Hard limit per session**
   - ตั้ง max ต่อ session เช่น 12 ชม. → ถ้าเกินให้ system ปิด

3. **Policy ต่อแบรนด์/โรงงาน/คน**
   - ในอนาคตอาจให้แต่ละ Atelier กำหนด threshold ของตัวเองได้

4. **Audit Log**
   - ทุกครั้งที่ Auto Guard เข้ามายุ่ง → บันทึกลง log (ใคร, token ไหน, ก่อน/หลังเท่าไร)


Phase 3 จบเมื่อ:
- ไม่มี session active ลากยาวผิดธรรมชาติอีกต่อไป
- รายงานเวลาไม่มีค่า outlier แปลก ๆ โดยไม่ได้อธิบาย

### 6.3 Real-world Constraints for Bellavier (Smartphone + Lock-screen Behavior)

ระบบ Auto Guard ของ Bellavier ต้องออกแบบจากข้อจำกัดจริงของโรงงานปัจจุบัน ซึ่งแตกต่างจาก ERP โรงงานขนาดใหญ่ที่มีอุปกรณ์เฉพาะ ดังนั้นต้องยึด 3 ปัจจัยหลัก:

#### **Factor A – ช่างใช้สมาร์ทโฟนส่วนตัว ไม่ใช่อุปกรณ์เฉพาะทาง**
- ไม่สามารถควบคุมระบบปฏิบัติการ การนอนหลับหน้าจอ หรือ heartbeat background ได้
- ไม่สามารถคาดหวังให้มือถือส่งสัญญาณสม่ำเสมอเหมือน Android Tablet ที่ตั้ง kiosk mode

#### **Factor B – พฤติกรรมธรรมชาติของงานหัตถศิลป์**
- ช่างจะเริ่มงาน → ล็อกหน้าจอทันที เพราะมือเลอะกาว/ฝุ่น และต้องใช้สมาธิสูง
- ไม่ได้เปิดจอมาดู timer ระหว่างทำงาน
- Micro-break เช่น ลุกไปคุย หรือเดินไปหยิบอุปกรณ์ 2–5 นาทีเป็นเรื่องปกติ
- มีโอกาส “ลืมกด Pause” แม้เทรนมาแล้ว เพราะไม่ได้โฟกัสที่มือถือ

#### **Factor C – Notification แทบไม่มีความหมาย**
- เมื่อจอถูกล็อก การแจ้งเตือน Push/Popup ไม่ช่วยอะไร
- ดังนั้น Auto Guard ต้องไม่พึ่งพา notification หรือ user interaction เพิ่มเติมเลย

---

### 6.4 Auto Guard Model ที่เหมาะกับสถานการณ์ Bellavier ปัจจุบัน
จากข้อจำกัดทั้งสามข้างต้น ระบบต้องใช้ “เวลาจริง + estimated_minutes” เป็นฐาน และไม่พึ่ง heartbeat/notification จนกว่าระบบเติบโตพอจะออกอุปกรณ์เฉพาะทางในอนาคต

#### **Rule 1 – Session Duration Cap (เพดานเวลาต่อ node)**
กำหนดเพดานตามสูตร:
```
max_session_minutes = min(MAX_CAP_GLOBAL, max(MIN_CAP, estimated_minutes * FACTOR))
```
ตัวอย่าง:
- MIN_CAP = 10 นาที
- FACTOR = 3.0
- MAX_CAP_GLOBAL = 240 นาที

หาก session active เกินเพดาน → auto-pause + clamp เวลา เพื่อกันเคสลืมค้างทั้งคืน

#### **Rule 2 – Daily Cap (เพดานเวลาต่อวัน)**
- จำกัดเวลาทำงานรวมต่อ token ต่อวัน เช่น 4 ชั่วโมง/วัน
- ป้องกันกรณีลืมเปิด active ค้างข้ามวัน

#### **Rule 3 – Session Split ข้ามวัน**
หากตรวจพบ session active ข้ามวัน:
- ปิด session เดิมทันทีด้วย auto-guard
- จำกัดเวลาสูงสุดตามเพดาน node
- ช่างต้องกด start ใหม่ในวันถัดไปเพื่อเริ่ม session ใหม่

#### **Rule 4 – Micro-break Tolerance (ปล่อยผ่าน)**
- ปล่อยผ่านการเดินคุย 2–10 นาทีโดยไม่ auto-pause
- เป็น noise ที่ยอมรับได้ในงานหัตถศิลป์ และไม่ควรบังคับเข้มเกินไป

---

### 6.5 สรุปนโยบาย Auto Guard สำหรับ Bellavier เวอร์ชันปัจจุบัน
1. ไม่พึ่ง notification
2. ไม่พึ่ง heartbeat (เพราะมือถือจะล็อกจอทันทีเมื่อเริ่มทำงาน)
3. ใช้เพดานเวลาเป็นหลักเพื่อกันเคสหนัก (ค้างทั้งคืน/หลายชั่วโมง)
4. Micro-break ยอมรับว่าเป็นธรรมชาติของงาน
5. ช่างจะเรียนรู้และลืมกดลดลงเอง เพราะ DAG ไม่ให้ไป node ถัดไปจนกว่าปิด session

ด้วยแนวคิดนี้ Auto Guard จะ “กันสิ่งผิดธรรมชาติ” โดยไม่ไปรบกวน Flow งานของช่าง และไม่ต้องพึ่ง interaction เพิ่มเติมใด ๆ

---

## 7. Phase 4 – Multi-surface Integration

**เป้าหมาย:**
- ใช้ Time Engine เดียวกันแสดงข้อมูลในหลายจอ:
  - Work Queue (Operator)
  - People Monitor (Manager)
  - Trace Overview (QA / Backoffice)
  - Serial / Token Detail (สำหรับสอบสวนย้อนหลัง)

### 7.1 People Monitor Integration

เชื่อม Phase 2 + Task 10.2 เข้าด้วยกัน:

- ใช้ Time Engine นับเวลา active ของแต่ละ Operator
- แสดงใน People tab:
  - Current Work
  - Realtime timer ต่อคน
  - Workload breakdown: active / paused / assigned

### 7.2 Trace Overview

- ในหน้า Trace Overview ของ serial/token:
  - แสดง timeline พร้อมเวลาของแต่ละขั้นตอน (Workcenter/Node)
  - ใช้ข้อมูล Time Engine ร่วมกับ Token Routing เพื่อบอกว่าแต่ละเฟสใช้เวลานานเท่าไร

### 7.3 Serial / Token Detail

- หน้า detail ของ token/serial ควรสามารถแสดง:
  - History ของ session/time
  - ใครทำงาน, เมื่อไร, ใช้เวลาเท่าไรในแต่ละรอบ

Phase 4 จบเมื่อ:
- ทุกจอสำคัญในระบบ ERP เห็นเวลาในรูปแบบ consistent และมาจากแหล่งเดียวกัน

---

## 8. Phase 5 – Advanced Analytics, Costing & Optimization

**เป้าหมาย:**
- เปลี่ยนเวลาให้กลายเป็น Insight ระดับธุรกิจ และต้นทุน

### 8.1 Costing Per Item / Per Bag

เชื่อมเวลาเข้ากับข้อมูลอื่น:
- อัตราค่าแรงต่อชั่วโมงของแต่ละประเภทช่าง
- เวลาที่ใช้จริงบนแต่ละ Token/Serial

→ คำนวณต้นทุนแรงงาน per item ได้ละเอียดมาก:

> Labour cost = sum_over_sessions( work_seconds * hourly_rate / 3600 )

### 8.2 Productivity & Bottleneck Analysis

รวบรวมเวลาต่อ Workcenter / Node / Operator:
- ดูว่าจุดไหนใช้เวลามากผิดปกติ
- ใช้ปรับปรุง Process หรือ Training

### 8.3 SLA & Lead Time

- ใช้เวลาจริงของแต่ละระยะ (สร้าง serial → ready → active → done) เพื่อหา lead time ที่แท้จริง
- วัดว่าแต่ละ Atelier / โรงงานย่อยทำงานได้ตาม SLA ที่ Bellavier ต้องการไหม

### 8.4 การแยกประเภทเวลา (Future Extension)

ในอนาคต Time Engine อาจต้องรองรับหลายชนิดเวลา:
- Operator time (เวลาที่ใช้มือทำจริง)
- Machine time (เครื่องจักรทำงาน)
- Waiting / Queueing time (งานรอคิว)
- Blocked time (ติดปัญหา เช่น รอวัสดุ, รอ QC)

ตอนออกแบบ Time Engine v2 ต้องเผื่อให้ขยายได้ในอนาคตโดยไม่ต้องรื้อโครงสร้าง

---

---

## 8.5 Phase 6 – Estimated Minutes Integration (DAG Designer → Time Engine v2)

**เป้าหมาย:**
- นำ Estimated Minutes ที่กำหนดใน DAG Designer มาเชื่อมกับ Time Engine v2 เพื่อยกระดับระบบให้สามารถพยากรณ์เวลา, วัดประสิทธิภาพ และทำ Costing แบบมืออาชีพ

### 6.1 Estimated Minutes คืออะไร
Estimated Minutes คือ “เวลาทฤษฎี” ที่กำหนดไว้ในแต่ละ Node ใน Routing ของกระบวนการผลิต เช่น:
- เย็บริม: 12 นาที
- ขัดขอบ: 5 นาที
- ประกอบตัวกระเป๋า: 30 นาที

ข้อมูลนี้เป็นฐานสำหรับการประเมิน Lead time, Costing และ Productivity แบบ ERP ระดับโลก (Hermès / LV / Toyota Lean). 

---

### 6.2 Estimated vs Actual (Time Engine v2)
เมื่อ Time Engine v2 มีเวลาจริง (Actual Time) จาก token_work_session → เราสามารถจับคู่กับเวลาทฤษฎี (Estimated) ได้แบบ Real-time เพื่อวิเคราะห์:

1. **Efficiency (%)**
   ```
   Efficiency = EstimatedMinutes / ActualMinutes × 100
   ```
   ใช้สำหรับประเมินความชำนาญของ Operator และความเสถียรของกระบวนการ

2. **Process Stability**
   - ถ้า Actual ใกล้เคียง Estimated → ขั้นตอนเสถียร
   - ถ้าต่างกันมาก → มีปัญหา เช่น วัตถุดิบ, ทักษะ, เครื่องมือ

3. **Early Warning System (Future)**
   ถ้า Actual > Estimated × 2 → แสดงว่า process ล้น, อาจเกิด bottleneck

---

### 6.3 Integration จุดต่าง ๆ ของระบบ

#### 6.3.1 Work Queue (Operator)
- แสดง Estimated Minutes ของ Node ปัจจุบัน
- คำนวณ progress bar เช่น `5/12 นาที (41%)`
- ให้ Operator รู้ว่าควรใช้เวลาแค่ไหนในแต่ละ Node

#### 6.3.2 People Monitor (Manager)
เพิ่มข้อมูล:
- Workload (time-based) = sum(estimated_remaining_time)
- Efficiency ของแต่ละ Operator
- อัตราความเร็วเฉลี่ยของ Operator ต่อ Node

#### 6.3.3 Trace Overview
- เพิ่ม Estimated Time vs Actual Time ต่อ Node
- ช่วยสืบสวนปัญหาคุณภาพหรือกระบวนการ

#### 6.3.4 Costing Engine (Phase 5)
- ใช้ Estimated Time เป็น Planning Cost
- ใช้ Actual Time เป็น Actual Labour Cost
- วิเคราะห์ Margin/Profit ต่อใบได้ละเอียดมาก

---

### 6.4 Implementation Roadmap สำหรับ Estimated Minutes

1. เพิ่ม field `estimated_minutes` ในข้อมูล DAG Node (Frontend/Backend)
2. ส่ง Estimated Minutes มาใน Routing ของ Token เมื่อเข้าสู่ Node
3. Work Queue เรียก Time Engine v2 + Estimated เพื่อคำนวณ progress
4. บันทึก Estimated vs Actual ลง token_step_history (สำหรับ Traceability)
5. เปิดให้ People Monitor แสดงข้อมูล Efficiency
6. ส่งข้อมูลเข้าระบบรายงาน Costing และ Productivity (Phase 5)

---

### 6.5 ประโยชน์เชิงกลยุทธ์ต่อ Bellavier Group

- ทำให้ Bellavier Hatthasilpa กลายเป็นระบบ ERP ที่วัด Productivity ระดับ World-class
- สนับสนุน Narrative ของหัตถศิลป์ไทยอย่างมีข้อมูลจริงรองรับ
- ทำให้การกำหนดราคา / Profit / Capacity Planning แม่นยำมาก
- เป็น Data Asset ที่ไม่มีคู่แข่งในไทยมี

---

## 9. Summary – จุดย้ำเตือนสำหรับอนาคต

---

## 10. Time Engine Configuration & Governance

เพื่อให้ระบบเวลา (Time Engine) มีความน่าเชื่อถือระดับองค์กร จำเป็นต้องกำหนดนโยบายกลาง (Governance) และกำกับดูแลค่าต่าง ๆ ที่มีผลต่อการคำนวณ โดยหลักการสำคัญมีดังนี้:

### 10.1 Configuration Registry
กำหนดตัวแปรสำคัญทั้งหมดให้อยู่ใน config เดียว เช่น:
- `time_engine.min_cap_minutes`
- `time_engine.max_cap_global_minutes`
- `time_engine.auto_guard.daily_cap_hours`
- `time_engine.estimated_factor.default`
- `time_engine.session_split.enabled`

ค่าเหล่านี้ต้องไม่ hard-code ในโค้ด แต่ดึงจาก config กลาง เพื่อให้แก้ไขในอนาคตได้โดยไม่ต้องแก้โค้ดหลายที่

### 10.2 Multi-level Override
รองรับการตั้งค่าตามระดับต่าง ๆ:
- Global (Bellavier Group ทั้งหมด)
- Per Brand (Rebello / Charlotte Aimée)
- Per Atelier / Workshop
- Per Workcenter (ในอนาคต)

### 10.3 Change Governance
การเปลี่ยนแปลงค่า config ต้องระบุข้อมูลต่อไปนี้:
- ผู้เปลี่ยน / ผู้อนุมัติ
- เหตุผลของการปรับค่า
- วันที่เริ่มมีผล (Effective Date)
- ค่าก่อนหน้า (Previous Value)

เหตุผล: เพื่อให้สามารถย้อนไปตรวจสอบได้ว่า Efficiency/เวลาทำงานเปลี่ยนเพราะทักษะช่างหรือเพราะปรับ config

---

## 11. Observability & Health Metrics for Time Engine

Time Engine v2 เป็น core service ระดับระบบ จำเป็นต้องมีตัวชี้วัดสุขภาพ (Health Metrics) เพื่อให้ Manager, QA และ Dev ตรวจพบปัญหาได้เร็ว

### 11.1 Core Metrics
ควรมีการเก็บข้อมูลดังนี้:
- จำนวน active sessions ทั้งหมดปัจจุบัน
- จำนวน session ที่ Auto Guard ทำงานต่อวัน
- ค่าเฉลี่ยเวลาแต่ละ Node (Actual vs Estimated)
- จำนวน outlier (Actual > Estimated × factor)
- สัดส่วน session ที่เกือบเกินเพดานเวลาต่อ Node

### 11.2 Alerting Conditions
ระบบควรสร้าง Alert ถ้าเกิดเหตุการณ์ต่อไปนี้:
- Auto Guard ทำงานกับ Node เดิมหลายครั้งผิดปกติใน 1 วัน
- มี active session เกิน MAX_CAP_GLOBAL แม้มี Auto Guard
- ค่าเฉลี่ย Node เพิ่มขึ้นผิดปกติจากสัปดาห์ก่อน (อาจมีปัญหาคุณภาพวัสดุ / เครื่องมือ)
- Operator คนใดมี outlier จำนวนมากผิดปกติ

### 11.3 Internal Logging / Audit Trail
ทุกครั้งที่ Auto Guard ทำงาน ต้องบันทึก:
- Token / Session ที่โดนกระทบ
- ค่าเวลาเดิม / หลัง clamp
- เหตุผล (max cap / daily cap / cross-day / inconsistent state)
- Timestamp

เหตุผล: เพื่อให้ QA และ Dev ตรวจสอบได้ว่าสาเหตุเกิดจากระบบหรือพฤติกรรมผู้ใช้

---

## 12. Ethical Use & Craftsman-first Culture

เพื่อคงไว้ซึ่งคุณค่าของงานหัตถศิลป์ (Hatthasilpa) และไม่ให้ระบบเวลาเป็นเครื่องมือควบคุมมนุษย์จนเกินไป จึงต้องกำหนดหลักการทางจริยธรรมในการใช้ข้อมูลเวลา

### 12.1 Purpose-driven Use
ระบบเวลาใช้เพื่อ:
- พัฒนาคุณภาพงานของช่าง
- ปรับปรุงกระบวนการผลิต
- สร้าง Traceability และ Storytelling ของงานฝีมือ
- วิเคราะห์ Productivity เชิงระบบ

ไม่ใช่เพื่อ:
- ลงโทษช่างจาก micro-break 2–5 นาที
- จับผิดพฤติกรรมส่วนบุคคลในระดับละเอียดยิบ
- ใช้ตัวเลขเวลาอย่างหยาบเป็นตัวตัดสินคุณค่า

### 12.2 Fair Evaluation Model
เมื่อประเมินประสิทธิภาพของช่าง ต้องดูปัจจัยหลายด้านร่วมกัน:
- เวลา (Actual Work Seconds)
- คุณภาพงาน (QC Pass / Defect Rate)
- อัตราเคลมลูกค้า
- ความยากของงาน / Node
- ความเสถียรของผลงาน (Variation)

### 12.3 Transparency & Trust
ระบบต้องสามารถอธิบายได้เสมอว่า:
- เวลาใดนับโดยระบบ
- เวลาใดถูก Auto Guard ปรับ
- เวลาใดเกิดจากมนุษย์กดจริง

ช่างต้องสามารถตรวจสอบข้อมูลของตัวเองได้ → เพื่อให้รู้สึกว่าระบบเป็นผู้ช่วย ไม่ใช่เครื่องจับผิด

### 12.4 Culture of Improvement
เป้าหมายของ Time Engine คือ:
> "งานดีขึ้น, กระบวนการดีขึ้น, มือช่างเก่งขึ้น"

ไม่ใช่:
> "ทำให้ช่างรีบขึ้นจนงานเสียคุณภาพ"

---

1. ห้ามกลับไปเขียน logic เวลาซ้ำ ๆ ใน SQL/Controller อีก  
   → ทุกอย่างต้องวิ่งผ่าน Time Engine

2. การแสดงผลเวลาใน UI ที่สวยไม่พอ ต้อง **ถูกต้อง** และ **อธิบายได้ย้อนหลัง** เสมอ

3. Auto Guard ไม่ใช่ Option แต่เป็น Requirement สำหรับระบบจริงในโรงงาน  
   → ป้องกันข้อมูลเวลาเพี้ยนจากพฤติกรรมมนุษย์และสภาพแวดล้อม

4. ทุก Phase ที่ทำต่อจากนี้ (Task 12.x เป็นต้นไป) ให้ยึดเอกสารฉบับนี้เป็น Guideline กลาง  
   - Agent / Dev คนไหนเข้ามาใหม่ต้องอ่านไฟล์นี้ก่อนแก้ Time Engine

5. ถ้า Bellavier Group จะไปอยู่ระดับเดียวกับ Hermès / LVMH จริง ๆ  
   ระบบเวลา (Time Engine) จะเป็นหนึ่งใน “หัวใจลึก ๆ” ที่ทำให้ **Traceability, Productivity, Storytelling, และ Costing** แข็งแรงกว่าคู่แข่งในไทยแบบคนละระดับ
